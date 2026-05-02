// HomeKit accessory for iPhone play/stop control.
//
// Exposes a single Switch accessory ("P3 Radio") that mirrors owntone's
// player state. The Switch's On characteristic is driven by owntone's
// notification WebSocket — owntone is the source of truth, the Switch
// reflects it. User toggles call back into the same code paths the web
// UI uses (executePlay with the day's schedule, or Stop), so HomeKit
// behaves exactly like opening the web page and pressing Play / Stop.
//
// No pause: the stream is a livestream and pausing has no useful
// semantics.
//
// Lifecycle: runHAP blocks until ctx is cancelled. The hap server
// un-publishes mDNS and closes connections on cancel; the WS reader
// closes its socket and unwinds. Callers are expected to run this in
// an errgroup goroutine.

package main

import (
	"context"
	"fmt"
	"log"
	"path/filepath"
	"sync"

	"github.com/brutella/hap"
	"github.com/brutella/hap/accessory"
	haplog "github.com/brutella/hap/log"

	"p3-controller/owntone"
)

func init() {
	// hap's INFO logger emits one line every time another HomeKit
	// device on the same Home tries to authenticate without pairing
	// credentials (HomePods, Apple TVs, family devices retrying until
	// the Home Hub propagates pairings to them). Steady-state noise;
	// re-enable if debugging pairing problems.
	haplog.Info.Disable()
}

// HAPConfig is the optional "hap" block in the JSON config file.
type HAPConfig struct {
	Enabled  bool   `json:"enabled"`
	Pin      string `json:"pin"`
	Name     string `json:"name"`
	Port     int    `json:"port"`
	StateDir string `json:"state_dir"`
}

// runHAP starts the HomeKit accessory and blocks until ctx is
// cancelled or the server returns an error.
func runHAP(ctx context.Context, client *owntone.Client, cfg *Config) error {
	hcfg := cfg.HAP

	name := hcfg.Name
	if name == "" {
		name = "P3 Radio"
	}

	a := accessory.NewSwitch(accessory.Info{
		Name:         name,
		Manufacturer: "p3-controller",
		Model:        "p3",
	})
	// Leave a.A.Id at the hap default (auto-assigned to 1). The HAP
	// spec expects a single non-bridged accessory at aid=1; iOS Home
	// pairs it incorrectly otherwise. Stable identity across restarts
	// comes from the server UUID persisted in FsStore, not from aid.

	store := hap.NewFsStore(filepath.Join(hcfg.StateDir, "hap"))

	server, err := hap.NewServer(store, a.A)
	if err != nil {
		return fmt.Errorf("hap.NewServer: %w", err)
	}
	if hcfg.Pin != "" {
		server.Pin = hcfg.Pin
	}
	// Pin the TCP port so it doesn't collide with other hap servers
	// on the same host. Empty Addr lets hap pick an ephemeral port.
	if hcfg.Port != 0 {
		server.Addr = fmt.Sprintf(":%d", hcfg.Port)
	}

	// Mutex serialises writes to the On characteristic. Both the WS
	// reader (state→characteristic) and the user toggle handler can
	// race otherwise.
	var mu sync.Mutex
	setOn := func(v bool) {
		mu.Lock()
		defer mu.Unlock()
		a.Switch.On.SetValue(v)
	}

	// User toggle: call into the same flow the web UI uses. We do
	// NOT optimistically write the characteristic — the WS event will
	// reflect the resulting owntone state, keeping a single source of
	// truth and avoiding a flicker if the action fails.
	a.Switch.On.OnValueRemoteUpdate(func(on bool) {
		if on {
			schedule := scheduleForNow()
			resp, _ := executePlay(client, cfg, cfg.speakersForSchedule(schedule), schedule)
			if resp.Status != "playing" {
				log.Printf("hap: play failed: %s", resp.Error)
			}
			return
		}
		if err := client.Stop(); err != nil {
			log.Printf("hap: stop: %v", err)
		}
	})

	// WS reader → On characteristic. Runs as a child goroutine of
	// runHAP so its lifetime tracks the accessory.
	wsDone := make(chan struct{})
	go func() {
		defer close(wsDone)
		err := client.SubscribePlayer(ctx, func() {
			player, err := client.GetPlayer()
			if err != nil {
				log.Printf("hap: get player on event: %v", err)
				return
			}
			setOn(player.State == "play")
		})
		if err != nil && ctx.Err() == nil {
			log.Printf("hap: ws subscribe: %v", err)
		}
	}()

	log.Printf("hap: listening (name=%q addr=%q pin=%s state_dir=%s)", name, server.Addr, server.Pin, hcfg.StateDir)

	// ListenAndServe blocks until ctx is cancelled. It returns nil
	// on a clean cancel.
	serveErr := server.ListenAndServe(ctx)

	// Wait for the WS goroutine to unwind. Cancelling ctx closed the
	// socket; this should return promptly.
	<-wsDone

	if serveErr != nil && ctx.Err() == nil {
		return fmt.Errorf("hap server: %w", serveErr)
	}
	return nil
}

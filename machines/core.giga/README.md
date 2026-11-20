# core.giga

Bare metal at Gigahost. Main host for internet-facing services and VMs.
Monitoring stays on core.oracldn.

## Addresses

| What         | Value                                | Use                                   |
| ------------ | ------------------------------------ | ------------------------------------- |
| IPv4         | `185.243.216.95/24`, gw `.1`         | all public v4                         |
| IPv4 extra   | `185.243.216.96/24`                  | unused                                |
| IPv6 transit | `2a03:94e0:ffff:185:243:216::95/118` | next hop only                         |
| IPv6 routed  | `2a03:94e0:200d::/48`                | everything we source or publish       |
| Host v6      | `2a03:94e0:200d::1`                  | AAAA for vhosts, outgoing source      |
| VM v6        | `2a03:94e0:200d:68::/64`             | `incusbr0`, beside NAT `10.68.0.0/16` |

## Hardware

HP DL385 Gen10 Plus, 2x EPYC 7V12 (128 cores), 128 GB, 25GbE. The E208i-a
controller must run in HBA mode so ZFS sees raw disks.

## Storage

| Pool      | Disks                   | Shape  | Holds                                                            |
| --------- | ----------------------- | ------ | ---------------------------------------------------------------- |
| `rpool`   | 2x 500 GB SATA SSD      | mirror | NixOS, `/nix`, service state, Garage metadata, Incus pool `safe` |
| `fast`    | 2x 2 TB NVMe            | stripe | Incus pool `fast`, Hugin gallery                                 |
| `solo`    | 1x 2 TB NVMe            | single | Incus pool `solo`                                                |
| `storage` | 6x 1.8 TB SAS HDD (4Kn) | raidz2 | Syncthing set, Hugin album, Garage data, files, copies of `solo` |

Placement follows what a disk loss costs:

- `safe`, redundant: mail and ts1p VMs.
- `solo`, one disk, replicated nightly to `storage`: garnix VM.
- `fast`, no redundancy, no copy: dev VM and anything that can be rebuilt.
  Munin regenerates the Hugin gallery from the album.

`storage` datasets: the Syncthing set from `metadata/syncthing.nix`
(`software`, `pictures`, `backup`, `books`, `sync`), plus `album`, `garage`,
`files`, `replica`.

## Mail reputation

DNS blocklist lookup of `.95`, `.96`, both transit v6 and the routed prefix:
not listed on Barracuda, SpamCop, PSBL, Mailspike, DroneBL.

Not answered from a shared resolver, check by hand before the mail VM:

- Spamhaus: <https://check.spamhaus.org/>
- UCEPROTECT (level 2 and 3 list whole ranges): <https://www.uceprotect.net/en/rblcheck.php>

## Waiting on kradalby

- [ ] Install NixOS; disk ids, WAN MAC, host SSH key.
- [ ] Tailnet join key (`authkey kradalby`).
- [ ] Jottacloud login for the restic relay (`rclone config` on this host).
- [ ] 1Password service-account token for `ts1p.giga`.
- [ ] Basic-auth password for `hugin.kradalby.no`.
- [ ] Seed asparges prod from beta, or start empty.

## Next work packages

- [ ] Dev VM.
- [ ] Multiple Headscale versions.
- [ ] Mail VM `mail.giga` with Stalwart.

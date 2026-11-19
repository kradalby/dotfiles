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

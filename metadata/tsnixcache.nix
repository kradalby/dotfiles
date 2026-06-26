# Public facts about the gigabuilder tsnixcache binary cache. The signing key
# here is the PUBLIC (verification) half — safe to commit. Replace the
# placeholder with the real key once gigabuilder runs `tsnixcache key generate`.
# Until then a down/absent cache fails gracefully (fallback + connect-timeout).
{
  publicKey = "tsnixcache:REPLACE_WITH_PUBKEY";

  # tsnet MagicDNS name on the kradalby tailnet, port 80. priority 30 ⇒ preferred
  # over cachix (41/42) so our own builds resolve from here first.
  substituters = ["http://tsnixcache?priority=30"];
}

# Public facts about the gigabuilder tsnixcache binary cache. The signing key
# here is the PUBLIC (verification) half — safe to commit.
# A down/absent cache fails gracefully (fallback + connect-timeout).
{
  publicKey = "tsnixcache:Chid5Mll6U8ZUCio/j4KqxgtIeqPxH8Duqpz96TU4Es=";

  # tsnet MagicDNS name on the kradalby tailnet, port 80. priority 30 ⇒ preferred
  # over cachix (41/42) so our own builds resolve from here first.
  substituters = ["http://tsnixcache?priority=30"];
}

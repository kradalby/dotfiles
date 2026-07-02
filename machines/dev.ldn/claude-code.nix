{...}: {
  home-manager.users.kradalby.services.claude-code = let
    wt = path: capacity: {
      inherit path capacity;
      spawn = "worktree";
      verbose = true;
    };
  in {
    dotfiles = wt "~/git/dotfiles" 8;
    aspargesgaarden-elm = wt "~/git/aspargesgaarden-elm" 8;
    fiken-go = wt "~/git/fiken-go" 8;
    gigahost-go = wt "~/git/gigahost-go" 8;
    headscale = wt "~/git/headscale" 32;
    sfiber = wt "~/git/sfiber" 16;
    tsnixcache = wt "~/git/tsnixcache" 8;
    ts1p = wt "~/git/ts1p" 8;
  };
}

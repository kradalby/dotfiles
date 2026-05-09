{...}: {
  home-manager.users.kradalby.services.claude-code = {
    dotfiles = {
      path = "~/git/dotfiles";
      spawn = "same-dir";
      capacity = 5;
      verbose = true;
    };
    headscale = {
      path = "~/git/headscale";
      spawn = "worktree";
      capacity = 32;
      verbose = true;
    };
    sfiber = {
      path = "~/git/sfiber";
      spawn = "worktree";
      capacity = 16;
      verbose = true;
    };
    aspargesgaarden-elm = {
      path = "~/git/aspargesgaarden-elm";
      spawn = "worktree";
      capacity = 8;
      verbose = true;
    };
    TubeLogger2000 = {
      path = "~/git/TubeLogger2000";
      spawn = "worktree";
      capacity = 8;
      verbose = true;
    };
  };
}

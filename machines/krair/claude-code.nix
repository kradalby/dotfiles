{...}: {
  home-manager.users.kradalby.services.claude-code = {
    # macOS-only work lives here; everything else runs on dev.ldn.
    dotfiles = {
      path = "~/git/dotfiles";
      spawn = "same-dir";
      capacity = 5;
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

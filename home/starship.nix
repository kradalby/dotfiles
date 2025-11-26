{pkgs, ...}: {
  programs.starship = {
    enable = true;
    package = pkgs.starship;
    enableFishIntegration = true;
    settings = {
      format = "$git_branch$git_status$nix_shell$cmd_duration$line_break$character";
      add_newline = true;

      nix_shell = {
        disabled = false;
        format = "[in Nix]($style) ";
        style = "cyan";
      };

      command_duration = {
        min_time = 0;
        format = "[⏱ $duration]($style) ";
      };
    };
  };
}

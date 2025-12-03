{pkgs, ...}: {
  programs.starship = {
    enable = true;
    package = pkgs.starship;
    enableFishIntegration = true;
    settings = {
      format = "$username$hostname$directory$git_branch$git_status$nix_shell$cmd_duration$line_break$character";
      add_newline = true;

      username = {
        show_always = true;
        format = "[$user]($style)@";
      };

      hostname = {
        ssh_only = false;
        format = "[$hostname]($style) ";
      };

      directory = {
        truncation_length = 3;
        truncate_to_repo = true;
        fish_style_pwd_dir_length = 1;
        format = "[$path]($style) ";
      };

      git_branch = {
        format = "[$symbol$branch]($style) ";
      };

      nix_shell = {
        disabled = false;
        format = "[in Nix]($style) ";
        style = "cyan";
      };

      cmd_duration = {
        min_time = 0;
        format = "[⏱ $duration]($style) ";
      };
    };
  };
}

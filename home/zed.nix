{
  "project_panel" = {
    "dock" = "right";
  };
  "base_keymap" = "VSCode";
  "theme" = {
    "light" = "One Light";
    "dark" = "Ayu Dark";
  };
  "telemetry" = {
    "diagnostics" = false;
    "metrics" = false;
  };
  "vim_mode" = true;
  "ui_font_size" = 14;
  "buffer_font_size" = 14;
  # "assistant" = {
  #   "default_open_ai_model" = "gpt-4-0613";
  # };
  languages = {
    Nix = {
      formatter = {
        external = {
          command = "alejandra";
          arguments = [];
        };
      };
    };
  };
}

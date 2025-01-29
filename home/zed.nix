{
  project_panel = {
    dock = "right";
  };
  base_keymap = "VSCode";
  theme = {
    light = "One Light";
    dark = "One Light";
    # "dark" = "Ayu Dark";
  };
  telemetry = {
    diagnostics = false;
    metrics = false;
  };
  vim_mode = true;
  ui_font_size = 14;
  buffer_font_size = 14;
  assistant = {
    version = "2";
    default_model = {
      provider = "ollama";
      model = "deepseek-r1:70b";
    };
  };
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

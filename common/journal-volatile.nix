{
  services.journald = {
    extraConfig = ''
      Storage=volatile
    '';
  };
}

{ config, lib, ... }: {
  services.autossh = {
    sessions = [
      {
        name = "docker-sock";
        user = "kradalby";
        monitoringPort = 20000;
        extraArguments = "-nNT -L localhost:2375:/var/run/docker.sock root@dev.ntnu.fap.no";
      }
    ];
  };
}

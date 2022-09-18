{
  servers = {
    ldn = {
      additional_networks = [ "10.65.0.0/16" "2a02:6b66:7019::/64" ];
      addresses = [ "10.69.0.205/32" "2a03:94e0:200d:69::205/128" ];
      endpoint_address = "ldn.fap.no";
      endpoint_port = 51820;
      public_key = "L1sF/PWHXiavT2arPLhDyh9wWwK5a3UeC4mpvFG8xFE=";
    };

    ntnu = {
      additional_networks = [ "10.61.0.0/16" ];
      addresses = [ "10.69.0.201/32" "2a03:94e0:200d:69::201/128" ];
      dns = "10.61.0.1";
      endpoint_address = "ntnu.fap.no";
      endpoint_port = 51820;
      public_key = "Vs52WDNND1jBNuMjuHY0/oRg/bLK0f4SWDAmvk4yv28=";
    };

    oracleldn = {
      additional_networks = [ "10.66.0.0/16" ];
      addresses = [ "10.69.0.206/32" "2a03:94e0:200d:69::206/128" ];
      endpoint_address = "oracldn.fap.no";
      endpoint_port = 51820;
      public_key = "Gp4ZxbTOP3yo8SVPBC1Bi34OqArGYsvP3MNT1CjbTyM=";
    };

    oraclefurt = {
      additional_networks = [ "10.67.0.0/16" ];
      addresses = [ "10.69.0.207/32" "2a03:94e0:200d:69::207/128" ];
      endpoint_address = "oracfurt.fap.no";
      endpoint_port = 51820;
      public_key = "3cjdc90xSHcs+E9lY1LoLavsWumxyNtsfCVuLWKHglw=";
    };

    terra = {
      additional_networks = [ "10.60.0.0/16" "2a03:94e0:200d::/48" ];
      addresses = [ "10.69.0.200/32" "2a03:94e0:200d:69::200/128" ];
      dns = "10.60.0.1";
      endpoint_address = "terra.fap.no";
      endpoint_port = 51820;
      public_key = "c/PM40me7sWgdYyXTMCTV3KXuRvCvpQzIW5AK4w+fDY=";
    };

    tjoda = {
      additional_networks = [ "10.62.0.0/16" ];
      addresses = [ "10.69.0.202/32" ];
      dns = "10.62.0.1";
      endpoint_address = "tjoda.fap.no";
      endpoint_port = 51820;
      public_key = "sZ6JQB3ud/NxyxrEiTBe6MkoTU4BTpaYz4lvboAq8AQ=";
    };

  };

  clients = {
    kpad = {
      additional_networks = [ ];
      addresses = [ "10.69.0.15/32" "2a03:94e0:200d:69::15/128" ];
      public_key = "nlpKp2gIsJhlOaj4buYlvznPuA7NHSDiDRSVEf/vRXM=";
    };

    kphone = {
      additional_networks = [ ];
      addresses = [ "10.69.0.2/32" "2a03:94e0:200d:69::2/128" ];
      public_key = "DjFhVRUhFgONHJqpFXoIb5WncKbZEvqkS7+Ub2VuSis=";
    };

    kramacbook = {
      additional_networks = [ ];
      addresses = [ "10.69.0.1/32" "2a03:94e0:200d:69::1/128" ];
      public_key = "A2hlNqjakhcYw+d40FQYUrMbnRN6KfL/ZhNAzuNoSjY=";
    };

    kranovo = {
      additional_networks = [ ];
      addresses = [ "10.69.0.4/32" "2a03:94e0:200d:69::4/128" ];
      public_key = "+08yaHUEhIin8ULKohe85TJzNvSmuM6CTL+qSmQkBQQ=";
    };

    kristineair = {
      additional_networks = [ ];
      addresses = [ "10.69.0.10/32" "2a03:94e0:200d:69::10/128" ];
      public_key = "2RA5T1aSHtNPpiqMXaKMhozmdJguPaWmMGJY7PekeFE=";
    };

    storagebassan = {
      additional_networks = [ ];
      addresses = [ "10.69.0.16/32" "2a03:94e0:200d:69::16/128" ];
      public_key = "nL309b5ZosnRKL0xGiNuCln9q5FqA8UGdot54C2ioy0=";
    };

    vetlelaptop = {
      additional_networks = [ ];
      addresses = [ "10.69.0.8/32" "2a03:94e0:200d:69::8/128" ];
      public_key = "c2l8n/va4SvSwmxF+Ckv6GFhJmj6W0EOXndHJwQJwXo=";
    };

    vetlephone = {
      additional_networks = [ ];
      addresses = [ "10.69.0.7/32" "2a03:94e0:200d:69::7/128" ];
      public_key = "gIUy1AimcxaPRK336Qmi47eZ2FBHO0vWHs3aYfg/62I=";
    };

    headscale = {
      additional_networks = [ ];
      addresses = [ "10.69.0.9/32" "2a03:94e0:200d:69::9/128" ];
      public_key = "tuiPc7znUC4vAFJhmbsVuenGBGY+Y4WgVxGrVUl6/wk=";
    };

  };

}

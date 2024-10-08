{
  servers = {
    oracleldn = {
      additional_networks = ["10.66.0.0/16"];
      addresses = ["10.69.0.206/32" "2a03:94e0:200d:69::206/128"];
      endpoint_address = "oracldn.fap.no";
      endpoint_port = 51820;
      public_key = "Gp4ZxbTOP3yo8SVPBC1Bi34OqArGYsvP3MNT1CjbTyM=";
    };

    oraclefurt = {
      additional_networks = ["10.67.0.0/16"];
      addresses = ["10.69.0.207/32" "2a03:94e0:200d:69::207/128"];
      endpoint_address = "oracfurt.fap.no";
      endpoint_port = 51820;
      public_key = "3cjdc90xSHcs+E9lY1LoLavsWumxyNtsfCVuLWKHglw=";
    };

    terra = {
      additional_networks = ["10.60.0.0/16" "2a03:94e0:200d::/48"];
      addresses = ["10.69.0.200/32" "2a03:94e0:200d:69::200/128"];
      dns = "10.60.0.1";
      endpoint_address = "terra.fap.no";
      endpoint_port = 51820;
      public_key = "c/PM40me7sWgdYyXTMCTV3KXuRvCvpQzIW5AK4w+fDY=";
    };

    tjoda = {
      additional_networks = [
        "10.62.0.0/16"
        # Advertise "selskap", Asparges guest network
        # "192.168.200.0/24"
      ];
      addresses = ["10.69.0.202/32"];
      dns = "10.62.0.1";
      endpoint_address = "tjoda.fap.no";
      endpoint_port = 51820;
      public_key = "sZ6JQB3ud/NxyxrEiTBe6MkoTU4BTpaYz4lvboAq8AQ=";
    };
  };

  clients = {
    ldn = {
      additional_networks = ["10.65.0.0/16" "2a02:6b66:7019::/64"];
      addresses = ["10.69.0.205/32" "2a03:94e0:200d:69::205/128"];
      # endpoint_address = "ldn.fap.no";
      # endpoint_port = 51820;
      public_key = "L1sF/PWHXiavT2arPLhDyh9wWwK5a3UeC4mpvFG8xFE=";
    };

    kramacbook = {
      additional_networks = [];
      addresses = ["10.69.0.1/32" "2a03:94e0:200d:69::1/128"];
      public_key = "A2hlNqjakhcYw+d40FQYUrMbnRN6KfL/ZhNAzuNoSjY=";
    };

    storagebassan = {
      additional_networks = [];
      addresses = ["10.69.0.16/32" "2a03:94e0:200d:69::16/128"];
      public_key = "nL309b5ZosnRKL0xGiNuCln9q5FqA8UGdot54C2ioy0=";
    };

    headscale = {
      additional_networks = [];
      addresses = ["10.69.0.9/32" "2a03:94e0:200d:69::9/128"];
      public_key = "tuiPc7znUC4vAFJhmbsVuenGBGY+Y4WgVxGrVUl6/wk=";
    };
  };
}

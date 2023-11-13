{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  cfg = config.services.tailscale-nginx-auth;
in {
  options.services.tailscale-nginx-auth = {
    enable = mkEnableOption "Tailscale NGINX Authentication service";

    package = mkOption {
      type = types.package;
      description = ''
        Package to use
      '';
      default = pkgs.tailscale-tools;
    };

    authConfig = mkOption {
      type = types.str;
      description = ''
        Variable to use in your nginx virtual host block
      '';
      default = ''
        auth_request /auth;
        auth_request_set $auth_user $upstream_http_tailscale_user;
        auth_request_set $auth_name $upstream_http_tailscale_name;
        auth_request_set $auth_login $upstream_http_tailscale_login;
        auth_request_set $auth_tailnet $upstream_http_tailscale_tailnet;
        auth_request_set $auth_profile_picture $upstream_http_tailscale_profile_picture;

        proxy_set_header X-Webauth-User "$auth_user";
        proxy_set_header X-Webauth-Name "$auth_name";
        proxy_set_header X-Webauth-Login "$auth_login";
        proxy_set_header X-Webauth-Tailnet "$auth_tailnet";
        proxy_set_header X-Webauth-Profile-Picture "$auth_profile_picture";
      '';
    };

    internalRoute = mkOption {
      type = types.str;
      description = ''
        Variable to use in your nginx virtual host block
      '';
      default = ''
        location /auth {
          internal;

          proxy_pass http://unix:/run/tailscale-nginx-auth/tailscale.nginx-auth.sock;
          proxy_pass_request_body off;

          # proxy_set_header Host $http_host;
          proxy_set_header Host $host;
          proxy_set_header Remote-Addr $remote_addr;
          proxy_set_header Remote-Port $remote_port;
          proxy_set_header Original-URI $request_uri;
        }
      '';
    };
  };

  config = mkIf (cfg.enable && config.services.nginx.enable) {
    systemd.services.tailscale-nginx-auth = {
      enable = true;
      description = "Tailscale NGINX Authentication service";
      script = ''
        ${cfg.package}/bin/nginx-auth -sockpath /run/tailscale-nginx-auth/tailscale.nginx-auth.sock
      '';
      wantedBy = ["default.target"];
      after = ["nginx.service"];
      wants = ["nginx.service"];

      serviceConfig = {
        # DynamicUser = true;
        User = config.services.nginx.user;
        Group = config.services.nginx.group;
        RuntimeDirectory = "tailscale-nginx-auth";
        RuntimeDirectoryMode = "0755";
      };

      path = [cfg.package];
    };

    # systemd.sockets.tailscale-nginx-auth = {
    #   description = "Tailscale NGINX Authentication socket";
    #   partOf = ["tailscale-nginx-auth.service"];
    #   listenStreams = ["/run/tailscale-nginx-auth/tailscale.nginx-auth.sock"];
    #   wantedBy = ["sockets.target"];
    # };
  };
}

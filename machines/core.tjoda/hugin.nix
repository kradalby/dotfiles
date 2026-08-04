# hugin serves the Munin-generated gallery off the 850 EVO. It is a tsnet app
# (kraweb), so it joins the tailnet as its own node `hugin` and exposes
# /metrics there — no VIP, same shape as hvor/krapage on core.oracldn.
{ config, ... }:
{
  age.secrets.hugin-tskey = {
    file = ../../secrets/hugin-tskey.age;
    owner = config.services.hugin.user;
  };

  services.hugin = {
    enable = true;
    # Munin's targetFolder: /pictures/hugin holds root/ and keywords/ directly.
    # /pictures/album is the raw export Munin reads from and is not served.
    contentDir = "/pictures/hugin";
    tailscaleKeyPath = config.age.secrets.hugin-tskey.path;
  };
}

# Without a join credential, the fleet SSH keys provide access on the local network.
{ services.openssh.openFirewall = true; }

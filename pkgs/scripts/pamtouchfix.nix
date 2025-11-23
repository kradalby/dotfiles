{ pkgs, ... }:
pkgs.writeScriptBin "pamtouchfix" ''
  #!/run/current-system/sw/bin/bash
  cat <<EOT > /etc/pam.d/sudo
  auth       optional       /opt/homebrew/lib/pam/pam_reattach.so
  auth       sufficient     pam_tid.so
  auth       sufficient     pam_smartcard.so
  auth       required       pam_opendirectory.so
  account    required       pam_permit.so
  password   required       pam_deny.so
  session    required       pam_permit.so
  EOT
''

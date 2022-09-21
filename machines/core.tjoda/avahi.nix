{config, ...}: {
  services.avahi = {
    interfaces = [config.my.lan "tailscale0" "wg0"];
    extraServiceFiles = {
      timemachine-tjoda = ''
        <?xml version="1.0" standalone='no'?><!--*-nxml-*-->
        <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
        <service-group>
          <name replace-wildcards="yes">core-tjoda</name>
          <service>
            <type>_smb._tcp</type>
            <port>445</port>
          </service>
          <service>
            <type>_device-info._tcp</type>
            <port>0</port>
            <txt-record>model=MacPro7,1@ECOLOR=226,226,224</txt-record>
          </service>
          <service>
            <type>_adisk._tcp</type>
            <txt-record>sys=waMa=0,adVF=0x100</txt-record>
            <txt-record>dk0=adVN=TimeMachineTjoda,adVF=0x82</txt-record>
          </service>
        </service-group>
      '';
    };
  };
}

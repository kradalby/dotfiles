{config, ...}: {
  services.avahi = {
    reflector = true;
    interfaces = [config.my.lan "iot" "tailscale0" "wg0"];
    extraServiceFiles = {
      timemachine-tjoda = ''
        <?xml version="1.0" standalone='no'?>
        <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
        <service-group>
         <name replace-wildcards="yes">core-tjoda</name>
         <service>
           <type>_smb._tcp</type>
           <host-name>core.tjoda.fap.no</host-name>
           <port>445</port>
         </service>
         <service>
           <type>_device-info._tcp</type>
           <host-name>core.tjoda.fap.no</host-name>
           <port>0</port>
               <!--<txt-record>model=TimeCapsule8,119</txt-record>-->
           <txt-record>model=RackMac</txt-record>
         </service>
         <service>
           <type>_adisk._tcp</type>
           <host-name>core.tjoda.fap.no</host-name>
           <txt-record>sys=waMa=0,adVF=0x100</txt-record>
           <txt-record>dk0=adVN=TimeMachineTjoda,adVF=0x82</txt-record>
         </service>
        </service-group>
      '';
      timemachine-terra = ''
        <?xml version="1.0" standalone='no'?>
        <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
        <service-group>
         <name replace-wildcards="yes">core-terra</name>
         <service>
           <type>_smb._tcp</type>
           <host-name>core.terra.fap.no</host-name>
           <port>445</port>
         </service>
         <service>
           <type>_device-info._tcp</type>
           <host-name>core.terra.fap.no</host-name>
           <port>0</port>
               <!--<txt-record>model=TimeCapsule8,119</txt-record>-->
           <txt-record>model=RackMac</txt-record>
         </service>
         <service>
           <type>_adisk._tcp</type>
           <host-name>core.terra.fap.no</host-name>
           <txt-record>sys=waMa=0,adVF=0x100</txt-record>
           <txt-record>dk0=adVN=TimeMachineTerra,adVF=0x82</txt-record>
         </service>
        </service-group>
      '';
    };
  };
}

{...}: let
  guestShare = path: {
    inherit path;
    browsable = "yes";
    "guest ok" = "yes";
    "read only" = "yes";
  };
in {
  services.samba = {
    shares = {
      storage = {
        path = "/storage";
        browsable = "yes";
        "guest ok" = "no";
        writeable = "yes";
        "valid users" = "kradalby";
        "force user" = "storage";
        "force group" = "storage";
        "create mask" = "0755";
        "directory mask" = "0775";
      };

      software = guestShare "/storage/software";
      libraries = guestShare "/storage/libraries";
      pictures = guestShare "/storage/pictures";
      books = guestShare "/storage/books";

      dropbox = {
        path = "/storage/dropbox";
        browsable = "yes";
        writeable = "yes";
        "guest ok" = "yes";
        "force user" = "storage";
        "force group" = "storage";
        "create mask" = "0755";
        "directory mask" = "0775";
      };
    };
  };
}

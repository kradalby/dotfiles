{ pkgs, ... }:
let
  inherit (pkgs) lib;

  # A photo is exported once per album it belongs to, so these spill extra
  # top-level dirs into the export.
  excludedAlbums = [
    "RAW"
    "Smarts"
    "Grafikk"
    "Snapchat"
    "WhatsApp"
  ];

  # Photos has no 2002 folder, hence the split range.
  years = map toString (lib.reverseList (lib.range 2003 2026)) ++ [
    "2001"
    "1992"
  ];

  namedFolders = [
    "Familie"
    "Unfinished"
  ];

  folders = years ++ namedFolders;

  config = (pkgs.formats.toml { }).generate "osxphotos.toml" {
    export = {
      # What gets picked up.
      only_photos = true;
      cleanup = true;
      retry = 5;
      convert_to_jpeg = true;
      jpeg_ext = "jpeg";
      download_missing = true;
      # use_photokit = true;

      # Metadata written into the exported files.
      exiftool = true;
      exiftool_merge_keywords = true;
      exiftool_merge_persons = true;
      person_keyword = true;
      keyword_template = [
        "{place.name.country}"
        "{place.name.area_of_interest}"
        "{place.name.city}"
        "{place.name.state_province}"
        "{searchinfo.venue_type}"
        "{searchinfo.venue}"
        "{searchinfo.activity}"
        "{searchinfo.holiday}"
        "{searchinfo.season}"
      ];
      # finder_tag_keywords = true;

      # Keeping the destination in step with the library.
      force_update = true;
      cleanup = true;
      # The share is the drive root, so cleanup would go after ext4's lost+found.
      keep = [ "lost+found" ];
      retry = 5;
      # overwrite = true;
      # ramdb unset: forced anyway for an export db on a network volume.
    };
  };
in
pkgs.writeShellApplication {
  name = "exportphotos";

  runtimeInputs = with pkgs; [ jq ];

  text = builtins.replaceStrings [ "@config@" ] [ "${config}" ] (builtins.readFile ./exportphotos.sh);
}

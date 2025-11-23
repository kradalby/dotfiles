{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "exif-set-photographer";

  runtimeInputs = with pkgs; [exiftool];

  text = ''
    if [ "$#" -ne 2 ]; then
      echo "Incorrect number of arguments"
      echo "USAGE: $0 <author> <image file>"
      exit 1
    fi

    author=$1
    img=$2

    exiftool -use MWG \
      "-filecreatedate<datetimeoriginal" \
      "-filemodifydate<datetimeoriginal" \
      -overwrite_original \
      -Copyright="Photo by $author. All rights to the respective authors." \
      -Creator="$author" \
      -Owner="$author" \
      -ownername="$author" \
      "$img"
  '';
}

{
  pkgs,
  lib,
  ...
}: let
  # this resolution allows two cameras on RPi4
  resolution = "1280x720";
  c270 = path: "${lib.getExe pkgs.ffmpeg} -hide_banner -loglevel error -f v4l2 -video_size ${resolution} -framerate 5 -i ${path} -pix_fmt yuv420p -c:v libx264 -preset ultrafast -b:v 600k -c:a aac -b:a 160k -f rtsp rtsp://localhost:$RTSP_PORT/$RTSP_PATH";
in {
  services.mediamtx = {
    enable = true;

    allowVideoAccess = true;

    settings = {
      paths = {
        cam0 = {
          runOnInit = c270 "/dev/v4l/by-id/usb-046d_0825_A4221F10-video-index0";
          runOnInitRestart = true;
        };
        cam1 = {
          runOnInit = c270 "/dev/v4l/by-id/usb-046d_0825_C4021F10-video-index0";
          runOnInitRestart = true;
        };
      };
    };
  };
}

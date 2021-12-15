#!/usr/bin/env bash
set -euo pipefail
SECONDS=0

# shellcheck disable=SC1090,SC1091
source "$HOME/git/client_bash/prometheus.bash"

io::prometheus::NewGauge name=photos_app_start_time_seconds help='Start time of the process since unix epoch in seconds.'
photos_app_start_time_seconds set "$(date +%s)"

labels_json=$(osxphotos labels --json)
number_of_labels=$(echo "$labels_json" | jq '.labels? | length')

info_json=$(osxphotos info --json)
# database_path=$(echo "$info_json" | jq '.database_path')

album_count=$(echo "$info_json" | jq '.albums_count')
hidden_photo_count=$(echo "$info_json" | jq '.hidden_photo_count')
keywords_count=$(echo "$info_json" | jq '.keywords_count')
movie_count=$(echo "$info_json" | jq '.movie_count')
persons_count=$(echo "$info_json" | jq '.persons_count')
photo_count=$(echo "$info_json" | jq '.photo_count')
shared_albums_count=$(echo "$info_json" | jq '.shared_albums_count')
shared_movie_count=$(echo "$info_json" | jq '.shared_movie_count')
shared_photo_count=$(echo "$info_json" | jq '.shared_photo_count')

people_json=$(echo "$info_json" | jq '.persons | with_entries(select(.value >= 100))')

io::prometheus::NewGauge name=photos_app_photo_count help='Number of photos in Photos.app database'
photos_app_photo_count set "$photo_count"

io::prometheus::NewGauge name=photos_app_album_count help='Number of albums in Photos.app database'
photos_app_album_count set "$album_count"

io::prometheus::NewGauge name=photos_app_hidden_photo_count help='Number of hidden photos in Photos.app database'
photos_app_hidden_photo_count set "$hidden_photo_count"

io::prometheus::NewGauge name=photos_app_keyword_count help='Number of keywords in Photos.app database'
photos_app_keyword_count set "$keywords_count"

io::prometheus::NewGauge name=photos_app_label_count help='Number of labels in Photos.app database'
photos_app_label_count set "$number_of_labels"

io::prometheus::NewGauge name=photos_app_movie_count help='Number of movies in Photos.app database'
photos_app_movie_count set "$movie_count"

io::prometheus::NewGauge name=photos_app_people_count help='Number of people in Photos.app database'
photos_app_people_count set "$persons_count"

io::prometheus::NewGauge name=photos_app_shared_album_count help='Number of shared albums in Photos.app database'
photos_app_shared_album_count set "$shared_albums_count"

io::prometheus::NewGauge name=photos_app_shared_movie_count help='Number of shared movies in Photos.app database'
photos_app_shared_movie_count set "$shared_movie_count"

io::prometheus::NewGauge name=photos_app_shared_photo_count help='Number of shared photos in Photos.app database'
photos_app_shared_photo_count set "$shared_photo_count"

io::prometheus::NewGauge name=photos_app_person_photo_count help='Number of photos per person in Photos.app database' labels=fullname
while read -r person; do
    count=$(echo "$people_json" | jq "to_entries[] | select(.key == \"$person\") | .value")
    photos_app_person_photo_count -fullname="$person" set "$count"
done <<<"$(echo "$people_json" | jq -r 'keys | .[]')"

in_cloud_count=$(osxphotos --json query --incloud | jq "length")
not_in_cloud_count=$(osxphotos --json query --not-incloud | jq "length")
cloudasset_count=$(osxphotos --json query --cloudasset | jq "length")
not_cloudasset_count=$(osxphotos --json query --not-cloudasset | jq "length")
in_album_count=$(osxphotos --json query --in-album | jq "length")
not_in_album_count=$(osxphotos --json query --not-in-album | jq "length")
panorama_count=$(osxphotos --json query --panorama | jq "length")
selfie_count=$(osxphotos --json query --selfie | jq "length")
edited_count=$(osxphotos --json query --edited | jq "length")
portrait_count=$(osxphotos --json query --portrait | jq "length")
burst_count=$(osxphotos --json query --burst | jq "length")
hdr_count=$(osxphotos --json query --hdr | jq "length")

io::prometheus::NewGauge name=photos_app_in_cloud_photo_count help='Number of photos present in iCloud in Photos.app database'
photos_app_in_cloud_photo_count set "$in_cloud_count"

io::prometheus::NewGauge name=photos_app_not_in_cloud_photo_count help='Number of photos not present in iCloud in Photos.app database'
photos_app_not_in_cloud_photo_count set "$not_in_cloud_count"

io::prometheus::NewGauge name=photos_app_cloudasset_photo_count help='Number of photos that is part of a iCloud library in Photos.app database'
photos_app_cloudasset_photo_count set "$cloudasset_count"

io::prometheus::NewGauge name=photos_app_not_cloudasset_photo_count help='Number of photos that is not part of a iCloud library in Photos.app database'
photos_app_not_cloudasset_photo_count set "$not_cloudasset_count"

io::prometheus::NewGauge name=photos_app_in_album_photo_count help='Number of photos in one or more albums in Photos.app database'
photos_app_in_album_photo_count set "$in_album_count"

io::prometheus::NewGauge name=photos_app_not_in_album_photo_count help='Number of photos not in any album in Photos.app database'
photos_app_not_in_album_photo_count set "$not_in_album_count"

io::prometheus::NewGauge name=photos_app_panorama_photo_count help='Number of panorama photos in Photos.app database'
photos_app_panorama_photo_count set "$panorama_count"

io::prometheus::NewGauge name=photos_app_selfie_photo_count help='Number of selfie photos in Photos.app database'
photos_app_selfie_photo_count set "$selfie_count"

io::prometheus::NewGauge name=photos_app_edited_photo_count help='Number of edited photos in Photos.app database'
photos_app_edited_photo_count set "$edited_count"

io::prometheus::NewGauge name=photos_app_portrait_photo_count help='Number of portrait photos in Photos.app database'
photos_app_portrait_photo_count set "$portrait_count"

io::prometheus::NewGauge name=photos_app_burst_photo_count help='Number of burst photos in Photos.app database'
photos_app_burst_photo_count set "$burst_count"

io::prometheus::NewGauge name=photos_app_hdr_photo_count help='Number of HDR photos in Photos.app database'
photos_app_hdr_photo_count set "$hdr_count"

DURATION=$SECONDS

io::prometheus::NewGauge name=photos_app_time_seconds help='Time spent gathering metrics with osxphotos'
photos_app_time_seconds set "$DURATION"

io::prometheus::NewGauge name=photos_app_end_time_seconds help='End time of the process since unix epoch in seconds.'
photos_app_end_time_seconds set "$(date +%s)"

io::prometheus::PushAdd \
    job="photos_app" \
    instance="kramacbook.vpn.fap.no" \
    gateway="https://pushgateway.terra.fap.no"
# path=""

# io::prometheus::ExportAsText

exit 0

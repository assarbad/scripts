#!/usr/bin/env bash
for i in "$@"; do
        ( \
                set -x; \
                ffmpeg -i "$i" -threads 4 -c:v libx264 -preset slow -profile:v high -c:a aac -strict experimental -vf scale=-1:720 "${i%.mov}.mp4" && \
                exiftool −overwrite_original_in_place -r -tagsFromFile "$i" "-gps:*" "${i%.mov}.mp4" && \
                mp4file --optimize "${i%.mov}.mp4" && \
                ffmpeg -i "$i" -threads 4 -c:v libvpx -crf 10 -b:v 1M -c:a libvorbis -vf scale=-1:720 "${i%.mov}.webm" \
        )
done

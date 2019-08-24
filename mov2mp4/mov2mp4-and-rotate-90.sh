#!/usr/bin/env bash
for i in "$@"; do
        ( \
                set -x; \
                ffmpeg -i "$i" -threads 4 -c:v libx264 -preset slow -profile:v high -strict experimental -c:a aac -vf "transpose=dir=clock:passthrough=landscape" "${i%.mov}.mp4" && \
                exiftool −overwrite_original_in_place -r -tagsFromFile "$i" "-gps:*" "${i%.mov}.mp4" && \
                mp4file --optimize "${i%.mov}.mp4" && \
                ffmpeg -i "$i" -threads 4 -c:v libvpx -crf 10 -b:v 1M -c:a libvorbis -vf "transpose=dir=clock:passthrough=landscape" -metadata:s:v rotate=0 "${i%.mov}.webm" \
        )
done

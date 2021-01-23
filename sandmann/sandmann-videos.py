#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# vim: set autoindent smartindent softtabstop=4 tabstop=4 shiftwidth=4 expandtab:
from __future__ import print_function, with_statement, unicode_literals, division, absolute_import
__author__ = "Oliver Schneider"
__copyright__ = "2020/21 Oliver Schneider (assarbad.net), under Public Domain/CC0, or MIT/BSD license where PD is not applicable"
__version__ = "0.2"
import argparse
import os
import sys
import json
import urllib.request
from urllib.parse import urlparse, urlunparse, urljoin
from collections import OrderedDict
from io import StringIO
from selenium import webdriver
from selenium.webdriver.common.keys import Keys

def get_videos(baseurl):
    videos = OrderedDict()
    try:
        options = webdriver.FirefoxOptions()
        options.add_argument('--headless')
        driver = webdriver.Firefox(options=options)
        driver.set_window_size(1120, 550)
        driver.get(baseurl)
        video_list = driver.find_elements_by_xpath("//div[contains(@class, 'manualteaserpicture') and contains(@class, 'player') and contains(@class, 'video')]")
        for video in video_list:
            mtinfo = video.get_attribute("data-jsb")
            metainfo = json.loads(mtinfo)
            for key in {"config", "media", "analytics"}:
                assert key in metainfo, "Der '{}'-Schlüssel fehlt in data-jsb".format(key)
            analytics = metainfo["analytics"]
            for key in {"rbbtitle", "rbbhandle", "chapter", "isTrailer", "duration", "termids"}:
                assert key in analytics, "Der '{}'-Schlüssel fehlt in data-jsb[analytics]".format(key)
            rbbtitle, rbbhandle = analytics["rbbtitle"], analytics["rbbhandle"]
            if "sendung_gebaerde" in rbbhandle:
                continue
            if "mit Gebärdensprache" in rbbtitle:
                continue
            media_info_url = urljoin(driver.current_url, metainfo["media"])
            response = urllib.request.urlopen(media_info_url)
            media_details = json.loads(response.read())
            for key in {"rbbtitle", "rbbhandle", "_type", "_isLive", "_duration", "_mediaArray"}:
                assert key in media_details, "Der '{}'-Schlüssel fehlt im JSON aus {}: {}".format(key, analytics["rbbtitle"], media_info_url)
            mdarray = media_details["_mediaArray"]
            assert len(mdarray) == 1, "Unerwartete Länge für _mediaArray"
            assert "_mediaStreamArray" in mdarray[0], "Fehlendes _mediaStreamArray in _mediaArray"
            stmarray = mdarray[0]["_mediaStreamArray"]
            streams = [x["_stream"] for x in stmarray if x["_stream"].endswith(".mp4") and ("hd-1800k" in x["_stream"] or "hd-3584k" in x["_stream"])]
            videos[(rbbtitle, rbbhandle)] = streams
    finally:
        driver.quit()
    return videos

def download_video(title, url):
    fname = title.replace(":", " -")
    extension = url.split("_")[-1]
    quality = extension.split(".")[0]
    print("""# Title: {title}
download '{filename} [{quality}].mp4' '{url}'
""".format(title=title, filename=fname, quality=quality, url=url))

if __name__ == "__main__":
    videos = get_videos("https://sandmann.de/videos/")
    print("#!/usr/bin/env bash")
    print("# Number of videos:", len(videos))
    print("""
DL="$HOME/.sandmann_downloaded.txt"
DLPROG=wget
if ! type $DLPROG > /dev/null 2>&1; then
    DLPROG=curl
    if ! type $DLPROG > /dev/null 2>&1; then
        echo "Kein Programm zum gefunden mit dem man die Videos runterladen kann (weder wget noch curl)."
    fi
fi

function curl_download() {
    ( set -x; curl --output "$1" "$2" )
}

function wget_download() {
    ( set -x; wget -O "$1" "$2" )
}

function download() {
    local FILE="$1"
    local URL="$2"
    local TITLE="$3"
    if [[ -e "$DL" ]] && grep -q "$URL" "$DL"; then
        echo "Der Titel '$TITLE' wurde bereits runtergeladen (vermutlicher Dateiname: $FILE)"
    else
        ${DLPROG}_download "$FILE" "$URL" && echo "$URL"|tee -a "$DL"
    fi
}
""")
    for (title, handle), urls in videos.items():
        for url in urls:
            download_video(title, url)

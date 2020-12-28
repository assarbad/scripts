#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# vim: set autoindent smartindent softtabstop=4 tabstop=4 shiftwidth=4 expandtab:
from __future__ import print_function, with_statement, unicode_literals, division, absolute_import
__author__ = "Oliver Schneider"
__copyright__ = "2020 Oliver Schneider (assarbad.net), under Public Domain/CC0, or MIT/BSD license where PD is not applicable"
__version__ = "0.1"
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
    print("# Title: {}\nwget -O '{} [{}].mp4' '{}'".format(title, fname, quality, url))

if __name__ == "__main__":
    videos = get_videos("https://sandmann.de/videos/")
    print("# Number of videos:", len(videos))
    for (title, handle), urls in videos.items():
        for url in urls:
            download_video(title, url)

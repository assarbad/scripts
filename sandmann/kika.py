#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# vim: set autoindent smartindent softtabstop=4 tabstop=4 shiftwidth=4 expandtab:
from __future__ import print_function, with_statement, unicode_literals, division, absolute_import
__author__ = "Oliver Schneider"
__copyright__ = "2020/21 Oliver Schneider (assarbad.net), under Public Domain/CC0, or MIT/BSD license where PD is not applicable"
__version__ = "0.1"
import argparse
import os
import sys
import re
import urllib.request
from collections import OrderedDict, namedtuple
from io import StringIO
from selenium import webdriver
from selenium.webdriver.common.keys import Keys
import xml.etree.ElementTree as ET

Asset = namedtuple('Asset', ['title', 'width', 'height', 'url', 'alturl'])

def nav_single_page(url, driver):
    driver.get(url)
    video_list = driver.find_elements_by_xpath("//a[contains(@class, 'js-broadcast-link') and @id[starts-with(., 'avplayer')]]")
    assert video_list, "Keine Videos auf {} gefunden".format(url)
    for video in video_list:
        name = video.get_attribute("title")
        onclick = video.get_attribute("onclick")
        # Die URL zu der XML mit den Download-Details rausklauben
        m = re.search(r"return BRavFramework\.register\(BRavFramework\(.+?\)\.setup\(\{dataURL:'([^']+)'\}\)\);", onclick)
        if m:
            xmlurl = m.group(1)
            yield (name, xmlurl,)

def get_videos(baseurl):
    videos = []
    try:
        options = webdriver.FirefoxOptions()
        options.add_argument('--headless')
        driver = webdriver.Firefox(options=options)
        driver.set_window_size(1920, 1080)
        driver.get(baseurl)
        title = driver.title
        # Navigation mit den Einzeilseiten für je x Videos
        pages = driver.find_elements_by_xpath("//a[contains(@class, 'pageItem')]")
        if pages:
            urls = set(page.get_attribute("href") for page in pages)
            assert urls, "Konnte die URLs zu den Unterseiten der Navigation nicht ermitteln"
            for url in sorted(urls):
                for name, xmlurl in nav_single_page(url, driver):
                    videos.append((title, name, xmlurl,))
        else: # ... manchmal gibt es aber bei wenigen Videos auch keine Navigation
            url = baseurl
            for name, xmlurl in nav_single_page(url, driver):
                videos.append((title, name, xmlurl,))
    finally:
        driver.quit()
    return videos

def decode_asset(name, node):
    assert node.tag == "asset", "Kann nur <asset /> Elemente parsen"
    height = int(node.find("./frameHeight").text, 10)
    width = int(node.find("./frameWidth").text, 10)
    assert height > 0, "Height is {}".format(height)
    assert width > 0, "Width is {}".format(width)
    url = node.find("./progressiveDownloadUrl").text
    alturl = node.find("./rtspStreamingUrl").text if node.find("./rtspStreamingUrl") else None
    if url == alturl:
        alturl = None
    return Asset(name, width, height, url, alturl)

def decode_xml(name, xmlurl):
    print("Name: {}\n\tURL: {}".format(name, xmlurl), file=sys.stderr)
    with urllib.request.urlopen(xmlurl) as xmlf:
        tree = ET.parse(xmlf)
        root = tree.getroot()
        assert root.tag == "avDocument"
        for asset in root.findall("./assets/asset"):
            yield decode_asset(name, asset)

def sanitize_name(inp):
    return inp.replace(":", " -").replace("?", "")

def download_video(title, video):
    assert video.url is not None, "No download URL for '{}'".format(video.title)
    if title.lower().endswith(" - kika"):
        title = title[:-7]
    extension = video.url.split(".")[-1].strip()
    fname = "{}/{} [{}p].{}".format(sanitize_name(title), sanitize_name(video.title), video.height, extension)
    print("""# Titel: {title}
download '{filename}' '{url}' '{title}'
""".format(title=video.title, filename=fname, url=video.url))

if __name__ == "__main__":
    if len(sys.argv) <= 1:
        raise RuntimeError("Die URL oder URLs müssen angegeben werden")
    baseurls = sys.argv[1:]
    videos = OrderedDict()
    num_vids = 0
    for baseurl in baseurls:
        try:
            for title, name, xmlurl in get_videos(baseurl):
                if title not in videos:
                    videos[title] = []
                for video in decode_xml(name, xmlurl):
                    if video.height >= 576:
                        # print(video, file=sys.stderr)
                        videos[title].append(video)
                        num_vids += 1
        except AssertionError as e:
            print(e, file=sys.stderr)
    print("#!/usr/bin/env bash")
    print("# Anzahl Videos:", num_vids)
    print("""
DL="$HOME/.kika_downloaded.txt"
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
    local DIRNAME="${FILE%/*}"
    local URL="$2"
    local TITLE="$3"
    if [[ -e "$DL" ]] && grep -q "$URL" "$DL"; then
        echo "Der Titel '$TITLE' wurde bereits runtergeladen (vermutlicher Dateiname: $FILE)"
    else
        if [[ "$FILE" != "$DIRNAME" ]] && [[ -n "$DIRNAME" ]] && [[ ! -d "$DIRNAME" ]]; then
            mkdir "$DIRNAME"
        fi
        ${DLPROG}_download "$FILE" "$URL" && echo "$URL"|tee -a "$DL"
    fi
}
""")
    for title, per_title_videos in videos.items():
        for video in per_title_videos:
            download_video(title, video)

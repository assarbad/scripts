#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# vim: set autoindent smartindent softtabstop=4 tabstop=4 shiftwidth=4 expandtab:
from __future__ import print_function, with_statement, unicode_literals, division, absolute_import
__author__ = "Oliver Schneider"
__copyright__ = "2021 Oliver Schneider (assarbad.net), under Public Domain/CC0, or MIT/BSD license where PD is not applicable"
__version__ = "0.1"
import os
import sys
import functools
import tempfile
from configparser import ConfigParser
from contextlib import contextmanager
from pathlib import Path
try:
    from selenium import webdriver
    # from selenium.common.exceptions import StaleElementReferenceException, TimeoutException
    # from selenium.webdriver.support import expected_conditions as EC
    # from selenium.webdriver.support.ui import WebDriverWait  # see: https://stackoverflow.com/a/46881813/
    # from selenium.webdriver.common.by import By
except ModuleNotFoundError:
    print("ERROR: please install 'selenium' (and a geckodriver) via 'pip' or try 'pipenv sync'!\n", file=sys.stderr)
    raise

DEFAULT_CONFIG = """\
[DEFAULT]
"""

DEFAULT_CREDENTIALS = """\
[secrets]
username = you@domain.tld
password = yourverysecretpassword
"""


@contextmanager
def firefox_driver(headless, profile_path=None, *args, **kwargs):
    """\
    This little context manager preconfigures Firefox the way we want it
    and yields a webdriver.Firefox instance\
    """
    downloadable = [
        "application/octet-stream",
        "application/pdf",
        "application/text",
        "application/x-pdf",
        "application/x-gzip",
        "application/xml",
        "application/zip",
        "text/csv",
        "text/plain",
        "text/xml",
    ]
    parent_dir = Path(__file__).resolve().parent
    with tempfile.TemporaryDirectory(prefix="download.", dir=str(parent_dir)) as dl_path:
        print("Download location: {}".format(dl_path))
        options = webdriver.FirefoxOptions()
        if headless:
            print("Not showing (marionette) browser UI")
            options.headless = True
        # if profile_path and os.path.isdir(profile_path):
        #     print("Using profile path: '{}'".format(profile_path))
        #     options.set_preference('profile', profile_path)
        options.ensure_clean_session = True
        options.set_preference('browser.cache.disk.enable', False)
        options.set_preference('browser.cache.memory.enable', True)
        options.set_preference('browser.cache.offline.enable', False)
        options.set_preference("browser.download.folderList", 2)
        options.set_preference("browser.download.manager.showWhenStarting", False)
        options.set_preference("browser.download.manager.alertOnEXEOpen", False)
        options.set_preference("browser.download.manager.focusWhenStarting", False)
        options.set_preference("browser.download.manager.useWindow", False)
        options.set_preference("browser.download.manager.showAlertOnComplete", False)
        options.set_preference("browser.download.manager.closeWhenDone", False)
        options.set_preference("browser.download.dir", dl_path)
        options.set_preference("browser.download.useDownloadDir", True)
        options.set_preference("browser.download.viewableInternally.enabledTypes", "")
        options.set_preference("browser.download.viewableInternally.typeWasRegistered.xml", False)
        options.set_preference("browser.helperApps.neverAsk.saveToDisk", ", ".join(downloadable))
        options.set_preference("browser.helperApps.alwaysAsk.force", False)
        options.set_preference("intl.accept_languages", "en-US")
        options.set_preference("pdfjs.disabled", True)
        options.set_preference("places.history.enabled", False)
        driver = webdriver.Firefox(options=options)  # service_log_path=os.path.devnull
        # service = selenium.webdriver.common.service.Service(executable)
        # driver = Firefox(service=service, options=options)
        try:
            driver.set_window_size(1920, 1080)
            yield driver
        finally:
            print("Quitting marionette browser", file=sys.stderr)
            driver.quit()


def process_page(cmdline, USERNAME, PASSWORD, *args, **kwargs):
    """\
    This is the central function which uses the webdriver instance to claim remaining
    keys.
    """
    assert all(isinstance(x, str) and x for x in {USERNAME, PASSWORD}), "Expected non-empty strings"
    headless = not cmdline.get("show_browser", False)
    url = "https://startpage.com"

    print("Visiting: {}".format(url))
    with firefox_driver(headless) as driver:
        driver.implicitly_wait(10)
        driver.get(url)
        # WebDriverWait(driver, 15).until(EC.element_to_be_clickable((By.ID, "foobar")))
        print("[{}] {}".format(driver.current_url, driver.title))


@functools.cache
def get_config_basepath(add_extension=""):
    """Return the path to the current script without extension"""
    return os.path.splitext(os.path.realpath(__file__))[0] + add_extension


def get_config():
    """\
    Read the configuration files (defaults, .ini and .credentials)
    and return the result as ConfigParser instance (defaults + .ini)
    and dict (everything)\
    """
    ini_path = get_config_basepath(".ini")
    cfg = ConfigParser()
    cfg.read_string(DEFAULT_CONFIG, source="<defaults>")
    cfg.read(ini_path)
    # assert "secrets" not in cfg.sections(), "Cannot store credentials in .ini. Use a .credentials file instead."
    # Logic for .ini file
    cred = ConfigParser()
    cred_path = get_config_basepath(".credentials")
    cred.read(cred_path)
    # assert cred.has_section("secrets"), "Need to have a [secrets] section in the .credentials file!"
    # Logic for .credentials file
    return cfg, {}


def parse_args():
    from argparse import ArgumentParser
    parser = ArgumentParser(description="This script attempts to claim keys from the my.visualstudio.com portal and downloads the KeysExport.xml")
    parser.add_argument("-c", "--write-credentials", action="store_true",
                        help="Writes a .credential with default values next to the script for customization,"
                        "_unless_ such a file already exists (i.e. it won't overwrite anything!).")
    parser.add_argument("-d", "--download-only", "--download", action="store_true",
                        help="This will instruct the script not to attempt to claim keys, but rather download KeysExport.xml"
                        "_unless_ such a file already exists (i.e. it won't overwrite anything!).")
    parser.add_argument("-i", "--write-ini", action="store_true",
                        help="Writes an .ini with default values next to the script for customization,"
                        "_unless_ such a file already exists (i.e. it won't overwrite anything!).")
    parser.add_argument("-s", "--show-browser", action="store_true",
                        help="Will show the browser window of the marionette geckodriver. The effect of this is _not_ to pass '--headless' to geckodriver.")
    return parser.parse_args()


def write_defaults(extension, key, contents, cmdline):
    """Writes one of the default files, unless the file already exists"""
    if cmdline.get(key, False):
        fname = get_config_basepath(extension)
        print("Writing {} file ({})".format(extension, fname))
        try:
            with open(fname, "x") as deffile:
                deffile.write(contents)
                return True
        except FileExistsError as exc:
            print(str(exc))
            return True
    return False


def main(**cmdline):
    wrote_creds = write_defaults(".credentials", "write_credentials", DEFAULT_CREDENTIALS, cmdline)
    wrote_ini = write_defaults(".ini", "write_ini", DEFAULT_CONFIG, cmdline)
    if wrote_creds or wrote_ini:
        return 0
    cfg, options = get_config()
    process_page(cmdline, "username", "password", **options)
    return 0


if __name__ == "__main__":
    args = parse_args()
    try:
        sys.exit(main(**vars(args)))
    except SystemExit:
        pass
    except ImportError:
        raise  # re-raise
    except RuntimeError:
        raise  # re-raise
    except:  # noqa: E722
        raise  # re-raise

#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# vim: set autoindent smartindent softtabstop=4 tabstop=4 shiftwidth=4 expandtab:
from __future__ import print_function, with_statement, unicode_literals, division, absolute_import
__author__ = "Oliver Schneider"
__copyright__ = "2021 Oliver Schneider (assarbad.net), under Public Domain/CC0, or MIT/BSD license where PD is not applicable"
__version__ = "0.2"
import os
import sys
import functools
import tempfile
from configparser import ConfigParser
from contextlib import contextmanager
from datetime import datetime
from pathlib import Path
try:
    from selenium import webdriver
    from selenium.common.exceptions import StaleElementReferenceException, TimeoutException
    from selenium.webdriver.support import expected_conditions as EC
    from selenium.webdriver.support.ui import WebDriverWait  # see: https://stackoverflow.com/a/46881813/
    from selenium.webdriver.common.by import By
except ModuleNotFoundError:
    print("ERROR: please install 'selenium' (and a geckodriver) via 'pip' or try 'pipenv sync'!\n", file=sys.stderr)
    raise

DEFAULT_CONFIG = """\
[DEFAULT]
portal = https://my.visualstudio.com/

[URLs]
prodkey = %(portal)sProductKeys
login = https://login.microsoftonline.com/
    https://login.live.com/
export = %(portal)s_apis/Key/ExportMyKeys?upn=

[IDs]
email = i0116
password = i0118
nextbtn = idSIButton9
exportbtn = id__15
"""

DEFAULT_CREDENTIALS = """\
[secrets]
email = you@domain.tld
password = yourverysecretpassword
"""


@contextmanager
def firefox_driver(headless, profile_path, no_rename, *args, **kwargs):
    """\
    This little context manager preconfigures Firefox the way we want it
    and yields a webdriver.Firefox instance\
    """
    utcnow = datetime.utcnow()
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
        # if profile_path:
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
            dlkeys = Path(os.path.join(dl_path, "KeysExport.xml"))
            if dlkeys.is_file:
                print("Keys were downloaded as: {}".format(str(dlkeys)))
                newname = os.path.join(str(parent_dir), "{:04d}-{:02d}-{:02d}_{:s}".format(utcnow.year, utcnow.month, utcnow.day, str(dlkeys.name)))
                if no_rename:
                    newname = os.path.join(str(parent_dir), str(dlkeys.name))
                print("\t... renaming to: {:s}".format(newname))
                dlkeys.rename(newname)
            driver.quit()


def do_step(driver, stepname, clickable, send=None, assert_urls=(), wait_duration=10):
    """\
    Performs a single step using the driver, waiting for a particular element
    to be clickable before performing it.

    driver: The webdriver.Firefox instance
    stepname: a string describing what
    clickable: a tuple of selenium.webdriver.common.by and the defining aspect (e.g. an ID)
    send: defines what action will be performed
        - None: nothing will be done
        - True: element will be .click()-ed
        - anything else will be passed to .send_keys()
    assert_urls: a single string or a tuple of strings with which the URL should start after
        waiting. If empty (tuple), no assertion will be done. Takes the parameters .startswith()
        expects.\
    """
    try:
        print("[>STEP] {}".format(stepname), file=sys.stderr)
        elem = WebDriverWait(driver, wait_duration).until(EC.element_to_be_clickable(clickable))
        assert not assert_urls or driver.current_url.startswith(assert_urls), "Something went wrong [{}], ended up at: {}".format(stepname, driver.current_url)
        print("[STEP>] {}".format(stepname), file=sys.stderr)
        if send is not None:
            if send is True:
                elem.click()
            else:
                elem.send_keys(send)
    except AssertionError:
        print("Title: {}".format(driver.title), file=sys.stderr)
        print("URL: {}".format(driver.current_url), file=sys.stderr)
        driver.save_screenshot("failure-screenshot.png")
        raise


def get_exported_keys_xml(driver, url_prodkey, id_exportbtn):
    """\
    This function attempts to export the keys from active subscriptions, by
    initiating a download of the XML file.

    TODO/FIXME:
    * create temporary directory inside download base directory
    Work in progress!!!
    """
    do_step(driver, "waiting for Product Keys page to be loaded", (By.ID, id_exportbtn), assert_urls=url_prodkey)
    do_step(driver, "clicking 'Export all keys'", (By.XPATH,
            "//button[@aria-label='Export all keys' and @aria-expanded='false' and @aria-haspopup='true' and contains(@class, ' export-all-keys ')]"),
            send=True, assert_urls=url_prodkey)
    do_step(driver, "clicking 'From active subscriptions'", (By.XPATH,
            "//button[@aria-label='From active subscriptions' and @aria-disabled='false' and @role='menuitem']"),
            send=True, assert_urls=url_prodkey)
    do_step(driver, "waiting for Product Keys page to be accessible after downloading XML", (By.ID, id_exportbtn), assert_urls=url_prodkey)


def get_keys(cmdline, url_prodkey, url_login, url_export, id_email, id_password, id_nextbtn, id_exportbtn, EMAIL, PASSWORD, *args, **kwargs):
    """\
    This is the central function which uses the webdriver instance to claim remaining
    keys.
    """
    assert all(isinstance(x, tuple) for x in {url_prodkey, url_login, url_export}), "Expected tuples"
    assert all(isinstance(x, str) and x for x in {id_email, id_password, id_nextbtn, id_exportbtn, EMAIL, PASSWORD}), "Expected non-empty strings"
    url = url_prodkey[0]

    headless = not cmdline.get("show_browser", False)
    profile_dir = cmdline.get("profile", None)
    no_rename = cmdline.get("no_rename", False)

    print("Visiting: {}".format(url))
    with firefox_driver(headless, profile_dir, no_rename) as driver:
        driver.get(url)

        nextbtn = (By.ID, id_nextbtn)

        if not cmdline.get("no_auth", False):
            do_step(driver, "entering email", (By.ID, id_email), send=EMAIL, assert_urls=url_login)
            do_step(driver, "clicking Next after entering email", nextbtn, send=True, assert_urls=url_login)
            do_step(driver, "entering password", (By.ID, id_password), send=PASSWORD, assert_urls=url_login)
            do_step(driver, "clicking Login/Next button after entering password", nextbtn, send=True, assert_urls=url_login)
            do_step(driver, "clicking Yes/Next button (stay signed in)", nextbtn, send=True, assert_urls=url_login)

        if cmdline.get("download_only", False):
            get_exported_keys_xml(driver, url_prodkey, id_exportbtn)
            return

        do_step(driver, "waiting for Product Keys page to be loaded", (By.ID, id_exportbtn), assert_urls=url_prodkey)

        # Merely report a count
        claims = driver.find_elements(By.CSS_SELECTOR, "a.claim-key-link")
        num_claims = len(claims)
        print("\t{} links with 'Claim Key'".format(num_claims), file=sys.stderr)

        driver.implicitly_wait(10)

        while True:
            claim = WebDriverWait(driver, 120).until(EC.presence_of_element_located((By.CSS_SELECTOR, "a.claim-key-link")))
            print("[STEP] Clicking: '{}'".format(claim.get_attribute("aria-label")), file=sys.stderr)
            claim.click()
            print("\t... waiting after click", file=sys.stderr)
            try:
                WebDriverWait(driver, 15).until(EC.element_to_be_clickable((By.ID, id_exportbtn)))
            except (TimeoutException, StaleElementReferenceException) as e:
                print("\t... looks like the daily limit was reached", file=sys.stderr)
                WebDriverWait(driver, 10).until(EC.presence_of_element_located((By.CLASS_NAME, "errormessage")))
                WebDriverWait(driver, 10).until(EC.presence_of_element_located((By.CSS_SELECTOR, "h2.title")))
                download_keys = driver.current_url == "https://my.visualstudio.com/Errors?e=46"
                if download_keys:
                    print("\t... yep, it's about the daily limit", file=sys.stderr)
                print("[{}] {}".format(driver.current_url, driver.title), file=sys.stderr)
                print(str(e), file=sys.stderr)
                if download_keys:
                    print("\t... let's try to download the XML with the keys", file=sys.stderr)
                    driver.get(url)
                    get_exported_keys_xml(driver, url_prodkey, id_exportbtn)
                return
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
    assert "secrets" not in cfg.sections(), "Cannot store credentials in .ini. Use a .credentials file instead."
    expecting = {"URLs", "IDs"}
    assert all(x in cfg.sections() for x in expecting),\
        "Missing sections in the read configuration. Expecting at least sections: {}".format(", ".join(expecting))
    options = {}
    blacklist = cfg.defaults()
    for section in cfg.sections():
        if section in {"", "DEFAULT"}:
            continue
        for key, value in cfg.items(section):
            # Skip defaults
            if key in blacklist and value == blacklist[key]:
                continue
            if section in {"URLs"}:
                options["{}_{}".format(section.lower()[:-1], key)] = tuple(x for x in value.split("\n"))
            elif section in {"IDs"}:
                options["{}_{}".format(section.lower()[:-1], key)] = value
    cred = ConfigParser()
    cred_path = get_config_basepath(".credentials")
    cred.read(cred_path)
    assert cred.has_section("secrets"), "Need to have a [secrets] section in the .credentials file!"
    expecting = {"password", "email"}
    assert all(cred.has_option("secrets", x) for x in expecting),\
        "Expected to find a 'password' and 'email' option in the [secrets] section."
    for option in expecting:
        options[option.upper()] = cred.get("secrets", option)
    return cfg, options


def parse_args():
    from argparse import ArgumentParser
    parser = ArgumentParser(description="This script attempts to claim keys from the my.visualstudio.com portal and downloads the KeysExport.xml")
    parser.add_argument("-A", "--no-auth", action="store_true",
                        help="Assume the user is already authenticated (best used with -p).")
    parser.add_argument("-c", "--write-credentials", action="store_true",
                        help="Writes a .credential with default values next to the script for customization,"
                        "_unless_ such a file already exists (i.e. it won't overwrite anything!).")
    parser.add_argument("-d", "--download-only", "--download", action="store_true",
                        help="This will instruct the script not to attempt to claim keys, but rather download KeysExport.xml"
                        "_unless_ such a file already exists (i.e. it won't overwrite anything!).")
    parser.add_argument("-i", "--write-ini", action="store_true",
                        help="Writes an .ini with default values next to the script for customization,"
                        "_unless_ such a file already exists (i.e. it won't overwrite anything!).")
    parser.add_argument("-R", "--no-rename", action="store_true",
                        help="Will skip renaming the KeysExport.xml to YYYY-MM-DD_KeysExport.xml")
    parser.add_argument("-s", "--show-browser", action="store_true",
                        help="Will show the browser window of the marionette geckodriver. The effect of this is _not_ to pass '--headless' to geckodriver.")
    parser.add_argument("-p", "--profile", action="store_true",
                        help="Allows to set the browser profile path to use.")
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
    get_keys(cmdline, **options)
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

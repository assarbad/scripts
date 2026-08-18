#!/usr/bin/env -S uv run --script --quiet
# -*- coding: utf-8 -*-
# vim: set autoindent smartindent softtabstop=4 tabstop=4 shiftwidth=4 expandtab:
from __future__ import print_function, with_statement, unicode_literals, division, absolute_import

__author__ = "Oliver Schneider"
__copyright__ = "2021, 2023 Oliver Schneider (assarbad.net), under Public Domain, or CC0 where Public Domain dedications are not possible"
__version__ = "0.4"
import os
import sys
import functools
import tempfile
from configparser import ConfigParser
from contextlib import contextmanager, suppress
from datetime import datetime
from pathlib import Path
from time import sleep
from timeit import default_timer as timer

try:
    from selenium import webdriver
    from selenium.common.exceptions import StaleElementReferenceException, TimeoutException, NoSuchElementException
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

[suppressions]
claim = (VL)
    Virtual Server 2005 Standard
    Windows Essential Business Server 2008 Standard and Premium Management Server
    Windows Essential Business Server 2008 Standard and Premium Messaging Server
    Windows Essential Business Server 2008 Standard and Premium Security Server
    Windows Small Business Server 2011 Essentials
    Windows Storage Server 2008 Workgroup
    Windows Storage Server 2008 Standard
    Windows Thin PC
    Windows XP Home
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
        print(f"Download location: {dl_path}")
        options = webdriver.FirefoxOptions()
        if headless:
            print("Not showing (marionette) browser UI")
            options.headless = True
        if profile_path and os.path.isdir(profile_path):
            print(f"Using profile path: '{profile_path}'")
            options.set_preference("profile", profile_path)
        else:
            options.ensure_clean_session = True
            options.set_preference("browser.cache.disk.enable", False)
            options.set_preference("browser.cache.memory.enable", True)
        options.set_preference("browser.cache.offline.enable", False)
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
            if dlkeys.is_file():
                print(f"Keys were downloaded as: {str(dlkeys)}")
                newname = os.path.join(str(parent_dir), f"{utcnow.year:04d}-{utcnow.month:02d}-{utcnow.day:02d}_{dlkeys.name:s}")
                if no_rename:
                    newname = os.path.join(str(parent_dir), str(dlkeys.name))
                print(f"\t... renaming to: {newname:s}")
                try:
                    dlkeys.rename(newname)
                except FileNotFoundError as exc:
                    print(str(exc), file=sys.stderr)
            print("Quitting marionette browser", file=sys.stderr)
            driver.quit()


def save_screenshot(driver, basename):
    """\
    Saves a screenshot of the current driver in the same directory as this script
    """
    now = datetime.utcnow().isoformat().replace(":", "-")
    parent_dir = Path(__file__).resolve().parent
    filename = parent_dir / Path(f"{now}_{basename}.png")
    driver.save_screenshot(str(filename))


def do_step(driver, stepname, clickable, send=None, assert_urls=(), wait_duration=10, hidden_send=False):
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
    start_time = timer()
    try:
        print(f"[>STEP] {stepname} {wait_duration}s timeout", file=sys.stderr)
        elem = WebDriverWait(driver, wait_duration).until(EC.element_to_be_clickable(clickable))
        assert not assert_urls or driver.current_url.startswith(assert_urls), f"ERROR: [{stepname}], ended up at: {driver.current_url} instead of {assert_urls}"
        # print(f"{elem=}", file=sys.stderr)
        # print(f"{dir(elem)=}", file=sys.stderr)
        if send is not None:
            if send is True:
                print(f"[STEP>] {stepname} -> clicking", file=sys.stderr)
                elem.click()
            else:
                print(f"[STEP>] {stepname} -> sending key: '{send}'", file=sys.stderr)
                elem.send_keys(send)
        end_time = timer()
        print(f"[STEP!] {stepname} (took {end_time - start_time:02.3f}s)", file=sys.stderr)
    except AssertionError:
        print(f"Title: {driver.title}", file=sys.stderr)
        print(f"URL: {driver.current_url}", file=sys.stderr)
        save_screenshot(driver, "failure")
        raise


# https://blog.mozilla.org/accessibility/
# https://developer.mozilla.org/en-US/docs/Learn/Accessibility/WAI-ARIA_basics

ELEM_EXPORTBTN = (
    By.XPATH,
    "//button[@aria-expanded='false' and @aria-haspopup='true' and contains(@class, 'ms-Button') and .//span[text()='Export all keys']]",
)
ELEM_FROMACTIVESUBSBTN = (
    By.XPATH,
    "//button[@role='menuitem' and .//span[text()='From active subscriptions']]",
)
ELEM_LOGIN_USERFIELD = (
    By.XPATH,
    "//input[@type='email' and @name='loginfmt' and @aria-required='true']",
)
ELEM_LOGIN_NEXTBTN = (
    By.XPATH,
    f"{ELEM_LOGIN_USERFIELD[1]}/../../../..//input[@type='submit' and @value='Next']",
)
ELEM_LOGIN_PASSWORDFIELD = (
    By.XPATH,
    "//input[@type='password' and @name='passwd' and @aria-required='true']",
)
ELEM_LOGIN_SIGNINBTN = (
    By.XPATH,
    f"{ELEM_LOGIN_PASSWORDFIELD[1]}/../../../..//input[@type='submit' and @value='Sign in']",
)
ELEM_LOGIN_YESBTN = (
    By.XPATH,
    "//input[@type='submit' and @value='Yes']",
)


def get_exported_keys_xml(driver, assert_urls):
    """\
    This function attempts to export the keys from active subscriptions, by
    initiating a download of the XML file.

    TODO/FIXME:
    * create temporary directory inside download base directory
    Work in progress!!!
    """
    do_step(driver, "waiting for 'Product Keys' page to be loaded", ELEM_EXPORTBTN, assert_urls=assert_urls, wait_duration=30)
    do_step(driver, "clicking 'Export all keys' button", ELEM_EXPORTBTN, send=True, assert_urls=assert_urls)
    with suppress(TimeoutException):  # just to be on the safe side ...
        do_step(driver, "waiting for 'From active subscriptions' to become available for click", ELEM_FROMACTIVESUBSBTN, assert_urls=assert_urls)
    do_step(driver, "clicking 'From active subscriptions'", ELEM_FROMACTIVESUBSBTN, send=True, assert_urls=assert_urls, wait_duration=120)
    do_step(driver, "waiting for 'Product Keys' page to be accessible again after downloading XML", ELEM_EXPORTBTN, assert_urls=assert_urls, wait_duration=120)


def enter_password(driver, assert_urls, PASSWORD):
    """\
    Just entering the password and potentially clicking that 'Stay signed in?' button for 'Yes'
    """
    elem = None
    with suppress(NoSuchElementException, TimeoutException):
        elem = driver.find_element(*ELEM_LOGIN_PASSWORDFIELD)
    if not elem:
        return
    do_step(driver, "entering password", ELEM_LOGIN_PASSWORDFIELD, send=PASSWORD, assert_urls=assert_urls, hidden_send=True)
    do_step(driver, "clicking 'Sign in' button after entering password", ELEM_LOGIN_SIGNINBTN, send=True, assert_urls=assert_urls)
    with suppress(TimeoutException):  # may never happen
        do_step(driver, "clicking 'Yes' button (for 'Stay signed in?')", ELEM_LOGIN_YESBTN, send=True, assert_urls=assert_urls)


def sign_in(driver, assert_urls, EMAIL, PASSWORD):
    """\
    This function signs into my.visualstudio.com by sending a "username" and password
    """
    elem = None
    with suppress(NoSuchElementException, TimeoutException):
        elem = driver.find_element(*ELEM_LOGIN_USERFIELD) or driver.find_element(*ELEM_LOGIN_PASSWORDFIELD)
    if not elem:
        return
    do_step(driver, "entering email", ELEM_LOGIN_USERFIELD, send=EMAIL, assert_urls=assert_urls)
    do_step(driver, "clicking 'Next' after entering email", ELEM_LOGIN_NEXTBTN, send=True, assert_urls=assert_urls)
    enter_password(driver, assert_urls, PASSWORD)


def scroll_page(driver, delay=0.2):
    """\
    Scroll down the height of a visible page
    """
    sleep(delay)
    driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
    return driver.execute_script("return document.body.scrollHeight")


def scroll_to_claim_key(driver, assert_urls, EMAIL, PASSWORD):
    # fluent wait? (Selenium)
    # expected conditions
    sign_in(driver, (), EMAIL, PASSWORD)
    with suppress(TimeoutException):  # may never happen
        do_step(driver, "waiting for 'Product Keys' page to be loaded", ELEM_EXPORTBTN, assert_urls=assert_urls, wait_duration=10)
    sign_in(driver, (), EMAIL, PASSWORD)
    last_height = driver.execute_script("return document.body.scrollHeight")
    while True:
        print(f"{last_height=}", file=sys.stderr)
        new_height = scroll_page(driver)
        elems = driver.find_elements(By.XPATH, "//button[contains(@class, 'ProductKeysList__AccessibleGridLink-') and ../span[contains(text(), 'remaining')]]")
        if elems:
            print(f"We found {len(elems)=} elements", file=sys.stderr)
            for elem in elems.items():
                print(f"{elem}", file=sys.stderr)
        if new_height == last_height:
            print(f"Reached the bottom of the page at {new_height}px", file=sys.stderr)
            break
        print(f"Scrolled {new_height - last_height}px down", file=sys.stderr)
        last_height = new_height
    # div[@class='ms-List']/div[@class='ms-List-surface']/div[@class='ms-List-page']
    # -> div[@class='ms-List-page' and @role='presentation'] <- actual loaded keys
    # -> <div role="presentation" class="ms-List-cell" data-list-index="30" data-automationid="ListCell" />
    # <span><button type="button" class="ms-Link ProductKeysList__AccessibleGridLink-sc-9hotbz-1 iPQlRw root-218" tabindex="0">Claim Key</button>
    # ...<span> 5 remaining</span></span>

    # $x("//button[contains(@class, 'ProductKeysList__AccessibleGridLink-') and ../span[contains(text(), 'remaining')]]")
    # driver.execute_script("window.scrollTo(0, Y)")
    # driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
    # # Scroll down to bottom
    #    driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
    # driver.find_element(By.XPATH, ...)
    # driver.execute_script("document.getElementById('your ID Element').scrollIntoView();")


def get_keys(cmdline, url_prodkey, url_login, url_export, EMAIL, PASSWORD, *args, **kwargs):
    """\
    This is the central function which uses the webdriver instance to claim remaining
    keys.
    """
    assert all(isinstance(x, tuple) for x in {url_prodkey, url_login, url_export}), "Expected tuples"
    assert all(isinstance(x, str) and x for x in {EMAIL, PASSWORD}), "Expected non-empty strings"
    url = url_prodkey[0]

    headless = not cmdline.get("show_browser", False)
    profile_dir = cmdline.get("profile", None)
    no_rename = cmdline.get("no_rename", False)

    print(f"Visiting: {url}")
    with firefox_driver(headless, profile_dir, no_rename) as driver:
        driver.get(url)

        # Common steps to log in, unless requested that we don't log in (e.g. when reusing a profile that is logged in already)
        if not cmdline.get("no_auth", False):
            sign_in(driver, url_login, EMAIL, PASSWORD)

        # Only downloading without attempting to request unclaimed keys?
        if cmdline.get("download_only", False):
            get_exported_keys_xml(driver, url_prodkey)
            return

        scroll_to_claim_key(driver, url_prodkey, EMAIL, PASSWORD)
        return

        suppress_claim = kwargs.get("suppression_claim", set())
        # Merely report a count of potentially eligible links
        claims = driver.find_elements(By.CSS_SELECTOR, "a.claim-key-link")
        if len(suppress_claim):
            claims = [x for x in claims if not any(needle in x.get_attribute("aria-label") for needle in suppress_claim)]
        num_claims = len(claims)
        print(f"\t{num_claims} links with 'Claim Key', excluding suppressed", file=sys.stderr)
        if not num_claims:
            print("\tNothing to do!", file=sys.stderr)
            return

        for claim in claims:
            print(claim.get_attribute("aria-label"))
        driver.implicitly_wait(10)

        while True:
            # TODO/FIXME: this should once again use the filtering from above and skip elements that match suppressions
            claim = WebDriverWait(driver, 120).until(EC.presence_of_element_located((By.CSS_SELECTOR, "a.claim-key-link")))
            print("[STEP] Clicking: '{}'".format(claim.get_attribute("aria-label")), file=sys.stderr)
            claim.click()
            print("\t... waiting after click", file=sys.stderr)
            try:
                WebDriverWait(driver, 15).until(EC.element_to_be_clickable((By.XPATH, ...)))
            except (TimeoutException, StaleElementReferenceException) as e:
                print("\t... looks like the daily limit was reached", file=sys.stderr)
                WebDriverWait(driver, 10).until(EC.presence_of_element_located((By.CLASS_NAME, "errormessage")))
                WebDriverWait(driver, 10).until(EC.presence_of_element_located((By.CSS_SELECTOR, "h2.title")))
                download_keys = driver.current_url == "https://my.visualstudio.com/Errors?e=46"
                if download_keys:
                    print("\t... yep, it's about the daily limit", file=sys.stderr)
                print(f"[{driver.current_url}] {driver.title}", file=sys.stderr)
                print(str(e), file=sys.stderr)
                if download_keys:
                    print("\t... let's try to download the XML with the keys", file=sys.stderr)
                    driver.get(url)
                    get_exported_keys_xml(driver, url_prodkey)
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
    expecting = {"URLs"}
    assert all(x in cfg.sections() for x in expecting), "Missing sections in the read configuration. Expecting at least sections: {}".format(
        ", ".join(expecting)
    )
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
            elif section in {"suppressions"}:
                options["{}_{}".format(section.lower()[:-1], key)] = set(x.strip() for x in value.split("\n"))
    cred = ConfigParser()
    cred_path = get_config_basepath(".credentials")
    cred.read(cred_path)
    assert cred.has_section("secrets"), "Need to have a [secrets] section in the .credentials file!"
    expecting = {"password", "email"}
    assert all(cred.has_option("secrets", x) for x in expecting), "Expected to find a 'password' and 'email' option in the [secrets] section."
    for option in expecting:
        options[option.upper()] = cred.get("secrets", option)
    return cfg, options


def parse_args():
    from argparse import ArgumentParser

    parser = ArgumentParser(description="This script attempts to claim keys from the my.visualstudio.com portal and downloads the KeysExport.xml")
    parser.add_argument("-A", "--no-auth", action="store_true", help="Assume the user is already authenticated (best used with -p).")
    parser.add_argument(
        "-c",
        "--write-credentials",
        action="store_true",
        help="Writes a .credential with default values next to the script for customization,"
        "_unless_ such a file already exists (i.e. it won't overwrite anything!).",
    )
    parser.add_argument(
        "-d",
        "--download-only",
        "--download",
        action="store_true",
        help="This will instruct the script not to attempt to claim keys, but rather download KeysExport.xml"
        "_unless_ such a file already exists (i.e. it won't overwrite anything!).",
    )
    parser.add_argument(
        "-i",
        "--write-ini",
        action="store_true",
        help="Writes an .ini with default values next to the script for customization,"
        "_unless_ such a file already exists (i.e. it won't overwrite anything!).",
    )
    parser.add_argument("-R", "--no-rename", action="store_true", help="Will skip renaming the KeysExport.xml to YYYY-MM-DD_KeysExport.xml")
    parser.add_argument(
        "-s",
        "--show-browser",
        action="store_true",
        help="Will show the browser window of the marionette geckodriver. The effect of this is _not_ to pass '--headless' to geckodriver.",
    )
    parser.add_argument("-p", "--profile", action="store", help="Allows to set the browser profile path to use (WORK IN PROGRESS).")
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

# Little helpers for Visual Studio subscriptions

> Prerequisites: Python 3.10 (probably earlier 3.x will also work, but I didn't test below 3.7), the Python `selenium` package and a `geckodriver`.

This directory contains two little scripts. One of them I have maintained for a little over a decade by now, although it got first published in 2017. The other is fairly new.

## Preparation

The easiest way to make use of the scripts is to use a Bash-compatible shell, have a 

## `combine-msdn-keys.py`

> Script-specific prerequisites: `7z` (CLI), `python` (3.x, initially tested with 3.7 through 3.10), `tar`, `xz`,  and optionally GNU make

Will help you to create a file (I prefer the name `allkeys.txt`) which will contain a listing of the product keys from subscriptions. It understands some of the older XML export formats, too; up to the current format.

If you're on Linux or otherwise have GNU make at your disposal, you can do the following for ease of use:

1. drop your `.xml` files (`KeysExport.xml`) into a subfolder (I use `keys` and that's what the accompanying `GNUmakefile` expects)
1. run `make rebuild` (or if you're not on GNU/Linux use whatever name GNU make can be found under, such as `gmake`)  
   The first time around you can also simply use `make`
1. Enjoy.

The outcome should be a `.tar.xz` and a `.7z` file along with their `.SHA256SUM` files, respectively. Additionally you should see `allkeys.txt` (and `allkeys.txt.bak` if you ran `make rebuild` and it existed before) and a file `SHA256SUMS` containing the hashes of all the files inside the `keys` subfolder.

## `get-msdn-keys.py`

This script uses Selenium, geckodriver (Firefox) and some logic to claim unclaimed keys from the "Product Keys" page on my.visualstudio.com.

Its logic can deal with reaching the daily limit for claiming keys (it's somewhere below 10 as of November 2021, but it varies sometimes). After claiming the keys it will attempt to download the `KeysExport.xml`.

> NOTE: This is work-in-progress as far as the download capability is concerned. The keys will end up in a file right next to this script and Firefox will automatically name a new file `KeysExport(1).xml` if the `KeysExport.xml` exists already (and so forth). I plan to change this, so that the file gets prefixed with the date (YYYY-MM-DD).

### Preparation

To get started quickly you really only need a `.credentials` file. This file lives alongside the Python script and instead of a `.py` extension carries a `.credentials` extension.

**NOTE:** A pre-existing `.credentials` file will _not_ be overwritten.

You can easily create a file like that by passing `--write-credentials` or `-c` to the script. I.e.:

```
get-msdn-keys.py --write-credentials
```

> NB: Called like this, the script will not perform its usual function but instead quit either with an error message or success, but with a zero exit code in either case.

Similar rules exist for the configuration file which is called `.ini` and the respective command line switches are `--write-ini` and `-i`. _Unless_ the subscription portal changes elements, there's no need to make use of this feature, though. It simply exists so the script may continue to work without changes, even though the portal introduces minor changes.

### Usage

At this point in time, aside from the two switches mentioned in the Preparation section, the following two switches may be useful:

* `-s`, `--show-browser` will show the (marionette) browser instance while Selenium and this script do their magic.
* `-d`, `--download-only` will skip claiming product keys and merely attempt to export them to the XML file (`KeysExport.xml`).

### Syntax

```
usage: get-msdn-keys.py [-h] [-c] [-d] [-i] [-R] [-s]

This script attempts to claim keys from the my.visualstudio.com portal and
downloads the KeysExport.xml

options:
  -h, --help            show this help message and exit
  -c, --write-credentials
                        Writes a .credential with default values next to the
                        script for customization,_unless_ such a file already
                        exists (i.e. it won't overwrite anything!).
  -d, --download-only, --download
                        This will instruct the script not to attempt to claim
                        keys, but rather download KeysExport.xml_unless_ such
                        a file already exists (i.e. it won't overwrite
                        anything!).
  -i, --write-ini       Writes an .ini with default values next to the script
                        for customization,_unless_ such a file already exists
                        (i.e. it won't overwrite anything!).
  -R, --no-rename       Will skip renaming the KeysExport.xml to YYYY-MM-
                        DD_KeysExport.xml
  -s, --show-browser    Will show the browser window of the marionette
                        geckodriver. The effect of this is _not_ to pass '--
                        headless' to geckodriver.
```

### Security note

For obvious reasons you should store the `.credentials` file in a secure place, such as an encrypted container. Currently this means the script also needs to go there.

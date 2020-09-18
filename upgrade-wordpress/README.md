# Scripts to help automate the WordPress upgrade

WordPress already has an upgrade/update mechanism, I hear you say. And yes, you're right.

_If_ you're inclined to:

1. open an FTP/FTPS server on your host
2. store the credentials to it in your WordPress installation
3. make the webroot of your WordPress installation writable

... _then_, yes, then you can enjoy automated updates. The thing is, you can also enjoy automated takeover of your site by malicious parties if any of the plugins you're using happens to be vulnerable.

Personally I don't like the prospect and moreover I don't like the idea of giving access unless _absolutely_ necessary. I follow IT news and so the availability of new WordPress versions quickly has my attention. So instead of making all sorts of web folders writable to the web server _or_ world, I keep them relatively tightly locked down and thereby gain a fair bit of extra security.

This folder contains two main scripts:

* `update-blog.sh`
* `update-wp-plugins.sh` (if symlinked to the name `update-wp-themes.sh` it will also act on themes)

## Prerequisites and/or limitations

Currently there are a few prerequisites and/or limitations you need to be aware of:

* `sudo` access is required for `chown` and `chmod`. I may actually at some point factor this out into some other script which gets sourced or something similar. But right now, that's needed.
* Perl, `mysqldump`, the GNU flavor of `find` and some other tools checked for on line 4 are also required - that is: the script will barf and tell you which tool is missing.
* Only the `.tar.gz` is supported at the moment, not the `.zip`.
* The group for the web server is assumed to be `www-data`.
* The only real check if you let the script download the `latest.tar.gz` is for the hash. Unfortunately the folks at WordPress don't offer PGP-signed hashes or tarballs. That means if you misconfigure your system you may end up falling prey to a MitM-attack. But again, this sort of implies that you are already reckless in the first place. Should the WordPress folks ever add real signatures, I will update this script to check for those instead.
* Since I am not using `builtin` or `command` to be explicit about what I am calling, you _could_ potentially override stuff from the script by defining a function named after a command (think `wget`). It is your responsibility to take care that this isn't a problem.
* While I am using this on some WordPress instances that have quite different configurations, the script may not be generic enough for your use case. So read, understand and edit it, if needed. Don't just execute it.

## `update-blog.sh`

This is the script to update to a newer WordPress version. It will attempt to find `wp-login.php` in a subfolder of the folder where the script is located. This will be used as the base folder for the blog to be updated. The script is _not_ prepared to handle multiple matches, just one (this can certainly be fixed, you have the source, go right ahead!).

There are several ways this script can be called:

1. `./update-blog.sh` -- i.e. without any arguments.  
   Once found, the script will assume it has to download the `latest.tar.gz` (yes, it defaults to US-English) and download _that_ as well as the accompanying `.sha1` file. The hash of the downloaded `.tar.gz` is then compared to the known hash and, provided this worked out, the upgrade process commences as if you had started it with an already downloaded `.tar.gz` (see 2). NB: the host for the download is limited to wordpress.org and de.wordpress.org at this moment and hardcoded to using `https://` ...
2. `./update-blog.sh /path/to/wordpress.tar.gz` -- will use the given path to a local file but not perform any hash checks on said file. It is assumed the file was vetted upfront.  
   The script will:
   * Look for `wp-config.php` either in the base folder of the blog or one folder up (which is more secure anyway)
   * Employ `perl` to parse the `wp-config.php` into a shell snippet that can be eval'd by Bash in order to get the credentials to the blog database
   * Extract the current WordPress version from `wp-includes/version.php` and make it available as variable `wp_version`
   * Take the current time (roughly ISO format)
   * Check if the argument to the script was `--backup` or `-b` (see 3 below)
   * Build a file name for the (full<sup>1</sup>) backup of the blog (database and all!)
   * Commence backup
      * Use `mysqldump` to back up the whole blog database (see <sup>1</sup>), the blog base folder and `wp-config.php` (which may be situated outside the blog base folder) into a tarball
      * Follow the recommendations for a manual WordPress update (e.g. remove `wp-includes` and `wp-admin`)
      * Unpack the tarball with the new WordPress version in-place
      * Check if there's a file named `.update-blog.post-overwrite` next to it and source that (think of it as a "hook" for you to customize the process)  
        NB: I use this to remove themes I don't use or crud that WordPress drops by default, which I don't need
      * Run via `sudo` both `chmod` and `chown` to set permissions and ownership
      * Check if there's a file named `.update-blog.post-permission-fix` next to it and source that (think of it as a "hook" for you to customize the process)
      * Remove the DB backup (i.e. the plain SQL file ... you will still have the compressed tarball with everything)

**NB:** Please beware that the if anything goes wrong from the point where `wp-includes` and `wp-admin` get removed (see above), your blog could end up in a failed state. However, recovery is as easy as unpacking the tarball with the full backup. I did not want to automate such an exceptional case, I'd rather retain full control in such situations.

<sup>1</sup> Full is actually a little lie. Comments marked as trash or spam, including those automatically marked this way (e.g. by Akismet) will _not_ be backed up.

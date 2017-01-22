(**Caution:** This is a very old document (like 2003-era old) and hasn't necessarily been updated for all changes to AutoFox since then. It was also quickly converted from HTML to Markdown, so conversion errors may have creeped in.)

# AutoFox 2.0 Manual.

## Where to put AutoFox &amp; the Configuration File.

As of version 2.0, AutoFox can be put wherever you like. Give it the name of the configuration file as an argument (e.g. `autofox mycomic.cfg`). This makes it easy to set it up system-wide and have everyone maintain their own configurations if desired.

If no name is given, AutoFox will check for `autofox.cfg` in the current directory. This retains backward compatibility with AutoFox 1.x (not that much else is compatible).

## Setup and Configuration.

_I'll be referring to the configuration file as `autofox.cfg` throughout for simplicity._

The syntax of `autofox.cfg` is simple. Lines that start with '#' are comments and ignored by AutoFox. Everything else is a name-value pair separated by '='. Whitespace is irrelevant except that an individual name-value pair must currently reside on one line by itself. Otherwise the '=' may be surrounded by spaces or tabs to your heart's content.

### When to Update

#### updatetime

`updatetime` specifies, of course, what time to update. We do this despite the fact that the script will be run by an external scheduling agent because if the script doesn't know what time to update, and you need to run the script manually for any reason, it won't have a clue whether it's supposed to put the next strip up yet it's due today.

`updatetime` is in the infinitely saner 24-hour format. So, for example, an update time of 11pm would be '2300'. 9am would be 0900.

Being a strong believer in letting the user do it however they want when possible, I made the actual syntax very loose. Unfortunately, this also means it can't really do any error checking. The only requirement is that there be two pairs of digits. This means that, for example, '2300' could be any of '2300', '23:00', '23.00', '23mydoghasfleas00', ':t:h:e:r:e:23:i:s:00:n:o:s:p:o:o:n:'. I strongly recommend you stick to one of the first three examples.

#### updateday

`updateday` is... a little weird. If you're updating before midnight server time, you'll need to set `updateday` to `previous` (e.g. if you want comics to appear at 2100 the night prior to the date the comic is assigned). Otherwise set it to `same`.

* Example 1: `updateday` set to previous, `updatetime` set to 2300, current time is 2300, date is January 2nd 2004, next strip is dated January 3rd, 2004, AutoFox is run. AF will put up January 3rd's strip.

* Example 2: `updateday` set to same, rest as above. AutoFox will NOT put up January 3rd's strip.

* Example 3: `updateday` set to same, current date is January 3rd, 2004, rest as above. AutoFox will put January 3rd's strip in place.

Remember: this is operating on the ***SERVER's*** time, so you need to make sure to account for any timezone differences.

### URL

Set `url` as appropriate (e.g. `https://www.example.com/`).

### Base Directory

The "base" directory for AutoFox is specified by the `basedir` value. This should usually just be set to your home directory (e.g. `/home/username/`). `workdir` and `sitedir` (both explained below) are relative to this directory.

### Workspace

The **Workspace** is where most of the files AutoFox needs to work with reside. By default, AutoFox tries to find the workspace in a directory called "workspace" under your base directory. You can change this name to whatever you want by changing the `workdir` value.

You'll need to create and populate three directories under the workspace:

#### comics

All your daily comic files (e.g. `yc20040103.png`, `yc20040103.html`, etc.) go here.

#### pages

Your site basically goes here. Any HTML files (*.html/*.htm) under this directory are automatically parsed before being copied to the site directory.

##### Things to note about `pages`

*   You can create an entire, multi-level directory tree under `pages`. AutoFox will traverse it in its entirety, replicating it under the site directory.
*   Your index template should go here and be named index.html. This a divergence from AutoKeen behaviour brought on by my desire to dispense with the useless conceptual separation between the index template and every other non-archival template file.

#### data

At present, the sole purpose of this directory is to store the `storyline.txt` and `daytemplate.html` files. Its use may be expanded in the future.

### A note about templates

Originally, AutoFox needed three specific templates: Index, Archive, and Daily. This has changed. The only template AutoFox demands separately is the Daily, which it expects to find under the `data` directory mentioned above. By default it looks for `dailytemplate.html`. You can change the name by setting `dailytemplate` in `autofox.cfg` to whatever name you want.

All other templates should go under the `pages` directory. Everything there gets parsed as if it were the index file (e.g. if it finds `***todays_comics***` in one, it'll replace it with _today's_ comics). Just put your index file in here named as your system requires (usually `index.html`).

### The Site Directory

This is the directory under which everything ends up after AutoFox is run. It should be the same directory that stuff under whatever you set `url` to is pulled from when someone goes to your site. For most people, this'll just be `public_html`.

Under this directory, you'll need to manually create three directories, `comics`, `d`, and `images`. `comics` is where AutoFox will put the comics themselves (and any associated HTML files for the day), and `d` is where AutoFox will place the daily archive pages it generates.

In `images`, place your navigation buttons (if any) for the `first_day`, `last_day`, `next_day`, `previous_day`, and `storylinestart` tags.

**NOTE:** The names of these images can be set by modifying the appropriate values in `autofox.cfg`. By default, if no names are set, AutoFox searches the `images` directory for the appropriate images, preferring PNGs, but if it can't find a PNG, it'll try to use any file it finds with an appropriate name with any extension (yes, this means it'll even try to use HTML files as images if you have, for example, a file called `first_day.html` in the images directory; yes, this is a sort-of bug, and the fix isn't clear-cut).

Here's a list of the values holding the filenames for the buttons and their corresponding tags. Note that the value names are also the filenames that AutoFox defaults to searching for if no name is explicitly specified.

<dl>

<dt>first_day</dt>

<dd>first_day</dd>

<dt>last_day</dt>

<dd>last_day</dd>

<dt>next_day</dt>

<dd>next_day</dd>

<dt>previous_day</dt>

<dd>previous_day</dd>

<dt>storystart</dt>

<dd>storylinestart</dd>

</dl>

If AutoFox can't locate button images, it'll just generate appropriate text links.

## Permissions.

In AutoFox 1.x, permissions on files and directories were of a high degree of concern due to the poor overall design. In AutoFox 2.0, this is much less of a concern. Make the workspace directory readable, writable, and executable only by yourself, and you're set. If you're uncertain how to do this, consult your system's documentation or administrator. On most Unix-ish systems, this should do the trick (replace `workspace` with whatever you named your workspace directory):

<pre>chmod og-rwx workspace
chmod u+rwx workspace
</pre>

## Storyline "Go!" button.

There is an unfortunate design oversight in the HTML standards. The dropbox format is excellent for uses such as those it's put to on webcomic sites, but its functionality must be handled by a separate script or scripts; it can't simply be used as a link mechanism, which would be extremely convenient for our purposes.

There are two ways that this may be done. KeenS* has used both in its history, and currently uses the most compatible one, which is a server-side script that takes the selection as input and redirects to the appropriate URL.

The other method is to use Javascript, which runs on the client (browser) to effect the redirection. This method is simpler to setup, but depends on a browser having Javascript capability. Most graphical browsers in use do have Javascript support, but some do not, and some users of browsers that do have Javascript support turn it off as a security measure, a usability measure, or both.

In the interest of compatibility, I include with AutoFox the ridiculously simple but completely sufficient script `ddredirect.pl`. Where exactly you put this is something you'll need to find out from your webhost. Generally it will go in a certain directory called something like `cgi-bin`. Depending on the host, you might need to do some special setup to get it working, or you might just be able to drop it in a directory, make it executable (`chmod u+x ddredirect.pl`), set the proper URL in `autofox.cfg` (variable name is `ddredirect`), and go. Consult your sysadmin. If you ARE the sysadmin, find someone that knows your OS and webserver ([I](http://runawaynet.com/~nknight/) know Unix and Apache 2.x).

## Automatic updating

You COULD simply run AutoFox manually every time you update, but this takes away part of the point of an automation system, and kinda puts a crimper on updates while you're vacationing or otherwise lacking in access to a computer with a 'net connection. Instead, it is strongly recommended you set AutoFox to run automatically every night.

Because different systems may have different scheduling mechanisms, a complete explanation of how to set one up is outside the scope of this document. A quick explanation for using `cron`, available on most Unix-ish systems, follows.

### AutoFox scheduling with cron

<pre>crontab -e
</pre>

This will bring up an editor with your crontab open and ready for editing. You'll need to insert a line like this:

<pre>00 23 * * * autofox /path/to/config/file
</pre>

The two numbers at the start (00 and 23) are the minute and hour (in that order) for cron to run the script. Set it to whatever time you set `updatetime` to in `autofox.cfg`.

`autofox` is the name of the AutoFox script itself. You'll want to change this to whatever is appropriate for your system. If AutoFox has been installed system-wide, just 'autofox' is probably fine. If it's instead in your home directory, you'll want to change it to something like `/home/username/autofox`.

You'll also probably want to change `/path/to/config/file` to the actual path to the config file. :)

## Tags

Tags are handled exactly as on KeenSp(ot|ace) in the format `***tagname***`, and the supported tags work in largely identical fashions to their KS counterparts.

### Supported tags

The following tags are supported. Most work exactly the same as on KS with only minor cosmetic differences at most. Significant differences are noted later.

*   todays_date
*   todays_comics
*   previous_day
*   next_day
*   first_day
*   last_day
*   the_year
*   day_of_the_month
*   month_of_the_year
*   short_month
*   day_of_the_week
*   daily_archive
*   url
*   calendar
*   big_calendar
*   home
*   storyline
*   storylinestart
*   include
*   includenoparse

### Tag differences

#### include and includenoparse

AutoFox uses an extended version of `include` that parses tags in the included files. This also allows nested includes (AutoFox checks to make sure it doesn't get caught in a loop).

Because this behaviour _might_ not always be desirable, `includenoparse` was added, which works exactly like `include`, but doesn't parse tags in the included files.

##### Including multiple files

AutoKeen documentation is often incomplete and difficult to come by. Near as we've been able to piece together, The KeenSpace version of AutoKeen has been intentionally crippled to disallow including of more than one file per template (though that same file can be included multiple times), whereas other versions (KeenSpot and KeenPrime) support including however many files you want however many times you want. AutoFox does, too.

## Storylines

### Setup

By default, the storyline code works identically to AutoKeen. The `storyline.txt` file (which you can rename in `autofox.cfg` by setting the `storyfile` variable) goes under the `data` directory in the workspace.

### Alternate mode

There's an alternate mode that I personally consider more sane, which actually uses the date in the date field rather than just checking that the date field is not blank. You can enable it by setting `storyline_use_date` to `1`.

Note that when using this mode, AutoFox still makes efforts to ensure that storylines are pre-selected properly even if they don't have a date field. It does this by attempting to extract the date from the path as in the default/original mode.

#### Format of the date field in alternate mode

The date field can currently be either in YYYYMMDD format, or MM/DD/YYYY format. My bias (and an interest in consistency throughout AutoFox) forces me to strongly recommend YYYYMMDD rather than the abomination of a date format we Americans have tainted the world with.

### History

Storyline support was a pain. I (Tegeran) tried it myself from scratch three times. It kicked my ass each time. The third time so severely that I just stopped coding for a month.

Finally, after a week of working on it, Nicholas "CaptainSpam" Killewald was able to get it working. It's basically all his code, with only some magic from me to help make sure the right storyline was pre-selected if you're using the AutoKeen-incompatible mode.

I mention all this to make sure you appreciate this feature and give plenty of credit to Spam. It was absolutely THE most difficult part of AutoFox, orders of magnitude worse than `calendar`, and will probably retain that distinction for eternity.

Now, you WILL be using the storyline feature, RIGHT? :P
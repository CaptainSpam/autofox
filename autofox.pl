#!/usr/bin/perl

# AutoFox 2.5

# Copyright (c) 2003-2008 Nicholas "Tegeran" Knight <nknight@runawaynet.com>
# Copyright (c) 2003-2018 Nicholas "CaptainSpam" Killewald <captainspam@exclaimindustries.net>
# See "LICENSE" file at the toplevel for your daily dose of 3-clause BSD.

# This is 2000-ish lines of semi-(readable|maintainable) Perl. It ain't pretty,
# but by some miracle it works, and it's surprisingly fast.

# It might be possible to clean AutoFox up quite a bit by using more of the
# standard modules. Unfortunately my familiarity with things outside the core
# language is quite limited, and I also harbour a fear that the surprisingly
# good performance seen in AF may be adversely affected.

use strict;
use warnings;
use File::Copy;
use POSIX;
#use local::lib;
use Switch;

my $afversion = "AutoFox 2.5.4-css";

#=======================================================================
# Why am I counting from 1? Because it simplifies things when dealing
# with user-supplied dates (which is about all AutoFox does) and saves
# many an addition operation (yeah, I know, I'm not supposed to try and
# optimize Perl code like that ;)). -Teg

my @mnames = ("Error", "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December");

my @mshortnames = ("Error", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul",
    "Aug", "Sep", "Oct", "Nov", "Dec");

my @dnames = ("Error", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday",
    "Friday", "Saturday");

my @dshortnames = ("Error", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat");

#=======================================================================
# Read in the config file in a totally unsafe and error-prone way. -Teg

my %conf = (
    url                     =>      "about:blank",
    updatetime              =>      2300,
    updateday               =>      "same",
    timezone                =>      strftime("%z",localtime),
    captionold              =>      1,
    captionsfile            =>      "captions.txt",
    comicsdir               =>      "comics/",
    imagedir                =>      "images/",
    dailydir                =>      "d/",
    uploaddir               =>      "comics/",
    sitedir                 =>      "public_html/",
    workdir                 =>      "workspace/",
    parsedir                =>      "pages/",
    datadir                 =>      "data/",
    storyfile               =>      "storyline.txt",
    logfile                 =>      "autofox.log",
    indexfile               =>      "index.html",
    storylinebanners        =>      "storylinebanners.txt",
    dailyext                =>      ".html",
    use_css_navbuttons      =>      0,
    last_day                =>      "",
    first_day               =>      "",
    previous_day            =>      "",
    next_day                =>      "",
    last_day_ghosted        =>      "",
    first_day_ghosted       =>      "",
    previous_day_ghosted    =>      "",
    next_day_ghosted        =>      "",
    storystart              =>      "storystart.gif",
    dailytemplate           =>      "dailytemplate.html",
    js_prefix               =>      "af_",
    storyline_use_date      =>      0,
    storyline_use_javascript    =>      1,
# Plain is unused for now
    storyline_use_plain     =>      1,
    bigcalwidth             =>      3,
    ddredirect              =>      "",
    calbacka                =>      "#d0d0d0",
    calbackb                =>      "#b0b0b0",
    calhighlight            =>      "#ffffff",
    calnolink               =>      "#000000",
# The RSS options
# Base functionality
    rss_full_generate       =>      0,
    rss_full_filename       =>      "comicfeed.rdf",
    rss_lite_generate       =>      0,
    rss_lite_filename       =>      "comicfeedlite.rdf",
    rss_limit               =>      10,
# Customization
    rss_title               =>      "DEFAULT TITLE",
    rss_link                =>      "http://localhost/",
    rss_description         =>      "Edit this in autofox.cfg!",
    rss_copyright           =>      "Copyright sometime... by someone... doing something"
### I want RSS image support later, but not right now.
);

my $config = "autofox.cfg";

if (defined $ARGV[0]) {
    $config = $ARGV[0];
}

open CONFIG, $config or die "Exiting: Can't open configuration file '$config'. $!\n";

while (<CONFIG>) {
    chomp;
    next if /^#/; next if /^\s*$/;
    s/\s*$//;
    /(\S*)\s*=\s*(.*)/;
    $conf{$1} = $2;
}

close CONFIG;

open(LOGFILE, ">>$conf{logfile}") or print "Can't open '$conf{logfile}' for logging: $!\nNon-fatal, but you're about to get a bunch of warning messages from Perl and\nyou won't have a nice log to look at.\n";

my $calbacka = $conf{calbacka};
my $calbackb = $conf{calbackb};
my $calhighlight = $conf{calhighlight};
my $calnolink = $conf{calnolink};

# Now we horribly and dangerously abuse the properties of a hash.

# FIXME: did some quick'n'dirty stuff here 20031104. Needs cleaned up. -Teg

# 2004-01-03 (Spirit to land tonight!) Just noticed this FAQ entry:
# http://www.perldoc.com/perl5.8.0/pod/perlfaq4.html#How-do-I-process-an-entire-hash-
# Modified code accordingly. Methinks it's faster, not that it's likely to make
# a whole lot of difference... -Teg

while (my ($key, $val) = each %conf) {
    if ($key =~ /dir$/ and $val !~ /\/$/) {
        $conf{$key} .= "/"
    }
}

my $basedir = $conf{basedir};
my $sitedir = $conf{sitedir};
my $dailydir = $conf{dailydir};
my $imagedir = $conf{imagedir};
my $comicsdir = $conf{comicsdir};
my $workdir = $conf{workdir};
my $parsedir = $conf{parsedir};
my $datadir = $conf{datadir};
my $uploaddir = $conf{uploaddir};

my $rss_full_generate = $conf{rss_full_generate};
my $rss_full_filename = $conf{rss_full_filename};
my $rss_lite_generate = $conf{rss_lite_generate};
my $rss_lite_filename = $conf{rss_lite_filename};
my $rss_limit = $conf{rss_limit};
my $rss_title = $conf{rss_title};
my $rss_link = $conf{rss_link};
my $rss_description = $conf{rss_description};
my $rss_copyright = $conf{rss_copyright};

# basedir CAN be relative to the execution path.  You shouldn't do that, but
# you can if you so wish.  However, for path-assembling purposes, it must end
# with a forward slash.  We can attach that as need be.
print "basedir doesn't start with a slash; this isn't fatal, and it'll be relative to\nwherever you executed the script, but chances are you didn't want that.\n" unless $basedir =~ /^\//;
$basedir = "$basedir/" unless $basedir =~ /\/$/;

# Both sitedir and workdir CAN refer to absolute locations, if they start with a
# forward slash.  If not, they get basedir stapled onto the front of them.
foreach ($sitedir, $workdir) {
    $_ = "$basedir$_" unless /^\//;
    $_ = "$_/" unless /\/$/;
}

# All other dirs should also end in a slash.  Starting with a slash is
# irrelevant; they'll all go under their respective directories no matter what
# (unless, say, the user puts .. in the path to break out, but if that's the
# case, it's their own fault).
foreach ($dailydir, $imagedir, $comicsdir, $workdir, $parsedir, $datadir, $uploaddir) {
    $_ = "$_/" unless /\/$/;
}

while (my ($key, $val) = each %conf) {
    if ($key =~ /(?:_day$|^storystart$)/ and $val =~ /^$/) {
        foreach my $fn (<$sitedir$imagedir$key.*>) {
            $conf{$key} = "$fn";
            last if $fn =~ /\.png$/; # Favouristic fiat.
        }
    }
}

my $storyfile = $conf{storyfile};
my $dailytemplate = $conf{dailytemplate};
my $dailyext = $conf{dailyext};

my ($updatehour, $updatemin) =
    ($conf{updatetime} =~ /(\d\d).*(\d\d)/);

my $timezone = $conf{timezone};

my $updateday = $conf{updateday};

my $js_prefix = $conf{js_prefix};

my $storyline_use_date = $conf{storyline_use_date};
my $storyline_use_javascript = $conf{storyline_use_javascript};
### FIXME: This is currently ignored (if javascript is false,
### this is implied)!
my $storyline_use_plain = $conf{storyline_use_plain};

my $ddredirect = $conf{ddredirect};

my $use_css_navbuttons = $conf{use_css_navbuttons};

my $first_day = $conf{first_day};
my $last_day = $conf{last_day};
my $previous_day = $conf{previous_day};
my $next_day = $conf{next_day};

my $first_day_ghosted = $conf{first_day_ghosted};
my $last_day_ghosted = $conf{last_day_ghosted};
my $previous_day_ghosted = $conf{previous_day_ghosted};
my $next_day_ghosted = $conf{next_day_ghosted};

my $storystart = $conf{storystart};

my $captionsfile = $conf{captionsfile};

my $storylinebanners = $conf{storylinebanners};

my $url = $conf{url};
$url .= "/" unless($url =~ /\/$/);

my $bigcalwidth = $conf{bigcalwidth};

my $dir = "";

# Declares whether the Javascript headers have been called yet.
# This gets reset on EVERY new page, but since I don't think it's
# prudent to either keep passing it to each header-using function or
# have the parse function deal with it, it's global.
my $headers_placed = 0;

# Declares whether the Javascript story dropdown has been created
# yet.  The problem is that in order for the Javascript to work,
# the dropdown needs its own object name.  If the story dropdown
# is called twice, both will have the same name, causing conflicts
# in Javascript parsing that I'd rather not deal with.  This also
# applies to the full storyline dropdown, given it's patently stupid
# to put both on the same page.
# Like $headers_placed, it's global and is reset per-page.
my $js_story_placed = 0;

# How many includes deep we are.  In the case of zero, we're resetting the
# header data.  Declared up here because we need it now, I guess.
my $includecount = 0;

#=======================================================================
# Version string and startup log message. -Teg
#
# I moved the version string up to immediately after the use statements.
# -Spam


aflog("AutoFox $afversion running for $url...");

# Let's do some directory sanity checking first!
sub checkdirectoryexists($$) {
    my $varname = shift;
    my $dir = shift;
    (-d $dir) or affatal("$varname ($dir) isn't a directory!");
}

sub checkdirectoryread($$) {
    my $varname = shift;
    my $dir = shift;
    checkdirectoryexists($varname, $dir);
    (-r $dir) or affatal("$varname ($dir) isn't readable!");
}

sub checkdirectoryreadwrite($$) {
    my $varname = shift;
    my $dir = shift;
    checkdirectoryread($varname, $dir);
    (-w $dir) or affatal("$varname ($dir) isn't writeable!");
}
# basedir needs to be there and readable.  We attempt to chdir into it first
# thing, after all.
checkdirectoryread("basedir", $basedir);

# workdir doesn't really need to be readable on its own.  We directly look at
# the subdirs and shouldn't have reason to explicitly read from workdir.
checkdirectoryexists("workdir", $workdir);

# sitedir, however, DOES need to be explicitly writeable.  That's where we're
# going to dump the final products, after all.
checkdirectoryreadwrite("sitedir", $sitedir);

# uploaddir and comicsdir need to be writeable (the former to remove comics, the
# latter to add them in).
checkdirectoryreadwrite("comicsdir", $sitedir . $comicsdir);
checkdirectoryreadwrite("uploaddir", $workdir . $uploaddir);

# dailydir also needs to be writeable (that's where the archive is built up).
checkdirectoryreadwrite("dailydir", $sitedir . $dailydir);

# imagedir, parsedir, and datadir only need read access.  Those just contain
# image filenames (for URLs), templates (for building the site), and data files
# (for other parsing bits).
checkdirectoryread("imagedir", $sitedir . $imagedir);
checkdirectoryread("parsedir", $workdir . $parsedir);
checkdirectoryread("datadir", $workdir . $datadir);

aflog("Entering $basedir...");
chdir($basedir) or affatal("Couldn't chdir into $basedir: $!");

aflog("Using $sitedir as the site directory...");
aflog("Using $workdir as the workspace directory...");

#=======================================================================
# Time zone hackery.  Do you know how many time zones there are in the
# Soviet Union? -Spam

# The server's time zone.  Useful in the upcoming calculations with the user's
# inputted time zone.
my $servertimezone = strftime("%z",localtime);

# Time zone's formats are, in general, the +/-nnnn format.
# But, since I'm feeling nice, the initial number can be ignored in the case
# of less-than-10-hours-off.  As in, EST can be either -500 or -0500.
# If this turns out to be a bogus format, we default it to the server's time
# zone.
if($timezone =~ /^(\+|\-)/) {
    $timezone =~ /^(\+|\-)(\d\d\d\d|\d\d\d)/;
    my $temp = $1 . $2;
    # Basic sanity check
    if($temp < -1200 or $temp > 1200 or abs($temp) % 100 >= 60) {
        aflog("Config error: timezone is not valid (needs to be in the +/-XXXX hours format), reverting to system time zone...");
        $timezone = $servertimezone;
    }
    # If the format matches, then $timezone is set properly.  Done!
} else {
    aflog("Config error: timezone is not valid (needs to be in the +/-XXXX hours format), reverting to system time zone...");
    $timezone = $servertimezone;
}

#=======================================================================
# Moving stuff from $uploaddir to $comicsdir. -Teg
# Also creates $curdate.

my %strips;
my $curdate;

# Get the current date as per GMT, then convert it to whatever time zone the
# user may or may not have requested.  Yes, this depends on the server knowing
# what time zone it's in.  I hereby declare servers that do not know this as
# "braindead".
my $tzoffset;
{
    my $houroffset = (int ($timezone / 100)) * 3600;
    my $minuteoffset = (abs($timezone) % 100) * 60;
    if($timezone < 0) { $minuteoffset *= -1 };
    $tzoffset = $houroffset + $minuteoffset;
}

# Right here, we get $curdate set.  For the purposes of execution, $curdate
# will always be adjusted for the current time zone.
my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime(time + $tzoffset);
$mon++;
$year += 1900;
if ($conf{updateday} eq "previous") {
    if ($hour > $updatehour || ($hour == $updatehour && $min >= $updatemin)) {
        my $mmon = $mon+1;
        my $mmday = $mday+1;
        fdn($mon, $mmon, $mmday);
        if ($mday == getndays($year, $mon)) {
            $curdate = $year . $mmon . "01";
        } else {
            $curdate = $year . $mon . $mmday;
        }
    } else {
        fdn($mon, $mday);
        $curdate = $year . $mon . $mday;
    }
} elsif ($updateday eq "same") {
    my $mmday = $mday-1;
    fdn($mmday, $mon, $mday);
    if ($hour > $updatehour || ($hour == $updatehour && $min >= $updatemin)) {
        $curdate = $year . $mon . $mday;
    } else {
        $curdate = $year . $mon . $mmday;
    }
} else {
    affatal("Invalid value for 'updateday', must be either 'previous' or 'same'. Check the docs again.");
}

foreach (<$workdir/$uploaddir/*>) {
    if (/(\d{8})/ and $1 <= $curdate) {
        move($_, "$sitedir$comicsdir") ? aflog("moved $_ to $sitedir$comicsdir") : aflog("FAILED TO MOVE $_ TO $sitedir$comicsdir: $!");
    }
}

#=======================================================================
# Storyline dropdown box.
# Let's dance. -Spam

my @sdrop;
if (open SDROP, "$workdir$datadir$storyfile") {
    @sdrop = <SDROP>;
    close SDROP;
}

my %storylinebanners;

if (open STORYBANNERS, "$workdir$datadir$storylinebanners") {
    while (<STORYBANNERS>) {
        next if /^$|^\s*#/;
        my ($name, $url) = /(.*?),(?!.*")(.*?)(?:\r|\n)/;
        $name =~ s/^"(.*?)"$/$1/;
        $storylinebanners{$name} = $url;
    }
    close STORYBANNERS;
}

# The storyline preparser.
# This will make it easier to just grab this preparsed data and throw
# it together later on.  Trust me.

# The @stories array will be a list of anonymous hashes.  Each hash has
# four keys:

# name: The storyline name
# path: The URL of the storyline
# date: The date in yyyymmdd format
#  (yes, I know that's not the format it's in in the storyline file)
# depth: How many layers deep the storyline is

# I have no idea why I did it like this.  I must've been REALLY tired.

my @stories;
{
    my $index = 0;
    foreach (@sdrop) {
        next if /^$|^\s*#/;
        my ($name, $path, $date) = /(.*?)\s*,\s*(?!.*")(.*?)(?:\s*,\s*(.*?))?(?:\r\n|\r|\n)/;

        # Catch quotes
        $name =~ s/^(\s*)"(.*?)"$/$1$2/;
        my ($cname) = ($name =~ /^\s*(.*)/); # "c"lean name

        # Any space that PRECEDES the name of a storyline (i.e.
        # collapseable level indicators) are replaced by a
        # DOUBLE &nbsp;.

        my ($tempspaces) = ($name =~ /^( *)/);
        my $depth = length $tempspaces;
        $tempspaces =~ s/ /&nbsp;&nbsp;/g;
        $name =~ s/^( *)/$tempspaces/;

        # Compatibility with Keenspace: Knock out leading @ symbol
        # (don't ask, I don't get why they made it so you need an @ to make an
        # external URL)
        $path =~ s/^\@//;

        # Make date in yyyymmdd format
        my $pdate;
        if (defined($date)) {
            # Hi.  Undocumented bit.  The $storyline_use_date variable
            # determines whether to use the actual date field (true) or
            # Keenspace-like interpretation (false, default).
            #
            # I actually think it ought to be documented. I was also
            # thinking about reversing it to make the AutoKeen behaviour
            # the non-default. -Teg
            my ($mon,$day,$year);

            if ($storyline_use_date) {

                # This way, people can use either YYYYMMDD or MM/DD/YYYY. I'm
                # also going to add a config option to switch between American
                # and standard XX/XX/YYYY formats, I think. -Teg
                if ($date =~ /\//) {
                    ($mon, $day, $year) = ($date =~ /(\d\d|\d)\/(\d\d|\d)\/(\d\d\d\d|\d\d)/);
                    fdn($mon, $day);
                    # Now, catch two-digit years, Y2K be damned!
                    if($year < 100) {
                        # I figure 1981 is safe enough as a lower bound
                        # of two-digit dates.  And coders of yore figured
                        # two-digit dates were safe bounds, too.
                        if($year >= 80 and $year <= 99) {
                            $year += 1900;
                        } else {
                            $year += 2000;
                        }
                    }
                    $date = "$year$mon$day";
                } else {
                    # Sanity check of the weakest order.
                    ($date) = ($date =~ /(\d{8})/);
                }
            } else {
                ($date) = ($path =~ /(\d{8})/);
            }
        } elsif ($path =~ /(\d{8})/) {
            # Magic bit to make SELECTED work on storylines with no date field.
            # See poorly-formatted code in storylinesubcheck() for rest of magic.
            # -Teg
            $pdate = $1;
        }

                # At this point, we have either $date or $pdate, I think.  If
                # either are beyond the current date, we ignore this entry, as
                # it hasn't happened yet and we'd be linking to a non-existant
                # file.
                next if((defined($date) and $date > $curdate) or (defined($pdate) and $pdate > $curdate));

        my $banner = exists $storylinebanners{$cname} ? $storylinebanners{$cname} : '';

        # Now throw it all together
        $stories[$index++] = {
                name => $name,
                cname => $cname,
                path => $path,
                date => $date,
                pdate => $pdate,
                banner => $banner,
                depth => $depth
            }
    }
}

# The stories array is made.  That's done, at least.
# Now, the subordinate array.

### There was a reason I made @subordinate list all the subordinates to each
### entry as opposed to just making it a list of flags (i.e. does this entry
### have ANY subordinates), but I can't remember what it was.  I kept the code
### in, but commented out.  It also threw a compile error.
#
# Said error might have had something to do with the reference to '@$subordinate' :) -Teg
# (later) Or I might be an idiot that never read part of the docs correctly. :P -Teg

my @subordinate;
for(my $i = 0; $i <= $#stories; $i++) {
    # Starting with the first story, we check anything after it to make an
    # array of what's underneath each story.  Really.
    $subordinate[$i] = 0;

    my $startdepth = $stories[$i]->{depth};
    for(my $j = ($i + 1); $j <= $#stories; $j++) {
        # ASSUMPTION: We only go down one depth at a time!
        # (I think it would be paradoxial to go down more than one at a time; I can't
        # even begin to imagine how it might be defined. -Teg)
        # If this is directly subordinate, add it to the fray.
        $subordinate[$i] = 1 if ($stories[$j]->{depth} == ($startdepth + 1));
        # If this is more than one level subordinate, skip it.
        next if($stories[$j]->{depth} > ($startdepth + 1));
        # If this is equal or higher, terminate the loop.
        last if($stories[$j]->{depth} <= $startdepth);
    }
}

# The big block of storyline subroutines.  If given the time to reorganize
# everything, these would go in a separate file.  We have GOT to get back to
# work on Autofox, you know that?

# Now, storyline() needs an argument, the current date.  This is used to check
# where we are in the story so we know where the collapseables should go to
# and what should be selected.  It IS always defined, right, Teg? :-)
#
# Yes, though parsetags() doesn't actually check to make sure it is. It just
# relies on us not screwing up in calling it. ;) -Teg

sub storyline {
    my $fulldate = shift;
    my $line;
    my @remainingstories;
    my $selected = 0;
    my $no_this_is_cgi = 0;

    # If this is Javascripty AND the headers have been called,
    # set it up as a Javascripty bit.  Otherwise, fall to CGI.
    ### FIXME: The CGI interface uses "dropdown" as the parameter name,
    ### but the Javascript one uses "page".
    if($storyline_use_javascript) {
        # Error checking
        if($headers_placed and !$js_story_placed) {
            $line = qq(<select name="$js_prefix).qq(story">\n);
        } else {
            if(!$headers_placed) {
                $line = "ERROR: Config says we want the Javascript dropdown, but the Javascript header hasn't been declared for this page yet!  Defaulting to CGI dropdown...<br>\n";
                $line = qq(<form method="post" action="$ddredirect"><select name="dropdown">\n);
                $no_this_is_cgi = 1;
            }
            if($js_story_placed) {
                $line = "ERROR: Config says we want the Javascript dropdown, but it's already been used on this page!  Ignoring this tag to avoid Javascript namespace collisions...<br>\n";
                return $line;
            }
        }
    } else {
        # If it's not set at all, we can safely assume CGI.
        $line = qq(<form method="post" action="$ddredirect"><select name="dropdown">\n);
    }

    # One recurse later, we'll be in business.
    $selected = storylinesubcheck(0,$fulldate,\@remainingstories);

    # We now have @remainingstories!  And the crowd goes wild.
    # We also have $selected, so we know what's selected.  Booyaa!

    for (my $i = 0; $i <= $#remainingstories; $i++) {
        my $link;
        my $selectedtext;

        if ($remainingstories[$i]->{path} eq "NULL" or $remainingstories[$i]->{path} eq "") {
            $link = "NULL";
        } elsif ($remainingstories[$i]->{path} =~ /^http\:\/\//) {
            $link = $remainingstories[$i]->{path};
        } else {
            $link = $url.$remainingstories[$i]->{path};
        }

        # Hey!  Catch initial double-slashes!
        # Smallish problem if the URL ends with a slash and the storyline
        # URL starts with a slash... realistically, it doesn't matter in a
        # practical sense (any sane webserver should know what to do with it),
        # but it looks ugly.  So there.

        $link =~ s/^(http\:\/\/(.*?)\/)\//$1/;

        if ($i == $selected) {
            $selectedtext = qq( selected="selected");
        } else {
            $selectedtext = "";
        }

        # A NULL entry is disabled.  Unclickable.  Ignored by the Javascripty bit.
        if ($link eq "NULL" or $link eq "") {
            $selectedtext .= qq( disabled="disabled");
        }

        $line .= qq(<option value="$link"$selectedtext>$remainingstories[$i]->{name}</option>\n);
    }

    if($storyline_use_javascript and !$no_this_is_cgi) {
        $line .= qq(</select>&nbsp;<input type="button" value="Go!" onclick=").$js_prefix.qq(story_go();" />\n);
    } else {
        $line .= qq(</select>&nbsp;<input type="submit" value="Go!" /></form>\n);
    }

    return $line;
}

# Basically, I just ripped the code out of the top of storylinestart()
# to make getstoryline() to make a quick and easy way to get at the
# storyline for any given date from anywhere in the code. It takes
# the normal fulldate argument and returns the hash for the appropriate
# storyline.
# -Teg 2004-01-11

sub getstoryline {
    my $fulldate = shift;
    my @remainingstories;
    my $selected = 0;

    # Same deal as in the main storyline checker, but with a twist at the end

    $selected = storylinesubcheck(0, $fulldate, \@remainingstories);

    return $remainingstories[$selected];

}

sub storylinebanner {
    my $fulldate = shift;
    my $storyline = getstoryline($fulldate);

    my $line = qq(<a href="$url$storyline->{path}">);

    unless ($storyline->{banner} eq '') {
        $line .= qq(<img src="$storyline->{banner}" alt="$storyline->{cname}" title="$storyline->{cname}">)
    } else {
        $line .= qq($storyline->{cname});
    }

    $line .= qq(</a>);

    return $line;
}

sub storylinestart {
    # Return a link to the start of the current storyline.
    my $fulldate = shift;
    my $link;


    # Now, all we need is the path of the resulting story.  And because I want
    # to be fancy, I'll alt/title tag it, too.
    my $storyline = getstoryline($fulldate);
    my $name = $storyline->{cname};

    if ($storyline->{path} =~ /^http\:\/\//) {
        $link = $storyline->{path};
    } else {
        $link = $url.$storyline->{path};
    }

    # Same deal as in storyline().

    $link =~ s/^(http\:\/\/(.*?)\/)\//$1/;

    if (-e ("$sitedir$imagedir$storystart")) {
        return qq(<a href="$link"><img src="$url$imagedir$storystart" alt="Start of $name" title="Start of $name" border=0></a>);
    } else {
        return qq(<a href="$link">Start of $name</a>);
    }
}

sub storylinesubcheck {
    my $startline = shift;
    my $fulldate = shift;
    my $remainingstories = shift;
    my $selected = 0;
    my $tempselected;

    my $firstdepth = $stories[$startline]->{depth};

    # Now then.

    # Now.  Then.

    # Take a look at each storyline past where we are now.  We're looking for
    # the next storyline of the same depth, if one exists.  After this, we
    # check to see if the current date falls between the two (or is greater
    # than the first one if no more of the same depth exist).  If it does, or
    # if the storyline has no date declared for it, we dive into the next
    # depth level and check all THOSE for similar conditions until we run out
    # of storylines at that depth.  Of course, once depth zero terminates, we
    # return back to storyline() to dump it all out.

    # As we come across each valid storyline, we push its full $stories data
    # into the @remainingstories hash, via reference passed between each call
    # to this recursive curse.
    for (my $i = $startline; $i <= $#stories; $i++) {
        # We're only checking one depth at a time.
        next if ($stories[$i]->{depth} > $firstdepth);

        # If this is ABOVE the starting depth, we're out of the current depth
        # check and can thus stop here.
        last if ($stories[$i]->{depth} < $firstdepth);

        # This storyline gets added in.
        push @$remainingstories, $stories[$i];

        # If the date of this one is less than the current date, bump up the
        # SELECTED variable to this entry.
        $selected = (scalar @$remainingstories - 1) if (
            (defined($stories[$i]->{date}) and $stories[$i]->{date} <= $fulldate)
            or # (The rest of the magic. -Teg)
            (defined($stories[$i]->{pdate}) and $stories[$i]->{pdate} <= $fulldate)
        );

        # Safely skip this if there's no subordinates to check.
        next if ($subordinate[$i] == 0);

        my $j;
        # Seek the next same-level storyline.
        for ($j = ($i + 1); $j <= ($#stories + 1); $j++) {

            # We've fallen out of the array.  Thus, this depth is unmatched
            # and this terminates the storyline array in general.
            last if ($j > $#stories);

            # Jackpot.  Bingo.  Yahtzee.  We have a winner.
            last if ($stories[$j]->{depth} <= $firstdepth);

            # Anything below this depth is skipped.
            next if ($stories[$j]->{depth} > $firstdepth);

        }

        # Okay.  We've got the end of the depth.  $i is the start, $j is the
        # end.  Simple.

        # Main case: If the current storyline has an undefined date, proceed
        # to the next depth.
        if (!defined($stories[$i]->{date})) {
            $tempselected = storylinesubcheck($i + 1, $fulldate, $remainingstories);
            $selected = $tempselected if(defined($tempselected) and $tempselected > $selected);
        } elsif ($j > $#stories) {
            # Off the end
            if ($stories[$i]->{date} <= $fulldate) {
                # The date falls here, spit out the next chunk.
                $tempselected = storylinesubcheck($i + 1, $fulldate, $remainingstories);
                $selected = $tempselected if(defined($tempselected) and $tempselected > $selected);
            } else {
                next;
            }
        } elsif ($stories[$i]->{date} <= $fulldate and $stories[$j]->{date} > $fulldate) {
            # It falls in here somewhere.
            $tempselected = storylinesubcheck($i + 1, $fulldate, $remainingstories);
            $selected = $tempselected if(defined($tempselected) and $tempselected > $selected);
        } else {
            next;
        }
    }
    return $selected;
}

sub storylinefull {
    # Returns the entire storyline dropdown with no collapsing.
    # Still takes a fulldate so we select the proper default.

    my $fulldate = shift;
    my $selected = 0;
    my $line;
    my $no_this_is_cgi = 0;

    # If this is Javascripty AND the headers have been called,
    # set it up as a Javascripty bit.  Otherwise, fall to CGI.
    ### FIXME: The CGI interface uses "dropdown" as the parameter name,
    ### but the Javascript one uses "page".
    if($storyline_use_javascript) {
        # Error checking
        if($headers_placed and !$js_story_placed) {
            $line = qq(<select name="$js_prefix).qq(story">\n);
        } else {
            if(!$headers_placed) {
                $line = "ERROR: Config says we want the Javascript dropdown, but the Javascript header hasn't been declared for this page yet!  Defaulting to CGI dropdown...<br>\n";
                $no_this_is_cgi = 1;
                $line = qq(<form method="post" action="$ddredirect"><select name="dropdown">\n);
            }
            if($js_story_placed) {
                $line = "ERROR: Config says we want the Javascript dropdown, but it's already been placed on this page!  Ignoring this tag to avoid Javascript namespace collisions...<br>\n";
                return $line;
            }
        }
    } else {
        # If it's not set at all, we can safely assume CGI.
        $line = qq(<form method="post" action="$ddredirect"><select name="dropdown">\n);
    }

    # Since we're not doing any collapse logic, all we really need to do is
    # grab the storyline array and chuck out EVERYTHING.  Except we do need
    # to make sure we stop on the right entry for default purposes.  Or
    # default porpoises.  That's all this loop does.

    for (my $i = 0; $i <= $#stories; $i++) {
        next unless(defined($stories[$i]->{date}));
        if($stories[$i]->{date} <= $fulldate) {
            $selected = $i;
        }
    }

    # $selected is now set.  Loop again through the hash.
    # Yes, this DOES look familiar.  From storyline() above.

    for (my $i = 0; $i <= $#stories; $i++) {
        my $link;
        my $selectedtext;

        # To avoid confusion for now, translate ALL dropdown
        # destinations to absolute paths.
        if ($stories[$i]->{path} eq "NULL" or $stories[$i]->{path} eq "") {
            $link = "NULL";
        } elsif ($stories[$i]->{path} =~ /^http\:\/\//) {
            $link = $stories[$i]->{path};
        } else {
            $link = $url.$stories[$i]->{path};
        }

        $link =~ s/^(http\:\/\/(.*?)\/)\//$1/;

        if ($i == $selected) {
            $selectedtext = " SELECTED";
        } else {
            $selectedtext = "";
        }

        if ($link eq "NULL") {
            $selectedtext .= " DISABLED";
        }

        $line .= qq(<option value="$link"$selectedtext>$stories[$i]->{name}</option>\n);
    }

    if($storyline_use_javascript and !$no_this_is_cgi) {
        $line .= qq(</select>&nbsp;<input type="button" value="Go!" onClick=").$js_prefix.qq(story_go();">\n);
    } else {
        $line .= qq(</select>&nbsp;<input type="submit" value="Go!"></form>\n);
    }

    return $line;
}




#=======================================================================
# Pulls in filenames from $comicsdir and loads them into various hashes
# for use later on (in the case of .tag and .cap files, it actually
# opens the files and reads in the contents). -Teg

my %dayhasstrip;
my %monthhasstrip;
my %captions;

while (my $nextname = <$sitedir$comicsdir*>) {
    $nextname =~ s/.*\///;
    if ($nextname =~ /((\d\d\d\d)(\d\d)(\d\d)).*\.(?:gif|jpg|jpeg|png|bmp|tiff|txt|html|htm)$/i) {
        push (@{$strips{$1}}, $nextname);
        $dayhasstrip{$2}[$3][$4] = 1;
        $monthhasstrip{$2}{$3} = 1;
    } elsif ($nextname =~ /((\d\d\d\d)(\d\d)(\d\d)).*\.(tag|cap)$/i) {
        open (CAPFILE, "$sitedir$comicsdir$nextname") or die "big problemski: $!";
        my $caption = join '', <CAPFILE>;
        close CAPFILE;
        my ($filename) = ($nextname =~ /(^(.*)\.(?:gif|jpg|jpeg|png|bmp))/);

        if($filename eq "") {
            aflog("WARNING: Caption file $nextname does not appear to be associated with any file!");
            next;
        }

        if (defined $captions{$filename}) {
            aflog("WARNING: More than one entry in captions list for $filename !! Later entries take precedence!");
        }
        $captions{$filename} = $caption;
    }
}

#=======================================================================
# Pulls in captions from captions.txt. -Teg

if (open (CAPTIONS, $captionsfile)) {
    foreach (<CAPTIONS>) {
        chomp;
        my ($filename, $caption) = ($_ =~ /(\S*) (.*)/);
        if (defined $captions{$filename}) {
            aflog("WARNING: More than one caption for $filename !! Later entries take precedence!");
        }
        $captions{$filename} = $caption;
    }
    close CAPTIONS;
}


#=======================================================================

my @daylist = sort keys %strips;

my ($fstrip, $fyear, $fmonth, $fday) = 
    ($daylist[0] =~ /((\d\d\d\d)(\d\d)(\d\d))/);

my ($lstrip, $lyear, $lmonth, $lday) =
    ($daylist[$#daylist] =~ /((\d\d\d\d)(\d\d)(\d\d))/);

aflog("(re)generating pages...");

open (DAYTEMPLATE, "$workdir$datadir$dailytemplate")
    or affatal("ERROR: No daily template found! Tried $workdir$datadir$dailytemplate.");
my $daytemplate = join '', <DAYTEMPLATE>;
close DAYTEMPLATE;

foreach my $i (0..$#daylist) {
    $daylist[$i] =~ /(\d{8})/;

    open(TODAY, ">" . $sitedir . $dailydir . $1 . $dailyext);
    my $line = parsetags($daytemplate, $1, $i);
    print TODAY $line;
    close TODAY;
}

#=======================================================================
# It's recursive either because I really, really suck, or because I'm
# insane. -Teg

### Teg, you're insane. :-) But that's what you're looking for in this
### part, I think. -Spam

my $wdir = "$workdir$parsedir";

traverse($wdir);

sub traverse {
    my $dir = shift;

    foreach (<$dir/*>) {
        my ($nfn) = /.*?$wdir\/(.*)/;
        if (-d) {
            mkdir "$sitedir$nfn";
            traverse($_);
        } else {
            open TEMPLATE, $_;
            my $page = join '', <TEMPLATE>;
            close TEMPLATE;
            $page = parsetags($page, $daylist[$#daylist], $#daylist);
            open OUTFILE, ">$sitedir$nfn" or die "$nfn $!";
            print OUTFILE $page;
            close OUTFILE;
        }
    }
}


aflog("done (re)generating pages");

#=========================================================================
# Now, let's go for the RSS file(s).
# Really, all this will do is either repeat todays_comics for a few strips
# back into the archive or display a link list to the /d/ pages.

# Are we even doing this in the first place?
if($rss_full_generate or $rss_lite_generate){
    # "Make me an RFC 822-compliant date, please."
    my $now = strftime("%a, %d %b %Y %H:%M:%S",gmtime(time + $tzoffset));
    $now .= " $timezone";

    aflog("Starting RSS generation");

    # First, we want the common header data.  We don't know specifically if
    # we want full, lite, or both, but both need the same data anyhoo.

    my $rssheader;
    $rssheader .= qq(<rss version="2.0">\n);
    $rssheader .= qq( <channel>\n);
    $rssheader .= qq(  <title>$rss_title</title>\n);
    $rssheader .= qq(  <link>$rss_link</link>\n);
    $rssheader .= qq(  <description>$rss_description</description>\n);
    $rssheader .= qq(  <copyright>$rss_copyright</copyright>\n);
    $rssheader .= qq(  <generator>$afversion</generator>\n);
    $rssheader .= qq(  <lastBuildDate>$now</lastBuildDate>\n);
    
    # The rss files are assumed to be relative to the public HTML root.  Let's
    # see if we can get our hands on it.

    # Part one: Full comic
    if ($rss_full_generate) {
        aflog("Full comic RSS generation to $rss_full_filename");
        if(open RSSFULLOUT, ">$sitedir$rss_full_filename"){
            # BLOCK FOR IF WE CAN OPEN THIS
            # Initialize the file:
            print RSSFULLOUT $rssheader;
            for(my $i = 0;$i < $rss_limit;$i++){
                last if($i >= $#daylist);
                my $workingfulldate=$daylist[($#daylist-$i)];
                my ($workingyear,$workingmon,$workingdate) = ($workingfulldate =~ /(\d\d\d\d)(\d\d)(\d\d)/);
                $workingdate =~ s/^0//;
                my $workingmonth = $mnames[$workingmon];
                my $workingday = $dnames[zeller($workingfulldate)];
                my $pubdate = "$dshortnames[zeller($workingfulldate)], $workingdate $mshortnames[$workingmon] $workingyear 00:00:01 $timezone";
    
                print RSSFULLOUT <<RSSLINKHEAD;
      <item>
       <title>Comic for $workingday, $workingmonth $workingdate, $workingyear</title>
       <link>$url$dailydir$workingfulldate$dailyext</link>
       <guid>$url$dailydir$workingfulldate$dailyext</guid>
       <pubDate>$pubdate</pubDate>
RSSLINKHEAD
    
                my $textblock;
                # If we're going with full comics, we can also get news bits
                # from data/news/.  News files are simply text files.
                # yyyymmdd.html or .txt, and all that.
                # We're assuming these files are HTML and thus don't need the
                # happy fun "linebreak-to-<br>" joy.
                if(open NEWS, "$workdir$datadir/news/$workingfulldate.html" or open NEWS, "$workdir$datadir/news/$workingfulldate.txt"){
                    $textblock .= join '', <NEWS>;
                    # Break the ]]> CDATA closing tag if it exists (paranoia)
                    $textblock =~ s/\]\]\>/\] \]\>/g;
                    $textblock .= "<br />";
                    close NEWS;
                }
                ### REMINDER TO SELF: This is the line that puts the current comic
                ### info in.  So stop looking all through the code for it.
                $textblock .= todays_comics_rss($workingfulldate);
    
                print RSSFULLOUT qq(   <description><![CDATA[$textblock]]></description>\n);
                print RSSFULLOUT "  </item>\n";
            }
            print RSSFULLOUT <<RSSFOOTER;
    </channel>
</rss>
RSSFOOTER
            close RSSFULLOUT;
        } else {
            aflog("Can't open full comic RSS file $rss_full_filename!  $!");
        }
        aflog("Full comic RSS generation complete.");
    }

    # Part two: Lite mode (only the title and a link)
    # This looks strikingly similar to full.  Funny that.

    if($rss_lite_generate){
        aflog("Lite mode RSS generation to $rss_lite_filename");
        if(open RSSLITEOUT, ">$sitedir$rss_lite_filename"){
            # BLOCK FOR IF WE CAN OPEN THIS
            # Initialize the file:
            print RSSLITEOUT $rssheader;
            for(my $i = 0;$i < $rss_limit;$i++){
                last if($i >= $#daylist);
                my $workingfulldate=$daylist[($#daylist-$i)];
                my ($workingyear,$workingmon,$workingdate) = ($workingfulldate =~ /(\d\d\d\d)(\d\d)(\d\d)/);
                $workingdate =~ s/^0//;
                my $workingmonth = $mnames[$workingmon];
                my $workingday = $dnames[zeller($workingfulldate)];
                my $pubdate = "$dshortnames[zeller($workingfulldate)], $workingdate $mshortnames[$workingmon] $workingyear 00:00:01 $timezone";
    
                print RSSLITEOUT <<RSSLINKHEADLITE;
      <item>
       <title>Comic for $workingday, $workingmonth $workingdate, $workingyear</title>
       <link>$url$dailydir$workingfulldate$dailyext</link>
       <guid>$url$dailydir$workingfulldate$dailyext</guid>
       <pubDate>$pubdate</pubDate>
RSSLINKHEADLITE
    
                print RSSLITEOUT qq(   <description>&lt;a href=&quot;$url$dailydir$workingfulldate$dailyext&quot;&gt;Comic for $workingday, $workingmonth $workingdate, $workingyear&lt;/a&gt;</description>\n);
                print RSSLITEOUT "  </item>\n";
            }
        print RSSLITEOUT <<RSSFOOTERLITE;
    </channel>
</rss>
RSSFOOTERLITE
            close RSSLITEOUT;
        } else {
            aflog("Can't open lite mode RSS file $rss_lite_filename!  $!");
        }
        aflog("Lite mode RSS generation complete.");
    }
}

aflog("AutoFox exiting. Comics in the archive at completion of this run: $#daylist");
#=======================================================================
# The actual parsing mechanism and the many functions. Some of this gets
# a little opaque, especially the calendar functions. -Teg

# For my and anyone else's future reference regarding parsetags():
# first argument: scalar to parse
# second argument: date we're on
# third argument: strip *number*
# For index and any pages other than the dailies, the date should be
# $daylist[$#daylist], and the number should be $#daylist.
# I actually forgot my own API and had to figure out what the heck I was
# doing all over again. Ugh. -Teg

# This is now declared up here because parsetags needs to know if
# it's in the middle of an include.  That way, it won't demand that
# headers be redeclared and can keep track of storylines.
my %alreadyincluded;

# This caches include files so we don't have to keep going back to disk
# to keep reading them over and over again.  I have this feeling that
# over the course of 500 or so comics, this could save bigly huge on
# execution time.
### FIXME: When we go for the full rewrite, this should be a tied
### variable and should exist in its own class file!  It makes more
### sense that way!  Really it does!
my %includecache;

sub parsetags {
    my $line = shift;
    my $fulldate;
    if ($line =~ s/\*\*\*set_date\s+(.*?)\*\*\*//) {
        $fulldate = $1;
    } else {
        $fulldate = shift;
    }

    if($includecount == 0) {
        # If %alreadyincluded is empty, this is NOT an include,
        # so we need to reset the header and story bits.
        $headers_placed = 0;
        $js_story_placed = 0;
    }

    (my $year, my $month, my $day) = ($fulldate =~ /(\d\d\d\d)(\d\d)(\d\d)/);
    $day =~ s/^0//;
    $month =~ s/^0//;
    my $weekday = $dnames[zeller($fulldate)];

    my $i = shift;

    # Sanity? What's that?
    #
    # There is essentially no checking done here. Anyone using this feature
    # is expected to understand what is going on well enough to fend for
    # themselves barring an actual bug in AF.
    #
    # Trying to get too fancy with regexes may cause problems.
    #
    # "pre" stuff occurs before all other parsing.
    # "post" stuff occurs after all other parsing EXCEPT ***includenoparse***.
    # "postinp" stuff occurs after ALL parsing, including ***includenoparse***.
    #
    # Right now it's extremely fragile and easily broken. Not hard to fix,
    # what's here was just done quickly as an initial "how will this be done?"
    # implementation. I'll clean it up after I get some sleeeeeeeeeep.
    # -Teg (20040627)
    my @regpre;
    my @regpost;
    my @regpostinp;

RELOOP:    while ($line =~ s/\*\*\*regex\s+(.*?)\s+(s(.)(?:.*?)\2(?<!\\)(?:.*?)\2(?<!\\))\*\*\*//) {
        my $when = $1;
        my $regex = $2;
        my $del = $3;

        my $delcount = 0;
        while ($regex =~ /(?<!\\)$del/) {
            $delcount++;
        }
        if ($delcount != 3) {
            aflog("Ignoring regex '$regex'. Contains too many delimiters ($2).");
            next RELOOP;
        }

        if ($regex =~ /\?\?\{/) {
            aflog("Ignoring regex '$regex'. Appears to contain arbitrary Perl code.");
            next RELOOP;
        }

        if ($regex =~ /(?<!\\)\$\{\\/) {
            aflog ("Ignoring regex '$regex'. Appears to contain Perl function call.");
            next RELOOP;
        }

        my $code = "\$line =~ $regex";

        switch ($when) {
            case "pre"
                { push @regpre, $code }
            case "post"
                { push @regpost, $code }
            case "postinp"
                { push @regpostinp, $code }
            else
                { aflog("Ignoring regex '$regex', \"when\" flag invalid or not specified."); next RELOOP; }
        }
    }

    # This needs to remain above everything else below.
    foreach (@regpre) {
        eval($_);
    }


    #***include*** *MUST* remain first! (for values of first not including ahead of regex stuff above)
    $line =~ s/\*\*\*include\s+(.*?)\*\*\*/${\include($1,$fulldate,$i)}/g;

    # PAY ATTENTION!  Past this, $headers_placed is set!
    # This will also throw a fit if headers are placed twice!
    $line =~ s/\*\*\*headers\*\*\*/${\make_headers()}/g;

    $line =~ s/\*\*\*today(?:s_date|'s_date)\*\*\*/$dnames[zeller($fulldate)], $mnames[$month] $day, $year/g;
    $line =~ s/\*\*\*today(?:s|'s)_iso_date\*\*\*/$fulldate/g;
    $line =~ s/\*\*\*today(?:s_|'s_)(?:comic|comics)\*\*\*/${\todays_comics($fulldate)}/g;
    $line =~ s/\*\*\*previous_day\*\*\*/${\previous_day($i)}/g;
    $line =~ s/\*\*\*next_day\*\*\*/${\next_day($i)}/g;
    $line =~ s/\*\*\*first_day\*\*\*/${\first_day($i)}/g;
    $line =~ s/\*\*\*last_day\*\*\*/${\last_day($i)}/g;
    $line =~ s/\*\*\*storylinestart\*\*\*/${\storylinestart($fulldate)}/g;
    $line =~ s/\*\*\*the_year\*\*\*/$year/g;
    $line =~ s/\*\*\*day_of_the_month\*\*\*/$day/g;
    $line =~ s/\*\*\*month_of_the_year\*\*\*/$mnames[$month]/g;
    $line =~ s/\*\*\*short_month\*\*\*/$mshortnames[$month]/g;
    $line =~ s/\*\*\*day_of_the_week\*\*\*/$weekday/g;
    $line =~ s/\*\*\*daily_archive\*\*\*/${\daily_archive()}/g;
    $line =~ s/\*\*\*url\*\*\*/$url/g;
    $line =~ s/\*\*\*calendar\*\*\*/${\calendar($fulldate)}/g;
    $line =~ s/\*\*\*big_calendar\*\*\*/${\big_calendar()}/g;
    $line =~ s/\*\*\*home\*\*\*/<a href="$url">Home<\/a>/g;
    $line =~ s/\*\*\*storyline\*\*\*/${\storyline($fulldate)}/g;
    $line =~ s/\*\*\*storylinebanner\*\*\*/${\storylinebanner($fulldate)}/g;
    $line =~ s/\*\*\*storylinefull\*\*\*/${\storylinefull($fulldate)}/g;
        $line =~ s/\*\*\*link_rel\*\*\*/${\link_rel($i)}/g;
    $line =~ s/\*\*\*afversion\*\*\*/$afversion/g;
    $line =~ s/\*\*\*(?:comics|comic)_from\s+(.*?)\*\*\*/${\todays_comics($1)}/g;

    # This needs to be above includenoparse and below everything else.
    foreach (@regpost) {
        eval($_);
    }

    #***includenoparse*** *MUST* remain last! (for values of last not including after 'foreach (@regpostinp)')
    $line =~ s/\*\*\*includenoparse\s+(.*?)\*\*\*/${\includenoparse($1)}/g;

    # This needs to remain absolutely, positively last. For now.
    foreach (@regpostinp) {
        eval($_);
    }

    return $line;
}

#=======================================================================
# ***include*** and ***includenoparse***

sub include {
    my $include = shift;
    my $fulldate = shift;
    my $i = shift;
    my $includelines;
    my $after;

    # Check for nest loops (Is this already included?)
    if ($alreadyincluded{$include}) {
        return "ERROR: Nest loop!";
    }

    # This isn't already included, so let's tack it on.
    $includelines = fetch_include("$workdir$parsedir$include");
    if($includelines =~ /^ERROR/) {
        return $includelines;
    }

    $alreadyincluded{$include} = 1;
    $includecount++;

    # Now, feed the file back in through the tag parser, maintaining all data
    # that came in in the first place (date, etc).

    $after = parsetags($includelines,$fulldate,$i);

    # It's been parsed and we're not in a loop, so assume we can remove this
    # from %alreadyincluded.
    undef $alreadyincluded{$include};
    $includecount--;

    return $after;
}

sub includenoparse {
    my $include = shift;
    my $includelines;

    # Just do a good ol' yank-and-chuck.
    $includelines = fetch_include("$workdir$parsedir$include");

    return $includelines;
}

#=======================================================================
#


sub todays_comics {
    my $fulldate = shift;
    my $comics;
    foreach (@{$strips{"$fulldate"}}) {
        if (/(txt|htm|html)$/) {
            open(TEXTFILE, "$sitedir$comicsdir/$_") or die "WTF?";
            $comics .= join '', <TEXTFILE>;
            close TEXTFILE;
        } else {
            my $ci = $_;
            my $caption = defined $captions{$ci} ? $captions{$ci} : "";
            $comics .= qq(<img src="$url$comicsdir$_" alt="$caption" title="$caption" class="comicimage" />\n<br />\n);
        }
    }
    $comics =~ s/\<br\>\n$//;
    return $comics;
}

sub todays_comics_rss {
    my $fulldate = shift;
    my $comics;
    foreach (@{$strips{"$fulldate"}}) {
        if (/(txt|htm|html)$/) {
            open(TEXTFILE, "$sitedir$comicsdir/$_") or die "WTF?";
            my $temptext .= join '',<TEXTFILE>;

            # Now, the fun part.  We have to fix any relative <img src>
            # or <a href> tags to be absolute.

            $temptext =~ s/\<img\s+src="(.*?)"(.*?)\>/\<img src="${\reltoabs($1)}"$2\>/g;
            $temptext =~ s/\<a\s+href="(.*?)"(.*?)\>/\<a href="${\reltoabs($1)}"$2\>/g;
            $temptext =~ s/\]\]\>/\] \]\>/g;

            $comics .= $temptext;
            close TEXTFILE;
        } else {
            my $ci = $_;
            my $caption = defined $captions{$ci} ? $captions{$ci} : "";
            $comics .= qq(<img src="$url$comicsdir$_" alt="$caption" title="$caption"><br />);
        }
    }
    return $comics;
}

sub first_day {
    my $i = shift;
    if ($i < 1) {
        # If there's a ghosted image, use that.
                if($use_css_navbuttons) {
                        return qq(<div class="navbutton firstbuttonghosted siteimage" alt="This is the first comic"></div>);
                } elsif( -e ("$sitedir$imagedir$first_day_ghosted")) {
            return qq(<img src="$url$imagedir$first_day_ghosted" class="firstbuttonghosted" alt="This is the first comic" />);
        } else {
            return "";
        }
    } else {
                if($use_css_navbuttons) {
            return qq(<a href="$url$dailydir$daylist[0].html"><div class="navbutton firstbutton siteimage" alt="First Day"></div></a>);
                } elsif (-e ("$sitedir$imagedir$first_day")) {
            return qq(<a href="$url$dailydir$daylist[0].html"><img src="$url$imagedir$first_day" alt="First Day" class="firstbutton" /></a>);
        } else {
            return qq(<a href="$url$dailydir$daylist[0].html" class="firstbutton">First Day</a>);
        }
    }
}

sub last_day {
    my $i = shift;
    if ($i == $#daylist) {
        # If there's a ghosted image, use that.
                if($use_css_navbuttons) {
                        return qq(<div class="navbutton lastbuttonghosted siteimage" alt="This is the most recent comic"></div>);
                } elsif( -e ("$sitedir$imagedir$last_day_ghosted")) {
            return qq(<img src="$url$imagedir$last_day_ghosted" class="lastbuttonghosted" alt="This is the most recent comic" />);
        } else {
            return "";
        }
    } else {
                if($use_css_navbuttons) {
            return qq(<a href="$url"><div class="navbutton lastbutton siteimage" alt="Last Day"></div></a>);
                } elsif (-e ("$sitedir$imagedir$last_day")) {
            return qq(<a href="$url"><img src="$url$imagedir$last_day" class="lastbutton" alt="Last Day" /></a>);
        } else {
            return qq(<a href="$url" class="lastbutton">Last Day</a>);
        }
    }
}

sub previous_day {
    my $i = shift;
    if ($i < 1) {
        # If there's a ghosted image, use that.
                if($use_css_navbuttons) {
                        return qq(<div class="navbutton prevbuttonghosted siteimage" alt="This is the first comic"></div>);
                } elsif( -e ("$sitedir$imagedir$previous_day_ghosted")) {
            return qq(<img src="$url$imagedir$previous_day_ghosted" class="prefbuttonghosted" alt="This is the first comic" />);
        } else {
            return "";
        }
    } else {
                if($use_css_navbuttons) {
            return qq(<a href="$url$dailydir$daylist[$i-1].html"><div class="navbutton prevbutton siteimage" alt="Previous Day"></div></a>);
                } elsif (-e ("$sitedir$imagedir$previous_day")) {
            return qq(<a href="$url$dailydir$daylist[$i-1].html"><img src="$url$imagedir$previous_day" class="prevbutton" alt="Previous Day" /></a>);
        } else {
            return qq(<a href="$url$dailydir$daylist[$i-1].html" class="prevbutton">Previous Day</a>);
        }
    }
}

sub next_day {
    my $i = shift;
    my $link;
    if ($i == $#daylist) {
        # If there's a ghosted image, use that.
                if($use_css_navbuttons) {
            return qq(<div class="navbutton nextbuttonghosted siteimage" alt="This is the current comic"></div>);
                } elsif (-e ("$sitedir$imagedir$next_day_ghosted")) {
            return qq(<img src="$url$imagedir$next_day_ghosted" class="nextbuttonghosted" alt="No Next Day" />);
        } else {
            return "";
        }
    }

    if ($i == ($#daylist - 1)) {
        $link = $url;
    } else {
        $link = "$url$dailydir$daylist[$i+1].html";
    }

        if($use_css_navbuttons) {
        return qq(<a href="$link"><div class="navbutton nextbutton siteimage" alt="Next Day"></div></a>);
        } elsif (-e ("$sitedir$imagedir$next_day")) {
        return qq(<a href="$link"><img src="$url$imagedir$next_day" class="nextbutton" alt="Next Day" /></a>);
    } else {
        return qq(<a href="$link" class="nextbutton">Next Day</a>);
    }
}

sub link_rel {
    my $i = shift;

    # In general, we can toss in the next, prev, start, and index tags when this
    # comes up.  To wit:
    #
    # next: The next comic in line (left out if this is the most recent)
    # prev: The previous comic in line (left out if this is the first)
    # start: The first comic (always added)
    # index: The current comic (always added)
    # 
    # We'll put those in under any situation, since we can't really tell if
    # we're on the front page or any non-front page.  The front page DOES use
    # navigation rel tags to go backward if need be.  This doesn't make as much
    # sense for, say, a cast page, but this is the safest way to do it.  If you
    # don't want such tags in your cast pages, use a different header that
    # doesn't call this.

    my $toreturn = "";

    if($i >= 1) {
        $toreturn .= qq(<link rel="prev" title="Previous comic" href="$url$dailydir$daylist[$i-1].html" />\n);
    }

    if($i < $#daylist) {
        $toreturn .= qq(<link rel="next" title="Next comic" href="$url$dailydir$daylist[$i+1].html" />\n);
    }

    $toreturn .= qq(<link rel="start" title="First comic" href="$url$dailydir$daylist[0].html" />\n);
    $toreturn .= qq(<link rel="index" title="Current comic" href="$url" />\n);

    return $toreturn;
}

sub daily_archive {
    my $line = "";
    my @reversestrips = reverse @daylist;
    foreach (@reversestrips) {
        /((\d\d\d\d)(\d\d)(\d\d))/;
        $line .= qq(<a href="$url$dailydir$1.html">$mshortnames[$3] $4, $2</a><br />\n);
    }
    return $line;
}

sub getndays {
    my $year = shift; my $month = shift;
    my @days = (0,31,28,31,30,31,30,31,31,30,31,30,31);
    if ($month < 1) {
        die "What? You want a month before January?! BAD USER/DEVELOPER!\n";
    }
    if ($month > 12) {
        die "What the...?! There's nothing after December!\n";
    }
    if ($month == 2) { # This block is not as I originally intended, but in retrospect it's clearer, if not as efficient.
        if ($year % 400 == 0) {
            return 29;
        } elsif ($year % 100 == 0) {
            return 28;
        } elsif ($year % 4 == 0) {
            return 29;
        } else {
            return 28;
        }
    }

    return $days[$month];
}

# Here there be dragons.
# Seriously, don't mess with zeller. Anyone doing so is likely to get a headache AND break something. -Teg
sub zeller {
    my $fulldate = shift;
    my ($year,$month,$day) = ($fulldate =~ /(\d\d\d\d)(\d\d)(\d\d)/);
    $day--;
    my ($startmonth, $startyear, $leapfactor);
    if ($month < 3) {
        $startmonth = 0;
        $startyear = $year - 1;
    } else {
        $startmonth = int(0.4*$month+2.3);
        $startyear = $year;
    }
    $leapfactor = int($startyear/4) - int($startyear/100) + int($startyear/400);
    return ((365 * $year + 31 * ($month-1) + $day + $leapfactor - $startmonth) % 7)+1;
}

sub affatal {
    my $es = shift;
    aflog($es);
    die $es;
}

#=======================================================================
# Calendar functions.
# WARNING: This section may cause spontanious insanity.

sub big_calendar {
    my $line;
        $line .= "<div class=\"bigcalendarcontainer\">\n";
    foreach my $year ($fyear..$lyear) {
        foreach my $month (1..12) {
            fdn($month);
            next unless $monthhasstrip{$year}{$month};
            my $date = $year . $month . "01";
            $line .= "<div class=\"calendarbox\">" . calendar($date, 1) . "</div>";
        }
    }
        $line .= "</div>\n";
    return $line;
}

# calendar() is long, complex, hard to read, suboptimal, and unfortunately
# some of the best original design work I've ever done.
# -Teg 2003-03-31
#
# Don't even try to understand it. *I* don't even know how it works anymore.
# -Teg 2003-06-08
#
# This monstrosity is now 117 lines long. Ugh.
# -Teg 2003-06-20
#
# I'm making periodic ventures into cleaning this up. Things may be more
# inconsistent than they already were for a while.
# -Teg 2004-01-08
#
# I didn't clean this up too much, but I've remade it to use the new CSS stuff
# I've been working on for the DoM site.  This version will ONLY support the
# CSS stuff.
# -Spam 2011-11-21
sub calendar {
    my $fulldate = shift;
    my ($year,$month,$day) = ($fulldate =~ /(\d\d\d\d)(\d\d)(\d\d)/);
    my $bigcal; $bigcal = 0 unless $bigcal = shift;

    my $prevmonth; my $pmname; my $pmyear; my $nextmonth; my $nmname; my $nmyear;

    unless ($bigcal) {
        $prevmonth = prevmonth($fulldate);

        $nextmonth = nextmonth($fulldate);

        if ($prevmonth == -1) {
            $prevmonth = "";
        } else {
            my ($pmn) = ($prevmonth =~ /\d\d\d\d(\d\d)\d\d/);
            $pmname = $mshortnames[$pmn];
            ($pmyear) = ($prevmonth =~ /(\d\d\d\d)\d\d\d\d/);
        }
        if ($nextmonth == -1) {
            $nextmonth = "";
        } else {
            my ($nmn) = ($nextmonth =~ /\d\d\d\d(\d\d)\d\d/);
            $nmname = $mshortnames[$nmn];
            ($nmyear) = ($nextmonth =~ /(\d\d\d\d)\d\d\d\d/);
        }
    }

    my $line = qq(<div class="calendarbox">\n);
        $line .= qq(<table class="calendar">\n);

    $line .= qq(<tr class="calendartoprow"><td colspan="7">);

    if ($prevmonth) {
        $line .= qq(<span class="calendarmonthnav">);
        $line .= qq(<a href="$url$dailydir$prevmonth.html">$pmname</a>);
                $line .= qq(</span>);
    }

    $line .= " <span class=\"calendarcurmonth\">$mnames[$month]&nbsp;$year</span> ";

    if ($nextmonth) {
        $line .= qq(<span class="calendarmonthnav">);
        $line .= qq(<a href="$url$dailydir$nextmonth.html">$nmname</a>);
        $line .= qq(</span>);
    }

    $line .= "</td></tr>\n";

    my $days = getndays($year, $month);
    my $nfdate = $year . $month . "01";
    my $prevdays = (zeller($nfdate)-1); # Number of days to show from previous month.
    my $pscount = $prevdays-1;
    my $acount = 1; # [sic]
    $line .= qq(<tr class="calendarrow">);
    my $cells = 42;
    foreach my $cell (1..$cells) {
        if ($cell <= $prevdays) {
                    # Cell is a part of LAST month.
            my ($pmonth, $pyear);

            if (($month-1) >= 1) {
                $pmonth = $month-1; fdn($pmonth);
                $pyear = $year;
            } else {
                $pmonth = 12;
                $pyear = ($year-1);
            }

            if ($pyear < $fyear) {
                $line .= qq(<td class="calendarprevmonthday"></td>);
                next;
            }

            my $pday = getndays($pyear, $pmonth)-$pscount; $pscount--;

            if ($dayhasstrip{$pyear}[$pmonth][$pday]) {
                $line .= qq(<td class="calendarprevmonthday"><a href="$url$dailydir$pyear$pmonth$pday.html">$pday</a></td>);
            } else {
                $line .= qq(<td class="calendarprevmonthday">$pday</td>);
            }

            fixtable($cell, $line);
            next;
        }
        if ($cell - $prevdays <= $days) {
            # Cell is a part of THIS month.
            my $today = $cell - $prevdays; my $dtoday = $today;
            fdn($today, $month);
            if ($dayhasstrip{$year}[$month][$today]) {
                if ("$year$month$today" eq $fulldate and !$bigcal) {
                    # Cell is, in fact, TODAY.
                    $line .= qq(<td class="calendardaywithcomic calendartoday"><a href="$url$dailydir$year$month$today.html">$dtoday</a></td>);
                } else {
                    $line .= qq(<td class="calendardaywithcomic"><a href="$url$dailydir$year$month$today.html">$dtoday</a></td>);
                }
            } else {
                $line .= qq(<td>$dtoday</td>);
            }
            fixtable($cell, $line);
            next;
        }
        # Cell is a part of NEXT month (note the next above; Teg, what
        # were you THINKING, man? :-) ).
        my ($pmonth, $pyear);
        my $pday = $acount;
        if ($month+1 <= 12) {
            $pmonth = $month+1; fdn($pmonth); $pyear = $year;
        } else {
            $pmonth = "01"; $pyear = $year+1;
        }
        if ($pyear > $lyear) {
            $line .= qq(<td class="calendarnextmonthday"></td>);
            fixtable($cell, $line);
            next;
        }
        if ($dayhasstrip{$pyear}[$pmonth][$pday]) {
            my $pdday = $pday;
            fdn($pday);
            $line .= qq(<td class="calendarnextmonthday"><a href="$url$dailydir$pyear$pmonth$pday.html">$pdday</a></td>);
        } else {
            $line .= qq(<td class="calendarnextmonthday">$pday</td>);
        }
        $acount++;
        fixtable($cell, $line);
    }
    $line .= "</table>\n";
        $line .= "</div>\n";
    return $line;
}

sub fixtable {
    my ($cellcount, $line) = @_;

    if($cellcount % 7 == 0) {
        $_[1] .= qq(</tr>\n);
        if($cellcount < 42) {
            $_[1] .= qq(<tr class="calendarrow">);
        }
    }
}

#=======================================================================
# Various utility functions, including logging functions.

sub fdn {
    foreach (@_) {
        if (/^\d$/) {
            $_ = "0$_";
        }
    }
}

sub aflog {
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time); $mon++;
    fdn($hour, $min, $sec, $mday);
    print LOGFILE "$mshortnames[$mon]  $mday $hour:$min:$sec   @_\n";
}

#========================================================================
# Search functions.

sub prevstrip {
    my $fulldate = shift;

    return -1 if $fulldate == $fstrip;
    if ($fulldate < $fstrip) {
        affatal("BUG: in prevstrip(). A date prior to the first in the"
                ." archive was passed in: p:$fulldate f:$fstrip");
    }

    my ($year,$month,$day) = ($fulldate =~ /(\d\d\d\d)(\d\d)(\d\d)/);

    while (1) {
        if ($day == 1) {
            if ($month == 1) {
                $month = 12;
                $year--;
            } else {
                $month--;
            }
            $day = getndays($year, $month);
        } else {
            $day--;
        }

        fdn($day, $month);

        if ($dayhasstrip{$year}[$month][$day]) {
            return "$year$month$day";
        }
    }
}

my $pmcount1 = 0;

sub prevmonth {
    my $fulldate = shift;

    my ($year, $month, $day) = ($fulldate =~ /(\d\d\d\d)(\d\d)(\d\d)/);

    return -1 if ( $fulldate == $fstrip ||
                  ( $month == $fmonth &&
                    $year == $fyear ) );
    if ($fulldate < $fstrip) {
        affatal("BUG: in prevmonth(). A date prior to the first in the"
                ." archive was passed in: p:$fulldate f:$fstrip");
    }


    while (1) {

        $pmcount1++;

        if ($month == 1) {
            $month = 12;
            $year--;
        } else {
            $month--;
        }
        fdn($month);

        if ($monthhasstrip{$year}{$month}) {
            $day = getndays($year, $month);
            unless ($dayhasstrip{$year}[$month][$day]) {
                ($day) = (prevstrip("$year$month$day") =~ /\d\d\d\d\d\d(\d\d)/);
            }

            fdn($day);

            $pmcount1 = 0;
            return "$year$month$day";
        } else {
            next;
        }
    }
}

sub nextstrip {
    my $fulldate = shift;

    if ($fulldate == $lstrip) {
        return -1;
    }
    if ($fulldate > $lstrip) {
        affatal("BUG: in nextstrip(). A date after the first in the"
        ." archive was passed in: p:$fulldate f:$fstrip");
    }

    my ($year,$month,$day) = ($fulldate =~ /(\d\d\d\d)(\d\d)(\d\d)/);

    while (1) {
        if ($day == getndays($year, $month)) {
            if ($month == 12) {
                $month = 1;
                $year++;
            } else {
                $month++;
                $day = 1;
            }
        } else {
            $day++;
        }

        fdn($day, $month);

        if ($dayhasstrip{$year}[$month][$day]) {
            return "$year$month$day";
        }
    }
}

sub nextmonth {
    my $fulldate = shift;

    my ($year, $month, $day) = ($fulldate =~ /(\d\d\d\d)(\d\d)(\d\d)/);

    if ( $fulldate == $lstrip || ( $month == $lmonth && $year == $lyear ) ) {
        return -1;
    }
    if ($fulldate > $lstrip) {
        affatal("BUG: in nextmonth(). A date prior to the first in the"
        ." archive was passed in: p:$fulldate f:$fstrip");
    }

    while (1) {
        if ($month == 12) {
            $month = 1;
            $year++;
        } else {
            $month++;
        }
        fdn($month);

        if ($monthhasstrip{$year}{$month}) {
            $day = 1; fdn($day);
            my $ret = "$year$month$day";
            unless ($dayhasstrip{$year}[$month][$day]) {
                $ret = nextstrip("$year$month$day");
            }
            return $ret;
        }
    }
}

sub make_headers {
    # This generates any headers required for Javascripty things later on.
    # Headers on!  Apply directly to website!  Headers on!  Apply directly to website!

    # First, if headers have been thrown already, complain.
    if($headers_placed) {
        return "ERROR: The headers have already been declared for this page!";
    }

    my $headeroutput;

    $headers_placed = 1;

    # For future use, this will parse any header-requiring option to output
    # what needs to be output.  First, though, if no headers are needed,
    # just give up now.

    ### FIXME: Later, with more options, this would be a big if statement of
    ### all of them ORed together.
    if($storyline_use_javascript == 1) {
        $headeroutput .= qq(<script type="text/javascript">\n<!--\n\n);
    } else {
        return $headeroutput;
    }

    # Now, parse out each header option.
    if($storyline_use_javascript == 1) {
        # Storyline headers (simple redirector, acted upon by go button)
        $headeroutput .= "function ".$js_prefix."story_go() {\n";
                $headeroutput .= "\tvar stories = document.getElementsByName(\"".$js_prefix."story\")[0];\n";
        $headeroutput .= "\tif (stories.value != \"NULL\") {\n";
        $headeroutput .= "\t\tlocation.href=stories.value;\n";
        $headeroutput .= "\t}\n";
        $headeroutput .= "}\n\n";
    }

    # End of headers (assuming there were any)
    $headeroutput .= "//-->\n";
    $headeroutput .= "</script>\n";

    return $headeroutput;
}

sub reltoabs {
    # This function hopefully converts any relative URL to an absolute one.

    my $convert = shift;

    # Basically, all we can check for is whether or not there's a protocol
    # declaration in the URL.  I can think of two protocols in common use and
    # one that might get fringe use, and probably a few other fringes that
    # get use that I don't know of, so we can only check for a protocol.

    return $convert if ($convert =~ /\:\/\// or $convert =~ /^mailto\:/);

    # To arms, men!

    if($convert =~ /^\//){
        # Relative to the root of the site
        return $url.$convert;
    } else {
        # Must be relative to the archive pages
        return $url.$conf{dailydir}.$convert;
    }

    return "HEY!  reltoabs() exploded!";
}

sub fetch_include {
    # Working with the forces of %includecache, fetch_include fights to
    # reduce parsing time by always remembering includes so we don't need
    # to keep reopening the same file for every comic in a five hundred
    # comic archive.

    my $file = shift;
    if(exists $includecache{$file}) {
        # Success!  We already know of this and can return it at once!
        return $includecache{$file};
    } else {
        # We don't know of this file yet.  Let's rectify this situation.
        open(FILE, $file) or return "ERROR: Can't open include file $file!";
        $includecache{$file} = join '', <FILE>;
        close(FILE);
        return $includecache{$file};
    }

    return "HEY!  fetch_include() exploded!";
}

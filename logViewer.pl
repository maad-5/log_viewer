#!/usr/bin/perl

use strict;
use warnings;

use feature 'say';

####################################################################################################
## SUB-ROUTINES FORWARD DECLARATION ##
####################################################################################################

sub case_heartbeat;
sub case_message;
sub case_pfx;
sub case_regular;
sub case_timestamp;

####################################################################################################
## OPTIONS VALIDATION ##
####################################################################################################

my %unique_options;

# Validate options' correctness.
foreach my $arg (@ARGV) {
    # Die if the current argument is ill-formed (i.e. not made of  lower case letters).
    die "Ill-formed argument: '$arg'. Script aborted.\n" if $arg !~ m/^-[a-z]+$/;

    # Trim the leading hyphen.
    $arg =~ s/-//;

    # Map the string into an array.
    my @list_of_options = split(//, $arg);

    # For each option, check if it's valid and not a redefinition.
    foreach my $opt (@list_of_options) {
        die "Incorrect option: '$opt'. Script aborted.\n" if $opt !~ m/[ehopt]/;
        die "Redefinition of option: '$opt'. Script aborted.\n" if $unique_options{$opt}++;
    }
}

# Evaluate each option given to the script.
if ($unique_options{"h"}) {
    my ($r, $b) = ("\e[0m", "\e[1m");

    say "\n" . $b . "_NAME:" . $r;
    say "\tlogViewer.pl";
    say "\n" . $b . "_DESCRIPTION:" . $r;
    say "\tA Perl script to pretty-print back-ends log files.";
    say "\tIt reads the STDIN only, and output in the STDOUT.";
    say "\n" . $b . "_OPTIONS:" . $r;
    say "\t" . $b . "-h" . $r;
    say "\t\tDisplay this help, then exit the script.";
    say "\t" . $b . "-t" . $r;
    say "\t\tCollapse the timestamp in front of each entry.";
    say "\t" . $b . "-o" . $r;
    say "\t\tCollapse the hostname part of each entry.";
    say "\t" . $b . "-p" . $r;
    say "\t\tCollapse the PFX part of each entry.";
    say "\t" . $b . "-e" . $r;
    say "\t\tCollapse the \"SEI heartbeat\" in a condensed way.";
    say "\n" . $b . "_EXAMPLE:" . $r;
    say "\ttailf myLogFile | logViewer.pl -top\n";

    exit;
}

# All script's options.
my $option_timestamp = $unique_options{"t"} ? 1 : 0;
my $option_hostname  = $unique_options{"o"} ? 1 : 0;
my $option_pfx       = $unique_options{"p"} ? 1 : 0;
my $option_heartbeat = $unique_options{"e"} ? 1 : 0;

####################################################################################################
## COLORS DEFINITION ##
####################################################################################################

# "Group" colors.
my $c_APP = "\e[38;5;33m";
my $c_DB  = "\e[38;5;163m";
my $c_MDW = "\e[38;5;163m";

# "Level" colors.
my $c_INFO  = "\e[38;5;46m";
my $c_NOT   = "\e[38;5;120m";
my $c_STAT  = "\e[38;5;120m";
my $c_ERROR = "\e[38;5;196m";
my $c_WARN  = "\e[38;5;226m";
my $c_DBG   = "\e[38;5;227m";

# Miscellaneous.
my $c_message = "\e[38;5;75m";  # For messages (XML or cryptic).
my $c_time    = "\e[38;5;87m";  # For timestamp.
my $c_file    = "\e[38;5;170m"; # For filename.
my $c_host    = "\e[38;5;208m"; # For hostname.
my $c_pfx     = "\e[38;5;245m"; # For PFX.

# Output formatting.
my $c_reset    = "\e[0m";
my $c_inverted = "\e[7m";

####################################################################################################
## REGEXP AND VARIABLES DEFINITION ##
####################################################################################################

# All the regex matching patterns.
my $r_date      = qr/\d{4}\/\d{2}\/\d{2}/;      # Matches "2016/11/05".
my $r_time      = qr/\d{2}:\d{2}:\d{2}\.\d{6}/; # Matches "08:45:30.051095".
my $r_timestamp = qr/$r_date $r_time/;
my $r_pfx       = qr/\[PFX: [-A-Z:#\d\$]+\]/;    # Matches "[PFX: 007G2:15$TBH#00:2-2]".
my $r_filename  = qr/<[-\w]+\.\w+#\d+ TID#\d+>/; # Matches "<Tools.cpp#573 TID#4>".

# The buffer array which will hold two consecutives log entries.
my @buffer = ("", "");

####################################################################################################
## ENTRY POINT ##
####################################################################################################

# Main "while" loop, entry point of the script's logic. Processing done line by line, and outputting
# entry by entry.
while (my $line = <STDIN>) {
    # Pop the front element, and push back the current line.
    shift @buffer;
    push(@buffer, $line);

    # If the current line starts with a timestamp, process it...
    if ($line =~ /^$r_timestamp/) {
        chomp $buffer[0];

        case_heartbeat($buffer[0]);
        case_message  ($buffer[0]);
        case_regular  ($buffer[0]);
        case_pfx      ($buffer[0]);
        case_timestamp($buffer[0]);

        say $buffer[0];
    }
    # ...otherwise, append it to the buffer's front element, and put it at the buffer's end.
    else {
        $buffer[1] = $buffer[0] . $buffer[1];
    }
}

# Print the last line.
shift @buffer;
chomp $buffer[0];

case_heartbeat($buffer[0]);
case_message  ($buffer[0]);
case_regular  ($buffer[0]);
case_pfx      ($buffer[0]);
case_timestamp($buffer[0]);

say $buffer[0];

####################################################################################################
## SUB-ROUTINES DEFINITION ##
####################################################################################################

sub case_heartbeat {
    # return unless $_[0] =~ m/kSEIHeartbeat/;
    #
    # state $counter = 0;
    #
    # if ($counter++) {
    #     $_[0] =~ s/($r_filename) (.*)/$1 beep/;
    # }
    # else {
    #     $_[0] =~ s/.*//;
    # }
}

sub case_message {
    return unless $_[0] =~ m/^$r_timestamp $r_pfx (SENDER:|RECEIVER:)/;

    # Remove unnecessary information.
    $_[0] =~ s/(SENDER:|RECEIVER:) Nb=\d+ Len=\d+ //;

    # Sub-case: XML message.
    if ($_[0] =~ m/<\?xml/i) {
        $_[0] =~ s/[[:^print:]]/$c_inverted#$c_reset/g;
        $_[0] =~ s/(<\?xml.*?\?><(?'tag'[-_\w:.]+).*?>.*?<\/\g{tag}>)/$c_message$1$c_reset/is;
    }
    # Sub-case: cryptic message.
    elsif ($_[0] =~ m/[[:^print:]]/) {
        my $placeholder = "--- Full cryptic message (scrapped) ---";

        $_[0] =~ s/^($r_timestamp $r_pfx).*/$1 $c_message$placeholder$c_reset/s;
    }
}

sub case_pfx {
    return unless $_[0] =~ m/$r_pfx/;

    if ($option_pfx) {
        $_[0] =~ s/$r_pfx/$c_pfx\[PFX: ...\]$c_reset/;
    }
    else {
        $_[0] =~ s/($r_pfx)/$c_pfx$1$c_reset/;
    }
}

sub case_regular {
    return unless $_[0] =~ m/^$r_timestamp \w+ [A-Z]+ [A-Z]+/;

    # Define a pattern matching array.
    # NOTE: below, @match_array[0] and @match_array[1] can be accessed without checking their
    # existence because the first statement of the sub-routine states they *do* exist.
    my @match_array = ($_[0] =~ m/^$r_timestamp \w+ ([A-Z]+) ([A-Z]+)( [a-zA-Z]+)?/);

    # Sub-case: group.
    if ($match_array[0] eq "DB") {
        $_[0] =~ s/(DB)/$c_DB$1$c_reset/;
    }
    elsif ($match_array[0] eq "APP") {
        $_[0] =~ s/(APP)/$c_APP$1$c_reset/;
    }
    elsif ($match_array[0] eq "MDW") {
        $_[0] =~ s/(MDW)/$c_MDW$1$c_reset/;
    }

    # Sub-case: level.
    if ($match_array[1] eq "INFO") {
        if (defined $match_array[2]) {
            $_[0] =~ s/(INFO [a-zA-Z]+)/$c_INFO$1$c_reset/;
        }
        else {
            $_[0] =~ s/(INFO)/$c_INFO$1$c_reset/;
        }
    }
    elsif ($match_array[1] eq "NOT") {
        $_[0] =~ s/(NOT)/$c_NOT$1$c_reset/;
    }
    elsif ($match_array[1] eq "STAT") {
        if (defined $match_array[2]) {
            $_[0] =~ s/(STAT [a-zA-Z]+)/$c_STAT$1$c_reset/;
        }
        else {
            $_[0] =~ s/(STAT)/$c_STAT$1$c_reset/;
        }

        $_[0] =~ s/($r_filename $r_pfx) (.*)/$1 $c_STAT$2$c_reset/;
    }
    elsif ($match_array[1] eq "ERROR") {
        $_[0] =~ s/(ERROR)( \[.*?\])?/$c_ERROR$c_inverted$1$c_reset$c_ERROR$2$c_reset/;
        $_[0] =~ s/($r_filename $r_pfx) (.*)/$1 $c_ERROR$2$c_reset/s;
    }
    elsif ($match_array[1] eq "WARN") {
        $_[0] =~ s/(WARN)( \[.*?\])?/$c_WARN$c_inverted$1$c_reset$c_WARN$2$c_reset/;
        $_[0] =~ s/($r_filename $r_pfx) (.*)/$1 $c_WARN$2$c_reset/s;
    }
    elsif ($match_array[1] eq "DBG") {
        $_[0] =~ s/(DBG)/$c_DBG$1$c_reset/;
    }

    # Sub-case: filename.
    $_[0] =~ s/($r_filename)/$c_file$1$c_reset/;

    # Sub-case: hostname.
    if ($option_hostname) {
        $_[0] =~ s/^($r_timestamp) \w+/$1 $c_host...$c_reset/;
    }
    else {
        $_[0] =~ s/^($r_timestamp) (\w+)/$1 $c_host$2$c_reset/;
    }
}

sub case_timestamp {
    if ($option_timestamp) {
        $_[0] =~ s/^$r_date ($r_time)/$c_time$1$c_reset/;
    }
    else {
        $_[0] =~ s/^($r_timestamp)/$c_time$1$c_reset/;
    }
}

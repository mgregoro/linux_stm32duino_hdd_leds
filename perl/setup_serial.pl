#!/usr/bin/env perl

use Device::SerialPort;

unless ($ARGV[0]) {
    warn "Usage: setup_serial.pl <serial_device>\n";
    warn " Also: make sure you are a member of the 'dialout' group or whatever, or have access\n";
    warn "       to the <serial_device> because if you run this script as root you have poor\n";
    warn "       computer hygiene\n";
    warn "  BTW: /dev/ttyACM0 is what the blue pill presents itself to me as in linux.  just\n";
    die  "       sayin\n";
}

if (-e "$ENV{HOME}/.config/perlserial.conf") {
    die "No.  $ENV{HOME}/.config/perlserial.conf exists.  Remove it or I ain't doing NOTHING.\n";
}

my $tty = Device::SerialPort->new($ARGV[0]) or die "Can't open @{[$ARGV[0]]} (are you in the 'dialout' group?): $!\n";

# configure serial 115200 bauds 8N1 for AOL
$tty->baudrate(115200);
$tty->databits(8);
$tty->stopbits(1);
$tty->parity('none');
$tty->read_char_time(0);

# 0.1s poll time;
$tty->read_const_time(100);

$tty->save("$ENV{HOME}/.config/perlserial.conf");

print "[info] perl serial spurter config has been configured as $ARGV[0]\n";
print "       you may now run serial_activity_spurter.pl to see the pretty\n";
print "       lights.\n";
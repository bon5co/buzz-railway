#!/usr/bin/perl
# Decode a NIP-19 npub (bech32) into the 64-char lowercase hex pubkey that
# buzz-relay requires (config.rs accepts *only* 64 hex chars; an npub is
# warn-and-ignored, which leaves the relay with no owner).
#
# The bech32 checksum is verified: a mistyped npub must fail loudly here rather
# than decode into a valid-looking hex key that silently locks the deployer out
# of their own relay.
use strict;
use warnings;

my $CHARSET = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';
my %V = map { substr($CHARSET, $_, 1) => $_ } 0 .. length($CHARSET) - 1;

sub polymod {
    my @values = @_;
    my @GEN = (0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3);
    my $chk = 1;
    for my $v (@values) {
        my $top = $chk >> 25;
        $chk = (($chk & 0x1ffffff) << 5) ^ $v;
        for my $i (0 .. 4) { $chk ^= $GEN[$i] if ($top >> $i) & 1 }
    }
    return $chk;
}

my $s = lc($ARGV[0] // '');
$s =~ s/^\s+|\s+$//g;
die "not bech32: no separator\n" unless (my $pos = rindex($s, '1')) > 0;
my ($hrp, $data) = (substr($s, 0, $pos), substr($s, $pos + 1));
die "not an npub (prefix '$hrp')\n" unless $hrp eq 'npub';
die "npub is too short\n" if length($data) < 7;

my @vals;
for my $c (split //, $data) {
    die "invalid bech32 character '$c'\n" unless exists $V{$c};
    push @vals, $V{$c};
}

my @expanded = ((map { ord($_) >> 5 } split //, $hrp), 0,
                (map { ord($_) & 31 } split //, $hrp), @vals);
die "bech32 checksum failed - check the key you pasted\n" unless polymod(@expanded) == 1;

my ($acc, $bits, $out) = (0, 0, '');
for my $v (@vals[0 .. $#vals - 6]) {
    $acc = ($acc << 5) | $v;
    $bits += 5;
    while ($bits >= 8) {
        $bits -= 8;
        $out .= sprintf('%02x', ($acc >> $bits) & 0xff);
    }
}
die "decoded key is " . length($out) . " chars, expected 64\n" unless length($out) == 64;
print "$out\n";

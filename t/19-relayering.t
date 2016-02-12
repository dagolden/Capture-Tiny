# Copyright (c) 2009 by David Golden. All rights reserved.
# Licensed under Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the License.
# A copy of the License was distributed with this file or you may obtain a
# copy of the License from http://www.apache.org/licenses/LICENSE-2.0

use strict;
use warnings;
use Test::More;
use lib 't/lib';
use Utils qw/next_fd sig_num/;
use Capture::Tiny ':all';

unless ( PerlIO->can('get_layers') ) {
    plan skip_all => "Requires PerlIO::getlayers";
}

plan 'no_plan';

local $ENV{PERL_CAPTURE_TINY_TIMEOUT} = 0; # no timeouts

my $builder = Test::More->builder;
binmode( $builder->failure_output, ':utf8' ) if $] >= 5.008;

my $fd = next_fd;
my ( $out, $err, $res, @res, %before, %inner, %outer );

sub _set_layers {
    my ($fh, $new_layers) = @_;
    # eliminate pseudo-layers
    binmode( $fh, ":raw" ) or die "can't binmode $fh";
    # strip off real layers until only :unix is left
    while ( 1 < ( my $layers =()= PerlIO::get_layers( $fh, output => 1 ) ) ) {
        binmode( $fh, ":pop" )  or die "can't binmode $fh";
    }
    binmode($fh, $new_layers);
}

sub _get_layers {
    return (
        stdout => [ PerlIO::get_layers( *STDOUT, output => 1 ) ],
        stderr => [ PerlIO::get_layers( *STDERR, output => 1 ) ],
    );
}

sub _cmp_layers {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my ($got, $exp, $label) = @_;

    ($got, $exp) = map { ":" . join(":", @$_) } $got, $exp;
    is( $got, $exp, $label );
}

#--------------------------------------------------------------------------#
# relayer should duplicate layers
#--------------------------------------------------------------------------#

_set_layers( \*STDOUT, ":unix:encoding(UTF-8):encoding(UTF-8):crlf" );
_set_layers( \*STDERR, ":unix:encoding(UTF-8):encoding(UTF-8):crlf" );

%before = _get_layers();

( $out, $err, @res ) = capture {
    %inner = _get_layers();
    print STDOUT "foo\n";
    print STDERR "bar\n";
};

%outer = _get_layers();

_cmp_layers( $inner{$_}, $before{$_}, "$_: layers inside capture match previous" )
  for qw/stdout stderr/;
_cmp_layers( $outer{$_}, $before{$_}, "$_: layers after capture match previous" )
  for qw/stdout stderr/;

#--------------------------------------------------------------------------#
# finish
#--------------------------------------------------------------------------#

is( next_fd, $fd, "no file descriptors leaked" );

exit 0;
# vim: set ts=4 sts=4 sw=4 et tw=75:

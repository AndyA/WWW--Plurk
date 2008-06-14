use strict;
use warnings;
use Test::More tests => 1;

package Fake::Plurk;
use strict;
use warnings;
use base qw( WWW::Plurk );

package main;

ok 1, 'is OK';

use strict;
use warnings;
use WWW::Plurk;
use Test::More;

if ( my $plurk_env = $ENV{PLURK_TEST_ACCOUNT} ) {
    my ( $user, $pass ) = split /:/, $plurk_env, 2;
    plan tests => 1;
    ok 1;
    my $plurk = WWW::Plurk->new;
    $plurk->login( $user, $pass );
}
else {
    plan skip_all =>
      'Set $ENV{PLURK_TEST_ACCOUNT} to "user:pass" to run these tests';
}


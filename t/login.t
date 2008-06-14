use strict;
use warnings;
use WWW::Plurk;
use Test::More;
use Test::Deep;

if ( my $plurk_env = $ENV{PLURK_TEST_ACCOUNT} ) {
    my ( $user, $pass ) = split /:/, $plurk_env, 2;
    plan tests => 2;
    my $plurk = WWW::Plurk->new;
    $plurk->login( $user, $pass );
    is $plurk->nick_name, $user, "nick name";

    my @friends = $plurk->friends;
    cmp_deeply [@friends], array_each( isa( 'WWW::Plurk::Friend' ) ),
      "friends";

    # $plurk->add_plurk(
    #     qualifier => 'is',
    #     content   => 'testing WWW::Plurk repeatedly'
    # );
}
else {
    plan skip_all =>
      'Set $ENV{PLURK_TEST_ACCOUNT} to "user:pass" to run these tests';
}


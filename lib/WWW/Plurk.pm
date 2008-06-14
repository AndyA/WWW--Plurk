package WWW::Plurk;

use warnings;
use strict;
use Carp;
use LWP::UserAgent;
use HTTP::Cookies;
use HTML::Tiny;
use JSON;
use DateTime::Format::Mail;
use WWW::Plurk::Friend;

=head1 NAME

WWW::Plurk - Unoffical plurk.com API

=head1 VERSION

This document describes WWW::Plurk version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

    use WWW::Plurk;
  
=head1 DESCRIPTION

Based on Ryan Lim's unofficial PHP API: L<http://code.google.com/p/rlplurkapi/>

=cut

# Default API URIs

my $BASE_DEFAULT = 'http://www.plurk.com';

my %PATH_DEFAULT = (
    login             => '/Users/login?redirect_page=main',
    add_plurk         => '/TimeLine/addPlurk',
    notifications     => '/Notifications',
    accept_friend     => '/Notifications/allow',
    deny_friend       => '/Notifications/deny',
    get_friends       => '/Users/getFriends',
    get_plurks        => '/TimeLine/getPlurks',
    add_response      => '/Responses/add',
    get_responses     => '/Responses/get2',
    get_unread_plurks => '/TimeLine/getUnreadPlurks',
    get_completion    => '/Users/getCompletion',
    home              => undef,
);

BEGIN {
    my @ATTR = qw(
      base_uri
      info
      state
    );

    my @INFO = qw(
      full_name
      nick_name
      uid
    );

    for my $attr ( @ATTR ) {
        no strict 'refs';
        *{$attr} = sub {
            my $self = shift;
            return $self->{$attr} unless @_;
            return $self->{$attr} = shift;
        };
    }

    for my $info ( @INFO ) {
        no strict 'refs';
        *{$info} = sub { shift->info->{$info} };
    }
}

=head1 INTERFACE 

=head2 C<< new >>

=cut

sub new {
    my $class = shift;
    my $self  = bless {
        base_uri => $BASE_DEFAULT,
        path     => {%PATH_DEFAULT},
        state    => 'init',
    }, $class;
    return $self;
}

sub _make_ua {
    my $self = shift;
    my $ua   = LWP::UserAgent->new;
    $ua->agent( join ' ', __PACKAGE__, $VERSION );
    $ua->cookie_jar( HTTP::Cookies->new );
    return $ua;
}

sub _ua {
    my $self = shift;
    return $self->{_ua} ||= $self->_make_ua;
}

sub _cookies { shift->_ua->cookie_jar }

sub _post {
    my ( $self, $service, $params ) = @_;
    my $resp
      = $self->_ua->post( $self->uri_for( $service ), $params || {} );
    croak $resp->status_line
      unless $resp->is_success
          or $resp->is_redirect;
    return $resp;
}

sub _get {
    my ( $self, $service, $params ) = @_;
    my $resp
      = $self->_ua->get( $self->uri_for( $service, $params || {} ) );
    croak $resp->status_line
      unless $resp->is_success
          or $resp->is_redirect;
    return $resp;
}

=head2 C<< login >>

=cut

sub login {
    my ( $self, $name, $pass ) = @_;

    my $resp = $self->_post(
        login => {
            nick_name => $name,
            password  => $pass,
        }
    );

    my $ok = 0;
    $self->_cookies->scan( sub { $ok++ if $_[1] eq 'plurkcookie' } );
    croak "Login for $name failed, no cookie returned"
      unless $ok;

    $self->path_for( home => $resp->header( 'Location' )
          || "/user/$name" );

    $self->_parse_user_home;
    $self->state( 'login' );
}

sub _parse_time {
    my ( $self, $time ) = @_;
    return DateTime::Format::Mail->parse_datetime( $time )->epoch;
}

sub _decode_json {
    my ( $self, $json ) = @_;

    # Plurk actually returns JS rather than JSON.
    $json =~ s{ new \s+ Date \s* \( \s* " (.+?) " \s* \) }
        { $self->_parse_time( $1 ) }xeg;

    return decode_json $json;
}

sub _parse_user_home {
    my $self = shift;
    my $resp = $self->_get( 'home' );
    if ( $resp->content =~ /^\s*var\s+GLOBAL\s*=\s*(.+)$/m ) {
        my $global = $self->_decode_json( $1 );
        $self->info(
            $global->{session_user}
              or croak "No session_user data found"
        );
    }
    else {
        croak "Can't find GLOBAL data on user page";
    }
}

=head2 C<< is_logged_in >>

=cut

sub is_logged_in { shift->state eq 'login' }

sub _logged_in {
    my $self = shift;
    croak "Please login first"
      unless $self->is_logged_in;
}

=head2 C<< friends >>

=cut

sub _get_friends {
    my $self = shift;
    $self->_logged_in;
    my $friends = decode_json $self->_get(
        get_completion => { user_id => $self->uid } )->content;
    return [
        map { WWW::Plurk::Friend->new( $_, $friends->{$_} ) }
          keys %$friends
    ];
}

sub friends {
    my $self = shift;
    return @{ $self->{friends} ||= $self->_get_friends };
}

=head2 C<< path_for >>

=cut

sub path_for {
    my ( $self, $service ) = ( shift, shift );
    croak "Unknown service $service"
      unless exists $PATH_DEFAULT{$service};
    return $self->{path}{$service} unless @_;
    return $self->{path}{$service} = shift;
}

=head2 C<< uri_for >>

Return the uri for part of the service

=cut

sub uri_for {
    my ( $self, $service ) = ( shift, shift );
    my $uri = $self->base_uri . $self->path_for( $service );
    return $uri unless @_;
    my $params = shift;
    return join '?', $uri, HTML::Tiny->new->query_encode( $params );
}

=head2 C<< base_uri >>

=head2 C<< info >>

=head2 C<< state >>

=head2 C<< nick_name >>

=head2 C<< full_name >>

=head2 C<< uid >>

=cut

1;
__END__

=head1 CONFIGURATION AND ENVIRONMENT
  
WWW::Plurk requires no configuration files or environment variables.

=head1 DEPENDENCIES

None.

=head1 INCOMPATIBILITIES

None reported.

=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-www-plurk@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.

=head1 AUTHOR

Andy Armstrong  C<< <andy.armstrong@messagesystems.com> >>

L<< http://www.plurk.com/user/AndyArmstrong >>

=head1 LICENCE AND COPYRIGHT

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

Copyright (c) 2008, Message Systems, Inc.
All rights reserved.

Redistribution and use in source and binary forms, with or
without modification, are permitted provided that the following
conditions are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in
      the documentation and/or other materials provided with the
      distribution.
    * Neither the name Message Systems, Inc. nor the names of its
      contributors may be used to endorse or promote products derived
      from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER
OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

package WWW::Plurk;

use warnings;
use strict;

use Carp;
use DateTime::Format::Mail;
use HTML::Tiny;
use HTTP::Cookies;
use JSON;
use LWP::UserAgent;
use Time::Piece;
use WWW::Plurk::Friend;
use WWW::Plurk::Message;

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

use constant MAX_MESSAGE_LENGTH => 140;

my $BASE_DEFAULT = 'http://www.plurk.com';

my %PATH_DEFAULT = (
    accept_friend     => '/Notifications/allow',
    add_plurk         => '/TimeLine/addPlurk',
    add_response      => '/Responses/add',
    deny_friend       => '/Notifications/deny',
    get_completion    => '/Users/getCompletion',
    get_friends       => '/Users/getFriends',
    get_plurks        => '/TimeLine/getPlurks',
    get_responses     => '/Responses/get2',
    get_unread_plurks => '/TimeLine/getUnreadPlurks',
    home              => undef,
    login             => '/Users/login?redirect_page=main',
    notifications     => '/Notifications',
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
        *{$info} = sub {
            my $self = shift;
            # Info attributes only available when logged in
            $self->_logged_in;
            return $self->info->{$info};
        };
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

sub _json_post {
    my $self = shift;
    return $self->_decode_json( $self->_post( @_ )->content );
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

sub _json_get {
    my $self = shift;
    return $self->_decode_json( $self->_get( @_ )->content );
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

    my %strings    = ();
    my $next_token = 1;

    my $tok = sub {
        my $str = shift;
        my $key = sprintf '#%d#', $next_token++;
        $strings{$key} = $str;
        return qq{"$key"};
    };

    # Stash string literals to avoid false positives
    $json =~ s{ " ( (?: \\. | [^\\"]+ )* ) " }{ $tok->( $1 ) }xeg;

    # Plurk actually returns JS rather than JSON.
    $json =~ s{ new \s+ Date \s* \( \s* " (\#\d+\#) " \s* \) }
        { $self->_parse_time( $strings{$1} ) }xeg;

    # Replace string literals
    $json =~ s{ " (\#\d+\#) " }{ qq{"$strings{$1}"} }xeg;

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

=head2 C<< friends_for >>

=cut

sub friends_for {
    my $self = shift;
    my $for = $self->_uid_cast( shift || $self );
    $self->_logged_in;
    my $friends
      = $self->_json_get( get_completion => { user_id => $for } );
    return map { WWW::Plurk::Friend->new( $self, $_, $friends->{$_} ) }
      keys %$friends;
}

=head2 C<< friends >>

=cut

sub friends {
    my $self = shift;
    return $self->friends_for( $self );
}

=head2 C<< add_plurk >>

Post a new plurk.

    $plurk->add_plurk(
        content => 'Hello, World'
    );

=cut

sub _is_user {
    my ( $self, $obj ) = @_;
    return UNIVERSAL::can( $obj, 'can' ) && $obj->can( 'uid' );
}

sub _uid_cast {
    my ( $self, $obj ) = @_;
    return $self->_is_user( $obj ) ? $obj->uid : $obj;
}

sub add_plurk {
    my ( $self, @args ) = @_;
    croak "Needs a number of key => value pairs"
      if @args & 1;
    my %args = @args;

    my $content = delete $args{content} || croak "Must have content";
    my $lang    = delete $args{lang}    || 'en';
    my $qualifier = delete $args{qualifier} || 'says';
    my $no_comments = delete $args{no_comments};

    my @limit
      = map { $self->_uid_cast( $_ ) } @{ delete $args{limit} || [] };

    if ( my @extra = sort keys %args ) {
        croak "Unknown parameter(s): ", join ',', @extra;
    }

    if ( length $content > MAX_MESSAGE_LENGTH ) {
        croak 'Plurks are limited to '
          . MAX_MESSAGE_LENGTH
          . ' characters';
    }

    my $reply = $self->_json_get(
        add_plurk => {
            posted      => localtime()->datetime,
            qualifier   => $qualifier,
            content     => $content,
            lang        => $lang,
            no_comments => ( $no_comments ? 1 : 0 ),
            @limit
            ? ( limited_to => '[' . join( ',', @limit ) . ']' )
            : (),
        }
    );

    if ( my $error = $reply->{error} ) {
        croak "Error posting: $error";
    }

    return WWW::Plurk::Message->new( $reply->{plurk} );

}

=head2 C<< get_plurks >>

=cut

sub get_plurks {
    my ( $self, @args ) = @_;
    croak "Needs a number of key => value pairs"
      if @args & 1;
    my %args = @args;

    my $uid = $self->_uid_cast( delete $args{uid} || $self );

    my $responses   = delete $args{responses};
    my $date_from   = delete $args{date_from};
    my $date_offset = delete $args{date_offset};

    if ( my @extra = sort keys %args ) {
        croak "Unknown parameter(s): ", join ',', @extra;
    }

    my $reply = $self->_json_post(
        get_plurks => {
            user_id => $uid,
            defined $date_from
            ? ( from_date => gmtime( $date_from )->datetime )
            : (),
            defined $date_offset
            ? ( offset => gmtime( $date_offset )->datetime )
            : (),
        }
    );

    return map { WWW::Plurk::Message->new( $self, $_ ) } @{$reply};
}

=head2 C<< get_responses_for >>

=cut

sub get_responses_for {
    my ( $self, $plurk_id ) = @_;

    my $reply
      = $self->_json_post( get_responses => { plurk_id => $plurk_id } );

    use Data::Dumper;
    warn "# ", Dumper( $reply );
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

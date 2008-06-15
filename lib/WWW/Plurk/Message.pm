package WWW::Plurk::Message;

use warnings;
use strict;
use Carp;

=head1 NAME

WWW::Plurk::Message - A plurk message

=head1 VERSION

This document describes WWW::Plurk::Message version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

    use WWW::Plurk::Message;
  
=head1 DESCRIPTION

Based on Ryan Lim's unofficial PHP API: L<http://code.google.com/p/rlplurkapi/>

=cut

BEGIN {
    my @INFO = qw(
      content
      content_raw
      id
      is_mute
      is_unread
      lang
      limited_to
      no_comments
      owner_id
      plurk_id
      posted
      qualifier
      response_count
      responses_seen
      source
      user_id
      plurk
    );

    for my $info ( @INFO ) {
        no strict 'refs';
        *{$info} = sub { shift->{$info} };
    }
}

=head1 INTERFACE 

=head2 C<< new >>

=cut

sub new {
    my ( $class, $plurk, $detail ) = @_;
    return bless {
        plurk => $plurk,
        %$detail,
    }, $class;
}

=head2 C<< get_responses >>

=cut

sub get_responses {
    my $self = shift;
    return $self->plurk->get_responses_for( $self->plurk_id );
}

=head2 C<< content >>

=head2 C<< content_raw >>

=head2 C<< id >>

=head2 C<< is_mute >>

=head2 C<< is_unread >>

=head2 C<< lang >>

=head2 C<< limited_to >>

=head2 C<< no_comments >>

=head2 C<< owner_id >>

=head2 C<< plurk_id >>

=head2 C<< posted >>

=head2 C<< qualifier >>

=head2 C<< response_count >>

=head2 C<< responses_seen >>

=head2 C<< source >>

=head2 C<< user_id >>

=head2 C<< plurk >>

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

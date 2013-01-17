package Mojolicious::Plugin::Ident::Response;

use strict;
use warnings;
use base qw( AnyEvent::Ident::Response );

# ABSTRACT: Ident response object
# VERSION

=head1 DESCRIPTION

This class represents the responses as they come back
from the remote ident server.

L<Mojolicious::Plugin::Ident::Response> is a L<AnyEvent::Ident::Response>.
The base class is subject to change in a future version, although it
this class will always provide the interface documented here.

=head1 ATTRIBUTES

=head2 $ident-E<gt>username

The username of the remote connection as provided by
the remote ident server.

=head2 $ident-E<gt>os

The operating system of the remote connection as provided
by the remote ident server.

=head2 $ident-E<gt>is_success

True if the ident response was not an error.  Only
useful in non-blocking mode, as in blocking mode an
exception will be thrown in the case of error.

=head2 $ident-E<gt>error_type

The error type returned by the ident server, if an error
happened.  Only useful in non-blocking mode, as in blocking
mode an exception will be thrown in the case of error.

=cut

my $server_user_uid;
my $server_user_name;

sub _server_user_uid  { $server_user_uid  }
sub _server_user_name { $server_user_name }

sub _setup
{
  if($^O eq 'MSWin32')
  {
    $server_user_name = $ENV{USERNAME};
  }
  else
  {
    $server_user_uid  = $<;
    $server_user_name = scalar getpwuid($<);
  }
  die "could not determine username"
    unless defined $server_user_name
    &&     $server_user_name;
}

=head1 METHODS

=head2 $ident-E<gt>same_user

Returns true if the remote user is the same as the one which started the 
Mojolicious application.  The user is considered the same if the remote 
connection came over the loopback address (127.0.0.1) and the username 
matches either the server's username or real uid.

=cut

sub same_user
{
  my($self) = @_;
  return unless $self->{remote_address} eq '127.0.0.1';
  return 1 if $self->username eq $server_user_name;
  return 1 if defined $server_user_uid && $self->username =~ /^\d+$/ && $self->username == $server_user_uid;
  return;
}

1;

=head1 SEE ALSO

L<Mojolicious::Plugin::Ident>,
L<AnyEvent::Ident::Response>

=cut

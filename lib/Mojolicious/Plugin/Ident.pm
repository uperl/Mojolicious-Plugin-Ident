package Mojolicious::Plugin::Ident;

use Mojo::Base 'Mojolicious::Plugin';
use Net::Ident;
use Socket qw( pack_sockaddr_in inet_aton );
use Mojo::Exception;
use v5.10;
use Carp qw( croak );

# ABSTRACT: Mojo plugin to interact with an ident server
# VERSION

=head1 SYNOPSIS

 use Mojolicious::Lite;
 plugin 'ident';
 
 # get the username of the remote using ident protocol
 get '/' => sub {
   my $self = shift;
   $self->render_text("hello " . $self->ident->username);
 };
 
 # only allow access to the user on localhost which 
 # started the mojolicious lite app
 under sub { shift->ident_same_user };
 
 get '/private' => sub {
   shift->render_text("secret place");
 };

=head1 DESCRIPTION

This is a plugin to easily interact with ident authentication
server running on the remote server.

=head1 HELPERS

=head2 $controller-E<gt>ident

Returns an instance of L<Mojolicious::Plugin::Ident::Response>, which
has two fields, username and os.

 get '/' => sub {
   my $self = shift;
   my $ident = $self->ident;
   $self->render_text(
     "username: " . $ident->username .
     "os:       " . $ident->os
   );
 };

Throws an exception if

=over 4

=item * it cannot connect to the remote's ident server

=item * the connection to the remote's ident server times out

=item * the remote ident server returns an error

=back

=head2 $controller-E<gt>ident_same_user

Returns true if and only if the remote user is the same as the user
who started the mojolicious server.  Only returns true if the user
connects using the loopback address (127.0.0.1).

Does not thow an exception if a connection or ident error is detected.
In this case it will note an error in the log and return false.

=cut

sub register
{
  my($self, $app, $conf) = @_;

  $app->helper(ident => sub {
    my($controller, $tx, $timeout) = @_;
    $tx //= $controller->tx;
    my $ident = Net::Ident->newFromInAddr(
      pack_sockaddr_in($tx->local_port, inet_aton($tx->local_address)),
      pack_sockaddr_in($tx->remote_port, inet_aton($tx->remote_address)),
      $timeout // 2,
    );
    my($username, $os, $error) = $ident->username;

    if($error)
    {
      die Mojo::Exception->new("ident error: $error");
    }

    return bless { os => $os, username => $username }, 'Mojolicious::Plugin::Ident::Response';
  });

  my $server_user_uid;
  my $server_user_name;
  if($^O eq 'MSWin32')
  {
    $server_user_name = $ENV{USERNAME};
  }
  else
  {
    $server_user_uid  = $<;
    $server_user_name = scalar getpwuid($<);
  }
  
  croak "could not determine server username"
    unless $server_user_name;
  
  # FIXME should not throw an exception
  # on error, just return 0 (unlike ident)
  # FIXME add logging to both helpers.
  # FIXME cache results of ident_same_user
  # in cookies (optionally).
  # FIXME make timeout configurable.
  $app->helper(ident_same_user => sub {
    my $controller = shift;
    return unless $controller->tx->remote_address eq '127.0.0.1';
    my $ident = $controller->ident(@_);
    if($ident->username =~ /^\d+$/ && defined $server_user_uid)
    {
      return $ident->username == $server_user_uid;
    }
    else
    {
      return $ident->username eq $server_user_name;
    }
  });
}

package
  Mojolicious::Plugin::Ident::Response;

use Mojo::Base -base;

has 'os';
has 'username';

1;

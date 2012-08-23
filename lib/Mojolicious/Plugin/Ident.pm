package Mojolicious::Plugin::Ident;

use strict;
use warnings;
use v5.10;
use Mojo::Base 'Mojolicious::Plugin';
use Net::Ident;
use Socket qw( pack_sockaddr_in inet_aton );
use Mojo::Exception;
use Mojolicious::Plugin::Ident::Response;

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
 under sub { eval { shift->ident->same_user } };
 
 get '/private' => sub {
   shift->render_text("secret place");
 };

=head1 DESCRIPTION

This is a plugin to easily interact with ident authentication
server running on the remote server.

=head1 OPTIONS

=head2 timeout

Number of seconds to wait before timing out in the connection with the
remote ident server.  The default is 2.

=head1 HELPERS

=head2 ident [ $tx, [ $timeout ] ]

Optionally takes a transaction and timeout arguments.  If not specified
the current transaction and the configured default will be used.

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

It also has a same_user method which can be use to determine if the
user on the server and the remote are the same.  The user is considered
the same if the remote connection came over the loopback address
(127.0.0.1) and the username matches either the server's username or 
real uid.

 under sub { shift->ident_same_user };
 get '/private' => 'private_route';

Throws an exception if

=over 4

=item * it cannot connect to the remote's ident server

=item * the connection to the remote's ident server times out

=item * the remote ident server returns an error

=back

=head2 ident_same_user [ $tx, [ $timeout ] ]

Optionally takes a transaction and timeout arguments.  If not specified
the current transaction and the configured default will be used.

Returns true if the user on the server and the remote are the same.  The
user is considered the same if the remote connection came over the loopback
address (127.0.0.1) and the username matches either the server's username
or real uid.

Returns false if the user is not the same or on any kind of error.  Does
not throw an exception in the case of connection or ident error.

=cut

sub register
{
  my($self, $app, $conf) = @_;

  Mojolicious::Plugin::Ident::Response->_setup;

  my $default_timeout = $conf->{timeout} // 2;

  $app->helper(ident => sub {
    my($controller, $tx, $timeout) = @_;
    $tx //= $controller->tx;
    my $ident = Net::Ident->newFromInAddr(
      pack_sockaddr_in($tx->local_port, inet_aton($tx->local_address)),
      pack_sockaddr_in($tx->remote_port, inet_aton($tx->remote_address)),
      $timeout // $default_timeout,
    );
    my($username, $os, $error) = $ident->username;

    if($error)
    {
      my $error = "ident error: $error";
      $app->log->error($error);
      die Mojo::Exception->new($error);
    }

    Mojolicious::Plugin::Ident::Response->new( 
      os             => $os,
      username       => $username,
      remote_address => $tx->remote_address,
    );
  });
  
  $app->helper(ident_same_user => sub {
    my $controller = shift;
    $controller->session('ident_same_user') // do {
      my $same_user = eval { $controller->ident(@_)->same_user };
      return if $@;
      $controller->session('ident_same_user' => $same_user);
      $same_user;
    };
  });
}

1;

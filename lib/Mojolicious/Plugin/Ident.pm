package Mojolicious::Plugin::Ident;

use strict;
use warnings;
use v5.10;
use Mojo::Base 'Mojolicious::Plugin';
use Net::Ident;
use Socket qw( pack_sockaddr_in inet_aton );
use Mojo::Exception;
use Mojolicious::Plugin::Ident::Response;

# ABSTRACT: Mojolicious plugin to interact with a remote ident service
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

This plugin provides an interface for querying an ident service on a 
remote system.  The ident protocol helps identify the user of a 
particular TCP connection.  If the remote client connecting to your 
Mojolicious application is running the ident service you can identify 
the remote users' name.  This can be useful for determining the source 
of abusive or malicious behavior.  Although ident can be used to 
authenticate users, it is not recommended for untrusted networks and 
systems (see CAVEATS below).

Under the covers this plugin uses L<Net::Ident>.

=head1 OPTIONS

=head2 timeout

 plugin 'ident' => { timeout => 60 };

Default number of seconds to wait before timing out when contacting the remote
ident server.  The default is 2.

=head1 HELPERS

=head2 ident [ $tx, [ $timeout ] ]

 get '/' => sub {
   my $self = shift;
   my $ident = $self->ident;
   $self->render_text(
     "username: " . $ident->username .
     "os:       " . $ident->os
   );
 };

Returns an instance of L<Mojolicious::Plugin::Ident::Response>, which 
provides two fields, username and os for the remote connection.  This 
helper optionally takes two arguments, a transaction ($tx) and a timeout 
($timeout).  If not specified, the current transaction and the 
configured default timeout will be used.

The ident helper will throw an exception if

=over 4

=item * it cannot connect to the remote's ident server

=item * the connection to the remote's ident server times out

=item * the remote ident server returns an error

=back

 under sub { eval { shift->ident->same_user } };
 get '/private' => 'private_route';

The ident response class also has a same_user method which can be used
to determine if the user which started the Mojolicious application
and the remote user are the same.  The user is considered the same if the 
remote connection came over the loopback address (127.0.0.1) and the username
matches either the server's username or real UID.  Although this can be used
as a simple authentication method, keep in mind that it may not be secure,
especially on systems where untrusted users can bind to port 113, such as
Windows (see CAVEATS below).

=head2 ident_same_user [ $tx, [ $timeout ] ]

 under sub { shift->ident_same_user };
 get '/private' => 'private_route';

This helper returns true if the remote user is the same as the user 
which started the Mojolicious application.  This uses the same_user 
method on the ident response class described above.  If it is able to 
connect to the ident service on the remote system it will cache the 
result so that the remote ident service does not have to be contacted on 
every HTTP request.  If the user does not match, or if it is unable to 
contact the remote ident service, or if the connection times out it will 
return false.  Unlike the ident helper, this one will not throw an 
exception.  This helper optionally takes two arguments, a transaction 
($tx) and a timeout ($timeout).  If not specified, the current 
transaction and the configured default timeout will be used.

=head1 CAVEATS

In Windows and possibly other operating systems, an unprivileged user can
listen to port 113 and on any untrusted network, a remote ident server is
not a reliable source for an authentication mechanism.  Most modern operating
systems do not enable the ident service by default, so unless you have
control both the client and the server and can configure the ident service
securely on both, its usefulness is reduced.

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
      $controller->app->log->error($error);
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

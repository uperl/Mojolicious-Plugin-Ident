package Mojolicious::Plugin::Ident;

use strict;
use warnings;
use v5.10;
use Mojo::Base 'Mojolicious::Plugin';
use AnyEvent;
use AnyEvent::Ident::Client;
use Mojo::Exception;
use Mojolicious::Plugin::Ident::Response;

# ABSTRACT: Mojolicious plugin to interact with a remote ident service
# VERSION

=head1 SYNOPSIS

 use Mojolicious::Lite;
 plugin 'ident';
 
 # log the ident user for every connection (async ident)
 under sub {
   shift->ident(sub {
     my $id_res = shift; # $id_res isa Mojolicious::Plugin::Ident::Response
     if($id_res->is_success) {
       app->log->info("ident user is " . $id_res->username);
     } else {
       app->log->info("unable to ident remote user");
     }
   });

   1;
 };
 
 # get the username of the remote using ident protocol
 get '/' => sub {
   my $self = shift;
   my $id_res = $self->ident; # $id_res isa Mojolicious::Plugin::Ident::Response
   $self->render_text("hello " . $id_res->username);
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

Under the covers this plugin uses L<AnyEvent::Ident>.

=head1 OPTIONS

=head2 timeout

 plugin 'ident' => { timeout => 60 };

Default number of seconds to wait before timing out when contacting the remote
ident server.  The default is 2.

=head2 port

 plugin 'ident' => { port => 113 };

Port number to connect to.  Usually this will be 113, but you may want to change
this for testing or some other purpose.

=head1 HELPERS

=head2 ident [ $tx, [ $timeout ] ], [ $callback ]

This helper makes a ident request.  This helper takes two optional arguments,
a transaction C<$tx> and a timeout C<$timeout>.  If not specified, the current
transaction and the configured default timeout will be used.  If a callback
is provided then the request is non-blocking.  If no callback is provided,
it will block until a response comes back or the timeout expires.

With a callback (non-blocking):

 get '/' => sub {
   my $self = shift;
   $self->ident(sub {
     my $res = shift->res;
     if($res->is_success)
     {
       $self->render_text(
         "username: " . $res->username .
         "os:       " . $res->os
       );
     }
     else
     {
       $self->render_text(
         "error: " . $res->error_type
       );
     }
   };
 };

The callback is passed an instance of L<Mojolicious::Plugin::Ident::Response>.  Even if
the response is an error.  The C<is_success> method on L<Mojolicious::Plugin::Ident::Response>
will tell you if the response is an error or not.

Without a callback (blocking):

 get '/' => sub {
   my $self = shift;
   my $ident = $self->ident;
   $self->render_text(
     "username: " . $ident->username .
     "os:       " . $ident->os
   );
 };

Returns an instance of L<Mojolicious::Plugin::Ident::Response>, which 
provides two fields, username and os for the remote connection.

When called in blocking mode (without a callback), the ident helper will throw 
an exception if

=over 4

=item * it cannot connect to the remote's ident server

=item * the connection to the remote's ident server times out

=item * the remote ident server returns an error

=back

 under sub { eval { shift->ident->same_user } };
 get '/private' => 'private_route';

The ident response class also has a same_user method which can be used
to determine if the user which started the Mojolicious application and
the remote user are the same.  The user is considered the same if the
remote connection came over the loopback address (127.0.0.1) and the
username matches either the server's username or real UID.  Although
this can be used as a simple authentication method, keep in mind that it
may not be secure (see CAVEATS below).

=head2 ident_same_user [ $tx, [ $timeout ] ], [ $callback ]

This helper makes an ident request and attempts to determine if the 
user that made the request is the same as the one that started the
Mojolicious application.  This helper takes two optional arguments,
a transaction C<$tx> and a timeout C<$timeout>.  If not specified, the current
transaction and the configured default timeout will be used.  If a callback
is provided then the request is non-blocking.  If no callback is provided,
it will block until a response comes back or the timeout expires.

With a callback (non-blocking):

 get '/private' => sub {
   my $self = shift;
   $self->ident_same_user(sub {
     my $same_user = shift;
     $same_user ? $self->render_text('private text') : $self->render_not_found;
   });
 }

When the response comes back it will call the callback and pass in a boolean
value indicating if the user is the same.  If the ident request connects
and does not timeout, then result will be cached.  If cached the callback may
be called immediately, before re-entering the event loop.

Without a callback (blocking):

 under sub { shift->ident_same_user };
 get '/private' => 'private_route';

without a callback this helper will return true or false depending on
if the user is the same.  It should never throw an exception.

=head1 CAVEATS

L<The RFC for the ident protocol|http://tools.ietf.org/html/rfc1413>
clearly states that ident should not be used for authentication, at
most it should be used only for audit (for example annotating log
files).

In Windows and possibly other operating systems, an unprivileged user
can listen to port 113 and on any untrusted network, a remote ident
server is not a secure authentication mechanism.  Most modern operating
systems do not enable the ident service by default, so unless you have
control both the client and the server and can configure the ident
service securely on both, its usefulness is reduced.

Using this module in the non-blocking mode requires that L<AnyEvent> use 
its L<EV> implementation, which is also used by L<Mojolicious>, if it is 
loaded.  This shouldn't be a problem, as L<EV> is a prerequisite to this 
module (though it does not use it directly), and both L<AnyEvent> and 
L<Mojolicious> will prefer to use L<EV> if it is installed.  You do have 
to make sure that you do not force another event loop, such as 
L<AnyEvent::Loop>, unless you are using only the blocking mode.

=cut

sub register
{
  my($self, $app, $conf) = @_;

  Mojolicious::Plugin::Ident::Response->_setup;

  my $default_timeout = $conf->{timeout} // 2;
  my $port = $conf->{port} // 113;

  $app->helper(ident => sub {
    my $callback;
    $callback = pop if ref($_[-1]) eq 'CODE';
    my($controller, $tx, $timeout) = @_;
    $tx //= $controller->tx;
    $timeout //= $default_timeout;
    
    if($callback)
    {
      AnyEvent::Ident::Client
        ->new( response_class => 'Mojolicious::Plugin::Ident::Response', hostname => $tx->remote_address, port => $port )
        ->ident($tx->remote_port, $tx->local_port, sub {
          my $ident_response = shift;
          $ident_response->{remote_address} = $tx->remote_address;
          $callback->($ident_response) 
        }
      );
      return;
    }
    
    my $done = AnyEvent->condvar;
    
    my $w = AnyEvent->timer(after => $timeout // $default_timeout, cb => sub {
      $done->croak("ident timeout");
    });
    
    my $ident_response;
    
    AnyEvent::Ident::Client
      ->new( response_class => 'Mojolicious::Plugin::Ident::Response', hostname => $tx->remote_address, port => $port )
      ->ident($tx->remote_port, $tx->local_port, sub {
        $ident_response = shift;
        $ident_response->{remote_address} = $tx->remote_address;
        $done->send(1);
      }
    );
    
    $done->recv;
    undef $w;

    if($ident_response->is_success)
    {
      return $ident_response;
    }
    else
    {
      my $error = 'ident error: ' . $ident_response->error_type;
      $controller->app->log->error($error);
      die Mojo::Exception->new($error);
    }
  });
  
  $app->helper(ident_same_user => sub {
    my $callback;
    $callback = pop if ref($_[-1]) eq 'CODE';
    my $controller = shift;
    
    if($callback)
    {
      my($tx, $timeout) = @_;
      $tx //= $controller->tx;
      $timeout //= $default_timeout;
      
      if(defined $controller->session('ident_same_user'))
      {
        $callback->($controller->session('ident_same_user'));
      }
      else
      {
        $controller->ident($tx, $timeout, sub {
          my $res = shift;
          if($res->is_success)
          {
            my $same_user = $res->same_user;
            $controller->session('ident_same_user' => $same_user);
            $callback->($same_user);
          }
          else
          {
            $callback->(0);
          }
        });
      }
    }
    else
    {
      $controller->session('ident_same_user') // do {
        my $same_user = eval { $controller->ident(@_)->same_user };
        return if $@;
        $controller->session('ident_same_user' => $same_user);
        $same_user;
      };
    }
  });
}

1;

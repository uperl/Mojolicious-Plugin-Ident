package Mojolicious::Plugin::Ident;

use Mojo::Base 'Mojolicious::Plugin';
use Net::Ident;
use Socket qw( pack_sockaddr_in inet_aton );
use Mojo::Exception;

# ABSTRACT: Mojo plugin to interact with an ident server
# VERSION

sub register
{
  my($self, $app, $conf) = @_;

  $app->helper(ident => sub {
    my($controller, $tx) = @_;
    $tx //= $controller->tx;
    my $ident = Net::Ident->newFromInAddr(
      pack_sockaddr_in($tx->local_port, inet_aton($tx->local_address)),
      pack_sockaddr_in($tx->remote_port, inet_aton($tx->remote_address)),
      2
    );
    my($username, $os, $error) = $ident->username;

    if($error)
    {
      die Mojo::Exception->new("ident error: $error");
    }

    return bless { os => $os, username => $username }, 'Mojolicious::Plugin::Ident::Response';
  });
}

package
  Mojolicious::Plugin::Ident::Response;

use Mojo::Base -base;

has 'os';
has 'username';

1;

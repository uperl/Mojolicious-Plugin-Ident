use strict;
use warnings;
use Test::More tests => 10;
use Test::Mojo;

my @test_ident_data = ( 'foo', 'AwesomeOS', '' );
my $port;

eval q{
  package Net::Ident;

  $INC{'Net/Ident.pm'} = __FILE__;

  use Test::More;
  use Socket qw( unpack_sockaddr_in inet_ntoa );

  sub newFromInAddr
  {
    my($class, $local, $remote, $timeout) = @_;
    my($local_port, $local_address) = unpack_sockaddr_in $local;
    my($remote_port, $remote_address) = unpack_sockaddr_in $remote;

    ($local_address, $remote_address) = map { inet_ntoa($_) } ($local_address, $remote_address);

    is $local_port, $port, "local port = $port";
    like $remote_port, qr{^\d+$}, "remote_port = $remote_port";
    is $local_address, '127.0.0.1', 'local_address = 127.0.0.1';
    is $remote_address, '127.0.0.1', 'remote_address = 127.0.0.1';
    is $timeout, 2, 'timeout = 2';

    bless {}, 'Net::Ident';
  }

  sub username { @test_ident_data }
};
die $@ if $@;

use Mojolicious::Lite;
plugin 'ident';

get '/' => sub { shift->render_text('index') };

get '/ident' => sub {
  my($self) = @_;
  my $ident = $self->ident;
  $self->render_json({ username => $ident->username, os => $ident->os, remote_address => $ident->remote_address });
};

my $t = Test::Mojo->new;

$port = $t->ua->app_url->port;

$t->get_ok("http://127.0.0.1:$port/ident")
  ->status_is(200)
  ->json_is('/username',       'foo')
  ->json_is('/os',             'AwesomeOS')
  ->json_is('/remote_address', '127.0.0.1');


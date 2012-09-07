use strict;
use warnings;
use Test::More tests => 2;
use Test::Mojo;

my @test_ident_data = ( '', '', 'some ident error' );

eval q{
  package Net::Ident;

  $INC{'Net/Ident.pm'} = __FILE__;

  use Test::More;
  use Socket qw( unpack_sockaddr_in inet_ntoa );

  sub newFromInAddr
  {
    my($class, $local, $remote, $timeout) = @_;
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
  $self->render_text('okay!');
};

my $t = Test::Mojo->new;

$t->get_ok("/ident")
  ->status_is(500);

use strict;
use warnings;
use Test::More tests => 3;
use Test::Mojo;

my @test_ident_data = ( 'foo', 'AwesomeOS', '' );
my $timeout;

eval q{
  package Net::Ident;

  $INC{'Net/Ident.pm'} = __FILE__;

  sub newFromInAddr
  {
    my($class, $local, $remote, $op_timeout) = @_;
    $timeout = $op_timeout;
    bless {}, 'Net::Ident';
  }

  sub username { @test_ident_data }
};
die $@ if $@;

use Mojolicious::Lite;
plugin 'ident' => { timeout => 4 };

get '/' => sub { shift->render_text('index') };

get '/ident' => sub {
  my($self) = @_;
  my $ident = $self->ident;
  $self->render_text('good');
};

my $t = Test::Mojo->new;

$t->get_ok("/ident")
  ->status_is(200);

is $timeout, 4, 'timeout = 4';

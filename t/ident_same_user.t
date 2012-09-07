use strict;
use warnings;
use Test::More tests => 15;
use Test::Mojo;

my @test_ident_data = ( 'foo', 'AwesomeOS', '' );
my $execute_count = 0;

eval q{
  package Net::Ident;

  $INC{'Net/Ident.pm'} = __FILE__;

  use Test::More;
  use Socket qw( unpack_sockaddr_in inet_ntoa );

  sub newFromInAddr
  {
    my($class, $local, $remote, $timeout) = @_;
    $execute_count++;
    bless {}, 'Net::Ident';
  }

  sub username { @test_ident_data }
};
die $@ if $@;

use Mojolicious::Lite;
plugin 'ident';
under sub { shift->ident_same_user };
get '/ident' => sub { shift->render_text('okay') };

my $same_user;

eval q{
  no warnings qw( redefine );
  sub Mojolicious::Plugin::Ident::Response::same_user
  {
    $same_user;
  }
};
die $@ if $@;

my $t = Test::Mojo->new;

is $execute_count, 0, 'execute_count = 0';

$same_user = 1;
$t->get_ok("/ident")
  ->status_is(200);
is $execute_count, 1, 'execute_count = 1';
$t->get_ok("/ident")
  ->status_is(200);
is $execute_count, 1, 'execute_count = 1';

$t->reset_session;

$same_user = 0;
$t->get_ok('/ident')
  ->status_is(404);
is $execute_count, 2, 'execute_count = 2';
$t->get_ok('/ident')
  ->status_is(404);
is $execute_count, 2, 'execute_count = 2';

$t->reset_session;
@test_ident_data = ( '', '', 'ident error' );
$t->get_ok('/ident')
  ->status_is(404);

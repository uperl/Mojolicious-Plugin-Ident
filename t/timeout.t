use strict;
use warnings;
use Test::More tests => 2;
use Test::Mojo;
use AnyEvent::Ident qw( ident_server );
use Mojolicious::Lite;

plugin 'ident' => { 
  port => do {
    my $server = ident_server '127.0.0.1', 0, sub {
      my $tx = shift;
    };
    $server->bindport;
  },
  timeout => 1,
};

get '/' => sub { shift->render_text('index') };

get '/ident' => sub {
  my($self) = @_;
  my $ident = $self->ident;
  $self->render_text('okay!');
};

my $t = Test::Mojo->new;

$t->get_ok("/ident")
  ->status_is(500);

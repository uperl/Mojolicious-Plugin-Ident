#!/usr/bin/env perl

use Mojolicious::Lite;

plugin 'Ident';

helper c => sub { shift };

get '/' => sub {
  my $self = shift;
  $self->render;
} => 'index';

app->start;
__DATA__

@@ index.html.ep
% layout 'default';
% title 'ident test';
<table>
  <tr>
    <td>username:</td><td><%= ident->username %></td>
  </tr>
  </tr>
    <td>os</td><td><%= ident->os %></td>
  </tr>
  <tr>
    <td>local</td><td><%= c->tx->local_address %>:<%= c->tx->local_port %></td>
  </tr>
  <tr>
    <td>remote</td><td><%= c->tx->remote_address %>:<%= c->tx->remote_port %></td>
  </tr>
</table>

@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
  <head><title><%= title %></title></head>
  <body><%= content %></body>
</html>

use strict;
use warnings;
use Test::More;
BEGIN { 
  plan skip_all => 'test requires Test::EOL' 
    unless eval q{ use Test::Fixme; 1 };
};
use Test::Fixme;
use FindBin;
use File::Spec;

chdir(File::Spec->catdir($FindBin::Bin, File::Spec->updir, File::Spec->updir));

run_tests(
  match => qr/FIXME/,
  # TODO: update Test::Fixme to take filenames
  where => [ grep { -e $_ } qw( bin lib t )],
);


# $Id: 01ref.t 50 2007-09-24 12:08:17Z cfaerber $

use strict;
use utf8;

use Test::More tests => 3;

use Unicode::Stringprep;

my $prep = Unicode::Stringprep->new(
  3.2,
  [ ],
  '',
  [ ],
  0
);

is(ref $prep, 'Unicode::Stringprep', 'bless you');

*prep = $prep;
is(eval { prep('TEST') }, 'TEST', 'direct call');
is(eval { $prep->('TEST') }, 'TEST', 'indirect call');

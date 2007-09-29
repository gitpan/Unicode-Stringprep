# $Id: 00use.t 50 2007-09-24 12:08:17Z cfaerber $

use strict;
use Test::More tests=>5;

BEGIN { use_ok 'Unicode::Stringprep' }
BEGIN { use_ok 'Unicode::Stringprep::Unassigned' }
BEGIN { use_ok 'Unicode::Stringprep::Mapping' }
BEGIN { use_ok 'Unicode::Stringprep::Prohibited' }
BEGIN { use_ok 'Unicode::Stringprep::BiDi' }

# $Id: 00use.t 85 2009-12-10 19:00:14Z cfaerber $

use strict;
use Test::More tests=>6;
use Test::NoWarnings;

BEGIN { use_ok 'Unicode::Stringprep' }
BEGIN { use_ok 'Unicode::Stringprep::Unassigned' }
BEGIN { use_ok 'Unicode::Stringprep::Mapping' }
BEGIN { use_ok 'Unicode::Stringprep::Prohibited' }
BEGIN { use_ok 'Unicode::Stringprep::BiDi' }

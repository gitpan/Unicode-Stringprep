# $Id: Stringprep.pm 68 2007-10-06 10:14:44Z cfaerber $

package Unicode::Stringprep;

use strict;
use utf8;
require 5.006_000;

our $VERSION = '1.00';
$VERSION = eval $VERSION;

require Exporter;
our @ISA    = qw(Exporter);
our @EXPORT = qw(stringprep);

use Carp;

use Unicode::Normalize();

use Unicode::Stringprep::Unassigned;
use Unicode::Stringprep::Mapping;
use Unicode::Stringprep::Prohibited;
use Unicode::Stringprep::BiDi;

sub new {
  my $self  = shift;
  my $class = ref($self) || $self;
  return bless _compile(@_), $class;
}

## Here be eval dragons

sub _compile {
  my $unicode_version = shift;
  my $mapping_tables = shift;
  my $unicode_normalization = uc shift;
  my $prohibited_tables = shift;
  my $bidi_check = shift;

  croak 'Unsupported UNICODE version '.$unicode_version.'.' 
    unless $unicode_version == 3.2;

  my $mapping_sub = _compile_mapping($mapping_tables);
  my $normalization_sub = _compile_normalization($unicode_normalization);
  my $prohibited_sub = _compile_prohibited($prohibited_tables);
  my $bidi_sub = $bidi_check ? _compile_bidi() : undef;

  my $code = "sub { no warnings 'utf8';".
   'my $string = shift;'.
   join('', map { $_ ? "{$_}\n" : ''} (
      $mapping_sub,
      $normalization_sub,
      $prohibited_sub,
      $bidi_sub )).
      'return $string;'.
    '}';

  return eval $code || die $@;
}


sub _compile_mapping {
  my %map = ();
  sub _mapping_tables {
    my $map = shift;
    while(@_) {
      my $data = shift;
      if(ref($data) eq 'HASH') { %{$map} = (%{$map},%{$data}) }
      elsif(ref($data) eq 'ARRAY') { _mapping_tables($map,@{$data}) }
      else{ $map->{$data} = shift };
    }
  }
  _mapping_tables(\%map,@_);

  return '' if !%map;

  sub _compile_mapping_r { 
     my $map = shift;
     if($#_ <= 7) {
       return (join '', (map { '$char == '.$_.
        ' ? "'.(join '', map { s/[\/\$\@\%\&\\]/\\$1/g; $_; } ( $$map{$_} )).'"'.
        '   : ' } @_)).' die';
     } else {
      my @a = splice @_, 0, int($#_/2);
      return '$char < '.$_[0].' ? ('.
        _compile_mapping_r($map,@a).
	') : ('.
        _compile_mapping_r($map,@_).
	')';
     }
  };

  my @from = sort { $a <=> $b } keys %map;

  return sprintf '$string =~ s/([%s])/my $char = ord($1); %s /ge;',
    (join '', (map { sprintf '\\x{%04X}', $_; } @from)),
    _compile_mapping_r(\%map, @from);
}

sub _compile_normalization {
  my $unicode_normalization = shift;
  $unicode_normalization =~ s/^NF//;

  return '$string = Unicode::Normalize::NFKC($string)' if $unicode_normalization eq 'KC';
  return '' if $unicode_normalization eq '';

  croak 'Unsupported UNICODE normalization (NF)'.$unicode_normalization.'.';
}

sub _compile_set {
  my @collect = ();
  sub _set_tables {
    my $set = shift;
    while(@_) {
      my $data = shift;
      if(ref($data) eq 'HASH') { _set_tables($set, %{$data}); }
      elsif(ref($data) eq 'ARRAY') { _set_tables($set, @{$data}); }
      else{ push @{$set}, [$data,shift || $data] };
    }
  }
  _set_tables(\@collect,@_);

  # NB: This destroys @collect as it modifies the anonymous ARRAYs
  # referenced in @collect.
  # This is harmless as it only modifies ARRAYs after they've been
  # inspected.

  my @set = ();
  foreach my $d (sort { $a->[0]<=>$b->[0] } @collect) {
    if(!@set || $set[$#set]->[1]+1 < $d->[0]) {
      push @set, $d;
    } elsif($set[$#set]->[1] < $d->[1]) {
      $set[$#set]->[1] = $d->[1];
    }
  }

  return join '', map {
    sprintf( $_->[0] >= $_->[1] 
      ? "\\x{%04X}"
      : "\\x{%04X}-\\x{%04X}",
      @{$_})
    } @set;

  return _set_compile(@set);
}

sub _compile_prohibited {
  my $prohibited_sub = _compile_set(@_);

  if($prohibited_sub) {
    return 
      'if($string =~ m/(['.$prohibited_sub.'])/) {'.
          'die sprintf("prohibited character U+%04X",ord($1))'.
      '}';
  }
}

sub _compile_bidi {
  my $is_RandAL = _compile_set(@Unicode::Stringprep::BiDi::D1);
  my $is_L = _compile_set(@Unicode::Stringprep::BiDi::D2);

  return 
    'if($string =~ m/['.$is_RandAL.']/) {'.
      'if($string =~ m/['.$is_L.']/) {'.
        'die "string contains both RandALCat and LCat characters"'.
      '} elsif($string !~ m/^['.$is_RandAL.']/) {'.
        'die "string contains RandALCat character but does not start with one"'.
      '} elsif($string !~ m/['.$is_RandAL.']$/) {'.
        'die "string contains RandALCat character but does not end with one"'.
      '}'.
    '}';
}

1;
__END__

=encoding utf8

=head1 NAME

Unicode::Stringprep - Preparation of Internationalized Strings (S<RFC 3454>)

=head1 SYNOPSIS

  use Unicode::Stringprep;
  use Unicode::Stringprep::Mapping;
  use Unicode::Stringprep::Prohibited;

  my $prepper = Unicode::Stringprep->new(
    3.2,
    [ { 32 => '<SPACE>'},  ],
    'KC',
    [ @Unicode::Stringprep::Prohibited::C12, @Unicode::Stringprep::Prohibited::C22,
      @Unicode::Stringprep::Prohibited::C3, @Unicode::Stringprep::Prohibited::C4,
      @Unicode::Stringprep::Prohibited::C5, @Unicode::Stringprep::Prohibited::C6,
      @Unicode::Stringprep::Prohibited::C7, @Unicode::Stringprep::Prohibited::C8,
      @Unicode::Stringprep::Prohibited::C9 ],
    1 );
  $output = $prepper->($input)

=head1 DESCRIPTION

This module implements the I<stringprep> framework for preparing
Unicode text strings in order to increase the likelihood that
string input and string comparison work in ways that make sense
for typical users throughout the world.  The I<stringprep>
protocol is useful for protocol identifier values, company and
personal names, internationalized domain names, and other text
strings.

The I<stringprep> framework does not specify how protocols should
prepare text strings. Protocols must create profiles of
stringprep in order to fully specify the processing options.

=head1 FUNCTIONS

This module provides a single function, C<new>, that creates a
perl function implementing a I<stringprep> profile.

This module exports nothing.

=over 4

=item B<new($unicode_version, $mapping_tables, $unicode_normalization, $prohibited_tables, $bidi_check)>

Creates a callable object that implements a stringprep profile.

C<$unicode_version> is the Unicode version specified by the
stringprep profile. Currently, this must be C<3.2>.

C<$mapping_tables> provides the mapping tables used for
stringprep.  It may be a reference to a hash or an array. A hash
must map Unicode codepoints (as integers, S<e. g.> C<0x0020> for
U+0020) to replacement strings (as perl strings).  An array may
contain pairs of Unicode codepoints and replacement strings as
well as references to nested hashes and arrays.
L<Unicode::Stringprep::Mapping> provides the tables from S<RFC 3454>,
S<Appendix B.> For further information on the mapping step, see
S<RFC 3454>, S<section 3.>

C<$unicode_normalization> is the Unicode normalization to be used.
Currently, C<''> (no normalization) and C<'KC'> (compatibility
composed) are specified for I<stringprep>. For further information
on the normalization step, see S<RFC 3454>, S<section 4.>

C<$prohibited_tables> provides the list of prohibited output
characters for stringprep.  It may be a reference to an array. The
array contains pairs of codepoints, which define the start and end
of a Unicode character range (as integers). The end character may
be C<undef>, specifying a single-character range. The array may
also contain references to nested arrays.
L<Unicode::Stringprep::Prohibited> provides the tables from
S<RFC 3454>, Appendix C. For further information on the prohibition
checking step, see S<RFC 3454>, S<section 5.>

C<$bidi_check> must be set to true if additional checks for
bidirectional characters are required. For further information on
the bidi checking step, see S<RFC 3454>, S<section 6.>

The function returned can be called with a single parameter, the
string to be prepared, and returns the prepared string. It will
die if the input string is invalid (so use C<eval> if necessary).

For performance reasons, it is strongly recommended to call the
C<new> function as few times as possible, S<i. e.> once per
I<stringprep> profile. It might also be better not to use this
module directly but to use (or write) a module implementing a
profile, such as L<Net::IDN::Nameprep>.

=back

=head1 IMPLEMENTING PROFILES

You can easily implement a I<stringprep> profile without
subclassing:

  package ACME::ExamplePrep;

  use Unicode::Stringprep;

  use Unicode::Stringprep::Mapping;
  use Unicode::Stringprep::Prohibited;

  *exampleprep = Unicode::Stringprep->new(
    3.2,
    [ 
      \@Unicode::Stringprep::Mapping::B1, 
    ],
    '',
    [
      \@Unicode::Stringprep::Prohibited::C12,
      \@Unicode::Stringprep::Prohibited::C22,
    ],
    1,
  );

This binds C<ACME::ExamplePrep::exampleprep> to the function
created by C<Unicode::Stringprep-E<gt>new>.

Usually, it is not necessary to subclass this module. Sublassing
this module is not recommended.

=head1 DATA TABLES

The following modules contain the data tables from S<RFC 3454>.
These modules are automatically loaded when loading
C<Unicode::Stringprep>.

=over 4

=item * L<Unicode::Stringprep::Unassigned>

  @Unicode::Stringprep::Unassigned::A1	# Appendix A.1

=item * L<Unicode::Stringprep::Mapping>

  @Unicode::Stringprep::Mapping::B1	# Appendix B.1
  @Unicode::Stringprep::Mapping::B2	# Appendix B.2
  @Unicode::Stringprep::Mapping::B2	# Appendix B.3

=item * L<Unicode::Stringprep::Prohibited>

  @Unicode::Stringprep::Prohibited::C11	# Appendix C.1.1
  @Unicode::Stringprep::Prohibited::C12	# Appendix C.1.2
  @Unicode::Stringprep::Prohibited::C21	# Appendix C.2.1
  @Unicode::Stringprep::Prohibited::C22	# Appendix C.2.2
  @Unicode::Stringprep::Prohibited::C3	# Appendix C.3
  @Unicode::Stringprep::Prohibited::C4	# Appendix C.4
  @Unicode::Stringprep::Prohibited::C5	# Appendix C.5
  @Unicode::Stringprep::Prohibited::C6	# Appendix C.6
  @Unicode::Stringprep::Prohibited::C7	# Appendix C.7
  @Unicode::Stringprep::Prohibited::C8	# Appendix C.8
  @Unicode::Stringprep::Prohibited::C9	# Appendix C.9

=item * L<Unicode::Stringprep::BiDi>

  @Unicode::Stringprep::BiDi::D1	# Appendix D.1
  @Unicode::Stringprep::BiDi::D2	# Appendix D.2

=back

=head1 PERL VERSION

You should use perl 5.8.3 or higher.

Well, these modules DO work with perl 5.6.x. However, B<you> have to make sure
that you only pass valid UTF-8 strings to this module or you will get
unintended results. perl 5.8.x (or higher) takes care of this by maintaining a
UTF-8 flag for strings.

With perl versions up to 5.8.2, surrogate characters (U+D800..U+DFFF) break
string handling. If a profile tries to map these characters, they won't be
mapped (currently no stringprep profile does this). If a profile prohibits
these characters, this module may fail to detect them (currently, all profiles
do that, so B<you> have to make sure that these characters are not present).

=head1 AUTHOR

Claus Färber <CFAERBER@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Unicode::Normalize>, S<RFC 3454> L<http://www.ietf.org/rfc/rfc3454.txt>

=cut

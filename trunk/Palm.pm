# Palm.pm
#
# Perl module for reading and writing Palm databases (both PDB and PRC).
#
#	Copyright (C) 1999, 2000, Andrew Arensburger.
#	You may distribute this file under the terms of the Artistic
#	License, as specified in the README file.
#
# $Id: Palm.pm,v 1.1 2005-03-09 03:51:22 christophe Exp $

use strict;
use warnings;
package Palm;
use vars qw( $VERSION );

# One liner, to allow MakeMaker to work.
$VERSION = do { my @r = (q$Revision: 1.1 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };

=head1 NAME

Palm - Palm OS utility functions

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 FUNCTIONS

=cut

my $EPOCH_1904 = 2082844800;		# Difference between Palm's
					# epoch (Jan. 1, 1904) and
					# Unix's epoch (Jan. 1, 1970),
					# in seconds.

=head2 palm2epoch
	
	my @parts = localtime( palm2epoch($palmtime) );

Converts a PalmOS timestamp to a Unix Epoch time. Note, however, that PalmOS
time is in the timezone of the Palm itself while Epoch is defined to be in
the GMT timezone. Further conversion may be necessary.

=cut

sub palm2epoch {
	return $_[0] - $EPOCH_1904;
}

=head2 epoch2palm
	
	my $palmtime = epoch2palm( time() );

Converts Unix epoch time to Palm OS time.

=cut

sub epoch2palm {
	return $_[0] + $EPOCH_1904;
}

=head2 mkpdbname
	
	$PDB->Write( mkpdbname($PDB->{name}) );

Convert a PalmOS database name to a 7-bit ASCII representation. Native
Palm database names can be found in ISO-8859-1 encoding. This encoding
isn't going to generate the most portable of filenames and, in particular,
ColdSync databases use this representation.

=cut

sub mkpdbname {
	my $name = shift;
	$name =~ s![%/\x00-\x19\x7f-\xff]!sprintf("%%%02X",ord($&))!ge;
	return $name;
}

=head1 AUTHOR

Andrew Arensburger E<lt>arensb@ooblick.comE<gt>

=head1 SEE ALSO

Palm::PDB(3)

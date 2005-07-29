# Palm::ZirePhoto.pm
# 
# Perl class for dealing with Zire71 photo database.
#
#	Copyright (C) 2003, Alessandro Zummo.
#	You may distribute this file under the terms of the Artistic
#	License, as specified in the README file.
#
# $Id: ZirePhoto.pm,v 1.7 2005-07-29 20:54:14 christophe Exp $


use strict;
package Palm::ZirePhoto;
use Palm::Raw();
use Palm::StdAppInfo();

use vars qw( $VERSION @ISA );

# One liner, to allow MakeMaker to work.
$VERSION = do { my @r = (q$Revision: 1.7 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };

@ISA = qw( Palm::StdAppInfo Palm::Raw );

=head1 NAME

Palm::ZirePhoto - Handler for Palm Zire71 Photo thumbnail databases.

=head1 SYNOPSIS

    use Palm::ZirePhoto;

=head1 DESCRIPTION

The Zire71 PDB handler is a helper class for the L<Palm::PDB> package. It parses Zire71
Photo thumbnail databases (and, hopefully, Tungsten Photo databases). Actual photos
are separate databases and must be processed separately.

This database is currently only capable of reading.

=head2 AppInfo block

The AppInfo block begins with standard category support. See
L<Palm::StdAppInfo> for details.

=head2 Records

Records may contain no data fields. This occurs when the record has been
marked deleted on the Palm, presumably in order to save space (Photo has no
provision for archiving when deleting and the separate database storage for
the actual images would make it pointless anyways).

    $record = $pdb->{records}[N]

    $record->{'width'}
    $record->{'height'}
    $record->{'size'}

The actual JPEG images dimensions and (compressed) file size.

    $record->{'thumb'}

The thumbnail is a very small (max size approx 84x84) JPEG format image.

    $record->{'name'}

Image name. Appending C<.jpg> to this will give the database name of the actual image
data.

    $record->{'time1'}
    $record->{'time2'}

Unix epoch time of when the image was last modified (C<time1>) and when it was
created (C<time2>).

=head2 Photo Databases

Actual photos are stored in separate databases. Each record is preceeded by an 8 byte
header that describes it a) as a data block (B<DBLK>) and b) the size of the block.
Records are generally 4k, except for the last. To convert a Photo database to a JPEG
image, one would do something like:

	use Palm::Raw;

	my $pdb = new Palm::PDB;
	$pdb->Load( "image.jpg.pdb" );
	open F, ">image.jpg";
	for( @{$pdb->{records}} ) {
		print F substr($_->{'data'}, 8);
	}
	close F;

Notes are stored at the end of the JPEG image. The following code can be used to
extract a note from a JPEG buffer C<$data>:

	my $note = $1 if $data =~ /NOTE.{8}([^\0]+)\0*ARCPHOTOBASE.{8}$/so;

=cut
#'

sub import
{
	&Palm::PDB::RegisterPDBHandlers(__PACKAGE__,
		[ "Foto", "Foto" ],
		);
}

sub new
{
	my $classname	= shift;
	my $self	= $classname->SUPER::new(@_);
			# Create a generic PDB. No need to rebless it,
			# though.

	$self->{name}		= "PhotosDB-Foto";	# Default
	$self->{creator}	= "Foto";
	$self->{type}		= "Foto";
	$self->{attributes}{resource} = 0;
				# The PDB is not a resource database by
				# default, but it's worth emphasizing.

	# Give the PDB an empty list of records
	$self->{records} = [];

	return $self;
}

sub ParseRecord
{
	my $self	= shift;
	my %record	= @_;
	my $data	= $record{'data'};

	delete $record{offset};		# This is useless
	delete $record{data};		# No longer necessary

	# when Photo thumbnail records are deleted/archived/whatever, the data section is
	# actually set to zero length. Presumably this is so that thumbnails take up
	# minimum space until a sync purges the records.

	return \%record unless length $data > 36;

	@record{
		'width',
		'height',
		'time1_secs',
		'size',
		'nameSize',
		'time2_secs',
		'thumb',
		'name'
	} = unpack "xxxx n n N N x5 n x5 N x4 N/a a*", $data;

	$record{'thumbSize'} = length($record{'thumb'});

	$record{'time1'} = $record{'time1_secs'} - 2082844800;
	$record{'time2'} = $record{'time2_secs'} - 2082844800;

	$record{'name'} = substr($record{'name'}, 0, $record{'nameSize'});

	return \%record;
}

1;

__END__

=head1 AUTHOR

Alessandro Zummo E<lt>a.zummo@towertech.itE<gt>

=head1 SEE ALSO

Palm::PDB(3)

Palm::StdAppInfo(3)

=cut

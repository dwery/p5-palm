# Palm::Memo.pm
# 
# Perl class for dealing with Palm Memo databases. 
#
#	Copyright (C) 1999, 2000, Andrew Arensburger.
#	You may distribute this file under the terms of the Artistic
#	License, as specified in the README file.
#
# $Id: Memo.pm,v 1.4 2000-02-02 04:19:40 arensb Exp $

package Palm::Memo;
($VERSION) = '$Revision: 1.4 $ ' =~ /\$Revision:\s+([^\s]+)/;

=head1 NAME

Palm::Memo - Handler for Palm Memo databases.

=head1 SYNOPSIS

    use Palm::Memo;

=head1 DESCRIPTION

The Memo PDB handler is a helper class for the Palm::PDB package. It
parses Memo databases.

=head2 AppInfo block

    $pdb->{"appinfo"}{"renamed"}

A scalar. I think this is a bitmap of category names that have changed
since the last sync.

    @{$pdb->{"appinfo"}{"categories"}}

Array of category names.

    @{$pdb->{"appinfo"}{"uniqueIDs"}}

Array of category IDs. By convention, categories created on the Palm
have IDs in the range 0-127, and categories created on the desktop
have IDs in the range 128-255.

    $pdb->{"appinfo"}{"lastUniqueID"}
    $pdb->{"appinfo"}{"sortOrder"}

I don't know what these are.

=head2 Sort block

    $pdb->{"sort"}

This is a scalar, the raw data of the sort block.

=head2 Records

    $record = $pdb->{"records"}[N]

    $record->{"data"}

A string, the text of the memo.

=cut
#'

use Palm::Raw();

@ISA = qw( Palm::Raw );

$numCategories = 16;		# Number of categories in AppInfo block
$categoryLength = 16;		# Length of category names

sub import
{
	&Palm::PDB::RegisterPDBHandlers(__PACKAGE__,
		[ "memo", "DATA" ],
		);
}

=head2 new

  $pdb = new Palm::Memo;

Create a new PDB, initialized with the various Palm::Memo fields
and an empty record list.

Use this method if you're creating a Memo PDB from scratch.

=cut
#'
sub new
{
	my $classname	= shift;
	my $self	= $classname->SUPER::new(@_);
			# Create a generic PDB. No need to rebless it,
			# though.

	$self->{"name"} = "MemoDB";	# Default
	$self->{"creator"} = "memo";
	$self->{"type"} = "DATA";
	$self->{"attributes"}{"resource"} = 0;
				# The PDB is not a resource database by
				# default, but it's worth emphasizing,
				# since MemoDB is explicitly not a PRC.

	# Initialize the AppInfo block
	$self->{"appinfo"} = {
		renamed		=> 0,	# Dunno what this is
		categories	=> [],	# List of category names
		uniqueIDs	=> [],	# List of category IDs
# XXX		lastUniqueID	=> ?
		sortOrder	=> undef,	# XXX - ?
	};

	# Make sure there are $numCategories categories
	$#{$self->{"appinfo"}{"categories"}} = $numCategories-1;
	$#{$self->{"appinfo"}{"uniqueIDs"}} = $numCategories-1;

	# If nothing else, there should be an "Unfiled" category, with
	# ID 0.
	$self->{"appinfo"}{"categories"}[0] = "Unfiled";
	$self->{"appinfo"}{"uniqueIDs"}[0] = 0;

	# Give the PDB a blank sort block
	$self->{"sort"} = undef;

	# Give the PDB an empty list of records
	$self->{"records"} = [];

	return $self;
}

=head2 new_Record

  $record = $pdb->new_Record;

Creates a new Memo record, with blank values for all of the fields.

=cut

sub new_Record
{
	my $classname = shift;
	my $retval = $classname->SUPER::new_Record(@_);

	$retval->{"data"} = "";

	return $retval;
}

# ParseAppInfoBlock
# Parse the AppInfo block for Memo databases.
# XXX - Weird: there are 282 bytes in a Memo AppInfo block, but the
# sizes of the fields add up to 281. This is most likely an alignment
# issue, but I would have expected the Palm header to mention this.
# XXX - Document the format of the AppInfo block more clearly.
# XXX - Parse the categories better.

sub ParseAppInfoBlock
{
	my $self = shift;
	my $data = shift;
	my $renamed;
	my @labels;
	my @uniqueIDs;
	my $lastUniqueID;
	my $sortOrder;
	my $unpackstr =		# Argument to unpack(), since it's hairy
		"n" .		# Renamed categories
		"a$categoryLength" x $numCategories .
				# Category names
		"C" x $numCategories .
				# Category IDs
		"C" .		# Last unique ID
		"x5" .		# Padding
		"C";		# Sort order
	my $i;
	my $appinfo = {};

	($renamed, @labels[0..($numCategories-1)],
	 @uniqueIDs[0..($numCategories-1)], $lastUniqueID, $sortOrder) =
		unpack $unpackstr, $data;
	for (@labels)
	{
		s/\0.*$//;	# Trim trailing NULs from category names
	}

	# Build the parsed AppInfo block
	$appinfo->{"renamed"} = $renamed;
			# XXX - "renamed" probably ought to be an
			# array of boolean values
	$appinfo->{"categories"} = \@labels;
	$appinfo->{"uniqueIDs"} = \@uniqueIDs;

	$appinfo->{"lastUniqueID"} = $lastUniqueID;
	$appinfo->{"sortOrder"} = $sortOrder;

	return $appinfo;
}

sub PackAppInfoBlock
{
	my $self = shift;
	my $retval;

	$retval = pack("n", $self->{"appinfo"}{"renamed"});
	for (@{$self->{"appinfo"}{"categories"}})
	{
		$retval .= pack("a$categoryLength", $_);
	}
	for (@{$self->{"appinfo"}{"uniqueIDs"}})
	{
		$retval .= pack("C", $_);
	}
	$retval .= pack("C x5 C x1",
		$self->{"appinfo"}{"lastUniqueID"},
		$self->{"appinfo"}{"sortOrder"});

	return $retval;
}

sub PackSortBlock
{
	# XXX
	return undef;
}

sub ParseRecord
{
	my $self = shift;
	my %record = @_;

	delete $record{"offset"};	# This is useless
	$record{"data"} =~ s/\0$//;	# Trim trailing NUL

	return \%record;
}

sub PackRecord
{
	my $self = shift;
	my $record = shift;

#print STDERR "Packing record [$record]\n";
	return $record->{"data"} . "\0";	# Add the trailing NUL
}

1;
__END__

=head1 AUTHOR

Andrew Arensburger E<lt>arensb@ooblick.comE<gt>

=head1 SEE ALSO

Palm::PDB(1)

=cut

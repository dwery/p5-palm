# Palm::Memo.pm
# 
# Perl class for dealing with Palm Memo databases. 
#
#	Copyright (C) 1999, Andrew Arensburger.
#	You may distribute this file under the terms of the Artistic
#	License, as specified in the README file.
#
# $Id: Memo.pm,v 1.2 1999-11-18 06:20:38 arensb Exp $

package Palm::Memo;

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

print STDERR "Packing record [$record]\n";
	return $record->{"data"} . "\0";	# Add the trailing NUL
}

1;
__END__

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

Each record is a string, the text of the memo.

=head1 AUTHOR

Andrew Arensburger E<lt>arensb@ooblick.comE<gt>

=head1 SEE ALSO

Palm::PDB(1)

=cut

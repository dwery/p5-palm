# Palm::ToDo.pm
# 
# Perl class for dealing with Palm ToDo databases. 
#
#	Copyright (C) 1999, 2000, Andrew Arensburger.
#	You may distribute this file under the terms of the Artistic
#	License, as specified in the README file.
#
# $Id: ToDo.pm,v 1.3 2000-02-01 12:31:52 arensb Exp $

package Palm::ToDo;
($VERSION) = '$Revision: 1.3 $ ' =~ /\$Revision:\s+([^\s]+)/;

use Palm::Raw();

@ISA = qw( Palm::Raw );

$numCategories = 16;		# Number of categories in AppInfo block
$categoryLength = 16;		# Length of category names

sub import
{
	&Palm::PDB::RegisterPDBHandlers(__PACKAGE__,
		[ "todo", "DATA" ],
		);
}

# ParseAppInfoBlock
# Parse the AppInfo block for ToDo databases.
sub ParseAppInfoBlock
{
	my $self = shift;
	my $data = shift;
	my $renamed;		# Renamed categories;
	my @labels;		# Category labels
	my @uniqueIDs;
	my $lastUniqueID;
	my $dirtyAppInfo;
	my $sortOrder;

	my $unpackstr =		# Argument to unpack(), since it's hairy
		"n" .		# Renamed categories
		"a$categoryLength" x $numCategories .
				# Category labels
		"C" x $numCategories .
				# Category IDs
		"C" .		# Last unique ID
		"x3" .		# Padding
		"n" .		# XXX - Dirty AppInfo (what is this?)
		"Cx";		# Sort order
	my $appinfo = {};

	($renamed, @labels[0..($numCategories-1)],
	 @uniqueIDs[0..($numCategories-1)], $lastUniqueID, $dirtyAppInfo,
	 $sortOrder, $extra) =
		unpack $unpackstr, $data;

	for (@labels)
	{
		s/\0.*//;	# Trim at first NUL
	}

	$appinfo->{"renamed"} = $renamed;
	$appinfo->{"categories"} = [ @labels ];
	$appinfo->{"uniqueIDs"} = [ @uniqueIDs ];
	$appinfo->{"lastUniqueID"} = $lastUniqueID;
	$appinfo->{"dirty_appinfo"} = $dirtyAppInfo;
	$appinfo->{"sort_order"} = $sortOrder;

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
	$retval .= pack("C x3 n Cx",
		$self->{"appinfo"}{"lastUniqueID"},
		$self->{"appinfo"}{"dirty_appinfo"},
		$self->{"appinfo"}{"sort_order"});

	return $retval;
}

sub ParseRecord
{
	my $self = shift;
	my %record = @_;
	my $data = $record{"data"};

	delete $record{"offset"};	# This is useless
	delete $record{"data"};		# No longer necessary

	my $date;
	my $priority;

	($date, $priority) = unpack "n C", $data;
	$data = substr $data, 3;	# Remove the stuff we've already seen

	if ($date != 0xffff)
	{
		my $day;
		my $month;
		my $year;

		$day   =  $date       & 0x001f;	# 5 bits
		$month = ($date >> 5) & 0x000f;	# 4 bits
		$year  = ($date >> 9) & 0x007f;	# 7 bits (years since 1904)
		$year += 1904;

		$record{"due_day"} = $day;
		$record{"due_month"} = $month;
		$record{"due_year"} = $year;
	}

	my $completed;		# Boolean

	$completed = $priority & 0x80;
	$priority &= 0x7f;	# Strip high bit

	$record{"completed"} = 1 if $completed;
	$record{"priority"} = $priority;

	my $description;
	my $note;

	($description, $note) = split /\0/, $data;

	$record{"description"} = $description;
	$record{"note"} = $note unless $note eq "";

	return \%record;
}

sub PackRecord
{
	my $self = shift;
	my $record = shift;
	my $retval;
	my $rawDate;
	my $priority;

	if (defined($record->{"due_day"}))
	{
		$rawDate = ($record->{"due_day"} & 0x001f) |
			(($record->{"due_month"} & 0x000f) << 5) |
			((($record->{"due_year"} - 1904) & 0x007f) << 9);
	} else {
		$rawDate = 0xffff;
	}
	$priority = $record->{"priority"} & 0x7f;
	$priority |= 0x80 if $record->{"completed"};

	$retval = pack "n C",
		$rawDate,
		$priority;
	$retval .= $record->{"description"} . "\0";
	$retval .= $record->{"note"} . "\0";

	return $retval;
}

1;
__END__

=head1 NAME

Palm::ToDo - Handler for Palm ToDo databases.

=head1 SYNOPSIS

    use Palm::ToDo;

=head1 DESCRIPTION

The ToDo PDB handler is a helper class for the Palm::PDB package. It
parses ToDo databases.

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
    $pdb->{"appinfo"}{"dirty_appinfo"}
    $pdb->{"appinfo"}{"sortOrder"}

I don't know what these are.

=head2 Sort block

    $pdb->{"sort"}

This is a scalar, the raw data of the sort block.

=head2 Records

    $record = $pdb->{"records"}[N]

    $record->{"due_day"}
    $record->{"due_month"}
    $record->{"due_year"}

The due date of the ToDo item. If the item has no due date, these are
undefined.

    $record->{"completed"}

This is defined and true iff the item has been completed.

    $record->{"priority"}

An integer. The priority of the item.

    $record->{"description"}

A text string. The description of the item.

    $record->{"note"}

A text string. The note attached to the item. Undefined if the item
has no note.

=head1 AUTHOR

Andrew Arensburger E<lt>arensb@ooblick.comE<gt>

=head1 SEE ALSO

Palm::PDB(1)

=cut

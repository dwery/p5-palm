# Palm::PDB::Raw.pm
# 
# Perl class for dealing with "raw" PDB databases. A "raw" database is
# one where the AppInfo and sort blocks, and all of the
# records/resources, are just strings of bytes.
# This is useful as a default PDB handler, for cases where you want to
# be able to handle any kind of database in a generic fashion.
# You may also find it useful to subclass this class, for cases where
# you don't care about every type of thing in a database.
#
#	Copyright (C) 1999, Andrew Arensburger.
#	You may distribute this file under the terms of the Artistic
#	License, as specified in the README file.
#
# $Id: Raw.pm,v 1.1 1999-11-18 05:16:36 arensb Exp $

package Palm::PDB::Raw;

use Palm::PDB;

@ISA = qw( Palm::PDB );

sub import
{
	# This package handles any PDB.
	&Palm::PDB::RegisterPDBHandlers(__PACKAGE__,
		[ "", "" ]
		);
}

sub ParseAppInfoBlock
{
	my $self = shift;
	my $data = shift;

	return $data;
}

sub ParseSortBlock
{
	my $self = shift;
	my $data = shift;

	return $data;
}

sub ParseRecord
{
	my $self = shift;
	my %record = @_;

	return \%record;
}

sub ParseResource
{
	my $self = shift;
	my %resource = @_;

	return \%resource;
}

sub PackAppInfoBlock
{
	my $self = shift;

	return $self->{"appinfo"};
}

sub PackSortBlock
{
	my $self = shift;

	return $self->{"sort"};
}

sub PackRecord
{
	my $self = shift;
	my $record = shift;

	return $record->{"data"};
}

sub PackResource
{
	my $self = shift;
	my $resource = shift;

	return $resource->{"data"};
}

1;
__END__

=head1 NAME

Palm::PDB::Raw - Handler for "raw" Palm databases.

=head1 SYNOPSIS

    use Palm::PDB::Raw;

=head1 DESCRIPTION

The Raw PDB handler is a helper class for the Palm::PDB package. It is
intended as a generic handler for any database, or as a fallback
default handler.

The Raw handler does no processing on the database whatsoever. The
AppInfo block, sort block, records and resources are simply strings,
raw data from the database.

By default, the Raw handler only handles record databases (.pdb
files). If you want it to handle resource databases (.prc files) as
well, you need to call

    &Palm::PDB::RegisterPRCHandlers("Palm::PDB::Raw", "");

in your script.

=head2 AppInfo block

    $pdb->{"appinfo"}

This is a scalar, the raw data of the AppInfo block.

=head2 Sort block

    $pdb->{"sort"}

This is a scalar, the raw data of the sort block.

=head2 Records

    @{$pdb->{"records"}};

Each element in the "records" array is a scalar, the raw data of that
record.

=head2 Resources

    @{$pdb->{"resources"}};

Each element in the "resources" array is a scalar, the raw data of
that resource.

=head1 AUTHOR

Andrew Arensburger E<lt>arensb@ooblick.comE<gt>

=head1 SEE ALSO

Palm::PDB(1)

=cut

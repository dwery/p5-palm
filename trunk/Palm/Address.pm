# Palm::Address.pm
# 
# Perl class for dealing with Palm AddressBook databases. 
#
#	Copyright (C) 1999, 2000, Andrew Arensburger.
#	You may distribute this file under the terms of the Artistic
#	License, as specified in the README file.
#
# $Id: Address.pm,v 1.5 2000-02-01 12:19:28 arensb Exp $

package Palm::Address;
($VERSION) = '$Revision: 1.5 $ ' =~ /\$Revision:\s+([^\s]+)/;

# AddressDB records are quite flexible and customizable, and therefore
# a pain in the ass to deal with correctly.

# XXX - Methods for adding, removing categories.

=head1 NAME

Palm::Address - Handler for Palm AddressBook databases.

=head1 SYNOPSIS

    use Palm::Address;

=head1 DESCRIPTION

The Address PDB handler is a helper class for the Palm::PDB package.
It parses AddressBook databases.

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
    $pdb->{"appinfo"}{"dirtyFields"}

I don't know what these are.

    $pdb->{"appinfo"}{"fieldLabels"}{"name"}
    $pdb->{"appinfo"}{"fieldLabels"}{"firstName"}
    $pdb->{"appinfo"}{"fieldLabels"}{"company"}
    $pdb->{"appinfo"}{"fieldLabels"}{"phone1"}
    $pdb->{"appinfo"}{"fieldLabels"}{"phone2"}
    $pdb->{"appinfo"}{"fieldLabels"}{"phone3"}
    $pdb->{"appinfo"}{"fieldLabels"}{"phone4"}
    $pdb->{"appinfo"}{"fieldLabels"}{"phone5"}
    $pdb->{"appinfo"}{"fieldLabels"}{"phone6"}
    $pdb->{"appinfo"}{"fieldLabels"}{"phone7"}
    $pdb->{"appinfo"}{"fieldLabels"}{"phone8"}
    $pdb->{"appinfo"}{"fieldLabels"}{"address"}
    $pdb->{"appinfo"}{"fieldLabels"}{"city"}
    $pdb->{"appinfo"}{"fieldLabels"}{"state"}
    $pdb->{"appinfo"}{"fieldLabels"}{"zipCode"}
    $pdb->{"appinfo"}{"fieldLabels"}{"country"}
    $pdb->{"appinfo"}{"fieldLabels"}{"title"}
    $pdb->{"appinfo"}{"fieldLabels"}{"custom1"}
    $pdb->{"appinfo"}{"fieldLabels"}{"custom2"}
    $pdb->{"appinfo"}{"fieldLabels"}{"custom3"}
    $pdb->{"appinfo"}{"fieldLabels"}{"custom4"}
    $pdb->{"appinfo"}{"fieldLabels"}{"note"}

These are the names of the various fields in the address record.

    $pdb->{"appinfo"}{"country"}

An integer: the code for the country for which these labels were
designed. The country name is available as

        $Palm::Address::countries[$pdb->{"appinfo"}{"country"}];

    $pdb->{"appinfo"}{"misc"}

An integer. The least-significant bit is a flag that indicates whether
the database should be sorted by company. The other bits are reserved.

=head2 Sort block

    $pdb->{"sort"}

This is a scalar, the raw data of the sort block.

=head2 Records

    $record = $pdb->{"records"}[N];

    $record->{"fields"}{"name"}
    $record->{"fields"}{"firstName"}
    $record->{"fields"}{"company"}
    $record->{"fields"}{"phone1"}
    $record->{"fields"}{"phone2"}
    $record->{"fields"}{"phone3"}
    $record->{"fields"}{"phone4"}
    $record->{"fields"}{"phone5"}
    $record->{"fields"}{"address"}
    $record->{"fields"}{"city"}
    $record->{"fields"}{"state"}
    $record->{"fields"}{"zipCode"}
    $record->{"fields"}{"country"}
    $record->{"fields"}{"title"}
    $record->{"fields"}{"custom1"}
    $record->{"fields"}{"custom2"}
    $record->{"fields"}{"custom3"}
    $record->{"fields"}{"custom4"}
    $record->{"fields"}{"note"}

These are scalars, the values of the various address book fields.

    $record->{"phoneLabel"}{"phone1"}
    $record->{"phoneLabel"}{"phone2"}
    $record->{"phoneLabel"}{"phone3"}
    $record->{"phoneLabel"}{"phone4"}
    $record->{"phoneLabel"}{"phone5"}

Most fields in an AddressBook record are straightforward: the "name"
field always gives the person's last name.

The "phoneI<N>" fields, on the other hand, can mean different things
in different records. There are five such fields in each record, each
of which can take on one of eight different values: "Work", "Home",
"Fax", "Other", "E-mail", "Main", "Pager" and "Mobile".

The $record->{"phoneLabel"}{"phone*"} fields are integers. Each one is
an index into @Palm::Address::phoneLabels, and indicates which
particular type of phone number each of the $record->{"phone*"} fields
represents.

    $record->{"phoneLabel"}{"display"}

Like the phone* fields above, this is an index into
@Palm::Address::phoneLabels. It indicates which of the phone*
fields to display in the list view.

    $record->{"phoneLabel"}{"reserved"}

I don't know what this is.

=head1 METHODS

=cut
#'

use Palm::Raw();

@ISA = qw( Palm::Raw );

$numCategories = 16;		# Number of categories in AppInfo block
$categoryLength = 16;		# Length of category names
$addrLabelLength = 16;
$numFieldLabels = 22;
$numFields = 19;

@phoneLabels = (
	"Work",
	"Home",
	"Fax",
	"Other",
	"E-mail",
	"Main",
	"Pager",
	"Mobile",
	);

@countries = (
	"Australia",
	"Austria",
	"Belgium",
	"Brazil",
	"Canada",
	"Denmark",
	"Finland",
	"France",
	"Germany",
	"Hong Kong",
	"Iceland",
	"Ireland",
	"Italy",
	"Japan",
	"Luxembourg",
	"Mexico",
	"Netherlands",
	"New Zealand",
	"Norway",
	"Spain",
	"Sweden",
	"Switzerland",
	"United Kingdom",
	"United States",
);

sub import
{
	&Palm::PDB::RegisterPDBHandlers(__PACKAGE__,
		[ "addr", "DATA" ],
		);
}

=head2 new

  $pdb = new Palm::Address;

Create a new PDB, initialized with the various Palm::Address fields
and an empty record list.

Use this method if you're creating an Address PDB from scratch.

=cut
#'

# new
# Create a new Palm::Address database, and return it
sub new
{
	my $classname	= shift;
	my $self	= $classname->SUPER::new(@_);
			# Create a generic PDB. No need to rebless it,
			# though.

	$self->{"name"} = "AddressDB";	# Default
	$self->{"creator"} = "addr";
	$self->{"type"} = "DATA";
	$self->{"attributes"}{"resource"} = 0;
				# The PDB is not a resource database by
				# default, but it's worth emphasizing,
				# since AddressDB is explicitly not a PRC.

	# Initialize the AppInfo block
	$self->{"appinfo"} = {
		renamed		=> 0,	# Dunno what this is
		categories	=> [],	# List of category names
		uniqueIDs	=> [],	# List of category IDs
		fieldLabels	=> {
			# Displayed labels for the various fields in
			# each address record.
			# XXX - These are American English defaults. It'd
			# be way keen to allow i18n.
			name		=> "Name",
			firstName	=> "First name",
			company		=> "Company",
			phone1		=> "Work",
			phone2		=> "Home",
			phone3		=> "Fax",
			phone4		=> "Other",
			phone5		=> "E-mail",
			phone6		=> "Main",
			phone7		=> "Pager",
			phone8		=> "Mobile",
			address		=> "Address",
			city		=> "City",
			state		=> "State",
			zipCode		=> "Zip Code",
			country		=> "Country",
			title		=> "Title",
			custom1		=> "Custom 1",
			custom2		=> "Custom 2",
			custom3		=> "Custom 3",
			custom4		=> "Custom 4",
			note		=> "Note",
		},

		# XXX - The country code corresponds to "United
		# States". Again, it'd be keen to allow the user's #
		# country-specific defaults.
		country		=> 22,

		misc		=> 0,
	};

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

Creates a new Address record, with blank values for all of the fields.

=cut

# new_Record
# Create a new, initialized record.
sub new_Record
{
	my $classname = shift;
	my $retval = $classname->SUPER::new_Record(@_);

	# Initialize the fields. This isn't particularly enlightening,
	# but every AddressDB record has these.
	$retval->{"fields"} = {
		name		=> undef,
		firstName	=> undef, 
		company		=> undef,
		phone1		=> undef,
		phone2		=> undef,
		phone3		=> undef,
		phone4		=> undef,
		phone5		=> undef,
		address		=> undef,
		city		=> undef,
		state		=> undef,
		zipCode		=> undef,
		country		=> undef,
		title		=> undef,
		custom1		=> undef,
		custom2		=> undef,
		custom3		=> undef,
		custom4		=> undef,
		note		=> undef,
	};

	# Initialize the phone labels
	$retval->{"phoneLabel"} = {
		phone1	=> 0,		# Work
		phone2	=> 1,		# Home
		phone3	=> 2,		# Fax
		phone4	=> 3,		# Other
		phone5	=> 4,		# E-mail
		display	=> 0,		# Display work phone by default
		reserved => undef	# ???
	};

	return $retval;
}

# ParseAppInfoBlock
# Parse the AppInfo block for Address databases.
# XXX - There appear to be two extra bytes at the end of the AppInfo
# block, unaccounted for by the header file. Alignment?

# The AppInfo block has the following overall structure:
#	1: renamedCategories
#	2: category labels
#	3: category IDs
#	4: last unique category ID
#	5: 3 bytes of padding
#	6: dirty field labels
#	7: field labels
#	8: country
#	9: misc
# 1: I think this is a bit field that indicates which category labels
#    have changed (i.e., which categories have been renamed). This
#    seems fairly standard.
# 2: An array of category names (16-character strings, NUL-terminated).
# 3: Not sure what this is.
# 4: Not sure what this is. Probably something to help in picking the
#    next category ID or something.
# 5: Padding.
# 6: I think this is like (1), a bit field of which field labels have
#    changed (i.e., which fields have been renamed).
# 7: An array of field labels (16-character strings, NUL-terminated).
# 8: The code for the country for which the labels were designed.
# 9: 7 reserved bits followed by one flag that's set if the database
#    should be sorted by company.

sub ParseAppInfoBlock
{
	my $self = shift;
	my $data = shift;
	my $renamed;
	my %renamedCategories;
	my @labels;
	my @uniqueIDs;
	my $lastUniqueID;
	my $dirtyFields;
	my %dirtyFields = ();
	my @fieldlabels;
	my $country;
	my $misc;

	my $unpackstr =		# Argument to unpack(), since it's hairy
		"n" .		# Renamed categories
		"a$categoryLength" x $numCategories .
				# Category labels
		"C" x $numCategories .
				# Category IDs
		"C" .		# Last unique ID
		"x3" .		# Padding
		"N" .		# Dirty flags
		"a$addrLabelLength" x $numFieldLabels .
				# Address labels
		"C" .		# Country
		"C";		# Misc
	my $i;
	my $appinfo = {};

	($renamed, @labels[0..($numCategories-1)],
	 @uniqueIDs[0..($numCategories-1)], $lastUniqueID, $dirtyFields,
	 @fieldLabels[0..($numFieldLabels-1)], $country, $misc) =
		unpack $unpackstr, $data;
	for (@labels)
	{
		s/\0.*$//;	# Trim at NUL
	}
	for (@fieldLabels)
	{
		s/\0.*$//;	# Trim everything after the first NUL
				# (when renaming custom fields, might
				# have something like "Foo\0om 1"
	}

	$appinfo->{"renamed"} = $renamed;
	$appinfo->{"categories"} = [ @labels ];
	$appinfo->{"uniqueIDs"} = [ @uniqueIDs ];
	$appinfo->{"lastUniqueID"} = $lastUniqueID;
	$appinfo->{"dirtyFields"} = $dirtyFields;
	$appinfo->{"fieldLabels"} = {
		name		=> $fieldLabels[0],
		firstName	=> $fieldLabels[1],
		company		=> $fieldLabels[2],
		phone1		=> $fieldLabels[3],
		phone2		=> $fieldLabels[4],
		phone3		=> $fieldLabels[5],
		phone4		=> $fieldLabels[6],
		phone5		=> $fieldLabels[7],
		address		=> $fieldLabels[8],
		city		=> $fieldLabels[9],
		state		=> $fieldLabels[10],
		zipCode		=> $fieldLabels[11],
		country		=> $fieldLabels[12],
		title		=> $fieldLabels[13],
		custom1		=> $fieldLabels[14],
		custom2		=> $fieldLabels[15],
		custom3		=> $fieldLabels[16],
		custom4		=> $fieldLabels[17],
		note		=> $fieldLabels[18],
		phone6		=> $fieldLabels[19],
		phone7		=> $fieldLabels[20],
		phone8		=> $fieldLabels[21],
		};
	$appinfo->{"country"} = $country;
	$appinfo->{"misc"} = $misc;	# XXX - Parse the "misc" field further

	return $appinfo;
}

sub PackAppInfoBlock
{
	my $self = shift;
	my $retval;
	my $i;

	$retval = pack("n", $self->{"appinfo"}{"renamed"});
	for ($i = 0; $i < $numCategories; $i++)
	{
		$retval .= pack("a$categoryLength",
				$self->{"appinfo"}{"categories"}[$i]);
	}

	for ($i = 0; $i < $numCategories; $i++)
	{
		$retval .= pack("C", $self->{"appinfo"}{"uniqueIDs"}[$i]);
	}

	$retval .= pack("C x3 N",
		$self->{"appinfo"}{"lastUniqueID"},
		$self->{"appinfo"}{"dirtyFields"});
	$retval .= pack("a$addrLabelLength" x $numFieldLabels,
		$self->{"appinfo"}{"fieldLabels"}{"name"},
		$self->{"appinfo"}{"fieldLabels"}{"firstName"},
		$self->{"appinfo"}{"fieldLabels"}{"company"},
		$self->{"appinfo"}{"fieldLabels"}{"phone1"},
		$self->{"appinfo"}{"fieldLabels"}{"phone2"},
		$self->{"appinfo"}{"fieldLabels"}{"phone3"},
		$self->{"appinfo"}{"fieldLabels"}{"phone4"},
		$self->{"appinfo"}{"fieldLabels"}{"phone5"},
		$self->{"appinfo"}{"fieldLabels"}{"address"},
		$self->{"appinfo"}{"fieldLabels"}{"city"},
		$self->{"appinfo"}{"fieldLabels"}{"state"},
		$self->{"appinfo"}{"fieldLabels"}{"zipCode"},
		$self->{"appinfo"}{"fieldLabels"}{"country"},
		$self->{"appinfo"}{"fieldLabels"}{"title"},
		$self->{"appinfo"}{"fieldLabels"}{"custom1"},
		$self->{"appinfo"}{"fieldLabels"}{"custom2"},
		$self->{"appinfo"}{"fieldLabels"}{"custom3"},
		$self->{"appinfo"}{"fieldLabels"}{"custom4"},
		$self->{"appinfo"}{"fieldLabels"}{"note"},
		$self->{"appinfo"}{"fieldLabels"}{"phone6"},
		$self->{"appinfo"}{"fieldLabels"}{"phone7"},
		$self->{"appinfo"}{"fieldLabels"}{"phone8"});
	$retval .= pack("C C x2",
		$self->{"appinfo"}{"country"},
		$self->{"appinfo"}{"misc"});
	return $retval;
}

# ParseRecord
# Parse an Address Book record.

# Address book records have the following overall structure:
#	1: phone labels
#	2: field map
#	3: fields

# Each record can contain a number of fields, such as "name",
# "address", "city", "company", and so forth. Each field has an
# internal name ("zipCode"), a printable name ("Zip Code"), and a
# value ("90210").
#
# For most fields, there is a hard mapping between internal and
# printed names: "name" always corresponds to "Last Name". The fields
# "phone1" through "phone5" are different: each of these can be mapped
# to one of several printed names: "Work", "Home", "Fax", "Other",
# "E-Mail", "Main", "Pager" or "Mobile". Multiple internal names can
# map to the same printed name (a person might have several e-mail
# addresses), and the mapping is part of the record (i.e., each record
# has its own mapping).
#
# Part (3) is simply a series of NUL-terminated strings, giving the
# values of the various fields in the record, in a certain order. If a
# record does not have a given field, there is no string corresponding
# to it in this part.
#
# Part (2) is a bit field that specifies which fields the record
# contains.
#
# Part (1) determines the phone mapping described above. This is
# implemented as an unsigned long, but what we're interested in are
# the six least-significant nybbles. They are:
#	disp	phone5	phone4	phone3	phone2	phone1
# ("phone1" is the least-significant nybble). Each nybble holds a
# value in the range 0-15 which in turn specifies the printed name for
# that particular internal name.

sub ParseRecord
{
	my $self = shift;
	my %record = @_;

	delete $record{"offset"};	# This is useless

	my $phoneFlags;
	my @phoneTypes;
	my $dispPhone;		# Which phone to display in the phone list
	my $reserved;		# Not sure what this is. It's the 8 high bits
				# of the "phone types" field.
	my $fieldMap;
	my $companyFieldOff;	# Company field offset: offset into the
				# raw "fields" string of the beginning of
				# the company name, plus 1. Presumably this
				# is to allow the address book app to quickly
				# display by company name. It is 0 in entries
				# that don't have a "Company" field.
				# This can be ignored when reading, and
				# must be computed when writing.
	my $fields;
	my @fields;

	($phoneFlags, $fieldMap, $companyFieldOff, $fields) =
		unpack("N N C a*", $record{"data"});
	@fields = split /\0/, $fields;

	# Parse the phone flags
	$phoneTypes[0] =  $phoneFlags        & 0x0f;
	$phoneTypes[1] = ($phoneFlags >>  4) & 0x0f;
	$phoneTypes[2] = ($phoneFlags >>  8) & 0x0f;
	$phoneTypes[3] = ($phoneFlags >> 12) & 0x0f;
	$phoneTypes[4] = ($phoneFlags >> 16) & 0x0f;
	$dispPhone     = ($phoneFlags >> 20) & 0x0f;
	$reserved      = ($phoneFlags >> 24) & 0xff;

	$record{"phoneLabel"}{"phone1"} = $phoneTypes[0];
	$record{"phoneLabel"}{"phone2"} = $phoneTypes[1];
	$record{"phoneLabel"}{"phone3"} = $phoneTypes[2];
	$record{"phoneLabel"}{"phone4"} = $phoneTypes[3];
	$record{"phoneLabel"}{"phone5"} = $phoneTypes[4];
	$record{"phoneLabel"}{"display"} = $dispPhone;
	$record{"phoneLabel"}{"reserved"} = $reserved;

	# Get the relevant fields
	$fieldMap & 0x0001 and $record{"fields"}{"name"} = shift @fields;
	$fieldMap & 0x0002 and $record{"fields"}{"firstName"} =
		shift @fields;
	$fieldMap & 0x0004 and $record{"fields"}{"company"} = shift @fields;
	$fieldMap & 0x0008 and $record{"fields"}{"phone1"} = shift @fields;
	$fieldMap & 0x0010 and $record{"fields"}{"phone2"} = shift @fields;
	$fieldMap & 0x0020 and $record{"fields"}{"phone3"} = shift @fields;
	$fieldMap & 0x0040 and $record{"fields"}{"phone4"} = shift @fields;
	$fieldMap & 0x0080 and $record{"fields"}{"phone5"} = shift @fields;
	$fieldMap & 0x0100 and $record{"fields"}{"address"} = shift @fields;
	$fieldMap & 0x0200 and $record{"fields"}{"city"} = shift @fields;
	$fieldMap & 0x0400 and $record{"fields"}{"state"} = shift @fields;
	$fieldMap & 0x0800 and $record{"fields"}{"zipCode"} = shift @fields;
	$fieldMap & 0x1000 and $record{"fields"}{"country"} = shift @fields;
	$fieldMap & 0x2000 and $record{"fields"}{"title"} = shift @fields;
	$fieldMap & 0x4000 and $record{"fields"}{"custom1"} = shift @fields;
	$fieldMap & 0x8000 and $record{"fields"}{"custom2"} = shift @fields;
	$fieldMap & 0x10000 and $record{"fields"}{"custom3"} = shift @fields;
	$fieldMap & 0x20000 and $record{"fields"}{"custom4"} = shift @fields;
	$fieldMap & 0x40000 and $record{"fields"}{"note"} = shift @fields;

	delete $record{"data"};

	return \%record;
}

sub PackRecord
{
	my $self = shift;
	my $record = shift;
	my $retval;

	$retval = pack("N",
		($record->{"phoneLabel"}{"phone1"}    & 0x0f) |
		(($record->{"phoneLabel"}{"phone2"}   & 0x0f) <<  4) |
		(($record->{"phoneLabel"}{"phone3"}   & 0x0f) <<  8) |
		(($record->{"phoneLabel"}{"phone4"}   & 0x0f) << 12) |
		(($record->{"phoneLabel"}{"phone5"}   & 0x0f) << 16) |
		(($record->{"phoneLabel"}{"display"}  & 0x0f) << 20) |
		(($record->{"phoneLabel"}{"reserved"} & 0xff) << 24));

	my $fieldMap;

	$fieldMap = 0;
	$fieldMap |= 0x0001 if $record->{"fields"}{"name"} ne "";
	$fieldMap |= 0x0002 if $record->{"fields"}{"firstName"} ne "";
	$fieldMap |= 0x0004 if $record->{"fields"}{"company"} ne "";
	$fieldMap |= 0x0008 if $record->{"fields"}{"phone1"} ne "";
	$fieldMap |= 0x0010 if $record->{"fields"}{"phone2"} ne "";
	$fieldMap |= 0x0020 if $record->{"fields"}{"phone3"} ne "";
	$fieldMap |= 0x0040 if $record->{"fields"}{"phone4"} ne "";
	$fieldMap |= 0x0080 if $record->{"fields"}{"phone5"} ne "";
	$fieldMap |= 0x0100 if $record->{"fields"}{"address"} ne "";
	$fieldMap |= 0x0200 if $record->{"fields"}{"city"} ne "";
	$fieldMap |= 0x0400 if $record->{"fields"}{"state"} ne "";
	$fieldMap |= 0x0800 if $record->{"fields"}{"zipCode"} ne "";
	$fieldMap |= 0x1000 if $record->{"fields"}{"country"} ne "";
	$fieldMap |= 0x2000 if $record->{"fields"}{"title"} ne "";
	$fieldMap |= 0x4000 if $record->{"fields"}{"custom1"} ne "";
	$fieldMap |= 0x8000 if $record->{"fields"}{"custom2"} ne "";
	$fieldMap |= 0x10000 if $record->{"fields"}{"custom3"} ne "";
	$fieldMap |= 0x20000 if $record->{"fields"}{"custom4"} ne "";
	$fieldMap |= 0x40000 if $record->{"fields"}{"note"} ne "";

	$retval .= pack("N", $fieldMap);

	my $fields = '';
	my $companyFieldOff = 0;

	$fields .= $record->{"fields"}{"name"} . "\0"
		unless $record->{"fields"}{"name"} eq "";
	$fields .= $record->{"fields"}{"firstName"} . "\0"
		unless $record->{"fields"}{"firstName"} eq "";
	if ($record->{"fields"}{"company"} ne "")
	{
		$companyFieldOff = length($fields) + 1;
		$fields .= $record->{"fields"}{"company"} . "\0"
	}
	$fields .= $record->{"fields"}{"phone1"} . "\0"
		unless $record->{"fields"}{"phone1"} eq "";
	$fields .= $record->{"fields"}{"phone2"} . "\0"
		unless $record->{"fields"}{"phone2"} eq "";
	$fields .= $record->{"fields"}{"phone3"} . "\0"
		unless $record->{"fields"}{"phone3"} eq "";
	$fields .= $record->{"fields"}{"phone4"} . "\0"
		unless $record->{"fields"}{"phone4"} eq "";
	$fields .= $record->{"fields"}{"phone5"} . "\0"
		unless $record->{"fields"}{"phone5"} eq "";
	$fields .= $record->{"fields"}{"address"} . "\0"
		unless $record->{"fields"}{"address"} eq "";
	$fields .= $record->{"fields"}{"city"} . "\0"
		unless $record->{"fields"}{"city"} eq "";
	$fields .= $record->{"fields"}{"state"} . "\0"
		unless $record->{"fields"}{"state"} eq "";
	$fields .= $record->{"fields"}{"zipCode"} . "\0"
		unless $record->{"fields"}{"zipCode"} eq "";
	$fields .= $record->{"fields"}{"country"} . "\0"
		unless $record->{"fields"}{"country"} eq "";
	$fields .= $record->{"fields"}{"title"} . "\0"
		unless $record->{"fields"}{"title"} eq "";
	$fields .= $record->{"fields"}{"custom1"} . "\0"
		unless $record->{"fields"}{"custom1"} eq "";
	$fields .= $record->{"fields"}{"custom2"} . "\0"
		unless $record->{"fields"}{"custom2"} eq "";
	$fields .= $record->{"fields"}{"custom3"} . "\0"
		unless $record->{"fields"}{"custom3"} eq "";
	$fields .= $record->{"fields"}{"custom4"} . "\0"
		unless $record->{"fields"}{"custom4"} eq "";
	$fields .= $record->{"fields"}{"note"} . "\0"
		unless $record->{"fields"}{"note"} eq "";

	$retval .= pack("C", $companyFieldOff);
	$retval .= $fields;

	return $retval;
}

1;
__END__

=head1 AUTHOR

Andrew Arensburger E<lt>arensb@ooblick.comE<gt>

=head1 SEE ALSO

Palm::PDB(1)

=head1 BUGS

The new() method initializes the AppInfo block with English labels and
"United States" as the country.

=cut

# Palm::StdAppInfo.pm
#
# Class for dealing with standard AppInfo blocks in PDBs.
#
#	Copyright (C) 1999, 2000, Andrew Arensburger.
#	You may distribute this file under the terms of the Artistic
#	License, as specified in the README file.
#
# $Id: StdAppInfo.pm,v 1.11 2000-09-24 16:26:11 arensb Exp $

use strict;
package Palm::StdAppInfo;
use Palm::Raw();

# Don't harass me about these variables
use vars qw( $VERSION @ISA $error );
	# $error acts like $! in that it reports the error that occurred

$VERSION = sprintf "%d.%03d", '$Revision: 1.11 $ ' =~ m{(\d+)\.(\d+)};
@ISA = qw( Palm::Raw );

=head1 NAME

Palm::StdAppInfo - Handles standard AppInfo block

=head1 SYNOPSIS

Usually:

    package MyPDBHandler;
    use Palm::StdAppInfo();		# Note the parentheses

    @ISA = qw( Palm::StdAppInfo );

    sub ParseAppInfoBlock {
	my $self = shift;
	my $data = shift;
	my $appinfo = {};

	&Palm::StdAppInfo::parse_StdAppInfo($appinfo, $data);

	$app_specific_data = $appinfo->{other};
    }

    sub PackAppInfoBlock {
	my $self = shift;
	my $retval;

	$self->{appinfo}{other} = <pack application-specific data>;
	$retval = &Palm::StdAppInfo::pack_StdAppInfo($self->{appinfo});
	return $retval;
    }

Or as a standalone C<PDB> helper class:

    use Palm::StdAppInfo;

=head1 DESCRIPTION

Many Palm applications use a common format for keeping track of categories.
The C<Palm::StdAppInfo> class deals with this common format:

	$pdb = new PDB;
	$pdb->Load("myfile.pdb");

	@categories   = @{$pdb->{appinfo}{categories}};
	$lastUniqueID =   $pdb->{appinfo}{lastUniqueID};
	$other        =   $pdb->{appinfo}{other};

where:

C<@categories> is an array of references-to-hash:

=item C<$cat = $categories[0];>

=over 4

=item C<$cat-E<gt>{name}>

The name of the category, a string of at most 16 characters.

=item C<$cat-E<gt>{id}>

The category ID, an integer in the range 0-255. Each category has a
unique ID. By convention, 0 is reserved for the "Unfiled" category;
IDs assigned by the Palm are in the range 1-127, and IDs assigned by
the desktop are in the range 128-255.

=item C<$cat-E<gt>{renamed}>

A boolean. This field is true iff the category has been renamed since
the last sync.

=back

C<$lastUniqueID> is (I think) the last category ID that was assigned.

C<$other> is any data that follows the category list in the AppInfo
block. If you're writing a helper class for a PDB that includes a
category list, you should parse this field to get any data that
follows the category list; you should also make sure that this field
is initialized before you call C<&Palm::StdAppInfo::pack_AppInfo>.

=cut

=head1 FUNCTIONS

=cut
#'

use constant numCategories => 16;	# Number of categories in AppInfo block
use constant categoryLength => 16;	# Length of category names
use constant stdAppInfoSize =>		# Length of a standard AppInfo block
		2 +	
		(categoryLength * numCategories) +
		numCategories +
		1 + 1;

sub import
{
	&Palm::PDB::RegisterPDBHandlers(__PACKAGE__,
		[ "", "" ],
		);
}

=head2 seed_StdAppInfo

    &Palm::StdAppInfo::seed_StdAppInfo(\%appinfo);

Creates the standard fields in an existing AppInfo hash. Usually used
to ensure that a newly-created AppInfo block contains an initialized
category array:

	my $appinfo = {};

	&Palm::StdAppInfo::seed_StdAppInfo($appinfo);

Note: this is not a method.

=cut

# seed_StdAppInfo
# *** THIS IS NOT A METHOD ***
# Given a reference to an appinfo hash, creates all of the fields for
# a new AppInfo block.
sub seed_StdAppInfo
{
	my $appinfo = shift;
	my $i;

	$appinfo->{categories} = [];	# Create array of categories

	# Initialize the categories
	# Note that all of the IDs are initialized to $i. There's no
	# real good reason for doing it this way, except that that's
	# what the Palm appears to do with new category lists.
	for ($i = 0; $i < numCategories; $i++)
	{
		$appinfo->{categories}[$i] = {};

		$appinfo->{categories}[$i]{renamed} = 0;
		$appinfo->{categories}[$i]{name}    = undef;
		$appinfo->{categories}[$i]{id}      = $i;
	}

	# The only fixed category is "Unfiled". Initialize it now
	$appinfo->{categories}[0]{name} = "Unfiled";
	$appinfo->{categories}[0]{id}   = 0;

	# I'm not sure what this is, but let's initialize it.
	# The Palm appears to initialize this to numCategories - 1.
	$appinfo->{lastUniqueID} = numCategories - 1;
}

=head2 newStdAppInfo

    $appinfo = Palm::StdAppInfo->newStdAppInfo;

Like C<seed_StdAppInfo>, but creates an AppInfo hash and returns a
reference to it.

=cut

sub newStdAppInfo
{
	my $class = shift;
	my $retval = {};

	&seed_StdAppInfo($retval);
	return $retval;
}

=head2 new

    $pdb = new Palm::StdAppInfo;

Create a new PDB, initialized with nothing but a standard AppInfo block.

There are very few reasons to use this, and even fewer good ones. If
you're writing a helper class to parse some PDB format that contains a
category list, then you should make that helper class a subclass of
C<Palm::StdAppInfo>.

=cut
#'

sub new
{
	my $classname	= shift;
	my $self	= $classname->SUPER::new(@_);
			# Create a generic PDB. No need to rebless it,
			# though.

	# Initialize the AppInfo block
	$self->{appinfo} = &newStdAppInfo();

	return $self;
}

=head2 parse_StdAppInfo

    $len = &Palm::StdAppInfo::parse_StdAppInfo(\%appinfo, $data);

This function (this is not a method) is intended to be called from
within a PDB helper class's C<ParseAppInfoBlock> method.

C<parse_StdAppInfo()> parses a standard AppInfo block from the raw
data C<$data> and fills in the fields in C<%appinfo>. It returns the
number of bytes parsed.

=cut
#'

# parse_StdAppInfo
# *** THIS IS NOT A METHOD ***
#
# Reads the raw data from $data, parses it as a standard AppInfo
# block, and fills in the corresponding fields in %$appinfo. Returns
# the number of bytes parsed.
sub parse_StdAppInfo
{
	my $appinfo = shift;	# A reference to hash, to fill in
	my $data = shift;	# Raw data to read
	my $unpackstr;		# First argument to unpack()
	my $renamed;		# Bitmap of renamed categories
	my @labels;		# Array of category labels
	my @uniqueIDs;		# Array of category IDs
	my $lastUniqueID;	# Not sure what this is

	# Make sure $appinfo contains all of the requisite fields
	&seed_StdAppInfo($appinfo);

	# The argument to unpack() isn't hard to understand, it's just
	# hard to write in a readable fashion.
	$unpackstr =		# Argument to unpack(), since it's hairy
		"n" .		# Renamed categories
		("a" . categoryLength) x numCategories .
				# Category labels
		"C" x numCategories .
				# Category IDs
		"C" .		# Last unique ID
		"x";

	# Unpack the data
	($renamed,
	 @labels[0..(numCategories-1)],
	 @uniqueIDs[0..(numCategories-1)],
	 $lastUniqueID) =
		unpack $unpackstr, $data;

	# Clean this stuff up a bit
	for (@labels)
	{
		s/\0.*$//;	# Trim at NUL
	}

	# Now put the data into $appinfo
	my $i;

	for ($i = 0; $i < numCategories; $i++)
	{
		$appinfo->{categories}[$i]{renamed} =
			($renamed & (1 << $i) ? 1 : 0);
		$appinfo->{categories}[$i]{name} = $labels[$i];
		$appinfo->{categories}[$i]{id}   = $uniqueIDs[$i];
	}
	$appinfo->{lastUniqueID} = $lastUniqueID;

	# There might be other stuff in the AppInfo block other than
	# the standard categories. Put everything else in
	# $appinfo->{other}.
	$appinfo->{other} = substr($data, stdAppInfoSize);

	return stdAppInfoSize;
}

=head2 ParseAppInfoBlock

    $pdb = new Palm::StdAppInfo;
    $pdb->ParseAppInfoBlock($data);

If your application's AppInfo block contains standard category support
and nothing else, you may choose to just inherit this method instead
of writing your own C<ParseAppInfoBlock> method. Otherwise, see the
example in the L<"SYNOPSIS">.

=cut
#'

sub ParseAppInfoBlock
{
	my $self = shift;
	my $data = shift;

	my $appinfo = {};

	&parse_StdAppInfo($appinfo, $data);
	return $appinfo;
}

=head2 pack_StdAppInfo

    $data = &Palm::StdAppInfo::pack_StdAppInfo(\%appinfo);

This function (this is not a method) is intended to be called from
within a PDB helper class's C<PackAppInfoBlock> method.

C<pack_StdAppInfo> takes an AppInfo hash and packs it as a string of
raw data that can be written to a PDB.

Note that if you're using this inside a helper class's
C<PackAppInfoBlock> method, you should make sure that
C<$appinfo{other}> is properly initialized before you call
C<&Palm::StdAppInfo::pack_StdAppInfo>.

=cut
#'

# pack_StdAppInfo
# *** THIS IS NOT A METHOD ***
#
# Given a reference to a hash containing an AppInfo block (such as
# that initialized by parse_StdAppInfo()), returns a packed string
# that can be written to the PDB file.
sub pack_StdAppInfo
{
	my $appinfo = shift;
	my $retval;
	my $i;

	# Create the bitfield of renamed categories
	my $renamed;

	$renamed = 0;
	for ($i = 0; $i < numCategories; $i++)
	{
		if ($appinfo->{categories}[$i]{renamed})
		{
			$renamed |= (1 << $i);
		}
	}
	$retval = pack("n", $renamed);

	# There have to be exactly 16 categories in the AppInfo block,
	# even though $appinfo->{categories} may have been mangled
	# by a naive (or clever) user or broken program.
	for ($i = 0; $i < numCategories; $i++)
	{
		my $name;		# Category name

		# This is mainly to stop Perl 5.6 from complaining if
		# the category name is undefined.
		if ((!defined($appinfo->{categories}[$i]{name})) ||
		    $appinfo->{categories}[$i]{name} eq "")
		{
			$name = "";
		} else {
			$name = $appinfo->{categories}[$i]{name};
		}

		$retval .= pack("a" . categoryLength,
			$appinfo->{categories}[$i]{name});
	}

	# Ditto for category IDs
	for ($i = 0; $i < numCategories; $i++)
	{
		$retval .= pack("C", $appinfo->{categories}[$i]{id});
	}

	# Last unique ID, and alignment padding
	$retval .= pack("Cx", $appinfo->{lastUniqueID});

	$retval .= $appinfo->{other} if defined($appinfo->{other});

	return $retval;
}

=head2 PackAppInfoBlock

    $pdb = new Palm::StdAppInfo;
    $data = $pdb->PackAppInfoBlock();

If your application's AppInfo block contains standard category support
and nothing else, you may choose to just inherit this method instead
of writing your own C<PackAppInfoBlock> method. Otherwise, see the
example in L<"SYNOPSIS">.

=cut
#'

sub PackAppInfoBlock
{
	my $self = shift;

	return &pack_StdAppInfo($self->{appinfo});
}

=head2 addCategory

    $pdb->addCategory($name [, $id [, $renamed]]);

Adds a category to $pdb.

The $name argument specifies the new category's name.

The optional $id argument specifies the new category's numeric ID; if
omitted or undefined, &addCategory will pick one.

The optional $renamed argument is a boolean value indicating whether
the new category should be marked as having been modified. This
defaults to true since, conceptually, &addCategory doesn't really add
a category: it finds one whose name happens to be empty, and renames
it.

Returns a true value if successful, false otherwise. In case of
failure, &addCategory sets $Palm::StdAppInfo::error to an error
message.

=cut
#'
sub addCategory
{
	my $self = shift;	# PDB
	my $name = shift;	# Category name
	my $id = shift;		# Category ID (optional)
	my $renamed = $#_ >= 0 ? $_[0] : 1;
				# Flag: was the category renamed (optional)
				# This initialization may look weird,
				# but it's this way so that it'll
				# default to true if omitted.
	my $categories = $self->{appinfo}{categories};
	my $i;
	my %used;		# Category IDs in use

	# Collect all the IDs in the current list
	for (@{$categories})
	{
		next if !defined($_->{name}) || $_->{name} eq "";
		$used{$_->{id}} = 1;
	}

	if (defined($id))
	{
		# Sanity check: make sure this ID isn't already in use
		if (defined($used{$id}))
		{
			$error = "Category ID already in use";
			return undef;
		}
	} else {
		# Find an unused category number, if none was specified
		for ($id = 128; $id < 256; $id++)
		{
			last if !defined($used{$id});
		}
	}

	# Go through the list of categories, looking for an unused slot
	for ($i = 0; $i < numCategories; $i++)
	{
		# Ignore named categories
		next unless !defined($categories->[$i]{name}) or
			$categories->[$i]{name} eq "";

		# Found an empty slot
		$categories->[$i]{name}    = $name;
		$categories->[$i]{id}      = $id;
		$categories->[$i]{renamed} = $renamed;
		return 1;
	}

	# If we get this far, there are no empty category slots
	$error = "No unused categories";
	return undef;
}

=head2 deleteCategory

    $pdb->deleteCategory($name);

Deletes the category with name $name. Actually, though, it doesn't
delete the category: it just changes its name to the empty string, and
marks the category as renamed.

=cut
#'
sub deleteCategory
{
	my $self = shift;
	my $name = shift;		# Category name

	for (@{$self->{appinfo}{categories}})
	{
		# Find the category named $name
		next if $_->{name} ne $name;

		# Erase this category
		$_->{name} = "";
		$_->{renamed} = 1;
	}
}

=head2 renameCategory

    $pdb->renameCategory($oldname, $newname);

Renames the category named $oldname to $newname.

If successful, returns a true value. If there is no category named
$oldname, returns a false value and sets $Palm::StdAppInfo::error to
an error message.

=cut
#'
sub renameCategory
{
	my $self = shift;
	my $oldname = shift;
	my $newname = shift;

	for (@{$self->{appinfo}{categories}})
	{
		# Look for a category named $oldname
		next if !defined($_->{name}) || $_->{name} ne $oldname;

		# Found it. Rename it and mark it as renamed.
		$_->{name} = $newname;
		$_->{renamed} = 1;
		return 1;
	}

	$error = "No such category";
	return undef;
}

1;
__END__

=head1 AUTHOR

Andrew Arensburger E<lt>arensb@ooblick.comE<gt>

=head1 SEE ALSO

Palm::PDB(3)

=cut

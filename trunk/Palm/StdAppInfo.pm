# Palm::StdAppInfo.pm
#
# Class for dealing with standard AppInfo blocks in PDBs.
#
#	Copyright (C) 1999, 2000, Andrew Arensburger.
#	You may distribute this file under the terms of the Artistic
#	License, as specified in the README file.
#
# $Id: StdAppInfo.pm,v 1.3 2000-05-07 06:33:56 arensb Exp $

# XXX - Write POD

# XXX - Describe the fields that StdAppInfo creates

# XXX - Methods for adding, removing categories

use strict;
package Palm::StdAppInfo;
use Palm::Raw();

# Don't harass me about these variables
use vars qw( $VERSION @ISA $numCategories $categoryLength $stdAppInfoSize );

$VERSION = (qw( $Revision: 1.3 $ ))[1];
@ISA = qw( Palm::Raw );

=head1 NAME

Palm::StdAppInfo - Handles standard AppInfo block

=head1 SYNOPSIS

    package MyPDBHandler;
    use Palm::StdAppInfo();

    @ISA = qw( Palm::StdAppInfo );

=head1 DESCRIPTION

Many Palm applications use a common format for keeping track of categories.
The C<Palm::StdAppInfo> class deals with this common format.

A standard AppInfo block begins with:

	short	renamed;	// Bitmap of renamed category names
	char	labels[16][16];	// Array of category names
	char	uniqueIDs[16];	// Category IDs
	char	lastUniqueID;
	char	padding;	// For word alignment

=head1 FUNCTIONS

=cut
#'

$numCategories = 16;		# Number of categories in AppInfo block
$categoryLength = 16;		# Length of category names
$stdAppInfoSize = 2 +		# Length of a standard AppInfo block
		($categoryLength * $numCategories) +
		$numCategories +
		1 + 1;

=head2 seed_StdAppInfo

    &Palm::StdAppInfo::seed_StdAppInfo(\%appinfo);

Creates the standard fields in an existing AppInfo hash.

=cut

# seed_StdAppInfo
# *** THIS IS NOT A METHOD ***
# Given a reference to an appinfo hash, creates all of the fields for
# a new AppInfo block.
sub seed_StdAppInfo
{
	my $appinfo = shift;

	$appinfo->{renamed} = 0;
	@{$appinfo->{categories}} = [ "Unfiled" ];
	@{$appinfo->{uniqueIDs}} = [ 0 ];
	$appinfo->{lastUniqueID} = 1;		# 0 means "Unfiled", by
						# convention

	# Make sure there are $numCategories categories, just for
	# neatness
	$#{$appinfo->{categories}} = $Palm::StdAppInfo::numCategories-1;
	$#{$appinfo->{uniqueIDs}}  = $Palm::StdAppInfo::numCategories-1;
}

=head2 newStdAppInfo

    $appinfo = Palm::StdAppInfo->newStdAppInfo;

Like C<seed_StdAppInfo>, but creates the AppInfo hash and returns it.

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

There are very few reasons to use this, and even fewer good ones.

=cut

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

This function is intended to be called from within a PDB helper class's
C<ParseAppInfoBlock> method.

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

	# The argument to unpack() isn't hard to understand, it's just
	# hard to write in a readable fashion.
	$unpackstr =		# Argument to unpack(), since it's hairy
		"n" .		# Renamed categories
		"a$categoryLength" x $numCategories .
				# Category labels
		"C" x $numCategories .
				# Category IDs
		"C" .		# Last unique ID
		"x";

	# Unpack the data
	($renamed,
	 @labels[0..($numCategories-1)],
	 @uniqueIDs[0..($numCategories-1)],
	 $lastUniqueID) =
		unpack $unpackstr, $data;

	# Clean this stuff up a bit
	for (@labels)
	{
		s/\0.*$//;	# Trim at NUL
	}

	# Now put the data into $appinfo
	$appinfo->{renamed} = $renamed;
	$appinfo->{categories} = [ @labels ];
	$appinfo->{uniqueIDs} = [ @uniqueIDs ];
	$appinfo->{lastUniqueID} = $lastUniqueID;

	return $stdAppInfoSize;
}

=head2 ParseAppInfoBlock

    $pdb = new Palm::StdAppInfo;
    $pdb->ParseAppInfoBlock($data);

If your application's AppInfo block contains standard category support
and nothing else, you may choose to just inherit this method instead
of writing your own C<ParseAppInfoBlock> method.

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

This function is intended to be called from within a PDB helper class's
C<PackAppInfoBlock> method.

C<pack_StdAppInfo> takes an AppInfo hash and packs it as a string of
raw data that can be written to a PDB.

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

	$retval = pack("n", $appinfo->{renamed});

	# There have to be exactly 16 categories in the AppInfo block,
	# even though $appinfo->{categories} may have been mangled
	# by a naive (or clever) user or broken program.
	for ($i = 0; $i < $numCategories; $i++)
	{
		$retval .= pack("a$categoryLength",
			$appinfo->{categories}[$i]);
	}

	# Ditto for category IDs
	for ($i = 0; $i < $numCategories; $i++)
	{
		$retval .= pack("C", $appinfo->{uniqueIDs}[$i]);
	}

	# Last unique ID, and alignment padding
	$retval .= pack("Cx", $appinfo->{lastUniqueID});

	return $retval;
}

=head2 PackAppInfoBlock

    $pdb = new Palm::StdAppInfo;
    $data = $pdb->PackAppInfoBlock();

If your application's AppInfo block contains standard category support
and nothing else, you may choose to just inherit this method instead
of writing your own C<PackAppInfoBlock> method.

=cut
#'

sub PackAppInfoBlock
{
	my $self = shift;

	return &pack_StdAppInfo($self->{appinfo});
}

1;
__END__

=head1 AUTHOR

Andrew Arensburger E<lt>arensb@ooblick.comE<gt>

=head1 SEE ALSO

Palm::PDB(3)

=cut

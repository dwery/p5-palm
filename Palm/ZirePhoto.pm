# Palm::TealMeal.pm
# 
# Perl class for dealing with Zire71 photo database.
#
#	Copyright (C) 2003, Alessandro Zummo.
#	You may distribute this file under the terms of the Artistic
#	License, as specified in the README file.
#
# $Id: ZirePhoto.pm,v 1.1 2003-06-24 14:28:11 azummo Exp $


use strict;
package Palm::ZirePhoto;
use Palm::Raw();

use vars qw( $VERSION @ISA );

# One liner, to allow MakeMaker to work.
$VERSION = do { my @r = (q$Revision: 1.1 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };

@ISA = qw( Palm::Raw );

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

sub new_Record
{
	my $classname = shift;
	my $retval = $classname->SUPER::new_Record(@_);

	return $retval;
}

sub ParseRecord
{
	my $self	= shift;
	my %record	= @_;
	my $data	= $record{'data'};

	delete $record{offset};		# This is useless
	delete $record{data};		# No longer necessary

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

	$record{'time1'} -= 2082844800;
	$record{'time2'} -= 2082844800;

	$record{'name'} = substr($record{'name'}, 0, $record{'nameSize'});

	return \%record;
}

sub PackRecord
{
	my $self	= shift;
	my $record	= shift;
	my $retval	= {};

	return $retval;
}

1;

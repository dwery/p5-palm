# Palm::Mail.pm
# 
# Perl class for dealing with Palm Mail databases. 
#
#	Copyright (C) 1999, 2000, Andrew Arensburger.
#	You may distribute this file under the terms of the Artistic
#	License, as specified in the README file.
#
# $Id: Mail.pm,v 1.5 2000-04-20 05:42:22 arensb Exp $

package Palm::Mail;
($VERSION) = '$Revision: 1.5 $ ' =~ /\$Revision:\s+([^\s]+)/;

=head1 NAME

Palm::Mail - Handler for Palm Mail databases.

=head1 SYNOPSIS

    use Palm::Mail;

=head1 DESCRIPTION

The Mail PDB handler is a helper class for the Palm::PDB package. It
parses Mail databases.

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
    $pdb->{"appinfo"}{"unsent"}
    $pdb->{"appinfo"}{"sigOffset"}

I don't know what these are.

=head2 Sort block

    $pdb->{"sort"}

This is a scalar, the raw data of the sort block.

=head2 Records

    $record = $pdb->{"records"}[N]

    $record->{"year"}
    $record->{"month"}
    $record->{"day"}
    $record->{"hour"}
    $record->{"minute"}

The message's timestamp.

    $record->{"is_read"}

This is defined and true iff the message has been read.

    $record->{"has_signature"}

For outgoing messages, this is defined and true iff the message should
have a signature attached. The signature itself is stored in the
"Saved Preferences.prc" database, and is of type "mail" with ID 2.

    $record->{"confirm_read"}

If this is defined and true, then the sender requests notification
when the message has been read.

    $record->{"confirm_delivery"}

If this is defined and true, then the sender requests notification
when the message has been delivered.

    $record->{"priority"}

An integer in the range 0-2, for high, normal, or low priority,
respectively.

    $record->{"addressing"}

An integer in the range 0-2, indicating the addressing type: To, Cc,
or Bcc respectively. I don't know what this means.

    $record->{"subject"}
    $record->{"from"}
    $record->{"to"}
    $record->{"cc"}
    $record->{"bcc"}
    $record->{"replyTo"}
    $record->{"sentTo"}

Strings, the various header fields.

    $record->{"body"}

A string, the body of the message.

=head1 METHODS

=cut
#'

use Palm::Raw();

@ISA = qw( Palm::Raw );

$numCategories = 16;		# Number of categories in AppInfo block
$categoryLength = 16;		# Length of category names

sub import
{
	&Palm::PDB::RegisterPDBHandlers(__PACKAGE__,
		[ "mail", "DATA" ],
		);
}

=head2 new

  $pdb = new Palm::Mail;

Create a new PDB, initialized with the various Palm::Mail fields
and an empty record list.

Use this method if you're creating a Mail PDB from scratch.

=cut
#'

sub new
{
	my $classname	= shift;
	my $self	= $classname->SUPER::new(@_);
			# Create a generic PDB. No need to rebless it,
			# though.

	$self->{"name"} = "MailDB";	# Default
	$self->{"creator"} = "mail";
	$self->{"type"} = "DATA";
	$self->{"attributes"}{"resource"} = 0;
				# The PDB is not a resource database by
				# default, but it's worth emphasizing,
				# since MailDB is explicitly not a PRC.

	# Initialize the AppInfo block
	$self->{"appinfo"} = {
		renamed		=> 0,	# Dunno what this is
		categories	=> [],	# List of category names
		uniqueIDs	=> [],	# List of category IDs
# XXX		lastUniqueID	=> ?
		sortOrder	=> undef,	# XXX - ?
		unsent		=> undef,	# XXX - ?
		sigOffset	=> 0,		# XXX - ?
	};

	# Make sure there are $numCategories categories
	$#{$self->{"appinfo"}{"categories"}} = $numCategories-1;
	$#{$self->{"appinfo"}{"uniqueIDs"}} = $numCategories-1;

	# If nothing else, there should be an "Unfiled" category, with
	# ID 0.
	$self->{"appinfo"}{"categories"}[0] = "Unfiled";
	$self->{"appinfo"}{"uniqueIDs"}[0] = 0;

	$self->{"sort"} = undef;	# Empty sort block

	$self->{"records"} = [];	# Empty list of records

	return $self;
}

=head2 new_Record

  $record = $pdb->new_Record;

Creates a new Mail record, with blank values for all of the fields.

Note: the time given by the C<year>, C<month>, C<day>, C<hour>, and
C<minute> fields in the new record are initialized to the time when
the record was created. They should be reset to the time when the
message was sent.

=cut

sub new_Record
{
	my $classname = shift;
	my $retval = $classname->SUPER::new_Record(@_);

	# Set the date and time on this message to today and now. This
	# is arguably bogus, since the Date: header on a message ought
	# to represent the time when the message was sent, rather than
	# the time when the user started composing it, but this is
	# better than nothing.

	($retval->{"year"},
	 $retval->{"month"},
	 $retval->{"day"},
	 $retval->{"hour"},
	 $retval->{"minute"}) = (localtime(time))[5,4,3,2,1];

	$retval->{"is_read"} = 0;	# Message hasn't been read yet.

	# No delivery service notification (DSN) by default.
	$retval->{"confirm_read"} = 0;
	$retval->{"confirm_delivery"} = 0;

	$retval->{"priority"} = 1;	# Normal priority

	$retval->{"addressing"} = 0;	# XXX - ?

	# All header fields empty by default.
	$retval->{"from"} = undef;
	$retval->{"to"} = undef;
	$retval->{"cc"} = undef;
	$retval->{"bcc"} = undef;
	$retval->{"replyTo"} = undef;
	$retval->{"sentTo"} = undef;

	$retval->{"body"} = "";
}

# ParseAppInfoBlock
# Parse the AppInfo block for Mail databases.
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
	my $unsent;
	my $sigOffset;		# XXX - Offset of signature?
#  my $padding;
#  my $extra;

	my $unpackstr =		# Argument to unpack(), since it's hairy
		"n" .		# Renamed categories
		"a$categoryLength" x $numCategories .
				# Category labels
		"C" x $numCategories .
				# Category IDs
		"C" .		# Last unique ID
		"x3" .		# Padding
		"n" .		# Dirty AppInfo (what is this?)
		"Cx" .		# Sort order
		"N" .		# Unique ID of unsent message (what is this?)
		"n";		# Signature offset
	my $appinfo = {};

#  print "AppInfo block:\n";
#  print "\tRaw: [$data]\n";
#  print "Parsing AppInfo block, length ", length($data), "\n";

	($renamed, @labels[0..($numCategories-1)],
	 @uniqueIDs[0..($numCategories-1)], $lastUniqueID, $dirtyAppInfo,
	 $sortOrder, $unsent, $sigOffset) =
		unpack $unpackstr, $data;

	for (@labels)
	{
		s/\0.*//;	# Trim at first NUL
	}

#  print "\tCategories:\n\t\t[", join("]\n\t\t[", @labels), "]\n";
#  print "\tCategory IDs:\n\t\t[", join("]\n\t\t[", @uniqueIDs), "]\n";
#  print "\tLast unique ID: [$lastUniqueID]\n";
#  #print "\tPadding: [$padding]\n";
#  print "\tDirty AppInfo: [$dirtyAppInfo]\n";
#  print "\tSort order: [$sortOrder]\n";
#  print "\tUnsent: [$unsent]\n";
#  printf "\tSig offset: 0x%04x\n", $sigOffset;
#  #print "\textra == [$extra] (", length($extra), ")\n";

	$appinfo->{"renamed"} = $renamed;
	$appinfo->{"categories"} = [ @labels ];
	$appinfo->{"uniqueIDs"} = [ @uniqueIDs ];
	$appinfo->{"lastUniqueID"} = $lastUniqueID;
	$appinfo->{"dirty_AppInfo"} = $dirtyAppInfo;
	$appinfo->{"sort_order"} = $sortOrder;
	$appinfo->{"unsent"} = $unsent;
	$appinfo->{"sig_offset"} = $sigOffset;

	return $appinfo;
}

sub PackAppInfoBlock
{
	my $self = shift;
	my $retval;

	$retval = pack("n", $self->{"appinfo"}{"renamed"});
#  print "Length(\$retval) == ", length($retval), "\n";
#  print "Packing ", $#{$self->{"appinfo"}{"categories"}}, " categories\n";
#  	for (@{$self->{"appinfo"}{"categories"}})
#  	{
#  		$retval .= pack("a$categoryLength", $_);
#  	}
	$retval .= pack("a$categoryLength" x $numCategories,
			@{$self->{"appinfo"}{"categories"}});
#  print "Length(\$retval) == ", length($retval), "\n";
#  print "Packing ", $#{$self->{"appinfo"}{"uniqueIDs"}}, " uniqueIDs\n";
#  	for (@{$self->{"appinfo"}{"uniqueIDs"}})
#  	{
#  		$retval .= pack("C", $_);
#  	}
	$retval .= pack("C"x$numCategories, @{$self->{"appinfo"}{"uniqueIDs"}});
#  print "Length(\$retval) == ", length($retval), "\n";
	$retval .= pack "C x3 n Cx N nx",
		$self->{"appinfo"}{"lastUniqueID"},
		$self->{"appinfo"}{"dirty_AppInfo"},
		$self->{"appinfo"}{"sort_order"},
		$self->{"appinfo"}{"unsent"},
		$self->{"appinfo"}{"sig_offset"};
#  print "length of appinfo block: ", length($retval), "\n";

	return $retval;
}

sub ParseRecord
{
	my $self = shift;
	my %record = @_;
	my $data = $record{"data"};

	delete $record{"offset"};	# This is useless
	delete $record{"data"};

#  print "Record:\n";
#  print "\tRaw: [$data]\n";

	my $date;
	my $hour;
	my $minute;
	my $flags;
	my $subject;
	my $from;
	my $to;
	my $cc;
	my $bcc;
	my $replyTo;
	my $sentTo;
	my $body;
	my $extra;		# Extra field after body. I don't know what
				# it is.
	my $unpackstr =
		"n" .		# Date
		"C" .		# Hour
		"C" .		# Minute
		"n";		# Flags

	($date, $hour, $minute, $flags) = unpack $unpackstr, $data;

	my $year;
	my $month;
	my $day;

	if ($date != 0)
	{
		$day   =  $date       & 0x001f;	# 5 bits
		$month = ($date >> 5) & 0x000f;	# 4 bits
		$year  = ($date >> 9) & 0x007f;	# 7 bits (years since 1904)
		$year += 1904;

		$record{"year"}   = $year;
		$record{"month"}  = $month;
		$record{"day"}    = $day;
		$record{"hour"}   = $hour;
		$record{"minute"} = $minute;
#  print "\tDate: [$date] ($day/$month/$year)\n";
#  print "\tTime: [$hour]:[$minute]\n";
	}

	my $is_read		= ($flags & 0x8000);
	my $has_signature	= ($flags & 0x4000);
	my $confirm_read	= ($flags & 0x2000);
	my $confirm_delivery	= ($flags & 0x1000);
	my $priority	= ($flags >> 10) & 0x03;
	my $addressing	= ($flags >>  8) & 0x03;

	# The signature is problematic: it's not stored in
	# "MailDB.pdb": it's actually in "Saved Preferences.pdb". Work
	# around this somehow; either read it from "Saved
	# Preferences.pdb" or, more simply, just read ~/.signature if
	# it exists.

	$record{"is_read"} = 1 if $is_read;
	$record{"has_signature"} = 1 if $has_signature;
	$record{"confirm_read"} = 1 if $confirm_read;
	$record{"confirm_delivery"} = 1 if $confirm_delivery;
	$record{"priority"} = $priority;
	$record{"addressing"} = $addressing;

#  printf "\tFlags: [0x%08x]", $flags;
#  print " READ" if $is_read;
#  print " SIG" if $has_signature;
#  print " CONFREAD" if $confirm_read;
#  print " CONFDELIVER" if $confirm_delivery;
#  print "\n";
#  print "\tPriority: [$priority] (", ("High","Normal","Low")[$priority], ")\n";
#  print "\tAddressing: [$addressing] (", ("To", "Cc", "Bcc")[$addressing] ,")\n";

	my $fields = substr $data, 6;
	my @fields = split /\0/, $fields;

	($subject, $from, $to, $cc, $bcc, $replyTo, $sentTo, $body,
	 $extra) = @fields;

	# Clean things up a bit

	# Multi-line values are bad in these headers. Replace newlines
	# with commas. Ideally, we'd use arrays for multiple
	# recipients, but that would involve parsing addresses, which
	# is non-trivial. Besides, most likely we'll just wind up
	# sending these strings as they are to 'sendmail', which is
	# better equipped to parse them.

	$to =~ s/\s*\n\s*(?!$)/, /gs;
	$cc =~ s/\s*\n\s*(?!$)/, /gs;
	$bcc =~ s/\s*\n\s*(?!$)/, /gs;
	$replyTo =~ s/\s*\n\s*(?!$)/, /gs;
	$sentTo =~ s/\s*\n\s*(?!$)/, /gs;

#  print "\tSubject: [$subject]\n";
#  print "\tFrom: [$from]\n";
#  print "\tTo: [$to]\n";
#  print "\tCc: [$cc]\n";
#  print "\tBcc: [$bcc]\n";
#  print "\tReply-To: [$replyTo]\n";
#  print "\tSent-To: [$sentTo]\n";
#  print "\tBody: [$body]\n";
#  print "\tLeftover fields (", $#fields-7, "): [", join("] [", @fields[8..$#fields]), "]\n";

	$record{"subject"} = $subject;
	$record{"from"} = $from;
	$record{"to"} = $to;
	$record{"cc"} = $cc;
	$record{"bcc"} = $bcc;
	$record{"reply_to"} = $replyTo;
	$record{"sent_to"} = $sentTo;
	$record{"body"} = $body;
	$record{"extra"} = $extra;

	# XXX - When sending, if there are any newlines in the header,
	# make sure there are spaces at the beginning of the next line
	# to indicate a continuation line.

	return \%record;
}

sub PackRecord
{
	my $self = shift;
	my $record = shift;
	my $retval;
	my $rawDate;
	my $flags;

	$rawDate = ($record->{"day"} & 0x001f) |
		(($record->{"month"} & 0x000f) << 5) |
		((($record->{"year"} - 1904) & 0x07f) << 9);
	$flags = 0;
	$flags |= 0x8000 if $record->{"is_read"};
	$flags |= 0x4000 if $record->{"has_signature"};
	$flags |= 0x2000 if $record->{"confirm_read"};
	$flags |= 0x1000 if $record->{"confirm_delivery"};
	$flags |= (($record->{"priority"} & 0x03) << 10);
	$flags |= (($record->{"addressing"} & 0x03) << 8);

	$retval = pack "n C C n",
		$rawDate,
		$record->{"hour"},
		$record->{"minute"},
		$flags;

	$retval .= join "\0",
		$record->{"subject"},
		$record->{"from"},
		$record->{"to"},
		$record->{"cc"},
		$record->{"bcc"},
		$record->{"reply_to"},
		$record->{"sent_to"},
		$record->{"body"};
	$retval .= "\0";

	return $retval;
}

1;
__END__

=head1 AUTHOR

Andrew Arensburger E<lt>arensb@ooblick.comE<gt>

=head1 SEE ALSO

Palm::PDB(1)

=cut

# Palm::Datebook.pm
# 
# Perl class for dealing with Palm DateBook databases. 
#
#	Copyright (C) 1999, Andrew Arensburger.
#	You may distribute this file under the terms of the Artistic
#	License, as specified in the README file.
#
# $Id: Datebook.pm,v 1.2 1999-11-18 06:20:14 arensb Exp $

package Palm::Datebook;

use Palm::Raw();

@ISA = qw( Palm::Raw );

$numCategories = 16;		# Number of categories in AppInfo block
$categoryLength = 16;		# Length of category names

sub import
{
	&Palm::PDB::RegisterPDBHandlers(__PACKAGE__,
		[ "date", "DATA" ],
		);
}

# ParseAppInfoBlock
# Parse the AppInfo block for Datebook databases.
# There appears to be one byte of padding at the end.
sub ParseAppInfoBlock
{
	my $self = shift;
	my $data = shift;
	my $renamed;		# Renamed categories
	my @labels;		# Category labels
	my @uniqueIDs;		# Category IDs
	my $lastUniqueID;
	my $startOfWeek;
	my $unpackstr =		# Argument to unpack(), since it's hairy
		"n" .			# Renamed categories
		"a$categoryLength" x $numCategories .
					# Category names
		"C" x $numCategories .	# Category IDs
		"C" .			# Last unique ID
		"x3" .			# Padding
		"C";			# Start of week
	my $i;
	my $appinfo = {};

	($renamed, @labels[0..($numCategories-1)],
	 @uniqueIDs[0..($numCategories-1)], $lastUniqueID, $startOfWeek) =
		unpack $unpackstr, $data;

	for (@labels)
	{
		s/\0.*//;		# Trim at NUL
	}

#  print "AppInfo block:\n";
#  printf "\trenamed: 0x%02x\n", $renamed;
#  print "\tCategories:\n\t\t[", join("]\n\t\t[", @labels), "]\n";
#  print "\tCategory IDs:\n\t\t[", join("]\n\t\t[", @uniqueIDs), "]\n";
#  print "\tLast unique ID: [$lastUniqueID]\n";
#  print "\tStart of week: [$startOfWeek]\n";

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

	# The labels exist, but they don't appear to be used.
	$appinfo->{"start_of_week"} = $startOfWeek;

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
	$retval .= pack("C x3 C x1",
		$self->{"appinfo"}{"lastUniqueID"},
		$self->{"appinfo"}{"start_of_week"});

	return $retval;
}

sub ParseRecord
{
	my $self = shift;
	my %record = @_;
	my $data;

	delete $record{"offset"};	# This is useless

	# Untimed events have 0xff for $startHour, $startMinute,
	# $endHour and $endMinute.
	my $startHour;		# In 24-hour format
	my $startMinute;
	my $endHour;		# In 24-hour format
	my $endMinute;
	my $rawDate;
	my $flags;
	my $unpackstr =		# Argument to unpack().
		"C C" .		# Start hour, minute
		"C C" .		# End hour, minute
		"n" .		# Raw date
		"n";		# Flags

	$data = $record{"data"};
	($startHour, $startMinute, $endHour, $endMinute, $rawDate,
	 $flags) =
		unpack $unpackstr, $data;
	$data = substr $data, 8;	# Chop off the part we've just parsed

	my $year;
	my $month;
	my $day;

	$day   =  $rawDate       & 0x001f;	# 5 bits
	$month = ($rawDate >> 5) & 0x000f;	# 4 bits
	$year  = ($rawDate >> 9) & 0x007f;	# 7 bits (years since 1904)
	$year += 1904;

	$record{"start_hour"} = $startHour;
	$record{"start_minute"} = $startMinute;
	$record{"end_hour"} = $endHour;
	$record{"end_minute"} = $endMinute;
	$record{"day"} = $day;
	$record{"month"} = $month;
	$record{"year"} = $year;

	# Flags
	my $when_changed	= ($flags & 0x8000 ? 1 : 0);
	my $have_alarm		= ($flags & 0x4000 ? 1 : 0);
	my $have_repeat		= ($flags & 0x2000 ? 1 : 0);
	my $have_note		= ($flags & 0x1000 ? 1 : 0);
	my $have_exceptions	= ($flags & 0x0800 ? 1 : 0);
	my $have_description	= ($flags & 0x0400 ? 1 : 0);

	$record{"other_flags"} = $flags & 0x03ff;

#  print "\tStart hour: [$startHour]\n";
#  print "\tStart minute: [$startMinute]\n";
#  print "\tEnd hour: [$endHour]\n";
#  print "\tEnd minute: [$endMinute]\n";
#  print "\tDate: raw [$rawDate] ($day/$month/$year)\n";
#  printf "\tFlags: 0x%02x:", $flags;
#  print " WHEN" if $when_changed;
#  print " ALARM" if $have_alarm;
#  print " REPEAT" if $have_repeat;
#  print " NOTE" if $have_note;
#  print " EXCEPTIONS" if $have_exceptions;
#  print " DESC" if $have_description;
#  print "\n";

	if ($when_changed)
	{
		$record{"when_changed"} = 1;
	}

	if ($have_alarm)
	{
		my $advance;
		my $adv_unit;

#  print "    Alarm:\n";
		($advance, $adv_unit) = unpack "cC", $data;
		$data = substr $data, 2;	# Chop off alarm data
#  print "\tAlarm advance: [$advance]\n";
#  print "\tAdvance unit: [$adv_unit] (", ("Minutes", "Hours", "Days")[$adv_unit], ")\n";

		$record{"alarm"}{"advance"} = $advance;
		$record{"alarm"}{"unit"} = $adv_unit;
	}

	if ($have_repeat)
	{
		my $type;
		my $endDate;
		my $frequency;
		my $repeatOn;
		my $repeatStartOfWeek;
		my $unknown;

#  print "    Repeat:\n";
		($type, $endDate, $frequency, $repeatOn, $repeatStartOfWeek,
		 $unknown) =
			unpack "Cx n C C C C", $data;
		$data = substr $data, 8;	# Chop off repeat part

		$record{"repeat"}{"type"} = $type;
		$record{"repeat"}{"unknown"} = $unknown;
#  printf "unknown == 0x%02x [%c]\n", $record{"repeat"}{"unknown"}, $record{"repeat"}{"unknown"};

#  print "\tType: [$type] (", ("none", "Daily", "Weekly", "Monthly by day", "Monthly by date", "Yearly")[$type], ")\n";
#  print "\tEnd hour: [$endHour]\n";
#  print "\tEnd minute: [$endMinute]\n";

		if ($endDate != 0xffff)
		{
			my $endYear;
			my $endMonth;
			my $endDay;

			$endDay   =  $endDate       & 0x001f;	# 5 bits
			$endMonth = ($endDate >> 5) & 0x000f;	# 4 bits
			$endYear  = ($endDate >> 9) & 0x007f;	# 7 bits (years
			$endYear += 1904;			# since 1904)
#  print "\tEnd date: [$endDate] ($endDay/$endMonth/$endYear)\n";

			$record{"repeat"}{"end_day"} = $endDay;
			$record{"repeat"}{"end_month"} = $endMonth;
			$record{"repeat"}{"end_year"} = $endYear;
		}

#  print "\tFrequency: [$frequency]\n";
#  print "\tRepeat on: [$repeatOn]\n";
#  print "\tRepeat start of week: [$repeatStartOfWeek]\n";

		$record{"repeat"}{"frequency"} = $frequency;
		if ($type == 2)
		{
			# "Weekly" repeat
			my $i;
			my @days;

			# Build an array of 7 elements (one for each
			# day of the week). Each element is set iff
			# the appointment repeats on that day.
			for ($i = 0; $i < 7; $i++)
			{
				if ($repeatOn & (1 << $i))
				{
					$days[$i] = 1;
				} else {
					$days[$i] = 0;
				}
			}

			$record{"repeat"}{"repeat_days"} = [ @days ];
			$record{"repeat"}{"start_of_week"} =
				$repeatStartOfWeek;
					# I don't know what this is,
					# but the Datebook app appears
					# to perform some hairy
					# calculations involving this.
		} elsif ($type == 3) {
			# "Monthly by day" repeat
			# If "weeknum" is 5, it means the last week of
			# the month
			$record{"repeat"}{"weeknum"} = int($repeatOn / 7);
			$record{"repeat"}{"daynum"} = $repeatOn % 7;
		}
	}

	if ($have_exceptions)
	{
		my $numExceptions;
		my @exceptions;

#  print "    Exceptions:\n";
#  print "      Raw: [$data]\n";
		$numExceptions = unpack "n", $data;
		$data = substr $data, 2;
		@exceptions = unpack "n" x $numExceptions, $data;
		$data = substr $data, 2 * $numExceptions;

#  print "\t# of exceptions: [$numExceptions]\n";

		my $exception;
		foreach $exception (@exceptions)
		{
			my $year;
			my $month;
			my $day;

			$day   =  $exception       & 0x001f;
			$month = ($exception >> 5) & 0x000f;
			$year  = ($exception >> 9) & 0x007f;
			$year += 1904;
#  print "\tException: [$exception] ($day/$month/$year)\n";

			push @{$record{"exceptions"}},
				[ $day, $month, $year ];
		}
	}

	my @fields = split /\0/, $data;

	if ($have_description)
	{
		my $description;

		$description = shift @fields;
#  print "\tDescription: [$description]\n";
		$record{"description"} = $description;
	}

	if ($have_note)
	{
		my $note;

		$note = shift @fields;
#  print "\tNote: [$note]\n";
		$record{"note"} = $note;
	}

#  print "\tLeftover fields: [", join("] [", @fields), "]\n";

	return \%record;
}

sub PackRecord
{
	my $self = shift;
	my $record = shift;
	my $retval;

	my $rawDate;
	my $flags;

	$rawDate = ($record->{"day"}            & 0x001f) |
		  (($record->{"month"}          & 0x000f) << 5) |
		  ((($record->{"year"} - 1904)  & 0x007f) << 9);

	# XXX - Better to collect data first, then build flags.
	$flags = $record->{"other_flags"};
#  	$flags |= 0x8000 if $record->{"when_changed"};
#  	$flags |= 0x4000 if keys %{$record->{"alarm"}} ne ();
#  	$flags |= 0x2000 if keys %{$record->{"repeat"}} ne ();
#  	$flags |= 0x1000 if $record->{"note"} ne "";
#  	$flags |= 0x0800 if $#{$record->{"exceptions"}} >= 0;
#  	$flags |= 0x0400 if $record->{"description"} ne "";

#  	$retval = pack "C C C C n n",
#  		$record->{"start_hour"},
#  		$record->{"start_minute"},
#  		$record->{"end_hour"},
#  		$record->{"end_minute"},
#  		$rawDate,
#  		$flags;

	if ($record->{"when_changed"})
	{
		$flags |= 0x8000;
	}

	my $alarm = undef;

	if (%{$record->{"alarm"}} ne ())
	{
		$flags |= 0x4000;
		$alarm = pack "c C",
			$record->{"alarm"}{"advance"},
			$record->{"alarm"}{"unit"};
	}

	my $repeat = undef;

	if (%{$record->{"repeat"}} ne ())
	{
		my $type;		# Repeat type
		my $endDate;
		my $repeatOn;
		my $repeatStartOfWeek = 0;

		$flags |= 0x2000;

		if (defined($record->{"repeat"}{"end_day"}))
		{
			# End date defined
			$endDate =
				($record->{"repeat"}{"end_day"} & 0x001f) |
				(($record->{"repeat"}{"end_month"}
					& 0x000f) << 5) |
				((($record->{"repeat"}{"end_year"} - 1904)
					& 0x007f) << 9);
		} else {
			# No end date defined
			$endDate = 0xffff;
		}

		if ($record->{"repeat"}{"type"} == 2)
		{
			# Weekly repeat
			my $i;

			$repeatOn = 0;
			for ($i = 0; $i < 7; $i++)
			{
				if ($record->{"repeat"}{"repeat_days"}[$i])
				{
					$repeatOn |= (1 << $i);
				}
			}
			$repeatStartOfWeek = $record->{"repeat"}{"start_of_week"};
		} elsif ($record->{"repeat"}{"type"} == 3)
		{
			# "Monthly by day" repeat
			my $weeknum = $record->{"repeat"}{"weeknum"};

			if ($weeknum > 5)
			{
				$weeknum = 5;
			}
			$repeatOn = ($record->{"repeat"}{"weeknum"} * 7) +
				($record->{"repeat"}{"daynum"} % 7);
		}

		$repeat = pack "Cx n C C C C",
			$record->{"repeat"}{"type"},
			$endDate,
			$record->{"repeat"}{"frequency"},
			$repeatOn,
			$repeatStartOfWeek,
			$record->{"repeat"}{"unknown"};
	}

	my $exceptions = undef;

	if (@{$record->{"exceptions"}} ne ())
	{
		my $numExceptions = $#{$record->{"exceptions"}} + 1;
		my $exception;

		$flags |= 0x0800;

		$exceptions = pack("n", $numExceptions);

		foreach $exception (@{$record->{"exceptions"}})
		{
			my $day		= $exception->[0];
			my $month	= $exception->[1];
			my $year	= $exception->[2];

			$exceptions .= pack("n",
				($day & 0x001f) |
				(($month & 0x000f) << 5) |
				((($year - 1904) & 0x007f) << 9));
		}
	}

	my $description = undef;

	if ($record->{"description"} ne "")
	{
		$flags |= 0x0400;
		$description = $record->{"description"} . "\0";
	}

	my $note = undef;

	if ($record->{"note"} ne "")
	{
		$flags |= 0x1000;
		$note = $record->{"note"} . "\0";
	}

#  printf "flags == 0x%04x\n", $flags;
	$retval = pack "C C C C n n",
		$record->{"start_hour"},
		$record->{"start_minute"},
		$record->{"end_hour"},
		$record->{"end_minute"},
		$rawDate,
		$flags;

	$retval .= $alarm;
	$retval .= $repeat;
	$retval .= $exceptions;
	$retval .= $description;
	$retval .= $note;

	return $retval;
}

1;
__END__

=head1 NAME

Palm::Datebook - Handler for Palm DateBook databases.

=head1 SYNOPSIS

    use Palm::Datebook;

=head1 DESCRIPTION

The Datebook PDB handler is a helper class for the Palm::PDB package.
It parses DateBook databases.

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

I don't know what this is.

=head2 Sort block

    $pdb->{"sort"}

This is a scalar, the raw data of the sort block.

=head2 Records

    $record = $pdb->{"records"}[N]

    $record->{"day"}
    $record->{"month"}
    $record->{"year"}

The day, month and year of the event. For repeating events, this is
the first date at which the event occurs.

    $record->{"start_hour"}
    $record->{"start_minute"}
    $record->{"end_hour"}
    $record->{"end_minute"}

The start and end times of the event. For untimed events, all of these
are 0xff.

    $record->{"when_changed"}

This is defined and true iff the "when info" for the record has
changed. I don't know what this means.

    $record->{"alarm"}{"advance"}
    $record->{"alarm"}{"unit"}

If the record has an alarm associated with it, the
%{$record->{"alarm"}} hash exists. The "unit" subfield is an integer:
0 for minutes, 1 for hours, 2 for days. The "advance" subfield
specifies how many units before the event the alarm should ring.
I<e.g.>, if "unit" is 1 and "advance" is 5, then the alarm will sound
5 hours before the event.

If "advance" is -1, then there is no alarm associated with this event.

    %{$record->{"repeat"}}

This has exists iff this is a repeating event.

    $record->{"repeat"}{"type"}

An integer which specifies the type of repeat:

=over 4

=item 0

no repeat.

=item 1

a daily event, one that occurs every day.

=item 2

a weekly event, one that occurs every week on the same dayZ<>(s). An
event may occur on several days every week, I<e.g.>, every Monday,
Wednesday and Friday.

For weekly events, the following fields are defined:

    @{$record->{"repeat"}{"repeat_days"}}

This is an array of 7 elements; each element is true iff the event
occurs on the corresponding day. I don't know whether the array begins
with Sunday, or with the start-of-week day as defined in the
preferences.

    $record->{"repeat"}{"start_of_week"}

I'm not sure what this is, but the Datebook app appears to perform
some hairy calculations involving this.

=item 3

a "monthly by day" event, I<e.g.>, one that occurs on the second
Friday of every month.

For "monthly by day" events, the following fields are defined:

    $record->{"repeat"}{"weeknum"}

The number of the week on which the event occurs. A value of 5 means
that the event occurs on the last week of the month.

    $record->{"repeat"}{"daynum"}

An integer, the day of the week on which the event occurs. Again, I
don't know whether 0 means Sunday, or the start-of-week day as defined
in the preferences.

=item 4

a "monthly by date" event, I<e.g.>, one that occurs on the 12th of
every month.

=item 5

a yearly event, I<e.g.>, one that occurs every year on December 25th.

    $record->{"repeat"}{"frequency"}

Specifies the frequency of the repeat. For instance, if the event is a
daily one, and $record->{"repeat"}{"frequency"} is 3, then the event
occurs every 3 days.

=back

    $record->{"repeat"}{"unknown"}

I don't know what this is.

    $record->{"repeat"}{"end_day"}
    $record->{"repeat"}{"end_month"}
    $record->{"repeat"}{"end_year"}

The last day, month and year on which the event occurs.

    @{$record->{"exceptions"}}
    $day   = $record->{"exceptions"}[N][0]
    $month = $record->{"exceptions"}[N][0]
    $year  = $record->{"exceptions"}[N][0]

If there are any exceptions to a repeating event, I<e.g.> a weekly
meeting that was cancelled one time, then the
@{$record->{"exceptions"}} array is defined.

Each element in this array is a reference to an anonymous array with
three elements: the day, month, and year of the exception.

    $record->{"description"}

A text string, the description of the event.

    $record->{"note"}

A text string, the note (if any) attached to the event.

=head1 AUTHOR

Andrew Arensburger E<lt>arensb@ooblick.comE<gt>

=head1 SEE ALSO

Palm::PDB(1)

=cut

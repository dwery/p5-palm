# Palm::PQA.pm
#
# Perl class for dealing with Palm PQA files.
#
#	Copyright (C) 2000, Andrew Arensburger.
#	You may distribute this file under the terms of the Artistic
#	License, as specified in the README file.
#
# $Id: PQA.pm,v 1.3 2002-11-03 16:43:16 azummo Exp $

# XXX - Write POD

use strict;
package Palm::PQA;
use Palm::Raw();

use vars qw( $VERSION @ISA
	%content_type2name %name2content_type
	%comp_type2name %name2comp_type
	$_in_tag
	);

# One liner, to allow MakeMaker to work.
$VERSION = do { my @r = (q$Revision: 1.3 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };

@ISA = qw( Palm::Raw );

sub import
{
	&Palm::PDB::RegisterPDBHandlers(__PACKAGE__,
		[ "clpr", "pqa " ],
		);
}

# Content type constants
use constant CONTENT_TEXT_PLAIN		=> 0;
use constant CONTENT_TEXT_HTML		=> 1;
use constant CONTENT_IMAGE_GIF		=> 2;
use constant CONTENT_IMAGE_JPEG		=> 3;
use constant CONTENT_APP_CML		=> 4;
use constant CONTENT_IMAGE_PALM		=> 5;

# This maps the content type name to its numerical value
%name2content_type = (
	"text/plain"			=> CONTENT_TEXT_PLAIN,
	"text/html"			=> CONTENT_TEXT_HTML,
	"image/gif"			=> CONTENT_IMAGE_GIF,
	"image/jpeg"			=> CONTENT_IMAGE_JPEG,
	"application/cml"		=> CONTENT_APP_CML,
	"image/palmos"			=> CONTENT_IMAGE_PALM,
);

# Build the inverse of the previous array
%content_type2name = reverse %name2content_type;

# Compression type constants
use constant COMPRESSION_NONE		=> 0;
use constant COMPRESSION_BITPACKED	=> 1;
use constant COMPRESSION_LZW		=> 2;

%Palm::PQA::comp_type2name = (
	COMPRESSION_NONE		=> "none",
	COMPRESSION_BITPACKED		=> "bit-packed",
	COMPRESSION_LZW			=> "lzw",
);
%Palm::PQA::name2comp_type = reverse %comp_type2name;

# Are we inside a tag?
# Private variable. Don't mess with this.
$_in_tag = 0;

# CML tag constants
use constant TAG_Anchor			=> 0x00;
use constant TAG_BGColor		=> 0x01;
use constant TAG_TextColor		=> 0x02;
use constant TAG_LinkColor		=> 0x03;
use constant TAG_TextSize		=> 0x04;
use constant TAG_TextBold		=> 0x05;
use constant TAG_TextItalic		=> 0x06;
use constant TAG_TextUnderline		=> 0x07;
use constant TAG_ParagraphAlign		=> 0x08;
use constant TAG_HorizontalRule		=> 0x09;
use constant TAG_H1			=> 0x0a;
use constant TAG_H2			=> 0x0b;
use constant TAG_H3			=> 0x0c;
use constant TAG_H4			=> 0x0d;
use constant TAG_H5			=> 0x0e;
use constant TAG_H6			=> 0x0f;
use constant TAG_BlockQuote		=> 0x10;
use constant TAG_Hyperlink		=> 0x11;
use constant TAG_Address		=> 0x12;
use constant TAG_TextStrike		=> 0x13;
use constant TAG_TextMono		=> 0x14;
use constant TAG_TextSub		=> 0x15;
use constant TAG_TextSup		=> 0x16;
use constant TAG_Clear			=> 0x17;
use constant TAG_HistoryListText	=> 0x18;
use constant TAG_IsIndex		=> 0x19;
use constant TAG_ListOrdered		=> 0x1a;
use constant TAG_ListUnordered		=> 0x1b;
use constant TAG_ListDefinition		=> 0x1c;
use constant TAG_ListItemCustom		=> 0x1d;
use constant TAG_ListItemNormal		=> 0x1e;
use constant TAG_ListItemTerm		=> 0x1f;
use constant TAG_ListItemDefinition	=> 0x20;
use constant TAG_Form			=> 0x21;
use constant TAG_InputTextLine		=> 0x22;
use constant TAG_InputPassword		=> 0x23;
use constant TAG_InputRadio		=> 0x24;
use constant TAG_InputCheckBox		=> 0x25;
use constant TAG_InputSubmit		=> 0x26;
use constant TAG_InputReset		=> 0x27;
use constant TAG_InputHidden		=> 0x28;
use constant TAG_InputTextArea		=> 0x29;
use constant TAG_Select			=> 0x2a;
use constant TAG_SelectItemNormal	=> 0x2b;
use constant TAG_SelectItemCustom	=> 0x2c;
use constant TAG_InputDatePicker	=> 0x2d;
use constant TAG_InputTimePicker	=> 0x2e;
use constant TAG_Table			=> 0x2f;
use constant TAG_TableRow		=> 0x30;
use constant TAG_Caption		=> 0x31;
use constant TAG_TableData		=> 0x32;
use constant TAG_TableHeader		=> 0x33;
use constant TAG_Image			=> 0x34;

# Special CML Tags.
use constant TAG_8BitEncoding		=> 0x70;
use constant TAG_CMLEnd			=> 0x71;

# Tags not passed to output
use constant TAG_TextFont		=> 0x100;
use constant TAG_Body			=> 0x101;
use constant TAG_Base			=> 0x102;
use constant TAG_TextBaseFont		=> 0x103;
use constant TAG_ListItem		=> 0x104;
use constant TAG_Input			=> 0x105;
use constant TAG_SelectItem		=> 0x106;
use constant TAG_Meta			=> 0x107;

# sub new
# sub new_Record

sub ParseAppInfoBlock
{
	my $self = shift;
	my $data = shift;

	my $appinfo = {};

	my $unpackstr =		# Argument to unpack()
		"a4" .		# Signature
		"n" .		# Version of PQA header
		"n";		# Version of HTML encoding

	my $signature;		# Signature. Must be 'lnch'
	my $header_version;	# Version of this PQA header. Must be 3.
	my $encoding_version;	# Version of HTML encoding

	# Get the signature, PQA header version, and HTML encoding string
	($signature, $header_version, $encoding_version) =
		unpack $unpackstr, $data;

	$appinfo->{signature} = $signature;
	$appinfo->{header_version} = $header_version;
	$appinfo->{encoding_version} = $encoding_version;

	$data = substr $data, 8;

	# Get the printable version string
	my $ver_str_len;		# Length of version string
	my $version;			# Version string

	$ver_str_len = unpack "n", $data;
	$ver_str_len *= 2;		# Length is given in words, not bytes
	$version = substr $data, 2, $ver_str_len;
	$data = substr $data, 2+$ver_str_len;
	$version =~ s/\0*$//;		# Trim trailing NULs
	$appinfo->{version} = $version;

	# Get the Launcher-visible title
	my $title_len;			# Length of title string
	my $title;			# Launcher-visible document title

	$title_len = unpack "n", $data;
	$title_len *= 2;		# Length is given in words, not bytes
	$title = substr $data, 2, $title_len;
	$data = substr $data, 2+$title_len;
	$title =~ s/\0*$//;		# Trim trailing NULs
	$appinfo->{title} = $title;

	# Get the PQA's icon
	my $icon_len;			# Length of icon data
	my $icon;			# Icon data

	$icon_len = unpack "n", $data;
	$icon_len *= 2;			# Length is given in words, not bytes
	$icon = substr $data, 2, $icon_len;
	$data = substr $data, 2+$icon_len;
	$appinfo->{icon} = $icon;	# XXX - Parse this further

	# Get the PQA's small icon
	my $sm_icon_len;		# Length of small icon data
	my $sm_icon;			# Small icon data

	$sm_icon_len = unpack "n", $data;
	$sm_icon_len *= 2;		# Length is given in words, not bytes
	$sm_icon = substr $data, 2, $sm_icon_len;
	$data = substr $data, 2+$sm_icon_len;
	$appinfo->{small_icon} = $sm_icon;	# XXX - Parse this further

	return $appinfo;
}

# sub PackAppInfoBlock


sub ParseRecord
{
	my $self = shift;
	my %record = @_;
	my $data;

	delete $record{offset};		# This is useless

	$data = $record{data};
	delete $record{data};

	my $url_offset;
	my $url_len;
	my $data_offset;
	my $data_len;
	my $content_type;
	my $compression_type;
	my $uncomp_data_len;
	my $flags;
	my $url;
	my $doc_data;

	my $unpackstr =
		"N" .		# URL offset
		"n" .		# URL length
		"N" .		# Data offset
		"n" .		# Data length
		"C" .		# Content type
		"C" .		# Compression type
		"N" .		# Uncompressed data length
		"C" .		# Flags
		"x";		# Reserved

	($url_offset, $url_len, $data_offset, $data_len, $content_type,
	 $compression_type, $uncomp_data_len, $flags) =
		unpack $unpackstr, $data;

	$record{url_offset} = $url_offset;	# XXX - Useless
	$record{url_len} = $url_len;
	$record{data_offset} = $data_offset;	# XXX - Useless
	$record{data_len} = $data_len;
	$record{content_type} = $content_type2name{$content_type};
	$record{compression_type} = $comp_type2name{$compression_type};
#  					# This should be interpreted as
#  					# "the compression scheme in use
#  					# when I read this record". The
#  					# caller should never have to worry
#  					# about this; &PackRecord should
#  					# honor this, though.
	$record{uncomp_data_len} = $uncomp_data_len;	# XXX - Useless
	$record{flags} = {};		# No flags yet.

	$url = substr $data, $url_offset, $url_len;
	$record{url} = $url;
	$doc_data = substr $data, $data_offset, $data_len;

	# Uncompress the data
	if ($compression_type == COMPRESSION_NONE)
	{
		# Uncompressed data
		$record{data} = $doc_data;
	} elsif ($compression_type == COMPRESSION_BITPACKED)
	{
		# XXX - Bit-packed compression
		$record{data} = &uncompress_bitpacked($doc_data);
	} elsif ($compression_type == COMPRESSION_LZW)
	{
		# XXX - LZW compression
		# $record{data} = &uncompress_lzw($doc_data);
	} else {
		# XXX - Unknown compression type
	}

	# XXX - Presumably, at this point we're left with
	# "uncompressed" PQA data. This can be further parsed into
	# title, links, etc.

	$data = substr $data, 20;

	return \%record;
}

# sub PackRecord

sub uncompress_bitpacked
{
	my $raw = shift;
	my $bits;		# $raw, turned into a string of 0s and 1s.
	my $chr;		# Current character
	my $retval = "";
	my $tag;

	$bits = unpack "B*", $raw;

	while ($bits ne "")
	{
print STDERR "bits: [", substr($bits, 0, 5), "] -> ";
		$chr = ord(pack("B5", substr($bits, 0, 5))) >> 3;
print STDERR "$chr]\n";
		$bits = substr $bits, 5;

		if ($chr eq 0)
		{
			# XXX - EndTag
			if ($_in_tag)
			{
print STDERR "EndTag\n";
				$retval .= "[EndTag]";
				$_in_tag = 0;
			} else {
print STDERR "NUL\n";
				$retval .= "\0";
			}
		} elsif ($chr eq 1)
		{
			# XXX - StartTag
			$_in_tag = 1;
			$tag = ord(pack("B8", substr($bits, 0, 8)));
#			$retval .= "[Tag: $tag]";
			$bits = substr $bits, 8;
print STDERR "StartTag [$tag]\n";

$retval .=
			&parse_tag($tag, \$bits);

			last if $tag == 113;	# CMLEnd
		} elsif ($chr eq 2)
		{
			# Single-character escape
print STDERR "SC: [", pack("B8", substr($bits, 0, 8)), "]\n";
			$retval .= pack("B8", substr($bits, 0, 8));
			$bits = substr $bits, 8;
		} elsif ($chr eq 3)
		{
			# ASCII Formfeed (0x0c)
print STDERR "FF\n";
			$retval .= chr(0x0c);
		} elsif ($chr eq 4)
		{
			# ASCII Carriage return (0x0d)
print STDERR "CR\n";
			$retval .= chr(0x0d);
		} elsif ($chr eq 5)
		{
			# ASCII space (0x20)
print STDERR "SP\n";
			$retval .= " ";
		} else {
			# ASCII lowercase letter
print STDERR "Char: [", chr(0x61 - 6 + $chr) . "]\n";
			$retval .= chr(0x61 - 6 + $chr);
		}
	}

	return $retval;
}

sub parse_tag
{
	my $tag = shift;
	my $bitsp = shift;		# Reference to string

	if ($tag == TAG_ParagraphAlign)
	{
		my $align = ord(pack("B2", substr($$bitsp, 0, 2))) >> 6;

		$$bitsp = substr $$bitsp, 2;
		$_in_tag = 0;
		return "Paragraph align: [$align]\n";
	} elsif ($tag == TAG_Table)
	{
		my $flag_hasalign;
		my $flag_haswidth;
		my $flag_hasborder;
		my $flag_hascellspacing;
		my $flag_hascellpadding;
		my $align;
		my $width;
		my $border;
		my $cellspacing;
		my $cellpadding;

print STDERR "Table.\n";
print STDERR "Table flags: [", substr($$bitsp, 0, 7), "]\n";
		($flag_hascellpadding, $flag_hascellspacing, $flag_hasborder,
		$flag_haswidth, $flag_hasalign) =
			$$bitsp =~ /^..(\d)(\d)(\d)(\d)(\d)/;
				# Plus two unused, reserved bits
		$$bitsp = substr $$bitsp, 7;

print STDERR "  Has align:        $flag_hasalign\n";
print STDERR "  Has width:        $flag_haswidth\n";
print STDERR "  Has border:       $flag_hasborder\n";
print STDERR "  Has cell spacing: $flag_hascellspacing\n";
print STDERR "  Has cell padding: $flag_hascellpadding\n";

		if ($flag_hasalign)
		{
			$align = ord(pack("B2", substr($$bitsp, 0, 2))) >> 6;
			$$bitsp = substr $$bitsp, 2;
print STDERR "  Align: [$align]\n";
		}

		if ($flag_haswidth)
		{
			$width = ord(pack("B16", substr($$bitsp, 0, 16)));
			$$bitsp = substr $$bitsp, 16;
print STDERR "  Width: [$width]\n";
		}

		if ($flag_hasborder)
		{
			$border = ord(pack("B8", substr($$bitsp, 0, 8)));
			$$bitsp = substr $$bitsp, 8;
print STDERR "  Border: [$border]\n";
		}

		if ($flag_hascellspacing)
		{
			$cellspacing = ord(pack("B8", substr($$bitsp, 0, 8)));
			$$bitsp = substr $$bitsp, 8;
print STDERR "  Cell spacing: [$cellspacing]\n";
		}

		if ($flag_hascellpadding)
		{
			$cellpadding = ord(pack("B8", substr($$bitsp, 0, 8)));
			$$bitsp = substr $$bitsp, 8;
print STDERR "  Cell padding: [$cellpadding]\n";
		}

#  		return "Table" .
#  			($flag_hasalign ? " ALIGN" : "") .
#  			($flag_haswidth ? " WIDTH" : "") .
#  			($flag_hasborder ? " BORDER" : "") .
#  			($flag_hascellspacing ? " CELLSPACING" : "") .
#  			($flag_cellpadding ? " CELLPADDING" : "");

return "[Table]";
	}
}

1;

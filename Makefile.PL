use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'Palm',
    'VERSION'		=> '1.004_000',
    'DISTNAME'		=> 'p5-Palm',	# More descriptive than just "Palm"
    'INSTALLDIRS'	=> 'site',
	 'AUTHOR' => 'Andrew Arensburger <arensb@ooblick.com>',
	 'ABSTACT' => 'Module for handling PalmOS databases',
    'EXE_FILES'		=> [ 'util/pdbdump' ],
);

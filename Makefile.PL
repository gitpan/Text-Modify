use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'Text::Modify',
    'VERSION_FROM' => 'lib/Text/Modify.pm', # finds $VERSION
    'PREREQ_PM'  => { },
    'dist' => {COMPRESS=>'gzip', SUFFIX=>'gz'}
);

use 5.006001;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'WWW::Statistics',
    VERSION_FROM      => 'lib/WWW/Statistics.pm', # finds $VERSION
    PREREQ_PM         => {GD => 2.12, DB::DBinterface => 0.95}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/WWW/Statistics.pm', # retrieve abstract from module
       AUTHOR         => 'DUPUIS Arnaud <a.dupuis@infinityperl.org>') : ()),
);

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl WWW-Statistics.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test;
BEGIN { plan tests => 11 };
use WWW::Statistics;
ok(1); # If we made it this far, we're ok.
sub prin
{
	my $text = shift;
	print STDERR $text;
}

sub Read
{
        my ($nom_fichier)=@_;
	unless ( -e $nom_fichier or -R $nom_fichier)
	{
		warn "unable to read $nom_fichier : $!\n";
		return undef ;
	}
        my $tmp="";
        my $p=0;
	my @file=();
        open (F2,"<$nom_fichier");
        while (defined($tmp=<F2>))
        {
                #chomp $tmp;
		unless($tmp=~ /^$/)
		{
                	$file[$p]=$tmp;
		}
		else
		{
			$file[$p]="\n";
		}
                $p++;
        }
        close (F2);
        return (@file);
}

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my ($dbhost,$dbuser,$dbpwd,$db,$dbi) = Read('param_temp.db');
chomp $dbhost;
chomp $dbuser;
chomp $dbpwd;
chomp $db;
chomp $dbi;
my $wso = WWW::Statistics->new(
	DB_USER => $dbuser ,
	DB_PASSWORD => $dbpwd,
        DB_HOST => $dbhost,
        DB_DATABASE => $db,
	DB_TYPE => $dbi
);
ok(defined $wso);
ok($wso->setMSTN('test_module'));
ok($wso->setBACKUP_TABLE_NAME('backup_module'));
ok($wso->initDataBase(MAIN_STAT_TABLE_NAME => test_module,PAGES_LIST => 'first,seconde,third'));
#ok($wso->addMainPages(PAGES_LIST => 'test'));
#ok(my $id = $wso->getIDfromPage('test'));
ok($wso->initBackupDatabase) ;
#ok($wso->dropMainPages(ID_LIST=>$id));
ok($wso->DBupdate("UPDATE test_module SET nb_seen=20"));
#ok($wso->updateBackupDBschema);
ok($wso->backupStats(BACKUP_DESCRIPTION => 'Test for WWW::Statistics ver.0.91'));
ok($wso->generateGDGraph(GRAPH_WIDTH => 800,WITH_HTML => 1));
#ok($wso->reIndexBackupTable);
ok($wso->DBupdate("DROP TABLE test_module"));
ok($wso->DBupdate("DROP TABLE backup_module"));
unlink 'param_temp.db';
package WWW::Statistics;

use 5.006001;
use strict;
use warnings;
use DB::DBinterface;
use GD ;

require Exporter;

our @ISA = qw(Exporter DB::DBinterface);

our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION = '0.91';

###------------>> Private methods :
my $ls = sub{

	my ($dir)=@_;
	if (! -e $dir )
	{
		print "[ WWW::Statistics ] Unknow directory ($dir).";
		return undef;
 	}
	if (! -d $dir )
	{
	 	print "[ WWW::Statistics ] $dir is not a directory.";
	 	return undef;
	}
	if (! opendir( DIR, $dir) )
	{
	 	print "[ WWW::Statistics ] Cannot open directory $dir : $!.";
	 	return undef;
	}
	my @files = grep !/(?:^\.$)|(?:^\.\$)/, readdir DIR;
	closedir DIR;

	return @files;
} ;

my $dropDirectories = sub {
	my ($dir,@img) = @_ ;
	my @ret_img = ();
	foreach my $a (@img)
	{
		unless( -d "$dir/$a")
		{
			if( -e "$dir/$a" )
			{
				push @ret_img, $a;
			}
		}
	}
	return @ret_img;
} ;

my $isImageFile = sub {
	my (@img) = @_ ;
	my @ret_img = ();
	foreach my $a (@img)
	{
		if($a =~ /^.*\.(bmp|xpm|xbm|ppm|pgm|pxr|pcx|jpeg|jpg|jpe|gif|ico|tiff|tif|png|psp|psd|xsd|raw)$/i)
		{
			push @ret_img, $a;
		}
	}
	return @ret_img;
};
## Private routine wich create the base of a Graph image. Arguments are a valid GD object, the step between graduation, 
my $createGBbaseImage = sub {
	my ($ref_obj,$ref_tab,$max,$larg,$haut,$color,$ref_x_c,$ref_y_c) = @_ ;
	$larg--;
	$haut--;
	my @date = @$ref_tab;
	my $step = int(($haut/$max)*5) ;
	#print "largeur : $larg\nhauteur : $haut\nstep : $step\n";
	my $t_larg = $larg-20;
	my $t_haut = $haut-20;
	my $border = $ref_obj->colorAllocate(0,0,0);
	my $rep = $ref_obj->colorAllocate(169,169,169);
	my $ind = 5;
	my $ind_step = int($max/($t_haut/$step)) ;
	#print "[+] max : $max\n[+] ind_step : $ind_step\n";
	for(my $k=$t_haut; $k>0; $k-=$step)
	{
		#print "\$ind : $ind\n";
		$ref_obj->string(gdTinyFont,2,$k,"$ind",$border) ;
		$ref_obj->dashedLine(20,$k,$larg,$k,$color);
		$ref_y_c->{$ind}= $k;
		$ind += $ind_step;
	}
	my $ti = 0;
	for(my $ki=20; $ki<=$t_larg; $ki+=$step)
	{
		if(defined($date[$ti]))
		{
			$ref_obj->string(gdTinyFont,$ki,$t_haut+2,"$date[$ti]->{id_backup}",$border);
			$ref_x_c->{"$date[$ti]->{id_backup}"} = $ki;
			$ti++;
		}
		$ref_obj->dashedLine($ki,0,$ki,$t_haut,$color);
	}
	$ref_obj->line(20,$t_haut,$larg,$t_haut,$rep);
	$ref_obj->line(20,0,20,$t_haut,$rep);
	$ref_obj->line(0,0,$larg,0,$border);
	$ref_obj->line(0,0,0,$haut,$border);
	$ref_obj->line($larg,0,$larg,$haut,$border);
	$ref_obj->line(0,$haut,$larg,$haut,$border);
};

## Private routine wich write a GD image in a png file. Arguments are a valid reference to a GD object and a filename WITH ABSOLUTE PATH.
my $saveImage = sub{
	my ($gdo, $img_file) = @_ ;
	open ( FICHIER_PNG , ">$img_file" ) or return undef;
	binmode FICHIER_PNG or return undef;
	print FICHIER_PNG $gdo->png;
	close ( FICHIER_PNG ) or return undef;
	return 1;
};

###------------>> Public methods :

sub new
{
	shift ;
	my @arg= @_ ;
        my $self;
	$self->{'DB_HOST'} = '127.0.0.1';
	$self->{'DB_USER'} = undef;
	$self->{'DB_PASSWORD'} = undef;
	$self->{'DB_TYPE'} = 'mysql';
	$self->{'DB_DATABASE'} = undef;
	$self->{'IMAGES_DIR'} = '/usr/local/share/iperl/';
	for (my $k=0;$k<=$#arg;$k=$k+2)
	{
		#print "\$arg[$k] : $arg[$k]\n\$arg[$k+1] : $arg[$k+1]\n";
		$self->{"$arg[$k]"} = $arg[$k+1];
	}
	unless(defined($self->{'DB_HOST'}) && defined($self->{'DB_USER'}) && defined($self->{'DB_PASSWORD'}) && defined($self->{'DB_DATABASE'}))
	{
		warn "[ WWW::Statistics::new ] one of the followings arguments is undef : DB_HOST, DB_USER, DB_PASSWORD, DB_DATABASE.\n";
		return undef;
	}
	my $self2= DB::DBinterface->new_h(
		DBHOST => $self->{'DB_HOST'},
		DBUSER=> $self->{'DB_USER'},
		DBPASSWORD => $self->{'DB_PASSWORD'},
		DATABASE => $self->{'DB_DATABASE'},
		DBTYPE => $self->{'DB_TYPE'}
	);
	$self = $self2;
	bless $self;
	return $self;
}
sub initDataBase
{
	my $self = shift ;
	my @args = @_ ;
	for (my $k=0;$k<=$#args;$k=$k+2)
	{
		$self->{"$args[$k]"} = $args[$k+1];
	}
	unless(exists($self->{'PAGES_LIST'}) && defined($self->{'PAGES_LIST'}))
	{
		warn "[ WWW::Statistics::initDatabase ] you might specify a table list with <OBJECT>->initDataBase(\n\tPAGES_LIST => 'page1,page2,...,pageN'\n);\n";
		return undef;
	}
	unless(exists($self->{'MAIN_STAT_TABLE_NAME'}) && defined($self->{'MAIN_STAT_TABLE_NAME'}))
	{
		warn "[ WWW::Statistics::initDatabase ] you might specify a main statistics table name with <OBJECT>->initDataBase(\n\tMAIN_STAT_TABLE_NAME => 'table_name'\n);\n";
		return undef;
	}
	$self->setMSTN($self->{'MAIN_STAT_TABLE_NAME'});
	$self->DBupdate("CREATE TABLE $self->{'MAIN_STAT_TABLE_NAME'} (id_pages tinyint primary key not null,name_pages varchar(250),nb_seen int)") or return undef;
	my @Tlist = split(/,/,$self->{'PAGES_LIST'});
	foreach my $a (@Tlist)
	{
		my $idmax = 0 ;
		my ($temp)=$self->DBselect("select max(id_pages) as idmax from $self->{'MAIN_STAT_TABLE_NAME'}");
		$idmax = $temp->{'idmax'};
		$idmax++;
		$self->DBupdate("INSERT INTO $self->{'MAIN_STAT_TABLE_NAME'} VALUES($idmax,'$a',0)") or return undef;
	}
	$self->{'PAGES_LIST'} = '';
	return 1;
}

sub generateGDGraph
{
	my $self = shift;
	my @args = @_ ;
	my $width = 400;
	my $height = 200 ;
	my $g_dir = './';
	my %x_cores = () ;
	my %y_cores = () ;
	for (my $k=0;$k<=$#args;$k=$k+2)
	{
		$self->{"$args[$k]"} = $args[$k+1];
	}
	unless(exists($self->{'BACKUP_TABLE_NAME'}) && defined($self->{'BACKUP_TABLE_NAME'}))
	{
		warn "[ WWW::Statistics::generateGDGraph ] you might specify a main statistics table name with <OBJECT>->generateGDGraph(\n\tBACKUP_TABLE_NAME => 'table_name'\n);\nor by :\n<OBJECT>->setBACKUP_TABLE_NAME('table_name')\n";
		return undef;
	}
	if(exists($self->{'GRAPH_WIDTH'}) && defined($self->{'GRAPH_WIDTH'}))
	{
		$width = $self->{'GRAPH_WIDTH'};
	}
	if(exists($self->{'GRAPH_HEIGHT'}) && defined($self->{'GRAPH_HEIGHT'}))
	{
		$height = $self->{'GRAPH_HEIGHT'};
	}
	if(exists($self->{'GRAPH_DIR'}) && defined($self->{'GRAPH_DIR'}))
	{
		$g_dir = $self->{'GRAPH_DIR'};
	}
	$height+= 20;
	$width+=20;
	my $gdo = new GD::Image( $width , $height) ;
	my $background = $gdo->colorAllocate(0,0,0);
	$gdo->transparent($background);
	my $max = $self->getMaxFromBackup;
	my $clm = $gdo->colorAllocate(255,228,196);
	my @db_b = $self->DBselect("SELECT * FROM $self->{'BACKUP_TABLE_NAME'}") or return undef;
	$createGBbaseImage->($gdo,\@db_b,$max,$width,$height,$clm,\%x_cores,\%y_cores);
	my %schema = $self->getHashShemaFromTable($self->{'BACKUP_TABLE_NAME'}) or return undef;
	my @field = split(/,/,$schema{Field});
	my %value = ();
	$height-- ;
	my $pas = $height/$max ;
	my $blue = $gdo->colorAllocate(0,0,255);
	my $red = $gdo->colorAllocate(255,0,0);
	my $green = $gdo->colorAllocate(0,255,0);
	print "PAS : $pas\nbleu : $blue\nrouge : $red\nvert : $green\n";
	my @colors = ($blue,$green,$red);
	my $colo_ind = 0;
	foreach my $a (@field)
	{
		#print "-> \$a = $a\n";
		my @coord = ();
		foreach my $z (@db_b)
		{
			if($a !~ /(id_backup|desc_backup|date_backup)/)
			{
				my $x = $x_cores{$z->{id_backup}} ;
				my $y = $height-($z->{$a} * $pas);
				print "$height-($z->{$a} * $pas) = $y\n";
				@coord = (@coord,$x,$y);
			}
			if ($#coord == 3)
			{
				#print "coordonnées de la ligne : (",join ',',@coord,") EN $colors[$colo_ind]\n";
				$gdo->line(@coord,$colors[$colo_ind]);
				@coord = ($coord[2],$coord[3]);
			}
		}
		$colo_ind++;
		$colo_ind=0 if($colo_ind>2);
	}
	my @time = localtime(time);
	$time[2]--;
	$time[4]++;
	$time[4]="0$time[4]";
	$time[5] += 1900 ;
	my $png = $g_dir.'/'.$time[3].$time[4].$time[5].$time[2].$time[1].$time[0].'.png';
	$saveImage->($gdo,$png);
# 	my $im = $gdo->copyReverseTranspose();
# 	$png = 'test.png' ;
# 	$saveImage->($im,"$png");
	if(exists($self->{'WITH_HTML'}) && defined($self->{'WITH_HTML'}))
	{
		my $HTML = <<EOF;
		<TABLE>
			<TR>
				<TD>
					<IMG SRC='$png'>
				</TD>
			</TR>
		</TABLE>
EOF
		return $HTML;
	}
	return $png;
}
sub reIndexBackupTable
{
	my $self = shift;
	my @args = @_ ;
	for (my $k=0;$k<=$#args;$k=$k+2)
	{
		$self->{"$args[$k]"} = $args[$k+1];
	}
	unless(exists($self->{'BACKUP_TABLE_NAME'}) && defined($self->{'BACKUP_TABLE_NAME'}))
	{
		warn "[ WWW::Statistics::reIndexBackupTable ] you might specify a main statistics table name with <OBJECT>->reIndexBackupTable(\n\tBACKUP_TABLE_NAME => 'table_name'\n);\nor by :\n<OBJECT>->setBACKUP_TABLE_NAME('table_name')\n";
		return undef;
	}
	my ($ref_max) = $self->DBselect("select max(id_backup) as max from $self->{'BACKUP_TABLE_NAME'}") or return undef;
	my $max = $ref_max->{max} + 1 ;
	$self->DBupdate("UPDATE $self->{'BACKUP_TABLE_NAME'} SET id_backup=id_backup+$max") or return undef;
	my @select = $self->DBselect("SELECT * FROM $self->{'BACKUP_TABLE_NAME'}") or return undef;
	my %tmp = ();
	foreach my $a (@select)
	{
		$tmp{"$a->{date_backup}"} = $a->{id_backup};
	}
	my @croiss = sort { $a <=> $b } keys %tmp;
	my $ind = 1;
	## TODO : intégrer une possibilitée e backup de la table (possile de la conservé) avec éventuellement la création d'une table permettant la correspondance entre les nom aléatoirement généré et le moment du backup.
	foreach my $z (@croiss)
	{
		print "$z : old => $tmp{$z}, new => $ind\n";
		$self->DBupdate("UPDATE $self->{'BACKUP_TABLE_NAME'} SET id_backup=$ind WHERE id_backup=$tmp{$z}") or return undef;
		$ind++;
	}

}
sub getMaxFromBackup
{
	my $self = shift;
	my @args = @_ ;
	my $max = 0;
	for (my $k=0;$k<=$#args;$k=$k+2)
	{
		$self->{"$args[$k]"} = $args[$k+1];
	}
	unless(exists($self->{'BACKUP_TABLE_NAME'}) && defined($self->{'BACKUP_TABLE_NAME'}))
	{
		warn "[ WWW::Statistics::getMaxFromBackup ] you might specify a main statistics table name with <OBJECT>->getMaxFromBackup(\n\tBACKUP_TABLE_NAME => 'table_name'\n);\nor by :\n<OBJECT>->setBACKUP_TABLE_NAME('table_name')\n";
		return undef;
	}
	my %schem = $self->getHashShemaFromTable($self->{'BACKUP_TABLE_NAME'}) or return undef;
	my @fields = split(/,/,$schem{Field});
	foreach my $a (@fields)
	{
		if($a !~ /(id_backup|desc_backup|date_backup)/)
		{
			my ($ref_max) = $self->DBselect("select max($a) as max from $self->{'BACKUP_TABLE_NAME'}") or return undef;
			$max = $ref_max->{max} if($ref_max->{max} > $max) ;
		}
	}
	return $max;
}
sub generateHTMLMainGraph
{
	my $self = shift;
	my @args = @_ ;
	my $images_dir = $ENV{PWD}.'/' ;
	my @images_list = ();
	my $c_idx = 0;
	my $td_font = '<FONT>';
	my $nb_pixels = 4;
	my $height = 9;
	my $img_align = 'CENTER' ;
	my $img_cycling = undef;
	my $ret_HTML = '';
	my $table = '<TABLE WIDTH="100%" BORDER=0 CELLPADDING=0 CELLSPACING=0 ALIGN="CENTER">';
	my $tr = '<TR>';
	my $td = '<TD>' ;
	my $th = undef;
	my $img = '<IMG SRC=__IMGSRC__ ALIGN=__IMGALIGN__ WIDTH=__IMGWIDTH__ HEIGHT=__IMGHEIGHT__>';
	for (my $k=0;$k<=$#args;$k=$k+2)
	{
		$self->{"$args[$k]"} = $args[$k+1];
	}
	if(exists($self->{'IMAGES_DIR'}) && defined($self->{'IMAGES_DIR'}))
	{
		$images_dir = $self->{'IMAGES_DIR'}.'/';
		unless( -e $images_dir )
		{
			warn "[ WWW::Statistics::generateHTMLMainGraph ] $images_dir : no such directory.\n";
			return undef;
		}
	}
	if(exists($self->{'IMAGES_CYCLING'}) && defined($self->{'IMAGES_CYCLING'}))
	{
		$img_cycling = $self->{'IMAGES_CYCLING'};
	}
	if(exists($self->{'PIXELS_FOR_POINT'}) && defined($self->{'PIXELS_FOR_POINT'}))
	{
		$nb_pixels = $self->{'PIXELS_FOR_POINT'};
	}
	if(exists($self->{'TABLE_TAG'}) && defined($self->{'TABLE_TAG'}))
	{
		$table = $self->{'TABLE_TAG'};
	}
	if(exists($self->{'TR_TAG'}) && defined($self->{'TR_TAG'}))
	{
		$tr = $self->{'TR_TAG'};
	}
	if(exists($self->{'TD_TAG'}) && defined($self->{'TD_TAG'}))
	{
		$td = $self->{'TD_TAG'};
	}
	if(exists($self->{'TABLE_NAME_FONT'}) && defined($self->{'TABLE_NAME_FONT'}))
	{
		$td_font = $self->{'TABLE_NAME_FONT'};
	}
	if(exists($self->{'TH_TAG'}) && defined($self->{'TH_TAG'}))
	{
		$th = $self->{'TH_TAG'};
	}
	if(exists($self->{'IMG_TAG'}) && defined($self->{'IMG_TAG'}))
	{
		$img = $self->{'IMG_TAG'};
	}
	if(exists($self->{'IMG_ALIGN_TAG'}) && defined($self->{'IMG_ALIGN_TAG'}))
	{
		$img_align = $self->{'IMG_ALIGN_TAG'};
	}
	if(exists($self->{'IMG_HEIGHT_TAG'}) && defined($self->{'IMG_HEIGHT_TAG'}))
	{
		$height = $self->{'IMG_HEIGHT_TAG'};
	}
	if(exists($self->{'IMAGES_LIST'}) && defined($self->{'IMAGES_LIST'}))
	{
		@images_list = split(/,/,$self->{'IMAGES_LIST'});
	}
	else
	{
		@images_list = $ls->($images_dir);
	}
	@images_list = $dropDirectories->($images_dir,@images_list);
	@images_list = $isImageFile->($images_dir,@images_list);
	unless(exists($self->{'MAIN_STAT_TABLE_NAME'}) && defined($self->{'MAIN_STAT_TABLE_NAME'}))
	{
		warn "[ WWW::Statistics::generateHTMLMainGraph ] you might specify a main statistics table name with <OBJECT>->generateHTMLMainGraph(\n\tMAIN_STAT_TABLE_NAME => 'table_name'\n);\nor by :\n<OBJECT>->setMSTN('table_name')\n";
		return undef;
	}
	my @db = $self->DBselect("SELECT name_pages,nb_seen FROM $self->{'MAIN_STAT_TABLE_NAME'}") or return undef;
	$ret_HTML = "$table\n";
	foreach my $p (@db)
	{
		my $img_tag = $img;
		$ret_HTML .= "\t$tr\n"; # new table line
		$ret_HTML .= "\t\t$td\n\t\t\t"; #new col
		$ret_HTML .= "$td_font $p->{name_pages} </FONT>";;
		$ret_HTML .= "\n\t\t</TD>\n\t\t$td\n\t\t\t";
		if(defined($img_cycling))
		{
			$c_idx++;
			$img_tag=~ s/__IMGSRC__/'$images_dir$images_list[$c_idx]'/;
			if($c_idx > $#images_list)
			{
				$c_idx = 0;
			}
		}
		else
		{
			$img_tag=~ s/__IMGSRC__/'$images_dir$images_list[0]'/;
		}
		my $pixel = $nb_pixels * $p->{nb_seen};
		$img_tag=~ s/__IMGWIDTH__/$pixel/;
		$img_tag=~ s/__IMGHEIGHT__/$height/;
		$img_tag=~ s/__IMGALIGN__/'$img_align'/;
		$ret_HTML .= "$img_tag ($p->{nb_seen})";
		$ret_HTML .= "\n\t\t</TD>\n\t</TR>\n";
	}
	$ret_HTML .= '</TABLE>';
	return $ret_HTML;
}
sub generateHTMLBackupGraph
{
	my $self = shift;
	my @args = @_ ;
	my $images_dir = $ENV{PWD}.'/' ;
	my @images_list = ();
	my $backup_id = undef;
	my $c_idx = 0;
	my $nb_pixels = 4;
	my $td_font = '<FONT>';
	my $height = 9;
	my $img_align = 'CENTER' ;
	my $img_cycling = undef;
	my $ret_HTML = '';
	my $table = '<TABLE WIDTH="100%" BORDER=0 CELLPADDING=0 CELLSPACING=0 ALIGN="CENTER">';
	my $tr = '<TR>';
	my $td = '<TD>' ;
	my $th = undef;
	my $img = '<IMG SRC=__IMGSRC__ ALIGN=__IMGALIGN__ WIDTH=__IMGWIDTH__ HEIGHT=__IMGHEIGHT__>';
	for (my $k=0;$k<=$#args;$k=$k+2)
	{
		$self->{"$args[$k]"} = $args[$k+1];
	}
	unless(exists($self->{'BACKUP_ID'}) && defined($self->{'BACKUP_ID'}))
	{
		warn "[ WWW::Statistics::generateHTMLBackupGraph ] you might specify a backup statistics id with <OBJECT>->generateHTMLMainGraph(\n\tBACKUP_ID => 'backup_id'\n);\n";
		return undef;
	}
	else
	{
		$backup_id = $self->{'BACKUP_ID'};
	}
	unless(exists($self->{'BACKUP_TABLE_NAME'}) && defined($self->{'BACKUP_TABLE_NAME'}))
	{
		warn "[ WWW::Statistics::generateHTMLBackupGraph ] you might specify a main statistics table name with <OBJECT>->generateHTMLBackupGraph(\n\tBACKUP_TABLE_NAME => 'table_name'\n);\nor by :\n<OBJECT>->setBACKUP_TABLE_NAME('table_name')\n";
		return undef;
	}
	if(exists($self->{'IMAGES_DIR'}) && defined($self->{'IMAGES_DIR'}))
	{
		$images_dir = $self->{'IMAGES_DIR'}.'/';
		unless( -e $images_dir )
		{
			warn "[ WWW::Statistics::generateHTMLMainGraph ] $images_dir : no such directory.\n";
			return undef;
		}
	}
	if(exists($self->{'IMAGES_CYCLING'}) && defined($self->{'IMAGES_CYCLING'}))
	{
		$img_cycling = $self->{'IMAGES_CYCLING'};
	}
	if(exists($self->{'PIXELS_FOR_POINT'}) && defined($self->{'PIXELS_FOR_POINT'}))
	{
		$nb_pixels = $self->{'PIXELS_FOR_POINT'};
	}
	if(exists($self->{'TABLE_TAG'}) && defined($self->{'TABLE_TAG'}))
	{
		$table = $self->{'TABLE_TAG'};
	}
	if(exists($self->{'TR_TAG'}) && defined($self->{'TR_TAG'}))
	{
		$tr = $self->{'TR_TAG'};
	}
	if(exists($self->{'TD_TAG'}) && defined($self->{'TD_TAG'}))
	{
		$td = $self->{'TD_TAG'};
	}
	if(exists($self->{'TABLE_NAME_FONT'}) && defined($self->{'TABLE_NAME_FONT'}))
	{
		$td_font = $self->{'TABLE_NAME_FONT'};
	}
	if(exists($self->{'TH_TAG'}) && defined($self->{'TH_TAG'}))
	{
		$th = $self->{'TH_TAG'};
	}
	if(exists($self->{'IMG_TAG'}) && defined($self->{'IMG_TAG'}))
	{
		$img = $self->{'IMG_TAG'};
	}
	if(exists($self->{'IMG_HEIGHT_TAG'}) && defined($self->{'IMG_HEIGHT_TAG'}))
	{
		$height = $self->{'IMG_HEIGHT_TAG'};
	}
	if(exists($self->{'IMAGES_LIST'}) && defined($self->{'IMAGES_LIST'}))
	{
		@images_list = split(/,/,$self->{'IMAGES_LIST'});
	}
	else
	{
		@images_list = $ls->($images_dir);
	}
	@images_list = $dropDirectories->($images_dir,@images_list);
	@images_list = $isImageFile->($images_dir,@images_list);
	my ($db) = $self->DBselect("SELECT * FROM $self->{'BACKUP_TABLE_NAME'} WHERE id_backup=$backup_id") or return undef;
	my @main_db = $self->DBselect("SELECT id_pages,name_pages FROM $self->{'MAIN_STAT_TABLE_NAME'}");
	$ret_HTML = "$table\n";
	foreach my $p (@main_db)
	{
		my $img_tag = $img;
		my $hits = "t$p->{id_pages}";
		$ret_HTML .= "\t$tr\n"; # new table line
		$ret_HTML .= "\t\t$td\n\t\t\t"; #new col
		$ret_HTML .= "$td_font $p->{name_pages} </FONT>";
		$ret_HTML .= "\n\t\t</TD>\n\t\t$td\n\t\t\t";
		if(defined($img_cycling))
		{
			$c_idx++;
			$img_tag=~ s/__IMGSRC__/'$images_dir$images_list[$c_idx]'/;
			if($c_idx > $#images_list)
			{
				$c_idx = 0;
			}
		}
		else
		{
			$img_tag=~ s/__IMGSRC__/'$images_dir$images_list[0]'/;
		}
		my $pixel = $nb_pixels * $db->{$hits};
		$img_tag=~ s/__IMGWIDTH__/$pixel/;
		$img_tag=~ s/__IMGHEIGHT__/$height/;
		$img_tag=~ s/__IMGALIGN__/'$img_align'/;
		$ret_HTML .= "$img_tag ($db->{$hits})";
		$ret_HTML .= "\n\t\t</TD>\n\t</TR>\n";
	}
	$ret_HTML .= '</TABLE>';
	return $ret_HTML;
}
sub addMainPages
{
	my $self = shift;
	my @args = @_ ;
	for (my $k=0;$k<=$#args;$k=$k+2)
	{
		#print "\$arg[$k] : $arg[$k]\n\$arg[$k+1] : $arg[$k+1]\n";
		$self->{"$args[$k]"} = $args[$k+1];
	}
	unless(exists($self->{'PAGES_LIST'}) && defined($self->{'PAGES_LIST'}))
	{
		warn "[ WWW::Statistics::addMainPages ] you might specify a table list with <OBJECT>->addPages(\n\tPAGES_LIST => 'page1,page2,...,pageN'\n);\n";
		return undef;
	}
	unless(exists($self->{'MAIN_STAT_TABLE_NAME'}) && defined($self->{'MAIN_STAT_TABLE_NAME'}))
	{
		warn "[ WWW::Statistics::addPages ] you might specify a main statistics table name with <OBJECT>->addPages(\n\tMAIN_STAT_TABLE_NAME => 'table_name'\n);\nor by :\n<OBJECT>->setMSTN('table_name')\n";
		return undef;
	}
	my @Tlist = split(/,/,$self->{'PAGES_LIST'});
	foreach my $a (@Tlist)
	{
		my $idmax = 0 ;
		my ($temp)=$self->DBselect("select max(id_pages) as idmax from $self->{'MAIN_STAT_TABLE_NAME'}") or return undef;
		$idmax = $temp->{'idmax'};
		$idmax++;
		$self->DBupdate("INSERT INTO $self->{'MAIN_STAT_TABLE_NAME'} VALUES($idmax,'$a',0)") or return undef;
	}
	$self->{'PAGES_LIST'} = '';
	#TODO : mettre un parametre AUTO_UPDATE_BACKUP à 0 ou 1 pour prendre en charge la mise à jour automatique du schema de la base de donnée de backup
	return 1;
}
sub dropMainPages
{
	my $self = shift;
	my @args = @_ ;
	for (my $k=0;$k<=$#args;$k=$k+2)
	{
		#print "\$arg[$k] : $arg[$k]\n\$arg[$k+1] : $arg[$k+1]\n";
		$self->{"$args[$k]"} = $args[$k+1];
	}
	unless(exists($self->{'ID_LIST'}) && defined($self->{'ID_LIST'}))
	{
		warn "[ WWW::Statistics::addPages ] you might specify a table or ID list with <OBJECT>->addPages(\n\tID_LIST => '1,2,...,N'\n);\n";
		return undef;
	}
	unless(exists($self->{'MAIN_STAT_TABLE_NAME'}) && defined($self->{'MAIN_STAT_TABLE_NAME'}))
	{
		warn "[ WWW::Statistics::addPages ] you might specify a main statistics table name with <OBJECT>->addPages(\n\tMAIN_STAT_TABLE_NAME => 'table_name'\n);\nor by :\n<OBJECT>->setMSTN('table_name')\n";
		return undef;
	}
	my @Tlist = split(/,/,$self->{'ID_LIST'});
	foreach my $a (@Tlist)
	{
		$self->DBupdate("DELETE FROM $self->{'MAIN_STAT_TABLE_NAME'} WHERE id_pages=$a") or return undef;
	}
	$self->{'ID_LIST'} = '' ;
	## TODO : mettre un parametre AUTO_UPDATE_BACKUP à 0 ou 1 pour prendre en charge la mise à jour automatique du schema de la base de donnée de backup
	## TODO2 : corriger les IDs pour ne pas qu'il y ai de trous dans les IDs
	return 1;
}

sub incrMainPage
{
	my $self = shift;
	my @args = @_ ;
	for (my $k=0;$k<=$#args;$k=$k+2)
	{
		#print "\$arg[$k] : $arg[$k]\n\$arg[$k+1] : $arg[$k+1]\n";
		$self->{"$args[$k]"} = $args[$k+1];
	}
	unless(exists($self->{'ID_PAGE'}) && defined($self->{'ID_PAGE'}))
	{
		warn "[ WWW::Statistics::incrMainPage ] you might specify a column ID list with <OBJECT>->incrMainPage(\n\tID_PAGE => 1\n);\n";
		return undef;
	}
	unless(exists($self->{'MAIN_STAT_TABLE_NAME'}) && defined($self->{'MAIN_STAT_TABLE_NAME'}))
	{
		warn "[ WWW::Statistics::incrMainPage ] you might specify a main statistics table name with <OBJECT>->addPages(\n\tMAIN_STAT_TABLE_NAME => 'table_name'\n);\nor by :\n<OBJECT>->setMSTN('table_name')\n";
		return undef;
	}
	$self->DBupdate("UPDATE $self->{'MAIN_STAT_TABLE_NAME'} SET nb_pages=nb_pages+1 WHERE id_pages=$self->{'ID_PAGE'}")or return undef;
	$self->{'ID_PAGE'} = '' ;
	return 1;
}

sub decrMainPage
{
	my $self = shift;
	my @args = @_ ;
	for (my $k=0;$k<=$#args;$k=$k+2)
	{
		#print "\$arg[$k] : $arg[$k]\n\$arg[$k+1] : $arg[$k+1]\n";
		$self->{"$args[$k]"} = $args[$k+1];
	}
	unless(exists($self->{'ID_PAGE'}) && defined($self->{'ID_PAGE'}))
	{
		warn "[ WWW::Statistics::decrMainPage ] you might specify a column ID with <OBJECT>->decrMainPage(\n\tID_PAGE => 1\n);\n";
		return undef;
	}
	unless(exists($self->{'MAIN_STAT_TABLE_NAME'}) && defined($self->{'MAIN_STAT_TABLE_NAME'}))
	{
		warn "[ WWW::Statistics::decrMainPagee ] you might specify a main statistics table name with <OBJECT>->addPages(\n\tMAIN_STAT_TABLE_NAME => 'table_name'\n);\nor by :\n<OBJECT>->setMSTN('table_name')\n";
		return undef;
	}
	$self->DBupdate("UPDATE $self->{'MAIN_STAT_TABLE_NAME'} SET nb_pages=nb_pages-1 WHERE id_pages=$self->{'ID_PAGE'}")or return undef;
	$self->{'ID_PAGE'} = '' ;
	return 1;
}

sub initBackupDatabase
{
	my $self = shift;
	my @args = @_ ;
	for (my $k=0;$k<=$#args;$k=$k+2)
	{
		#print "\$arg[$k] : $arg[$k]\n\$arg[$k+1] : $arg[$k+1]\n";
		$self->{"$args[$k]"} = $args[$k+1];
	}
	#TODO : finir -> creation d'une table en regardant tout les tuple dans la table principale.
	unless(exists($self->{'BACKUP_TABLE_NAME'}) && defined($self->{'BACKUP_TABLE_NAME'}))
	{
		warn "[ WWW::Statistics::initBackupDatabase ] you might specify a main statistics table name with <OBJECT>->initBackupDatabase(\n\tBACKUP_TABLE_NAME => 'table_name'\n);\nor by :\n<OBJECT>->setBACKUP_TABLE_NAME('table_name')\n";
		return undef;
	}
	unless(exists($self->{'MAIN_STAT_TABLE_NAME'}) && defined($self->{'MAIN_STAT_TABLE_NAME'}))
	{
		warn "[ WWW::Statistics::initBackupDatabase ] you might specify a main statistics table name with <OBJECT>->initBackupDatabase(\n\tMAIN_STAT_TABLE_NAME => 'table_name'\n);\nor by :\n<OBJECT>->setMSTN('table_name')\n";
		return undef;
	}
	my @nb_ref = $self->DBselect("SELECT id_pages FROM $self->{'MAIN_STAT_TABLE_NAME'}") or return undef;
	my $col = "";
	foreach my $a (@nb_ref)
	{
		$col .= ",t$a->{id_pages} int";
	}
	$self->DBupdate("CREATE TABLE $self->{'BACKUP_TABLE_NAME'} (id_backup int primary key not null$col,desc_backup varchar(200), date_backup varchar(100))") or return undef;
	return 1;
}
sub backupStats
{
	my $self = shift;
	my @args = @_ ;
	for (my $k=0;$k<=$#args;$k=$k+2)
	{
		$self->{"$args[$k]"} = $args[$k+1];
	}
	unless(exists($self->{'BACKUP_TABLE_NAME'}) && defined($self->{'BACKUP_TABLE_NAME'}))
	{
		warn "[ WWW::Statistics::backupStats ] you might specify a main statistics table name with <OBJECT>->updateBackupDBschema(\n\tBACKUP_TABLE_NAME => 'table_name'\n);\nor by :\n<OBJECT>->setBACKUP_TABLE_NAME('table_name')\n";
		return undef;
	}
	unless(exists($self->{'MAIN_STAT_TABLE_NAME'}) && defined($self->{'MAIN_STAT_TABLE_NAME'}))
	{
		warn "[ WWW::Statistics::backupStats ] you might specify a main statistics table name with <OBJECT>->updateBackupDBschema(\n\tMAIN_STAT_TABLE_NAME => 'table_name'\n);\nor by :\n<OBJECT>->setMSTN('table_name')\n";
		return undef;
	}
	unless(exists($self->{'BACKUP_DESCRIPTION'}) && defined($self->{'BACKUP_DESCRIPTION'}))
	{
		warn "[ WWW::Statistics::backupStats ] no description found assuming : no description.\n";
		$self->{'BACKUP_DESCRIPTION'} = 'no description';
	}
	my ($descr) = $self->DBencode('ip-wm',$self->{'BACKUP_DESCRIPTION'}) or return undef;
	my $idmax = 0 ;
	my ($temp)=$self->DBselect("select max(id_backup) as idmax from $self->{'BACKUP_TABLE_NAME'}") or return undef;
	$idmax = $temp->{'idmax'};
	$idmax++;
	my @ref_count = $self->DBselect("SELECT id_pages,nb_seen FROM $self->{'MAIN_STAT_TABLE_NAME'}") or return undef;
	my %schema = $self->getHashShemaFromTable($self->{'BACKUP_TABLE_NAME'});
	my $field = $schema{Field} ;
	my @time = localtime(time);
	$time[2]--;
	$time[4]++;
	$time[5] += 1900 ;
	for(my $k=0;$k<=$#time;$k++)
	{
		$time[$k] = "0$time[$k]" if(length($time[$k])<2) ;
	}
	#my $date = "$time[3]/$time[4]/$time[5] $time[2]H$time[1]min";
	my $date = $time[5].$time[4].$time[3].$time[2].$time[1].$time[0];
	$field=~ s/id_backup/$idmax/;
	$field=~ s/desc_backup/'$descr'/;
	$field=~ s/date_backup/'$date'/;
	for(my $ki = 0 ; $ki <= $#ref_count ; $ki++)
	{
		my $chi = "t$ref_count[$ki]->{id_pages}";
		my $vali = $ref_count[$ki]->{nb_seen} ;
		$field =~ s/$chi/$vali/;
	}
	$self->DBupdate("INSERT INTO $self->{'BACKUP_TABLE_NAME'} VALUES($field)") or return undef;
	if(exists($self->{'RESET_MAIN'}) && defined($self->{'RESET_MAIN'}))
	{
		$self->DBupdate("UPDATE $self->{'MAIN_STAT_TABLE_NAME'} SET nb_seen=0");
	}
	return $idmax;
}
sub updateBackupDBschema
{
	my $self = shift;
	# met à jour en ajoutant ou enlevant des colonnes à la base de donnée. CETTE MÉTHODE NE PEUT PAS ETRE APELÉ SI LA TABLE DE BACKUP EST VIDE !!!!
	my @args = @_ ;
	for (my $k=0;$k<=$#args;$k=$k+2)
	{
		$self->{"$args[$k]"} = $args[$k+1];
	}
	unless(exists($self->{'BACKUP_TABLE_NAME'}) && defined($self->{'BACKUP_TABLE_NAME'}))
	{
		warn "[ WWW::Statistics::updateBackupDBschema ] you might specify a main statistics table name with <OBJECT>->updateBackupDBschema(\n\tBACKUP_TABLE_NAME => 'table_name'\n);\nor by :\n<OBJECT>->setBACKUP_TABLE_NAME('table_name')\n";
		return undef;
	}
	unless(exists($self->{'MAIN_STAT_TABLE_NAME'}) && defined($self->{'MAIN_STAT_TABLE_NAME'}))
	{
		warn "[ WWW::Statistics::updateBackupDBschema ] you might specify a main statistics table name with <OBJECT>->updateBackupDBschema(\n\tMAIN_STAT_TABLE_NAME => 'table_name'\n);\nor by :\n<OBJECT>->setMSTN('table_name')\n";
		return undef;
	}
	my @nb_ref_main = $self->DBselect("SELECT id_pages FROM $self->{'MAIN_STAT_TABLE_NAME'}") or return undef;
	my $idmax = 0 ;
	my ($temp)=$self->DBselect("select max(id_backup) as idmax from $self->{'BACKUP_TABLE_NAME'}") or return undef;
	if(defined($temp->{'idmax'}))
	{
		$idmax = $temp->{'idmax'};
	}
	else
	{
		return undef;
	}
	my %schema = $self->getHashShemaFromTable($self->{'BACKUP_TABLE_NAME'}) or return undef;
	my $field = $schema{Field} ;
	$field=~ s/,//g ;
	$field=~ s/id_backup//;
	$field=~ s/desc_backup//;
	foreach my $a (@nb_ref_main)
	{
		my $ch = "t$a->{id_pages}";
		if($field =~ /$ch/)
		{
			#print "colonne $ch existante dans $self->{'BACKUP_TABLE_NAME'}\n";
			$field=~ s/$ch// ;
		}
		else
		{
			#print "colonne $ch NON existante dans $self->{'BACKUP_TABLE_NAME'}\n";
			$self->DBupdate("ALTER TABLE $self->{'BACKUP_TABLE_NAME'} ADD $ch int");
		}
	}
	#print "Field à la fin : $field\n";
	if($field !~ /^$/)
	{
		my @col = $field =~ /t([0-9]*)/g;#split(/t/,$field);
		foreach my $z (@col)
		{
			#print "\$z : '$z'\n";
			my $chi = "t$z";
			$self->DBupdate("ALTER TABLE $self->{'BACKUP_TABLE_NAME'} DROP $chi") or return undef;
		}
	}
	return 1;
}
sub getIDfromPage
{
	my $self = shift;
	my $page = shift;
	my ($tmp) = $self->DBselect("SELECT id_pages FROM $self->{'MAIN_STAT_TABLE_NAME'} WHERE name_pages='$page'") or return undef;
	return $tmp->{id_pages};
}
sub setMSTN
{
	my $self = shift;
	my $value = shift;
	$self->{'MAIN_STAT_TABLE_NAME'} = $value;
}
sub getMSTN
{
	my $self = shift;
	return $self->{'MAIN_STAT_TABLE_NAME'};
}
sub setBACKUP_TABLE_NAME
{
	my $self = shift;
	my $value = shift;
	$self->{'BACKUP_TABLE_NAME'} = $value;
}
sub getBACKUP_TABLE_NAME
{
	my $self = shift;
	return $self->{'BACKUP_TABLE_NAME'};
}
sub setBACKUP_DESCRIPTION
{
	my $self = shift;
	my $value = shift;
	$self->{'BACKUP_DESCRIPTION'} = $value;
}
sub getBACKUP_DESCRIPTION
{
	my $self = shift;
	return $self->{'BACKUP_DESCRIPTION'};
}
sub setIMAGES_DIR
{
	my $self = shift;
	my $value = shift;
	$self->{'IMAGES_DIR'} = $value;
}
sub getIMAGES_DIR
{
	my $self = shift;
	return $self->{'IMAGES_DIR'};
}
sub availableMethods
{
	my $self = shift;
	printf("Available methods for WWW::Statistics are :\n
	new -> constructor
	setDBHOST(VALUE) -> accessor for setting DBHOST
	getDBHOST -> accessor for getting value of DBHOST
	setDBUSER(VALUE) -> accessor for setting DBUSER
	getDBUSER -> accessor for getting value of DBUSER
	setDBPASSWORD(VALUE) -> accessor for setting DBPASSWORD
	getDBPASSWORD -> accessor for getting value of DBPASSWORD
	setDATABASE(VALUE) -> accessor for setting DBDATABASE
	getDATABASE -> accessor for getting value of DBDATABASE
	setMSTN(VALUE) -> accessor for setting MAIN_STAT_TABLE_NAME
	getMSTN -> accessor for getting value of MAIN_STAT_TABLE_NAME
	setBACKUP_TABLE_NAME(VALUE) -> accessor for setting BACKUP_TABLE_NAME
	getBACKUP_TABLE_NAME -> accessor for getting value of BACKUP_TABLE_NAME
	setBACKUP_DESCRIPTION(VALUE) -> accessor for setting BACKUP_DESCRIPTION
	getBACKUP_DESCRIPTION -> accessor for getting value of BACKUP_DESCRIPTION
	setIMAGES_DIR(VALUE) -> accessor for setting IMAGES_DIR
	getIMAGES_DIR -> accessor for getting value of IMAGES_DIR
	addMainPages -> Add a page to the main stats table (MAIN_STAT_TABLE_NAME)
	dropMainPages -> drop a page to the main stats table (MAIN_STAT_TABLE_NAME)
	getIDfromPage(PAGE_NAME) -> return the id of PAGE_NAME
	initDataBase -> create and initialyzed the main database
	initBackupDatabase -> create the backup database
	decrMainPage(ID_PAGE) -> decrement the page identified by ID_PAGE
	incrMainPage(ID_PAGE) -> increment the page identified by ID_PAGE
	updateBackupDBschema -> update the backup table's schema from the main table one.
	backupStats -> backup statistics.
	generateHTMLBackupGraph -> generate (and return) an HTML <TABLE> wich contain a graph of the specified backup is (see manpage)
	generateHTMLMainGraph -> generate (and return) an HTML <TABLE> wich contain the graph of main table.
	generateGDGraph -> use the GD module to generate a graph (freshmeat like) of the statistics from the backup table.
	reIndexBackupTable -> re-index the id_backup column of BACKUP_TABLE_NAME.
	getMaxFromBackup -> get the maximum id of BACKUP_TABLE_NAME all columns included.
	debugTrace -> a method wich print debug informations
	DBselect(REQUEST) -> execute the SQL request REQUEST (only for ``SELECT'' request)
	DBupdate(REQUEST) -> execute the SQL request REQUEST (all but ``SELECT'' request)
	getShemaHashFromTable(TABLE) -> execute a ``describe'' SQL request on TABLE and return a hash with to key : Field and Type (values are separated by a coma)
	getRefTabShemaFromTable(TABLE) -> execute a ``describe'' SQL request on TABLE and return a table wich contain ref on hash with 2 keys : Field and Type.
	");
	print "\n";
}


# Preloaded methods go here.

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

WWW::Statistics - Perl extension for genarate and manage web site statistics

=head1 SYNOPSIS

	use WWW::Statistics;
	my $wso = WWW::Statistics->new(
		DB_USER => 'test' ,
		DB_PASSWORD => 'toto',
		DB_HOST => '192.168.0.20',
		DB_DATABASE => 'test_stat'
	) or die "[ ERROR ]\n";
	$wso->setMSTN('test_script');
	$wso->setBACKUP_TABLE_NAME('backup_script');
	$wso->initDataBase(
		MAIN_STAT_TABLE_NAME => test_script,
		PAGES_LIST => 'first,seconde,third'
	) or die "[ ERROR ]\n";
	$wso->addMainPages(PAGES_LIST => 'test') or die "[ ERROR ]\n";
	print "[ OK ]\n";
	$id = $wso->getIDfromPage('test');
	print "[+] id page 'test' (according to getIDfromPage)\t $id\n";
	$wso->initBackupDatabase or die "[ ERROR ]\n";
	$wso->dropMainPages(ID_LIST=>$id) or die "[ ERROR ]\n";
	$wso->updateBackupDBschema or die "[ ERROR ]\n";
	my $id = $wso->backupStats(
		BACKUP_DESCRIPTION => 'This is a test of WWW::Statistics'
	);
	my $html = $wso->generateHTMLMainGraph(
		IMAGES_DIR => '/home/arnaud/images/',
		TABLE_NAME_FONT => "<font color='#3366CC'>",
		TABLE_TAG => "<table cellspacing='1' cellpadding='5' width='250' border='0' bgcolor='#000000'>",
		TR_TAG => "<tr bgcolor='#EEEEEE'>"
	);
	Write('gen.html',"$html\n"); ## The Write function is from File::Reader
	$g = $wso->generateGDGraph(
		GRAPH_WIDTH => 800,
		WITH_HTML => 1
	); ## Generate a graph and return the HTML source code wich included him, else this metod return the name of the image.
	my $back = $wso->generateHTMLBackupGraph(
		IMAGES_DIR => '/home/1024/INSEP/soutien/images',
		BACKUP_ID => 5,
		IMAGES_CYCLING => 1,
		TABLE_NAME_FONT => "<font color='#3366CC'>",
		TABLE_TAG => "<table cellspacing='1' cellpadding='5' width='250' border='0' bgcolor='#000000'>",
		TR_TAG => "<tr bgcolor='#EEEEEE'>"
	);
	$wso->reIndexBackupTable;

=head1 DESCRIPTION

This module allow you to simply manage statistics for web site. 
It generate a really simple database, and give you all methods to manage it easily.
With WWW::Statistics you can make your own statistics admin interface really simply.

=head2 EXPORT

None by default.

=head1 METHODS

=item * new :
 constructor. Arguments are :
	DB_HOST : IP adress or hostname of the database (default is 127.0.0.1)
	
        DB_USER : A username wich is authoryzed to connect to database (default is undef)
	
        DB_PASSWORD : The password associates with DBUSER (default is undef)
	
        DB_DATABASE : the database name (default is undef)
        
	DB_TYPE : the DBI driver name (default is 'mysql')
	
	IMAGES_DIR : the directory where we can found images for using in HTML graph generation. (optionnal)
	
Moreover, you can pass all arguments wich are definable by followings accessors. It returned a WWW::Statistics object reference

=item * setMSTN(VALUE) :

 accessor for setting MAIN_STAT_TABLE_NAME. It returned 1 or undef.

=item * getMSTN :

 accessor for getting value of MAIN_STAT_TABLE_NAME.

=item * setBACKUP_TABLE_NAME(VALUE) :

 accessor for setting BACKUP_TABLE_NAME. It returned 1 or undef.

=item * getBACKUP_TABLE_NAME :

 accessor for getting value of BACKUP_TABLE_NAME

=item * setBACKUP_DESCRIPTION(VALUE) :

 accessor for setting BACKUP_DESCRIPTION. It returned 1 or undef.

=item * getBACKUP_DESCRIPTION :

 accessor for getting value of BACKUP_DESCRIPTION

=item * setIMAGES_DIR(VALUE) :

 accessor for setting IMAGES_DIR. It returned 1 or undef.

=item * getIMAGES_DIR :

 accessor for getting value of IMAGES_DIR

=item * addMainPages :

 Add a page to the main stats table (MAIN_STAT_TABLE_NAME). Returned undef if faile, else 1.

=item * dropMainPages :

 drop a page to the main stats table (MAIN_STAT_TABLE_NAME). Returned undef if faile, else 1.

=item * getIDfromPage(PAGE_NAME) :

 return the id of PAGE_NAME. Be carefull with this because if you have 2 pages with same name thereturned result will random...

=item * initDataBase :

 create and initialyzed the main database. Arguments are :
 
	PAGES_LIST : a list of pages you want to manage statistics for. Pass arguments as string (ex: 'index.pl,news.pl,pub.html'). Separator is the coma (',').
	
	If you don't have set it before : MAIN_STAT_TABLE_NAME the main statistics table (where are record current stats). Returned undef if faile, else 1.

=item * initBackupDatabase :

 create the backup database. Returned undef if faile, else 1.

=item * decrMainPage(ID_PAGE) :

 decrement the page identified by ID_PAGE. Returned undef if faile, else 1.

=item * incrMainPage(ID_PAGE) :

 increment the page identified by ID_PAGE. Returned undef if faile, else 1.

=item * updateBackupDBschema :

 update the backup table's schema from the main table one. Returned undef if faile, else 1.

=item * backupStats :

 backup statistics. Returned undef if faile, else 1.

=item * generateHTMLBackupGraph :

 generate (and return) an HTML <TABLE> wich contain a graph of the specified backup is (see generateHTMLMainGraph method for explanation of arguments)

=item * generateHTMLMainGraph :

 generate (and return) an HTML <TABLE> wich contain the graph of main table. Arguments are :
 
 	IMAGES_DIR : if you don't have set it before, the directory where we can find images wich we use to generate the graph.
	
	TABLE_NAME_FONT : opening HTML tag <FONT> wich determine the font of text inside <TD>
	
	TABLE_TAG : HTML tag <TABLE> you can specify special tag here
	
	TR_TAG : specify your <TR> tag here
	
	TD_TAG : specify your <TD> tag here
	
	TH_TAG : specify your <TH> tag here
	
	IMAGES_CYCLING : 0 or 1. If enable module choose one per one the different images wich are present in IMAGES_DIR. Else the module choose the first image.
	
	IMAGES_LIST : specify a list of images you want to use (as a string like 'img1.png,image.gif,logo.xpm' separator is a coma). (OPTIONNAL)
	
	IMG_TAG : specify your <IMG> tag here. Default is : <IMG SRC=__IMGSRC__ ALIGN=__IMGALIGN__ WIDTH=__IMGWIDTH__ HEIGHT=__IMGHEIGHT__>. You can use __IMGSRC__, __IMGALIGN__, __IMGWIDTH__ and __IMGHEIGHT__ as variables.
	
	Default values are :
		
		__IMGSRC__ : IMAGES_DIR/first image in directory. Accessed by IMAGES_DIR and IMAGES_LIST
		
		__IMGALIGN__ : CENTER. Accessed by IMG_ALIGN_TAG
		
		__IMGWIDTH__ : 4 * number of hits. Accessed by POINT_FOR_PIXEL
		
		__IMGHEIGHT__ : 9. Accessed by IMG_HEIGHT_TAG
		
		You can access to thoses variables by followings parameters and use them as variables in your own <IMG> tag.
	
	PIXELS_FOR_POINT : specify the number of pixels you want for a point in statistics. Default is 4 pixels. For example, if you have 10 hits on a page, the image wich represent this value may have 40 pixels long.

WARNING : all *_TAG options accept a string as HTML tag but ONLY THE OPENNING ONE !! Tags are closed by the module. Moreover, they all are optionnals.

=item * generateGDGraph :

 use the GD module to generate a graph (freshmeat like) of the statistics from the backup table. Returned the name of image generate (wich is stored in IMAGES_DIR)

=item * reIndexBackupTable :

 re-index the id_backup column of BACKUP_TABLE_NAME. Returned undef if faile, else 1.

=item * getMaxFromBackup :

 get the maximum id of BACKUP_TABLE_NAME all columns included.

=head2 Heritage

WWW::Statistics heritate from DB::DBinterface so read this module manpage to having a description of his own methods and functions.

=head2 Returned values

Alle methods returned undef if there is a problem.

=head1 SEE ALSO

DB::DBinterface

=head1 AUTHOR

DUPUIS Arnaud, E<lt>a.dupuis@infinityperl.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2004 by DUPUIS Arnaud

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.3 or,
at your option, any later version of Perl 5 you may have available.


=cut

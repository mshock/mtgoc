#! perl 
# generate pricing/completion reports for a csv mtgo collection

use strict;
use LWP::Simple;
use Parse::CSV;

my $buy_flag = 1;

my $col_file = 'mtgo_collection.csv';
my $out_file = 'mtgo_report.txt';

my $bo_prices = get 'http://www.supernovabots.com/prices_6.txt';
my $reg_prices = get 'http://www.supernovabots.com/prices_0.txt';
my $prem_prices = get 'http://www.supernovabots.com/prices_3.txt';

# base rarity / quality values
my %base_val = (
	'Yes'.'C' => .05,
	'Yes'.'U' => .10,
	'Yes'.'R' => .25,
	'Yes'.'M' => 1.0,
	'No'.'C' => .01,
	'No'.'U' => .05,
	'No'.'R' => .10,
	'No'.'M' => .25,
);

my ($buy_tot, $sell_tot) =0 x2;

open(my $csv_handle, '<:encoding(UTF-8)', $col_file);
open(OUT, '>', $out_file);
my $parser = Parse::CSV->new(
      handle     => $csv_handle,
      csv_attr => {
          sep_char   => ',',
          quote_char => '"',
      },
  );
  
# iterate over all lines in collection csv
while(my $row_ref = $parser->fetch) {
	# skip header since names field is buggy for Parse::CSV
	next if $parser->row==1;
	
	my @row = @{$row_ref};
	my ($cname,
		$cquant,
		$ctrade,
		$crarity,
		$cset,
		$cnum,
		$cfoil) = @row;
		
	
	# set the url to get the price from
	my $prices;
	if ($cname =~ /Booster/ && !$cfoil) {
		#print "[OK]\tfound booster @row\n";
		$prices = $bo_prices;
	}
	elsif ($cfoil =~ /Y/) {
		#print "[OK]\tfound foil @row\n";
		$prices = $prem_prices;
	}
	elsif ($cfoil =~ /N/) {
		#print "[OK]\tfound reg @row\n";
		$prices = $reg_prices;
	}
	else {
		print "[ERROR]\tbad row @ @row\n";
	}
	
	my ($buy,$sell);
	if ($prices =~ m/$cname\s*\[$cset\]\s*([0-9\.]+)\s*([0-9\.]+)/) {
		($buy, $sell) = ($1,$2);
	}
	elsif ($prices =~ m/$cname\s*\[$cset\]\s*([0-9\.]+)\s*$/) {
		$buy = $1;
		$sell = $buy_flag?0:$1;
	}
	elsif ($prices =~ m/$cname\s*\[$cset\]\s*([0-9\.]+).*$/) {
		$sell = $1;
		$buy = $buy_flag?0:$base_val{$cfoil.$crarity};
	}
	else {
		
		($buy, $sell) = ($base_val{$cfoil.$crarity}) x2;
		#print "\t\tcard not found, ";
		if ($buy_flag) {
			#print "skipping\n";
			($buy, $sell) = (0,0);
		}
		else  {
			#print "using bulk value\n";
		}
	}
	$buy_tot+=$buy*$cquant;
	$sell_tot+=$sell*$cquant;
	printf "%-50s\t%-7.2f\t%-7.2f\n",$cname.(($cquant-1&&" x$cquant")||''),$buy,$sell if $buy || $sell;
	
}

printf "\n%-50s\t%-7.2f\t%-7.2f\n",'Total', $sell_tot, $buy_tot;
close $csv_handle;
close OUT;

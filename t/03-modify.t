#!/usr/bin/perl -w

use Test::More tests => 10;

use File::Spec;
use File::Compare;
use File::Copy;

use_ok(Text::Modify);

my $input = File::Spec->catfile("t","03-modify.in");
my $tmpfile = File::Spec->catfile("t","03-modify.tmp");
my $output = File::Spec->catfile("t","03-modify.out");

print "Using file: $input $output $tmpfile\n";

my $text = new Text::Modify(file => $input, writeto => $tmpfile, dryrun => 0, backup => 0, debug => 1);
isa_ok($text,"Text::Modify","Instantiate Text::Modify object");

ok($text->replaceLine("sad","funny"),"add rule (simple)");
Debug(2,"Error: $text->getError()") if $text->isError();
ok($text->replaceLine("Multi","Muli"),"add rule (string multi)");
Debug(2,"Error: $text->getError()") if $text->isError();
ok($text->replaceLine("^#.*remove.*",""),"add rule (regex simple)");
Debug(2,"Error: $text->getError()") if $text->isError();
ok($text->deleteLine('removed$'),"delete line rule");
Debug(2,"Error: $text->getError()") if $text->isError();
ok($text->defineRule(replace => '10.10.(\d+).100\s+(\w+)', with => '10.10.10.100	$2'),"add rule (regex with vars)");
Debug(2,"Error: $text->getError()") if $text->isError();
ok($text->defineRule(replace=>'127\.0\.0\.1\s+',with=>"127.0.0.1		localhost\n",ifmissing=>'insert'),"add rule (regex + insert if missing)");
ok($text->process());
my $comp = File::Compare::compare_text($tmpfile,$output, \&compareText );
ok($comp == 0,"Comparing $tmpfile with expected output $output");
unlink($tmpfile);


### Check if test repository is accessable, otherwise skip
# SKIP: {
#     skip "Test repository not found", 7 unless $repl;
# };

### New syntax
# my $fp = new File::Modify(file => $input, writeto => $output, dryrun => 0, backup => 0);
# $fp->definedBlock('myconfig',fromLine=>1,toLine=>20);
# $fp->definedBlock('vendorconf',
# 	fromMatch=>'^#+\s*VENDOR SPECIFIC CONFIG start',
# 	toMatch  =>'^#+\s*VENDOR SPECIFIC CONFIG end',
# 	ignorecase=>1 );
### This is the same as, but without checking for the order of end/start
# $fp->definedBlock('vendorconf',fromMatch=>'^#+\s*VENDOR SPECIFIC CONFIG (start|end)');
# $fp->addRule(replace=>'test',with=>'text',block=>'myconfig')

sub compareText {
	my $a = shift;
	my $b = shift;
	$a =~ s/[\r\n]+$//;
	$b =~ s/[\r\n]+$//;
	if ($a ne $b) { Debug(1,"Expected: '$a'  --> Got: '$b'"); }
	return $a ne $b;
}
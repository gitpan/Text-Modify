package Text::Modify;
#================================================================
# (C)2004, rl AT brabbel.net
#================================================================
# - Multiline replace is NOT supported currently
# - only simple regex and string replacement probably works the
#   way it should
#================================================================

use strict;
use File::Temp qw(tempfile);
use File::Copy;
use Text::Modify::Rule;
use Text::Buffer;
use vars qw($VERSION);

BEGIN {
	$VERSION="0.2";
}

sub new {
    my $class = shift;
    my %default = (
    	backup		=> 1,		# The node id if available (used only for correlation with OMC db)
    	backupExt	=> '.bak',	# The ip address of the core network interface
    	dryrun		=> 0,
    	writeto		=> undef,	# Output file to use, by default a temp. file is created and input file is overwritten 
    	_debug		=> 0
    );
    my $self = bless {%default}, $class;
    # Processing of arguments, either ->new("filename")
    # or ->new(file => "test.txt", writeto => "test.out")
    my %opts;
    if (scalar(@_) > 1) {
    	%opts = @_;
	    if ($opts{debug}) { $self->{_debug} = $opts{debug}; } 
    	foreach (qw(file writeto dryrun backup backupExt)) {
    		if (exists($opts{$_})) {
    			$self->_debug("Setting option: $_ = " . (defined($opts{$_}) ? $opts{$_} : "undef"));
    			$self->{$_} = $opts{$_};
    		}
    	}
    	if ($self->{writeto}) { $self->{backup} = 0; }
    }
    else { $self->{file} = shift; }
    $self->_debug("Created object $class as $self (" . ref($self) . ")");
    $self->clearError();
    $self->{ruleorder} = [];
    $self->{blockorder} = [];
    # Define the "ALL" block, which includes the whole file and is used
    # for rules with no specific block defined
    
    return $self;
}

sub defineBlock {
	my $self = shift;
	my $name = shift;
	my %opts = @_;
	if (exists($self->{block}->{$name})) {
		$self->setError("Block $name already defined");
		return 0;
	}
	if ($opts{fromline}) {
		$self->{block}->{$name}->{from} = $opts{fromline};
	} elsif ($opts{frommatch}) {
		$self->{block}->{$name}->{frommatch} = $opts{frommatch};
	} else {
		$self->{block}->{$name}->{from} = 0;
	}
	if ($opts{toline}) {
		$self->{block}->{$name}->{to} = $opts{toline};
	} elsif ($opts{frommatch}) {
		$self->{block}->{$name}->{tomatch} = $opts{tomatch};
	} else {
		$self->{block}->{$name}->{to} = 999999;
	}
	push @{$self->{blockorder}},$name;
	return 1;
}

sub undefineBlock {
	my $self = shift;
	my $name = shift;
	if (exists($self->{block}->{$name})) {
		$self->_debug("Undefining block $name");
		delete($self->{block}->{$name});
		my @tmp = @{$self->{blockorder}};
		@{$self->{blockorder}} = grep($_ ne $name, @tmp);    
	} else {
		$self->_debug("Block $name not defined, ignoring");
	}
	return 1;
}

sub listMatchBlocks {
	my $self = shift;
	return (grep { !defined($self->{block}->{$_}->{from}) || !defined($self->{block}->{$_}->{to}) } $self->listBlocks());
}

sub listCurrentBlocks {
	my $self = shift;
	return (grep { $self->{block}->{$_}->{active} } $self->listBlocks());
}

sub listBlocks {
	my $self = shift;
	return @{$self->{blockorder}};
}

### TODO Need to define all methods and also options like
### TODO addIfMissing to add a required line even if it is not found at end/start of file or block
# ->replace( replace => "SAD", with => "FUNNY", ignorecase => 1, addIfMissing => 1 )
# ->replace( repalce => "sad (\d+) day", with => "funny \$1 week", ignorecase => 1, addIfMissing => 1 )

sub defineRule {
	my $self = shift;
	my %opts = @_;
	### TODO need to generate a better name if undefined
	my $name = $opts{name};
	if (!$name) {
		$name = "rule" . ($#{$self->{ruleorder}}+1);
	}
	$self->_debug("Defining rule '$name': " . join(",",%opts));
	if (!$opts{replace} && !$opts{insert} && !$opts{'delete'}) {
		$self->addError("Failed to define rule $name");
		return 0;
	}
	$self->{rule}->{$name} = new Text::Modify::Rule(%opts, debug => $self->{_debug});
	if (!$self->{rule}->{$name}) {
		$self->setError("Could not init rule $name");
		return 0;
	}
	push @{$self->{ruleorder}},$name;
	return 1;	
}

sub undefineRule {
	my $self = shift;
	my $name = shift;
	if (exists($self->{rule}->{$name})) {
		$self->_debug("Undefining rule $name");
		delete($self->{rule}->{$name});
		my @tmp = @{$self->{ruleorder}};
		@{$self->{ruleorder}} = grep($_ ne $name, @tmp);    
	} else {
		$self->_debug("Rule $name not defined, ignoring");
	}
	return 1;
}

# Simple syntax ->replaceLine("MY","HIS") or ->replaceLine("WHAT","WITH",ignorecase => 1) 
# supported options are: 
# 	dryrun		do not apply changes
#	ignorecase	ignore case for matching
#	ifmissing 	insert/append/ignore/fail string if missing (cannot use results of regex then)
# 	matchfirst	only match X times for replacing, 1 would only replace the first occurence
sub replaceLine {
	my ($self,$what,$with,%opts) = @_;
	$opts{replace} = $what;
	$opts{with} = $with;
	return $self->defineRule(%opts);
}

sub replaceInBlock { }

# Usage: Delete line matching expressions MATCH
# Syntax: ->deleteLine("MATCH", ignorecase => 1, matchfirst => 1)
# supported options are: 
# 	dryrun		do not apply changes
#	ignorecase	ignore case for matching
#	ifmissing 	ignore|fail if missing
# 	matchfirst	only match X times for replacing, 1 would only replace the first occurence

sub deleteLine { 
	my ($self,$what,%opts) = @_;
	$opts{'delete'} = $what;
	return $self->defineRule(%opts);
}
sub deleteInBlock { }

sub insertLine { 
	my ($self,$what,%opts) = @_;
	$opts{insert} = $what;
	$opts{at} = "top";
	return $self->defineRule(%opts);	
}
sub insertLineInBlock { }

sub appendLine { 
	my ($self,$what,%opts) = @_;
	$opts{insert} = $what;
	$opts{at} = "bottom";
	return $self->defineRule(%opts);	
}
sub appendLineInBlock { }


sub listRules {
	### TODO maybe it would be better to place rules outside of blocks
	my $self = shift;
	$self->_debug("Returning ordered rules: " . join(", ",@{$self->{ruleorder}}));
	return @{$self->{ruleorder}};
}

sub backupExtension {
	my $self = shift;
	my $ext = shift;
	if (defined($ext)) {
		$self->{backupExt} = $ext;
		return 1;
	}
	return $self->{backupExt};
}

sub getBackupFilename {
	my $self = shift;
	my $file = $self->{'file'} || shift;
	my $bakfile = $file . $self->{'backupExt'};
	
	if (-f $bakfile) {
		$self->_debug("Bakfile $bakfile already existing, using next available");
		# TODO Need to do backupfile rotation or merge into createBackup
		my $cnt = 1;
		while (-f "$bakfile.$cnt" && $cnt) {
			$cnt++;
		}
		$bakfile = "$bakfile.$cnt";
	}
	return $bakfile;
}

#=====================================================
# create backup of set or supplied file
#=====================================================
sub createBackup {
	my $self = shift;
	my $file = $self->{'file'} || shift;
	my $bakfile = $self->getBackupFilename();
	### Create a backup if bakfile is set
	if ($bakfile && $bakfile ne $file) {
		$self->_debug("- Creating backup copy $bakfile");
		copy($file,$bakfile);
		# TODO restore permissions and ownership of file
	}
	return $bakfile;
}




sub _processLine {
	my $self = shift;
	my $line = shift;
	# TODO Do the actual processing, block detection and replacing
	my $changed = 0;
	my $out = $line;
	foreach my $rulekey (keys %{$self->{'rule'}}) {
		my $string = undef;
		my $rule = $self->{'rule'}->{$rulekey};
		$self->_debug("Processing rule $rulekey (" . ref($rule) . ")");
		if ($rule) {
			$string = $rule->process($out);
		}
		$self->_debug("Line before(<<<)/after(>>>):\n<<<$line>>>" . ($string || "undef"));
		if (defined($string)) {
			$self->{replacecount} += $rule->getReplaceCount();
			$self->{matchcount}   += $rule->getMatchCount();
			if ($string ne $line) {
				$changed = 1;
				$out = $string;
			}
		}
	
	}
	if ($changed) { $self->{lineschanged}++ }
	if (!$self->{dryrun}) {
		if ($self->{tmpfh}->opened()) {
			$self->{tmpfh}->print($out);
		} else {
			$self->setError("Cannot write to temp. file $self->{tmpname}");
			return 0;
		}
	}
	return $line;
}

sub _readFile {
	my $self = shift;
	my $file = $self->{'file'};
	$self->{linesread} = 0;	
	if (-r $file && open(IN,$file)) {
		while (<IN>) {
			# TODO Actually process the line and do the replacing
			$self->{linesread}++;			
			$self->_debug("Read line " . $self->{linesread} . ": $_");
			push @{$self->{data}},$_;
		}
		close(IN);
		if ($self->isError()) {
			Error($self->getError());
			return 0;
		}
	} else {
		$self->setError("Cannot read from $file");
		return 0;
	}
	return 1;
}

sub _writeFile {
	my $self = shift;
	my $file = $self->{'writeto'};
	$self->{lineswritten} = 0;
	# TODO maybe should move back processing here	
	if (-w $file && open(OUT,">$file")) {
		$self->_debug(3,"Writing to file $file");
		foreach (@{$self->{data}}) {
			$self->_debug("Writing: $_");
			print OUT $_;
			$self->{lineswritten}++;
		}
		if (!close(OUT)) {
			$self->setError("Failed to close file after $self->{lineswritten} lines written");
			return 0;
		}
	} else {
		$self->setError("Cannot write file $file");
		return 0;
	}
	return 1;
}

sub process {
	my $self = shift;
	my $file = $self->{'file'};
	my $bakfile = "";
	if ($self->{'backup'}) {
		$self->_debug("Creating backup");
		$bakfile = $self->createBackup();
		if ($self->isError()) {
			Error($self->getError());
			return 0;
		}
	}
	my $txtbuf = Text::Buffer->new(file => $file);
	$self->{linesread} = $txtbuf->getLineCount();
	$self->{_buffer} = $txtbuf;
	$self->_debug("Read $self->{linesread} from $file");

# TODO Need this for processing of large files	
#	if (!$self->{writeto}) {
#		($self->{tmpfh},$self->{tmpname}) = tempfile();
#		$self->_debug(2,"Using temp. file: $self->{tmpname}");
#	}

	$self->{replacecount} = 0;
	$self->{matchcount} = 0;
	$self->{addcount} = 0;
	$self->{deletecount} = 0;
	$self->{lineschanged} = 0;
	$self->{linesprocessed} = 0;

	$self->_debug("Starting processing of data " . (defined($self->{data}) ? $self->{data} : "undef") . " (error=" . $self->isError(). ")");	
	foreach ($self->listRules()) {
		my $rule = $self->{rule}->{$_};
		$self->_debug("Processing rule $_");
		$rule->process($self->{_buffer});
		$self->{replacecount} += $rule->getReplaceCount();
		$self->{matchcount} += $rule->getMatchCount();
		$self->{addcount} += $rule->getAddCount();
		$self->{deletecount} += $rule->getDeleteCount();
		$self->_debug("Stats rule $_ (change/match/repl/add/del): " . 
			"$self->{lineschanged}/$self->{matchcount}/$self->{replacecount}/$self->{addcount}/$self->{deletecount}");
		if ($rule->isError()) {
			$self->addError($rule->getError());
			last;
		}
	}
	if ($self->isError()) {
		return 0;
	}
	
	### Now mv the temp. file to overwrite the original configfile
	if (!$self->{dryrun}) {
		if (!$self->{_buffer}->save($self->{writeto})) {
			return 0;
		}
	} else {
		$self->_debug("Dryrun, not writing file")
	}
	$self->_debug("Statistics:
	Lines read: 	$self->{linesread}   
	Lines changed:  $self->{lineschanged}   
	Lines matched:  $self->{matchcount}   
	Lines replaced: $self->{replacecount}
	Lines added:	$self->{addcount}
	Lines deleted:	$self->{deletecount}");
	return 1;
}

sub dryrun {
	my $self = shift;
	$self->{dryrun} = 1;
	my $rc = $self->process();
	$self->{dryrun} = 0;
	return $rc;
}

sub isDryRun          { return shift->{dryrun}; }
sub getLinesModified  { return shift->{lineschanged}; }
sub getLinesProcessed { return shift->{linesprocessed}; }
sub getReplaceCount   { return shift->{replacecount}; }
sub getMatchCount     { return shift->{matchcount}; }
sub getAddCount       { return shift->{addcount}; }
sub getDeleteCount    { return shift->{deletecount}; }

#=============================================================
# ErrorHandling Methods
#=============================================================
sub addError { my $self = shift; $self->{error} .= shift; }
sub isError { return (shift->{'error'} ? 1 : 0); }
sub setError { my $self = shift; $self->{error} = shift; }
sub getError {
	my $self = shift;
	my $error = $self->{error};
	$self->clearError();
	return $error;
}
sub clearError { shift->{error} = ""; }

#=============================================================
# Private methods (for internal use )
#=============================================================

# Only internal function for debug output
sub _debug {
	my $self = shift;
	if ($self->{_debug}) {
		print "@_\n";
	}
}

1;
package Text::Modify::Rule;

# TODO Concept change to support blocks/insert/addIfMissing options
# maybe this has to be moved outside of rule, as a rule has no scope of work only a single line
# the concept has to be extended to working on the whole file/block, with a special concept to 
# handle large files (>100KB) with autodetection of file size (slow but working)

use strict;

#====================================================
# Possible usage and params:
# replace=>'texttoreplace',with=>'anothertext'
# 	optional:
#		ifMissing=>'insert|append|warn|fail'
#		match=>'first'	(last not implemented yet)
#====================================================
sub new {
    my $class = shift;
    my $self = {
    	addcount => 0,
    	deletecount => 0,
    	matchcount => 0,
    	replacecount => 0,
    	ignorecase => 1,
    	dryrun => 0,
    	matchfirst => 65535,
    	_debug => 0
    };
    bless $self,$class;
    $self->clearModified();
    $self->clearError();
    my %opts = @_;
    if ($opts{debug}) { $self->{_debug} = $opts{debug}; } 
    $self->{'type'} = undef;
	if ($opts{replace}) {
		if (defined($opts{with})) {
			$self->{type}  = 'replace';
			$self->{regex} = $opts{replace};
			# Set available options
			foreach (qw(replace with dryrun ignorecase matchfirst ifmissing)) {
				$self->{$_}= $opts{$_} if (defined($opts{$_}));
			}
			# Create the regex options from params
			$self->{opts} .= ($self->{ignorecase} ? "i" : "");
		}
	} elsif ($opts{insert}) {
		if (defined($opts{at})) {
			$self->{type} = 'insert';
			$self->{regex} = "";
			# Set available options
			foreach (qw(insert at dryrun ignorecase ifmissing)) {
				$self->{$_}= $opts{$_} if (defined($opts{$_}));
			}
		}
	} elsif ($opts{delete}) {
		$self->{type} = 'delete';
		$self->{regex} = $opts{delete};
		# Set available options
		foreach (qw(dryrun ignorecase matchfirst)) {
			$self->{$_}= $opts{$_} if (defined($opts{$_}));
		}
	} elsif ($opts{move}) {
		# TODO move option not implemented
		if (defined($opts{to})) {
			$self->{type} = 'move';
			$self->{regex} = $opts{move};
			# Set available options
			foreach (qw(move to dryrun ignorecase matchfirst ifmissing)) {
				$self->{$_}= $opts{$_} if (defined($opts{$_}));
			}
		}
	} 
	if (!$self->{type}) {
		$self->_debug(1,"Unknown type");
		$self->setError("Unknown Rule type");
		return undef;	
	}
	if (!defined($self->{opts})) { $self->{opts} = ""; }
    return $self;
}

sub isError    { my $self = shift; return ($self->{error} ne ""); }
sub clearError { my $self = shift; $self->{error} = ""; }
sub setError   { my $self = shift; $self->{error} = shift; }
sub getError   { return shift->{error}; }

sub setModified   { my $self = shift; $self->{'modified'} = 1; }
sub clearModified { my $self = shift; $self->{'modified'} = 0; }

sub getAddCount {
	return shift->{addcount};
}
sub getMatchCount {
	return shift->{matchcount};
}
sub getDeleteCount {
	return shift->{deletecount};
}
sub getReplaceCount {
	return shift->{replacecount};
}

sub processLine {
	my $self = shift;
	my $string = shift;
	return undef if !defined($string);
	my ($match,$opts) = ($self->{replace},$self->{opts});
	if ($self->{matchcount} >= $self->{matchfirst}) {
		$self->_debug(4,"First matches reached, ignoring this line");
		return $string;
	}
	my $found = 0;
	eval "\$found = (\$string =~ /$match/$opts);";
	$self->_debug(5,"Eval: \$found = ('$string' =~ /$match/$opts) = $found");
	if ( $found ) {
		$self->_debug(4,"Found match for $string... replacing with $self->{'with'}");
		$self->{matchcount}++;
		my $tmp = $string;
		eval "\$tmp =~ s/$match/$self->{with}/g$opts";
		if ($tmp ne $string) { $self->{replacecount}++ };
		return $tmp;
	}
	return $string;
}

#==================================
# Process block of lines
#==================================
sub process {
	my $self = shift;
	my $txt = shift;
	if (!($txt && $txt->isa("Text::Buffer"))) {	return undef; }
	my @insertblock;
	my @appendblock;
	# Start processing
	$self->_debug("processing rule of type $self->{type} with match ", $self->{regex});
	my $i=0;
	my $abs=0;
	my ($match,$opts) = ($self->{regex},$self->{opts});
	my $found = 0;
	my $rc = 1;		# Return code for this function
	$txt->goto('top');
	my $string = $txt->get();
	while (defined($string)) {
		$abs++;
		if ($self->{matchcount} >= $self->{matchfirst}) {
			$self->_debug(4,"First matches reached, ignoring rest for this rule");
			last;
		}
		eval "\$found = (\$string =~ /$match/$opts);";
		$self->_debug(5,"Eval: \$found = ('$string' =~ /$match/$opts) = $found");
		if ( $found ) {
			$self->{matchcount}++;
			# TODO complete all functionality here (replace,insert,delete,move)
			$self->_debug(3,"Found match on line $abs (rel $i): $string");
			if ($self->{type} eq "delete") {
				$self->{deletecount}++;
				# Should be deleted from array
				$self->_debug(4,"deleting line");
				$txt->delete();
			}
			elsif ($self->{type} eq "move") {
				# Should be deleted from array
				$self->{addcount}++;
				$self->{deletecount}++;
				$self->_debug(4,"moving line");
				if ($self->{to} eq "top") {
					$txt->insert($string);
				} else {
					$txt->append($string);
				}
				$txt->delete();
			}
			elsif ($self->{type} eq "replace") {
				$self->_debug(4,"replacing with $self->{'with'}");
				my $tmp = $string;
				eval "\$tmp =~ s/$match/$self->{with}/g$opts";
				if ($tmp ne $string) { $self->{replacecount}++; $self->setModified(); };
				$txt->set($tmp);
			}
			else {
				$self->setError("not processed by any rule");
				return 0;
			}
		}
		$string = $txt->next();
	}
	
	if ($self->{type} eq "insert") {
		# Should be deleted from array
		$self->_debug(4,"insert line");
		$self->{addcount}++;
		if ($self->{ifmissing} eq "insert") {
			$self->_debug(4,"inserting missing line");
			$txt->insert($self->{with});
		} else {
			$self->_debug(4,"appending missing line");
			$txt->append($self->{with});
		}
		next;
	}
	
	# process missing elements
	$self->_debug(5,"Processing ifmissing: ifmissing=" . ($self->{ifmissing} ? $self->{ifmissing} : "unset") . " matches=" . $self->getMatchCount());
	if ($self->{ifmissing} && $self->getMatchCount() == 0) {
		# Add the missing element now
		$self->{addcount}++;
		if ($self->{ifmissing} eq "insert") {
			$self->_debug(4,"inserting missing line");
			$txt->insert($self->{with});
		}
		elsif ($self->{ifmissing} eq "append") {
			$self->_debug(4,"appending missing line");
			$txt->append($self->{with});
		}
		elsif ($self->{ifmissing} eq "ignore") {
			$self->_debug(4,"ignoring missing line");
		}
		elsif ($self->{ifmissing} eq "error") {
			$self->setError("Required line $match not found");
			$rc = 0;
		}
	}

	$self->_debug("=== OUT ===\n" . $txt->dumpAsString() . "=== EOF ===") if ($self->{_debug});
	
	return $rc;
}

sub _debug {
	my $self = shift;
	if ($self->{_debug}) {
		print "@_\n";
	}
}

1;
package Text::Buffer;

use strict;
use vars qw($VERSION);

use Carp;

BEGIN {
	$VERSION = '0.3';
}

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self = {
				 _debug    => 1,
				 _buffer   => [],
				 _currline => 0,
				 _modified => 0
	};

	bless( $self, $class );
	$self->_debug("Instantiated new object $class");

	my %opts = @_;
	if ( $opts{file} ) {
		$self->{file} = $opts{file};
		$self->load();
	}
	elsif ( $opts{array} ) {
		if ( ref( $opts{array} ) eq "ARRAY" ) {
			foreach ( @{ $opts{array} } ) {
				$self->append($_);
			}
		}
		$self->_setModified(1);
	}

	return $self;
}

sub load {
	my $self = shift;
	my $file = shift || $self->{file};
	if ( !$file ) {
		$self->_setError("No file to load specified");
		return undef;
	}
	$self->_debug("Loading file $file");
	if ( open( FIL, $file ) ) {
		$self->_debug("clearing buffer and adding $file to buffer");
		$self->clear();
		while (<FIL>) {
			$self->append($_);
		}
		close(FIL);
		$self->_clearModified();
		return 1;
	}
	else {
		$self->_setError("Failed to load file $file");
		return undef;
	}
	return 0;
}

sub save {
	my $self = shift;
	my $file = shift || $self->{file};
	if ( !$file ) {
		$self->_setError("No file to save to specified");
		return undef;
	}

	if ( !$self->isModified() ) {
		$self->_debug("Buffer not modified, not saving to file $file");
		return 1;
	}
	else {
		$self->_debug(
				   "Saving " . $self->getLineCount() . " lines to file $file" );
	}

	if ( open( FIL, ">$file" ) ) {
		$self->_debug("saving buffer to $file");
		$self->goto('top');
		my $str = $self->get();
		my $cnt = 0;
		while ( defined($str) ) {
			$cnt++;
			print FIL $str;
			$str = $self->next();
		}
		close(FIL);
		return $cnt;
	}
	else {
		$self->_setError("Failed to load file $file");
		return undef;
	}

	return 0;
}

sub clear {
	my $self = shift;
	@{ $self->{_buffer} } = ();
	$self->{_currline} = 0;
	return 1;
}

#=============================================================
# Public Methods
#=============================================================
# Navigation methods
#-------------------------------------------------------------

# Internal method returning the resulting array position (starting at 0)
sub _translateLinePos {
	my $self    = shift;
	my $linenum = shift || return undef;
	my $curr    = $self->{_currline};      # Resulting line to return
	if ( $linenum =~ /^[0-9]+$/ ) {
		$curr = $linenum - 1;
	}
	elsif ( $linenum =~ /^[+-]\d+$/ ) {
		eval "\$curr=$curr$linenum";
	}
	elsif ( $linenum =~ /^(start|top|first)$/ ) {
		$curr = 0;
	}
	elsif ( $linenum =~ /^(end|bottom|last)$/ ) {
		$curr = $self->getLineCount() - 1;
	}
	else {
		$self->_debug("Could not translate: $linenum");
		return undef;
	}

	# do sanity check now
	if ( $curr < 0 || $curr >= $self->getLineCount() ) {
		$self->_debug(
					"Failed sanity check, current line would be out of bounds");
		return undef;
	}

	return $curr;
}

sub goto {
	my $self = shift;
	my $goto = shift;
	my $curr = $self->_translateLinePos($goto);

	if ( !defined($curr) ) {
		$self->_setError("Invalid line position: $goto");
		return undef;
	}

	$self->_debug(   "goto $goto succeeded from array pos "
				   . $self->{_currline}
				   . " to $curr" );
	$self->{_currline} = $curr;
	return $self->getLineNumber();
}

sub getLineCount {
	my $self = shift;
	return ( $#{ $self->{_buffer} } + 1 );
}

sub getLineNumber {
	my $self = shift;
	$self->_debug(   "line is "
				   . ( $self->{_currline} + 1 )
				   . ", array pos is $self->{_currline}" );
	return ( $self->{_currline} + 1 );
}

sub isEOF { return shift->isEndOfBuffer() }

sub isEndOfBuffer {
	my $self = shift;
	return ( $self->{_currline} >= $self->getLineCount() );
}
sub isEmpty { return ( shift->getLineCount() == 0 ) }

sub isModified     { return shift->{_modified}; }
sub _setModified   { my $self = shift; $self->{_modified}++; }
sub _clearModified { my $self = shift; $self->{_modified} = 0; }

sub next {
	my $self = shift;
	my $num  = shift || 1;

	#FIXME should return all lines as array in array context
	if ( !$self->goto("+$num") ) {
		return undef;
	}
	return $self->get();
}

sub previous {
	my $self = shift;
	my $num  = shift || 1;

	#FIXME should return all lines as array in array context
	if ( !$self->goto("-$num") ) {
		return undef;
	}
	return $self->get();
}

#-------------------------------------------------------------
# Searching methods
#-------------------------------------------------------------
sub find {
	return undef;
}

sub findNext {
	return undef;
}

sub findPrevious {
	return undef;
}

#-------------------------------------------------------------
# Viewing/Editing methods
#-------------------------------------------------------------
sub get {
	my $self    = shift;
	my $linenum = shift;
	if ( defined($linenum) ) { $linenum = $self->_translateLinePos($linenum) }
	else { $linenum = $self->{_currline} }
	if ( !defined($linenum) ) {
		$self->_setError("Invalid line position");
		return undef;
	}
	my $line = ${ $self->{_buffer} }[$linenum];
	$self->_debug( "get line $linenum in array: "
				   . ( defined($line) ? $line : "*undef*" ) );
	return $line;
}

sub set {
	my $self    = shift;
	my $line    = shift;
	my $linenum = shift;
	if ( defined($linenum) ) { $linenum = $self->translateLinePos($linenum) }
	else { $linenum = $self->{_currline} }
	if ( !defined($line) ) {
		$self->_setError("Cannot set undefined data for line $linenum");
		return undef;
	}
	$self->_debug("set line $linenum in array: $line");
	if ( !defined( ${ $self->{_buffer} }[$linenum] )
		 || ${ $self->{_buffer} }[$linenum] ne $line )
	{
		$self->_setModified();
	}

	${ $self->{_buffer} }[$linenum] = $line;
	return 1;
}

# Insert before start of buffer
sub insert {
	my $self = shift;
	unshift( @{ $self->{_buffer} }, @_ );
	return 1;
}

sub append {
	my $self = shift;
	push( @{ $self->{_buffer} }, @_ );
	return 1;
}

sub delete {
	my $self = shift;
	splice( @{ $self->{_buffer} }, $self->{_currline}, 1 );
	return $self->get();
}

sub dumpAsString {
	my $self = shift;
	return
	  join( "", map { ( defined($_) ? $_ : "*undef*" ) } @{ $self->{_buffer} } )
	  if ( $self->{_buffer} )
	  && ( ref( $self->{_buffer} ) eq "ARRAY" )
	  && $#{ $self->{_buffer} } >= 0;
	return "";
}

sub replace {
	my $self  = shift;
	my $match = shift;
	my $with  = shift;
	my $opts  = shift;
	if ( !defined($opts) ) { $opts = "g"; }
	my $count;
	my $str = $self->get();
	return undef if !defined($str);
	$self->_debug(
"Doing replacement of '$match' with '$with' (opts: $opts) on string: $str" );
	eval "\$count = (\$str =~ s/$match/$with/$opts)";

	if ($count) {
		$self->set($str);
	}

	return $count;
}

#-------------------------------------------------------------
# ErrorHandling Methods
#-------------------------------------------------------------
sub _setError { my $self = shift; $self->{error} = shift; }
sub isError { return ( shift->{'error'} ? 1 : 0 ); }

sub getError {
	my $self  = shift;
	my $error = $self->{error};
	$self->_clearError();
	return $error;
}
sub _clearError { shift->{error} = ""; }

#=============================================================
# Private Methods
#=============================================================
# Only internal function for debug output
sub _debug {
	my $self = shift;
	if ( $#_ == -1 ) {
		return $self->{_debug};
	}
	elsif ( $self->{_debug} ) {
		print "[DEBUG] @_\n";
	}
}

1;
__END__

=head1 NAME

Text::Buffer - oo-style interface for handling a line-based text buffer

=head1 SYNOPSIS

  use Text::Buffer;

  my $text = new Text::Buffer(-file=>'my.txt');

  $text->goto(5);                   # goto line 5
  $text->delete();                  # return the whole buffer as string
  $text->replace("sad","funny");    # replace sad with funny in this line
  my $line = $text->next();         # goto next line
  $text->set($line);                # exchange current line with $line
  $text->next();                    # goto next line
  $text->insert("start of story");  # Insert text at start of buffer
  $text->append("end of story");    # Append text at end of buffer

=head1 DESCRIPTION

C<Text::Buffer> provides a mean of handling a text buffer with an 
oo-style interface.

It provides basic navigation/editing functionality with an very easy
interface. Generally a B<Text::Buffer> object is created by using
B<new>. Without an options this will create an empty text buffer. 
Optionally a file or reference to an array can be provided to load
this into the buffer. 

	my $text = new Text::Buffer();

Now the basic methods for navigation (goto, next, previous), searching
(find, findNext, findPrevious) or viewing/editing (get, set, delete, 
insert, append and replace).

	$text->goto("+1");
	my $line = $text->get();
	$line =~ s/no/NO/g;
	$text->set($line);

=head1 Methods

=over 8

=item new

    $text = new Text::Buffer(%options);

This creates a new object, starting with an empty buffer unless the
B<-file> or B<-array> options are provided. The available
attributes are:

=over 8

=item file FILE

File to open and read into the buffer. The file will read immediatly
and is closed after reading, as it is read completly into the buffer.
Be sure to have enough free memory available when opening large files.

=item array \@ARRAY

The contents of array will by copied into the buffer. Creates the buff
This specifies one or more prompts to scan for.  For a single prompt,
the value may be a scalar; for more, or for matching of regular
expressions, it should be an array reference.  For example,

    array => \@test
    array => ['first line','second line']

# TODO Handling of line endings can be altered with the autoNewLine option.

=back

=item load

	$text = new Text::Buffer(file => "/tmp/foo.txt")
    $text->load();
    $text->load("/tmp/bar.txt");

Load the specified file (first argument or the one during new with -file option)
into the buffer, which is cleared before loading.

=item save

	$text = new Text::Buffer(file => "/tmp/foo.txt")
	# ... do some modifications here ...
    $text->save();
    $text->save("/tmp/bar.txt");

Load the specified file (first argument or the one during new with -file option)
into the buffer, which is cleared before loading

=item goto

    $text->goto(5);
    $text->goto("+2");

Sets the current line to edit in the buffer. Returns undef if the requested 
line is out of range. When supplying a numeric value (matching [0-1]+) the
line is set to that absolut position. The prefixes + and - denote a relative
target line. The strings "top" or "start" and "bottom" or "end" are used for
jumping to the start or end of the buffer.
The first line of the buffer is B<1>, not zero.

=item next

    $text->next();
    $text->next(2);

Accepts the same options as goto, which is performed with the option 
provided and the new line is returned. In array context returns all lines
from the current to the new line (expect the current line).
Undef is returned if the position is out of range.

=item previous

Same as B<next>, but in the other editing direction (to start of buffer).

=item get

    my $line = $text->get();
	
Get the current line from the buffer.

=item set

    $text->set("Replace with this text");
	
Replace the current line in the buffer with the supplied text.

=item insert

    $text->insert("top of the flops");

Adds the string to the top of the buffer.

=item append

Same as B<insert>, but adds the string at the end of the buffer.

=item replace

	my $count = $text->replace("foo","bar");

Replace the string/regex supplied as the first argument with the
string from the second argument. Returns the number of occurences.
The example above replaces any occurence of the string B<foo> with
B<bar>.

=item delete

	$text->delete();
	my $nextline = $this->delete(); 

Deletes the current editing line and gets the next line (which will have
the same line number as the deleted now). 

=item clear

	$text->clear();

Resets the buffer to be empty. No save is performed.

=item getLineCount

Returns the number of lines in the buffer. Returns 0 if buffer is empty.

=item getLineNumber

Returns the current line position in the buffer (always starting at 1).

=item isModified

Returns 1 if the buffer has been modified, by using any of the
editing methods (replace, set, insert, append, ...)

=item isEmpty

Returns 1 if the buffer is currently empty.

=item isEOF
=item isEndOfBuffer

	while (!$text->isEndOfBuffer()) { $text->next(); }

Returns 1 if the current position is at the end of file.

=item find

	my $linenum = $text->find("/regex/");

Search for the supplied string/regex in the buffer (starting at top of
buffer). Even if 2 matches are found in the same line, find always returns
the next found line and 0 if no more lines are found.

# TODO Implement search wrapping

=item findNext

	my $linenum = $text->findNext();

Repeats the search on the next line, search to the end of the buffer.

=item findPrevious

	my $linenum = $text->findPrevious();

Repeats the search on the previous line, searching to the top of the buffer.

=item isError
=item getError

	if ($text->isError()) { print "Error: " . $text->getError() . "\n"; }

Simple error handling routines. B<isError> returns 1 if an internal error
has been raised. B<getError> returns the textual error.

=item dumpAsString

	print $text->dumpAsString();

Returns (dumps) the whole buffer as a string. Can be used to directly
write to a file or postprocess manually.

=back


=head1 BUGS

There definitly are some, if you find some, please report them, by
contacting the author.

=head1 LICENSE

This software is released under the same terms as perl itself. 
You may find a copy of the GPL and the Artistic license at 

   http://www.fsf.org/copyleft/gpl.html
   http://www.perl.com/pub/a/language/misc/Artistic.html

=head1 AUTHOR

Roland Lammel (lammel@cpan.org)

=cut

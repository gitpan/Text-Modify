#!/usr/bin/perl -w

use strict;

use Test::More tests => 40;

use Text::Buffer;

my $text = Text::Buffer->new();

# Text::Buffer does not handle newlines anywhere special
# currently, so use simple strings for comparision

# Empty buffer tests
ok( $text, 'create empty buffer');
is( $text->getLineCount(), 0, 'empty line count'); 
is( $text->getLineNumber(), 1, 'line pos is 1 (even on empty buffer)' ); 
ok( $text->isEOF(), 'empty buffer is always EOF' );
ok( $text->isEmpty(), 'empty buffer is emtpy' );

ok( $text->insert("bar"), 'inserting bar' );
# insert increases the linecount, but should not alter curr linepos
is( $text->getLineCount(), 1, 'correct line count after insert' );
is( $text->get(), "bar", 'correct get after insert' );

# replace content of current line
ok( $text->set("foo"), 'set current line');
is( $text->get(), "foo", 'get after set');

is( $text->getLineNumber(), 1, 'correct line pos after insert' );
ok( $text->append("bar"), 'appending bar' );
# append should not alter the current position
is( $text->getLineNumber(), 1, 'correct line pos after append' );
is( $text->get(), "foo", 'correct current line content after append' );

ok( $text->append("noone","wants","me" ), 'appending 3 lines' );
is( $text->getLineCount(), 5, 'count after array append' );

# Test navigation
is( $text->goto(3), 3, 'goto line 3' );
is( $text->get(), "noone", 'get content of line 3' );

is( $text->goto("-2"), 1, 'goto line 1 by -2' );
is( $text->get(), "foo", 'get content of current line' );
is( $text->goto("+3"), 4, 'goto line 4 by +3' );
is( $text->get(), "wants", 'get content of current line' );
is( $text->next(), "me", 'get next' );
is( $text->previous(2), "noone", 'get previous 2' );

my $linecount = $text->getLineCount();
is( $text->goto('top'), 1, 'goto top');
is( $text->goto('bottom'), $linecount, 'goto top');
is( $text->goto('start'), 1, 'goto top');
is( $text->goto('end'), $linecount, 'goto top');
is( $text->goto('first'), 1, 'goto top');
is( $text->goto('last'), $linecount, 'goto top');

# outofbounds checks, error handling
is( $text->goto(1000), undef, 'goto invalid pos');
ok( $text->getError() =~ /Invalid line position/i, 'correct error');
ok( !$text->getError(), 'error should be cleared after first get');

is( $text->goto(-1000), undef, 'goto invalid pos');
ok( $text->getError() =~ /Invalid line position/i, 'correct error');

is( $text->goto('blabla'), undef, 'goto invalid pos');
ok( $text->getError() =~ /Invalid line position/i, 'correct error');

# replace tests
$text->goto(1);
ok($text->set("foo needs bar even if foo is a foobar"),'Create string for replace');
is($text->replace('foo','bar'),3,"replace foo with bar");
is($text->get(), "bar needs bar even if bar is a barbar", 'replaced string also ok');

# TODO search/find test

# TODO add save buffer test
# ok( $text->save("foo") == 1, 'save buffer' );

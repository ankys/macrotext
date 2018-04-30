
use strict;
use warnings;
use utf8;

use File::Basename;
use File::Spec;

# use MacroText;
require File::Spec->catfile(File::Basename::dirname(__FILE__), "MacroText.pm");

sub file_readall {
	my $path = shift;
	unless (open(IN, $path)) {
		return;
	}
	binmode(IN);
	local $/;
	my $text = <IN>;
	close(IN);
	return $text;
}

my $path_tests = shift(@ARGV) || File::Spec->catfile(File::Basename::dirname(__FILE__), "test.txt");
my $start = shift(@ARGV);
my $end = shift(@ARGV);

my $text_tests = file_readall($path_tests);

my $posmap = Util::posmap_new_split_lines($text_tests);
my @entrys = ();
while ($text_tests =~ m/===([^\x0D\x0A]*)(?:\x0D\x0A|\x0D|\x0A)(.*?)(?:\x0D\x0A|\x0D|\x0A)---(?:\x0D\x0A|\x0D|\x0A)(.*?)(?:\x0D\x0A|\x0D|\x0A)---(?:\x0D\x0A|\x0D|\x0A)/osg) {
	my $title = $1;
	my $input = $2;
	my $output = $3;
	my $position = $-[2];
	$title =~ s/^\s*|\s*$//osg;
	my $entry = { title => $title, input => $input, output => $output, position => $position, file_path => $path_tests, posmap => $posmap };
	push(@entrys, $entry);
}

my $callback = sub {
	my $mt = shift;
	my $code = shift;
	my $type = shift;
	my $get_msg = shift;
	my $pos = shift;
	my $entry = shift;
	return if $type eq "Debug";
	my $file = $entry->{file_path};
	my $posmap = $entry->{posmap};
	$pos += $entry->{position};
	my ($row, $col) = Util::posmap_get($posmap, $pos);
	($row, $col) = ($row + 1, $col + 1);
	my $msg = $get_msg->();
	print STDERR "$file:$row:$col:$type: $msg\n";
};
my $mt = MacroText::new({ allow_system => 1, callback => $callback });

my @range =
	defined($start) && defined($end) ? ($start .. $end) :
	defined($start) ? ($start) :
	(1 .. scalar(@entrys));
my @failed_indexs = ();
for my $index (@range) {
	$mt = $mt->clear_macros();
	my $entry = $entrys[$index - 1];
	my $title = $entry->{title};
	my $input = $entry->{input};
	my $correct_output = $entry->{output};
	my $node = $mt->parse($input, $entry);
	my $enode = $mt->eval($node);
	my $output = $enode->tostring();
	my $success = $output eq $correct_output;
	if ($success) {
		print "test $index $title: OK\n";
	} else {
		print "test $index $title: NG\n";
		print "$input\n";
		print "$output\n";
		print "$correct_output\n";
		push(@failed_indexs, $index);
	}
}
if (scalar(@failed_indexs) > 0) {
	my $failed = join(" ", @failed_indexs);
	print "NG $failed\n";
} else {
	print "OK all\n";
}

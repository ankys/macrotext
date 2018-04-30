
#
# macro text
# \@setl{a}{1 2}\join{:}{\map{\add{\_}{2}}{\a}}
# -> \@setl{ a }{ 1 2 } \join{ : }{ \map{ \add{ \_ }{ 2 } }{ \a } }
# -> \join{ : }{ \map{ \add{ \_ }{ 2 } }{ 1 2 } }
# -> \join{ : }{ \add{ 1 }{ 2 } \add{ 2 }{ 2 } }
# -> \join{ : }{ 3 4 }
# -> 3:4
#

package MacroText;
use v5.8;
use strict;
use warnings;
use utf8;

use Encode;
use List::Util;
use File::Basename;
use File::Path;

{
package Util;
sub integer_range {
	my $start = shift;
	my $end = shift;
	return $start < $end ? ($start .. $end) : reverse($end .. $start);
}
sub list_transpose {
	my $length = List::Util::max(map { scalar(@$_) } (@_));
	return unless defined($length);
	my @list = ();
	for (my $i = 0; $i < $length; $i++) {
		push(@list, [map { $_->[$i] } (@_)]);
	}
	return @list;
}
sub list_allnexts(&@) {
	my $code = shift;
	no strict 'refs';
	use vars qw($a $b);
	my $caller = caller;
	my ($a, $b);
	local(*{"${caller}::a"}) = \$a;
	local(*{"${caller}::b"}) = \$b;

	for (my $i = 0; $i + 1 < scalar(@_); $i++) {
		$a = $_[$i];
		$b = $_[$i + 1];
		if (!&{$code}()) {
			return;
		}
	}
	return 1;
}
sub list_alltwo(&@) {
	my $code = shift;
	no strict 'refs';
	use vars qw($a $b);
	my $caller = caller;
	my ($a, $b);
	local(*{"${caller}::a"}) = \$a;
	local(*{"${caller}::b"}) = \$b;

	for (my $i = 0; $i < scalar(@_); $i++) {
		for (my $j = $i + 1; $j < scalar(@_); $j++) {
			$a = $_[$i];
			$b = $_[$j];
			if (!&{$code}()) {
				return;
			}
		}
	}
	return 1;
}
sub list_group(&@) {
	my $code = shift;
	no strict 'refs';
	use vars qw($a $b);
	my $caller = caller;
	my ($a, $b);
	local(*{"${caller}::a"}) = \$a;
	local(*{"${caller}::b"}) = \$b;

	my @groups = ();
	my ($c_group, $c_value);
	for my $value (@_) {
		$a = $value;
		$b = $c_value;
		if (!(defined($c_value) && &{$code}())) {
			$c_group = [];
			push(@groups, $c_group);
		}
		$c_value = $value;
		push(@$c_group, $value);
	}
	return @groups;
}
sub kvlist_value(\@$) {
	my $r_kvlist = shift;
	my $key = shift;
	my %dict = @$r_kvlist;
	return $dict{$key};
}
sub kvlist_keys {
	my %dict = @_;
	return keys(%dict);
}
sub kvlist_values {
	my %dict = @_;
	return values(%dict);
}
sub kvlist_map(&@) {
	my $code = shift;
	no strict 'refs';
	use vars qw($a $b);
	my $caller = caller;
	my ($a, $b);
	local(*{"${caller}::a"}) = \$a;
	local(*{"${caller}::b"}) = \$b;

	my @list = ();
	for (my $i = 0; $i + 1 < scalar(@_); $i += 2) {
		$a = $_[$i];
		$b = $_[$i + 1];
		push(@list, &{$code}());
	}
	return @list;
}
sub kvlist_kmap(&@) {
	my $code = shift;
	my @list = ();
	for (my $i = 0; $i + 1 < scalar(@_); $i += 2) {
		$_ = $_[$i];
		push(@list, &{$code}() => $_[$i + 1]);
	}
	return @list;
}
sub kvlist_vmap(&@) {
	my $code = shift;
	my @list = ();
	for (my $i = 0; $i + 1 < scalar(@_); $i += 2) {
		$_ = $_[$i + 1];
		push(@list, $_[$i] => &{$code}());
	}
	return @list;
}
sub hash_sort {
	my %hash = @_;
	return map { $_ => $hash{$_} } (sort(keys(%hash)));
}
sub posmap_new_split_lines {
	my $text = shift;
	my @posmap = ();
	my $row = 0;
	my $position = 0;
	while ($text =~ m/([^\x0D\x0A]*)(\x0D\x0A|\x0D|\x0A|$)/osg) {
		my $line = $1;
		my $eol = $2;
		push(@posmap, [$position, $row]);
		$row++;
		$position += length($line) + length($eol);
	}
	return \@posmap;
}
sub posmap_get {
	my $posmap = shift;
	my $position = shift;
	my $info = List::Util::first { $_->[0] <= $position } (reverse(@$posmap));
	return unless defined($info);
	my $tag = $info->[1];
	my $extra = $position - $info->[0];
	return ($tag, $extra);
}
sub io_main {
	my $expr = shift;
	my $input = shift;
	my $flag_output = shift;
	my $output;
	open(FH, $expr) or return;
	binmode(FH);
	local $/;
	if (defined($input)) {
		print FH ($input);
	}
	if ($flag_output) {
		$output = <FH>;
	}
	close(FH);
	if ($flag_output) {
		return $output;
	}
	return 1;
}
sub io_readall {
	my $expr = shift;
	return io_main($expr, undef, 1);
}
sub io_writeall {
	my $expr = shift;
	my $data = shift;
	return io_main($expr, $data);
}
sub io_stream {
	my $expr = shift;
	my $data = shift;
	return io_main($expr, $data, 1);
}
sub file_readall {
	my $path = shift;
	open(FH, "<", $path) or return;
	binmode(FH);
	local $/;
	my $data = <FH>;
	close(FH);
	return $data;
}
sub file_writeall {
	my $path = shift;
	my $data = shift;
	my $dir = File::Basename::dirname($path);
	File::Path::mkpath($dir);
	open(FH, ">", $path) or return;
	binmode(FH);
	local $/;
	print FH ($data);
	close(FH);
	return 1;
}
}
{
package MacroText::EvalExpr;
sub eval_expr {
	return eval(shift);
}
}

{
package MacroText::Node;
# node =
#   | string : 1 of (str : string)
#   | macro : 10 of (reserved : boolean) * (name : string) * (args : nodelist list)
use constant {
	NODE_STRING => 1,
	NODE_MACRO => 10,
};
sub new {
	my $tag = shift;
	return bless([undef, $tag]);
}
sub string {
	my $node = shift;
	my $str = shift;
	return bless([NODE_STRING, $node->tag, $str]);
}
sub macro {
	my $node = shift;
	my $reserved = shift;
	my $name = shift;
	my $r_args = shift;
	return bless([NODE_MACRO, $node->tag, $reserved, $name, $r_args]);
}
sub tag {
	my $node = shift;
	return $node->[1];
}
sub is_string {
	my $node = shift;
	my $r_str = shift || \my $r;
	if ($node->[0] == NODE_STRING) {
		$$r_str = $node->[2];
		return 1;
	}
}
sub is_macro {
	my $node = shift;
	my $r_reserved = shift || \my $r1;
	my $r_name = shift || \my $r2;
	my $rr_args = shift || \my $r3;
	if ($node->[0] == NODE_MACRO) {
		($$r_reserved, $$r_name, $$rr_args) = ($node->[2], $node->[3], $node->[4]);
		return 1;
	}
}
sub enode {
	my $node = shift;
	MacroText::ENode::new($node->tag);
}
sub tostring {
	my $node = shift;
	if ($node->is_string(\my $str)) {
		return MacroText::escape($str);
	} elsif ($node->is_macro(\my $reserved, \my $name, \my $r_args)) {
		my $prefix = $name eq "" ? "" : $reserved ? "\\\@$name" : "\\$name";
		my @strs = map { $_->tostring() } (@$r_args);
		return join("", ($prefix, map { ("{", $_, "}") } (@strs)));
	}
}
}

{
package MacroText::NodeList;
# nodelist = (braced : boolean) * (nodes : [node])
sub new {
	my $tag = shift;
	my $braced = shift;
	my $nodes = shift;
	return bless([$tag, $braced, $nodes]);
}
sub tag {
	my $nodelist = shift;
	return $nodelist->[0];
}
sub braced {
	my $nodelist = shift;
	return $nodelist->[1];
}
sub nodes {
	my $nodelist = shift;
	return $nodelist->[2];
}
sub enode {
	my $nodelist = shift;
	MacroText::ENode::new($nodelist->tag);
}
sub tostring {
	my $nodelist = shift;
	my $nodes = $nodelist->nodes;
	my @strs = map { $_->tostring() } (@$nodes);
	return join("", @strs);
}
}

{
package MacroText::ENode;
# enode =
#   | none : 0
#   | nodelist : 1 of (enodes : [enode])
#   | string : 10 of (str : string)
#   | scalar : 11 of (value : scalar)
#   | list : 12 of (list : [enode])
#   | dict : 13 of (dict : string => enode)
use constant {
	ENODE_NONE => 0,
	ENODE_NODELIST => 1,
	ENODE_STRING => 10,
	ENODE_SCALAR => 11,
	ENODE_LIST => 12,
	ENODE_DICT => 13,
};
sub contract_strings {
	my @groups = Util::list_group { $a->is_string() && $b->is_string() } (@_);
	return map {
		scalar(@$_) > 1 && $_->[0]->is_string() ?
			$_->[0]->string(join("", map { $_->[2] } (@$_))) :
		@$_
	} (@groups);
}
sub escape_list {
	my $enode = shift;
	my $r_enodes = shift;
	my $space = 0;
	my $length = 0;
	my @enodes = map {
		my $enode = $_;
		$enode->is_string(\my $str);
		if ($str =~  m/\s/os) {
			$space = 1;
		}
		if ($str =~ m/"/os) {
			$str =~ s/"/`"/osg;
			$enode->string($str);
		}
		$length += length($str);
		$enode;
	} (@$r_enodes);
	return
		$length == 0 ? ($enode->string("\"\"")) :
		$space ? ($enode->string("\""), @enodes, $enode->string("\"")) :
		@enodes;
}
sub new {
	my $tag = shift;
	return bless([ENODE_NONE, $tag]);
}
sub none {
	my $enode = shift;
	return bless([ENODE_NONE, $enode->tag]);
}
sub nodelist {
	my $enode = shift;
	my $r_enodes = shift;
	return bless([ENODE_NODELIST, $enode->tag, $r_enodes]);
}
sub string {
	my $enode = shift;
	my $str = shift;
	return bless([ENODE_STRING, $enode->tag, $str]);
}
sub scalar {
	my $enode = shift;
	my $value = shift;
	return bless([ENODE_SCALAR, $enode->tag, $value]);
}
sub list {
	my $enode = shift;
	my $r_list = shift;
	return bless([ENODE_LIST, $enode->tag, $r_list]);
}
sub dict {
	my $enode = shift;
	my $r_dict = shift;
	return bless([ENODE_DICT, $enode->tag, $r_dict]);
}
sub object {
	my $enode = shift;
	my $obj = shift;
	if (ref($obj) eq "") {
		my $value = $obj;
		return $enode->scalar($value);
	} elsif (ref($obj) eq "SCALAR") {
		return $enode->object($$obj);
	} elsif (ref($obj) eq "ARRAY") {
		my $r_list = $obj;
		return $enode->list([map { $enode->object($_) } (@$r_list)]);
	} elsif (ref($obj) eq "HASH") {
		my $r_dict = $obj;
		return $enode->dict([Util::kvlist_vmap { $enode->object($_) } (%$r_dict)]);
	} else {
		return $enode->none();
	}
}
sub boolean {
	my $enode = shift;
	return $enode->scalar(@_);
}
sub integer {
	my $enode = shift;
	return $enode->scalar(@_);
}
sub number {
	my $enode = shift;
	return $enode->scalar(@_);
}
sub string_list {
	my $enode = shift;
	return $enode->list([map { $enode->string($_) } (@_)]);
}
sub tag {
	my $enode = shift;
	return $enode->[1];
}
sub is_none {
	my $enode = shift;
	if ($enode->[0] == ENODE_NONE) {
		return 1;
	}
}
sub is_nodelist {
	my $enode = shift;
	my $rr_enodes = shift || \my $r;
	if ($enode->[0] == ENODE_NODELIST) {
		$$rr_enodes = $enode->[2];
		return 1;
	}
}
sub is_string {
	my $enode = shift;
	my $r_str = shift || \my $r;
	if ($enode->[0] == ENODE_STRING) {
		$$r_str = $enode->[2];
		return 1;
	}
}
sub is_scalar {
	my $enode = shift;
	my $r_value = shift || \my $r;
	if ($enode->[0] == ENODE_SCALAR) {
		$$r_value = $enode->[2];
		return 1;
	}
}
sub is_list {
	my $enode = shift;
	my $rr_list = shift || \my $r;
	if ($enode->[0] == ENODE_LIST) {
		$$rr_list = $enode->[2];
		return 1;
	}
}
sub is_dict {
	my $enode = shift;
	my $rr_dict = shift || \my $r;
	if ($enode->[0] == ENODE_DICT) {
		$$rr_dict = $enode->[2];
		return 1;
	}
}
sub to_strings {
	my $enode = shift;
	if ($enode->is_none()) {
		return ();
	} elsif ($enode->is_nodelist(\my $r_enodes)) {
		return map { $_->to_strings() } (@$r_enodes);
	} elsif ($enode->is_string(\my $str)) {
		return $enode;
	} elsif ($enode->is_scalar(\my $value)) {
		my $str = defined($value) ? $value : "";
		return $enode->string($str);
	} elsif ($enode->is_list(\my $r_list)) {
		my @enodess = map { [$_->to_strings()] } (@$r_list);
		my @enodess2 = map { [escape_list($enode, $_)] } (@enodess);
		my $enode_space = $enode->string(" ");
		return ($enode_space, map { (@$_, $enode_space) } (@enodess2));
	} elsif ($enode->is_dict(\my $r_dict)) {
		my @enodess = Util::kvlist_map { [$enode->string($a)] => [$b->to_strings()] } (Util::hash_sort(@$r_dict));
		my @enodess2 = map { [escape_list($enode, $_)] } (@enodess);
		my $enode_space = $enode->string(" ");
		return ($enode_space, map { (@$_, $enode_space) } (@enodess2));
	}
	return ();
}
sub to_string {
	my $enode = shift;
	my @enodes = $enode->to_strings();
	my @strs = map { $_->[2] } (@enodes);
	return join("", @strs);
}
sub to_scalar {
	my $enode = shift;
	if ($enode->is_none()) {
		return undef;
	} elsif ($enode->is_nodelist(\my $r_enodes)) {
		my $value;
		if (defined(List::Util::first { $_->is_scalar(\$value) } (@$r_enodes))) {
			return $value;
		} else {
			return $enode->to_string();
		}
	} elsif ($enode->is_string(\my $str)) {
		return $str;
	} elsif ($enode->is_scalar(\my $value)) {
		return $value;
	} elsif ($enode->is_list(\my $r_list)) {
		return $enode->to_string();
	} elsif ($enode->is_dict(\my $r_dict)) {
		return $enode->to_string();
	}
}
sub to_list {
	my $enode = shift;
	if ($enode->is_none()) {
		return ();
	} elsif ($enode->is_nodelist(\my $r_enodes)) {
		my @enodes = contract_strings(@$r_enodes);
		return map { $_->to_list() } (@enodes);
	} elsif ($enode->is_string(\my $str)) {
		my @values = MacroText::split_list($str);
		return map { $enode->string($_) } (@values);
	} elsif ($enode->is_scalar(\my $value)) {
		return ($enode);
	} elsif ($enode->is_list(\my $r_list)) {
		return @$r_list;
	} elsif ($enode->is_dict(\my $r_dict)) {
		return Util::kvlist_map { $enode->string($a) => $b } (Util::hash_sort(@$r_dict));
	}
}
sub to_dict {
	my $enode = shift;
	if ($enode->is_dict(\my $r_dict)) {
		return @$r_dict;
	} else {
		my @list = $enode->to_list();
		return Util::kvlist_map { $a->to_string() => $b } (@list);
	}
}
sub to_object {
	my $enode = shift;
	if ($enode->is_none()) {
		return undef;
	} elsif ($enode->is_nodelist(\my $r_enodes)) {
		if (defined(List::Util::first { $_->is_dict() } (@$r_enodes))) {
			return { Util::kvlist_vmap { $_->to_object() } ($enode->to_dict()) };
		} elsif (defined(List::Util::first { $_->is_list() } (@$r_enodes))) {
			return [map { $_->to_object() } ($enode->to_list())];
		} else {
			return $enode->to_scalar();
		}
		# return [map { $_->to_object() } (@$r_enodes)];
	} elsif ($enode->is_string(\my $str)) {
		return $str;
	} elsif ($enode->is_scalar(\my $value)) {
		return $value;
	} elsif ($enode->is_list(\my $r_list)) {
		return [map { $_->to_object() } (@$r_list)];
	} elsif ($enode->is_dict(\my $r_dict)) {
		return { Util::kvlist_vmap { $_->to_object() } (@$r_dict) };
	}
}
sub to_boolean {
	my $enode = shift;
	return $enode->to_scalar();
}
sub to_integer {
	my $enode = shift;
	return int($enode->to_scalar());
}
sub to_number {
	my $enode = shift;
	return $enode->to_scalar();
}
sub to_string_list {
	my $enode = shift;
	return map { $_->to_string() } ($enode->to_list());
}
sub tostring {
	my $enode = shift;
	if ($enode->is_none()) {
		return "";
	} elsif ($enode->is_nodelist(\my $r_enodes)) {
		my @strs = map { $_->tostring() } (@$r_enodes);
		return join("", @strs);
	} elsif ($enode->is_string(\my $str)) {
		return MacroText::escape($str);
	} elsif ($enode->is_scalar(\my $value)) {
		return defined($value) ? $value : "";
	} elsif ($enode->is_list(\my $r_list)) {
		my @strs = map { $_->tostring() } (@$r_list);
		return join("", ("\\list", map { ("{", $_, "}") } (@strs)));
	} elsif ($enode->is_dict(\my $r_dict)) {
		my @dict_str = Util::kvlist_vmap { $_->tostring() } (Util::hash_sort(@$r_dict));
		my %strs = Util::kvlist_vmap { $_->tostring() } (@$r_dict);
		return join("", ("\\dict", Util::kvlist_map { ("{", $a, "}{", $b, "}") } (@dict_str)));
	}
}
}

{
package MacroText::Macro;
# macro =
#   | none : 100
#   | string : 101 of (str : string)
#   | scalar : 102 of (value : scalar)
#   | node : 103 of (node : enode)
#   | list : 104 of (list : [macro])
#   | dict : 105 of (dict : string => macro)
#   | func (function) : 111 of (higher_order : boolean) * (expr : nodelist) * (args : [nodelist])
#   | macro : 121 of (reserved : boolean) * (name : string) * (args : [nodelist])
use constant {
	MACRO_NONE => 100,
	MACRO_STRING => 101,
	MACRO_SCALAR => 102,
	MACRO_NODE => 103,
	MACRO_LIST => 104,
	MACRO_DICT => 105,
	MACRO_FUNC => 111,
	MACRO_MACRO => 121,
};
sub new {
	return bless([MACRO_NONE]);
}
sub none {
	my $macro = shift;
	return bless([MACRO_NONE]);
}
sub string {
	my $macro = shift;
	my $str = shift;
	return bless([MACRO_STRING, $str]);
}
sub scalar {
	my $macro = shift;
	my $value = shift;
	return bless([MACRO_SCALAR, $value]);
}
sub list {
	my $macro = shift;
	my $r_list = shift;
	return bless([MACRO_LIST, $r_list]);
}
sub dict {
	my $macro = shift;
	my $r_dict = shift;
	return bless([MACRO_DICT, $r_dict]);
}
sub node {
	my $macro = shift;
	my $node = shift;
	return bless([MACRO_NODE, $node]);
}
sub func {
	my $macro = shift;
	my $higher_order = shift;
	my $expr = shift;
	my $r_args = shift || [];
	return bless([MACRO_FUNC, $higher_order, $expr, $r_args]);
}
sub macro {
	my $macro = shift;
	my $reserved = shift;
	my $name = shift;
	my $r_args = shift || [];
	return bless([MACRO_MACRO, $reserved, $name, $r_args]);
}
sub node_list {
	my $macro = shift;
	my @list = map { $macro->node($_) } (@_);
	return $macro->list(\@list);
}
sub node_dict {
	my $macro = shift;
	my %dict = Util::kvlist_vmap { $macro->node($_) } (@_);
	return $macro->dict(\%dict);
}
sub object {
	my $macro = shift;
	my $obj = shift;
	if (ref($obj) eq "") {
		my $value = $obj;
		return $macro->scalar($value);
	} elsif (ref($obj) eq "SCALAR") {
		return $macro->object($$obj);
	} elsif (ref($obj) eq "ARRAY") {
		my @list = @$obj;
		return $macro->list([map { $macro->object($_) } (@list)]);
	} elsif (ref($obj) eq "HASH") {
		my %dict = %$obj;
		return $macro->dict({ Util::kvlist_vmap { $macro->object($_) } (%dict) });
	} else {
		return $macro->none();
	}
}
sub reset {
	my $macro = shift;
	my $macro2 = shift;
	@$macro = @$macro2;
}
sub is_none {
	my $macro = shift;
	if ($macro->[0] == MACRO_NONE) {
		return 1;
	}
}
sub is_string {
	my $macro = shift;
	my $r_str = shift || \my $r;
	if ($macro->[0] == MACRO_STRING) {
		$$r_str = $macro->[1];
		return 1;
	}
}
sub is_scalar {
	my $macro = shift;
	my $r_value = shift || \my $r;
	if ($macro->[0] == MACRO_SCALAR) {
		$$r_value = $macro->[1];
		return 1;
	}
}
sub is_list {
	my $macro = shift;
	my $rr_list = shift || \my $r;
	if ($macro->[0] == MACRO_LIST) {
		$$rr_list = $macro->[1];
		return 1;
	}
}
sub is_dict {
	my $macro = shift;
	my $rr_dict = shift || \my $r;
	if ($macro->[0] == MACRO_DICT) {
		$$rr_dict = $macro->[1];
		return 1;
	}
}
sub is_node {
	my $macro = shift;
	my $r_node = shift || \my $r;
	if ($macro->[0] == MACRO_NODE) {
		$$r_node = $macro->[1];
		return 1;
	}
}
sub is_func {
	my $macro = shift;
	my $r_higher_order = shift || \my $r1;
	my $r_expr = shift || \my $r2;
	my $rr_args = shift || \my $r3;
	if ($macro->[0] == MACRO_FUNC) {
		($$r_higher_order, $$r_expr, $$rr_args) = ($macro->[1], $macro->[2], $macro->[3]);
		return 1;
	}
}
sub is_macro {
	my $macro = shift;
	my $r_reserved = shift || \my $r1;
	my $r_name = shift || \my $r2;
	my $rr_args = shift || \my $r3;
	if ($macro->[0] == MACRO_MACRO) {
		($$r_reserved, $$r_name, $$rr_args) = ($macro->[1], $macro->[2], $macro->[3]);
		return 1;
	}
}
}

# macrotext : (rmacros, macros)
package MacroText;

use constant {
	MSG_TOKEN => 1,
	MSG_EXCESSVMS => 2,
	MSG_EXCESSVME => 3,
	MSG_LITTLEVME => 4,
	MSG_LITTLEME => 5,
	MSG_MACRO => 100,
	MSG_NOMACRO => 101,
	MSG_EXCESSARGS => 102,
	MSG_LITTLEARGS => 103,
	MSG_MESSAGE => 200,
};
my $messages_c = {
	MSG_TOKEN, "token %s",
	MSG_EXCESSVMS, "too many \\\@{",
	MSG_EXCESSVME, "too many \\\@}",
	MSG_LITTLEVME, "too few \\\@}",
	MSG_LITTLEME, "too few }",
	MSG_MACRO, "macro %s",
	MSG_NOMACRO, "undefined macro %s",
	MSG_EXCESSARGS, "too many arguments to macro %s, expected %s, have %s",
	MSG_LITTLEARGS, "too few arguments to macro %s, required %s, have %s",
	MSG_MESSAGE, "message %s",
};
use constant CODETYPE => {
	MSG_TOKEN, "Debug",
	MSG_EXCESSVMS, "Warning",
	MSG_EXCESSVME, "Warning",
	MSG_LITTLEVME, "Warning",
	MSG_LITTLEME, "Warning",
	MSG_MACRO, "Debug",
	MSG_NOMACRO, "Warning",
	MSG_EXCESSARGS, "Info",
	MSG_LITTLEARGS, "Warning",
	MSG_MESSAGE, "Message",
};

sub escape {
	my $str = shift;
	$str =~ s/(\\|\{|\})/\\$1/osg;
	return $str;
}
sub escape_list {
	my $value = shift;
	$value =~ s/"/`"/osg if $value =~ m/"/os;
	return $value eq "" ? "\"\"" : $value =~ m/\s/os ? "\"$value\"" : $value;
}
sub create_list {
	return join(" ", map { escape_list($_) } (@_));
}
sub split_list {
	my $str = shift;
	my @tokens = $str =~ m/\s+|`.|"|[^`"\s]+/osg;
	my @groups = ();
	my $c_group = [];
	my $c_mode = 0; # quot mode
	foreach my $token (@tokens) {
		if (!$c_mode && $token =~ m/^\s+$/osg) {
			push(@groups, $c_group);
			$c_group = [];
		} else {
			push(@$c_group, $token);
			if ($token eq '"') {
				$c_mode = !$c_mode;
			}
		}
	}
	push(@groups, $c_group);
	return map {
		my @tokens = @$_;
		scalar(@tokens) == 0 ? () :
		join("", map { $_ eq '"' ? () : $_ =~ m/^`(.*)$/os ? ($1) : $_ } (@tokens))
	} (@groups);
}

sub new {
	my $parameters = shift;
	my $rmacros = [];
	push(@$rmacros, get_rmacros_core());
	push(@$rmacros, get_rmacros_sideeffect());
	if ($parameters->{allow_system}) {
		push(@$rmacros, get_rmacros_system());
	}
	my $macros = {};
	my $messages = $messages_c;
	my $callback = $parameters->{callback};
	return bless([$rmacros, $macros, $messages, $callback]);
}
sub rmacros {
	my $mt = shift;
	return $mt->[0];
}
sub macros {
	my $mt = shift;
	return $mt->[1];
}
sub messages {
	my $mt = shift;
	return $mt->[2];
}
sub callback {
	my $mt = shift;
	return $mt->[3];
}
sub add_rmacros {
	my $mt = shift;
	push(@{$mt->rmacros}, @_);
}
sub get_rmacro {
	my $mt = shift;
	my $name = shift;
	my ($name2, $r_names, $pattern);
	return List::Util::first {
		(defined($name2 = $_->{name}) && $name2 eq $name) ||
		(defined($r_names = $_->{names}) && defined(List::Util::first { $_ eq $name } (@$r_names))) ||
		(defined($pattern = $_->{pattern}) && $name =~ $pattern)
	} (@{$mt->rmacros});
}
sub clear_macros {
	my $mt = shift;
	return bless([$mt->rmacros, {}, $mt->messages, $mt->callback]);
}
sub clone_macros {
	my $mt = shift;
	my $macros = $mt->macros;
	my %macros = %$macros;
	return bless([$mt->rmacros, \%macros, $mt->messages, $mt->callback]);
}
sub add_macro {
	my $mt = shift;
	my $name = shift;
	my $macro = shift;
	$mt->macros->{$name} = $macro;
}
sub add_macro_string {
	my $mt = shift;
	my $name = shift;
	my $macro = $mt->new_macro()->string(@_);
	$mt->add_macro($name, $macro);
}
sub add_macro_node {
	my $mt = shift;
	my $name = shift;
	my $macro = $mt->new_macro()->node(@_);
	$mt->add_macro($name, $macro);
}
sub add_macro_func {
	my $mt = shift;
	my $name = shift;
	my $macro = $mt->new_macro()->func(@_);
	$mt->add_macro($name, $macro);
}
sub add_macro_object {
	my $mt = shift;
	my $name = shift;
	my $macro = $mt->new_macro()->object(@_);
	$mt->add_macro($name, $macro);
}
sub get_macro {
	my $mt = shift;
	my $name = shift;
	return $mt->macros->{$name};
}
sub fire_callback {
	my $mt = shift;
	my $code = shift;
	my $tag = shift;
	my @args = @_;
	my $type = CODETYPE->{$code} || "";
	my $get_msg = sub { sprintf($mt->messages->{$code}, @args) };
	$mt->callback->($mt, $code, $type, $get_msg, $tag->[0], $tag->[1], @args)  if defined($mt->callback);
}

sub new_node {
	my $mt = shift;
	return MacroText::Node::new(@_);
}
sub new_nodelist {
	my $mt = shift;
	return MacroText::NodeList::new(@_);
}
sub new_macro {
	my $mt = shift;
	return MacroText::Macro::new(@_);
}
sub parse {
	my $mt = shift;
	my $text = shift;
	my $tag = shift;

	# lex
	my @tokens = $text =~ m/\\?(?:\x0D\x0A|\x0D|\x0A)|\\@\{|\\@\}|\\@?\w+(?:\s*\{)?|\{|\}(?:\s*\{)?|\\\W|[^\x0D\x0A\\\{\}]+/osg;

	my $pos = 0;
	my $callback = sub {
		$mt->fire_callback(shift, [$pos, $tag], @_);
	};
	# parse
	my $nodelist_root = $mt->new_nodelist([$pos, $tag], 0, []);
	my @c_argsnodess = ();
	my $c_mode = 0;
	foreach my $token (@tokens) {
		$callback->(MSG_TOKEN, $token);
		my $node = $mt->new_node([$pos, $tag]);
		my $r_c_nodes = $#c_argsnodess < 0 ? $nodelist_root->nodes : $c_argsnodess[$#c_argsnodess]->[1];
		if ($token =~ m/^(\\?)(\x0D\x0A|\x0D|\x0A)$/os) {
			if ($c_mode || $1 eq "") {
				push(@$r_c_nodes, $node->string($token));
			}
		} elsif (!$c_mode && $token eq "\\@\{") {
			# print "begin verbatim mode";
			$c_mode = 1;
		} elsif ($c_mode && $token eq "\\@\{") {
			$callback->(MSG_EXCESSVMS);
		} elsif (!$c_mode && $token eq "\\@\}") {
			$callback->(MSG_EXCESSVME);
		} elsif ($c_mode && $token eq "\\@\}") {
			# print "end verbatim mode";
			$c_mode = 0;
		} elsif (!$c_mode && $token =~ m/^\\(@?)(\w+)\s*(\{?)$/os) {
			my $reserved = $1 eq "@";
			my $name = $2;
			my @args = ();
			push(@$r_c_nodes, $node->macro($reserved, $name, \@args));
			if ($reserved) {
				# print "begin reserved macro $2";
			} else {
				# print "begin macro $2";
			}
			if ($3 eq "\{") {
				# print " and begin arg 0";
				my @nodes = ();
				my $pos2 = $pos + length($token) - length($3);
				my $arg = $mt->new_nodelist([$pos2, $tag], 1, \@nodes);
				push(@args, $arg);
				push(@c_argsnodess, [\@args, \@nodes]);
			}
		} elsif (!$c_mode && $token eq "\{") {
			# print "begin block macro and begin arg 0";
			my @args = ();
			push(@$r_c_nodes, $node->macro(1, "", \@args));
			my @nodes = ();
			my $arg = $mt->new_nodelist([$pos, $tag], 1, \@nodes);
			push(@args, $arg);
			push(@c_argsnodess, [\@args, \@nodes]);
		} elsif (!$c_mode && $token =~ m/^\}\s*(\{?)$/os) {
			if ($#c_argsnodess < 0) {
				# report_message(5, 'Too much }');
				if ($1 eq "\{") {
					# print "begin block macro and begin arg 0";
					my @args = ();
					push(@$r_c_nodes, $node->macro(1, "", \@args));
					my @nodes = ();
					my $pos2 = $pos + length($token) - length($1);
					my $arg = $mt->new_nodelist([$pos2, $tag], 1, \@nodes);
					push(@args, $arg);
					push(@c_argsnodess, [\@args, \@nodes]);
				}
			} else {
				# print "end arg";
				my $r_c_argsnodes = pop(@c_argsnodess);
				if ($1 eq "\{") {
					# print " and begin arg";
					my @nodes = ();
					my $pos2 = $pos + length($token) - length($1);
					my $arg = $mt->new_nodelist([$pos2, $tag], 1, \@nodes);
					my $r_c_args = $r_c_argsnodes->[0];
					push(@$r_c_args, $arg);
					push(@c_argsnodess, [$r_c_args, \@nodes]);
				} else {
					# print " and end macro";
				}
			}
		} elsif (!$c_mode && $token =~ m/^\\(\W)$/os) {
			# print "scalar $1";
			push(@$r_c_nodes, $node->string($1));
		} else {
			# print "scalar $token";
			push(@$r_c_nodes, $node->string($token));
		}
		$pos += length($token);
	}
	
	if ($c_mode) {
		$callback->(MSG_LITTLEVME);
	}
	if (scalar(@c_argsnodess) > 0) {
		$callback->(MSG_LITTLEME);
	}
	return $nodelist_root;
}
sub eval_iter {
	my $mt = shift;
	my $node = shift;
	my $enode = $node->enode;
	if ($node->is_string(\my $str)) {
		return $enode->string($str);
	} elsif ($node->is_macro(\my $reserved, \my $name, \my $r_args)) {
		return $mt->apply_macro($enode, $reserved, $name, $r_args);
	}
}
sub eval_nodes {
	my $mt = shift;
	my $nodelist = shift;
	if ($nodelist->braced) {
		$mt = $mt->clone_macros();
	}
	my $nodes = $nodelist->nodes;
	my @nodes = @$nodes;
	return map { $mt->eval_iter($_) } (@nodes);
}
sub eval {
	my $mt = shift;
	my $nodelist = shift;
	my @enodes = $mt->eval_nodes($nodelist);
	my $enode = $nodelist->enode;
	return $enode->nodelist(\@enodes);
}
sub eval_string {
	my $mt = shift;
	return $mt->eval(@_)->to_string();
}
sub eval_scalar {
	my $mt = shift;
	return $mt->eval(@_)->to_scalar();
}
sub eval_list {
	my $mt = shift;
	return $mt->eval(@_)->to_list();
}
sub eval_dict {
	my $mt = shift;
	return $mt->eval(@_)->to_dict();
}
sub eval_object {
	my $mt = shift;
	return $mt->eval(@_)->to_object();
}
sub eval_boolean {
	my $mt = shift;
	return $mt->eval(@_)->to_boolean();
}
sub eval_integer {
	my $mt = shift;
	return $mt->eval(@_)->to_integer();
}
sub eval_number {
	my $mt = shift;
	return $mt->eval(@_)->to_number();
}
sub eval_string_list {
	my $mt = shift;
	return $mt->eval(@_)->to_string_list();
}
sub eval_macro {
	my $mt = shift;
	my $enode = shift;
	my $macro = shift;
	if ($macro->is_none()) {
		return ();
	} elsif ($macro->is_string(\my $str)) {
		return $enode->string($str);
	} elsif ($macro->is_scalar(\my $value)) {
		return $enode->scalar($value);
	} elsif ($macro->is_list(\my $r_list)) {
		my @list_node = map { $mt->eval_macro($enode, $_) } (@$r_list);
		return $enode->list(\@list_node);
	} elsif ($macro->is_dict(\my $r_dict)) {
		my @dict_node = Util::kvlist_vmap { $mt->eval_macro($enode, $_) } (%$r_dict);
		return $enode->dict(\@dict_node);
	} elsif ($macro->is_node(\my $node)) {
		return $node;
	} elsif ($macro->is_func(\my $higher_order, \my $expr, \my $r_args)) {
		if ($higher_order) {
			# args will be evaluated in evaluating macro
			$mt = $mt->clone_macros();
			my @macros = map { $macro->func(1, $_, []) } (@$r_args);
			my $macro = $macro->list(\@macros);
			$mt->add_macro("_", $macro);
			for my $i (0 .. $#macros) {
				my $index = $i + 1;
				$mt->add_macro("$index", $macros[$i]);
			}
			return $mt->eval($expr);
		} else {
			my @nodes = map { $mt->eval($_) } (@$r_args);
			$mt = $mt->clone_macros();
			my @macros = map { $macro->node($_) } (@nodes);
			my $macro = $macro->list(\@macros);
			$mt->add_macro("_", $macro);
			for my $i (0 .. $#macros) {
				my $index = $i + 1;
				$mt->add_macro("$index", $macros[$i]);
			}
			return $mt->eval($expr);
		}
	} elsif ($macro->is_macro(\my $reserved, \my $name, \$r_args)) {
		return $mt->apply_macro($enode, $reserved, $name, $r_args);
	}
}
sub apply_macro {
	my $mt = shift;
	my $enode = shift;
	my $reserved = shift;
	my $name = shift;
	my $r_args = shift;
	my @args = @$r_args;
	# print $name;
	$mt->fire_callback(MSG_MACRO, $enode->tag, $name);
	if ($name eq "") {
		return map { $mt->eval_nodes($_) } (@args);
	} elsif (!$reserved && defined(my $macro = $mt->get_macro($name))) {
		my $macro = $mt->bind_macro_args($macro, \@args);
		unless (defined($macro)) {
			return ();
		}
		return $mt->eval_macro($enode, $macro);
	} elsif (defined(my $rmacro = $mt->get_rmacro($name))) {
		my $min_arg = $rmacro->{min_arg};
		if (defined($min_arg) && scalar(@args) < $min_arg) {
			$mt->fire_callback(MSG_LITTLEARGS, $enode->tag, $name, $min_arg, scalar(@args));
			return ();
		}
		my $max_arg = $rmacro->{max_arg};
		if (defined($max_arg) && scalar(@args) > $max_arg) {
			$mt->fire_callback(MSG_EXCESSARGS, $enode->tag, $name, $max_arg, scalar(@args));
		}
		$name =~ $rmacro->{pattern} if defined($rmacro->{pattern});
		return $rmacro->{code}->($mt, $enode, @args);
	}
	$mt->fire_callback(MSG_NOMACRO, $enode->tag, $name);
	return ();
}
sub new_macro_enodes {
	my $macro = shift;
	my $type = shift;
	my @enodes = @_;
	return
		$type eq "_string" || $type eq "s" ?
			map { $macro->string($_->to_string()) } (@enodes) :
		$type eq "_list" || $type eq "l" ?
			map { $macro->node_list($_->to_list()) } (@enodes) :
		$type eq "_dict" || $type eq "d" ?
			map { $macro->node_dict($_->to_dict()) } (@enodes) :
		$type eq "_node" || $type eq "n" ?
			map { $macro->node($_) } (@enodes) :
		map { $macro->node($_) } (@enodes);
}
sub new_macro_args {
	my $mt = shift;
	my $enode = shift;
	my $macro = shift;
	my $type = shift;
	my $arg_node = shift;
	my @args = @_;
	return
		$type eq "_string" || $type eq "s" ?
			$macro->string($mt->eval_string($arg_node)) :
		$type eq "_list" || $type eq "l" ?
			$macro->node_list($mt->eval_list($arg_node)) :
		$type eq "_dict" || $type eq "d" ?
			$macro->node_dict($mt->eval_dict($arg_node)) :
		$type eq "_node" || $type eq "n" || $type eq "" ?
			$macro->node($mt->eval($arg_node)) :
		$type eq "_func" || $type eq "f" ?
			$macro->func(0, $arg_node, \@args) :
		$type eq "_hfunc" || $type eq "h" ?
			$macro->func(1, $arg_node, \@args) :
		$type eq "_macro" || $type eq "m" ?
			$macro->macro(0, $mt->eval_string($arg_node), \@args) :
		$type eq "_rmacro" || $type eq "r" ?
			$macro->macro(1, $mt->eval_string($arg_node), \@args) :
		$type eq "_bind" || $type eq "b" ?
			$mt->get_macro_args($arg_node, @args) :
		$macro->node($mt->eval($arg_node));
}
sub bind_macro_args {
	my $mt = shift;
	my $macro = shift;
	my $r_args = shift;
	if ($macro->is_list(\my $r_list)) {
		my $arg = shift(@$r_args);
		return $macro unless defined($arg);
		my $index = $mt->eval_integer($arg);
		my $macro = $r_list->[$index];
		return unless defined($macro);
		return $mt->bind_macro_args($macro, $r_args);
	} elsif ($macro->is_dict(\my $r_dict)) {
		my $arg = shift(@$r_args);
		return $macro unless defined($arg);
		my $key = $mt->eval_string($arg);
		my $macro = $r_dict->{$key};
		return unless defined($macro);
		return $mt->bind_macro_args($macro, $r_args);
	} elsif ($macro->is_func(\my $higher_order, \my $expr, \my$r_args0)) {
		my @args = (@$r_args0, @$r_args);
		return $macro->func($higher_order, $expr, \@args);
	} elsif ($macro->is_macro(\my $reserved, \my $name, \$r_args0)) {
		my @args = (@$r_args0, @$r_args);
		return $macro->macro($reserved, $name, \@args);
	} else {
		return $macro;
	}
}
sub get_macro_args {
	my $mt = shift;
	my $arg_name = shift;
	my @args = @_;
	my $name = $mt->eval_string($arg_name);
	my $macro = $mt->macros->{$name};
	return unless defined($macro);
	return $mt->bind_macro_args($macro, \@args);
}
sub set_macro {
	my $mt = shift;
	my $name = shift;
	my $macro = shift;
	my $option = shift;
	if ($option) {
		my $macro1 = $mt->get_macro($name);
		unless (defined($macro1)) {
			$mt->add_macro($name, $macro);
		}
	} else {
		$mt->add_macro($name, $macro);
	}
}
sub put_macro {
	my $mt = shift;
	my $r_names = shift;
	my $macro = shift;
	my $option = shift;
	my @names = @$r_names;
	my $name0 = shift(@names);
	unless (defined($name0)) {
		# error
		return;
	}
	my $macro1 = $mt->get_macro($name0);
	unless (defined($macro1)) {
		$mt->add_macro($name0, $macro);
	}
	for my $name (@names) {
		unless (defined($macro1)) {
			# error
			return;
		}
		if ($macro1->is_list(\my $r_list)) {
			$macro1 = $r_list->[$name];
			unless (defined($macro1)) {
				$r_list->[$name] = $macro;
			}
		} elsif ($macro1->is_dict(\my $r_dict)) {
			$macro1 = $r_dict->{$name};
			unless (defined($macro1)) {
				$r_dict->{$name} = $macro;
			}
		} else {
			# error
			return;
		}
	}
	if ($option) {
	} else {
		if (defined($macro1)) {
			$macro1->reset($macro);
		}
	}
}
sub set_macros {
	my $mt = shift;
	my $command = shift;
	my $option = shift;
	for my $name_macro (@_) {
		my ($node_name, $macro) = @$name_macro;
		if ($command eq "set"){
			my $name = $node_name->to_string();
			$mt->set_macro($name, $macro, $option);
		} elsif ($command eq "put") {
			my $name = $node_name->to_string();
			$mt->put_macro([$name], $macro, $option);
		} elsif ($command eq "chain_put" || $command eq "cput") {
			my @nodes = $node_name->to_list();
			my @names = map { $_->to_string() } (@nodes);
			$mt->put_macro(\@names, $macro, $option);
		}
	}
}

my $rmacro_ignore = {
	name => "ignore",
	code => sub {
		my ($mt, $enode) = (shift, shift);
		foreach my $arg (@_) {
			$mt->eval($arg);
		}
		return;
	}
	};
my $rmacro_id = {
	name => "id",
	min_arg => 1,
	max_arg => 1,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		return $mt->eval_nodes($_[0]);
	}
	};
my $rmacro_say = {
	name => "say",
	code => sub {
		my ($mt, $enode) = (shift, shift);
		# my @strs = map { $mt->eval($_)->tostring() } (@_);
		my @strs = map { $mt->eval_string($_) } (@_);
		my $msg = join(" ", @strs);
		$mt->fire_callback(MSG_MESSAGE, $enode->tag, $msg);
		return;
	}
	};
my $rmacro_let = {
	pattern => qr/^(|option_|o)()(let)(_string|s|_list|l|_dict|d|_node|n||_func|f|_hfunc|h|_macro|m|_rmacro|r|_bind|b)$/os,
	min_arg => 3,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my ($option, $tuple, $command, $type) = ($1, $2, $3, $4);
		my ($arg_name, $arg_node, $arg_expr, @args) = @_;
		my $node_name = $mt->eval($arg_name);
		my $macro = new_macro_args($mt, $enode, $mt->new_macro(), $type, $arg_node, @args);
		return unless defined($macro);
		$mt = $mt->clone_macros();
		$mt->set_macros("set", $option, [$node_name, $macro]);
		return $mt->eval_nodes($arg_expr);
	}
	};
my $rmacro_tlet = {
	pattern => qr/^(|option_|o)(tuple_|t)(let)(_string|s|_list|l|_dict|d|_node|n|)$/os,
	min_arg => 3,
	max_arg => 3,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my ($option, $tuple, $command, $type) = ($1, $2, $3, $4);
		my ($arg_name, $arg_node, $arg_expr, @args) = @_;
		my @nodes_name = $mt->eval_list($arg_name);
		my @nodes_node = $mt->eval_list($arg_node);
		my @macros = new_macro_enodes($mt->new_macro(), $type, @nodes_node);
		my $count = List::Util::min(scalar(@nodes_name), scalar(@macros));
		my @name_macros = (Util::list_transpose(\@nodes_name, \@macros))[0 .. $count - 1];
		$mt = $mt->clone_macros();
		$mt->set_macros("set", $option, @name_macros);
		return $mt->eval_nodes($arg_expr);
	}
	};
my $rmacro_set = {
	pattern => qr/^(|option_|o)()(set|put|chain_put|cput)(_string|s|_list|l|_dict|d|_node|n||_func|f|_hfunc|h|_macro|m|_rmacro|r|_bind|b)$/os,
	min_arg => 2,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my ($option, $tuple, $command, $type) = ($1, $2, $3, $4);
		my ($arg_name, $arg_node, @args) = @_;
		my $node_name = $mt->eval($arg_name);
		my $macro = new_macro_args($mt, $enode, $mt->new_macro(), $type, $arg_node, @args);
		return unless defined($macro);
		$mt->set_macros($command, $option, [$node_name, $macro]);
		return;
	}
	};
my $rmacro_tset = {
	pattern => qr/^(|option_|o)(tuple_|t)(set|put|chain_put|cput)(_string|s|_list|l|_dict|d|_node|n|)$/os,
	min_arg => 2,
	max_arg => 2,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my ($option, $tuple, $command, $type) = ($1, $2, $3, $4);
		my ($arg_name, $arg_node, @args) = @_;
		my @nodes_name = $mt->eval_list($arg_name);
		my @nodes_node = $mt->eval_list($arg_node);
		my @macros = new_macro_enodes($mt->new_macro(), $type, @nodes_node);
		my $count = List::Util::min(scalar(@nodes_name), scalar(@macros));
		my @name_macros = (Util::list_transpose(\@nodes_name, \@macros))[0 .. $count - 1];
		$mt->set_macros($command, $option, @name_macros);
		return;
	}
	};
my $rmacro_get = {
	name => "get",
	min_arg => 1,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my $arg_name = shift;
		my @args = @_;
		my $macro = $mt->get_macro_args($arg_name, @_);
		unless (defined($macro)) {
			return;
		}
		return $mt->eval_macro($enode, $macro);
	}
	};
my $rmacro_def = {
	name => "def",
	min_arg => 1,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my $arg_name = shift;
		my @args = @_;
		my $macro = $mt->get_macro_args($arg_name, @_);
		my $result = defined($macro);
		return $enode->boolean($result);
	}
	};
my $rmacro_if = {
	name => "if",
	min_arg => 2,
	max_arg => 3,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my $condition = $mt->eval_boolean($_[0]);
		if ($condition) {
			return $mt->eval_nodes($_[1]);
		} else {
			return $mt->eval_nodes($_[2]) if defined($_[2]);
			return;
		}
	}
	};
my $rmacro_ifg = {
	name => "ifg",
	code => sub {
		my ($mt, $enode) = (shift, shift);
		for (my $i = 0; $i < scalar(@_); $i += 2) {
			if ($i + 1 == scalar(@_)) {
				return $mt->eval_nodes($_[$i]);
			}
			my $condition = $mt->eval_boolean($_[$i]);
			if ($condition) {
				return $mt->eval_nodes($_[$i + 1]);
			}
		}
		return;
	}
	};
my $rmacro_switch = {
	name => "switch",
	min_arg => 1,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my $value = $mt->eval_scalar(shift(@_));
		for (my $i = 0; $i < scalar(@_); $i += 2) {
			if ($i + 1 == scalar(@_)) {
				return $mt->eval_nodes($_[$i]);
			}
			my $value2 = $mt->eval_scalar($_[$i]);
			if ($value2 eq $value) {
				return $mt->eval_nodes($_[$i + 1]);
			}
		}
		return;
	}
	};
my $rmacro_loop = {
	name => "loop",
	min_arg => 2,
	max_arg => 2,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my $count = $mt->eval_integer($_[0]);
		for (my $i = 0; $i < $count; $i++) {
			$mt->eval($_[1]);
		}
		return;
	}
	};
my $rmacro_while = {
	name => "while",
	min_arg => 2,
	max_arg => 3,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		if (defined($_[2])) {
			my $count = $mt->eval_integer($_[2]);
			for (my $i = 0; $i < $count; $i++) {
				last unless $mt->eval_boolean($_[0]);
				$mt->eval($_[1]);
			}
		} else {
			while ($mt->eval_boolean($_[0])) {
				$mt->eval($_[1]);
			}
		}
		return;
	}
	};
my $rmacro_int = {
	name => "int",
	min_arg => 1,
	max_arg => 1,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my $value = $mt->eval_scalar($_[0]);
		my $result = int($value);
		return $enode->integer($result);
	}
	};
my $rmacro_add = {
	name => "add",
	min_arg => 1,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my @values = map { $mt->eval_number($_) } (@_);
		my $result = List::Util::sum(@values);
		return $enode->number($result);
	}
	};
my $rmacro_sub = {
	name => "sub",
	min_arg => 1,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my @values = map { $mt->eval_number($_) } (@_);
		my $result = List::Util::reduce { $a - $b } (@values);
		return $enode->number($result);
	}
	};
my $rmacro_mul = {
	name => "mul",
	min_arg => 1,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my @values = map { $mt->eval_number($_) } (@_);
		my $result = List::Util::reduce { $a * $b } (@values);
		return $enode->number($result);
	}
	};
my $rmacro_div = {
	name => "div",
	min_arg => 1,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my @values = map { $mt->eval_number($_) } (@_);
		my $result = List::Util::reduce { $a / $b } (@values);
		return $enode->number($result);
	}
	};
my $rmacro_mod = {
	name => "mod",
	min_arg => 1,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my @values = map { $mt->eval_number($_) } (@_);
		my $result = List::Util::reduce { $a % $b } (@values);
		return $enode->number($result);
	}
	};
my $rmacro_pow = {
	name => "pow",
	min_arg => 1,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my @values = map { $mt->eval_number($_) } (@_);
		my $result = List::Util::reduce { $a ** $b } (@values);
		return $enode->number($result);
	}
	};
my $rmacro_max = {
	name => "max",
	min_arg => 1,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my @values = map { $mt->eval_number($_) } (@_);
		my $result = List::Util::max(@values);
		return $enode->number($result);
	}
	};
my $rmacro_min = {
	name => "min",
	min_arg => 1,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my @values = map { $mt->eval_number($_) } (@_);
		my $result = List::Util::min(@values);
		return $enode->number($result);
	}
	};
my $rmacro_bnot = {
	names => ["bnot", "bit_not"],
	min_arg => 1,
	max_arg => 1,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my $value = $mt->eval_integer($_[0]);
		my $result = ~$value;
		return $enode->integer($result);
	}
	};
my $rmacro_bor = {
	names => ["bor", "bit_or"],
	min_arg => 1,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my @values = map { $mt->eval_integer($_) } (@_);
		my $result = List::Util::reduce { $a | $b } (@values);
		return $enode->integer($result);
	}
	};
my $rmacro_band = {
	names => ["band", "bit_and"],
	min_arg => 1,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my @values = map { $mt->eval_integer($_) } (@_);
		my $result = List::Util::reduce { $a & $b } (@values);
		return $enode->integer($result);
	}
	};
my $rmacro_bxor = {
	names => ["bxor", "bit_xor"],
	min_arg => 1,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my @values = map { $mt->eval_integer($_) } (@_);
		my $result = List::Util::reduce { $a ^ $b } (@values);
		return $enode->integer($result);
	}
	};
my $rmacro_lshift = {
	name => "lshift",
	min_arg => 1,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my @values = map { $mt->eval_integer($_) } (@_);
		my $result = List::Util::reduce { $a << $b } (@values);
		return $enode->integer($result);
	}
	};
my $rmacro_rshift = {
	name => "rshift",
	min_arg => 1,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my @values = map { $mt->eval_integer($_) } (@_);
		my $result = List::Util::reduce { $a >> $b } (@values);
		return $enode->integer($result);
	}
	};
my $rmacro_eq = {
	name => "eq",
	min_arg => 2,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my @values = map { $mt->eval_number($_) } (@_);
		my $result = Util::list_allnexts { $a == $b } (@values);
		return $enode->boolean($result);
	}
	};
my $rmacro_ne = {
	name => "ne",
	min_arg => 2,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my @values = map { $mt->eval_number($_) } (@_);
		my $result = Util::list_alltwo { $a != $b } (@values);
		return $enode->boolean($result);
	}
	};
my $rmacro_lt = {
	name => "lt",
	min_arg => 2,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my @values = map { $mt->eval_number($_) } (@_);
		my $result = Util::list_allnexts { $a < $b } (@values);
		return $enode->boolean($result);
	}
	};
my $rmacro_gt = {
	name => "gt",
	min_arg => 2,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my @values = map { $mt->eval_number($_) } (@_);
		my $result = Util::list_allnexts { $a > $b } (@values);
		return $enode->boolean($result);
	}
	};
my $rmacro_le = {
	name => "le",
	min_arg => 2,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my @values = map { $mt->eval_number($_) } (@_);
		my $result = Util::list_allnexts { $a <= $b } (@values);
		return $enode->boolean($result);
	}
	};
my $rmacro_ge = {
	name => "ge",
	min_arg => 2,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my @values = map { $mt->eval_number($_) } (@_);
		my $result = Util::list_allnexts { $a >= $b } (@values);
		return $enode->boolean($result);
	}
	};
my $rmacro_cmp = {
	name => "cmp",
	min_arg => 2,
	max_arg => 2,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my $value1 = $mt->eval_number($_[0]);
		my $value2 = $mt->eval_number($_[1]);
		my $result = $value1 <=> $value2;
		return $enode->boolean($result);
	}
	};
my $rmacro_not = {
	name => "not",
	min_arg => 1,
	max_arg => 1,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my $value = $mt->eval_boolean($_[0]);
		my $result = !$value;
		return $enode->boolean($result);
	}
	};
my $rmacro_or = {
	name => "or",
	min_arg => 1,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my $value;
		my $arg = List::Util::first { $value = $mt->eval_boolean($_); $value } (@_);
		my $result = defined($arg) ? $value : 0;
		return $enode->boolean($result);
	}
	};
my $rmacro_and = {
	name => "and",
	min_arg => 1,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my $arg = List::Util::first { !$mt->eval_boolean($_) } (@_);
		my $result = !defined($arg);
		return $enode->boolean($result);
	}
	};
my $rmacro_string = {
	name => "string",
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my @strs = map { $mt->eval_string($_) } (@_);
		my $result = join("", @strs);
		return $enode->string($result);
	}
	};
my $rmacro_srepeat = {
	names => ["srepeat", "str_repeat"],
	min_arg => 2,
	max_arg => 2,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my $str = $mt->eval_string($_[0]);
		my $count = $mt->eval_integer($_[1]);
		my $result = $str x $count;
		return $enode->string($result);
	}
	};
my $rmacro_length = {
	name => "length",
	min_arg => 1,
	max_arg => 1,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my $str = $mt->eval_string($_[0]);
		my $result = length($str);
		return $enode->integer($result);
	}
	};
my $rmacro_substr = {
	name => "substr",
	min_arg => 2,
	max_arg => 3,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my $str = $mt->eval_string($_[0]);
		my $index = $mt->eval_integer($_[1]);
		my $length = defined($_[2]) ? $mt->eval_integer($_[2]) : undef;
		my $result = substr($str, $index, $length);
		return $enode->string($result);
	}
	};
my $rmacro_index = {
	name => "index",
	min_arg => 2,
	max_arg => 3,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my $str = $mt->eval_string($_[0]);
		my $substr = $mt->eval_string($_[1]);
		my $position = defined($_[2]) ? $mt->eval_integer($_[2]) : undef;
		my $result = index($str, $substr, $position);
		return $enode->integer($result);
	}
	};
my $rmacro_rindex = {
	name => "rindex",
	min_arg => 2,
	max_arg => 3,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my $str = $mt->eval_string($_[0]);
		my $substr = $mt->eval_string($_[1]);
		my $position = defined($_[2]) ? $mt->eval_integer($_[2]) : undef;
		my $result = rindex($str, $substr, $position);
		return $enode->integer($result);
	}
	};
my $rmacro_sprintf = {
	name => "sprintf",
	min_arg => 1,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my $format = $mt->eval_string(shift(@_));
		# my @args = map { $mt->eval_scalar($_) } (@_);
		my @args = map { $mt->eval_string($_) } (@_);
		my $result = sprintf($format, @args);
		return $enode->string($result);
	}
	};
my $rmacro_seq = {
	names => ["seq", "str_eq"],
	min_arg => 2,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my @values = map { $mt->eval_string($_) } (@_);
		my $result = Util::list_allnexts { $a eq $b } (@values);
		return $enode->boolean($result);
	}
	};
my $rmacro_sne = {
	names => ["sne", "str_ne"],
	min_arg => 2,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my @values = map { $mt->eval_string($_) } (@_);
		my $result = Util::list_alltwo { $a ne $b } (@values);
		return $enode->boolean($result);
	}
	};
my $rmacro_slt = {
	names => ["slt", "str_lt"],
	min_arg => 2,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my @values = map { $mt->eval_string($_) } (@_);
		my $result = Util::list_allnexts { $a lt $b } (@values);
		return $enode->boolean($result);
	}
	};
my $rmacro_sgt = {
	names => ["sgt", "str_gt"],
	min_arg => 2,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my @values = map { $mt->eval_string($_) } (@_);
		my $result = Util::list_allnexts { $a gt $b } (@values);
		return $enode->boolean($result);
	}
	};
my $rmacro_sle = {
	names => ["sle", "str_le"],
	min_arg => 2,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my @values = map { $mt->eval_string($_) } (@_);
		my $result = Util::list_allnexts { $a le $b } (@values);
		return $enode->boolean($result);
	}
	};
my $rmacro_sge = {
	names => ["sge", "str_ge"],
	min_arg => 2,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my @values = map { $mt->eval_string($_) } (@_);
		my $result = Util::list_allnexts { $a ge $b } (@values);
		return $enode->boolean($result);
	}
	};
my $rmacro_scmp = {
	names => ["scmp", "str_cmp"],
	min_arg => 2,
	max_arg => 2,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my $value1 = $mt->eval_string($_[0]);
		my $value2 = $mt->eval_string($_[1]);
		my $result = $value1 cmp $value2;
		return $enode->boolean($result);
	}
	};
my $rmacro_split = {
	name => "split",
	min_arg => 2,
	max_arg => 2,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my $separator = $mt->eval_string($_[0]);
		my $str = $mt->eval_string($_[1]);
		my @words = split($separator, $str);
		return $enode->string_list(@words);
	}
	};
my $rmacro_join = {
	name => "join",
	min_arg => 2,
	max_arg => 2,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my $separator = $mt->eval_string($_[0]);
		my @strs = $mt->eval_string_list($_[1]);
		my $result = join($separator, @strs);
		return $enode->string($result);
	}
	};
my $rmacro_decode = {
	name => "decode",
	min_arg => 2,
	max_arg => 2,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my $encoding = $mt->eval_string($_[0]);
		my $data = $mt->eval_scalar($_[1]);
		my $result = Encode::decode($encoding, $data);
		return $enode->string($result);
	}
	};
my $rmacro_encode = {
	name => "encode",
	min_arg => 2,
	max_arg => 2,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my $encoding = $mt->eval_string($_[0]);
		my $str = $mt->eval_string($_[1]);
		my $result = Encode::encode($encoding, $str);
		return $enode->scalar($result);
	}
	};
my $rmacro_list = {
	name => "list",
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my @enodes = map { $mt->eval($_) } (@_);
		return $enode->list(\@enodes);
	}
	};
my $rmacro_lparse = {
	names => ["lparse", "list_parse"],
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my @list = map { $mt->eval_list($_) } (@_);
		return $enode->list(\@list);
	}
	};
my $rmacro_repeat = {
	name => "repeat",
	min_arg => 2,
	max_arg => 2,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my $value = $mt->eval($_[0]);
		my $count = $mt->eval_integer($_[1]);
		my @list = ($value) x $count;
		return $enode->list(\@list);
	}
	};
my $rmacro_range = {
	name => "range",
	min_arg => 2,
	max_arg => 2,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my $start = $mt->eval_integer($_[0]);
		my $end = $mt->eval_integer($_[1]);
		my @list = Util::integer_range($start, $end);
		return $enode->object(\@list);
	}
	};
my $rmacro_at = {
	name => "at",
	min_arg => 2,
	max_arg => 2,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my @list = $mt->eval_list($_[0]);
		my $index = $mt->eval_string($_[1]);
		return $list[$index];
	}
	};
my $rmacro_len = {
	name => "len",
	min_arg => 1,
	max_arg => 1,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my @list = $mt->eval_list($_[0]);
		my $result = scalar(@list);
		return $enode->integer($result);
	}
	};
my $rmacro_slice = {
	name => "slice",
	min_arg => 2,
	max_arg => 3,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my @list = $mt->eval_list($_[0]);
		my $start = $mt->eval_integer($_[1]);
		my $length = defined($_[2]) ? $mt->eval_integer($_[2]) : undef;
		my @list2 = splice(@list, $start, $length);
		return $enode->list(\@list2);
	}
	};
my $rmacro_splice = {
	name => "splice",
	min_arg => 2,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my @list = $mt->eval_list(shift(@_));
		my $start = $mt->eval_integer(shift(@_));
		my $length = defined($_[0]) ? $mt->eval_integer(shift(@_)) : undef;
		my @list2 = map { $mt->eval($_) } (@_);
		splice(@list, $start, $length, @list2);
		return $enode->list(\@list);
	}
	};
my $rmacro_reverse = {
	name => "reverse",
	min_arg => 1,
	max_arg => 1,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my @list = $mt->eval_list($_[0]);
		my @list2 = reverse(@list);
		return $enode->list(\@list2);
	}
	};
my $rmacro_sort = {
	name => "sort",
	min_arg => 1,
	max_arg => 2,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		if (scalar(@_) >= 2) {
			my @list = $mt->eval_list($_[1]);
			$mt = $mt->clone_macros();
			my @list2 = sort {
				$mt->add_macro_node("a", $a);
				$mt->add_macro_node("b", $b);
				$mt->eval_scalar($_[0])
			} (@list);
			return $enode->list(\@list2);
		} else {
			my @strs = $mt->eval_string_list($_[0]);
			my @list2 = sort(@strs);
			return $enode->string_list(@list2);
		}
	}
	};
my $rmacro_shift = {
	name => "shift",
	min_arg => 0,
	max_arg => 1,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my $name = defined($_[0]) ? $mt->eval_string($_[0]) : "_";
		my $macro = $mt->get_macro($name);
		if (defined($macro) && $macro->is_list(\my $r_macros)) {
			my $macro = shift(@$r_macros);
			return $mt->eval_macro($enode, $macro, []);
		}
		return;
	}
	};
my $rmacro_push = {
	name => "push",
	min_arg => 0,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my $name = defined($_[0]) ? $mt->eval_string(shift(@_)) : "_";
		my $macro = $mt->get_macro($name);
		if (defined($macro) && $macro->is_list(\my $r_macros)) {
			my @macros = map { $macro->node($mt->eval($_)) } (@_);
			push(@$r_macros, @macros);
		}
		return;
	}
	};
my $rmacro_lfor = {
	names => ["lfor", "list_for","lforeach", "list_foreach"],
	min_arg => 3,
	max_arg => 3,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my $name = $mt->eval_string($_[0]);
		my @list = $mt->eval_list($_[1]);
		$mt = $mt->clone_macros();
		for my $value (@list) {
			$mt->add_macro_node($name, $value);
			$mt->eval($_[2]);
		}
		return;
	}
	};
my $rmacro_map = {
	names => ["map", "list_map", "lmap"],
	min_arg => 2,
	max_arg => 2,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my @list = $mt->eval_list($_[1]);
		$mt = $mt->clone_macros();
		my @list2 = map {
			$mt->add_macro_node("_", $_);
			$mt->eval($_[0])
		} (@list);
		return $enode->list(\@list2);
	}
	};
my $rmacro_filter = {
	names => ["filter", "list_filter", "lfilter"],
	min_arg => 2,
	max_arg => 2,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my @list = $mt->eval_list($_[1]);
		$mt = $mt->clone_macros();
		my @list2 = grep {
			$mt->add_macro_node("_", $_);
			$mt->eval_boolean($_[0])
		} (@list);
		return $enode->list(\@list2);
	}
	};
my $rmacro_first = {
	name => "first",
	min_arg => 2,
	max_arg => 2,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my @list = $mt->eval_list($_[1]);
		$mt = $mt->clone_macros();
		return List::Util::first {
			$mt->add_macro_node("_", $_);
			$mt->eval_boolean($_[0])
		} (@list);
	}
	};
my $rmacro_all = {
	name => "all",
	min_arg => 2,
	max_arg => 2,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my @list = $mt->eval_list($_[1]);
		$mt = $mt->clone_macros();
		my $result = !defined(List::Util::first {
			$mt->add_macro_node("_", $_);
			!$mt->eval_boolean($_[0])
		} (@list));
		return $enode->boolean($result);
	}
	};
my $rmacro_fold = {
	name => "fold",
	min_arg => 2,
	max_arg => 2,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my @list = $mt->eval_list($_[1]);
		$mt = $mt->clone_macros();
		return List::Util::reduce {
			$mt->add_macro_node("a", $a);
			$mt->add_macro_node("b", $b);
			$mt->eval($_[0])
		} (@list);
	}
	};
my $rmacro_value = {
	name => "value",
	min_arg => 2,
	max_arg => 2,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my @kvlist = $mt->eval_dict($_[0]);
		my $key = $mt->eval_string($_[1]);
		return Util::kvlist_value(@kvlist, $key);
	}
	};
my $rmacro_keys = {
	name => "keys",
	min_arg => 1,
	max_arg => 1,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my @kvlist = $mt->eval_dict($_[0]);
		my @list = Util::kvlist_keys(@kvlist);
		return $enode->string_list(@list);
	}
	};
my $rmacro_values = {
	name => "values",
	min_arg => 1,
	max_arg => 1,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my @kvlist = $mt->eval_dict($_[0]);
		my @list = Util::kvlist_values(@kvlist);
		return $enode->list(\@list);
	}
	};
my $rmacro_kvmap = {
	names => ["kvmap", "kvlist_kvmap", "kvlist_keyvalue_map", "dmap", "dkvmap", "dict_kvmap", "dict_keyvalue_map"],
	min_arg => 2,
	max_arg => 2,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my @kvlist = $mt->eval_list($_[1]);
		my $arg_expr = $_[0];
		my @list = Util::kvlist_map {
			$mt = $mt->clone_macros();
			$mt->add_macro_node("a", $a);
			$mt->add_macro_node("b", $b);
			$mt->eval($arg_expr)
		} (@kvlist);
		return $enode->list(\@list);
	}
	};
my $rmacro_kmap = {
	names => ["kmap", "kvlist_kmap", "kvlist_key_map", "dkmap", "dict_kmap", "dict_key_map"],
	min_arg => 2,
	max_arg => 2,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my @kvlist = $mt->eval_list($_[1]);
		my $arg_expr = $_[0];
		my @kvlist2 = Util::kvlist_kmap {
			$mt = $mt->clone_macros();
			$mt->add_macro_node("_", $_);
			$mt->eval($arg_expr)
		} (@kvlist);
		return $enode->list(\@kvlist2);
	}
	};
my $rmacro_vmap = {
	names => ["vmap", "kvlist_vmap", "kvlist_value_map", "dvmap", "dict_vmap", "dict_value_map"],
	min_arg => 2,
	max_arg => 2,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my @kvlist = $mt->eval_list($_[1]);
		my $arg_expr = $_[0];
		my @kvlist2 = Util::kvlist_vmap {
			$mt = $mt->clone_macros();
			$mt->add_macro_node("_", $_);
			$mt->eval($arg_expr)
		} (@kvlist);
		return $enode->list(\@kvlist2);
	}
	};
my $rmacro_dict = {
	name => "dict",
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my @dict = Util::kvlist_map {
			my $key = $mt->eval_string($a);
			my $value = $mt->eval($b);
			($key => $value)
		} (@_);
		return $enode->dict(\@dict);
	}
	};
my $rmacro_dparse = {
	names => ["dparse", "dict_parse"],
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my @dict = map { $mt->eval_dict($_) } (@_);
		return $enode->dict(\@dict);
	}
	};
my $rmacro_dsort = {
	names => ["dsort", "dict_sort"],
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my @dict = map { $mt->eval_dict($_) } (@_);
		my @kvlist = Util::hash_sort(@dict);
		return $enode->dict(\@kvlist);
	}
	};
my $rmacro_dfor = {
	names => ["dfor", "dict_for","dforeach", "dict_foreach"],
	min_arg => 3,
	max_arg => 3,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my $name_key = $mt->eval_string($_[0]);
		my $name_value = $mt->eval_string($_[1]);
		my %dict = $mt->eval_dict($_[2]);
		$mt = $mt->clone_macros();
		while (my ($key, $value) = each(%dict)) {
			$mt->add_macro_string($name_key, $key);
			$mt->add_macro_node($name_value, $value);
			$mt->eval($_[3]);
		}
		return;
	}
	};
my $rmacro_input = {
	name => "input",
	min_arg => 1,
	max_arg => 1,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my $text = $mt->eval_string($_[0]);
		my $nodelist = $mt->parse($text, $enode->tag->[1]);
		return $mt->eval($nodelist);
	}
	};
my $rmacro_tostr = {
	name => "tostr",
	min_arg => 1,
	max_arg => 1,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my $str = $mt->eval($_[0])->tostring();
		return $enode->string($str);
	}
	};
my @rmacros_core = (
	$rmacro_ignore,
	$rmacro_id,
	$rmacro_let,
	$rmacro_tlet,
	$rmacro_get,
	$rmacro_def,
	$rmacro_if,
	$rmacro_ifg,
	$rmacro_switch,
	$rmacro_int,
	$rmacro_add,
	$rmacro_sub,
	$rmacro_mul,
	$rmacro_div,
	$rmacro_mod,
	$rmacro_pow,
	$rmacro_max,
	$rmacro_min,
	$rmacro_bnot,
	$rmacro_bor,
	$rmacro_band,
	$rmacro_bxor,
	$rmacro_lshift,
	$rmacro_rshift,
	$rmacro_eq,
	$rmacro_ne,
	$rmacro_lt,
	$rmacro_gt,
	$rmacro_le,
	$rmacro_ge,
	$rmacro_cmp,
	$rmacro_not,
	$rmacro_or,
	$rmacro_and,
	$rmacro_string,
	$rmacro_srepeat,
	$rmacro_length,
	$rmacro_substr,
	$rmacro_index,
	$rmacro_rindex,
	$rmacro_sprintf,
	$rmacro_seq,
	$rmacro_sne,
	$rmacro_slt,
	$rmacro_sgt,
	$rmacro_sle,
	$rmacro_sge,
	$rmacro_scmp,
	$rmacro_split,
	$rmacro_join,
	$rmacro_decode,
	$rmacro_encode,
	$rmacro_list,
	$rmacro_lparse,
	$rmacro_repeat,
	$rmacro_range,
	$rmacro_at,
	$rmacro_len,
	$rmacro_slice,
	$rmacro_splice,
	$rmacro_reverse,
	$rmacro_sort,
	$rmacro_map,
	$rmacro_filter,
	$rmacro_first,
	$rmacro_all,
	$rmacro_fold,
	$rmacro_value,
	$rmacro_keys,
	$rmacro_values,
	$rmacro_kvmap,
	$rmacro_kmap,
	$rmacro_vmap,
	$rmacro_dict,
	$rmacro_dparse,
	$rmacro_dsort,
	$rmacro_input,
	$rmacro_tostr,
	);
sub get_rmacros_core {
	return @rmacros_core;
}
my @rmacros_sideeffect = (
	$rmacro_say,
	$rmacro_set,
	$rmacro_tset,
	$rmacro_loop,
	$rmacro_while,
	$rmacro_shift,
	$rmacro_push,
	$rmacro_lfor,
	$rmacro_dfor,
	);
sub get_rmacros_sideeffect {
	return @rmacros_sideeffect;
}
my $rmacro_readall = {
	names => ["readall", "ireadall", "io_readall"],
	min_arg => 1,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my $expr = $mt->eval_string(shift(@_));
		my $data = Util::io_readall($expr);
		return $enode->scalar($data);
	}
	};
my $rmacro_writeall = {
	names => ["writeall", "iwriteall", "io_writeall"],
	min_arg => 2,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my $expr = $mt->eval_string(shift(@_));
		my $data = $mt->eval_scalar(shift(@_));
		my $result = Util::io_writeall($expr, $data);
		return $enode->scalar($result);
	}
	};
my $rmacro_stream = {
	names => ["stream", "istream", "io_stream"],
	min_arg => 2,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my $expr = $mt->eval_string(shift(@_));
		my $input = $mt->eval_scalar(shift(@_));
		my $output = Util::io_stream($expr, $input);
		return $enode->scalar($output);
	}
	};
my $rmacro_freadall = {
	names => ["freadall", "file_readall"],
	min_arg => 1,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my $path = $mt->eval_string(shift(@_));
		my $data = Util::file_readall($path);
		return $enode->scalar($data);
	}
	};
my $rmacro_fwriteall = {
	names => ["fwriteall", "file_writeall"],
	min_arg => 2,
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my $path = $mt->eval_string(shift(@_));
		my $data = $mt->eval_scalar(shift(@_));
		my $result = Util::file_writeall($path, $data);
		return $enode->scalar($result);
	}
	};
my $rmacro_stdout = {
	name => "stdout",
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my @strs = map { $mt->eval_string($_) } (@_);
		print STDOUT @strs;
		return;
	}
	};
my $rmacro_stderr = {
	name => "stderr",
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my @strs = map { $mt->eval_string($_) } (@_);
		print STDERR @strs;
		return;
	}
	};
my $rmacro_stdin = {
	name => "stdin",
	code => sub {
		my ($mt, $enode) = (shift, shift);
		print STDERR "> ";
		my $str = <STDIN>;
		return $enode->string($str);
	}
	};
my $rmacro_eval = {
	name => "eval",
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my $expr = $mt->eval_string(shift(@_));
		my @args = map { $mt->eval_object($_) } (@_);
		my $result = MacroText::EvalExpr::eval_expr($expr, @args);
		return $enode->object($result);
	}
	};
my $rmacro_system = {
	name => "system",
	code => sub {
		my ($mt, $enode) = (shift, shift);
		my @list = $mt->eval_string_list(@_);
		my $result = system(@list);
		return $enode->scalar($result);
	}
	};
my @rmacros_system = (
	$rmacro_readall,
	$rmacro_writeall,
	$rmacro_stream,
	$rmacro_freadall,
	$rmacro_fwriteall,
	$rmacro_stdout,
	$rmacro_stderr,
	$rmacro_stdin,
	$rmacro_eval,
	$rmacro_system,
	);
sub get_rmacros_system {
	return @rmacros_system;
}

# for debug
if ($0 eq __FILE__) {
	my $callback = sub {
		my $mt = shift;
		my $code = shift;
		my $type = shift;
		my $get_msg = shift;
		my $pos = shift;
		my $tag = shift;
		# return if $type eq "Debug";
		my $file = defined($tag->[0]) ? $tag->[0] : "-";
		$tag->[2] = Util::posmap_new_split_lines($tag->[1]) unless defined($tag->[2]);
		my $posmap = $tag->[2];
		my ($row, $col) = Util::posmap_get($posmap, $pos);
		($row, $col) = ($row + 1, $col + 1);
		my $msg = $get_msg->();
		print STDERR "$file:$row:$col:$type: $msg\n";
	};
	my $mt = MacroText::new({ allow_system => 1, callback => $callback });
	my $text = shift;
	print $text, "\n";
	my $node = $mt->parse($text, [undef, $text, undef]);
	print $node->tostring(), "\n";
	my $enode = $mt->eval($node);
	# print $node->tostring(), "\n";
	# $enode = $mt->eval($node);
	print $enode->tostring(), "\n";
}

1;

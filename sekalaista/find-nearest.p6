unit sub MAIN(Str $file where *.IO.f);

my Pair @lines = $file.IO.lines.map: -> $line { $line => $line.lc.subst(/<-[\w\ \-]>/, "", :g).words.Set };

for $*IN.lines() -> $_ is copy {
	s:g/<-[\w\ \-]>//;
	my $words = .lc.words.Set;
	.say for @lines.map(-> $p { ($p.value ∩ $words).elems => $p.key }).sort[*-10..*];
}


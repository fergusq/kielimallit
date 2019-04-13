my @sentence;
my $sentence-characters = SetHash.new;
my @sentences;
my %propnouns is BagHash;
for lines() {
	next if /^\#/ or /^$/;
	
	my ($id, $form, $lemma, $upos, $xpos, $feats, $head, $deprel, $deps, $misc) = .split("\t");
	if $id == 1 {
		my $sentence = @sentence.join(" ");
		$sentence ~~ s:g/\s+ <before <[.,!?]>>//;
		push @sentences, ($sentence, $sentence-characters.Set);
		@sentence = ();
		$sentence-characters = SetHash.new;
	}
	push @sentence, $form;

	if $upos eq "PROPN" {
		%propnouns{$lemma}++;
		$sentence-characters{$lemma}++;
	}
}

#.say for %propnouns.pairs.sort(-*.value);

my $characters = %propnouns.pick(5).Set;
say $characters;

my $i = 0;
for @sentences -> ($sentence, $sentence-characters) {
	#say $sentence-characters ⊖ $characters;
	next unless $sentence-characters ⊂ $characters;
	say $sentence;
	$i++;
	say "\n" if $i %% 5;
}

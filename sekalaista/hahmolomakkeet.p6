unit sub MAIN(Str $out-file);

my constant \tmp-file = "/tmp/hahmolomakkeet.md";

# Otteistaja

my $sampler = run "python3", "sample-model.py", "iso-lc", "lstm2-pyhis", :in, :out;
sub predict(Str $prompt, :$pred-only --> Str) {
	$sampler.in.put: $prompt;
	my $prediction = $sampler.out.get;
	$prediction ~~ s/^ "> "//;
	$prediction ~~ s:g/\x1b .*? m//;
	$prediction .= substr($prompt.chars+1);
	$prediction ~~ s/\. .*/./;
	note "$prompt --> $prediction";
	$pred-only ?? $prediction !! "$prompt$prediction"
}

# Muuttujapuu

class Var {
	has Str $.name;
	has Var @.deps;
	has Var @.dependants = [];
	has &.source;
	has Str $.value is rw = "";

	submethod TWEAK {
		for @!deps {
			.dependants.push: self;
		}
	}

	method update {
		$.value = &!source();
		.update for @.dependants;
	}
}

my Var %vars;

sub var(Str $name, &source, *@deps --> Var) {
	%vars{$name} = Var.new(name => $name, source => &source, deps => @deps.map: {%vars{$_}})
}

sub get-val(Str $var --> Str) {
	%vars{$var}.value
}

# Varsinainen ohjelma

my Str @characters = <noora eero filip>;
my Str @relations = <rakastat ihailet vihaat kadehdit>;

# Muuttujat

for @characters -> $char {
	my Var $v = var $char, {predict "$char asui lapsena"};
	$v.update;
}
for @characters -> $char {
	note "Käsitellään hahmoa $char...";
	for @characters -> $friend {
		next if $char eq $friend;

		my Var $v = var "$char -> $friend", {
			my Str $desc = get-val $friend;
			my Str $prompt-proper = "@relations.pick() häntä, sillä";
			my Str $reason = predict "$desc $prompt-proper";
			"$desc **$reason.substr($desc.chars+1)**"
		}, $friend;
		$v.update;
	}
}

# Ulostulo

sub make-pdf() {
	note "Kirjoitetaan Markdown-tiedostoa...";

	my $fh = open tmp-file, :w;

	$fh.put: "---\ntitle: Hahmolomakkeet\nlang: fi-FI\n...";

	for @characters -> $char {
		$fh.put: "\n---\n\n# $char";
		$fh.put: get-val $char;
		for @characters -> $friend {
			next if $char eq $friend;
			$fh.put: "\n## $friend";
			$fh.put: get-val "$char -> $friend";
		}
	}

	$fh.close;

	note "Luodaan pdf...";
	run "pandoc", "-f", "markdown", "-t", "ms", "-o", $out-file, tmp-file;
}

loop {
	make-pdf;
	my @vars = %vars.keys.sort;
	say "\t{.key + 1}. {.value}" for @vars.pairs;
	my $input = prompt "Laske uudelleen [1-@vars.elems()] » ";
	last without $input;
	with $input.Int {
		%vars{@vars[$_ - 1]}.update;
		make-pdf;
	} else {
		last;
	}
}

$sampler.in.close;
$sampler.out.close;

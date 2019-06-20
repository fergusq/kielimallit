unit sub MAIN(Str $out-file);

my constant \tmp-file = "/tmp/hahmolomakkeet.md";

# Otteistaja

enum SamplerType <LstmSampler TxlSampler>;

my $lstm-sampler = run "python3", "sample-model.py", "iso-lc", "lstm2-pyhis", :in, :out;
my $txl-sampler = run "python3", "sample-model.py", "iso-lc", "txl1-pyhis", "--transformerxl", :in, :out;

my %samplers = LstmSampler => $lstm-sampler, TxlSampler => $txl-sampler;

sub predict(Str $prompt, :$pred-only, SamplerType :$sampler = LstmSampler --> Str) {
	my $sampler-prog = %samplers{$sampler};
	$sampler-prog.in.put: $prompt;
	my $prediction = $sampler-prog.out.get;
	$prediction ~~ s/^ "> "//;
	$prediction ~~ s:g/\x1b .*? m//;
	$prediction .= substr($prompt.chars+1);
	$prediction ~~ s/\. .*/./;
	note "$sampler: $prompt --> $prediction";
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
	%vars{$name} = Var.new(:$name, :&source, deps => @deps.map: {%vars{$_}})
}

sub get-val(Str $var --> Str) {
	%vars{$var}.value
}

# Varsinainen ohjelma

my Str %char-parts = <noora nooraa eero eeroa filip filipiä vladimir vladimiria anna annaa katariina katariinaa>;
my Str @relations = <rakastat ihailet vihaat kadehdit>;

my Str @characters = %char-parts.keys.pick: *;

sub friends(Str $char) {
	my $index = @characters.antipairs.Hash{$char};
	my $offset = @characters.elems ÷ 2;
	@characters[($index-1)%*], @characters[($index+1)%*], @characters[($index+$offset)%*]
}

# Muuttujat

my Var $intro-v = var "intro", {predict "@characters[0..^*].join(Q/, /) ja @characters[*-1] ovat", sampler => TxlSampler};
$intro-v.update;

for @characters -> $char {
	my Var $v = var $char, {predict "$char asui lapsena"};
	$v.update;
}
for @characters -> $char {
	note "Käsitellään %char-parts{$char}...";
	for friends($char) -> $friend {
		next if $char eq $friend;

		for ^3 {
			my Var $v = var "$char -> $friend $_", {
				my Str $desc = get-val $friend;
				my Str $prompt-proper = "@relations.pick() %char-parts{$friend}, sillä";
				my Str $reason = predict "$desc $prompt-proper", sampler => TxlSampler;
				"$desc **$reason.substr($desc.chars+1)**"
			}, $friend;
			$v.update;
		}
	}
}

# Ulostulo

sub make-pdf() {
	note "Kirjoitetaan Markdown-tiedostoa...";

	my $fh = open tmp-file, :w;

	$fh.put: "---\ntitle: Hahmolomakkeet\nlang: fi-FI\n...\n\n{get-val Q/intro/}\n";
	for @characters -> $char {
		$fh.put: "\n---\n\n# $char";
		$fh.put: get-val $char;
		for friends($char) -> $friend {
			next if $char eq $friend;
			$fh.put: "\n## Tuttu: $friend";
			for ^3 {
				$fh.put: "\n### Vaihtoehto $_";
				$fh.put: get-val "$char -> $friend $_";
			}
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
	with $input and $input.Int {
		%vars{@vars[$_ - 1]}.update;
	} else {
		last;
	}
}

for %samplers.values -> $sampler {
	$sampler.in.close;
	$sampler.out.close;
}

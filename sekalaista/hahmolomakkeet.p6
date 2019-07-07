unit sub MAIN(Str $out-file, Bool :$impro);

my constant \tmp-file = "/tmp/hahmolomakkeet.md";

# Otteistaja

enum SamplerType <LstmSampler TxlSampler>;

my $lstm-sampler = run "python3", "sample-model.py", "iso-lc", "lstm2-pyhis", :in, :out;
my $txl-sampler = run "python3", "sample-model.py", "iso-lc", "txl1-pyhis", "--transformerxl", :in, :out;

my %samplers = LstmSampler => $lstm-sampler, TxlSampler => $txl-sampler;

for %samplers.values {
	.in.put: "/repe 0.7";
}

sub predict(Str $prompt, Bool :$pred-only, Bool :$no-log, SamplerType :$sampler = LstmSampler --> Str) {
	my $sampler-prog = %samplers{$sampler};
	$sampler-prog.in.put: $prompt;
	my $prediction = $sampler-prog.out.get;
	$prediction ~~ s/^ "> "+//;
	$prediction ~~ s:g/\x1b .*? m//;
	$prediction .= substr($prompt.chars+1);
	$prediction ~~ s/\. .*/./;
	note "$sampler: $prompt --> $prediction" unless $no-log;
	$pred-only ?? $prediction !! "$prompt$prediction"
}

sub context-predict(Str $context, Str $prompt, Bool :$no-log, SamplerType :$sampler = TxlSampler --> Str) {
	$prompt ~ predict "$context $prompt", :pred-only, :$sampler, :$no-log
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
my Str @names = <pariisi europ helsin pyhävuor suom venäjä ranska annan annaa annal annas>;

sub var(Str $name, &source, *@deps --> Var) {
	%vars{$name} = Var.new(:$name, :&source, deps => @deps.map: {%vars{$_}})
}

sub multi-var(Int $n, Str $name, &source, *@deps) {
	for ^$n {
		my Var $v = var "$name $_", &source, |@deps;
		$v.update;
	}
}

sub get-val(Str $var --> Str) {
	without %vars{$var} {
		die "Tuntematon muuttuja '$var'";
	}
	%vars{$var}.value
}

sub capitalize(Str $text --> Str) {
	$text.split(/<[.?!]>" "*/, :v)».tc.join("").wordcase(:where(-> $word {$word eq "anna" or [or] @names.map: {$word.starts-with: $_}}))
}

# Varsinainen ohjelma

if ($impro) {
	while True {
		my $prompt = prompt "Kehote> ";
		for ^3 {
			my $text = capitalize context-predict "xxbos", $prompt, :no-log;
			say "Vaihtoehto {$_+1}. $text";
		}
	}
}

my Str %char-parts = <noora nooraa eero eeroa filip filipiä vladimir vladimiria anna annaa katariina katariinaa>;
my Str @relations = <rakastat ihailet vihaat kadehdit>;

my Str @characters = %char-parts.keys.pick: *;
@names.append: @characters.grep: * ne "anna";

my constant %friends6 = 0 => (1, 2, 3), 1 => (0, 2, 4), 2 => (0, 1, 5), 3 => (4, 5, 0), 4 => (3, 5, 1), 5 => (3, 4, 2);

sub friends(Str $char) {
	my $index = @characters.antipairs.Hash{$char};
	return @characters[%friends6{$index}<>] if @characters.elems == 6;
	my $offset = @characters.elems ÷ 2;
	@characters[($index-1)%*], @characters[($index+1)%*], @characters[($index+$offset)%*]
}

# Muuttujat

multi-var 3, "intro", {predict "@characters[0..^*].join(Q/, /) ja @characters[*-1] ovat", sampler => TxlSampler};

my @char-vars =
	"lapsena", "jo silloin, kun olit lapsi,",
	"vuodet kuluvat", "vuodet kuluvat ja",
	"viime aikoina", "viime aikoina olet",
	"tulevaisuudessa", "tukevaisuudessa tahtoisit vain",
	"kuukausi", "muutama kuukausi sitten",
	"viikko", "joitakin viikkoja sitten";

for @characters -> $char {
	my Var $v = var $char, {predict "$char on tunnettu siitä,", sampler => TxlSampler};
	$v.update;
	#multi-var 3, "$char aikuisena", {predict "olet $char. aikuisena olet viime aikoina", sampler => TxlSampler};
	for @char-vars -> $var-name, $prompt {
		multi-var 3, "$char $var-name", {context-predict "olet $char.", $prompt};
	}
}
for @characters -> $char {
	note "Käsitellään %char-parts{$char}...";
	for friends($char) -> $friend {
		next if $char eq $friend;

		multi-var 3, "$char -> $friend", {
			my Str $desc = get-val $friend;
			my Str $prompt-proper = "@relations.pick() %char-parts{$friend}, sillä";
			my Str $reason = predict "$desc $prompt-proper", sampler => TxlSampler;
			$reason.substr: $desc.chars+1
		}, $friend, $char;
	}
}

# Ulostulo

sub get-choices(Int $n, Str $var --> Str) {
	(^$n).map({"- _Vaihtoehto {$_+1}._ " ~ capitalize get-val "$var $_"}).join: "\n"
}

sub make-pdf() {
	note "Kirjoitetaan Markdown-tiedostoa...";

	my $fh = open tmp-file, :w;

	$fh.put: "---\ntitle: Hahmolomakkeet\nlang: fi-FI\n...\n";
	$fh.put: "\n# Alustus\n" ~ get-choices 3, "intro";
	for @characters -> $char {
		$fh.put: "\n```\{=ms}\n.bp\n```";
		$fh.put: "\n# $char.tc(): tausta";
		$fh.put: capitalize get-val $char;
		$fh.put: "\n## Lapsuus\n" ~ get-choices 3, "$char lapsena";
		$fh.put: "\n## Vuodet kuluvat\n" ~ get-choices 3, "$char vuodet kuluvat";
		$fh.put: "\n## Viime aikoina\n" ~ get-choices 3, "$char viime aikoina";
		$fh.put: "\n## Tulevaisuudessa\n" ~ get-choices 3, "$char tulevaisuudessa";
		$fh.put: "\n```\{=ms}\n.bp\n```";
		$fh.put: "\n# $char.tc(): tutut";
		for friends($char) -> $friend {
			next if $char eq $friend;
			$fh.put: "\n## Tuttu: $friend.tc()";
			$fh.put: capitalize get-val $friend;
			$fh.put: "\n" ~ get-choices 3, "$char -> $friend";
		}	
		$fh.put: "\n```\{=ms}\n.bp\n```";
		$fh.put: "\n# $char.tc(): muistot";
		$fh.put: "\n## Muisto 1\n" ~ get-choices 3, "$char kuukausi";
		$fh.put: "\n## Muisto 2\n" ~ get-choices 3, "$char viikko";
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

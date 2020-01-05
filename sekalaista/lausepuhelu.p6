unit sub MAIN(Str $sp-model = "iso-lc", Str $model = "txl1");

my $sampler = run "python3", "predict.py", $sp-model, "txl,1,$model", :in, :out;
$sampler.in.put: "/end ▁br";
sub predict(Str $prompt is copy, :$with-prompt --> Str) {
	$prompt .= trim-leading;
	$sampler.in.put: $prompt;
	$_ = $sampler.out.get;
	s/^ "> "+//;
	s:g/\x1b .*? m//;
	$_ .= trim;
	#note "$prompt --> $_";
	$with-prompt ?? "$prompt$_" !! $_
}

my Str $conversation = "xxbos";

loop {
	my $input = prompt ">> ";
	last without $input;
	$input .= trim;
	$input .= lc if $sp-model ~~ /"-lc"/;

	$conversation ~= qq[ $input];

	for ^2 {
		my $output = predict($conversation);
		if $output ~~ /xxbos/ {
			$output ~~ s/ xxbos .* //;
			$output.say;
			"\n~ Loppu ~".say;
			$conversation = "xxbos";
			last;
		}
		$output.say;

		$conversation ~= qq[ $output br br];
		"".say;
	}
}

say $conversation;

$sampler.in.close;
$sampler.out.close;

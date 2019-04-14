unit sub MAIN(Str $question-file where *.IO.f);

my Str %questions;
for $question-file.IO.lines {
	my ($idx, $question) = .split("\t");
	%questions{$idx} = $question;
}

my Array %answers;
for $*IN.lines() {
	if /\w* "kysymys " (\d+) ", vastaus " (<[1..5]>) ", perustelu: " (.+)/ {
		%answers{$0}.push: ($1-1, $2.trim);
	}
}

say q:to/END/;
---
title: Otteita vaalikonevastauksia jäljittelevästä pupusta
lang: fi-FI
...
END

for %answers.kv -> $q-id, @answers {
	with %questions{$q-id} {
		say "## $_";
	} else {
		say "## Kysymys $q-id";
	}

	say "|1|2|3|4|5|Perustelut|";
	say "|-|-|-|-|-|----------|";

	for @answers {
		my @ans = "0" xx 5;
		@ans[$_[0]] = "X";
		say "|@ans.join("|")|$_[1]|";
	}
}

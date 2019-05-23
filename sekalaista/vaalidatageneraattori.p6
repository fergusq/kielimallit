#!/usr/bin/env perl6

use v6;

use HTTP::Easy::PSGI;
use Web::Request;

unit sub MAIN(Bool :$txl, Bool :$show-origin);

my $repo-path = %*ENV<LSTM_PATH> // ".";

# Kysymykset id-kysymys-pareina
my %questions = "$repo-path/data/vaalidata-kysymykset.tsv".IO.lines.flatmap: *.split("\t");

my @original-answers;
my Array %origin;

if $show-origin {
	# Alkuperäiset vastaukset
	note "Loading vaalidata.csv...";
	$_ = "$repo-path/data/vaalidata.csv".IO.slurp.lc;
	note "Making substitutions...";
	s:g/<-[\w\ \n]>//; note "1 done";
	s:g/^^\"|\"$$//; note "2 done";
	s:g/\"\"/"/; note "3 done";
	@original-answers = .lines; note "lines done";

	# Tehdään alkuperäisistä vastauksista indeksi
	note "Making index...";
	for @original-answers.kv -> $i, $ans {
		$*ERR.print: "\r$i / @original-answers.elems()" if $i %% 100;
		for $ans.words.rotor(2 => -1).map: *.join(" ") -> $word-pair {
			%origin{$word-pair}.push: $ans;
		}
	}
	note "\rindex done";
}

my $http = HTTP::Easy::PSGI.new(:port(8080));

my $form = qq:to"EOT";
<form>
	Valitse kysymys:
	<select name="kysymys">
		%questions.sort(*.key.Int).map({qq[<option value={$_.key}>{$_.value}</option>]}).join(qq[\n])
	</select>
	<input type="submit">
</form>
<!-- : -->
EOT

sub response(Int $code, Str $content) {
	return [ $code, [ "Content-Type" => "text/html;charset=UTF-8" ], [ qq:to"EOT" ] ];
	<html>
		<head>
			<style>
			body \{font-family: Helvetica, sans-serif;}
			h2 \{text-align: center;font-size: 1.2rem;}
			th, td \{width: 6em;text-align: center;}
			.sel, .oth \{font-size: 3rem;font-family: serif;}
			.desc, .text \{width: 100%;}
			.desc \{padding: 1em;text-align: center;font-weight: bold;}
			.text \{border: 1px solid gray;border-radius: 1em;padding:1em;}
			table \{margin-left: auto; margin-right: auto;}
			</style>
		</head>
		<body>
			<h1>Vaalikonevastausgeneraattori</h1>
			$form
			<hr/>
			$content
		</body>
	</html>
	EOT
}

my $sampler = $txl
	?? run "python3", "sample-model.py", "iso-lc", "txl1-vaalidata", "--transformerxl", :in, :out
	!! run "python3", "sample-model.py", "iso-lc", "lstm2-vaalidata", :in, :out;

my $sep = $txl ?? "/" !! "xxbos";

my %colors = 1 => "red", 2 => "orange", 3 => "black", 4 => "lightgreen", 5 => "darkgreen";

# entry point
my $app = sub (%env) {
	my $req = Web::Request.new(%env);

	with $req.get("kysymys") -> $q-id {
		return response(400, "400") unless $q-id ~~ /^\d+$/;
		$sampler.in.put: "$sep kysymys $q-id";
		my $answers = $sampler.out.get;
		$answers ~~ s:g/\x1b .*? m//;
		if $answers ~~ /$sep " "? "kysymys " $q-id ", vastaus " (<[1..5]>) ", perustelu: " (.*?) ($sep | $)/ {
			my ($num, $text) = $0, $1;
			
			# Tehdään numeerisen vastauksen näyttämiseen palluroita
			my @a = "<span class=oth>○</span>" xx 5;
			@a[$num - 1] = "<span class=sel style=\"color:%colors{$num}\">●</span>";
			
			# Etsitään alkuperäisistä vastauksista lähellä olevia fraaseja
			my @inspirations;
			
			if $show-origin {
				for $text.lc.subst(/<-[\w\ ]>/, "").words.rotor(2 => -1).map(*.join: " ") -> $word-pair {
					next without %origin{$word-pair};
					my @matches = %origin{$word-pair}<>;
					@inspirations.append: "<li>" ~ @matches.pick.subst($word-pair, "<b> $word-pair </b>") ~ "</li>" if @matches;
					CATCH { .note; .resume; }
				}
			}

			return response(200, qq:to"EOT");
				<h2> %questions{$q-id} </h2>
				<table>
				<tr><th>Täysin eri mieltä</th><th></th><th>En osaa sanoa</th><th></th><th>Täysin samaa mieltä</th></tr>
				<tr> @a.map({qq[<td> $_ </td>]}).join() </tr>
				<tr><td class=desc colspan=5>Perustelut:</td></tr>
				<tr><td class=text colspan=5> $text </td></tr>
				</table>
				<ul>
					@inspirations.join(qq[\n])
				</ul>
				EOT
		} else {
			note "No answer found: $answers";
			return response(500, "500 Internal Server Error");
		}
	} else {
		return response(200, "Tervetuloa vaalikonevastausgeneraattoriin!");
	}
}

$http.handle($app);


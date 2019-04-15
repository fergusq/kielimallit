#!/usr/bin/env perl6

use v6;

use HTTP::Easy::PSGI;
use Web::Request;

my $repo-path = %*ENV<LSTM_PATH>;
my %questions = "$repo-path/data/vaalidata-kysymykset.tsv".IO.lines.flatmap: *.split("\t");

my $http = HTTP::Easy::PSGI.new(:port(8080));

my $form = qq:to"EOT";
<form>
	Valitse kysymys:
	<select name="kysymys">
		%questions.sort(*.key.Int).map({"<option value={$_.key}>{$_.value}</option>"}).join("\n")
	</select>
	<input type="submit">
</form>
<!-- : -->
EOT

sub response(Int $code, Str $content) {
	return [ $code, [ "Content-Type" => "text/html;charset=UTF-8" ], [ qq:to"EOT".subst(/content/, $content) ] ];
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
			content
		</body>
	</html>
	EOT
}

my $sampler = run "python3", "sample-model.py", "iso-lc", "lstm2-vaalidata", :in, :out;

my %colors = 1 => "red", 2 => "orange", 3 => "black", 4 => "lightgreen", 5 => "darkgreen";

# entry point
my $app = sub (%env) {
	my $req = Web::Request.new(%env);

	with $req.get("kysymys") -> $q-id {
		return response(400, "400") unless $q-id ~~ /^\d+$/;
		$sampler.in.put: "xxbos kysymys $q-id";
		my $answers = $sampler.out.get;
		$answers ~~ s:g/\x1b .*? m//;
		if $answers ~~ /"xxbos kysymys " $q-id ", vastaus " (<[1..5]>) ", perustelu: " (.*?) "xxbos"/ {
			my ($num, $text) = $0, $1;
			my @a = "<span class=oth>○</span>" xx 5;
			@a[$num - 1] = "<span class=sel style=\"color:%colors{$num}\">●</span>";
			return response(200, qq:to"EOT");
				<h2> %questions{$q-id} </h2>
				<table>
				<tr><th>Täysin eri mieltä</th><th></th><th>En osaa sanoa</th><th></th><th>Täysin samaa mieltä</th></tr>
				<tr> @a.map({"<td> $_ </td>"}).join() </tr>
				<tr><td class=desc colspan=5>Perustelut:</td></tr>
				<tr><td class=text colspan=5> $text </td></tr>
				</table>
				EOT
		} else {
			return response(500, "500 Internal Server Error");
		}
	} else {
		return response(200, $form);
	}
}

$http.handle($app);


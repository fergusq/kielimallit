use Text::CSV;

unit sub MAIN(Str $data-file, Str $out-file);

class Question {
	has Int $.id;
	has Int $.number-idx;
	has Int $.text-idx is rw = Int;
}

my @data = csv(in => $data-file);
my %questions;

my $counter = 0;
for @data[0].kv -> $i, $header {
	if $header ∉ %questions {
		%questions{$header} = Question.new(id => $counter++, number-idx => $i);
	} else {
		%questions{$header}.text-idx = $i;
	}	
}

for %questions.kv -> $question, $ids {
	next without $ids.text-idx;
	note "{$ids.id}\t$question.trim()";
}

my @output;

for @data[1..*] -> @candidate {
	for %questions.values -> $question {
		next without $question.text-idx;
		my $number = @candidate[$question.number-idx];
		my $text = @candidate[$question.text-idx];
		next unless $text ~~ /\w/;
		@output.push: ("Kysymys {$question.id}, vastaus $number, perustelu: $text.trim()",);
	}
}

csv(in => @output, out => $out-file);

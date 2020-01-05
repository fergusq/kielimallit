use Text::CSV;

unit sub MAIN(Str $data-file);

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

for @data[1..*] -> @candidate {
	for %questions.values -> $question {
		next without $question.text-idx;
		my $number = @candidate[$question.number-idx];
		my $text = @candidate[$question.text-idx];
		my $party = @candidate[1];
		next unless $text ~~ /\w/;
		$text .= trim;
		$text ~~ s:g/\n/ br /;
		$text ~~ s:g/\s+/ /;
		say "xxbos {$party}, kysymys {$question.id}, vastaus $number, perustelu: $text.trim()";
	}
}
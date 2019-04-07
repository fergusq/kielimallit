import sentencepiece as spm
import numpy as np
import sys
import fire

sp = spm.SentencePieceProcessor()
sp.Load("iso-lc.model")

def main(input_file, output_file):
	ids = []
	with open(input_file, "r") as f:
		for i, line in enumerate(f):
			if i%10000 == 0:
				print(i, end="\r")
				sys.stdout.flush()
			ids += [sp.EncodeAsIds(line.lower())]

	ids = np.array(ids)
	np.save(output_file, ids)

if __name__ == "__main__":
	fire.Fire(main)

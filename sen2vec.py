import fire
import fastai as fa
import fastai.text as fatext
import numpy as np
import sentencepiece as sp
import torch
import torch.nn.functional as F
import argparse
import sys
from typing import List

def loadVocab(filename):
	with open(filename, "r") as f:
		tokens = [l.strip().split()[0] for l in f]
	
	return fatext.transform.Vocab(tokens)

def embeddings(learner, xb):
	a = learner.model.eval()(xb)
	#for t in a[1]:
	#	print(t.shape)
	#exit()
	return a[1][2][0][-1]

def main():
	parser = argparse.ArgumentParser()
	parser.add_argument("vocab_prefix", type=str, help="sentencepiece model prefix")
	parser.add_argument("model", type=str, help="model name")
	parser.add_argument("input_file", type=str, help="file containing sentences")
	args = parser.parse_args()
	
	vocab = loadVocab(args.vocab_prefix + ".vocab")
	spm = sp.SentencePieceProcessor()
	spm.Load(args.vocab_prefix + ".model")
	db = fatext.data.TextLMDataBunch.from_ids(".", vocab, np.array([[0]]), np.array([[0]]))
	learner = fatext.learner.language_model_learner(db, fatext.models.AWD_LSTM, pretrained=False)
	learner.load(args.model)
	
	ans = {}
	
	with open(args.input_file) as f:
		for i, line in enumerate(f):
			line = line.strip().lower()
			if not line:
				continue
			
			if i%13 == 0:
				print(i, file=sys.stderr, end="\r")
				sys.stderr.flush()
			
			tokens = spm.EncodeAsPieces(line)
			learner.model.reset()
			xb = torch.tensor([vocab.numericalize(tokens)])
			embds = embeddings(learner, xb)
			ans[line] = list(map(float, embds))
	
	print(len(ans), 400)
	for i, line in enumerate(ans):
		if i%13 == 0:
			print(i, file=sys.stderr, end="\r")
			sys.stderr.flush()
		print(line.replace(" ", "_"), *ans[line])

if __name__ == "__main__":	
	main()

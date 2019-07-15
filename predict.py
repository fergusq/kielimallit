import fastai as fa
import fastai.text as fatext
import numpy as np
import sentencepiece as sp
import torch
import torch.nn.functional as F
import argparse
import sys
import readline
from typing import List, Tuple, Any

def loadVocab(filename):
	with open(filename, "r") as f:
		tokens = [l.strip().split()[0] for l in f]
	
	return fatext.transform.Vocab(tokens)

class Models:
	def __init__(self, vocab, learners: List[Tuple[float, Any]]):
		self.vocab = vocab
		self.learners = learners
		self.n = 100
		self.end = 0
		self.temperature = 0.7
		self.repetition_penalty = 0.
		self.excluded_tokens = ["<unk>"]
		self.promoted_tokens = []

	def weightedPredict(self, tokens: List[str]):
		for _, learner in self.learners:
			learner.model.reset()
		
		xb = torch.tensor([self.vocab.numericalize(tokens or [""])])
		history = []
		i_x = 0
		while True:
			res = sum([w*learner.pred_batch(batch=(xb,torch.tensor([0])))[0][-1] for w, learner in self.learners])
			for token in self.excluded_tokens:
				res[self.vocab.stoi[token]] = 0.

			for token in self.promoted_tokens:
				res[self.vocab.stoi[token]] *= 10.
			
			if self.repetition_penalty > 0.:
				for i, token_id in enumerate(reversed(history)):
					res[token_id] *= 1.0-self.repetition_penalty*2**(-i*.1)
			
			if self.temperature != 1.:
				res.pow_(1 / self.temperature)
			
			idx = torch.multinomial(res, 1).item()
			tok = self.vocab.itos[idx]
			
			if tok == self.end:
				break
			
			yield tok
			history.append(idx)
			
			xb = xb.new_tensor([idx])[None]
			
			i_x += 1
			
			if i_x == self.n:
				break

def model(s):
    try:
        t, w, model = s.split(',')
        return t, float(w), model
    except:
        raise argparse.ArgumentTypeError("Models must be type,weight,model")


def main():
	parser = argparse.ArgumentParser()
	parser.add_argument("vocab_prefix")
	parser.add_argument("models", nargs="+", type=model)
	args = parser.parse_args()
	
	vocab = loadVocab(args.vocab_prefix + ".vocab")
	spm = sp.SentencePieceProcessor()
	spm.Load(args.vocab_prefix + ".model")
	
	learners = []
	for t, w, model_name in args.models:
		db = fatext.data.TextLMDataBunch.from_ids(".", vocab, np.array([[0]]), np.array([[0]]))
		learner = fatext.learner.language_model_learner(db, fatext.models.AWD_LSTM if t != "txl" else fatext.models.TransformerXL, pretrained=False)
		learner.load(model_name)
		learners.append((w, learner))
	
	models = Models(vocab, learners)
	
	while True:
		try:
			text = input("> ").lower()
		except EOFError:
			break
		
		if text.startswith("/n "):
			models.n = int(text.split(" ")[1])
			models.end = None
		elif text.startswith("/temp "):
			models.temperature = float(text.split(" ")[1])
		elif text.startswith("/repe "):
			models.repetition_penalty = float(text.split(" ")[1])
		elif text.startswith("/end "):
			models.end = text.split(" ")[1]
			models.n = None
		else:
			tokens = spm.EncodeAsPieces(text)
			for i, token in enumerate(models.weightedPredict(tokens)):
				if token == "▁br":
					print("")
				else:
					print("\x1b[" + ("0m" if i%2 == 0 else "4m") + token.replace("▁", " "), end="")
				
				sys.stdout.flush()
			
			print("\x1b[0m")

if __name__ == "__main__":
	main()

import fire
import fastai as fa
import fastai.text as fatext
import numpy as np
import sentencepiece as sp
import torch
from typing import List

def loadVocab(filename):
	with open(filename, "r") as f:
		tokens = [l.strip().split()[0] for l in f]
	
	return fatext.transform.Vocab(tokens)

def predict(vocab, learner, text:str, n_words:int=1, temperature:float=1., min_p:float=None, sep:str=' ',
            excluded_tokens:List[str]=[],
            decoder=fatext.learner.decode_spec_tokens):
	"Return the `n_words` that come after `text`."
	learner.model.reset()
	xb,yb = torch.tensor([vocab.numericalize(text.split(sep))]),torch.tensor([0])
	new_idx = []
	for _ in range(n_words): #progress_bar(range(n_words), leave=False):
		res = learner.pred_batch(batch=(xb,yb))[0][-1]
		#if len(new_idx) == 0: learner.model[0].select_hidden([0])
		for token in excluded_tokens:
			res[learner.data.vocab.stoi[token]] = 0.
		if min_p is not None: 
			if (res >= min_p).float().sum() == 0:
				warn(f"There is no item with probability >= {min_p}, try a lower value.")
			else: res[res < min_p] = 0.
		if temperature != 1.: res.pow_(1 / temperature)
		idx = torch.multinomial(res, 1).item()
		new_idx.append(idx)
		xb = xb.new_tensor([idx])[None]
	return text + sep + sep.join(decoder(learner.data.vocab.textify(new_idx, sep=None)))

def main(vocab_prefix, input_file, model_file):
	vocab = loadVocab(vocab_prefix + ".vocab")
	spm = sp.SentencePieceProcessor()
	spm.Load(vocab_prefix + ".model")
	data = np.load(input_file)
	train_set = data[len(data)//10:]
	valid_set = data[:len(data)//10]
	db = fatext.data.TextLMDataBunch.from_ids(".", vocab, train_set, valid_set)
	learner = fatext.learner.language_model_learner(db, fatext.models.AWD_LSTM, pretrained=False)
	learner.load(model_file)
	params = {
			"temp": [float, 1.0],
			"top_k": [int, 10],
			"n": [int, 100],
			"beam_sz": [int, 1000],
			"type": [str, "no beam"],
			"excl": [lambda s: s.split(" "), ["<unk>"]]
	}
	while True:
		text = input("> ").lower()
		for key in params:
			if text.startswith("/%s " % key):
				params[key][1] = params[key][0](text[len("/%s " % key):])
				break
		else:
			tokens = " ".join(spm.EncodeAsPieces(text))
			if params["type"][1] == "beam":
				prediction = learner.beam_search(tokens, params["n"][1], temperature=params["temp"][1], top_k=params["top_k"][1], beam_sz=params["beam_sz"][1])
			else:
				prediction = predict(vocab, learner, tokens, params["n"][1], temperature=params["temp"][1], excluded_tokens=params["excl"][1])
			
			out = ""
			for i, token in enumerate(prediction.split(" ")):
				out += "\x1b[" + ("0m" if i%2 == 0 else "4m") + token.replace("▁", " ")
			
			print(out + "\x1b[0m")

if __name__ == "__main__":
	fire.Fire(main)

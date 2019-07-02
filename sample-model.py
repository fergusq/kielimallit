import fastai as fa
import fastai.text as fatext
import numpy as np
import sentencepiece as sp
import torch
import torch.nn.functional as F
import readline
from typing import List

def loadVocab(filename):
	with open(filename, "r") as f:
		tokens = [l.strip().split()[0] for l in f]
	
	return fatext.transform.Vocab(tokens)

def loadEnVocab(filename):
	return fatext.transform.Vocab(np.load(filename))

def pred_batch(learner, xb):
	a = learner.model.eval()(xb)
	return F.softmax(a[0].detach().cpu(), dim=-1), a[1]

def predict(vocab, learner, tokens:List[str], n_words:int=1, temperature:float=1., min_p:float=None,
	    excluded_tokens:List[str]=["<unk>"],
	    promoted_tokens:List[str]=[],
	    interactive=False,
	    track="",
	    repetition_penalty:float=0.):
	"Return the `n_words` that come after `tokens`."
	learner.model.reset()
	# generoidaan väritystilassa todennäköisyydet myös kehotteelle, joten ei syötetä kehotetta mallille alussa
	if track != "":
		xb = torch.tensor([[0]])
		output = tokens
		tokens = []
	else:
		xb = torch.tensor([vocab.numericalize(tokens or [""])])
		output = []
	history = []
	for i_x in range(len(output) + n_words):
		# -n-tilassa lasketaan lauseupotuksen arvot (en uskalla käyttää tätä muulloin, pitäisi kyllä)
		if track and track.startswith("-n"):
			res, embeddings = pred_batch(learner, xb)
			res = res[0][-1]
		else:
			res = learner.pred_batch(batch=(xb,torch.tensor([0])))[0][-1]
		
		#if len(new_idx) == 0: learner.model[0].select_hidden([0])
		# muutetaan poissuljettujen ja tuettujen sanakkeiden todennäköisyydet
		for token in excluded_tokens:
			res[learner.data.vocab.stoi[token]] = 0.
		for token in promoted_tokens:
			res[learner.data.vocab.stoi[token]] *= 10.
		
		if repetition_penalty > 0.:
			for i, token_id in enumerate(reversed(history)):
				res[token_id] *= 1.0-repetition_penalty*2**(-i*.1)
		
		if min_p is not None: 
			if (res >= min_p).float().sum() == 0:
				warn(f"There is no item with probability >= {min_p}, try a lower value.")
			else: res[res < min_p] = 0.
		
		if temperature != 1.: res.pow_(1 / temperature)
		
		# otetaan output-taulukosta valmis arvo, käytetään -p-tilassa todennäköisyyksien laskemiseen kehotteelle
		if len(output) > i_x:
			idx = learner.data.vocab.stoi[output[i_x]]
		# interaktiivisessa tilassa kysytään käyttäjältä
		elif interactive:
			argsort = res.argsort().tolist()
			print("".join(tokens+output))
			print(*["\t%d. %s (%f)" % (i + 1, learner.data.vocab.itos[n], res[n]) for i, n in enumerate(argsort[:-16:-1])], sep="\n")
			try:
				n = int(input("> "))
				if n == 0: break
				idx = argsort[-n]
			except:
				idx = torch.multinomial(res, 1).item()
		# muulloin arvotaan jokin arvo
		else:
			idx = torch.multinomial(res, 1).item()
		
		token = learner.data.vocab.itos[idx]
		history.append(idx)
		
		# lisätään tarvittaessa väritys sanakkeeseen
		if track and track[:2] not in ["-n", "-p"] and track in learner.data.vocab.stoi:
			token = "\x1b[48;2;%d;0;0m%s" % (min(int((res[learner.data.vocab.stoi[track]]**0.1)*255), 255), token)
		elif track and track == "-p":
			token = "\x1b[48;2;%d;0;0m%s" % (min(int((res[idx]**0.1)*255), 255), token)
		elif track and track.startswith("-n"):
			n = int(track[2:])
			token = get_neuron_color(embeddings, n, token)
		
		if len(output) <= i_x:
			output.append(token)
		else:
			output[i_x] = token
		
		xb = xb.new_tensor([idx])[None]
	return tokens + output

def create_heatmaps(vocab, learner, tokens:List[str], temperature:float=1.):
	learner.model.reset()
	xb = torch.tensor([[0]])
	output = [""] * 400
	for token in tokens:
		idx = learner.data.vocab.stoi[token]
		xb = xb.new_tensor([idx])[None]
		_, embeddings = pred_batch(learner, xb)
		
		for n in range(400):
			output[n] += get_neuron_color(embeddings, n, token)
		
	for n in range(400):
		print(n)
		print(output[n])
		print()

def get_neuron_color(embeddings, n, token):
	red = max(embeddings[2][0][-1][n], 0)
	blue = max(-embeddings[2][0][-1][n], 0)
	return "\x1b[48;2;%d;0;%dm%s" % (min(int(red*255), 255), min(int(blue*255), 255), token)

def main(vocab_prefix, model_file, n=0, en=False, prompt="", heatmaps=False, transformerxl=False):
	if not en:
		vocab = loadVocab(vocab_prefix + ".vocab")
		spm = sp.SentencePieceProcessor()
		spm.Load(vocab_prefix + ".model")
	else:
		vocab = loadEnVocab(vocab_prefix)
	db = fatext.data.TextLMDataBunch.from_ids(".", vocab, np.array([[0]]), np.array([[0]]))
	learner = fatext.learner.language_model_learner(db, fatext.models.AWD_LSTM if not transformerxl else fatext.models.TransformerXL, pretrained=False)
	learner.load(model_file)
	params = {
			"temp": [float, 0.7],
			"top_k": [int, 10],
			"n": [int, 100],
			"beam_sz": [int, 1000],
			"type": [str, "no beam"],
			"excl": [lambda s: s.split(" "), ["<unk>"]],
			"promo": [lambda s: s.split(" "), []],
			"interactive": [lambda s: (False if s.lower() in ["", "0", "false", "f"] else True), False],
			"repe": [float, 0.],
			"color": [str, ""]
	}
	if n:
		print("".join(predict(vocab, learner, spm.EncodeAsPieces(prompt), n, temperature=0.7)).replace("▁", " "))
		return
	if heatmaps:
		create_heatmaps(vocab, learner, spm.EncodeAsPieces(prompt), temperature=0.7)
		return
	
	while True:
		try:
			text = input("> ").lower()
		except EOFError:
			break
		
		for key in params:
			if text.startswith("/%s " % key):
				params[key][1] = params[key][0](text[len("/%s " % key):])
				break
		else:
			if not en:
				tokens = spm.EncodeAsPieces(text)
			else:
				tokens = vocab.numericalize(text.split(" "))
			if params["type"][1] == "beam":
				prediction = learner.beam_search(" ".join(tokens), params["n"][1], temperature=params["temp"][1], top_k=params["top_k"][1], beam_sz=params["beam_sz"][1]).split(" ")
			else:
				prediction = predict(vocab, learner, tokens, params["n"][1],
					temperature=params["temp"][1],
					excluded_tokens=params["excl"][1],
					promoted_tokens=params["promo"][1],
					interactive=params["interactive"][1],
					repetition_penalty=params["repe"][1],
					track=params["color"][1])
			
			out = ""
			for i, token in enumerate(prediction):
				out += "\x1b[" + ("0m" if i%2 == 0 else "4m") + token.replace("▁", " ")
				if en:
					out += " "
			
			print(out + "\x1b[0m")

if __name__ == "__main__":
	import fire
	fire.Fire(main)

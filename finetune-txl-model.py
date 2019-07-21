print("Imports")
import fire
import torch
import fastai.text as fatext
import fastai.callbacks as facb
from fastai.metrics import accuracy, error_rate
import numpy as np

def loadVocab(filename):
	with open(filename, "r") as f:
		tokens = [l.strip().split()[0] for l in f]
	
	return fatext.transform.Vocab(tokens)

def main(vocab_file, input_file, epochs=25):
	print("Start")
	print("Loading vocab...")
	vocab = loadVocab(vocab_file)
	print("Loading data...")
	data = np.load(input_file)
	train_set = data[len(data)//10:]
	valid_set = data[:len(data)//10]
	print("Loading learner...")
	db = fatext.data.TextLMDataBunch.from_ids(".", vocab, train_set, valid_set)
	learner = fatext.learner.language_model_learner(db, fatext.models.TransformerXL, pretrained=False, metrics=[accuracy, error_rate], callback_fns=[facb.CSVLogger],
		config={**fatext.models.tfmerXL_lm_config,
	#		"n_layers": 24, "n_heads": 8, "d_model": 1024, "d_head": 128, "d_inner": 3072, "mem_len": 768, "ctx_len": 768
			}
		)
	learner.load("txl1")
	#learner.unfreeze()
	learner.fit_one_cycle(epochs, callbacks=[facb.SaveModelCallback(learner, every='epoch', monitor='accuracy')])
	learner.save("final_modelx")

if __name__ == "__main__":
	print("Main")
	fire.Fire(main)

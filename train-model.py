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
	torch.cuda.device(0)
	print("Loading vocab...")
	vocab = loadVocab(vocab_file)
	print("Loading data...")
	data = np.load(input_file)
	train_set = data[len(data)//10:]
	valid_set = data[:len(data)//10]
	print("Loading learner...")
	db = fatext.data.TextLMDataBunch.from_ids(".", vocab, train_set, valid_set)
	learner = fatext.learner.language_model_learner(db, fatext.models.AWD_LSTM, pretrained=False, metrics=[accuracy, error_rate], callback_fns=[facb.CSVLogger])
	learner.fit(epochs, 0.003, callbacks=[facb.SaveModelCallback(learner, every='epoch', monitor='accuracy')])
	learner.save("final_model")

if __name__ == "__main__":
	fire.Fire(main)

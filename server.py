from flask import Flask, jsonify, request, make_response, Response
import fastai.text as fatext
import numpy as np
import sentencepiece as sp
import argparse
import importlib
sample = importlib.import_module("sample-model")

from typing import Tuple

def initModel(vocab_prefix, model_file, transformerxl=False):
	vocab = sample.loadVocab(vocab_prefix + ".vocab")
	spm = sp.SentencePieceProcessor()
	spm.Load(vocab_prefix + ".model")
	db = fatext.data.TextLMDataBunch.from_ids(".", vocab, np.array([[0]]), np.array([[0]]))
	if transformerxl:
		learner = fatext.learner.language_model_learner(db, fatext.models.TransformerXL, pretrained=False)
	else:
		learner = fatext.learner.language_model_learner(db, fatext.models.AWD_LSTM, pretrained=False, config={**fatext.models.awd_lstm_lm_config, "n_hid": 1150})
	learner.load(model_file)
	return vocab, spm, learner

def createApp(models):
	app = Flask(__name__)

	@app.route("/predict/<model_name>", methods=["GET", "POST"])
	def predict(model_name) -> Response:
		vocab, spm, learner = models[model_name]
		params = request.args if request.method == "GET" else request.form
		n = int(params.get("n", "100"))
		temperature = float(params.get("temp", "0.7"))
		prompt = params.get("prompt", "")
		tokens = spm.EncodeAsPieces(prompt)
		prediction = sample.predict(vocab, learner, tokens, n, temperature=temperature, repetition_penalty=True)
		res = make_response(jsonify({"prompt": prompt, "prediction": "".join(prediction).replace("▁", " ").strip()}))
		res.headers["Access-Control-Allow-Origin"] = "*"
		return res
	
	return app

def main():
	parser = argparse.ArgumentParser()
	parser.add_argument("port")
	parser.add_argument("vocab_prefix")
	parser.add_argument("model_file")
	parser.add_argument("--transformerxl", action="store_true")
	args = parser.parse_args()

	vocab, spm, learner = initModel(args.vocab_prefix, args.model_file, args.transformerxl)

	app = createApp({args.model_file: (vocab, spm, learner)})

	app.run(port=args.port)

if __name__ == "__main__":
	main()

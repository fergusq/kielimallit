from flask import Flask, jsonify, request, make_response, Response
import fastai.text as fatext
import numpy as np
import sentencepiece as sp
import argparse
import re
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

def parseSourceFile(filename):
	ans = set()
	with open(filename, "r") as file:
		for line in file:
#			words = line.lower().split(" ")
#			for i in range(0, len(words)-3):
#				trigraph = " ".join(words[i:i+3])
#				ans.append(trigraph)
			ans |= set(k for k in re.split(r" *(?:[^0-9a-zåäö\- ]|ja) *", line.lower()) if k.strip() != "")
	
	return ans

def createApp(models, source_file=None):
	if source_file:
		source_set = parseSourceFile(source_file)
	else:
		source_set = set()

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
		prediction = "".join(prediction).replace("▁", " ").strip()
		if params.get("annotate", "0") == "0":
			res = make_response(jsonify({"prompt": prompt, "prediction": prediction}))
		else:
			#words = re.sub(r"[^a-zA-ZåäöÅÄÖ ]", "", re.sub(r"\s+", " ", prediction.lower())).strip().split(" ")
			#novelities = [True]*len(words)
			#for i in range(0, len(words)-3):
			#	trigraph = " ".join(words[i:i+3])
			#	if trigraph in source_set:
			#		novelities[i] = False
			#		novelities[i+1] = False
			#		novelities[i+2] = False
			#ans = [{"word": word, "novel": novelity} for word, novel in zip(words, novelities)]
			ans = prediction[:len(prompt)]
			sents = re.split(r"( *(?:[^0-9a-zåäö\- ]|\bja\b) *)", prediction[len(prompt):].lower())
			for sent in sents:
				s = sent.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
				if sent in source_set:
					ans += "<copy>" + s + "</copy>"
				else:
					ans += s
			res = make_response(jsonify({"prompt": prompt, "prediction": ans}))
		
		res.headers["Access-Control-Allow-Origin"] = "*"
		return res
	
	return app

def main():
	parser = argparse.ArgumentParser()
	parser.add_argument("port")
	parser.add_argument("vocab_prefix")
	parser.add_argument("model_file")
	parser.add_argument("source_file", default=None)
	parser.add_argument("--transformerxl", action="store_true")
	args = parser.parse_args()

	vocab, spm, learner = initModel(args.vocab_prefix, args.model_file, args.transformerxl)

	app = createApp({args.model_file: (vocab, spm, learner)}, args.source_file)

	app.run(port=args.port, debug=True)

if __name__ == "__main__":
	main()

from flask import Flask, jsonify, request, make_response, Response
from flask_sockets import Sockets
import fastai.text as fatext
import numpy as np
import sentencepiece as sp
import argparse
import traceback
import json
import predict

from typing import Tuple

def initModel(vocab_prefix, model_file, transformerxl=False):
	vocab = predict.loadVocab(vocab_prefix + ".vocab")
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
	sockets = Sockets(app)

	@app.route("/predict/<model_name>", methods=["GET", "POST"])
	def predictNormal(model_name) -> Response:
		vocab, spm, learner = models[model_name]
		model = predict.Models(vocab, [(1., learner)])
		params = request.args if request.method == "GET" else request.form
		model.n = int(params.get("n", "100"))
		model.temperature = float(params.get("temp", "0.7"))
		model.end = params.get("end", None)
		model.repetition_penalty = 0.7
		prompt = params.get("prompt", "")
		tokens = spm.EncodeAsPieces(prompt)
		prediction = model.weightedPredict(tokens)
		res = make_response(jsonify({"prompt": prompt, "prediction": "".join(prediction).replace("▁", " ").strip()}))
		res.headers["Access-Control-Allow-Origin"] = "*"
		return res
	
	@sockets.route("/predictws")
	def predictSocket(ws):
		try:
			while not ws.closed:
				raw_message = ws.receive()
				if not raw_message:
					continue

				message = json.loads(raw_message)
				command = message["command"]
				if command == "select-model":
					vocab, spm, learner = models[message["model-name"]]
					model = predict.Models(vocab, [(1., learner)])
					model.repetition_penalty = 0.7
				if command == "generate":
					model.n = int(message.get("n", "100"))
					model.temperature = float(message.get("temp", "0.7"))
					prompt = message.get("prompt", "")
					tokens = spm.EncodeAsPieces(prompt)
					prediction = model.weightedPredict(tokens)
					for token in prediction:
						ws.send(json.dumps({"command": "append", "token": token.replace("▁", " ")}))
					
					ws.send(json.dumps({"command": "end"}))
				
		except:
			traceback.print_exc()	
	
	return app

def main():
	parser = argparse.ArgumentParser()
	parser.add_argument("port", type=int)
	parser.add_argument("vocab_prefix")
	parser.add_argument("model_file")
	parser.add_argument("--transformerxl", action="store_true")
	args = parser.parse_args()

	model = initModel(args.vocab_prefix, args.model_file, args.transformerxl)

	app = createApp({args.model_file: model})

	from gevent import pywsgi
	from geventwebsocket.handler import WebSocketHandler
	server = pywsgi.WSGIServer(('', args.port), app, handler_class=WebSocketHandler)
	server.serve_forever()

if __name__ == "__main__":
	main()

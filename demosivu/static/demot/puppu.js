const libvoikko = Libvoikko();
var voikko, interval, progress = 0;
const socket = new WebSocket("wss://puppu.kaivos.org/predictws");
const preprompt = "Kerran eräänä iltana ollessani ulkona tupakalla, samalla kun join kahvia, kuulin oven käyvän. xxbos ";
async function generate(n, prompt) {
	startProgress(n);
	document.getElementById("loading").style.display = "block";
	const response = await fetch("https://puppu.kaivos.org/predict/" + model + "?n=" + n + "&prompt=" + encodeURIComponent(prompt));
	const data = await response.json();
	document.getElementById("loading").style.display = "none";
	clearInterval(interval);
	return data.prediction;
}

function startProgress(n) {
	const timeEstimate = 40*n;
	progress = 0;
	interval = setInterval(() => {
		const p = 100*progress/timeEstimate;
		if (p <= 1) {
			document.getElementById("progress").value = p;
		} else {
			document.getElementById("progress").removeAttribute("value");
			clearInterval(interval);
		}
		progress++;
	}, 100);
}

var generating = false, generatedText = "", generationFinished, generationFailed, generateN = 0, generateI = 0;

socket.onopen = function () {
	document.getElementById("gen-button").disabled = false;
	if (typeof model === "string") {
		socket.send(JSON.stringify({command: "select-model", "model-name": model}));
	} else {
		socket.send(JSON.stringify({command: "select-models", "models": model}));
	}
}

socket.onmessage = function (event) {
	const data = JSON.parse(event.data);
	if (!generating) return;
	if (data.command === "append") {
		generatedText += data.token;
		generateI += 1;
		document.getElementById("generated-text").innerText = fixCaseAndXXBOS(generatedText.substr(preprompt.length));
		document.getElementById("progress").value = generateI/generateN;
	} else if (data.command === "end") {
		generationFinished(generatedText);
		generating = false;
		document.getElementById("loading").style.display = "none";
	}
}

function generateInParts(n, prompt) {
	if (generating) return Promise.reject();
	generatedText = prompt;
	generateI = 0;
	generateN = n;
	generating = true;
	socket.send(JSON.stringify({
		command: "generate",
		n: n,
		prompt: prompt
	}));
	document.getElementById("loading").style.display = "block";
	document.getElementById("progress").value = 0;
	return new Promise((resolve, reject) => {
		generationFinished = resolve;
		generationFailed = reject;
	});
}

function fixCaseAndXXBOS(text) {
	return fixCase(text.replace(/\s+br\b/g, brReplacement || "\n").replace(/xxbos[.\n]*/gi, ""));
}

function fixCase(text) {
	if (voikko === undefined) {
		voikko = libvoikko.init("fi");
	}
	let ans = "";
	let capitalize = true;
	for (const token of voikko.tokens(text)) {
		let cap = capitalize;
		if (token.type === "WORD") {
			const a = voikko.analyze(token.text);
			cap |= a.length && a.every(alt => alt.BASEFORM && alt.BASEFORM.toLowerCase() !== alt.BASEFORM);
		}
		ans += cap ? token.text.capitalize() : token.text;
		if (token.type !== "WHITESPACE" && !["-", "\"", "'"].includes(token.text)) {
			capitalize = [".", "?", "!"].includes(token.text);
		}
	}
	return ans;
}

String.prototype.capitalize = function() {
	return this.replace(/(?:^|\s)\S/g, function(a) { return a.toUpperCase(); });
};

async function generateTextWithXXBOS() {
	document.getElementById("gen-button").disabled = true;
	const n = parseInt(document.getElementById("select-n").value);
	const prompt = (preprompt + document.getElementById("prompt").value).toLowerCase();
	document.getElementById("generated-text").style.display = "block";
	let text = await generateInParts(n, prompt);
	text = fixCaseAndXXBOS(text.substr(preprompt.length));
	document.getElementById("generated-text").innerText = text;
	document.getElementById("gen-button").disabled = false;
}

async function generateText() {
	document.getElementById("gen-button").disabled = true;
	const n = parseInt(document.getElementById("select-n").value);
	const prompt = (document.getElementById("prompt").value).trim().toLowerCase();
	document.getElementById("generated-text").style.display = "block";
	let text = await generateInParts(n, prompt);
	text = fixCase(text);
	document.getElementById("generated-text").innerText = text;
	document.getElementById("gen-button").disabled = false;
}

const colors = ["red", "orange", "black", "lightgreen", "darkgreen"];

async function generateElectionData() {
	const sq = document.getElementById("select-question");
	document.getElementById("question").innerText = sq.options[sq.selectedIndex].text;
	
	document.getElementById("gen-button").disabled = true;
	
	const n = 100;
	const prompt = "/kysymys " + sq.value + ",";
	
	document.getElementById("generated-text-container").style.display = "none";
	
	const text = await generate(n, prompt);
	const matches = text.match(/vastaus ([1-5]), perustelu: ([^/]*)(\/|$)/);
	
	document.getElementById("generated-text-container").style.display = "block";
	
	document.getElementById("generated-text").innerText = fixCase(matches[2]);
	
	const num = parseInt(matches[1])-1;
	const circles = [0,0,0,0,0].map(_ => "<td><span class=oth>○</span></td>");
	circles[num] = `<td><span class="sel" style="color: ${colors[num]}">●</span></td>`;
	document.getElementById("num").innerHTML = circles.join("");
	
	document.getElementById("gen-button").disabled = false;
}

function showSettings() {
	document.getElementById("show-settings").style.display = "none";
	document.getElementById("settings").style.display = "block";
}

function closeSettings() {
	document.getElementById("show-settings").style.display = "inline";
	document.getElementById("settings").style.display = "none";
}

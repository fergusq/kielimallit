const libvoikko = Libvoikko();
var voikko, interval, progress = 0;
async function generate(n, prompt) {
	const timeEstimate = 40*n;
	progress = 0;
	interval = setInterval(() => {
		const p = 100*progress/timeEstimate;
		if (p <= 1) {
			document.getElementById("progress").value = p;
		} else {
			document.getElementById("progress").removeAttribute("value");
		}
		progress++;
	}, 100);
	document.getElementById("loading").style.display = "block";
	const response = await fetch("https://puppu.kaivos.org/predict/" + model + "?n=" + n + "&prompt=" + encodeURIComponent(prompt));
	const data = await response.json();
	document.getElementById("loading").style.display = "none";
	clearInterval(interval);
	return data.prediction;
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
		if (token.type !== "WHITESPACE") {
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
	const prompt = ("xxbos " + document.getElementById("prompt").value).trim().toLowerCase();
	document.getElementById("generated-text").style.display = "none";
	let text = await generate(n, prompt);
	text = fixCase(text.replace(/xxbos\s*/, "").replace(/\s+br\s+/g, "\n\n").replace(/xxbos.*/g, ""));
	document.getElementById("generated-text").style.display = "block";
	document.getElementById("generated-text").innerText = text;
	document.getElementById("gen-button").disabled = false;
}

async function generateText() {
	document.getElementById("gen-button").disabled = true;
	const n = parseInt(document.getElementById("select-n").value);
	const prompt = (document.getElementById("prompt").value).trim().toLowerCase();
	document.getElementById("generated-text").style.display = "none";
	let text = await generate(n, prompt);
	text = fixCase(text);
	document.getElementById("generated-text").style.display = "block";
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
	const matches = text.match(/kysymys (\d+), vastaus ([1-5]), perustelu: ([^/]*)(\/|$)/);
	
	document.getElementById("generated-text-container").style.display = "block";
	
	document.getElementById("generated-text").innerText = fixCase(matches[3]);
	
	const num = parseInt(matches[2])-1;
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

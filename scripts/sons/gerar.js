// Gerador dos sons do jogo (FASES F10, GDD 7.7): todos os sons são SINTETIZADOS aqui, por código,
// para serem 100% originais (nada gravado, nada de outros jogos). Decisão do dono do projeto na F10.
//
// Uso (na raiz do projeto):
//   node scripts/sons/gerar.js
// Escreve os arquivos .wav em assets/sons/ (mono, 44,1 kHz, 16 bits). O mesmo código gera sempre os
// mesmos arquivos (o ruído usa semente fixa). Para mudar um som, mude a receita aqui e rode de novo.
//
// Estilo: macio e cartoon. Nada estridente, nada de estampido realista. Os tiros são um "pop" (tom que
// cai rápido) com um sopro de ruído filtrado; o abate é um "crack" curto, oco e macio.

const fs = require("fs");
const path = require("path");

const RATE = 44100;
const OUT = path.join(__dirname, "..", "..", "assets", "sons");

// Peças básicas ---------------------------------------------------------------------------------------

function seeded(seed) {
	let s = seed >>> 0 || 1;
	return () => {
		s ^= s << 13;
		s ^= s >>> 17;
		s ^= s << 5;
		return ((s >>> 0) / 4294967296) * 2 - 1;
	};
}

const buffer = (seconds) => new Float32Array(Math.ceil(seconds * RATE));

// Soma `src` em `dst` a partir de `at` segundos, com ganho.
function mix(dst, src, at = 0, gain = 1) {
	const start = Math.floor(at * RATE);
	for (let i = 0; i < src.length && start + i < dst.length; i++) dst[start + i] += src[i] * gain;
	return dst;
}

// Tom com afinação que vai de f0 a f1 (curva exponencial em `glide` s) e envelope de queda `tau`.
// wave: "sine" | "tri" | "square" (quadrada amaciada).
function tone({ f0, f1 = f0, glide = 0.05, tau = 0.1, length = 0.5, attack = 0.002, wave = "sine", gain = 1 }) {
	const out = buffer(length);
	let phase = 0;
	for (let i = 0; i < out.length; i++) {
		const t = i / RATE;
		const k = Math.min(t / glide, 1);
		const f = f0 * Math.pow(f1 / f0, k);
		phase += (2 * Math.PI * f) / RATE;
		let v = Math.sin(phase);
		if (wave === "tri") v = (2 / Math.PI) * Math.asin(Math.sin(phase));
		if (wave === "square") v = Math.tanh(3 * Math.sin(phase)) * 0.8;
		const env = Math.min(t / attack, 1) * Math.exp(-t / tau);
		out[i] = v * env * gain;
	}
	return out;
}

// Ruído filtrado (passa-baixa e passa-alta de um polo), com envelope de queda.
function noise({ seed = 1, tau = 0.05, length = 0.4, low = 4000, high = 0, attack = 0.001, gain = 1, sweepTo }) {
	const rnd = seeded(seed);
	const out = buffer(length);
	let lp = 0;
	let hpIn = 0;
	let hpOut = 0;
	for (let i = 0; i < out.length; i++) {
		const t = i / RATE;
		const cutoff = sweepTo ? low * Math.pow(sweepTo / low, Math.min(t / length, 1)) : low;
		const a = 1 - Math.exp((-2 * Math.PI * cutoff) / RATE);
		lp += a * (rnd() - lp);
		let v = lp;
		if (high > 0) {
			const r = Math.exp((-2 * Math.PI * high) / RATE);
			hpOut = r * (hpOut + v - hpIn);
			hpIn = v;
			v = hpOut;
		}
		const env = Math.min(t / attack, 1) * Math.exp(-t / tau);
		out[i] = v * env * gain;
	}
	return out;
}

// Ecos curtos (sensação de espaço aberto, sem reverb pesado).
function echo(src, { delay = 0.07, feedback = 0.3, taps = 3 }) {
	const out = new Float32Array(src.length + Math.ceil(delay * taps * RATE));
	mix(out, src);
	for (let k = 1; k <= taps; k++) mix(out, src, delay * k, Math.pow(feedback, k));
	return out;
}

// Normaliza o pico (padrão -3 dB) e suaviza o fim.
function finish(src, peak = 0.7) {
	let max = 0;
	for (const v of src) max = Math.max(max, Math.abs(v));
	const g = max > 0 ? peak / max : 1;
	const fade = Math.floor(0.008 * RATE);
	// corta o silêncio do fim
	let end = src.length;
	while (end > 1 && Math.abs(src[end - 1] * g) < 0.0005) end--;
	const out = src.slice(0, end);
	for (let i = 0; i < out.length; i++) {
		out[i] *= g;
		const left = out.length - i;
		if (left < fade) out[i] *= left / fade;
	}
	return out;
}

function writeWav(name, samples) {
	const data = Buffer.alloc(samples.length * 2);
	for (let i = 0; i < samples.length; i++) {
		const v = Math.max(-1, Math.min(1, samples[i]));
		data.writeInt16LE(Math.round(v * 32767), i * 2);
	}
	const header = Buffer.alloc(44);
	header.write("RIFF", 0);
	header.writeUInt32LE(36 + data.length, 4);
	header.write("WAVE", 8);
	header.write("fmt ", 12);
	header.writeUInt32LE(16, 16);
	header.writeUInt16LE(1, 20); // PCM
	header.writeUInt16LE(1, 22); // mono
	header.writeUInt32LE(RATE, 24);
	header.writeUInt32LE(RATE * 2, 28);
	header.writeUInt16LE(2, 32);
	header.writeUInt16LE(16, 34);
	header.write("data", 36);
	header.writeUInt32LE(data.length, 40);
	fs.writeFileSync(path.join(OUT, name + ".wav"), Buffer.concat([header, data]));
	return { name, seconds: samples.length / RATE };
}

// Receitas ----------------------------------------------------------------------------------------------

// Tiro macio: "pop" (tom que cai) + sopro de ruído + um clique bem curto no começo.
// f: afinação do pop; body: duração do pop; air: quanto sopro; bright: corte do sopro; tail: eco.
function shot({ seed, f, body, air, bright, tail = 0, double = false, punch = 1 }) {
	const len = 0.6;
	const out = buffer(len);
	mix(out, tone({ f0: f * 2.2, f1: f, glide: 0.03, tau: body, length: len, wave: "tri", gain: punch }));
	mix(out, tone({ f0: f * 1.02, f1: f * 0.55, glide: body * 2, tau: body * 1.6, length: len, gain: 0.6 }));
	mix(out, noise({ seed, tau: body * 0.7, length: len, low: bright, high: 120, gain: air }));
	mix(out, noise({ seed: seed + 7, tau: 0.004, length: 0.03, low: 6000, high: 800, gain: 0.35 }));
	if (double) mix(out, finish(out.slice(), 0.5), 0.045, 0.6);
	return finish(tail > 0 ? echo(out, { delay: 0.08, feedback: tail, taps: 3 }) : out);
}

const WEAPONS = {
	// Pistolas: claras e curtas
	tiro_bolinha: { seed: 11, f: 420, body: 0.045, air: 0.5, bright: 3200 },
	tiro_chumbinho: { seed: 12, f: 260, body: 0.07, air: 0.9, bright: 2200 },
	tiro_zumbido: { seed: 13, f: 520, body: 0.035, air: 0.45, bright: 3600 },
	tiro_precisa: { seed: 14, f: 380, body: 0.04, air: 0.25, bright: 1800 }, // silenciador: abafado
	tiro_tambor: { seed: 15, f: 230, body: 0.08, air: 0.7, bright: 2400, tail: 0.25 },
	// Submetralhadoras: leves e rápidas
	tiro_ferrao: { seed: 21, f: 560, body: 0.03, air: 0.45, bright: 3800 },
	tiro_vespa: { seed: 22, f: 480, body: 0.032, air: 0.35, bright: 2600 },
	// Escopetas: muito sopro, grave
	tiro_balde: { seed: 31, f: 170, body: 0.1, air: 1.2, bright: 1600, tail: 0.25, punch: 1.2 },
	tiro_varredor: { seed: 32, f: 200, body: 0.085, air: 1.0, bright: 1900, tail: 0.2 },
	// Fuzis leves e fuzis
	tiro_tatico: { seed: 41, f: 360, body: 0.05, air: 0.6, bright: 3000 },
	tiro_atirador: { seed: 42, f: 300, body: 0.065, air: 0.6, bright: 2600, tail: 0.25 },
	tiro_rajada: { seed: 43, f: 400, body: 0.04, air: 0.4, bright: 2800 },
	tiro_trovao: { seed: 44, f: 280, body: 0.06, air: 0.75, bright: 2400, tail: 0.2 },
	// Snipers: grave, com eco de campo aberto
	tiro_matapato: { seed: 51, f: 240, body: 0.09, air: 0.8, bright: 2200, tail: 0.35 },
	tiro_gemea: { seed: 52, f: 210, body: 0.09, air: 0.9, bright: 2000, tail: 0.3, double: true },
	tiro_luneta: { seed: 53, f: 180, body: 0.12, air: 0.9, bright: 1800, tail: 0.4, punch: 1.2 },
	// Metralhadoras: curtas e encorpadas
	tiro_martelo: { seed: 61, f: 260, body: 0.05, air: 0.7, bright: 2200 },
	tiro_moedor: { seed: 62, f: 330, body: 0.03, air: 0.5, bright: 2600 },
};

const SOUNDS = {
	// Corpo a corpo: sopro de ar (ruído que varre)
	golpe_leve: () => finish(noise({ seed: 71, tau: 0.09, length: 0.25, low: 900, sweepTo: 2600, high: 200, attack: 0.04 })),
	golpe_forte: () => {
		const out = buffer(0.4);
		mix(out, noise({ seed: 72, tau: 0.14, length: 0.4, low: 600, sweepTo: 2000, high: 150, attack: 0.06 }));
		mix(out, tone({ f0: 140, f1: 90, glide: 0.1, tau: 0.08, length: 0.3, gain: 0.4 }), 0.08);
		return finish(out);
	},
	// Recarga: dois cliques de plástico (tira o pente, põe o pente)
	recarga: () => {
		const click = (seed, f) => {
			const c = buffer(0.08);
			mix(c, tone({ f0: f, tau: 0.012, length: 0.08, wave: "tri" }));
			mix(c, noise({ seed, tau: 0.006, length: 0.05, low: 5000, high: 1500, gain: 0.5 }));
			return c;
		};
		const out = buffer(0.45);
		mix(out, click(81, 900));
		mix(out, click(82, 1300), 0.28);
		return finish(out, 0.6);
	},
	sacar: () => finish(noise({ seed: 83, tau: 0.05, length: 0.18, low: 1500, sweepTo: 4000, high: 600, attack: 0.02 }), 0.5),
	sem_municao: () => finish(tone({ f0: 1500, tau: 0.008, length: 0.05, wave: "tri" }), 0.5),
	// Marcador de acerto: "tic" curto e agradável
	acerto: () => {
		const out = buffer(0.08);
		mix(out, tone({ f0: 2200, tau: 0.012, length: 0.08 }));
		mix(out, tone({ f0: 3300, tau: 0.008, length: 0.08, gain: 0.4 }));
		return finish(out, 0.55);
	},
	// Escudo quebrado: brilho que desce (vidro de desenho, sem estilhaço realista)
	escudo_quebrado: () => {
		const out = buffer(0.5);
		[1800, 2400, 3100].forEach((f, i) =>
			mix(out, tone({ f0: f, f1: f * 0.6, glide: 0.2, tau: 0.08, length: 0.4, gain: 0.5 }), i * 0.03)
		);
		mix(out, noise({ seed: 91, tau: 0.05, length: 0.3, low: 7000, high: 2500, gain: 0.3 }));
		return finish(out, 0.55);
	},
	// "Crack" de abate (GDD 7.7): estalo curto, OCO e MACIO, como um nó de dedo numa caixa de madeira
	crack_abate: () => {
		const out = buffer(0.35);
		mix(out, noise({ seed: 101, tau: 0.003, length: 0.02, low: 7000, high: 1200, gain: 0.8 }));
		mix(out, tone({ f0: 1250, f1: 1100, glide: 0.02, tau: 0.018, length: 0.2, gain: 0.8 }));
		mix(out, tone({ f0: 760, f1: 700, glide: 0.03, tau: 0.03, length: 0.25, gain: 0.7 }));
		mix(out, tone({ f0: 340, f1: 300, glide: 0.05, tau: 0.06, length: 0.3, wave: "tri", gain: 0.6 }));
		return finish(out, 0.75);
	},
	// Derrubado some em poeira: "puf"
	derrubado: () => finish(noise({ seed: 111, tau: 0.12, length: 0.45, low: 1200, sweepTo: 300, high: 80, attack: 0.02 }), 0.5),
	// Comunicação
	ping: () => {
		const out = buffer(0.3);
		mix(out, tone({ f0: 880, tau: 0.06, length: 0.2 }));
		mix(out, tone({ f0: 1320, tau: 0.08, length: 0.25 }), 0.08);
		return finish(out, 0.5);
	},
	frase: () => finish(tone({ f0: 660, f1: 780, glide: 0.04, tau: 0.05, length: 0.15 }), 0.4),
	// Cartas (F10)
	carta_nuvem_arremesso: () =>
		finish(noise({ seed: 121, tau: 0.12, length: 0.35, low: 700, sweepTo: 2500, high: 200, attack: 0.03 }), 0.45),
	carta_nuvem_puf: () => {
		const out = buffer(0.8);
		mix(out, noise({ seed: 122, tau: 0.22, length: 0.8, low: 900, sweepTo: 250, high: 60, attack: 0.01 }));
		mix(out, tone({ f0: 160, f1: 90, glide: 0.2, tau: 0.12, length: 0.5, gain: 0.5 }));
		return finish(out, 0.6);
	},
	carta_impulso: () => {
		const out = buffer(0.5);
		mix(out, tone({ f0: 220, f1: 880, glide: 0.25, tau: 0.18, length: 0.5, wave: "tri" }));
		mix(out, noise({ seed: 131, tau: 0.15, length: 0.4, low: 800, sweepTo: 4000, high: 300, gain: 0.5, attack: 0.01 }));
		return finish(out, 0.6);
	},
	carta_tremor: () => {
		const out = buffer(0.9);
		mix(out, noise({ seed: 141, tau: 0.3, length: 0.9, low: 260, high: 25, attack: 0.02, gain: 1.4 }));
		mix(out, tone({ f0: 70, f1: 45, glide: 0.5, tau: 0.3, length: 0.9, gain: 0.8 }));
		for (let k = 0; k < 5; k++)
			mix(out, noise({ seed: 142 + k, tau: 0.02, length: 0.08, low: 1800, high: 300, gain: 0.35 }), 0.05 + k * 0.12);
		return finish(out, 0.7);
	},
	carta_renascer_marca: () => {
		const out = buffer(0.9);
		[523, 659, 784].forEach((f, i) => mix(out, tone({ f0: f, tau: 0.35, length: 0.8, gain: 0.5 }), i * 0.06));
		return finish(out, 0.45);
	},
	carta_renascer_volta: () => {
		const out = buffer(0.9);
		[392, 523, 659, 784, 1047].forEach((f, i) => mix(out, tone({ f0: f, tau: 0.2, length: 0.6, gain: 0.5 }), i * 0.05));
		mix(out, noise({ seed: 151, tau: 0.2, length: 0.5, low: 1000, sweepTo: 6000, high: 400, gain: 0.25 }));
		return finish(out, 0.55);
	},
	// Ponto de escudo (F10): brilho que sobe
	escudo_recarga: () => {
		const out = buffer(0.6);
		[660, 880, 1175].forEach((f, i) => mix(out, tone({ f0: f, f1: f * 1.05, glide: 0.1, tau: 0.12, length: 0.4, gain: 0.5 }), i * 0.07));
		return finish(out, 0.5);
	},
};

// Gera tudo ------------------------------------------------------------------------------------------

fs.mkdirSync(OUT, { recursive: true });
const made = [];
for (const [name, recipe] of Object.entries(WEAPONS)) made.push(writeWav(name, shot(recipe)));
for (const [name, recipe] of Object.entries(SOUNDS)) made.push(writeWav(name, recipe()));
for (const m of made) console.log(`${m.name.padEnd(24)} ${m.seconds.toFixed(2)} s`);
console.log(`${made.length} sons em ${path.relative(process.cwd(), OUT)}`);

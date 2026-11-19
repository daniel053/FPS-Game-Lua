// Gerador dos sons do jogo (FASES F10, GDD 7.7): todos os sons são SINTETIZADOS aqui, por código,
// para serem 100% originais (nada gravado, nada de outros jogos). Decisão do dono do projeto na F10.
//
// Uso (na raiz do projeto):
//   node scripts/sons/gerar.js
// Escreve os arquivos .wav em assets/sons/ (mono, 44,1 kHz, 16 bits). O mesmo código gera sempre os
// mesmos arquivos (o ruído usa semente fixa). Para mudar um som, mude a receita aqui e rode de novo.
//
// ESTILO (dono do projeto, F10): FPS TÁTICO, NÃO ULTRA-REALISTA. Nada de som retrô / 8 bits: nenhum som
// é feito de tom puro afinado (era isso que soava como jogo antigo). Cada som é montado em CAMADAS,
// como nos efeitos de FPS:
//   * estalo: rajada curtíssima de ruído agudo (o "crack" do disparo);
//   * explosão: ruído filtrado com queda rápida (o corpo do tiro);
//   * soco: grave curto que cai de afinação (o peso, sentido mais que ouvido);
//   * mecanismo: cliques metálicos (ressonâncias desafinadas entre si, ferrolho e mola);
//   * espaço: cauda de reverberação filtrada (campo aberto), com pré-atraso;
//   * saturação leve no fim, para colar as camadas e dar presença.
// Os sons de habilidade e de interface seguem a mesma ideia: ruído filtrado em movimento, graves e
// sinos de FM (desafinados, como metal), sempre com espaço; nunca arpejo de onda simples.

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

// Filtro biquad (RBJ). `freq` pode ser uma função do tempo (varredura). type: lp | hp | bp | peak
function biquad(src, type, freq, q = 0.707, gainDb = 0) {
	const out = new Float32Array(src.length);
	let x1 = 0, x2 = 0, y1 = 0, y2 = 0;
	const fAt = typeof freq === "function" ? freq : () => freq;
	let b0, b1, b2, a1, a2, lastF = -1;
	for (let i = 0; i < src.length; i++) {
		const f = Math.min(Math.max(fAt(i / RATE), 20), RATE * 0.45);
		if (Math.abs(f - lastF) > 0.5) {
			lastF = f;
			const w = (2 * Math.PI * f) / RATE;
			const cos = Math.cos(w), sin = Math.sin(w), alpha = sin / (2 * q);
			let B0, B1, B2, A0, A1, A2;
			if (type === "lp") [B0, B1, B2] = [(1 - cos) / 2, 1 - cos, (1 - cos) / 2];
			else if (type === "hp") [B0, B1, B2] = [(1 + cos) / 2, -(1 + cos), (1 + cos) / 2];
			else if (type === "bp") [B0, B1, B2] = [alpha, 0, -alpha];
			if (type === "peak") {
				const A = Math.pow(10, gainDb / 40);
				[B0, B1, B2] = [1 + alpha * A, -2 * cos, 1 - alpha * A];
				[A0, A1, A2] = [1 + alpha / A, -2 * cos, 1 - alpha / A];
			} else [A0, A1, A2] = [1 + alpha, -2 * cos, 1 - alpha];
			b0 = B0 / A0; b1 = B1 / A0; b2 = B2 / A0; a1 = A1 / A0; a2 = A2 / A0;
		}
		const x = src[i];
		const y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;
		x2 = x1; x1 = x; y2 = y1; y1 = y;
		out[i] = y;
	}
	return out;
}

// Envelope: ataque linear + queda exponencial (tau) a partir de `hold`.
function envelope(src, { attack = 0.001, hold = 0, tau = 0.1 }) {
	for (let i = 0; i < src.length; i++) {
		const t = i / RATE;
		const a = Math.min(t / attack, 1);
		const d = t < attack + hold ? 1 : Math.exp(-(t - attack - hold) / tau);
		src[i] *= a * d;
	}
	return src;
}

function whiteNoise(seconds, seed) {
	const rnd = seeded(seed);
	const out = buffer(seconds);
	for (let i = 0; i < out.length; i++) out[i] = rnd();
	return out;
}

// Grave que cai de afinação (o "soco"): seno com queda rápida, sem ataque de clique.
function thump(f0, f1, tau, seconds = 0.4) {
	const out = buffer(seconds);
	let phase = 0;
	for (let i = 0; i < out.length; i++) {
		const t = i / RATE;
		const f = f1 + (f0 - f1) * Math.exp(-t / 0.025);
		phase += (2 * Math.PI * f) / RATE;
		out[i] = Math.sin(phase) * Math.min(t / 0.002, 1) * Math.exp(-t / tau);
	}
	return out;
}

// Clique metálico: várias ressonâncias desafinadas entre si (parciais que não formam nota), com
// fase inicial aleatória, mais um toque de ruído. Curto: soa como peça de metal batendo.
function metal(freqs, tau, seed, seconds = 0.2) {
	const rnd = seeded(seed);
	const out = buffer(seconds);
	freqs.forEach((f, k) => {
		const phase0 = rnd() * Math.PI;
		const detune = 1 + rnd() * 0.015;
		const decay = tau * (1 - k * 0.12);
		const amp = 1 / (k + 1.2);
		for (let i = 0; i < out.length; i++) {
			const t = i / RATE;
			out[i] += Math.sin(2 * Math.PI * f * detune * t + phase0) * Math.exp(-t / decay) * Math.min(t / 0.0003, 1) * amp;
		}
	});
	mix(out, envelope(biquad(whiteNoise(seconds, seed + 1), "hp", 2500), { attack: 0.0002, tau: 0.002 }), 0, 0.5);
	return out;
}

// Sino de FM (metal desafinado, para habilidades e interface): portadora + moduladora não inteira.
function bell(f, { ratio = 1.41, index = 2.5, tau = 0.4, seconds = 1.2, attack = 0.004 }) {
	const out = buffer(seconds);
	for (let i = 0; i < out.length; i++) {
		const t = i / RATE;
		const env = Math.min(t / attack, 1) * Math.exp(-t / tau);
		const mod = Math.sin(2 * Math.PI * f * ratio * t) * index * Math.exp(-t / (tau * 0.5));
		out[i] = Math.sin(2 * Math.PI * f * t + mod) * env;
	}
	return out;
}

// Ruído filtrado em movimento ("whoosh"): passa-faixa que varre de f0 a f1.
function whoosh(seconds, seed, f0, f1, { q = 1.2, attack = 0.05, tau = 0.15, hold = 0 } = {}) {
	const n = whiteNoise(seconds, seed);
	const swept = biquad(n, "bp", (t) => f0 * Math.pow(f1 / f0, Math.min(t / seconds, 1)), q);
	return envelope(swept, { attack, hold, tau });
}

// Reverberação de Schroeder (4 pentes com amortecimento + 2 passa-tudo): "campo aberto".
function reverb(src, { decay = 0.6, size = 1, damp = 0.4, predelay = 0.012, wet = 0.3, extra = 1.2 }) {
	const len = src.length + Math.ceil((decay * 1.5 + predelay) * RATE * extra);
	const dry = new Float32Array(len);
	dry.set(src);
	const combs = [0.0297, 0.0371, 0.0411, 0.0437].map((d) => Math.floor(d * size * RATE));
	const wetBuf = new Float32Array(len);
	const pre = Math.floor(predelay * RATE);
	for (const d of combs) {
		const g = Math.pow(10, (-3 * (d / RATE)) / decay);
		const line = new Float32Array(d);
		let idx = 0, lp = 0;
		for (let i = 0; i < len; i++) {
			const x = i - pre >= 0 ? dry[i - pre] : 0;
			const y = line[idx];
			lp = y * (1 - damp) + lp * damp;
			line[idx] = x + lp * g;
			idx = (idx + 1) % d;
			wetBuf[i] += y * 0.25;
		}
	}
	let out = wetBuf;
	for (const d of [0.005, 0.0017].map((s) => Math.floor(s * size * RATE))) {
		const line = new Float32Array(d);
		const ap = new Float32Array(len);
		let idx = 0;
		for (let i = 0; i < len; i++) {
			const x = out[i];
			const y = line[idx];
			const v = x + y * 0.5;
			line[idx] = v;
			ap[i] = y - v * 0.5;
			idx = (idx + 1) % d;
		}
		out = ap;
	}
	const res = new Float32Array(len);
	for (let i = 0; i < len; i++) res[i] = dry[i] + out[i] * wet;
	return res;
}

// Saturação suave (cola as camadas e dá presença).
function saturate(src, drive = 1.5) {
	const norm = Math.tanh(drive);
	return src.map((v) => Math.tanh(v * drive) / norm);
}

// Normaliza o pico (padrão -2 dB), corta o silêncio do fim e suaviza o fim.
function finish(src, peak = 0.8) {
	let max = 0;
	for (const v of src) max = Math.max(max, Math.abs(v));
	const g = max > 0 ? peak / max : 1;
	let end = src.length;
	while (end > 1 && Math.abs(src[end - 1] * g) < 0.0008) end--;
	const out = src.slice(0, end);
	const fade = Math.floor(0.01 * RATE);
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

// Tiro ------------------------------------------------------------------------------------------------
// crack: quanto estalo agudo; blast: corte da explosão (Hz) e queda (s); punch: grave (Hz) e peso;
// mech: cliques do mecanismo depois do disparo; room: cauda (decay em s, quanto de cauda);
// silenced: troca o estalo por um sopro abafado.

// Equilíbrio entre as camadas (conferido pela energia por faixa: o grave não pode cobrir o estalo,
// porque no celular quase não se ouve abaixo de 150 Hz)
const CRACK = 1.6;
const PRESENCE = 1.3;
const PUNCH = 0.45;

function shot(p) {
	const len = 0.5;
	const out = buffer(len);
	const s = p.seed;
	if (p.silenced) {
		// Silenciador: "tchff" abafado + soco curto + o mecanismo bem audível
		mix(out, envelope(biquad(whiteNoise(len, s), "bp", 1400, 0.9), { attack: 0.002, tau: 0.03 }), 0, 1.2);
		mix(out, envelope(biquad(whiteNoise(len, s + 1), "lp", 600), { attack: 0.001, tau: 0.05 }), 0, 1.0);
	} else {
		// Estalo: rajada curtíssima e brilhante
		mix(out, envelope(biquad(whiteNoise(0.05, s), "hp", p.crackHp || 2200), { attack: 0.0002, tau: 0.004 }), 0, p.crack * CRACK);
		// Presença (1,5 a 4 kHz): é o que faz o tiro "estalar" mesmo no alto-falante do celular
		const presence = biquad(whiteNoise(len, s + 3), "bp", p.presence || 2600, 0.8);
		mix(out, envelope(presence, { attack: 0.0004, hold: 0.002, tau: p.blastTau * 0.7 }), 0, PRESENCE);
		// Explosão: ruído filtrado com queda rápida, com um "peito" em médios
		let blast = biquad(whiteNoise(len, s + 1), "lp", p.blast);
		blast = biquad(blast, "peak", p.blast * 0.35, 1, 6);
		mix(out, envelope(blast, { attack: 0.0006, hold: 0.004, tau: p.blastTau }), 0, 1.6);
	}
	// Soco grave
	mix(out, thump(p.punch * 2.2, p.punch, p.punchTau), 0, p.weight * PUNCH);
	// Mecanismo: ferrolho voltando
	if (p.mech) mix(out, metal(p.mech, 0.018, s + 2), p.mechAt || 0.035, p.mechGain || 0.25);
	let shotOut = saturate(out, p.drive || 1.8);
	// Espaço: campo aberto, com o agudo da cauda abafado
	const tail = biquad(shotOut, "lp", p.roomLp || 3500);
	const roomed = reverb(tail, { decay: p.room, wet: p.roomWet, size: p.roomSize || 1.2, damp: 0.5 });
	const finalOut = new Float32Array(roomed.length);
	finalOut.set(shotOut);
	for (let i = 0; i < roomed.length; i++) finalOut[i] += (roomed[i] - (i < tail.length ? tail[i] : 0)) * 1;
	return finish(biquad(finalOut, "hp", 35));
}

// Mecanismos (ressonâncias em Hz): pistola leve, fuzil, ferrolho pesado
const MECH_LIGHT = [2900, 4300, 6100];
const MECH_RIFLE = [2300, 3500, 5200, 7100];
const MECH_HEAVY = [1700, 2600, 3900, 5600];

const WEAPONS = {
	// Pistolas: estalo seco, pouco grave, cauda curta
	tiro_bolinha: { seed: 11, crack: 0.9, blast: 3200, blastTau: 0.022, punch: 90, punchTau: 0.05, weight: 0.6, mech: MECH_LIGHT, room: 0.5, roomWet: 0.35 },
	tiro_chumbinho: { seed: 12, crack: 0.8, blast: 2000, blastTau: 0.045, punch: 70, punchTau: 0.08, weight: 1.0, mech: MECH_LIGHT, room: 0.6, roomWet: 0.4 },
	tiro_zumbido: { seed: 13, crack: 1.0, blast: 3800, blastTau: 0.018, punch: 100, punchTau: 0.04, weight: 0.5, mech: MECH_LIGHT, mechAt: 0.025, room: 0.4, roomWet: 0.3 },
	tiro_precisa: { seed: 14, silenced: true, punch: 85, punchTau: 0.04, weight: 0.5, mech: MECH_LIGHT, mechGain: 0.45, mechAt: 0.02, room: 0.3, roomWet: 0.15 },
	tiro_tambor: { seed: 15, crack: 1.1, blast: 2400, blastTau: 0.04, punch: 65, punchTau: 0.09, weight: 1.1, room: 0.9, roomWet: 0.5, drive: 2.2 },
	// Submetralhadoras: leves, rápidas, cauda curta (tiro em sequência)
	tiro_ferrao: { seed: 21, crack: 0.9, blast: 3600, blastTau: 0.016, punch: 105, punchTau: 0.035, weight: 0.45, mech: MECH_LIGHT, mechAt: 0.02, mechGain: 0.15, room: 0.35, roomWet: 0.25 },
	tiro_vespa: { seed: 22, crack: 0.8, blast: 3000, blastTau: 0.02, punch: 95, punchTau: 0.04, weight: 0.5, mech: MECH_LIGHT, mechAt: 0.022, mechGain: 0.15, room: 0.35, roomWet: 0.25 },
	// Escopetas: muito corpo e grave, cauda larga
	tiro_balde: { seed: 31, crack: 1.0, crackHp: 1500, blast: 1700, blastTau: 0.07, punch: 55, punchTau: 0.13, weight: 1.4, room: 1.2, roomWet: 0.55, drive: 2.4 },
	tiro_varredor: { seed: 32, crack: 1.0, crackHp: 1700, blast: 1900, blastTau: 0.06, punch: 60, punchTau: 0.11, weight: 1.3, mech: MECH_HEAVY, mechAt: 0.05, mechGain: 0.15, room: 1.0, roomWet: 0.5, drive: 2.2 },
	// Fuzis leves e fuzis: estalo forte, corpo médio, mecanismo de fuzil
	tiro_tatico: { seed: 41, crack: 1.1, blast: 3000, blastTau: 0.028, punch: 80, punchTau: 0.06, weight: 0.8, mech: MECH_RIFLE, room: 0.8, roomWet: 0.4 },
	tiro_atirador: { seed: 42, crack: 1.3, blast: 2600, blastTau: 0.04, punch: 70, punchTau: 0.08, weight: 1.0, mech: MECH_RIFLE, mechAt: 0.045, room: 1.1, roomWet: 0.5, drive: 2.0 },
	tiro_rajada: { seed: 43, crack: 1.0, blast: 3200, blastTau: 0.024, punch: 85, punchTau: 0.055, weight: 0.75, mech: MECH_RIFLE, mechAt: 0.03, mechGain: 0.18, room: 0.7, roomWet: 0.38 },
	tiro_trovao: { seed: 44, crack: 1.2, blast: 2500, blastTau: 0.035, punch: 70, punchTau: 0.07, weight: 1.0, mech: MECH_RIFLE, room: 0.9, roomWet: 0.45, drive: 2.0 },
	// Snipers: estalo enorme, grave, eco longo de campo aberto, ferrolho pesado
	tiro_matapato: { seed: 51, crack: 1.4, blast: 2200, blastTau: 0.05, punch: 60, punchTau: 0.1, weight: 1.2, mech: MECH_HEAVY, mechAt: 0.12, mechGain: 0.3, room: 1.6, roomWet: 0.6, drive: 2.3 },
	tiro_gemea: { seed: 52, crack: 1.4, blast: 2000, blastTau: 0.055, punch: 55, punchTau: 0.11, weight: 1.3, mech: MECH_HEAVY, mechAt: 0.1, mechGain: 0.3, room: 1.5, roomWet: 0.6, drive: 2.3 },
	tiro_luneta: { seed: 53, crack: 1.6, blast: 1900, blastTau: 0.07, punch: 50, punchTau: 0.14, weight: 1.5, mech: MECH_HEAVY, mechAt: 0.15, mechGain: 0.35, room: 2.0, roomWet: 0.65, drive: 2.6 },
	// Metralhadoras: encorpadas e curtas (tiro contínuo)
	tiro_martelo: { seed: 61, crack: 1.0, blast: 2400, blastTau: 0.03, punch: 70, punchTau: 0.06, weight: 1.0, mech: MECH_HEAVY, mechAt: 0.028, mechGain: 0.15, room: 0.6, roomWet: 0.35, drive: 2.0 },
	tiro_moedor: { seed: 62, crack: 0.8, blast: 2800, blastTau: 0.018, punch: 85, punchTau: 0.04, weight: 0.7, mech: MECH_HEAVY, mechAt: 0.02, mechGain: 0.12, room: 0.4, roomWet: 0.28 },
};

// Outros sons ------------------------------------------------------------------------------------------

const room = (src, decay = 0.5, wet = 0.3) => reverb(src, { decay, wet, damp: 0.5, size: 1 });

const SOUNDS = {
	// Corpo a corpo: deslocamento de ar (whoosh) com um pouco de corpo
	golpe_leve: () => finish(room(whoosh(0.3, 71, 500, 2200, { attack: 0.06, tau: 0.06, hold: 0.04 }), 0.3, 0.15)),
	golpe_forte: () => {
		const out = buffer(0.5);
		mix(out, whoosh(0.45, 72, 300, 1600, { attack: 0.08, tau: 0.09, hold: 0.06 }));
		mix(out, thump(110, 60, 0.07), 0.12, 0.5);
		return finish(room(out, 0.35, 0.2));
	},
	// Recarga: pente saindo (clique + atrito), pente entrando (batida firme) e ferrolho
	recarga: () => {
		const out = buffer(0.9);
		mix(out, metal(MECH_RIFLE, 0.02, 81), 0, 0.5);
		mix(out, envelope(biquad(whiteNoise(0.15, 82), "bp", 2500, 1.5), { attack: 0.01, tau: 0.04 }), 0.03, 0.25);
		mix(out, metal([1900, 2800, 4100], 0.025, 83), 0.38, 0.7);
		mix(out, thump(150, 90, 0.03), 0.38, 0.4);
		mix(out, metal(MECH_HEAVY, 0.03, 84), 0.62, 0.6);
		mix(out, metal(MECH_RIFLE, 0.02, 85), 0.7, 0.5);
		return finish(room(out, 0.25, 0.12), 0.7);
	},
	// Sacar: tecido + clique metálico
	sacar: () => {
		const out = buffer(0.35);
		mix(out, envelope(biquad(whiteNoise(0.2, 91), "bp", 1800, 0.8), { attack: 0.03, tau: 0.04 }), 0, 0.4);
		mix(out, metal(MECH_RIFLE, 0.02, 92), 0.12, 0.8);
		return finish(room(out, 0.2, 0.1), 0.6);
	},
	sem_municao: () => finish(room(metal([3100, 4700, 6900], 0.022, 93, 0.12), 0.15, 0.1), 0.55),
	// Marcador de acerto: "tic" seco e brilhante (um toque metálico pequeno)
	acerto: () => finish(room(metal([3600, 5400, 7600], 0.03, 94, 0.15), 0.12, 0.08), 0.6),
	// Escudo quebrado: energia que estilhaça (estalo + cacos agudos + queda de energia)
	escudo_quebrado: () => {
		const out = buffer(0.7);
		mix(out, envelope(biquad(whiteNoise(0.1, 101), "hp", 3000), { attack: 0.0005, tau: 0.01 }), 0, 0.8);
		for (let k = 0; k < 7; k++)
			mix(out, metal([4000 + k * 530, 6100 + k * 410], 0.03, 102 + k, 0.15), k * 0.018, 0.35);
		mix(out, whoosh(0.5, 110, 3000, 400, { q: 2, attack: 0.005, tau: 0.15 }), 0, 0.5);
		return finish(room(out, 0.5, 0.25), 0.7);
	},
	// Abate (GDD 7.7): estalo curto, OCO e macio. Batida firme em algo oco (madeira grossa / caixa),
	// com um toque metálico de "confirmado" bem curto por cima. Seco, sem eco longo.
	crack_abate: () => {
		const out = buffer(0.4);
		mix(out, envelope(biquad(whiteNoise(0.05, 121), "bp", 2800, 1.2), { attack: 0.0003, tau: 0.005 }), 0, 1.0);
		const body = envelope(biquad(whiteNoise(0.3, 122), "bp", 520, 8), { attack: 0.0005, tau: 0.04 });
		mix(out, body, 0, 2.2);
		const hollow = envelope(biquad(whiteNoise(0.3, 123), "bp", 230, 10), { attack: 0.001, tau: 0.06 });
		mix(out, hollow, 0.002, 2.4);
		mix(out, thump(160, 90, 0.05), 0, 0.5);
		mix(out, metal([2900, 4400], 0.03, 124, 0.12), 0.01, 0.2);
		return finish(room(saturate(out, 1.6), 0.18, 0.12), 0.85);
	},
	// Derrubado: poeira (sopro grave que se espalha) + baque
	derrubado: () => {
		const out = buffer(0.8);
		mix(out, whoosh(0.7, 131, 1500, 250, { q: 0.8, attack: 0.01, tau: 0.18 }));
		mix(out, thump(120, 55, 0.08), 0, 0.6);
		return finish(room(out, 0.5, 0.25), 0.6);
	},
	// Comunicação: avisos curtos e limpos, de rádio tático (sino de FM curto, não nota pura)
	ping: () => {
		const out = buffer(0.6);
		mix(out, bell(1320, { ratio: 2.01, index: 1.2, tau: 0.08, seconds: 0.4 }), 0, 0.6);
		mix(out, bell(1760, { ratio: 2.01, index: 1.2, tau: 0.1, seconds: 0.4 }), 0.07, 0.6);
		mix(out, envelope(biquad(whiteNoise(0.03, 141), "bp", 4000, 2), { attack: 0.0005, tau: 0.004 }), 0, 0.3);
		return finish(room(out, 0.4, 0.25), 0.55);
	},
	frase: () => {
		const out = buffer(0.4);
		mix(out, bell(990, { ratio: 2.01, index: 0.8, tau: 0.07, seconds: 0.3 }));
		mix(out, envelope(biquad(whiteNoise(0.02, 142), "bp", 3500, 2), { attack: 0.0005, tau: 0.004 }), 0, 0.3);
		return finish(room(out, 0.3, 0.2), 0.45);
	},
	// Cartas (F10): habilidades, com ar, energia e espaço
	carta_nuvem_arremesso: () => {
		const out = buffer(0.5);
		mix(out, metal([1500, 2300], 0.02, 151), 0, 0.4); // destrava a granada
		mix(out, whoosh(0.4, 152, 600, 2400, { q: 1.5, attack: 0.04, tau: 0.08, hold: 0.05 }), 0.05, 1);
		return finish(room(out, 0.35, 0.2), 0.6);
	},
	carta_nuvem_puf: () => {
		const out = buffer(1.3);
		mix(out, envelope(biquad(whiteNoise(0.05, 161), "hp", 1500), { attack: 0.0005, tau: 0.008 }), 0, 0.6);
		mix(out, thump(130, 60, 0.1), 0, 0.8);
		// gás saindo: chiado que abre e assenta
		mix(out, envelope(biquad(whiteNoise(1.2, 162), "bp", (t) => 3500 - 2000 * Math.min(t, 1), 0.7), { attack: 0.02, hold: 0.15, tau: 0.35 }), 0.01, 0.9);
		return finish(room(out, 0.9, 0.35), 0.65);
	},
	carta_impulso: () => {
		const out = buffer(0.8);
		mix(out, thump(140, 50, 0.09), 0, 1.0); // empurrão no chão
		mix(out, envelope(biquad(whiteNoise(0.05, 171), "hp", 1200), { attack: 0.0005, tau: 0.01 }), 0, 0.5);
		mix(out, whoosh(0.6, 172, 400, 3500, { q: 1.4, attack: 0.02, tau: 0.15, hold: 0.08 }), 0.01, 1.2); // ar subindo
		return finish(room(saturate(out, 1.5), 0.6, 0.3), 0.7);
	},
	carta_tremor: () => {
		const out = buffer(1.3);
		mix(out, thump(90, 38, 0.25, 1.2), 0, 1.4);
		mix(out, envelope(biquad(whiteNoise(1.2, 181), "lp", 300), { attack: 0.02, hold: 0.1, tau: 0.3 }), 0, 1.8);
		// pedras rachando ao longo da onda
		for (let k = 0; k < 6; k++)
			mix(out, envelope(biquad(whiteNoise(0.1, 182 + k), "bp", 1200 + k * 150, 1.5), { attack: 0.001, tau: 0.02 }), 0.04 + k * 0.09, 0.5);
		return finish(room(saturate(out, 1.8), 0.8, 0.3), 0.75);
	},
	carta_renascer_marca: () => {
		const out = buffer(1.4);
		mix(out, thump(110, 70, 0.06), 0, 0.5);
		mix(out, bell(523, { ratio: 1.41, index: 1.8, tau: 0.45, seconds: 1.2 }), 0, 0.5);
		mix(out, bell(784, { ratio: 1.41, index: 1.2, tau: 0.35, seconds: 1.2 }), 0.02, 0.35);
		mix(out, whoosh(0.8, 191, 2000, 6000, { q: 3, attack: 0.1, tau: 0.25 }), 0, 0.2);
		return finish(room(out, 1.0, 0.4), 0.55);
	},
	carta_renascer_volta: () => {
		const out = buffer(1.4);
		mix(out, whoosh(0.6, 201, 300, 5000, { q: 1.5, attack: 0.15, tau: 0.1, hold: 0.15 }), 0, 1.0); // sugado de volta
		mix(out, thump(130, 60, 0.08), 0.32, 0.9);
		mix(out, bell(659, { ratio: 1.41, index: 2, tau: 0.4, seconds: 1 }), 0.32, 0.5);
		mix(out, bell(988, { ratio: 1.41, index: 1.4, tau: 0.35, seconds: 1 }), 0.34, 0.35);
		return finish(room(out, 1.0, 0.4), 0.65);
	},
	// Ponto de escudo (F10): carga de energia que sobe e trava
	escudo_recarga: () => {
		const out = buffer(0.9);
		mix(out, whoosh(0.45, 211, 600, 4500, { q: 2.5, attack: 0.2, tau: 0.05, hold: 0.15 }), 0, 0.9);
		mix(out, bell(1175, { ratio: 2.41, index: 1.5, tau: 0.2, seconds: 0.6 }), 0.33, 0.45);
		mix(out, metal([2400, 3600], 0.02, 212, 0.1), 0.33, 0.3);
		return finish(room(out, 0.6, 0.3), 0.55);
	},
};

// Gera tudo ------------------------------------------------------------------------------------------

fs.mkdirSync(OUT, { recursive: true });
const made = [];
for (const [name, recipe] of Object.entries(WEAPONS)) made.push(writeWav(name, shot(recipe)));
for (const [name, recipe] of Object.entries(SOUNDS)) made.push(writeWav(name, recipe()));
for (const m of made) console.log(`${m.name.padEnd(24)} ${m.seconds.toFixed(2)} s`);
console.log(`${made.length} sons em ${path.relative(process.cwd(), OUT)}`);

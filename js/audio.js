let ctx;
let master;
let sfxGain;
let musicGain;
let sceneGain;
let started = false;

function ensure() {
  if (ctx) return;
  const AC = window.AudioContext || window.webkitAudioContext;
  if (!AC) return;
  ctx = new AC();
  master = ctx.createGain();
  sfxGain = ctx.createGain();
  musicGain = ctx.createGain();
  sceneGain = ctx.createGain();
  sfxGain.connect(master);
  musicGain.connect(sceneGain);
  sceneGain.connect(master);
  master.connect(ctx.destination);
  master.gain.value = 0.8;
  sfxGain.gain.value = 0.85;
  musicGain.gain.value = 0.4;
  const base = ctx.createOscillator();
  const fifth = ctx.createOscillator();
  base.type = "sine";
  fifth.type = "sine";
  base.frequency.value = 98;
  fifth.frequency.value = 146.8;
  const baseG = ctx.createGain();
  const fifthG = ctx.createGain();
  baseG.gain.value = 0.045;
  fifthG.gain.value = 0.03;
  base.connect(baseG);
  fifth.connect(fifthG);
  baseG.connect(musicGain);
  fifthG.connect(musicGain);
  const lfo = ctx.createOscillator();
  const depth = ctx.createGain();
  lfo.frequency.value = 0.07;
  depth.gain.value = 0.012;
  lfo.connect(depth);
  depth.connect(baseG.gain);
  base.start();
  fifth.start();
  lfo.start();
}

export function unlock() {
  ensure();
  if (ctx && ctx.state === "suspended") ctx.resume();
  started = true;
}

export function setVolumes({ master: m = 0.8, sfx = 0.85, music = 0.4 }) {
  ensure();
  if (!ctx) return;
  master.gain.value = m;
  sfxGain.gain.value = sfx;
  musicGain.gain.value = music;
}

export function setScene(scene) {
  ensure();
  if (!ctx) return;
  const now = ctx.currentTime;
  sceneGain.gain.cancelScheduledValues(now);
  sceneGain.gain.linearRampToValueAtTime(scene === "game" ? 0.28 : 1, now + 0.4);
}

function tone(freq, dur, type, gain, slide) {
  if (!ctx || !started) return;
  const t = ctx.currentTime;
  const o = ctx.createOscillator();
  const g = ctx.createGain();
  o.type = type;
  o.frequency.setValueAtTime(Math.max(40, freq), t);
  if (slide) o.frequency.exponentialRampToValueAtTime(Math.max(40, slide), t + dur);
  g.gain.setValueAtTime(gain, t);
  g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
  o.connect(g);
  g.connect(sfxGain);
  o.start(t);
  o.stop(t + dur + 0.02);
}

const PRESETS = {
  click: () => tone(520, 0.05, "triangle", 0.03, 320),
  error: () => tone(140, 0.12, "square", 0.03, 90),
  move: () => tone(660, 0.04, "sine", 0.02, 880),
  attack: () => tone(220, 0.08, "triangle", 0.04, 140),
  q: () => {
    tone(740, 0.12, "sine", 0.05, 1180);
    tone(1180, 0.16, "triangle", 0.03, 640);
  },
  w: () => tone(520, 0.22, "sine", 0.05, 780),
  e: () => {
    tone(360, 0.28, "sine", 0.04, 720);
    tone(540, 0.28, "triangle", 0.02, 900);
  },
  r: () => tone(196, 0.45, "sine", 0.07, 98),
  chime: () => {
    tone(880, 0.18, "sine", 0.04, 1320);
    tone(1320, 0.22, "triangle", 0.02, 1760);
  },
  ping: () => tone(988, 0.09, "sine", 0.04, 740),
  recall: () => tone(392, 0.18, "sine", 0.03, 523),
  level: () => {
    tone(523, 0.1, "triangle", 0.04, 659);
    tone(659, 0.14, "sine", 0.04, 784);
  },
  coin: () => tone(1046, 0.07, "square", 0.02, 1568),
  heal: () => tone(640, 0.16, "sine", 0.04, 960),
  flash: () => tone(180, 0.08, "sawtooth", 0.03, 520),
  hit: () => tone(160, 0.05, "square", 0.025, 80),
};

export function play(name) {
  const fn = PRESETS[name];
  if (fn) fn();
}

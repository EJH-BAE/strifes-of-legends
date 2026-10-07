import { ABILITIES, LANE, MAP, WALLS, WORLD } from "./data.js";
import { clamp, dist } from "./geom.js";

let ground;
let textUnit = 16;

function fontPx(px) {
  return `${px * textUnit}px Malgun Gothic, "Noto Sans KR", sans-serif`;
}

function hash(n) {
  n = (n * 1664525 + 1013904223) >>> 0;
  return n / 4294967296;
}

function buildGround() {
  const size = 1600;
  const c = document.createElement("canvas");
  c.width = size;
  c.height = size;
  const g = c.getContext("2d");
  const s = size / WORLD;
  g.scale(s, s);
  g.fillStyle = "#1a3330";
  g.fillRect(0, 0, WORLD, WORLD);

  const blue = g.createRadialGradient(MAP.fountain.x, MAP.fountain.y, 80, MAP.fountain.x, MAP.fountain.y, 1700);
  blue.addColorStop(0, "#24564f");
  blue.addColorStop(1, "rgba(26,51,48,0)");
  g.fillStyle = blue;
  g.fillRect(0, 0, WORLD, WORLD);

  const red = g.createRadialGradient(MAP.redBase.x, MAP.redBase.y, 80, MAP.redBase.x, MAP.redBase.y, 1500);
  red.addColorStop(0, "#5a2c32");
  red.addColorStop(1, "rgba(26,51,48,0)");
  g.fillStyle = red;
  g.fillRect(0, 0, WORLD, WORLD);

  g.strokeStyle = "rgba(70, 110, 140, 0.28)";
  g.lineWidth = 420;
  g.lineCap = "round";
  g.beginPath();
  g.moveTo(900, 1700);
  g.lineTo(2500, 2500);
  g.lineTo(4000, 4000);
  g.lineTo(5400, 4900);
  g.stroke();

  g.strokeStyle = "#6d5b40";
  g.lineWidth = 210;
  g.lineCap = "round";
  g.lineJoin = "round";
  g.beginPath();
  LANE.forEach((p, i) => (i ? g.lineTo(p.x, p.y) : g.moveTo(p.x, p.y)));
  g.stroke();
  g.strokeStyle = "#8a7352";
  g.lineWidth = 120;
  g.stroke();

  for (let i = 0; i < 2800; i++) {
    const x = hash(i * 3 + 1) * WORLD;
    const y = hash(i * 3 + 2) * WORLD;
    const a = 0.03 + hash(i * 3 + 3) * 0.07;
    g.fillStyle = hash(i) > 0.5 ? `rgba(255,255,255,${a})` : `rgba(0,0,0,${a})`;
    g.fillRect(x, y, 18 + hash(i + 9) * 40, 14);
  }

  g.fillStyle = "rgba(198,161,90,0.16)";
  g.beginPath();
  g.arc(MAP.fountain.x, MAP.fountain.y, MAP.fountain.r, 0, Math.PI * 2);
  g.fill();
  g.strokeStyle = "rgba(232, 208, 150, 0.45)";
  g.lineWidth = 8;
  g.stroke();

  g.fillStyle = "rgba(160, 70, 64, 0.18)";
  g.beginPath();
  g.arc(MAP.redBase.x, MAP.redBase.y, MAP.redBase.r, 0, Math.PI * 2);
  g.fill();

  g.fillStyle = "rgba(243, 230, 196, 0.55)";
  g.font = "700 64px Cinzel, Palatino Linotype, serif";
  g.textAlign = "center";
  g.fillText("기지", MAP.fountain.x, MAP.fountain.y + 18);
  ground = c;
}

function worldTransform(ctx, sim) {
  const shake = sim.cam.shake || 0;
  const ox = (Math.random() - 0.5) * shake;
  const oy = (Math.random() - 0.5) * shake;
  const vw = sim.viewW();
  const vh = sim.viewH();
  const sx = sim.canvas.width / vw;
  const sy = sim.canvas.height / vh;
  ctx.setTransform(sx, 0, 0, sy, (-sim.cam.x + ox) * sx, (-sim.cam.y + oy) * sy);
  return { sx, sy, vw, vh };
}

export function drawFrame(canvas, minimap, sim) {
  if (!ground) buildGround();
  const ctx = canvas.getContext("2d");
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  const { sx } = worldTransform(ctx, sim);
  textUnit = sim.viewW() / (sim.canvas.clientWidth || sim.viewW());
  const vw = sim.viewW();
  const vh = sim.viewH();
  ctx.drawImage(
    ground,
    (sim.cam.x / WORLD) * ground.width,
    (sim.cam.y / WORLD) * ground.height,
    (vw / WORLD) * ground.width,
    (vh / WORLD) * ground.height,
    sim.cam.x,
    sim.cam.y,
    vw,
    vh
  );

  drawAim(ctx, sim);
  for (const mark of sim.marks) drawMark(ctx, mark);
  for (const ward of sim.wards) drawWard(ctx, ward, sim.time);
  for (const portal of sim.portals) drawPortal(ctx, portal, sim.time);

  const drawables = [];
  for (const w of WALLS) drawables.push({ y: w.y + w.h, draw: () => drawWall(ctx, w) });
  for (const c of sim.chimes) drawables.push({ y: c.y, draw: () => drawChime(ctx, c, sim.time) });
  for (const s of sim.shrines) drawables.push({ y: s.y, draw: () => drawShrine(ctx, s, sim.time) });
  for (const u of sim.units) {
    if (u.dead && u.kind !== "tower") continue;
    if (u !== sim.player && !sim.sees(u.x, u.y) && u.kind !== "champion") {
      if (!sim.sees(u.x, u.y)) continue;
    }
    if (u !== sim.player && !sim.sees(u.x, u.y)) continue;
    drawables.push({ y: u.y, draw: () => drawUnit(ctx, u, sim) });
  }
  drawables.sort((a, b) => a.y - b.y);
  for (const d of drawables) d.draw();

  if (sim.ult) drawUlt(ctx, sim.ult);
  for (const p of sim.projectiles) drawProjectile(ctx, p, sim.time);
  for (const p of sim.particles) {
    ctx.globalAlpha = Math.max(0, p.life / p.max);
    ctx.fillStyle = p.color;
    ctx.beginPath();
    ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
    ctx.fill();
    ctx.globalAlpha = 1;
  }
  for (const ping of sim.pings) drawPing(ctx, ping, sx);
  for (const f of sim.floats) {
    ctx.globalAlpha = Math.max(0, f.life / f.max);
    ctx.fillStyle = f.color;
    ctx.font = fontPx(15);
    ctx.textAlign = "center";
    ctx.fillText(f.text, f.x, f.y);
    ctx.globalAlpha = 1;
  }

  if (sim.settings.fog) drawFog(ctx, sim);
  drawVignette(ctx, sim);
  drawMinimap(minimap, sim);
}

function drawAim(ctx, sim) {
  const p = sim.player;
  if (p.dead) return;
  const showRange = sim.settings.showRanges || sim.aim?.kind === "amove";
  if (showRange) ring(ctx, p.x, p.y, p.range, "rgba(255,80,80,0.28)");
  if (!sim.aim) return;
  const m = sim.mouse;
  if (sim.aim.kind === "amove") {
    ring(ctx, m.x, m.y, 18, "rgba(255,90,80,0.8)");
    return;
  }
  if (sim.aim.kind === "q") {
    const def = ABILITIES.q;
    const d = dist(p.x, p.y, m.x, m.y) || 1;
    const len = Math.min(def.range, d);
    const ang = Math.atan2(m.y - p.y, m.x - p.x);
    const x2 = p.x + Math.cos(ang) * len;
    const y2 = p.y + Math.sin(ang) * len;
    ctx.strokeStyle = "rgba(243, 214, 140, 0.85)";
    ctx.lineWidth = def.width;
    ctx.lineCap = "round";
    ctx.globalAlpha = 0.35;
    ctx.beginPath();
    ctx.moveTo(p.x, p.y);
    ctx.lineTo(x2, y2);
    ctx.stroke();
    ctx.globalAlpha = 1;
    ctx.lineWidth = 3;
    ctx.stroke();
  }
  if (sim.aim.kind === "w") {
    ring(ctx, p.x, p.y, ABILITIES.w.range, "rgba(180, 230, 160, 0.45)");
    const d = dist(p.x, p.y, m.x, m.y) || 1;
    const len = Math.min(ABILITIES.w.range, d);
    const ang = Math.atan2(m.y - p.y, m.x - p.x);
    ring(ctx, p.x + Math.cos(ang) * len, p.y + Math.sin(ang) * len, 70, "rgba(190, 240, 170, 0.9)");
  }
  if (sim.aim.kind === "e") {
    const aim = sim.aimE(m.x, m.y, true);
    ctx.strokeStyle = aim ? "rgba(170, 245, 235, 0.9)" : "rgba(255,120,100,0.8)";
    ctx.lineWidth = 4;
    ctx.beginPath();
    ctx.moveTo(p.x, p.y);
    ctx.lineTo(m.x, m.y);
    ctx.stroke();
    if (aim) {
      ring(ctx, aim.ax, aim.ay, 48, "rgba(180,255,245,0.9)");
      ring(ctx, aim.bx, aim.by, 48, "rgba(180,255,245,0.9)");
    }
  }
  if (sim.aim.kind === "r") {
    const d = dist(p.x, p.y, m.x, m.y) || 1;
    const len = Math.min(ABILITIES.r.range, d);
    const ang = Math.atan2(m.y - p.y, m.x - p.x);
    ring(ctx, p.x + Math.cos(ang) * len, p.y + Math.sin(ang) * len, ABILITIES.r.radius, "rgba(243, 214, 140, 0.85)");
  }
}

function ring(ctx, x, y, r, color) {
  ctx.strokeStyle = color;
  ctx.lineWidth = 3;
  ctx.beginPath();
  ctx.arc(x, y, r, 0, Math.PI * 2);
  ctx.stroke();
}

function drawMark(ctx, mark) {
  const t = 1 - mark.life / mark.max;
  ctx.globalAlpha = 1 - t;
  if (mark.kind === "stasis") {
    ctx.strokeStyle = "rgba(246, 231, 178, 0.8)";
    ctx.lineWidth = 6;
    ctx.beginPath();
    ctx.arc(mark.x, mark.y, mark.r, 0, Math.PI * 2);
    ctx.stroke();
    ctx.globalAlpha = 1;
    return;
  }
  ctx.strokeStyle = mark.kind === "attack" ? "#ff6d6d" : "#9dffb0";
  ctx.lineWidth = 3;
  ctx.beginPath();
  ctx.arc(mark.x, mark.y, 10 + t * 26, 0, Math.PI * 2);
  ctx.stroke();
  ctx.globalAlpha = 1;
}

function drawWall(ctx, w) {
  const h = 52;
  ctx.fillStyle = "#231f1c";
  ctx.fillRect(w.x, w.y - h, w.w, w.h + h);
  ctx.fillStyle = "#3c3833";
  ctx.fillRect(w.x, w.y - h, w.w, w.h);
  ctx.fillStyle = "#5c564c";
  ctx.fillRect(w.x + 6, w.y - h + 6, w.w - 12, 18);
  ctx.strokeStyle = "rgba(214, 180, 110, 0.35)";
  ctx.lineWidth = 3;
  ctx.strokeRect(w.x + 2, w.y - h + 2, w.w - 4, w.h - 4);
}

function drawChime(ctx, c, time) {
  const y = c.y - 26 + Math.sin(time * 2 + c.bob) * 6;
  ctx.save();
  ctx.translate(c.x, y);
  ctx.rotate(Math.sin(time + c.bob) * 0.2);
  ctx.fillStyle = "#f6e7b2";
  ctx.beginPath();
  ctx.moveTo(0, -16);
  ctx.lineTo(10, 0);
  ctx.lineTo(0, 16);
  ctx.lineTo(-10, 0);
  ctx.closePath();
  ctx.fill();
  ctx.restore();
}

function drawShrine(ctx, s, time) {
  const power = clamp(s.t / 5, 0, 1);
  const r = 18 + power * 16;
  ctx.save();
  ctx.translate(s.x, s.y);
  ctx.fillStyle = `rgba(190, 230, 170, ${0.25 + power * 0.35})`;
  ctx.beginPath();
  ctx.ellipse(0, 8, r * 1.4, r * 0.7, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = "#f4f7ef";
  ctx.beginPath();
  ctx.moveTo(-10, 6);
  ctx.quadraticCurveTo(0, -18 - power * 10, 10, 6);
  ctx.lineTo(6, 16);
  ctx.lineTo(-6, 16);
  ctx.closePath();
  ctx.fill();
  ctx.fillStyle = "#d4b483";
  ctx.fillRect(-12, 16, 24, 4);
  ctx.restore();
  void time;
}

function drawPortal(ctx, portal, time) {
  const pulse = 0.5 + Math.sin(time * 4) * 0.15;
  ctx.strokeStyle = `rgba(190, 255, 246, ${0.4 + pulse * 0.3})`;
  ctx.lineWidth = 16;
  ctx.globalAlpha = 0.45;
  ctx.beginPath();
  ctx.moveTo(portal.ax, portal.ay);
  ctx.lineTo(portal.bx, portal.by);
  ctx.stroke();
  ctx.globalAlpha = 1;
  for (const [x, y] of [
    [portal.ax, portal.ay],
    [portal.bx, portal.by],
  ]) {
    ctx.save();
    ctx.translate(x, y);
    ctx.strokeStyle = "#e9fff8";
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.ellipse(0, 0, 26, 40, 0, 0, Math.PI * 2);
    ctx.stroke();
    ctx.restore();
  }
}

function drawWard(ctx, w) {
  ctx.save();
  ctx.translate(w.x, w.y);
  ctx.fillStyle = "#d9c089";
  ctx.beginPath();
  ctx.moveTo(0, -16);
  ctx.lineTo(8, 8);
  ctx.lineTo(-8, 8);
  ctx.closePath();
  ctx.fill();
  ctx.restore();
}

function drawUnit(ctx, u, sim) {
  if (u.kind === "tower") return drawTower(ctx, u);
  if (u.kind === "minion") return drawMinion(ctx, u);
  if (u.kind === "dummy") return drawDummy(ctx, u, sim);
  if (u.kind === "ally") return drawAlly(ctx, u, sim);
  drawChampion(ctx, u, sim);
}

function footShadow(ctx, r) {
  ctx.fillStyle = "rgba(0,0,0,0.35)";
  ctx.beginPath();
  ctx.ellipse(0, 8, r * 0.7, r * 0.28, 0, 0, Math.PI * 2);
  ctx.fill();
}

function drawChampion(ctx, u, sim) {
  ctx.save();
  ctx.translate(u.x, u.y);
  footShadow(ctx, u.r);
  const bob = u.moving ? Math.sin(sim.time * 10) * 2 : Math.sin(sim.time * 2) * 1;
  ctx.translate(0, bob);
  ctx.rotate(0);
  ctx.fillStyle = "#141a2b";
  ctx.beginPath();
  ctx.moveTo(0, 18);
  ctx.quadraticCurveTo(-26, 8, -18, -18);
  ctx.quadraticCurveTo(-8, -46, 0, -50);
  ctx.quadraticCurveTo(8, -46, 18, -18);
  ctx.quadraticCurveTo(26, 8, 0, 18);
  ctx.fill();
  ctx.strokeStyle = "#e6d2a2";
  ctx.lineWidth = 2;
  ctx.stroke();
  ctx.fillStyle = "#f4efe4";
  ctx.beginPath();
  ctx.ellipse(0, -24, 9, 11, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = "#d4b483";
  ctx.beginPath();
  ctx.arc(0, -24, 4, 0.2, Math.PI - 0.2);
  ctx.stroke();
  const dir = u.facing;
  ctx.strokeStyle = "rgba(243,230,196,0.8)";
  ctx.beginPath();
  ctx.moveTo(0, -8);
  ctx.lineTo(Math.cos(dir) * 22, Math.sin(dir) * 10 - 8);
  ctx.stroke();
  if (u.hitFlash > 0) {
    ctx.fillStyle = "rgba(255,255,255,0.35)";
    ctx.fill();
  }
  ctx.restore();
  const meepCount = Math.max(sim.meeps, 0);
  for (let i = 0; i < meepCount; i++) {
    const a = sim.time * 1.4 + (i * Math.PI * 2) / Math.max(1, meepCount);
    drawMeep(ctx, u.x + Math.cos(a) * 34, u.y + Math.sin(a) * 14 - 20);
  }
  if (u.stasis > 0) drawCocoon(ctx, u);
  bars(ctx, u, sim, true);
  if (u.recall > 0) channel(ctx, u, 1 - u.recall / 8, "귀환");
  if (u.casting) channel(ctx, u, 1 - u.casting.t / u.casting.max, "");
}

function drawMeep(ctx, x, y) {
  ctx.save();
  ctx.translate(x, y);
  ctx.fillStyle = "#fff6d2";
  ctx.beginPath();
  ctx.moveTo(0, -7);
  ctx.quadraticCurveTo(7, 0, 0, 8);
  ctx.quadraticCurveTo(-7, 0, 0, -7);
  ctx.fill();
  ctx.restore();
}

function drawAlly(ctx, u, sim) {
  ctx.save();
  ctx.translate(u.x, u.y);
  footShadow(ctx, u.r);
  ctx.fillStyle = "#1d4c86";
  ctx.beginPath();
  ctx.ellipse(0, -6, 16, 22, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = "#d7e6f8";
  ctx.beginPath();
  ctx.arc(0, -24, 8, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = "#f2d48a";
  ctx.fillRect(-3, -8, 6, 16);
  ctx.restore();
  if (u.stasis > 0) drawCocoon(ctx, u);
  bars(ctx, u, sim, true);
}

function drawDummy(ctx, u, sim) {
  ctx.save();
  ctx.translate(u.x, u.y);
  footShadow(ctx, u.r);
  ctx.fillStyle = u.chase ? "#6a2a2a" : "#6b4a32";
  ctx.fillRect(-16, -36, 32, 48);
  ctx.fillStyle = "#e8d7c4";
  ctx.beginPath();
  ctx.arc(0, -46, 14, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = "#f0d48a";
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.arc(0, -46, 6, 0, Math.PI * 2);
  ctx.stroke();
  if (u.chase) {
    ctx.strokeStyle = "#eee";
    ctx.beginPath();
    ctx.moveTo(16, -10);
    ctx.lineTo(32, 8);
    ctx.stroke();
  }
  ctx.restore();
  if (u.stasis > 0) drawCocoon(ctx, u);
  if (u.stun > 0) stunMark(ctx, u, sim.time);
  bars(ctx, u, sim, true);
}

function drawMinion(ctx, u) {
  ctx.save();
  ctx.translate(u.x, u.y);
  footShadow(ctx, u.r);
  ctx.fillStyle = u.team === "blue" ? "#2f6fbe" : "#b23b3b";
  ctx.beginPath();
  ctx.ellipse(0, -4, u.r * 0.55, u.r * 0.75, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = "#f3e6c8";
  ctx.fillRect(-2, -u.r, u.role === "caster" ? 4 : 3, u.r);
  ctx.restore();
  if (u.stasis > 0) drawCocoon(ctx, u);
  if (u.hp < u.maxHp) bars(ctx, u, { selected: null, player: null }, false);
}

function drawTower(ctx, u) {
  ctx.save();
  ctx.translate(u.x, u.y);
  if (u.dead) {
    ctx.fillStyle = "#2a2724";
    ctx.fillRect(-28, -10, 56, 24);
    ctx.restore();
    return;
  }
  footShadow(ctx, u.r);
  ctx.fillStyle = "#4a463f";
  ctx.fillRect(-26, -48, 52, 64);
  ctx.fillStyle = u.team === "blue" ? "#7eb6ff" : "#ff8d86";
  ctx.beginPath();
  ctx.moveTo(0, -78);
  ctx.lineTo(16, -40);
  ctx.lineTo(-16, -40);
  ctx.closePath();
  ctx.fill();
  ctx.restore();
  if (u.stasis > 0) drawCocoon(ctx, u);
  bars(ctx, u, { selected: null }, false);
}

function drawCocoon(ctx, u) {
  ctx.save();
  ctx.translate(u.x, u.y - 10);
  ctx.fillStyle = "rgba(246, 231, 178, 0.28)";
  ctx.strokeStyle = "rgba(255, 244, 210, 0.9)";
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.ellipse(0, 0, u.r * 0.9, u.r * 1.25, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.stroke();
  ctx.restore();
}

function stunMark(ctx, u, time) {
  ctx.save();
  ctx.translate(u.x, u.y - u.r - 18);
  ctx.strokeStyle = "#d7e4ff";
  ctx.lineWidth = 2;
  for (let i = 0; i < 3; i++) {
    const a = time * 3 + i * 2.1;
    ctx.beginPath();
    ctx.arc(Math.cos(a) * 12, Math.sin(a) * 4, 3, 0, Math.PI * 2);
    ctx.stroke();
  }
  ctx.restore();
}

function bars(ctx, u, sim, named) {
  const w = u.kind === "tower" ? 90 : 54;
  const x = u.x - w / 2;
  const y = u.y - u.r - (u.kind === "champion" ? 62 : 48);
  ctx.fillStyle = "rgba(0,0,0,0.55)";
  ctx.fillRect(x - 1, y - 1, w + 2, 7);
  const pct = clamp(u.hp / u.maxHp, 0, 1);
  ctx.fillStyle = u.team === "blue" ? "#3ecf6e" : pct < 0.35 ? "#e23b3b" : "#e2b43b";
  if (u.team === "red") ctx.fillStyle = pct < 0.3 ? "#ff5a4a" : "#ff5d4e";
  if (u.team === "blue" && u.kind !== "champion") ctx.fillStyle = "#46a2ff";
  if (u === sim.player) ctx.fillStyle = pct < 0.3 ? "#e23d3d" : pct < 0.6 ? "#e0b14a" : "#3ecf6e";
  ctx.fillRect(x, y, w * pct, 5);
  if (named) {
    ctx.fillStyle = "#f4efe4";
    ctx.font = fontPx(13);
    ctx.textAlign = "center";
    ctx.fillText(u.name, u.x, y - 4);
  }
  if (sim.selected === u) {
    ctx.strokeStyle = "rgba(243,230,196,0.8)";
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.ellipse(u.x, u.y + 8, u.r + 8, u.r * 0.4, 0, 0, Math.PI * 2);
    ctx.stroke();
  }
}

function channel(ctx, u, pct, label) {
  const w = 64;
  ctx.fillStyle = "rgba(0,0,0,0.6)";
  ctx.fillRect(u.x - w / 2, u.y - u.r - 78, w, 6);
  ctx.fillStyle = "#f0d48a";
  ctx.fillRect(u.x - w / 2, u.y - u.r - 78, w * clamp(pct, 0, 1), 6);
  if (label) {
    ctx.fillStyle = "#f6e7b2";
    ctx.font = fontPx(12);
    ctx.textAlign = "center";
    ctx.fillText(label, u.x, u.y - u.r - 84);
  }
}

function drawUlt(ctx, ult) {
  ctx.fillStyle = "#fff6d4";
  ctx.beginPath();
  ctx.arc(ult.px, ult.py, 10, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = "rgba(246,231,178,0.4)";
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(ult.x, ult.y);
  ctx.lineTo(ult.px, ult.py);
  ctx.stroke();
}

function drawProjectile(ctx, p) {
  ctx.save();
  ctx.translate(p.x, p.y);
  if (p.kind === "q") {
    ctx.rotate(p.ang);
    ctx.fillStyle = "#fff4cf";
    ctx.fillRect(-18, -5, 36, 10);
    ctx.fillStyle = "#d4b483";
    ctx.beginPath();
    ctx.arc(16, 0, 6, 0, Math.PI * 2);
    ctx.fill();
  } else {
    ctx.fillStyle = p.meep ? "#fff6d2" : p.from?.team === "red" ? "#ffb0a8" : "#d5e4ff";
    ctx.beginPath();
    ctx.arc(0, 0, p.kind === "aa" && p.from?.kind === "tower" ? 7 : 5, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.restore();
}

function drawPing(ctx, ping, sx) {
  const colors = {
    alert: "#7eb6ff",
    danger: "#ff5d4e",
    missing: "#f0d48a",
    help: "#7eb6ff",
    omw: "#8de08a",
  };
  ctx.save();
  ctx.translate(ping.x, ping.y - 20);
  ctx.strokeStyle = colors[ping.type] || "#fff";
  ctx.lineWidth = 3;
  ctx.globalAlpha = clamp(ping.life, 0, 1);
  ctx.beginPath();
  ctx.arc(0, 0, 22, 0, Math.PI * 2);
  ctx.stroke();
  ctx.fillStyle = colors[ping.type] || "#fff";
  ctx.font = fontPx(14);
  ctx.textAlign = "center";
  ctx.fillText(ping.text, 0, -28);
  ctx.restore();
  ctx.globalAlpha = 1;
}

function drawFog(ctx, sim) {
  const fog = sim._fog || (sim._fog = document.createElement("canvas"));
  fog.width = sim.canvas.width;
  fog.height = sim.canvas.height;
  const g = fog.getContext("2d");
  g.setTransform(1, 0, 0, 1, 0, 0);
  g.clearRect(0, 0, fog.width, fog.height);
  g.fillStyle = "rgba(3, 8, 12, 0.55)";
  g.fillRect(0, 0, fog.width, fog.height);
  const { sx, sy } = worldTransform(g, sim);
  g.globalCompositeOperation = "destination-out";
  const holes = [{ x: sim.player.x, y: sim.player.y, r: 1350 }];
  for (const u of sim.units) {
    if (u.dead || u.team !== "blue") continue;
    holes.push({ x: u.x, y: u.y, r: u.kind === "tower" ? 900 : 800 });
  }
  for (const w of sim.wards) holes.push({ x: w.x, y: w.y, r: 900 });
  for (const h of holes) {
    const grd = g.createRadialGradient(h.x, h.y, h.r * 0.55, h.x, h.y, h.r);
    grd.addColorStop(0, "rgba(0,0,0,1)");
    grd.addColorStop(1, "rgba(0,0,0,0)");
    g.fillStyle = grd;
    g.beginPath();
    g.arc(h.x, h.y, h.r, 0, Math.PI * 2);
    g.fill();
  }
  void sx;
  void sy;
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  ctx.drawImage(fog, 0, 0);
}

function drawVignette(ctx, sim) {
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  const grd = ctx.createRadialGradient(
    sim.canvas.width / 2,
    sim.canvas.height / 2,
    sim.canvas.width * 0.2,
    sim.canvas.width / 2,
    sim.canvas.height / 2,
    sim.canvas.width * 0.72
  );
  grd.addColorStop(0, "rgba(0,0,0,0)");
  grd.addColorStop(1, "rgba(0,0,0,0.38)");
  ctx.fillStyle = grd;
  ctx.fillRect(0, 0, sim.canvas.width, sim.canvas.height);
}

function drawMinimap(canvas, sim) {
  if (!canvas) return;
  const dpr = Math.min(2, window.devicePixelRatio || 1);
  const size = Math.floor(188 * dpr);
  if (canvas.width !== size) {
    canvas.width = size;
    canvas.height = size;
  }
  const ctx = canvas.getContext("2d");
  const s = size / WORLD;
  ctx.setTransform(s, 0, 0, s, 0, 0);
  ctx.fillStyle = "#10211f";
  ctx.fillRect(0, 0, WORLD, WORLD);
  ctx.fillStyle = "#6d5b40";
  ctx.lineWidth = 90;
  ctx.strokeStyle = "#6d5b40";
  ctx.beginPath();
  LANE.forEach((p, i) => (i ? ctx.lineTo(p.x, p.y) : ctx.moveTo(p.x, p.y)));
  ctx.stroke();
  ctx.fillStyle = "#3a342c";
  for (const w of WALLS) ctx.fillRect(w.x, w.y, w.w, w.h);
  for (const u of sim.units) {
    if (u.dead) continue;
    if (u !== sim.player && !sim.sees(u.x, u.y)) continue;
    ctx.fillStyle = u === sim.player ? "#f0d48a" : u.team === "blue" ? "#7eb6ff" : "#ff7d74";
    ctx.beginPath();
    ctx.arc(u.x, u.y, u.kind === "tower" ? 70 : u.kind === "minion" ? 28 : 48, 0, Math.PI * 2);
    ctx.fill();
  }
  for (const c of sim.chimes) {
    ctx.fillStyle = "#fff1c2";
    ctx.fillRect(c.x - 16, c.y - 16, 32, 32);
  }
  for (const ping of sim.pings) {
    ctx.fillStyle = "#fff";
    ctx.beginPath();
    ctx.arc(ping.x, ping.y, 50, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.strokeStyle = "rgba(243,230,196,0.9)";
  ctx.lineWidth = 18;
  ctx.strokeRect(sim.cam.x, sim.cam.y, sim.viewW(), sim.viewH());
}

export function paintPortrait(canvas) {
  const ctx = canvas.getContext("2d");
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  const g = ctx.createRadialGradient(42, 36, 8, 42, 42, 48);
  g.addColorStop(0, "#31405f");
  g.addColorStop(1, "#121722");
  ctx.fillStyle = g;
  ctx.beginPath();
  ctx.arc(42, 42, 40, 0, Math.PI * 2);
  ctx.fill();
  ctx.save();
  ctx.translate(42, 50);
  ctx.fillStyle = "#1a2236";
  ctx.beginPath();
  ctx.moveTo(0, 16);
  ctx.quadraticCurveTo(-22, 6, -16, -16);
  ctx.quadraticCurveTo(-6, -40, 0, -44);
  ctx.quadraticCurveTo(6, -40, 16, -16);
  ctx.quadraticCurveTo(22, 6, 0, 16);
  ctx.fill();
  ctx.strokeStyle = "#e6d2a2";
  ctx.stroke();
  ctx.fillStyle = "#f4efe4";
  ctx.beginPath();
  ctx.ellipse(0, -18, 8, 10, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = "#d4b483";
  ctx.beginPath();
  ctx.arc(0, -18, 3.5, 0.2, Math.PI - 0.2);
  ctx.stroke();
  ctx.restore();
}

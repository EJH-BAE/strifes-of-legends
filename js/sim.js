import { ABILITIES, CHAMPION, ITEMS, LANE, MAP, VIEW_W, WALLS, WORLD } from "./data.js";
import { clamp, dist, exitSolid, firstSolid, hitsWall, lerp, lineClear } from "./geom.js";
import { buildGrid, findPath } from "./path.js";
import { play } from "./audio.js";

let UID = 1;
const nextId = () => UID++;

function statsAt(level) {
  const L = level - 1;
  return {
    maxHp: CHAMPION.hp + CHAMPION.hpL * L,
    maxMana: CHAMPION.mana + CHAMPION.manaL * L,
    ad: CHAMPION.ad + CHAMPION.adL * L,
    armor: CHAMPION.armor + CHAMPION.armorL * L,
    mr: CHAMPION.mr + CHAMPION.mrL * L,
    ms: CHAMPION.ms,
    as: CHAMPION.as,
    range: CHAMPION.range,
    mregen: CHAMPION.mregen,
  };
}

export class Simulation {
  constructor(canvas, settings, hooks) {
    this.canvas = canvas;
    this.settings = settings;
    this.hooks = hooks;
    this.walls = WALLS;
    this.grid = buildGrid(WALLS, WORLD, 80, 42);
    this.units = [];
    this.projectiles = [];
    this.shrines = [];
    this.portals = [];
    this.wards = [];
    this.chimes = [];
    this.pings = [];
    this.marks = [];
    this.floats = [];
    this.particles = [];
    this.time = 0;
    this.waveIn = 30;
    this.paused = false;
    this.shopOpen = false;
    this.aim = null;
    this.pingHold = null;
    this.rmb = false;
    this.mmb = false;
    this.shift = false;
    this.ctrl = false;
    this.alt = false;
    this.space = false;
    this.camLock = !!settings.cameraLocked;
    this.cam = { x: 0, y: 0, shake: 0 };
    this.mouse = { x: MAP.spawn.x, y: MAP.spawn.y };
    this.screen = { x: 0, y: 0 };
    this.selected = null;
    this.selectedItem = -1;
    this.gold = 500;
    this.cs = 0;
    this.kills = 0;
    this.deaths = 0;
    this.level = 6;
    this.xp = 0;
    this.points = 0;
    this.chimeCount = 0;
    this.sessionChimes = 0;
    this.casts = 0;
    this.meeps = 1;
    this.meepT = 0;
    this.oocStacks = 0;
    this.oocT = 0;
    this.flashReject = 0;
    this.inventory = [null, null, null, null, null, null];
    this.trinket = { id: "ward", count: 1 };
    this.cd = { q: 0, w: 0, e: 0, r: 0, d: 0, f: 0, ward: 0 };
    this.wCharges = 2;
    this.wChargeT = 0;
    this.base = statsAt(6);
    this.skills = { q: 3, w: 1, e: 1, r: 1 };
    this.help = true;
    this.pathAt = 0;
    this.lastDest = null;
    this.player = this.makeChampion();
    this.units.push(this.player);
    this.selected = this.player;
    this.spawnPractice();
    this.recalc();
    this.player.hp = this.player.maxHp;
    this.player.mana = this.player.maxMana;
    this.centerOn(this.player.x, this.player.y);
    this.spawnWave("blue");
    this.spawnWave("red");
    this.placeChime(1700, 4700);
    this.placeChime(2300, 4100);
    this.placeChime(3000, 2500);
    this.placeChime(3700, 2900);
    this.placeChime(4700, 1800);
    const opt = { signal: (this.ac = new AbortController()).signal };
    window.addEventListener("keydown", (e) => this.onKeyDown(e), opt);
    window.addEventListener("keyup", (e) => this.onKeyUp(e), opt);
    window.addEventListener("mousedown", (e) => this.onMouseDown(e), opt);
    window.addEventListener("mouseup", (e) => this.onMouseUp(e), opt);
    window.addEventListener("mousemove", (e) => this.onMouseMove(e), opt);
    window.addEventListener("contextmenu", (e) => {
      if (e.target === canvas) e.preventDefault();
    }, opt);
    window.addEventListener("blur", () => this.onBlur(), opt);
    window.addEventListener("resize", () => this.resize(), opt);
    this.resize();
  }

  destroy() {
    this.ac.abort();
  }

  resize() {
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    const w = this.canvas.clientWidth || window.innerWidth;
    const h = this.canvas.clientHeight || window.innerHeight;
    this.canvas.width = Math.max(1, Math.floor(w * dpr));
    this.canvas.height = Math.max(1, Math.floor(h * dpr));
    this.dpr = dpr;
  }

  viewW() {
    return VIEW_W;
  }

  viewH() {
    const c = this.canvas;
    if (!c.height) return VIEW_W * 0.5625;
    return VIEW_W * (c.height / c.width);
  }

  centerOn(x, y) {
    const vw = this.viewW();
    const vh = this.viewH();
    this.cam.x = clamp(x - vw / 2, 0, WORLD - vw);
    this.cam.y = clamp(y - vh / 2, 0, WORLD - vh);
  }

  screenToWorld(sx, sy) {
    const rect = this.canvas.getBoundingClientRect();
    const x = ((sx - rect.left) / rect.width) * this.viewW() + this.cam.x;
    const y = ((sy - rect.top) / rect.height) * this.viewH() + this.cam.y;
    return { x, y };
  }

  makeChampion() {
    const s = this.base;
    return {
      id: nextId(),
      kind: "champion",
      team: "blue",
      name: CHAMPION.name,
      x: MAP.spawn.x,
      y: MAP.spawn.y,
      r: 42,
      hp: s.maxHp,
      maxHp: s.maxHp,
      mana: s.maxMana,
      maxMana: s.maxMana,
      baseMs: s.ms,
      bonusMs: 0,
      ad: s.ad,
      ap: 0,
      armor: s.armor,
      mr: s.mr,
      as: s.as,
      range: s.range,
      facing: -0.8,
      path: null,
      forced: null,
      attackMove: null,
      atk: 0,
      windup: 0,
      windupT: 0,
      stun: 0,
      slow: 0,
      slowT: 0,
      stasis: 0,
      combat: 0,
      dead: false,
      deathT: 0,
      recall: 0,
      casting: null,
      travel: null,
      buffs: [],
      potionT: 0,
      potionLeft: 0,
      hitFlash: 0,
      moving: false,
      curMs: s.ms,
      home: { ...MAP.spawn },
    };
  }

  spawnPractice() {
    this.units.push(this.makeDummy(MAP.wallDummy.x, MAP.wallDummy.y, "벽 허수아비", false));
    this.units.push(this.makeDummy(MAP.lineDummy.x, MAP.lineDummy.y, "줄 허수아비", false));
    this.units.push(this.makeDummy(MAP.chaseDummy.x, MAP.chaseDummy.y, "전투 인형", true));
    const ally = {
      id: nextId(),
      kind: "ally",
      team: "blue",
      name: "수호자",
      x: MAP.ally.x,
      y: MAP.ally.y,
      r: 40,
      hp: 420,
      maxHp: 760,
      armor: 30,
      mr: 30,
      ad: 40,
      range: 150,
      baseMs: 325,
      bonusMs: 0,
      as: 0.65,
      facing: 0.4,
      path: null,
      forced: null,
      attackMove: null,
      atk: 0,
      windup: 0,
      windupT: 0,
      stun: 0,
      slow: 0,
      slowT: 0,
      stasis: 0,
      combat: 0,
      dead: false,
      deathT: 0,
      buffs: [],
      hitFlash: 0,
      moving: false,
      curMs: 325,
      home: { ...MAP.ally },
      hold: true,
    };
    this.units.push(ally);
    this.units.push(this.makeTower("blue", MAP.blueTower.x, MAP.blueTower.y));
    this.units.push(this.makeTower("red", MAP.redTower.x, MAP.redTower.y));
  }

  makeDummy(x, y, name, chase) {
    return {
      id: nextId(),
      kind: "dummy",
      team: "red",
      name,
      x,
      y,
      r: 44,
      hp: chase ? 900 : 1600,
      maxHp: chase ? 900 : 1600,
      armor: 30,
      mr: 30,
      ad: chase ? 48 : 0,
      range: chase ? 160 : 0,
      baseMs: chase ? 325 : 0,
      bonusMs: 0,
      as: 0.7,
      facing: Math.PI,
      path: null,
      forced: null,
      attackMove: null,
      atk: 0,
      windup: 0,
      windupT: 0,
      stun: 0,
      slow: 0,
      slowT: 0,
      stasis: 0,
      combat: 0,
      dead: false,
      deathT: 0,
      buffs: [],
      hitFlash: 0,
      moving: false,
      curMs: chase ? 325 : 0,
      home: { x, y },
      chase,
      aggro: chase ? 680 : 0,
      leash: chase ? 980 : 0,
      hold: !chase,
    };
  }

  makeTower(team, x, y) {
    return {
      id: nextId(),
      kind: "tower",
      team,
      name: team === "blue" ? "서약 포탑" : "잿불 포탑",
      x,
      y,
      r: 70,
      hp: 4200,
      maxHp: 4200,
      armor: 40,
      mr: 40,
      ad: 185,
      range: 775,
      baseMs: 0,
      as: 0.85,
      facing: team === "blue" ? -0.7 : 2.4,
      path: null,
      forced: null,
      attackMove: null,
      atk: 0,
      windup: 0,
      windupT: 0,
      stun: 0,
      slow: 0,
      slowT: 0,
      stasis: 0,
      combat: 0,
      dead: false,
      deathT: 0,
      buffs: [],
      hitFlash: 0,
      moving: false,
      curMs: 0,
      hold: true,
    };
  }

  spawnWave(team) {
    const path = team === "blue" ? LANE : [...LANE].reverse();
    const o = path[0];
    for (let i = 0; i < 3; i++) this.units.push(this.makeMinion(team, "melee", o.x - i * 36, o.y + (team === "blue" ? 28 : -28), path));
    for (let i = 0; i < 2; i++) this.units.push(this.makeMinion(team, "caster", o.x - 70, o.y + i * 40 * (team === "blue" ? 1 : -1), path));
  }

  makeMinion(team, role, x, y, path) {
    const melee = role === "melee";
    const pos = this.shove(x, y, 28);
    return {
      id: nextId(),
      kind: "minion",
      role,
      team,
      name: melee ? "전사 미니언" : "마법 미니언",
      x: pos.x,
      y: pos.y,
      r: melee ? 30 : 26,
      hp: melee ? 480 : 300,
      maxHp: melee ? 480 : 300,
      armor: 0,
      mr: 0,
      ad: melee ? 12 : 23,
      range: melee ? 115 : 520,
      baseMs: 325,
      bonusMs: 0,
      as: melee ? 0.8 : 0.7,
      facing: team === "blue" ? -0.8 : 2.3,
      path: null,
      forced: null,
      attackMove: null,
      atk: Math.random() * 0.4,
      windup: 0,
      windupT: 0,
      stun: 0,
      slow: 0,
      slowT: 0,
      stasis: 0,
      combat: 0,
      dead: false,
      deathT: 0,
      buffs: [],
      hitFlash: 0,
      moving: false,
      curMs: 325,
      lane: path,
      laneI: 1,
      gold: melee ? 21 : 14,
      xp: melee ? 48 : 30,
    };
  }

  shove(x, y, r) {
    if (!hitsWall(x, y, r, WALLS) && x > 200 && y > 200 && x < WORLD - 200 && y < WORLD - 200) return { x, y };
    for (let a = 0; a < 20; a++) {
      const ang = (a / 20) * Math.PI * 2;
      for (let d = 30; d <= 500; d += 30) {
        const nx = x + Math.cos(ang) * d;
        const ny = y + Math.sin(ang) * d;
        if (!hitsWall(nx, ny, r, WALLS) && nx > 200 && ny > 200 && nx < WORLD - 200 && ny < WORLD - 200) return { x: nx, y: ny };
      }
    }
    return { x, y };
  }

  placeChime(x, y) {
    const p = this.shove(x, y, 20);
    this.chimes.push({ id: nextId(), x: p.x, y: p.y, bob: Math.random() * Math.PI * 2 });
  }

  blocked() {
    return this.hooks.blockInput?.();
  }

  onBlur() {
    this.aim = null;
    this.pingHold = null;
    this.rmb = false;
    this.mmb = false;
    this.space = false;
    this.shift = false;
  }

  onKeyDown(e) {
    if (this.blocked()) return;
    if (e.code === "Escape") {
      this.hooks.onEscape?.();
      e.preventDefault();
      return;
    }
    if (this.paused) return;
    if (e.repeat) return;
    const keys = this.settings.keys;
    if (e.code === keys.center) this.space = true;
    if (e.code === "ShiftLeft" || e.code === "ShiftRight") this.shift = true;
    if (e.code === "ControlLeft" || e.code === "ControlRight") this.ctrl = true;
    if (e.code === "AltLeft" || e.code === "AltRight") this.alt = true;
    if (e.code === "Tab") {
      this.showTab = true;
      e.preventDefault();
    }
    const map = {
      [keys.q]: "q",
      [keys.w]: "w",
      [keys.e]: "e",
      [keys.r]: "r",
    };
    if (this.ctrl && map[e.code]) {
      this.rankUp(map[e.code]);
      e.preventDefault();
      return;
    }
    if (e.code === keys.q) this.pressSpell("q");
    else if (e.code === keys.w) this.pressSpell("w");
    else if (e.code === keys.e) this.pressSpell("e");
    else if (e.code === keys.r) this.pressSpell("r");
    else if (e.code === keys.d) this.castFlash();
    else if (e.code === keys.f) this.castHeal();
    else if (e.code === keys.recall) this.castRecall();
    else if (e.code === keys.shop) this.tryShop();
    else if (e.code === keys.stop) this.stop(this.player);
    else if (e.code === keys.amove) this.aim = this.aim?.kind === "amove" ? null : { kind: "amove" };
    else if (e.code === keys.ping) this.pingHold = { x: this.screen.x, y: this.screen.y, t: performance.now() };
    else if (e.code === keys.lock) {
      this.camLock = !this.camLock;
      this.feed(this.camLock ? "시점을 고정했습니다." : "시점 고정을 해제했습니다.");
    } else if (e.code === keys.i1) this.useSlot(0);
    else if (e.code === keys.i2) this.useSlot(1);
    else if (e.code === keys.i3) this.useSlot(2);
    else if (e.code === keys.i4) this.useSlot(3);
    else if (e.code === keys.i5) this.useSlot(4);
    else if (e.code === keys.i6) this.useSlot(5);
    else if (e.code === keys.i7) this.useSlot(6);
    if (["Space", "Tab", keys.q, keys.w, keys.e, keys.r, keys.d, keys.f, keys.recall, keys.shop].includes(e.code)) {
      e.preventDefault();
    }
  }

  onKeyUp(e) {
    if (e.code === this.settings.keys.center) this.space = false;
    if (e.code === "ShiftLeft" || e.code === "ShiftRight") this.shift = false;
    if (e.code === "ControlLeft" || e.code === "ControlRight") this.ctrl = false;
    if (e.code === "AltLeft" || e.code === "AltRight") this.alt = false;
    if (e.code === "Tab") this.showTab = false;
    if (this.blocked() || this.paused) {
      this.pingHold = null;
      return;
    }
    const keys = this.settings.keys;
    const spell = { [keys.q]: "q", [keys.w]: "w", [keys.e]: "e", [keys.r]: "r" }[e.code];
    if (spell && this.settings.castMode === "indicator" && this.aim?.kind === spell) {
      this.confirmAim(this.mouse);
    }
    if (e.code === keys.ping && this.pingHold) {
      this.releasePing();
    }
  }

  onMouseDown(e) {
    if (this.blocked() || this.paused) return;
    if (e.target !== this.canvas) return;
    this.mouse = this.screenToWorld(e.clientX, e.clientY);
    this.screen = { x: e.clientX, y: e.clientY };
    if (e.button === 1) {
      this.mmb = true;
      this.panX = e.clientX;
      this.panY = e.clientY;
      e.preventDefault();
      return;
    }
    if (e.button === 2) {
      this.rmb = true;
      if (this.aim?.kind === "amove" && !e.shiftKey) this.aim = null;
      if (e.shiftKey) this.orderAttackMove(this.player, this.mouse.x, this.mouse.y);
      else if (this.aim && this.aim.kind !== "amove") {
        this.aim = null;
        this.issueRight(this.mouse);
      } else this.issueRight(this.mouse);
      e.preventDefault();
      return;
    }
    if (e.button === 0) {
      if (this.aim?.kind === "amove") {
        this.orderAttackMove(this.player, this.mouse.x, this.mouse.y);
        this.aim = null;
        return;
      }
      if (this.aim) {
        this.confirmAim(this.mouse);
        return;
      }
      this.selected = this.pickAny(this.mouse.x, this.mouse.y) || null;
    }
  }

  onMouseUp(e) {
    if (e.button === 2) this.rmb = false;
    if (e.button === 1) this.mmb = false;
  }

  onMouseMove(e) {
    this.screen = { x: e.clientX, y: e.clientY };
    if (!this.canvas.clientWidth) return;
    this.mouse = this.screenToWorld(e.clientX, e.clientY);
    if (this.blocked() || this.paused) return;
    if (this.mmb) {
      const dx = e.clientX - this.panX;
      const dy = e.clientY - this.panY;
      this.panX = e.clientX;
      this.panY = e.clientY;
      const rect = this.canvas.getBoundingClientRect();
      this.cam.x = clamp(this.cam.x - (dx / rect.width) * this.viewW(), 0, WORLD - this.viewW());
      this.cam.y = clamp(this.cam.y - (dy / rect.height) * this.viewH(), 0, WORLD - this.viewH());
      return;
    }
    if (this.rmb && e.target === this.canvas && !this.aim) {
      if (this.shift) this.orderAttackMove(this.player, this.mouse.x, this.mouse.y);
      else this.issueRight(this.mouse);
    }
  }

  issueRight(world) {
    const portal = this.portalAt(world.x, world.y);
    if (portal && dist(this.player.x, this.player.y, portal.ax, portal.ay) < 220) {
      this.enterPortal(this.player, portal);
      return;
    }
    const enemy = this.pickEnemy(world.x, world.y);
    if (enemy) this.orderAttack(this.player, enemy);
    else this.orderMove(this.player, world.x, world.y);
  }

  pressSpell(slot) {
    const p = this.player;
    if (!this.canAct(p, true)) return;
    if (this.alt && slot === "w") {
      this.aim = null;
      this.beginCast("w", p.x, p.y);
      return;
    }
    const mode = this.settings.castMode;
    if (mode === "quick") {
      this.beginCast(slot, this.mouse.x, this.mouse.y);
      return;
    }
    this.aim = { kind: slot };
  }

  confirmAim(world) {
    if (!this.aim) return;
    const kind = this.aim.kind;
    this.aim = null;
    if (kind === "amove") {
      this.orderAttackMove(this.player, world.x, world.y);
      return;
    }
    this.beginCast(kind, world.x, world.y);
  }

  cancelTransient() {
    let used = false;
    if (this.aim) {
      this.aim = null;
      used = true;
    }
    if (this.pingHold) {
      this.pingHold = null;
      used = true;
    }
    return used;
  }

  canAct(u, silent) {
    if (!u || u.dead || u.stasis > 0 || u.stun > 0 || u.travel) {
      if (!silent && u === this.player) this.reject("cd");
      return false;
    }
    return true;
  }

  beginCast(slot, x, y) {
    const p = this.player;
    if (!this.canAct(p)) return;
    if (this.skills[slot] <= 0) {
      this.feed("아직 배우지 않은 스킬입니다.");
      this.reject("cd");
      return;
    }
    const def = ABILITIES[slot];
    if (this.cd[slot] > 0 || (slot === "w" && this.wCharges <= 0)) {
      this.reject("cd");
      return;
    }
    if (p.mana < def.cost) {
      this.feed("마나가 부족합니다.");
      this.reject("mana");
      return;
    }
    if (slot === "e") {
      const aim = this.aimE(x, y, true);
      if (!aim) {
        this.feed("그곳에는 지형이 없습니다.");
        this.reject("cd");
        return;
      }
    }
    this.cancelRecall(false);
    this.cancelWindup(p);
    p.forced = null;
    p.attackMove = null;
    p.path = null;
    const ang = Math.atan2(y - p.y, x - p.x);
    p.facing = ang;
    p.casting = { slot, x, y, t: def.cast, max: def.cast };
    this.casts++;
  }

  finishCast(cast) {
    const p = this.player;
    const def = ABILITIES[cast.slot];
    if (p.dead || p.stun > 0 || p.stasis > 0) return;
    if (p.mana < def.cost) {
      this.feed("마나가 부족합니다.");
      return;
    }
    if (cast.slot === "w" && this.wCharges <= 0) return;
    if (cast.slot !== "w" && this.cd[cast.slot] > 0) return;
    p.mana -= def.cost;
    if (cast.slot === "q") this.fireQ(cast.x, cast.y);
    if (cast.slot === "w") this.fireW(cast.x, cast.y);
    if (cast.slot === "e") this.fireE(cast.x, cast.y);
    if (cast.slot === "r") this.fireR(cast.x, cast.y);
  }

  fireQ(x, y) {
    const p = this.player;
    const rank = this.skills.q - 1;
    const def = ABILITIES.q;
    const ang = Math.atan2(y - p.y, x - p.x);
    this.cd.q = def.cd[rank];
    this.projectiles.push({
      kind: "q",
      x: p.x + Math.cos(ang) * 36,
      y: p.y + Math.sin(ang) * 36,
      ang,
      speed: def.speed,
      traveled: 0,
      max: def.range,
      extra: 0,
      width: def.width,
      dmg: def.dmg[rank] + def.ratio * p.ap,
      disable: def.disable[rank],
      from: p,
      first: null,
      hit: new Set(),
    });
    play("q");
    this.burst(p.x, p.y, "#f3e6c4", 8, 80);
  }

  fireW(x, y) {
    const p = this.player;
    const def = ABILITIES.w;
    const d = dist(p.x, p.y, x, y);
    let tx = x;
    let ty = y;
    if (d > def.range) {
      tx = p.x + ((x - p.x) / d) * def.range;
      ty = p.y + ((y - p.y) / d) * def.range;
    }
    const ally = this.units.find((u) => u.team === "blue" && !u.dead && (u.kind === "champion" || u.kind === "ally") && dist(tx, ty, u.x, u.y) < 150);
    this.wCharges--;
    if (this.wCharges < 2 && this.wChargeT <= 0) this.wChargeT = 0.001;
    play("w");
    if (ally) {
      this.consumeShrine(ally, 1);
      this.burst(ally.x, ally.y, "#d8f5c8", 14, 90);
      return;
    }
    if (this.shrines.length >= 3) this.shrines.shift();
    const spot = this.shove(tx, ty, 20);
    this.shrines.push({ x: spot.x, y: spot.y, t: 0, team: "blue" });
    this.burst(spot.x, spot.y, "#f3e6c4", 10, 40);
  }

  aimE(x, y, quiet) {
    const p = this.player;
    const d = dist(p.x, p.y, x, y) || 1;
    const dx = (x - p.x) / d;
    const dy = (y - p.y) / d;
    const hit = firstSolid(p.x, p.y, dx, dy, ABILITIES.e.range, WALLS);
    if (!hit) return null;
    const exit = exitSolid(hit.x, hit.y, dx, dy, 1800, WALLS);
    if (!exit) return null;
    const ax = hit.x - dx * 28;
    const ay = hit.y - dy * 28;
    if (hitsWall(ax, ay, 20, WALLS)) return quiet ? null : null;
    return { ax, ay, bx: exit.x, by: exit.y, dx, dy };
  }

  fireE(x, y) {
    const aim = this.aimE(x, y);
    if (!aim) {
      this.feed("그곳에는 지형이 없습니다.");
      this.player.mana += ABILITIES.e.cost;
      return;
    }
    const rank = this.skills.e - 1;
    this.cd.e = ABILITIES.e.cd[rank];
    this.portals = [{ ...aim, life: ABILITIES.e.life, team: "blue" }];
    play("e");
    this.burst(aim.ax, aim.ay, "#d7fff8", 12, 70);
    this.burst(aim.bx, aim.by, "#d7fff8", 12, 70);
  }

  fireR(x, y) {
    const p = this.player;
    const def = ABILITIES.r;
    const d = dist(p.x, p.y, x, y);
    const reach = Math.min(d, def.range);
    const ang = Math.atan2(y - p.y, x - p.x);
    const tx = p.x + Math.cos(ang) * reach;
    const ty = p.y + Math.sin(ang) * reach;
    const ratio = clamp(reach / def.range, 0, 1);
    const travel = lerp(0.65, 1.8, ratio);
    this.cd.r = def.cd[this.skills.r - 1];
    this.ult = { x: p.x, y: p.y - 20, tx, ty, t: 0, dur: travel };
    play("r");
  }

  castFlash() {
    const p = this.player;
    if (!this.canAct(p)) return;
    if (this.cd.d > 0) {
      this.reject("cd");
      return;
    }
    let ang = Math.atan2(this.mouse.y - p.y, this.mouse.x - p.x);
    let d = dist(p.x, p.y, this.mouse.x, this.mouse.y);
    if (d < 12) {
      ang = p.facing;
      d = ABILITIES.d.range;
    }
    d = Math.min(ABILITIES.d.range, d);
    const tx = p.x + Math.cos(ang) * d;
    const ty = p.y + Math.sin(ang) * d;
    let dest;
    if (!hitsWall(tx, ty, p.r, WALLS)) dest = { x: tx, y: ty };
    else {
      let lo = 0;
      let hi = d;
      for (let i = 0; i < 14; i++) {
        const mid = (lo + hi) / 2;
        const mx = p.x + Math.cos(ang) * mid;
        const my = p.y + Math.sin(ang) * mid;
        if (hitsWall(mx, my, p.r, WALLS)) hi = mid;
        else lo = mid;
      }
      dest = { x: p.x + Math.cos(ang) * lo, y: p.y + Math.sin(ang) * lo };
    }
    this.cancelRecall(false);
    this.cancelWindup(p);
    p.casting = null;
    p.path = null;
    this.burst(p.x, p.y, "#cfe7ff", 10, 90);
    p.x = dest.x;
    p.y = dest.y;
    p.facing = ang;
    this.cd.d = ABILITIES.d.cd;
    this.burst(p.x, p.y, "#e7f2ff", 14, 120);
    play("flash");
  }

  castHeal() {
    const p = this.player;
    if (!this.canAct(p)) return;
    if (this.cd.f > 0) {
      this.reject("cd");
      return;
    }
    const amount = 80 + 14 * (this.level - 1);
    this.heal(p, amount);
    let ally = null;
    let best = Infinity;
    for (const u of this.units) {
      if (u === p || u.team !== "blue" || u.dead || u.stasis > 0) continue;
      if (u.kind !== "ally" && u.kind !== "champion") continue;
      const dd = dist(p.x, p.y, u.x, u.y);
      if (dd > ABILITIES.f.range) continue;
      const pct = u.hp / u.maxHp;
      if (pct < best) {
        best = pct;
        ally = u;
      }
    }
    if (ally) this.heal(ally, amount);
    const boost = (u) => u.buffs.push({ kind: "ms", amt: 0.3, t: 1, max: 1 });
    boost(p);
    if (ally) boost(ally);
    this.cd.f = ABILITIES.f.cd;
    this.cancelRecall(false);
    play("heal");
  }

  castRecall() {
    const p = this.player;
    if (!this.canAct(p)) return;
    if (dist(p.x, p.y, MAP.fountain.x, MAP.fountain.y) < 80) {
      this.feed("이미 기지 한가운데 있습니다.");
      return;
    }
    this.cancelWindup(p);
    p.casting = null;
    p.path = null;
    p.forced = null;
    p.attackMove = null;
    p.recall = 8;
    play("recall");
    this.feed("귀환을 시작합니다.");
  }

  cancelRecall(msg) {
    if (this.player.recall > 0) {
      this.player.recall = 0;
      if (msg) this.feed("귀환이 취소되었습니다.");
    }
  }

  tryShop() {
    const p = this.player;
    const near = dist(p.x, p.y, MAP.fountain.x, MAP.fountain.y) <= MAP.fountain.r;
    if (this.shopOpen) {
      this.shopOpen = false;
      this.hooks.onShop?.(false);
      return;
    }
    if (!near) {
      this.feed("상점 범위 밖에 있습니다.");
      play("error");
      return;
    }
    this.shopOpen = true;
    this.hooks.onShop?.(true);
  }

  stop(u) {
    if (!u || u.dead) return;
    u.path = null;
    u.forced = null;
    u.attackMove = null;
    this.cancelWindup(u);
    if (u === this.player) {
      u.casting = null;
      this.cancelRecall(u.recall > 0);
      this.aim = null;
    }
  }

  orderMove(u, x, y) {
    if (!this.canAct(u, true) || u.casting) {
      if (u === this.player && u.casting) {
        u.casting = null;
      } else if (u.stun > 0 || u.stasis > 0 || u.dead || u.travel) return;
    }
    if (u === this.player && u.recall > 0) this.cancelRecall(true);
    const dest = this.clampDest(u.x, u.y, x, y, u.r);
    u.forced = null;
    u.attackMove = null;
    this.setPath(u, dest.x, dest.y);
    if (u === this.player) {
      this.marks.push({ x: dest.x, y: dest.y, life: 0.35, max: 0.35, kind: "move" });
      play("move");
    }
  }

  orderAttack(u, target) {
    if (!target || target.dead) return;
    if (u === this.player && !this.canAct(u, true)) return;
    if (u === this.player && u.casting) u.casting = null;
    if (u === this.player && u.recall > 0) this.cancelRecall(true);
    u.forced = target;
    u.attackMove = null;
    if (u === this.player) {
      this.marks.push({ x: target.x, y: target.y, life: 0.3, max: 0.3, kind: "attack" });
      play("attack");
    }
  }

  orderAttackMove(u, x, y) {
    if (u === this.player && u.stun > 0) return;
    if (u === this.player && u.casting) u.casting = null;
    if (u === this.player && u.recall > 0) this.cancelRecall(true);
    const dest = this.clampDest(u.x, u.y, x, y, u.r);
    u.forced = null;
    u.attackMove = { x: dest.x, y: dest.y };
    this.setPath(u, dest.x, dest.y);
    if (u === this.player) this.marks.push({ x: dest.x, y: dest.y, life: 0.35, max: 0.35, kind: "attack" });
  }

  clampDest(px, py, x, y, r) {
    if (!hitsWall(x, y, r, WALLS)) return { x, y };
    let lo = 0;
    let hi = 1;
    for (let i = 0; i < 12; i++) {
      const mid = (lo + hi) / 2;
      const mx = px + (x - px) * mid;
      const my = py + (y - py) * mid;
      if (hitsWall(mx, my, r, WALLS)) hi = mid;
      else lo = mid;
    }
    return { x: px + (x - px) * lo, y: py + (y - py) * lo };
  }

  setPath(u, x, y) {
    const now = this.time;
    if (u === this.player && this.lastDest && now - this.pathAt < 0.07 && dist(this.lastDest.x, this.lastDest.y, x, y) < 36) {
      return;
    }
    u.path = findPath(this.grid, u.x, u.y, x, y, WALLS, u.r);
    if (u === this.player) {
      this.pathAt = now;
      this.lastDest = { x, y };
    }
  }

  pickAny(x, y) {
    let best = null;
    let bestD = 1e9;
    for (const u of this.units) {
      if (u.dead && u.kind !== "tower") continue;
      if (!this.sees(u.x, u.y) && u !== this.player) continue;
      const d = dist(x, y, u.x, u.y);
      if (d < u.r + 26 && d < bestD) {
        best = u;
        bestD = d;
      }
    }
    return best;
  }

  pickEnemy(x, y) {
    let best = null;
    let bestD = 1e9;
    for (const u of this.units) {
      if (u.dead || u.team === "blue") continue;
      if (!this.sees(u.x, u.y)) continue;
      const d = dist(x, y, u.x, u.y);
      if (d < u.r + 30 && d < bestD) {
        best = u;
        bestD = d;
      }
    }
    return best;
  }

  portalAt(x, y) {
    for (const portal of this.portals) {
      if (dist(x, y, portal.ax, portal.ay) < 80) return portal;
    }
    return null;
  }

  enterPortal(u, portal) {
    if (!u || u.dead || u.stun > 0 || u.stasis > 0 || u.travel) return;
    if (u.kind === "minion" || u.kind === "tower") return;
    const length = dist(portal.ax, portal.ay, portal.bx, portal.by);
    const speed = u.team === "blue" ? ABILITIES.e.allySpeed : ABILITIES.e.speed;
    u.travel = { portal, t: 0, dur: Math.max(0.18, length / speed) };
    u.path = null;
    u.forced = null;
    u.attackMove = null;
    u.casting = null;
    this.cancelWindup(u);
    if (u === this.player && u.recall > 0) this.cancelRecall(true);
  }

  rankUp(slot) {
    const cap = slot === "r" ? 3 : 5;
    if (this.points <= 0 || this.skills[slot] >= cap) return;
    if (slot === "r") {
      const need = [6, 11, 16][this.skills.r];
      if (this.level < need) {
        this.feed(`궁극기는 ${need}레벨에 올릴 수 있습니다.`);
        return;
      }
    }
    this.skills[slot]++;
    this.points--;
    play("level");
  }

  useSlot(index) {
    const p = this.player;
    if (!this.canAct(p)) return;
    if (index === 6) {
      this.useWard();
      return;
    }
    const item = this.inventory[index];
    if (!item) return;
    this.selectedItem = index;
    if (item.id === "potion") this.usePotion(item);
  }

  usePotion(item) {
    const p = this.player;
    if (p.potionT > 0) {
      this.feed("이미 물약을 마시고 있습니다.");
      return;
    }
    if (p.hp >= p.maxHp) {
      this.feed("체력이 가득 찼습니다.");
      return;
    }
    item.count--;
    if (item.count <= 0) {
      const idx = this.inventory.indexOf(item);
      if (idx >= 0) this.inventory[idx] = null;
    }
    p.potionT = 15;
    p.potionLeft = 150;
    play("heal");
  }

  useWard() {
    const p = this.player;
    if (this.cd.ward > 0) {
      this.reject("cd");
      return;
    }
    const d = dist(p.x, p.y, this.mouse.x, this.mouse.y);
    const reach = Math.min(600, d);
    const ang = d < 4 ? p.facing : Math.atan2(this.mouse.y - p.y, this.mouse.x - p.x);
    let x = p.x + Math.cos(ang) * reach;
    let y = p.y + Math.sin(ang) * reach;
    const spot = this.shove(x, y, 16);
    this.wards.push({ x: spot.x, y: spot.y, life: 90, team: "blue" });
    this.cd.ward = 90;
    this.burst(spot.x, spot.y, "#f3e6c4", 8, 40);
    play("w");
  }

  buy(id) {
    const def = ITEMS[id];
    if (!def || def.trinket) return;
    if (!this.shopOpen) return;
    if (this.gold < def.cost) {
      this.feed("골드가 부족합니다.");
      play("error");
      return;
    }
    if (def.stack) {
      const stack = this.inventory.find((s) => s && s.id === id && s.count < def.stack);
      if (stack) {
        stack.count++;
        this.gold -= def.cost;
        this.recalc();
        play("coin");
        return;
      }
    }
    const empty = this.inventory.findIndex((s) => !s);
    if (empty < 0) {
      this.feed("가방이 가득 찼습니다.");
      play("error");
      return;
    }
    this.inventory[empty] = { id, count: 1 };
    this.gold -= def.cost;
    this.recalc();
    play("coin");
  }

  sell(index) {
    if (!this.shopOpen) return;
    const item = this.inventory[index];
    if (!item) return;
    const def = ITEMS[item.id];
    const price = Math.floor(def.cost * (def.sell ?? 0.7));
    item.count--;
    this.gold += price;
    if (item.count <= 0) this.inventory[index] = null;
    this.recalc();
    play("coin");
  }

  swapSlots(a, b) {
    if (a === b || a < 0 || b < 0 || a > 5 || b > 5) return;
    const tmp = this.inventory[a];
    this.inventory[a] = this.inventory[b];
    this.inventory[b] = tmp;
    this.recalc();
  }

  recalc() {
    const b = this.base;
    let hp = b.maxHp;
    let mana = b.maxMana;
    let ad = b.ad;
    let armor = b.armor;
    let mr = b.mr;
    let ms = 0;
    let as = 0;
    let ap = 0;
    let mregen = b.mregen;
    for (const slot of this.inventory) {
      if (!slot) continue;
      const def = ITEMS[slot.id];
      const n = slot.count || 1;
      if (def.hp) hp += def.hp * (def.stack ? 1 : n);
      if (def.ms) ms += def.ms;
      if (def.ap) ap += def.ap;
      if (def.armor) armor += def.armor;
      if (def.mr) mr += def.mr;
      if (def.as) as += def.as;
      if (def.mregen) mregen += def.mregen;
    }
    const p = this.player;
    const hpPct = p.maxHp ? p.hp / p.maxHp : 1;
    const manaPct = p.maxMana ? p.mana / p.maxMana : 1;
    p.maxHp = hp;
    p.maxMana = mana;
    p.hp = Math.min(hp, p.hp || hpPct * hp);
    p.mana = Math.min(mana, p.mana || manaPct * mana);
    p.ad = ad;
    p.ap = ap;
    p.armor = armor;
    p.mr = mr;
    p.baseMs = b.ms;
    p.bonusMs = ms;
    p.as = b.as * (1 + as);
    p.range = b.range;
    p.mregen = mregen;
  }

  reject(kind) {
    this.flashReject = kind;
    this.rejectT = 0.25;
    play("error");
  }

  feed(text) {
    this.hooks.onFeed?.(text);
  }

  releasePing() {
    const hold = this.pingHold;
    this.pingHold = null;
    if (!hold) return;
    const dx = this.screen.x - hold.x;
    const dy = this.screen.y - hold.y;
    const held = performance.now() - hold.t;
    let type = "alert";
    if (Math.hypot(dx, dy) > 28 || held > 280) {
      const ang = Math.atan2(dy, dx);
      const deg = (ang * 180) / Math.PI;
      if (deg < -45 && deg >= -135) type = "danger";
      else if (deg >= 45 && deg < 135) type = "help";
      else if (Math.abs(deg) > 135) type = "missing";
      else type = "omw";
    }
    const labels = {
      alert: "주의",
      danger: "위험!",
      missing: "적 사라짐!",
      help: "도와주세요!",
      omw: "갑니다!",
    };
    const unit = this.pickAny(this.mouse.x, this.mouse.y);
    const text = unit ? `${unit.name} · ${labels[type]}` : labels[type];
    this.pings.push({
      x: unit ? unit.x : this.mouse.x,
      y: unit ? unit.y : this.mouse.y,
      type,
      text,
      life: 4,
      unit: unit && type !== "alert" ? unit : unit && type === "alert" ? unit : null,
    });
    this.feed(text);
    play("ping");
  }

  update(dt) {
    if (this.paused) return;
    this.time += dt;
    if (this.rejectT > 0) this.rejectT -= dt;
    if (this.cam.shake > 0) this.cam.shake = Math.max(0, this.cam.shake - dt * 18);
    this.updateCooldowns(dt);
    this.updatePlayer(dt);
    this.updateUlt(dt);
    for (const u of this.units) this.updateUnit(u, dt);
    this.separate(dt);
    this.updateProjectiles(dt);
    this.updateShrines(dt);
    this.updatePortals(dt);
    this.updateWards(dt);
    this.updateChimes(dt);
    this.updateWaves(dt);
    this.updateFx(dt);
    this.updateCamera();
    if (this.shopOpen && dist(this.player.x, this.player.y, MAP.fountain.x, MAP.fountain.y) > MAP.fountain.r + 40) {
      this.shopOpen = false;
      this.hooks.onShop?.(false);
    }
  }

  updateCooldowns(dt) {
    for (const k of ["q", "e", "r", "d", "f", "ward"]) {
      if (this.cd[k] > 0) this.cd[k] = Math.max(0, this.cd[k] - dt);
    }
    if (this.wCharges < 2) {
      this.wChargeT += dt;
      if (this.wChargeT >= ABILITIES.w.recharge) {
        this.wCharges++;
        this.wChargeT = this.wCharges < 2 ? 0 : 0;
      }
    }
  }

  updatePlayer(dt) {
    const p = this.player;
    if (p.dead) return;
    if (p.combat > 0) p.combat -= dt;
    if (this.oocT > 0) {
      this.oocT -= dt;
      if (this.oocT <= 0) this.oocStacks = 0;
    }
    const maxMeeps = Math.min(4, 1 + Math.floor(this.chimeCount / 10));
    const interval = Math.max(4, 8 - Math.floor(this.chimeCount / 20));
    if (this.meeps < maxMeeps) {
      this.meepT += dt;
      if (this.meepT >= interval) {
        this.meeps++;
        this.meepT = 0;
      }
    }
    this.meepMax = maxMeeps;
    this.meepInterval = interval;
    if (p.potionT > 0 && p.potionLeft > 0) {
      const step = Math.min(p.potionLeft, (150 / 15) * dt);
      p.potionLeft -= step;
      p.potionT -= dt;
      this.heal(p, step, true);
    }
    if (dist(p.x, p.y, MAP.fountain.x, MAP.fountain.y) <= MAP.fountain.r && p.stasis <= 0) {
      p.hp = Math.min(p.maxHp, p.hp + p.maxHp * 0.34 * dt);
      p.mana = Math.min(p.maxMana, p.mana + p.maxMana * 0.34 * dt);
    } else if (p.stasis <= 0) {
      p.hp = Math.min(p.maxHp, p.hp + (p.combat > 0 ? 0.35 : 1.15) * dt);
      p.mana = Math.min(p.maxMana, p.mana + p.mregen * dt);
    }
    if (p.casting) {
      p.casting.t -= dt;
      if (p.casting.t <= 0) {
        const cast = p.casting;
        p.casting = null;
        this.finishCast(cast);
      }
    }
    if (p.recall > 0) {
      p.recall -= dt;
      if (p.recall <= 0) {
        p.recall = 0;
        const spot = this.shove(MAP.spawn.x, MAP.spawn.y, p.r);
        p.x = spot.x;
        p.y = spot.y;
        p.path = null;
        this.feed("기지로 돌아왔습니다.");
        play("recall");
        this.burst(p.x, p.y, "#f3e6c4", 16, 80);
      }
    }
  }

  updateUlt(dt) {
    if (!this.ult) return;
    this.ult.t += dt;
    const t = clamp(this.ult.t / this.ult.dur, 0, 1);
    const arc = Math.sin(t * Math.PI) * 180;
    this.ult.px = lerp(this.ult.x, this.ult.tx, t);
    this.ult.py = lerp(this.ult.y, this.ult.ty, t) - arc;
    if (this.settings.particles === "high" && Math.random() < 0.8) {
      this.particles.push({
        x: this.ult.px,
        y: this.ult.py,
        vx: 0,
        vy: -10,
        life: 0.4,
        max: 0.4,
        color: "#f6e7b2",
        size: 3,
      });
    }
    if (this.ult.t >= this.ult.dur) {
      this.impactUlt(this.ult.tx, this.ult.ty);
      this.ult = null;
    }
  }

  impactUlt(x, y) {
    const r = ABILITIES.r.radius;
    for (const u of this.units) {
      if (u.dead) continue;
      if (dist(u.x, u.y, x, y) <= r + u.r * 0.25) {
        u.stasis = ABILITIES.r.stasis;
        u.path = null;
        u.forced = null;
        u.attackMove = null;
        u.casting = null;
        u.windup = 0;
        if (u === this.player) this.cancelRecall(false);
      }
    }
    this.marks.push({ x, y, life: 2.5, max: 2.5, kind: "stasis", r });
    if (this.settings.shake) this.cam.shake = 10;
    this.burst(x, y, "#f6e7b2", 24, 160);
    play("r");
  }

  updateUnit(u, dt) {
    if (u.hitFlash > 0) u.hitFlash -= dt;
    if (u.dead) {
      if (u.deathT < Infinity) {
        u.deathT -= dt;
        if (u.deathT <= 0) this.respawn(u);
      }
      return;
    }
    if (u.stasis > 0) {
      u.stasis -= dt;
      u.moving = false;
      return;
    }
    if (u.slowT > 0) u.slowT -= dt;
    if (u.stun > 0) {
      u.stun -= dt;
      u.moving = false;
      u.path = null;
      return;
    }
    if (u.buffs) {
      for (const b of u.buffs) b.t -= dt;
      u.buffs = u.buffs.filter((b) => b.t > 0);
    }
    if (u.travel) {
      u.travel.t += dt;
      const portal = u.travel.portal;
      const t = clamp(u.travel.t / u.travel.dur, 0, 1);
      u.x = lerp(portal.ax, portal.bx, t);
      u.y = lerp(portal.ay, portal.by, t);
      u.moving = true;
      if (t >= 1) {
        const spot = this.shove(portal.bx, portal.by, u.r);
        u.x = spot.x;
        u.y = spot.y;
        u.travel = null;
        u.moving = false;
      }
      return;
    }
    if (u.combat > 0 && u !== this.player) u.combat -= dt;
    if (u.kind === "tower") {
      this.updateTower(u, dt);
      return;
    }
    if (u !== this.player) this.runAI(u, dt);
    if (u.casting || u.recall) {
      u.moving = false;
      return;
    }
    this.updateCombatOrder(u, dt);
    this.updateMovement(u, dt);
  }

  runAI(u) {
    if (u.hold && u.kind !== "minion") return;
    if (u.kind === "dummy" && u.chase) {
      const homeD = dist(u.x, u.y, u.home.x, u.home.y);
      const pd = dist(u.x, u.y, this.player.x, this.player.y);
      if (homeD > u.leash || this.player.dead || !this.sees(this.player.x, this.player.y)) {
        u.forced = null;
        if (homeD > 30) this.setPath(u, u.home.x, u.home.y);
        if (u.combat <= 0) u.hp = Math.min(u.maxHp, u.hp + 80 * 0.016);
        return;
      }
      if (pd < u.aggro || u.combat > 0) u.forced = this.player;
      else if (homeD > 24) {
        u.forced = null;
        this.setPath(u, u.home.x, u.home.y);
      }
      return;
    }
    if (u.kind === "ally") return;
    if (u.kind === "minion") {
      const foe = this.nearestFoe(u, 520);
      if (foe) {
        u.forced = foe;
        return;
      }
      u.forced = null;
      const wp = u.lane[Math.min(u.laneI, u.lane.length - 1)];
      if (dist(u.x, u.y, wp.x, wp.y) < 50) {
        if (u.laneI < u.lane.length - 1) u.laneI++;
      } else if (!u.path) this.setPath(u, wp.x, wp.y);
    }
  }

  nearestFoe(u, radius) {
    let best = null;
    let bestD = radius;
    for (const o of this.units) {
      if (o.dead || o.team === u.team || o.stasis > 0) continue;
      if (o.kind === "tower" && dist(u.x, u.y, o.x, o.y) > radius) continue;
      const d = dist(u.x, u.y, o.x, o.y);
      if (d < bestD) {
        best = o;
        bestD = d;
      }
    }
    return best;
  }

  updateTower(u, dt) {
    if (u.atk > 0) u.atk -= dt;
    if (u.windup > 0) {
      u.windup -= dt;
      if (u.windup <= 0) this.fireAuto(u);
      return;
    }
    let target = null;
    let best = u.range;
    for (const o of this.units) {
      if (o.dead || o.team === u.team || o.kind === "tower") continue;
      const d = dist(u.x, u.y, o.x, o.y);
      if (d > u.range + 10) continue;
      const pri = o.kind === "minion" ? 0 : 1;
      const score = d + pri * 1000;
      if (!target || score < best) {
        target = o;
        best = score;
      }
    }
    if (target && u.atk <= 0 && lineClear(u.x, u.y, target.x, target.y, WALLS, 8)) {
      u.forced = target;
      u.facing = Math.atan2(target.y - u.y, target.x - u.x);
      u.windupT = 0.25;
      u.windup = 0.25;
    }
  }

  updateCombatOrder(u, dt) {
    if (u.atk > 0) u.atk -= dt;
    if (u.attackMove) {
      const foe = this.foeInRange(u);
      if (foe) u.forced = foe;
      else if (u.forced && (u.forced.dead || dist(u.x, u.y, u.forced.x, u.forced.y) > u.range + u.forced.r)) {
        u.forced = null;
      }
    }
    const target = u.forced;
    if (target) {
      if (target.dead || target.stasis > 0) {
        u.forced = null;
        return;
      }
      const reach = (u.range || 0) + target.r * 0.25;
      const d = dist(u.x, u.y, target.x, target.y);
      const clear = lineClear(u.x, u.y, target.x, target.y, WALLS, 6);
      if (d <= reach && clear && u.range > 0) {
        u.path = null;
        u.facing = Math.atan2(target.y - u.y, target.x - u.x);
        if (u.windup <= 0 && u.atk <= 0 && u.ad > 0) {
          const wind = Math.max(0.18, 0.32 / (u.as || 0.6));
          u.windup = wind;
          u.windupT = wind;
        }
      } else if (!u.hold) {
        const end = u.path && u.path[u.path.length - 1];
        if (!end || dist(end.x, end.y, target.x, target.y) > 56) this.setPath(u, target.x, target.y);
      }
    } else if (u.attackMove && !u.path) {
      this.setPath(u, u.attackMove.x, u.attackMove.y);
    }
  }

  foeInRange(u) {
    let best = null;
    let bestD = (u.range || 0) + 20;
    for (const o of this.units) {
      if (o.dead || o.team === u.team || o.stasis > 0) continue;
      const d = dist(u.x, u.y, o.x, o.y);
      if (d <= (u.range || 0) + o.r * 0.25 && d < bestD && lineClear(u.x, u.y, o.x, o.y, WALLS, 6)) {
        best = o;
        bestD = d;
      }
    }
    return best;
  }

  updateMovement(u, dt) {
    if (u.windup > 0 && !u.path) {
      u.windup -= dt;
      u.moving = false;
      if (u.windup <= 0) this.fireAuto(u);
      return;
    }
    if (!u.path || !u.path.length) {
      u.moving = false;
      if (u.windup > 0) {
        u.windup -= dt;
        if (u.windup <= 0) this.fireAuto(u);
      }
      if (u.attackMove && dist(u.x, u.y, u.attackMove.x, u.attackMove.y) < 24) u.attackMove = null;
      return;
    }
    const wp = u.path[0];
    const d = dist(u.x, u.y, wp.x, wp.y);
    if (d < 14) {
      u.path.shift();
      if (u.path.length) {
        while (u.path.length > 1 && lineClear(u.x, u.y, u.path[0].x, u.path[0].y, WALLS, u.r)) {
          /* keep the nearest visible corner */
          break;
        }
      }
      u.moving = false;
      return;
    }
    const ms = this.moveSpeed(u);
    const step = Math.min(d, ms * dt);
    const ang = Math.atan2(wp.y - u.y, wp.x - u.x);
    const dx = Math.cos(ang) * step;
    const dy = Math.sin(ang) * step;
    const beforeX = u.x;
    const beforeY = u.y;
    if (!hitsWall(u.x + dx, u.y + dy, u.r, WALLS)) {
      u.x += dx;
      u.y += dy;
    } else if (!hitsWall(u.x + dx, u.y, u.r, WALLS)) u.x += dx;
    else if (!hitsWall(u.x, u.y + dy, u.r, WALLS)) u.y += dy;
    else u.path = null;
    const moved = Math.hypot(u.x - beforeX, u.y - beforeY);
    u.moving = moved > 0.5;
    if (moved > 0.5) {
      u.facing = ang;
      if (u.windup > 0) this.cancelWindup(u);
    }
  }

  moveSpeed(u) {
    let ms = (u.baseMs || 0) + (u.bonusMs || 0);
    if (u.slowT > 0) ms *= 1 - (u.slow || 0);
    if (u.buffs) {
      let bonus = 0;
      for (const b of u.buffs) if (b.kind === "ms") bonus += b.amt * (b.t / b.max);
      ms *= 1 + bonus;
    }
    if (u === this.player && this.player.combat <= 0 && this.oocStacks > 0) {
      ms *= 1 + (0.24 + (this.oocStacks - 1) * 0.14);
    }
    u.curMs = ms;
    return ms;
  }

  cancelWindup(u) {
    if (u.windup > 0) {
      u.windup = 0;
      u.windupT = 0;
    }
  }

  fireAuto(u) {
    const target = u.forced;
    if (!target || target.dead || target.stasis > 0) return;
    const reach = (u.range || 0) + target.r * 0.35 + 40;
    if (dist(u.x, u.y, target.x, target.y) > reach) return;
    u.atk = 1 / (u.as || 0.6);
    const meep = u === this.player && this.meeps > 0 && target.kind !== "tower";
    if (meep) this.meeps--;
    this.projectiles.push({
      kind: "aa",
      x: u.x,
      y: u.y - 8,
      speed: u.kind === "tower" ? 1100 : 1500,
      dmg: u.ad,
      dtype: "physical",
      from: u,
      target,
      meep,
      life: 2.2,
    });
    if (u === this.player) play("attack");
  }

  updateProjectiles(dt) {
    for (let i = this.projectiles.length - 1; i >= 0; i--) {
      const p = this.projectiles[i];
      if (p.kind === "aa") {
        if (!p.target || p.target.dead || p.target.stasis > 0) {
          this.projectiles.splice(i, 1);
          continue;
        }
        const ang = Math.atan2(p.target.y - p.y, p.target.x - p.x);
        p.x += Math.cos(ang) * p.speed * dt;
        p.y += Math.sin(ang) * p.speed * dt;
        p.life -= dt;
        if (dist(p.x, p.y, p.target.x, p.target.y) < p.target.r + 12) {
          this.deal(p.from, p.target, p.dmg, "physical");
          if (p.meep) this.meepImpact(p.target);
          this.projectiles.splice(i, 1);
        } else if (p.life <= 0) this.projectiles.splice(i, 1);
        continue;
      }
      const step = p.speed * dt;
      p.x += Math.cos(p.ang) * step;
      p.y += Math.sin(p.ang) * step;
      p.traveled += step;
      if (p.first) p.extra += step;
      let done = false;
      if (hitsWall(p.x, p.y, 10, WALLS)) {
        if (p.first) this.applyStun(p.first, p.disable);
        done = true;
      }
      if (!done) {
        for (const u of this.units) {
          if (u.dead || u.team === "blue" || u.kind === "tower" || p.hit.has(u.id)) continue;
          if (dist(p.x, p.y, u.x, u.y) > p.width / 2 + u.r * 0.45) continue;
          p.hit.add(u.id);
          this.deal(p.from, u, p.dmg, "magic");
          if (!p.first) {
            p.first = u;
            this.applySlow(u, ABILITIES.q.slow, p.disable);
          } else {
            this.applyStun(p.first, p.disable);
            this.applyStun(u, p.disable);
            done = true;
            break;
          }
        }
      }
      if (!done && p.first && p.extra >= ABILITIES.q.extra) done = true;
      if (!done && !p.first && p.traveled >= p.max) done = true;
      if (done) {
        this.burst(p.x, p.y, "#f6e7b2", 6, 50);
        this.projectiles.splice(i, 1);
      }
    }
  }

  meepImpact(target) {
    const p = this.player;
    const dmg = 30 + 6 * Math.floor(this.chimeCount / 5) + 0.4 * p.ap;
    this.deal(p, target, dmg, "magic");
    const slow = this.chimeCount >= 5 ? Math.min(0.75, 0.25 + Math.floor((this.chimeCount - 5) / 10) * 0.1) : 0;
    if (slow) this.applySlow(target, slow, 1);
    if (this.chimeCount >= 15) {
      const splash = this.chimeCount >= 35 ? 250 : 180;
      for (const u of this.units) {
        if (u === target || u.dead || u.team === "blue" || u.kind === "tower") continue;
        if (dist(u.x, u.y, target.x, target.y) <= splash) {
          this.deal(p, u, dmg, "magic");
          if (slow) this.applySlow(u, slow, 1);
        }
      }
    }
    this.burst(target.x, target.y, "#fff1c2", 8, 70);
  }

  applyStun(u, dur) {
    if (!u || u.dead || u.kind === "tower" || u.stasis > 0) return;
    u.stun = Math.max(u.stun, dur);
    u.slowT = 0;
    u.path = null;
    u.windup = 0;
    u.casting = null;
    if (u === this.player) this.cancelRecall(u.recall > 0);
  }

  applySlow(u, amt, dur) {
    if (!u || u.dead || u.kind === "tower" || u.stasis > 0 || u.stun > 0) return;
    if (u.slowT < dur || amt >= (u.slow || 0)) {
      u.slow = amt;
      u.slowT = dur;
    }
  }

  deal(from, target, amount, type) {
    if (!target || target.dead || target.stasis > 0 || amount <= 0) return 0;
    let dealt = amount;
    if (type === "physical") dealt *= 100 / (100 + (target.armor || 0));
    if (type === "magic") dealt *= 100 / (100 + (target.mr || 0));
    dealt = Math.max(1, dealt);
    target.hp -= dealt;
    target.hitFlash = 0.08;
    target.combat = 4;
    if (from) from.combat = 4;
    if (target === this.player) this.player.combat = 5;
    if (from === this.player) this.player.combat = 5;
    if (target.recall > 0 || (target === this.player && this.player.recall > 0)) this.cancelRecall(true);
    if (this.settings.damageNumbers) {
      this.floats.push({
        x: target.x + (Math.random() - 0.5) * 20,
        y: target.y - target.r - 10,
        vy: -28,
        life: 0.7,
        max: 0.7,
        text: `${Math.round(dealt)}`,
        color: type === "magic" ? "#d7c4ff" : "#f4f1ea",
      });
    }
    if (target.hp <= 0) this.kill(target, from);
    else if (from && target.kind === "dummy") target.forced = target.forced || (target.chase ? from : null);
    return dealt;
  }

  heal(u, amount, silent) {
    if (!u || u.dead || u.stasis > 0 || amount <= 0) return;
    const before = u.hp;
    u.hp = Math.min(u.maxHp, u.hp + amount);
    const got = u.hp - before;
    if (!silent && got > 0.5 && this.settings.damageNumbers) {
      this.floats.push({
        x: u.x,
        y: u.y - u.r - 16,
        vy: -24,
        life: 0.7,
        max: 0.7,
        text: `+${Math.round(got)}`,
        color: "#b6f0a8",
      });
    }
  }

  kill(target, from) {
    target.dead = true;
    target.hp = 0;
    target.path = null;
    target.forced = null;
    target.casting = null;
    target.windup = 0;
    if (target.kind === "minion") {
      target.deathT = 0.01;
      if (dist(this.player.x, this.player.y, target.x, target.y) < 1100 && !this.player.dead) {
        if (from === this.player) {
          this.gold += target.gold;
          this.cs++;
          this.xp += target.xp;
          this.floats.push({
            x: target.x,
            y: target.y - 20,
            vy: -20,
            life: 0.8,
            max: 0.8,
            text: `+${target.gold}`,
            color: "#f0d48a",
          });
          play("coin");
        } else this.xp += Math.round(target.xp * 0.45);
        this.checkLevel();
      }
      return;
    }
    if (target === this.player) {
      this.deaths++;
      this.cancelRecall(false);
      target.deathT = 8;
      this.feed("전사했습니다.");
      return;
    }
    if (target.kind === "tower") {
      target.deathT = Infinity;
      if (from === this.player) {
        this.gold += 250;
        play("coin");
        this.feed(`${target.name}을 파괴했습니다.`);
      }
      return;
    }
    target.deathT = target.kind === "champion" ? 8 : 8;
    if (from === this.player && target.team !== "blue") this.kills++;
  }

  respawn(u) {
    if (u.kind === "minion") {
      const i = this.units.indexOf(u);
      if (i >= 0) this.units.splice(i, 1);
      return;
    }
    u.dead = false;
    u.stun = 0;
    u.stasis = 0;
    u.slowT = 0;
    const home = u.home || MAP.spawn;
    const spot = this.shove(home.x, home.y, u.r || 40);
    u.x = spot.x;
    u.y = spot.y;
    u.hp = u.maxHp;
    if (u === this.player) {
      u.mana = u.maxMana;
      u.recall = 0;
      u.travel = null;
      this.feed("수련장에서 다시 깨어났습니다.");
    }
  }

  checkLevel() {
    while (this.level < 18 && this.xp >= this.xpNeed()) {
      this.xp -= this.xpNeed();
      this.level++;
      this.points++;
      this.base = statsAt(this.level);
      const p = this.player;
      const beforeHp = p.maxHp;
      const beforeMana = p.maxMana;
      this.recalc();
      p.hp += p.maxHp - beforeHp;
      p.mana += p.maxMana - beforeMana;
      play("level");
      this.feed(`레벨 ${this.level}. 스킬 포인트가 있습니다.`);
    }
  }

  xpNeed() {
    return 160 + this.level * 40;
  }

  updateShrines(dt) {
    for (let i = this.shrines.length - 1; i >= 0; i--) {
      const s = this.shrines[i];
      s.t += dt;
      for (const u of this.units) {
        if (u.dead || u.stasis > 0) continue;
        if (u.kind !== "champion" && u.kind !== "ally" && u.kind !== "dummy") continue;
        if (dist(u.x, u.y, s.x, s.y) > 72) continue;
        if (u.team !== "blue") {
          this.shrines.splice(i, 1);
          this.burst(s.x, s.y, "#888", 6, 40);
          break;
        }
        this.consumeShrine(u, clamp(s.t / 5, 0, 1));
        this.shrines.splice(i, 1);
        break;
      }
    }
  }

  consumeShrine(u, power) {
    const rank = Math.max(0, this.skills.w - 1);
    const def = ABILITIES.w;
    const ap = this.player.ap;
    const minH = def.minHeal[rank] + def.minRatio * ap;
    const maxH = def.maxHeal[rank] + def.maxRatio * ap;
    const heal = lerp(minH, maxH, power);
    this.heal(u, heal);
    const ms = def.ms[rank] + def.msAp * (ap / 100);
    u.buffs = u.buffs || [];
    u.buffs.push({ kind: "ms", amt: ms, t: 1.5, max: 1.5 });
    play("heal");
    this.burst(u.x, u.y, "#e7ffd8", 12, 70);
  }

  updatePortals(dt) {
    for (let i = this.portals.length - 1; i >= 0; i--) {
      this.portals[i].life -= dt;
      if (this.portals[i].life <= 0) this.portals.splice(i, 1);
    }
    for (const u of this.units) {
      if (u.dead || u.travel || u.stun > 0 || u.stasis > 0) continue;
      if (u.kind === "minion" || u.kind === "tower") continue;
      for (const portal of this.portals) {
        if (!u.path || !u.path.length) continue;
        if (dist(u.x, u.y, portal.ax, portal.ay) > 64) continue;
        const end = u.path[u.path.length - 1];
        if (dist(end.x, end.y, portal.ax, portal.ay) < 130) this.enterPortal(u, portal);
      }
    }
  }

  updateWards(dt) {
    for (let i = this.wards.length - 1; i >= 0; i--) {
      this.wards[i].life -= dt;
      if (this.wards[i].life <= 0) this.wards.splice(i, 1);
    }
  }

  updateChimes(dt) {
    const p = this.player;
    if (!p.dead) {
      for (let i = this.chimes.length - 1; i >= 0; i--) {
        const c = this.chimes[i];
        if (dist(p.x, p.y, c.x, c.y) < 70) {
          this.chimes.splice(i, 1);
          this.chimeCount++;
          this.sessionChimes++;
          this.oocStacks = Math.min(10, this.oocStacks + 1);
          this.oocT = 20;
          p.mana = Math.min(p.maxMana, p.mana + p.maxMana * 0.12);
          this.xp += 20;
          this.checkLevel();
          play("chime");
          this.burst(c.x, c.y, "#fff4cc", 12, 60);
          this.feed(`차임 ${this.chimeCount}`);
        }
      }
    }
    this.chimeSpawn = (this.chimeSpawn || 6) - dt;
    if (this.chimeSpawn <= 0 && this.chimes.length < 10) {
      this.chimeSpawn = 16;
      const ang = Math.random() * Math.PI * 2;
      const d = 700 + Math.random() * 1400;
      this.placeChime(p.x + Math.cos(ang) * d, p.y + Math.sin(ang) * d);
    }
  }

  updateWaves(dt) {
    this.waveIn -= dt;
    if (this.waveIn <= 0) {
      this.waveIn = 30;
      this.spawnWave("blue");
      this.spawnWave("red");
    }
  }

  updateFx(dt) {
    for (let i = this.marks.length - 1; i >= 0; i--) {
      this.marks[i].life -= dt;
      if (this.marks[i].life <= 0) this.marks.splice(i, 1);
    }
    for (let i = this.pings.length - 1; i >= 0; i--) {
      const ping = this.pings[i];
      if (ping.unit && !ping.unit.dead) {
        ping.x = ping.unit.x;
        ping.y = ping.unit.y;
      }
      ping.life -= dt;
      if (ping.life <= 0) this.pings.splice(i, 1);
    }
    for (let i = this.floats.length - 1; i >= 0; i--) {
      const f = this.floats[i];
      f.life -= dt;
      f.y += f.vy * dt;
      if (f.life <= 0) this.floats.splice(i, 1);
    }
    const cap = this.settings.particles === "high" ? 180 : 40;
    if (this.particles.length > cap) this.particles.splice(0, this.particles.length - cap);
    for (let i = this.particles.length - 1; i >= 0; i--) {
      const p = this.particles[i];
      p.life -= dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vy *= 0.98;
      if (p.life <= 0) this.particles.splice(i, 1);
    }
  }

  separate() {
    const list = this.units.filter((u) => !u.dead && !u.travel && u.stasis <= 0 && u.kind !== "tower");
    for (let i = 0; i < list.length; i++) {
      for (let j = i + 1; j < list.length; j++) {
        const a = list[i];
        const b = list[j];
        const d = dist(a.x, a.y, b.x, b.y) || 0.001;
        const min = a.r + b.r - 6;
        if (d >= min) continue;
        const push = (min - d) * 0.35;
        const nx = (a.x - b.x) / d;
        const ny = (a.y - b.y) / d;
        const wa = a.kind === "champion" ? 0.35 : 0.65;
        const wb = b.kind === "champion" ? 0.35 : 0.65;
        this.nudge(a, nx * push * wa, ny * push * wa);
        this.nudge(b, -nx * push * wb, -ny * push * wb);
      }
    }
  }

  nudge(u, dx, dy) {
    if (u.hold && u.kind !== "champion") return;
    if (!hitsWall(u.x + dx, u.y + dy, u.r, WALLS)) {
      u.x += dx;
      u.y += dy;
    }
  }

  updateCamera() {
    const follow = (this.camLock || this.space) && !this.mmb;
    if (follow) this.centerOn(this.player.x, this.player.y);
    else {
      this.cam.x = clamp(this.cam.x, 0, Math.max(0, WORLD - this.viewW()));
      this.cam.y = clamp(this.cam.y, 0, Math.max(0, WORLD - this.viewH()));
    }
  }

  lookAt(x, y) {
    if (this.camLock || this.space) return false;
    this.centerOn(x, y);
    return true;
  }

  sees(x, y) {
    if (!this.settings.fog) return true;
    const sources = [{ x: this.player.x, y: this.player.y, r: 1350 }];
    for (const u of this.units) {
      if (u.dead || u.team !== "blue" || u === this.player) continue;
      sources.push({ x: u.x, y: u.y, r: u.kind === "tower" ? 900 : u.kind === "minion" ? 650 : 1000 });
    }
    for (const w of this.wards) sources.push({ x: w.x, y: w.y, r: 900 });
    for (const s of sources) if (dist(s.x, s.y, x, y) <= s.r) return true;
    return false;
  }

  burst(x, y, color, n, speed) {
    const count = this.settings.particles === "high" ? n : Math.ceil(n * 0.35);
    for (let i = 0; i < count; i++) {
      const a = Math.random() * Math.PI * 2;
      const s = speed * (0.35 + Math.random());
      this.particles.push({
        x,
        y,
        vx: Math.cos(a) * s,
        vy: Math.sin(a) * s,
        life: 0.35 + Math.random() * 0.35,
        max: 0.7,
        color,
        size: 1.5 + Math.random() * 2.4,
      });
    }
  }

  resetCooldowns() {
    this.cd = { q: 0, w: 0, e: 0, r: 0, d: 0, f: 0, ward: 0 };
    this.wCharges = 2;
    this.wChargeT = 0;
    this.player.mana = this.player.maxMana;
    if (!this.player.dead) this.player.hp = this.player.maxHp;
    this.feed("스킬과 자원을 되돌렸습니다.");
  }

  setSettings(settings) {
    this.settings = settings;
  }
}

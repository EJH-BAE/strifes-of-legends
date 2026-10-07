import { drawFrame } from "./draw.js";
import { Hud } from "./hud.js";
import { Simulation } from "./sim.js";
import { loadProfile, saveProfile } from "./data.js";
import { setScene } from "./audio.js";

export class Session {
  constructor(els, hooks) {
    this.els = els;
    this.hooks = hooks;
    this.hud = new Hud(els.game);
    this.hud.onResume = () => this.setPaused(false);
    this.hud.onRestart = () => this.restart();
    this.hud.onSettings = () => hooks.openSettings("game");
    this.hud.onExit = () => this.exit();
    this.sim = null;
    this.raf = 0;
    this.startedAt = 0;
    this.running = false;
  }

  start(settings) {
    this.stopLoop();
    if (this.sim) this.sim.destroy();
    this.settings = settings;
    this.sim = new Simulation(this.els.canvas, settings, {
      blockInput: () => this.hooks.settingsOpen(),
      onEscape: () => this.onEscape(),
      onShop: (open) => this.hud.setShop(open),
      onFeed: (text) => this.hud.feed(text),
    });
    this.hud.bind(this.sim);
    this.hud.setPause(false);
    this.hud.setShop(false);
    this.hud.feed("수련장에 들어왔습니다.");
    this.startedAt = performance.now();
    this.running = true;
    this.last = performance.now();
    setScene("game");
    this.loop();
  }

  restart() {
    const settings = this.settings;
    this.start(settings);
    this.hud.feed("수련장을 다시 열었습니다.");
  }

  loop = (now = performance.now()) => {
    if (!this.running || !this.sim) return;
    const dt = Math.min(0.05, (now - this.last) / 1000);
    this.last = now;
    this.sim.update(dt);
    drawFrame(this.els.canvas, this.els.minimap, this.sim);
    this.hud.sync();
    this.raf = requestAnimationFrame(this.loop);
  };

  stopLoop() {
    this.running = false;
    if (this.raf) cancelAnimationFrame(this.raf);
  }

  setPaused(paused) {
    if (!this.sim) return;
    this.sim.paused = paused;
    this.hud.setPause(paused);
    if (paused) this.sim.shopOpen = false;
    this.hud.setShop(false);
  }

  onEscape() {
    if (this.hooks.settingsOpen()) {
      this.hooks.closeSettings(false);
      return;
    }
    if (this.sim.shopOpen) {
      this.sim.shopOpen = false;
      this.hud.setShop(false);
      return;
    }
    if (this.sim.cancelTransient()) return;
    this.setPaused(!this.sim.paused);
  }

  applySettings(settings) {
    this.settings = settings;
    if (this.sim) this.sim.setSettings(settings);
  }

  exit() {
    if (!this.sim) {
      this.hooks.showHome();
      return;
    }
    const profile = loadProfile();
    profile.games += 1;
    profile.seconds += (performance.now() - this.startedAt) / 1000;
    profile.chimes += this.sim.sessionChimes;
    profile.lastHits += this.sim.cs;
    saveProfile(profile);
    this.stopLoop();
    this.sim.destroy();
    this.sim = null;
    setScene("home");
    this.hooks.showHome();
  }
}

import { ABILITIES, ITEMS, SHOP_ORDER, keyLabel } from "./data.js";
import { paintPortrait } from "./draw.js";

const ORDER = ["q", "w", "e", "r"];

export class Hud {
  constructor(root) {
    this.root = root;
    this.sim = null;
    this.drag = null;
    paintPortrait(root.querySelector("#portrait"));
    this.feedEl = root.querySelector("#feed");
    this.cache = "";
    root.querySelector("#shop-btn").addEventListener("click", () => this.sim?.tryShop());
    root.querySelector("#shop-close").addEventListener("click", () => {
      if (!this.sim) return;
      this.sim.shopOpen = false;
      this.setShop(false);
    });
    root.querySelector("#minimap").addEventListener("mousedown", (e) => this.onMap(e));
    root.querySelector("#minimap").addEventListener("mousemove", (e) => {
      if (e.buttons & 1) this.onMap(e);
    });
    root.querySelector("#hide-help").addEventListener("click", () => {
      root.querySelector("#help").classList.add("hidden");
    });
    root.querySelector("#pause-resume").addEventListener("click", () => this.onResume?.());
    root.querySelector("#pause-reset").addEventListener("click", () => this.sim?.resetCooldowns());
    root.querySelector("#pause-restart").addEventListener("click", () => this.onRestart?.());
    root.querySelector("#pause-settings").addEventListener("click", () => this.onSettings?.());
    root.querySelector("#pause-exit").addEventListener("click", () => this.onExit?.());
    this.buildAbilities();
    this.buildShop();
    this.buildSlots();
    window.addEventListener("mousemove", (e) => this.onDragMove(e));
    window.addEventListener("mouseup", (e) => this.onDragEnd(e));
  }

  bind(sim) {
    this.sim = sim;
    this.cache = "";
    this.sync();
  }

  buildAbilities() {
    const row = this.root.querySelector("#ability-row");
    row.innerHTML = "";
    for (const id of ORDER) {
      const def = ABILITIES[id];
      const btn = document.createElement("button");
      btn.type = "button";
      btn.className = "ability";
      btn.dataset.spell = id;
      btn.innerHTML = `<span class="key"></span><span class="glyph">${def.key}</span><i class="sweep"></i><b class="cd-num"></b><em class="pips"></em><em class="up">+</em><span class="tip"></span>`;
      btn.addEventListener("click", (e) => {
        if (!this.sim || this.sim.paused) return;
        if (e.target.classList.contains("up")) this.sim.rankUp(id);
        else this.sim.pressSpell(id);
      });
      row.appendChild(btn);
    }
    const sums = this.root.querySelector("#summoners");
    sums.innerHTML = "";
    for (const id of ["d", "f"]) {
      const btn = document.createElement("button");
      btn.type = "button";
      btn.className = "summoner";
      btn.dataset.spell = id;
      btn.innerHTML = `<span class="key"></span><span class="glyph">${ABILITIES[id].key}</span><i class="sweep"></i><b class="cd-num"></b><span class="tip"></span>`;
      btn.addEventListener("click", () => {
        if (!this.sim || this.sim.paused) return;
        if (id === "d") this.sim.castFlash();
        else this.sim.castHeal();
      });
      sums.appendChild(btn);
    }
  }

  buildSlots() {
    const row = this.root.querySelector("#item-row");
    row.innerHTML = "";
    for (let i = 0; i < 7; i++) {
      const el = document.createElement("button");
      el.type = "button";
      el.className = "slot" + (i === 6 ? " trinket" : "");
      el.dataset.slot = String(i);
      el.innerHTML = `<span class="mark"></span><i class="count"></i><b class="key"></b><span class="tip"></span>`;
      el.addEventListener("mousedown", (e) => this.onSlotDown(e, i));
      el.addEventListener("contextmenu", (e) => {
        e.preventDefault();
        if (this.sim?.shopOpen && i < 6) this.sim.sell(i);
      });
      el.addEventListener("click", () => {
        if (!this.sim || this.dragMoved) return;
        this.sim.selectedItem = i;
        el.parentElement.querySelectorAll(".slot").forEach((s) => s.classList.toggle("picked", s === el));
      });
      row.appendChild(el);
    }
  }

  buildShop() {
    const list = this.root.querySelector("#shop-list");
    list.innerHTML = "";
    for (const id of SHOP_ORDER) {
      const def = ITEMS[id];
      const row = document.createElement("button");
      row.type = "button";
      row.className = "shop-item";
      row.dataset.item = id;
      row.innerHTML = `<span class="mark" style="background:${def.color}">${def.mark}</span><span><strong>${def.name}</strong><small>${def.desc}</small></span><em>${def.cost}</em>`;
      row.addEventListener("click", () => this.sim?.buy(id));
      list.appendChild(row);
    }
  }

  onSlotDown(e, index) {
    if (e.button !== 0 || !this.sim || index > 5) return;
    const item = this.sim.inventory[index];
    if (!item) return;
    this.drag = { index, x: e.clientX, y: e.clientY };
    this.dragMoved = false;
  }

  onDragMove(e) {
    if (!this.drag) return;
    if (Math.hypot(e.clientX - this.drag.x, e.clientY - this.drag.y) > 6) this.dragMoved = true;
    const ghost = this.root.querySelector("#drag-ghost");
    if (this.dragMoved) {
      const def = ITEMS[this.sim.inventory[this.drag.index].id];
      ghost.classList.remove("hidden");
      ghost.style.left = `${e.clientX + 8}px`;
      ghost.style.top = `${e.clientY + 8}px`;
      ghost.textContent = def.mark;
    }
  }

  onDragEnd(e) {
    if (!this.drag) return;
    const ghost = this.root.querySelector("#drag-ghost");
    ghost.classList.add("hidden");
    if (this.dragMoved) {
      const el = document.elementFromPoint(e.clientX, e.clientY);
      const slot = el?.closest?.(".slot");
      if (slot && slot.dataset.slot < 6) this.sim.swapSlots(this.drag.index, Number(slot.dataset.slot));
    }
    this.drag = null;
  }

  onMap(e) {
    if (!this.sim) return;
    const rect = this.root.querySelector("#minimap").getBoundingClientRect();
    const x = ((e.clientX - rect.left) / rect.width) * 6400;
    const y = ((e.clientY - rect.top) / rect.height) * 6400;
    if (!this.sim.lookAt(x, y)) this.feed("시점이 고정되어 있습니다. Y로 해제하세요.");
  }

  setShop(open) {
    this.root.querySelector("#shop").classList.toggle("hidden", !open);
  }

  setPause(open) {
    this.root.querySelector("#pause").classList.toggle("hidden", !open);
  }

  feed(text) {
    const li = document.createElement("li");
    li.textContent = text;
    this.feedEl.appendChild(li);
    while (this.feedEl.children.length > 6) this.feedEl.firstChild.remove();
  }

  sync() {
    const sim = this.sim;
    if (!sim) return;
    const p = sim.player;
    const hpPct = Math.max(0, p.hp / p.maxHp);
    const hp = this.root.querySelector(".hp");
    hp.querySelector(".fill").style.width = `${hpPct * 100}%`;
    hp.classList.toggle("low", hpPct < 0.3);
    hp.classList.toggle("mid", hpPct >= 0.3 && hpPct < 0.6);
    hp.querySelector("span").textContent = `${Math.ceil(p.hp)} / ${Math.ceil(p.maxHp)}`;
    const mp = this.root.querySelector(".mp");
    mp.querySelector(".fill").style.width = `${(p.mana / p.maxMana) * 100}%`;
    mp.querySelector("span").textContent = `${Math.ceil(p.mana)} / ${Math.ceil(p.maxMana)}`;
    const need = sim.xpNeed();
    this.root.querySelector(".xp .fill").style.width = `${Math.min(100, (sim.xp / need) * 100)}%`;
    this.root.querySelector("#level").textContent = String(sim.level);
    this.root.querySelector("#gold").textContent = String(sim.gold);
    this.root.querySelector("#cs").textContent = `CS ${sim.cs}`;
    const t = Math.floor(sim.time);
    this.root.querySelector("#clock").textContent = `${Math.floor(t / 60)}:${String(t % 60).padStart(2, "0")}`;
    this.root.querySelector("#kda").textContent = `${sim.kills} / ${sim.deaths}`;
    this.root.querySelector("#wave").textContent = `미니언 ${Math.ceil(sim.waveIn)}`;
    this.root.querySelector("#ms").textContent = `${Math.round(p.curMs || p.baseMs)}`;
    const keys = sim.settings.keys;
    this.syncSpell("q", keys.q, sim.cd.q, ABILITIES.q.cd[sim.skills.q - 1] || 1, sim.skills.q, 5);
    this.syncSpell("w", keys.w, sim.wCharges < 2 ? ABILITIES.w.recharge - sim.wChargeT : 0, ABILITIES.w.recharge, sim.skills.w, 5, sim.wCharges);
    this.syncSpell("e", keys.e, sim.cd.e, ABILITIES.e.cd[sim.skills.e - 1] || 1, sim.skills.e, 5);
    this.syncSpell("r", keys.r, sim.cd.r, ABILITIES.r.cd[sim.skills.r - 1] || 1, sim.skills.r, 3);
    this.syncSpell("d", keys.d, sim.cd.d, ABILITIES.d.cd, 1, 1);
    this.syncSpell("f", keys.f, sim.cd.f, ABILITIES.f.cd, 1, 1);
    this.root.querySelectorAll(".ability, .summoner").forEach((btn) => {
      const id = btn.dataset.spell;
      const def = ABILITIES[id];
      const noMana = def.cost && p.mana < def.cost;
      btn.classList.toggle("nomana", !!noMana);
      btn.classList.toggle("reject", sim.rejectT > 0 && (noMana ? sim.flashReject === "mana" : sim.flashReject === "cd"));
    });
    const sig = JSON.stringify(sim.inventory) + sim.cd.ward.toFixed(1);
    if (sig !== this.cache) {
      this.cache = sig;
      this.paintSlots();
    } else {
      this.paintWardCd();
    }
    const target = sim.selected && sim.selected !== p ? sim.selected : null;
    const frame = this.root.querySelector("#target-frame");
    frame.classList.toggle("hidden", !target || target.dead);
    if (target && !target.dead) {
      frame.querySelector("strong").textContent = target.name;
      frame.querySelector(".fill").style.width = `${(target.hp / target.maxHp) * 100}%`;
      frame.querySelector("em").textContent = `${Math.ceil(target.hp)} / ${Math.ceil(target.maxHp)}`;
    }
    const death = this.root.querySelector("#death");
    death.classList.toggle("hidden", !p.dead);
    if (p.dead) death.querySelector("b").textContent = Math.ceil(p.deathT);
    const tab = this.root.querySelector("#scoreboard");
    tab.classList.toggle("hidden", !sim.showTab);
    if (sim.showTab) {
      tab.innerHTML = `<div><span>${p.name}</span><span>${sim.kills}/${sim.deaths}</span><span>CS ${sim.cs}</span><span>${sim.gold} 골드</span></div>`;
    }
    const wheel = this.root.querySelector("#wheel");
    if (sim.pingHold) {
      wheel.classList.remove("hidden");
      wheel.style.left = `${sim.pingHold.x}px`;
      wheel.style.top = `${sim.pingHold.y}px`;
      const dx = sim.screen.x - sim.pingHold.x;
      const dy = sim.screen.y - sim.pingHold.y;
      const ang = Math.atan2(dy, dx);
      const dist = Math.hypot(dx, dy);
      let dir = "";
      if (dist > 28) {
        const deg = (ang * 180) / Math.PI;
        if (deg < -45 && deg >= -135) dir = "up";
        else if (deg >= 45 && deg < 135) dir = "down";
        else if (Math.abs(deg) > 135) dir = "left";
        else dir = "right";
      }
      wheel.querySelectorAll(".w").forEach((el) => el.classList.toggle("on", el.dataset.dir === dir));
    } else wheel.classList.add("hidden");
    const hint = this.root.querySelector("#cast-hint");
    if (sim.aim) {
      const names = { q: "별빛의 결속", w: "돌봄의 성소", e: "벽 너머의 길", r: "멈춘 운명", amove: "공격 이동" };
      hint.textContent = `${names[sim.aim.kind]} · 좌클릭으로 사용, 우클릭으로 취소`;
      hint.classList.remove("hidden");
    } else hint.classList.add("hidden");
    this.root.querySelector("#shop-gold").textContent = `${sim.gold} 골드`;
    this.root.querySelectorAll(".shop-item").forEach((btn) => {
      const def = ITEMS[btn.dataset.item];
      btn.classList.toggle("broke", sim.gold < def.cost);
    });
    this.root.style.setProperty("--hud", String(sim.settings.hudScale || 1));
  }

  syncSpell(id, key, cd, max, rank, cap, charges) {
    const btn = this.root.querySelector(`[data-spell="${id}"]`);
    if (!btn) return;
    btn.querySelector(".key").textContent = keyLabel(key);
    const sweep = btn.querySelector(".sweep");
    const num = btn.querySelector(".cd-num");
    const left = Math.max(0, cd);
    const pct = max > 0 ? Math.min(1, left / max) : 0;
    sweep.style.setProperty("--p", left > 0.05 ? String(pct) : "0");
    num.textContent = left > 0.05 ? (left >= 10 ? String(Math.ceil(left)) : left.toFixed(1)) : "";
    const pips = btn.querySelector(".pips");
    if (pips) {
      pips.innerHTML = Array.from({ length: cap }, (_, i) => `<s class="${i < rank ? "on" : ""}"></s>`).join("");
    }
    const up = btn.querySelector(".up");
    if (up && this.sim) {
      const can = this.canRank(id);
      up.classList.toggle("show", can);
    }
    if (charges != null) {
      let badge = btn.querySelector(".charges");
      if (!badge) {
        badge = document.createElement("i");
        badge.className = "charges";
        btn.appendChild(badge);
      }
      badge.textContent = String(charges);
    }
    const def = ABILITIES[id];
    const tip = btn.querySelector(".tip");
    tip.innerHTML = `<strong>${def.name}</strong><small>${def.blurb}</small>`;
  }

  canRank(slot) {
    const sim = this.sim;
    const cap = slot === "r" ? 3 : 5;
    if (sim.points <= 0 || sim.skills[slot] >= cap) return false;
    if (slot === "r") return sim.level >= [6, 11, 16][sim.skills.r];
    return true;
  }

  paintSlots() {
    const keys = this.sim.settings.keys;
    this.root.querySelectorAll(".slot").forEach((el) => {
      const i = Number(el.dataset.slot);
      const item = i === 6 ? this.sim.trinket : this.sim.inventory[i];
      const mark = el.querySelector(".mark");
      const count = el.querySelector(".count");
      el.querySelector(".key").textContent = keyLabel(keys[`i${i + 1}`]);
      if (!item) {
        mark.textContent = "";
        mark.style.background = "";
        count.textContent = "";
        el.querySelector(".tip").innerHTML = "";
        return;
      }
      const def = ITEMS[item.id];
      mark.textContent = def.mark;
      mark.style.background = def.color;
      count.textContent = item.count > 1 ? String(item.count) : "";
      el.querySelector(".tip").innerHTML = `<strong>${def.name}</strong><small>${def.desc}</small>`;
    });
    this.paintWardCd();
  }

  paintWardCd() {
    const el = this.root.querySelector('.slot[data-slot="6"] .mark');
    if (!el || !this.sim) return;
    el.style.filter = this.sim.cd.ward > 0 ? "grayscale(0.8) brightness(0.7)" : "";
  }
}

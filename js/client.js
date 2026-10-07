import { ABILITIES, HOTKEYS, keyLabel, loadProfile, loadSettings, saveProfile, saveSettings } from "./data.js";
import { play, setScene, setVolumes, unlock } from "./audio.js";
import { Session } from "./session.js";

export function boot() {
  const home = document.getElementById("home");
  const settingsEl = document.getElementById("settings");
  const game = document.getElementById("game");
  const settings = loadSettings();
  const app = {
    settings,
    draft: structuredClone(settings),
    snapshot: structuredClone(settings),
    tab: "general",
    rebinding: null,
    page: "home",
    settingsOpen: false,
    from: "home",
  };

  const session = new Session(
    { game, canvas: document.getElementById("view"), minimap: document.getElementById("minimap") },
    {
      settingsOpen: () => app.settingsOpen,
      openSettings: (from) => openSettings(from),
      closeSettings: (apply) => closeSettings(apply),
      showHome: () => showHome(),
    }
  );

  function paintNames() {
    const name = app.settings.name || "Bae";
    document.getElementById("chip-name").textContent = name;
    document.getElementById("party-name").textContent = name;
  }

  function renderCollection() {
    const card = document.getElementById("champ-card");
    const skills = ["p", "q", "w", "e", "r"].map((id) => {
      const a = ABILITIES[id];
      return `<li><b>${a.key}</b><div><strong>${a.name}</strong><small>${a.blurb}</small></div></li>`;
    });
    card.innerHTML = `
      <div class="champ-seal">바드</div>
      <div>
        <h2>바드</h2>
        <p class="role">방랑하는 수호자 · 서포터</p>
        <p>별 사이의 길을 여는 수호자. 빛을 묶어 전장을 잠재우고, 동료가 설 자리를 남긴다.</p>
        <ul class="skill-list">${skills.join("")}</ul>
        <button type="button" id="play-collection" class="play-btn slim">수련장에서 사용</button>
      </div>`;
    card.querySelector("#play-collection").addEventListener("click", () => startMatch());
  }

  function renderProfile() {
    const profile = loadProfile();
    const mins = Math.floor(profile.seconds / 60);
    document.getElementById("profile-card").innerHTML = `
      <div class="who"><i></i><div><b>${app.settings.name || "Bae"}</b><small>수련생</small></div></div>
      <dl>
        <div><dt>수련</dt><dd>${profile.games}</dd></div>
        <div><dt>머문 시간</dt><dd>${mins}분</dd></div>
        <div><dt>차임</dt><dd>${profile.chimes}</dd></div>
        <div><dt>막타</dt><dd>${profile.lastHits}</dd></div>
      </dl>`;
  }

  function showPage(id) {
    app.page = id;
    document.querySelectorAll(".page").forEach((p) => p.classList.toggle("hidden", p.id !== `page-${id}`));
    document.querySelectorAll("#nav button").forEach((b) => b.classList.toggle("on", b.dataset.page === id));
    if (id === "profile") renderProfile();
  }

  function showHome() {
    game.classList.add("hidden");
    home.classList.remove("hidden");
    setScene("home");
    renderProfile();
    paintNames();
  }

  function startMatch() {
    if (app.settingsOpen) return;
    unlock();
    play("click");
    home.classList.add("hidden");
    game.classList.remove("hidden");
    requestAnimationFrame(() => session.start(app.settings));
  }

  function openSettings(from) {
    app.from = from || "home";
    app.snapshot = structuredClone(app.settings);
    app.draft = structuredClone(app.settings);
    app.tab = "general";
    app.rebinding = null;
    app.settingsOpen = true;
    settingsEl.classList.remove("hidden");
    renderSettings();
  }

  function closeSettings(apply) {
    if (apply) commitSettings();
    else {
      app.draft = structuredClone(app.snapshot);
      setVolumes(app.settings);
    }
    app.settingsOpen = false;
    app.rebinding = null;
    settingsEl.classList.add("hidden");
  }

  function commitSettings() {
    app.settings = structuredClone(app.draft);
    saveSettings(app.settings);
    setVolumes(app.settings);
    session.applySettings(app.settings);
    paintNames();
    const profile = loadProfile();
    saveProfile(profile);
  }

  function renderSettings() {
    document.querySelectorAll("#settings-tabs button").forEach((b) => b.classList.toggle("on", b.dataset.tab === app.tab));
    const panel = document.getElementById("settings-panel");
    const d = app.draft;
    if (app.tab === "general") {
      panel.innerHTML = `
        <h2>일반</h2>
        <label class="field">소환사 이름<input name="name" maxlength="16" value="${escapeHtml(d.name)}"/></label>
        <p class="fine">Strifes of Legends는 여기서 새로 만드는 수련용 프로토타입이다. 화면 속 문장과 문양은 이 프로젝트를 위해 그렸다.</p>`;
    } else if (app.tab === "controls") {
      const groups = {};
      for (const row of HOTKEYS) (groups[row.group] ||= []).push(row);
      const blocks = Object.entries(groups)
        .map(([group, rows]) => {
          const items = rows
            .map((row) => {
              const waiting = app.rebinding === row.id;
              return `<button type="button" data-rebind="${row.id}" class="${waiting ? "wait" : ""}"><span>${row.label}</span><kbd>${waiting ? "키 입력" : keyLabel(d.keys[row.id])}</kbd></button>`;
            })
            .join("");
          return `<h3>${group}</h3><div class="key-grid">${items}</div>`;
        })
        .join("");
      panel.innerHTML = `
        <h2>조작</h2>
        <div class="radios">
          ${radio("castMode", "normal", "일반 시전", "키를 누른 뒤 좌클릭으로 확정. 우클릭은 취소하고 이동한다.")}
          ${radio("castMode", "indicator", "표시 후 시전", "키를 누르고 있는 동안 범위를 보고, 손을 떼면 시전한다.")}
          ${radio("castMode", "quick", "빠른 시전", "키를 누르는 순간 커서 위치에 시전한다.")}
        </div>
        ${blocks}
        <ul class="fine-list">
          <li>왼쪽 클릭은 대상·아이템 선택, 아이템은 끌어서 칸을 바꾼다.</li>
          <li>오른쪽 클릭은 이동과 공격. Shift+우클릭은 공격 이동.</li>
          <li>G를 짧게 누르면 주의, 길게 누르고 방향을 고르면 위험 / 적 사라짐 / 도와주세요 / 갑니다.</li>
          <li>스킬 포인트는 Ctrl+QWER 또는 아이콘의 + 로 찍는다.</li>
        </ul>`;
    } else if (app.tab === "video") {
      panel.innerHTML = `
        <h2>영상</h2>
        ${check("cameraLocked", "시작할 때 시점 고정")}
        ${check("showRanges", "기본 공격 사거리 표시")}
        ${check("damageNumbers", "피해·회복 수치")}
        ${check("shake", "화면 흔들림")}
        ${check("fog", "전장의 안개")}
        <label class="field">이펙트
          <select name="particles">
            <option value="high" ${d.particles === "high" ? "selected" : ""}>높음</option>
            <option value="low" ${d.particles === "low" ? "selected" : ""}>낮음</option>
          </select>
        </label>`;
    } else if (app.tab === "sound") {
      panel.innerHTML = `
        <h2>소리</h2>
        ${slider("master", "마스터", d.master)}
        ${slider("sfx", "효과", d.sfx)}
        ${slider("music", "배경", d.music)}`;
    } else {
      panel.innerHTML = `
        <h2>인터페이스</h2>
        ${slider("hudScale", "HUD 크기", d.hudScale, 0.8, 1.2, 0.05)}
        <p class="fine">하단 초상화, 체력, 스킬, 아이템, 미니맵은 경기 중에 같은 자리를 지킨다.</p>`;
    }
  }

  function radio(name, value, title, desc) {
    const on = app.draft[name] === value ? "checked" : "";
    return `<label class="choice"><input type="radio" name="${name}" value="${value}" ${on}/><span><b>${title}</b><small>${desc}</small></span></label>`;
  }

  function check(name, label) {
    return `<label class="choice"><input type="checkbox" name="${name}" ${app.draft[name] ? "checked" : ""}/><span>${label}</span></label>`;
  }

  function slider(name, label, value, min = 0, max = 1, step = 0.01) {
    return `<label class="field">${label}<input type="range" name="${name}" min="${min}" max="${max}" step="${step}" value="${value}"/><b>${Number(value).toFixed(2)}</b></label>`;
  }

  function escapeHtml(s) {
    return String(s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  }

  document.getElementById("nav").addEventListener("click", (e) => {
    const btn = e.target.closest("button");
    if (!btn) return;
    play("click");
    showPage(btn.dataset.page);
  });
  document.getElementById("play-main").addEventListener("click", startMatch);
  document.getElementById("play-mode").addEventListener("click", startMatch);
  document.getElementById("open-settings").addEventListener("click", () => openSettings("home"));
  document.getElementById("mute").addEventListener("click", () => {
    unlock();
    if (app.settings.master > 0) {
      app._master = app.settings.master;
      app.settings.master = 0;
    } else app.settings.master = app._master || 0.8;
    setVolumes(app.settings);
    saveSettings(app.settings);
    document.getElementById("mute").classList.toggle("off", app.settings.master === 0);
  });
  document.getElementById("set-ok").addEventListener("click", () => closeSettings(true));
  document.getElementById("set-apply").addEventListener("click", () => commitSettings());
  document.getElementById("set-cancel").addEventListener("click", () => closeSettings(false));
  document.getElementById("settings-tabs").addEventListener("click", (e) => {
    const btn = e.target.closest("button");
    if (!btn) return;
    app.tab = btn.dataset.tab;
    app.rebinding = null;
    renderSettings();
  });
  document.getElementById("settings-panel").addEventListener("click", (e) => {
    const btn = e.target.closest("[data-rebind]");
    if (!btn) return;
    app.rebinding = btn.dataset.rebind;
    renderSettings();
  });
  document.getElementById("settings-panel").addEventListener("input", (e) => {
    const el = e.target;
    if (el.name === "name") app.draft.name = el.value.slice(0, 16);
    if (["master", "sfx", "music", "hudScale"].includes(el.name)) {
      app.draft[el.name] = Number(el.value);
      el.parentElement.querySelector("b").textContent = Number(el.value).toFixed(2);
      if (el.name !== "hudScale") setVolumes(app.draft);
    }
  });
  document.getElementById("settings-panel").addEventListener("change", (e) => {
    const el = e.target;
    if (el.type === "checkbox") app.draft[el.name] = el.checked;
    if (el.type === "radio") app.draft[el.name] = el.value;
    if (el.name === "particles") app.draft.particles = el.value;
  });

  window.addEventListener(
    "keydown",
    (e) => {
      if (app.rebinding) {
        e.preventDefault();
        e.stopPropagation();
        if (e.code !== "Escape" && e.code !== "Tab") {
          const keys = app.draft.keys;
          for (const k of Object.keys(keys)) {
            if (k !== app.rebinding && keys[k] === e.code) keys[k] = keys[app.rebinding];
          }
          keys[app.rebinding] = e.code;
        }
        app.rebinding = null;
        renderSettings();
        return;
      }
      if (app.settingsOpen) {
        if (e.target.matches("input, textarea, select")) return;
        if (e.code === "Escape") {
          e.preventDefault();
          e.stopPropagation();
          closeSettings(false);
        }
        return;
      }
      if (!game.classList.contains("hidden")) return;
      if (e.code === "Enter") startMatch();
    },
    true
  );

  window.addEventListener("pointerdown", () => unlock(), { once: false });
  renderCollection();
  renderProfile();
  paintNames();
  setVolumes(settings);
  setScene("home");
  startBackdrop();
}

function startBackdrop() {
  const canvas = document.getElementById("bg");
  const ctx = canvas.getContext("2d");
  const stars = Array.from({ length: 80 }, () => ({
    x: Math.random(),
    y: Math.random() * 0.7,
    r: Math.random() * 1.4 + 0.3,
    p: Math.random() * Math.PI * 2,
  }));
  const resize = () => {
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    canvas.width = Math.floor(window.innerWidth * dpr);
    canvas.height = Math.floor(window.innerHeight * dpr);
  };
  resize();
  window.addEventListener("resize", resize);
  const frame = (t) => {
    requestAnimationFrame(frame);
    if (document.getElementById("home").classList.contains("hidden")) return;
    const w = canvas.width;
    const h = canvas.height;
    const g = ctx.createLinearGradient(0, 0, 0, h);
    g.addColorStop(0, "#090b12");
    g.addColorStop(0.45, "#14110e");
    g.addColorStop(1, "#070806");
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, w, h);
    const glow = ctx.createRadialGradient(w * 0.42, h * 0.62, 20, w * 0.42, h * 0.72, w * 0.45);
    glow.addColorStop(0, "rgba(198,161,90,0.18)");
    glow.addColorStop(1, "rgba(198,161,90,0)");
    ctx.fillStyle = glow;
    ctx.fillRect(0, 0, w, h);
    for (const s of stars) {
      const tw = 0.35 + Math.sin(t * 0.001 + s.p) * 0.35;
      ctx.fillStyle = `rgba(244, 230, 200, ${tw})`;
      ctx.beginPath();
      ctx.arc(s.x * w, s.y * h, s.r * (w / 1600), 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.save();
    ctx.translate(w * 0.48, h * 0.78);
    ctx.strokeStyle = "rgba(232, 208, 150, 0.35)";
    ctx.lineWidth = Math.max(2, w / 900);
    ctx.beginPath();
    ctx.moveTo(-w * 0.18, 0);
    ctx.quadraticCurveTo(0, -h * 0.42, w * 0.18, 0);
    ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(0, -h * 0.36);
    ctx.lineTo(0, h * 0.02);
    ctx.stroke();
    ctx.restore();
  };
  requestAnimationFrame(frame);
}

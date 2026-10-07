export const WORLD = 6400;

export const WALLS = [
  { x: 0, y: 0, w: WORLD, h: 160 },
  { x: 0, y: WORLD - 160, w: WORLD, h: 160 },
  { x: 0, y: 0, w: 160, h: WORLD },
  { x: WORLD - 160, y: 0, w: 160, h: WORLD },
  { x: 2680, y: 1680, w: 360, h: 1500 },
  { x: 1680, y: 2680, w: 780, h: 280 },
  { x: 3920, y: 3520, w: 980, h: 300 },
  { x: 1980, y: 1280, w: 460, h: 460 },
  { x: 4300, y: 4680, w: 520, h: 420 },
];

export const LANE = [
  { x: 1500, y: 5000 },
  { x: 2100, y: 4450 },
  { x: 2800, y: 3900 },
  { x: 3450, y: 3300 },
  { x: 4100, y: 2650 },
  { x: 4700, y: 2000 },
  { x: 5200, y: 1500 },
];

export const MAP = {
  spawn: { x: 1300, y: 5180 },
  fountain: { x: 1260, y: 5280, r: 600 },
  redBase: { x: 5140, y: 1460, r: 460 },
  ally: { x: 1040, y: 5560 },
  wallDummy: { x: 3280, y: 2300 },
  lineDummy: { x: 3540, y: 2300 },
  chaseDummy: { x: 4560, y: 2620 },
  blueTower: { x: 2140, y: 4360 },
  redTower: { x: 4380, y: 2140 },
};

export const VIEW_W = 2300;

export const CHAMPION = {
  name: "바드",
  title: "방랑하는 수호자",
  role: "서포터",
  blurb: "별 사이의 길을 여는 수호자. 빛을 묶어 전장을 잠재우고, 동료가 설 자리를 남긴다.",
  ms: 330,
  range: 500,
  hp: 575,
  hpL: 89,
  mana: 350,
  manaL: 50,
  ad: 52,
  adL: 3,
  armor: 34,
  armorL: 4.5,
  mr: 30,
  mrL: 1.3,
  as: 0.625,
  mregen: 1.15,
};

export const ABILITIES = {
  p: {
    name: "방랑의 메아리",
    key: "P",
    blurb: "차임을 주우면 경험치와 마나, 비전투 이동 속도가 쌓인다. 밉은 기본 공격을 실어 추가 마법 피해를 주고, 차임이 모이면 둔화와 흩뿌리는 타격이 열린다.",
  },
  q: {
    name: "별빛의 결속",
    key: "Q",
    cost: 60,
    cd: [11, 10, 9, 8, 7],
    range: 850,
    width: 120,
    speed: 1500,
    cast: 0.25,
    dmg: [80, 120, 160, 200, 240],
    ratio: 0.8,
    disable: [1, 1.2, 1.4, 1.6, 1.8],
    slow: 0.6,
    extra: 300,
    blurb: "직선으로 빛을 날린다. 처음 맞은 적은 피해를 입고 느려지며, 빛이 벽이나 다른 적까지 이어지면 둘 다 속박된다.",
  },
  w: {
    name: "돌봄의 성소",
    key: "W",
    cost: 70,
    recharge: 18,
    charges: 2,
    range: 800,
    cast: 0.25,
    minHeal: [25, 50, 75, 100, 125],
    maxHeal: [50, 87.5, 125, 162.5, 200],
    minRatio: 0.4,
    maxRatio: 0.7,
    ms: [0.2, 0.225, 0.25, 0.275, 0.3],
    msAp: 0.06,
    blurb: "성소를 남긴다. 시간이 지날수록 회복량이 커지고, 아군이 밟으면 회복과 함께 잠시 빨라진다. 적이 밟으면 사라진다.",
  },
  e: {
    name: "벽 너머의 길",
    key: "E",
    cost: 30,
    cd: [22, 20.5, 19, 17.5, 16],
    range: 900,
    cast: 0.25,
    life: 10,
    speed: 900,
    allySpeed: 1197,
    blurb: "지형 너머로 이어지는 일방 통로를 연다. 아군은 더 빠르게 통과하고, 적도 입구로 들어올 수 있다.",
  },
  r: {
    name: "멈춘 운명",
    key: "R",
    cost: 100,
    cd: [110, 95, 80],
    range: 3400,
    radius: 350,
    cast: 0.5,
    stasis: 2.5,
    blurb: "시간을 두고 떨어진 영역에 닿으면, 그 안의 챔피언·미니언·포탑이 2.5초 동안 멈춘다. 아군과 적 모두 대상이다.",
  },
  d: {
    name: "점멸",
    key: "D",
    cd: 300,
    range: 400,
    blurb: "커서 방향으로 짧은 거리를 즉시 이동한다. 도착 지점이 비어 있으면 얇은 벽도 넘는다.",
  },
  f: {
    name: "회복",
    key: "F",
    cd: 240,
    range: 800,
    blurb: "자신과 주변에서 가장 다친 아군을 회복하고, 잠시 이동 속도가 붙는다.",
  },
};

export const ITEMS = {
  potion: {
    id: "potion",
    name: "체력 물약",
    cost: 50,
    stack: 5,
    sell: 0.4,
    active: true,
    color: "#9a3030",
    mark: "약",
    desc: "15초에 걸쳐 체력 150을 회복한다.",
  },
  boots: {
    id: "boots",
    name: "속도의 장화",
    cost: 300,
    ms: 25,
    sell: 0.7,
    color: "#8a6230",
    mark: "장",
    desc: "이동 속도 +25.",
  },
  tome: {
    id: "tome",
    name: "비전의 고서",
    cost: 435,
    ap: 20,
    sell: 0.7,
    color: "#3d4f86",
    mark: "서",
    desc: "주문력 +20.",
  },
  ruby: {
    id: "ruby",
    name: "루비 결정",
    cost: 400,
    hp: 150,
    sell: 0.7,
    color: "#7a2430",
    mark: "루",
    desc: "체력 +150.",
  },
  cloth: {
    id: "cloth",
    name: "헝겊 갑옷",
    cost: 300,
    armor: 15,
    sell: 0.7,
    color: "#6d6456",
    mark: "갑",
    desc: "방어력 +15.",
  },
  mantle: {
    id: "mantle",
    name: "마력 망토",
    cost: 450,
    mr: 25,
    sell: 0.7,
    color: "#3c6d62",
    mark: "망",
    desc: "마법 저항력 +25.",
  },
  dagger: {
    id: "dagger",
    name: "날카로운 단검",
    cost: 250,
    as: 0.15,
    sell: 0.7,
    color: "#8d8f98",
    mark: "단",
    desc: "공격 속도 +15%.",
  },
  charm: {
    id: "charm",
    name: "정령 부적",
    cost: 250,
    mregen: 0.8,
    sell: 0.7,
    color: "#2f6d78",
    mark: "부",
    desc: "마나 재생이 영구히 증가한다.",
  },
  ward: {
    id: "ward",
    name: "와드 토템",
    cost: 0,
    active: true,
    trinket: true,
    color: "#c6a15a",
    mark: "와",
    desc: "시야 와드를 설치한다. 재사용 90초, 지속 90초.",
  },
};

export const SHOP_ORDER = ["potion", "boots", "tome", "ruby", "cloth", "mantle", "dagger", "charm"];

export const HOTKEYS = [
  { group: "스킬", id: "q", label: "별빛의 결속" },
  { group: "스킬", id: "w", label: "돌봄의 성소" },
  { group: "스킬", id: "e", label: "벽 너머의 길" },
  { group: "스킬", id: "r", label: "멈춘 운명" },
  { group: "스킬", id: "d", label: "점멸" },
  { group: "스킬", id: "f", label: "회복" },
  { group: "스킬", id: "recall", label: "귀환" },
  { group: "스킬", id: "shop", label: "상점" },
  { group: "명령", id: "stop", label: "행동 중지" },
  { group: "명령", id: "amove", label: "공격 이동" },
  { group: "명령", id: "ping", label: "스마트 핑" },
  { group: "화면", id: "lock", label: "시점 고정 전환" },
  { group: "화면", id: "center", label: "챔피언에게 시점" },
  { group: "아이템", id: "i1", label: "아이템 칸 1" },
  { group: "아이템", id: "i2", label: "아이템 칸 2" },
  { group: "아이템", id: "i3", label: "아이템 칸 3" },
  { group: "아이템", id: "i4", label: "아이템 칸 4" },
  { group: "아이템", id: "i5", label: "아이템 칸 5" },
  { group: "아이템", id: "i6", label: "아이템 칸 6" },
  { group: "아이템", id: "i7", label: "아이템 칸 7" },
];

export const DEFAULT_SETTINGS = {
  name: "Bae",
  castMode: "normal",
  cameraLocked: true,
  showRanges: false,
  damageNumbers: true,
  particles: "high",
  fog: false,
  shake: true,
  hudScale: 1,
  master: 0.8,
  sfx: 0.85,
  music: 0.4,
  keys: {
    q: "KeyQ",
    w: "KeyW",
    e: "KeyE",
    r: "KeyR",
    d: "KeyD",
    f: "KeyF",
    recall: "KeyB",
    shop: "KeyP",
    stop: "KeyS",
    amove: "KeyA",
    ping: "KeyG",
    lock: "KeyY",
    center: "Space",
    i1: "Digit1",
    i2: "Digit2",
    i3: "Digit3",
    i4: "Digit4",
    i5: "Digit5",
    i6: "Digit6",
    i7: "Digit7",
  },
};

export const DEFAULT_PROFILE = {
  games: 0,
  seconds: 0,
  chimes: 0,
  lastHits: 0,
  casts: 0,
};

export function keyLabel(code) {
  if (!code) return "없음";
  if (code === "Space") return "Space";
  if (code.startsWith("Key")) return code.slice(3);
  if (code.startsWith("Digit")) return code.slice(5);
  if (code === "Escape") return "Esc";
  return code.replace(/^Arrow/, "");
}

export function loadSettings() {
  try {
    const raw = localStorage.getItem("sol-settings");
    if (!raw) return structuredClone(DEFAULT_SETTINGS);
    const parsed = JSON.parse(raw);
    return {
      ...structuredClone(DEFAULT_SETTINGS),
      ...parsed,
      keys: { ...DEFAULT_SETTINGS.keys, ...(parsed.keys || {}) },
    };
  } catch {
    return structuredClone(DEFAULT_SETTINGS);
  }
}

export function saveSettings(settings) {
  localStorage.setItem("sol-settings", JSON.stringify(settings));
}

export function loadProfile() {
  try {
    const raw = localStorage.getItem("sol-profile");
    if (!raw) return structuredClone(DEFAULT_PROFILE);
    return { ...structuredClone(DEFAULT_PROFILE), ...JSON.parse(raw) };
  } catch {
    return structuredClone(DEFAULT_PROFILE);
  }
}

export function saveProfile(profile) {
  localStorage.setItem("sol-profile", JSON.stringify(profile));
}

import { hitsWall, lineClear } from "./geom.js";

class Heap {
  constructor() {
    this.a = [];
  }
  push(f, i, g) {
    const a = this.a;
    a.push({ f, i, g });
    let n = a.length - 1;
    while (n > 0) {
      const p = (n - 1) >> 1;
      if (a[p].f <= a[n].f) break;
      const tmp = a[p];
      a[p] = a[n];
      a[n] = tmp;
      n = p;
    }
  }
  pop() {
    const a = this.a;
    if (!a.length) return null;
    const top = a[0];
    const last = a.pop();
    if (a.length) {
      a[0] = last;
      let n = 0;
      while (true) {
        const l = n * 2 + 1;
        const r = l + 1;
        let s = n;
        if (l < a.length && a[l].f < a[s].f) s = l;
        if (r < a.length && a[r].f < a[s].f) s = r;
        if (s === n) break;
        const tmp = a[n];
        a[n] = a[s];
        a[s] = tmp;
        n = s;
      }
    }
    return top;
  }
  get size() {
    return this.a.length;
  }
}

export function buildGrid(walls, world, cell, radius) {
  const cols = Math.ceil(world / cell);
  const rows = Math.ceil(world / cell);
  const blocked = new Uint8Array(cols * rows);
  for (let y = 0; y < rows; y++) {
    for (let x = 0; x < cols; x++) {
      const cx = x * cell + cell / 2;
      const cy = y * cell + cell / 2;
      if (hitsWall(cx, cy, radius, walls)) blocked[y * cols + x] = 1;
    }
  }
  return { cols, rows, cell, blocked, world };
}

function openAt(grid, x, y) {
  if (x < 0 || y < 0 || x >= grid.cols || y >= grid.rows) return false;
  return grid.blocked[y * grid.cols + x] === 0;
}

function nearestOpen(grid, cx, cy) {
  if (openAt(grid, cx, cy)) return { x: cx, y: cy };
  for (let rad = 1; rad <= 14; rad++) {
    for (let y = cy - rad; y <= cy + rad; y++) {
      for (let x = cx - rad; x <= cx + rad; x++) {
        if (Math.max(Math.abs(x - cx), Math.abs(y - cy)) !== rad) continue;
        if (openAt(grid, x, y)) return { x, y };
      }
    }
  }
  return { x: cx, y: cy };
}

function cellOf(v, cell, max) {
  return Math.max(0, Math.min(max - 1, Math.floor(v / cell)));
}

function smooth(points, walls, radius) {
  if (points.length <= 2) return points;
  const out = [points[0]];
  let i = 0;
  while (i < points.length - 1) {
    let j = points.length - 1;
    while (j > i + 1 && !lineClear(points[i].x, points[i].y, points[j].x, points[j].y, walls, radius)) j--;
    out.push(points[j]);
    i = j;
  }
  return out;
}

export function findPath(grid, sx, sy, tx, ty, walls, radius) {
  if (lineClear(sx, sy, tx, ty, walls, radius)) return [{ x: tx, y: ty }];
  const { cols, rows, cell, blocked } = grid;
  const startC = nearestOpen(grid, cellOf(sx, cell, cols), cellOf(sy, cell, rows));
  const goalC = nearestOpen(grid, cellOf(tx, cell, cols), cellOf(ty, cell, rows));
  const startI = startC.y * cols + startC.x;
  const goalI = goalC.y * cols + goalC.x;
  if (blocked[startI] || blocked[goalI]) return [{ x: tx, y: ty }];

  const gScore = new Float32Array(cols * rows);
  gScore.fill(Infinity);
  gScore[startI] = 0;
  const prev = new Int32Array(cols * rows);
  prev.fill(-1);
  const heap = new Heap();
  const h = (i) => {
    const x = i % cols;
    const y = (i / cols) | 0;
    return Math.hypot(x - goalC.x, y - goalC.y);
  };
  heap.push(h(startI), startI, 0);
  let guard = 0;
  while (heap.size && guard++ < 12000) {
    const cur = heap.pop();
    if (!cur || cur.g !== gScore[cur.i]) continue;
    if (cur.i === goalI) break;
    const cx = cur.i % cols;
    const cy = (cur.i / cols) | 0;
    for (let oy = -1; oy <= 1; oy++) {
      for (let ox = -1; ox <= 1; ox++) {
        if (!ox && !oy) continue;
        const nx = cx + ox;
        const ny = cy + oy;
        if (!openAt(grid, nx, ny)) continue;
        if (ox && oy && (!openAt(grid, cx + ox, cy) || !openAt(grid, cx, cy + oy))) continue;
        const ni = ny * cols + nx;
        const ng = cur.g + (ox && oy ? 1.4142 : 1);
        if (ng < gScore[ni]) {
          gScore[ni] = ng;
          prev[ni] = cur.i;
          heap.push(ng + h(ni), ni, ng);
        }
      }
    }
  }
  if (prev[goalI] === -1 && goalI !== startI) return [{ x: tx, y: ty }];
  const cells = [];
  let c = goalI;
  let safe = 0;
  while (c !== -1 && safe++ < cols * rows) {
    const x = c % cols;
    const y = (c / cols) | 0;
    cells.push({ x: x * cell + cell / 2, y: y * cell + cell / 2 });
    if (c === startI) break;
    c = prev[c];
  }
  cells.reverse();
  if (!cells.length) return [{ x: tx, y: ty }];
  cells[cells.length - 1] = { x: tx, y: ty };
  return smooth(cells, walls, radius * 0.85);
}

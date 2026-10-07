export function clamp(v, a, b) {
  return Math.max(a, Math.min(b, v));
}

export function dist(ax, ay, bx, by) {
  return Math.hypot(ax - bx, ay - by);
}

export function lerp(a, b, t) {
  return a + (b - a) * t;
}

export function hitsWall(x, y, r, walls) {
  for (let i = 0; i < walls.length; i++) {
    const w = walls[i];
    const nx = clamp(x, w.x, w.x + w.w);
    const ny = clamp(y, w.y, w.y + w.h);
    const dx = x - nx;
    const dy = y - ny;
    if (dx * dx + dy * dy < r * r) return w;
  }
  return null;
}

export function lineClear(x1, y1, x2, y2, walls, radius) {
  const d = Math.hypot(x2 - x1, y2 - y1);
  const steps = Math.max(1, Math.ceil(d / 22));
  for (let i = 0; i <= steps; i++) {
    const t = i / steps;
    if (hitsWall(x1 + (x2 - x1) * t, y1 + (y2 - y1) * t, radius, walls)) return false;
  }
  return true;
}

export function pointInRect(x, y, w) {
  return x >= w.x && y >= w.y && x <= w.x + w.w && y <= w.y + w.h;
}

export function firstSolid(x, y, dx, dy, maxDist, walls) {
  const steps = Math.max(1, Math.ceil(maxDist / 10));
  for (let i = 1; i <= steps; i++) {
    const px = x + dx * i * 10;
    const py = y + dy * i * 10;
    for (let k = 0; k < walls.length; k++) {
      if (pointInRect(px, py, walls[k])) {
        return { wall: walls[k], x: px, y: py, dist: i * 10 };
      }
    }
  }
  return null;
}

export function exitSolid(x, y, dx, dy, maxDist, walls) {
  const steps = Math.max(1, Math.ceil(maxDist / 10));
  let seen = false;
  for (let i = 1; i <= steps; i++) {
    const px = x + dx * i * 10;
    const py = y + dy * i * 10;
    let inside = false;
    for (let k = 0; k < walls.length; k++) {
      if (pointInRect(px, py, walls[k])) inside = true;
    }
    if (inside) seen = true;
    else if (seen) return { x: px, y: py, dist: i * 10 };
  }
  return null;
}

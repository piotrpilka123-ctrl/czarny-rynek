'use strict';
/* ============================================================
   NAWIGACJA: wyznaczanie trasy po chodnikach + wstęga 3D na ziemi
   ============================================================ */
const Nav = {
  nodes: [], ribbon: null, mat: null, path: null, length: 0,

  init() {
    const L = W.lat;
    for (let a = 0; a < 6; a++) for (let b = 0; b < 6; b++) this.nodes.push({ a, b, x: L[a], z: L[b], i: a * 6 + b });
    const tex = GFX.tex(GFX.canvas(128, 64, (g, w, h) => {
      g.clearRect(0, 0, w, h); g.strokeStyle = 'rgba(255,255,255,.95)'; g.lineWidth = 12; g.lineCap = 'round'; g.lineJoin = 'round';
      g.beginPath(); g.moveTo(40, 10); g.lineTo(84, 32); g.lineTo(40, 54); g.stroke();
    }), { repeat: true });
    this.tex = tex;
    this.mat = new THREE.MeshBasicMaterial({ map: tex, transparent: true, opacity: 0.85, depthWrite: false, color: new THREE.Color(0.5, 2.2, 0.9), fog: false, polygonOffset: true, polygonOffsetFactor: -4, side: THREE.DoubleSide });
    this.ribbon = new THREE.Mesh(new THREE.BufferGeometry(), this.mat);
    this.ribbon.frustumCulled = false; this.ribbon.visible = false; this.ribbon.renderOrder = 5;
    W.scene.add(this.ribbon);
  },

  nearestNode(x, z, needLos) {
    let best = null, bd = 1e9, bestAny = null, bda = 1e9;
    for (const n of this.nodes) {
      const d = Math.hypot(n.x - x, n.z - z);
      if (d < bda) { bda = d; bestAny = n; }
      if (d < bd && (!needLos || W.los(x, z, n.x, n.z))) { bd = d; best = n; }
    }
    return best || bestAny;
  },

  find(ax, az, bx, bz) {
    const direct = Math.hypot(bx - ax, bz - az);
    if (direct < 45 && W.los(ax, az, bx, bz)) return [[ax, az], [bx, bz]];
    const s = this.nearestNode(ax, az, true), e = this.nearestNode(bx, bz, true);
    // Dijkstra po kracie 6×6
    const dist = new Array(36).fill(1e9), prev = new Array(36).fill(-1), done = new Array(36).fill(false);
    dist[s.i] = 0;
    for (let it = 0; it < 36; it++) {
      let u = -1, ud = 1e9;
      for (let i = 0; i < 36; i++) if (!done[i] && dist[i] < ud) { ud = dist[i]; u = i; }
      if (u < 0 || u === e.i) break;
      done[u] = true;
      const n = this.nodes[u];
      for (const [da, db] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
        const a = n.a + da, b = n.b + db; if (a < 0 || a > 5 || b < 0 || b > 5) continue;
        const v = a * 6 + b, m = this.nodes[v], w = Math.abs(m.x - n.x) + Math.abs(m.z - n.z);
        if (dist[u] + w < dist[v]) { dist[v] = dist[u] + w; prev[v] = u; }
      }
    }
    const mid = []; let cur = e.i;
    while (cur >= 0) { mid.unshift([this.nodes[cur].x, this.nodes[cur].z]); cur = prev[cur]; }
    let pts = [[ax, az], ...mid, [bx, bz]];
    // wygładzanie: usuń punkty pośrednie, gdy widać się na wprost
    for (let pass = 0; pass < 3; pass++) {
      for (let i = 1; i < pts.length - 1; i++) {
        if (W.los(pts[i - 1][0], pts[i - 1][1], pts[i + 1][0], pts[i + 1][1])) { pts.splice(i, 1); i--; }
      }
    }
    return pts;
  },

  set(pts, color) {
    this.path = pts;
    if (!pts || pts.length < 2) { this.ribbon.visible = false; this.length = 0; return; }
    const pos = [], uv = [], idx = [], hw = 0.32;
    let acc = 0, vi = 0;
    for (let i = 0; i < pts.length - 1; i++) {
      const a = pts[i], b = pts[i + 1], dx = b[0] - a[0], dz = b[1] - a[1], len = Math.hypot(dx, dz) || 0.001;
      const nx = -dz / len * hw, nz = dx / len * hw;
      // dzielimy na odcinki, żeby wstęga leżała na krawężnikach
      const segs = Math.max(1, Math.ceil(len / 4));
      for (let s = 0; s < segs; s++) {
        const t0 = s / segs, t1 = (s + 1) / segs;
        const x0 = a[0] + dx * t0, z0 = a[1] + dz * t0, x1 = a[0] + dx * t1, z1 = a[1] + dz * t1;
        const y0 = W.loc === 'out' ? W.groundY(x0, z0) + 0.07 : 0.05, y1 = W.loc === 'out' ? W.groundY(x1, z1) + 0.07 : 0.05;
        pos.push(x0 + nx, y0, z0 + nz, x0 - nx, y0, z0 - nz, x1 + nx, y1, z1 + nz, x1 - nx, y1, z1 - nz);
        const u0 = (acc + len * t0) / 1.3, u1 = (acc + len * t1) / 1.3;
        uv.push(u0, 0, u0, 1, u1, 0, u1, 1);
        idx.push(vi, vi + 1, vi + 2, vi + 1, vi + 3, vi + 2); vi += 4;
      }
      acc += len;
    }
    this.length = acc;
    const g = this.ribbon.geometry;
    g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
    g.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2));
    g.setIndex(idx);
    if (color) { this.mat.color.copy(lin(color)).multiplyScalar(2.2); }
    this.ribbon.visible = true;
  },
  clear() { this.path = null; this.length = 0; if (this.ribbon) this.ribbon.visible = false; },
  update(dt) { if (this.ribbon && this.ribbon.visible) this.tex.offset.x -= dt * 1.4; },
};

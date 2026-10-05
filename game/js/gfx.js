'use strict';
/* ============================================================
   GFX: renderer, postprocessing (bloom + grading), niebo, materiały PBR,
   proceduralne tekstury oraz narzędzia do scalania geometrii
   ============================================================ */

const GFX = {
  renderer: null, composer: null, bloom: null, grade: null, scene: null, camera: null,
  quality: 'high', usePost: false, hdr: false, matCache: {}, matList: [], texCache: {},
  skyMat: null, skyMesh: null, envScene: null, envMesh: null, pmrem: null, envKey: '', envTarget: null,
  envIntensity: 0.6, sun: null,
};

const lin = (c) => { const col = (c instanceof THREE.Color) ? c.clone() : new THREE.Color(c); return col.convertSRGBToLinear(); };
const rr = (a, b) => a + Math.random() * (b - a);
const pick = (arr) => arr[(Math.random() * arr.length) | 0];
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const lerp = (a, b, t) => a + (b - a) * t;

function mulberry(a) { return function () { a |= 0; a = a + 0x6D2B79F5 | 0; let t = Math.imul(a ^ a >>> 15, 1 | a); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }

/* ---------- jakość ---------- */
GFX.presets = {
  high: { pr: 1.5, bloom: true, shadow: 2048, hdr: true, fxaa: true },
  med:  { pr: 1.0, bloom: true, shadow: 1024, hdr: true, fxaa: true },
  low:  { pr: 1.0, bloom: false, shadow: 1024, hdr: false, fxaa: false },
};

GFX.init = function (host) {
  let q = 'high';
  try { q = localStorage.getItem('cr_quality') || 'high'; } catch (e) {}
  if (/lite|low/.test(location.search)) q = 'low';
  if (!GFX.presets[q]) q = 'high';
  GFX.quality = q;
  const r = new THREE.WebGLRenderer({ antialias: q === 'low', powerPreference: 'high-performance', stencil: false });
  r.setSize(window.innerWidth, window.innerHeight);
  r.shadowMap.enabled = true; r.shadowMap.type = THREE.PCFSoftShadowMap;
  r.physicallyCorrectLights = false;
  host.appendChild(r.domElement);
  GFX.renderer = r;
  GFX.isGL2 = r.capabilities.isWebGL2;
  GFX.hdrOK = GFX.isGL2 && (r.extensions.has('EXT_color_buffer_float') || r.extensions.has('EXT_color_buffer_half_float'));
  window.addEventListener('resize', () => GFX.resize());
};

GFX.attach = function (scene, camera, sun) {
  GFX.scene = scene; GFX.camera = camera; GFX.sun = sun;
  GFX.buildSky();
  GFX.setQuality(GFX.quality, true);
};

GFX.setQuality = function (q, first) {
  const P = GFX.presets[q]; GFX.quality = q;
  try { localStorage.setItem('cr_quality', q); } catch (e) {}
  const r = GFX.renderer, w = window.innerWidth, h = window.innerHeight;
  r.setPixelRatio(Math.min(window.devicePixelRatio || 1, P.pr));
  const wantPost = q !== 'low' && !!THREE.EffectComposer && GFX.isGL2;
  // sprzątanie starego composera
  if (GFX.composer) { try { GFX.composer.renderTarget1.dispose(); GFX.composer.renderTarget2.dispose(); } catch (e) {} GFX.composer = null; }
  GFX.usePost = false;
  if (wantPost) {
    try {
      const pr = r.getPixelRatio();
      const useHDR = P.hdr && GFX.hdrOK;
      GFX.hdr = useHDR;
      // uwaga: HDR + MSAA bywa wadliwe na części kart, dlatego wygładzanie robi FXAA
      const rt = new THREE.WebGLRenderTarget(w * pr, h * pr, { format: THREE.RGBAFormat, type: useHDR ? THREE.HalfFloatType : THREE.UnsignedByteType, minFilter: THREE.LinearFilter, magFilter: THREE.LinearFilter });
      const comp = new THREE.EffectComposer(r, rt);
      comp.setPixelRatio(pr); comp.setSize(w, h);
      comp.addPass(new THREE.RenderPass(GFX.scene, GFX.camera));
      if (P.bloom) {
        GFX.bloom = new THREE.UnrealBloomPass(new THREE.Vector2(w, h), 0.55, 0.65, 1.0);
        comp.addPass(GFX.bloom);
      } else GFX.bloom = null;
      GFX.grade = new THREE.ShaderPass(GFX.GradeShader);
      comp.addPass(GFX.grade);
      GFX.fxaa = null;
      if (P.fxaa && THREE.FXAAShader) {
        GFX.fxaa = new THREE.ShaderPass(THREE.FXAAShader);
        GFX.fxaa.material.uniforms.resolution.value.set(1 / (w * pr), 1 / (h * pr));
        comp.addPass(GFX.fxaa);
      }
      GFX.composer = comp; GFX.usePost = true;
      r.outputEncoding = THREE.LinearEncoding; r.toneMapping = THREE.NoToneMapping;
    } catch (e) { console.warn('post off', e); GFX.usePost = false; GFX.composer = null; }
  }
  if (!GFX.usePost) { r.outputEncoding = THREE.sRGBEncoding; r.toneMapping = THREE.ACESFilmicToneMapping; r.toneMappingExposure = 1.0; }
  // cienie
  if (GFX.sun) {
    GFX.sun.shadow.mapSize.set(P.shadow, P.shadow);
    if (GFX.sun.shadow.map) { GFX.sun.shadow.map.dispose(); GFX.sun.shadow.map = null; }
  }
  if (!first && GFX.scene) GFX.scene.traverse(o => { if (o.material) (Array.isArray(o.material) ? o.material : [o.material]).forEach(m => m.needsUpdate = true); });
};

GFX.resize = function () {
  const w = window.innerWidth, h = window.innerHeight;
  GFX.renderer.setSize(w, h);
  if (GFX.camera) { GFX.camera.aspect = w / h; GFX.camera.updateProjectionMatrix(); }
  if (GFX.composer) GFX.composer.setSize(w, h);
  if (GFX.fxaa) { const pr = GFX.renderer.getPixelRatio(); GFX.fxaa.material.uniforms.resolution.value.set(1 / (w * pr), 1 / (h * pr)); }
};

GFX.render = function (dt) {
  if (GFX.skyMesh && GFX.camera) GFX.skyMesh.position.copy(GFX.camera.position);
  if (GFX.usePost && GFX.composer) {
    GFX.grade.uniforms.time.value += dt;
    GFX.composer.render(dt);
  } else GFX.renderer.render(GFX.scene, GFX.camera);
};

/* ---------- shader końcowy: tone mapping ACES + gamma + winieta + ziarno ---------- */
GFX.GradeShader = {
  uniforms: { tDiffuse: { value: null }, exposure: { value: 1.0 }, vignette: { value: 0.75 }, grain: { value: 0.025 }, time: { value: 0 }, sat: { value: 1.08 }, tint: { value: new THREE.Vector3(1, 1, 1) }, shake: { value: 0 } },
  vertexShader: 'varying vec2 vUv; void main(){ vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0); }',
  fragmentShader: `
    uniform sampler2D tDiffuse; uniform float exposure, vignette, grain, time, sat, shake; uniform vec3 tint; varying vec2 vUv;
    vec3 aces(vec3 x){ const float a=2.51,b=0.03,c=2.43,d=0.59,e=0.14; return clamp((x*(a*x+b))/(x*(c*x+d)+e),0.0,1.0); }
    void main(){
      vec2 uv = vUv;
      vec2 q = uv - 0.5;
      float ab = dot(q,q) * 0.006 + shake * 0.004;
      vec3 col;
      col.r = texture2D(tDiffuse, uv + q*ab).r;
      col.g = texture2D(tDiffuse, uv).g;
      col.b = texture2D(tDiffuse, uv - q*ab).b;
      col *= exposure * tint;
      col = aces(col);
      float l = dot(col, vec3(0.2126,0.7152,0.0722));
      col = mix(vec3(l), col, sat);
      col = pow(col, vec3(1.0/2.2));
      col *= 1.0 - dot(q,q) * vignette;
      float g = fract(sin(dot(uv * vec2(1920.0,1080.0) + time, vec2(12.9898,78.233))) * 43758.5453);
      col += (g - 0.5) * grain;
      gl_FragColor = vec4(col, 1.0);
    }`,
};

/* ---------- niebo (kopuła z chmurami, słońcem) + mapa otoczenia ---------- */
GFX.buildSky = function () {
  const mat = new THREE.ShaderMaterial({
    side: THREE.BackSide, depthWrite: false, fog: false,
    uniforms: {
      uTop: { value: new THREE.Color(0x3a6ea5) }, uHorizon: { value: new THREE.Color(0xa8c8e8) }, uSunDir: { value: new THREE.Vector3(0, 1, 0) },
      uSunColor: { value: new THREE.Color(1, 0.9, 0.7) }, uNight: { value: 0 }, uTime: { value: 0 }, uCloud: { value: 0.6 },
    },
    vertexShader: 'varying vec3 vDir; void main(){ vDir = normalize(position); gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0); }',
    fragmentShader: `
      uniform vec3 uTop, uHorizon, uSunDir, uSunColor; uniform float uNight, uTime, uCloud; varying vec3 vDir;
      float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
      float noise(vec2 p){ vec2 i = floor(p), f = fract(p); f = f*f*(3.0-2.0*f);
        return mix(mix(hash(i), hash(i+vec2(1,0)), f.x), mix(hash(i+vec2(0,1)), hash(i+vec2(1,1)), f.x), f.y); }
      float fbm(vec2 p){ float v = 0.0, a = 0.5; for(int i=0;i<5;i++){ v += a*noise(p); p = p*2.03 + 17.0; a *= 0.5; } return v; }
      void main(){
        vec3 d = normalize(vDir);
        float h = clamp(d.y, 0.0, 1.0);
        vec3 col = mix(uHorizon, uTop, pow(h, 0.5));
        if (d.y < 0.0) col = mix(uHorizon, uHorizon * 0.55, clamp(-d.y * 5.0, 0.0, 1.0));
        float sd = max(dot(d, uSunDir), 0.0);
        col += uSunColor * (pow(sd, 700.0) * 14.0 + pow(sd, 14.0) * 0.45 * (1.0 - uNight));
        if (d.y > 0.0) {
          vec2 uv = d.xz / (d.y + 0.2) * 1.4 + vec2(uTime * 0.012, uTime * 0.004);
          float c = smoothstep(0.42, 0.78, fbm(uv * 1.3));
          c *= smoothstep(0.0, 0.22, d.y);
          vec3 cc = mix(vec3(1.0, 0.98, 0.96), uHorizon * 1.1, 0.35) * (1.0 - uNight * 0.9);
          float shade = fbm(uv * 1.3 + vec2(0.04, 0.03));
          cc *= 0.82 + 0.35 * (shade - 0.5) + 0.2;
          col = mix(col, cc, c * uCloud);
        }
        gl_FragColor = vec4(col, 1.0);
        #include <tonemapping_fragment>
        #include <encodings_fragment>
      }`,
  });
  GFX.skyMat = mat;
  const sky = new THREE.Mesh(new THREE.SphereGeometry(450, 32, 20), mat);
  sky.renderOrder = -10; sky.frustumCulled = false;
  GFX.scene.add(sky); GFX.skyMesh = sky;
  GFX.pmrem = new THREE.PMREMGenerator(GFX.renderer);
  GFX.envScene = new THREE.Scene();
  GFX.envMesh = new THREE.Mesh(new THREE.SphereGeometry(100, 24, 16), mat);
  GFX.envScene.add(GFX.envMesh);
};

/* odświeża mapę otoczenia (odbicia) – wywoływane tylko przy zmianie pory dnia */
GFX.updateEnv = function (key) {
  if (key === GFX.envKey) return;
  GFX.envKey = key;
  try {
    const sky = GFX.skyMesh; GFX.scene.remove(sky);
    const rt = GFX.pmrem.fromScene(GFX.envScene, 0.02, 1, 300);
    GFX.scene.add(sky);
    if (GFX.envTarget) GFX.envTarget.dispose();
    GFX.envTarget = rt; GFX.scene.environment = rt.texture;
  } catch (e) { console.warn('env', e); }
};
GFX.setEnvIntensity = function (v) {
  if (Math.abs(v - GFX.envIntensity) < 0.01) return;
  GFX.envIntensity = v;
  for (const m of GFX.matList) if (m.userData.envBase != null) m.envMapIntensity = m.userData.envBase * v;
};

/* ---------- materiały ---------- */
/* mat(color, {rough, metal, emissive, ei, map, bump, bumpScale, vc, transparent, opacity, side, env, normalMap}) */
GFX.mat = function (color, o) {
  o = o || {};
  const key = (typeof color === 'object' && color.isColor ? color.getHexString() : String(color)) + '|' + [o.rough, o.metal, o.emissive, o.ei, o.map && o.map.uuid, o.bump && o.bump.uuid, o.vc, o.transparent, o.opacity, o.side, o.env, o.alphaTest, o.key, o.emissiveMap && o.emissiveMap.uuid].join(',');
  let m = GFX.matCache[key]; if (m) return m;
  const p = { color: lin(color), roughness: o.rough != null ? o.rough : 0.8, metalness: o.metal != null ? o.metal : 0.0 };
  if (o.vc) p.vertexColors = true;
  if (o.map) p.map = o.map;
  if (o.bump) { p.bumpMap = o.bump; p.bumpScale = o.bumpScale != null ? o.bumpScale : 1.0; }
  if (o.normalMap) p.normalMap = o.normalMap;
  if (o.emissive != null) { p.emissive = lin(o.emissive); p.emissiveIntensity = o.ei != null ? o.ei : 1; }
  if (o.emissiveMap) p.emissiveMap = o.emissiveMap;
  if (o.transparent) { p.transparent = true; p.opacity = o.opacity != null ? o.opacity : 1; }
  if (o.alphaTest) p.alphaTest = o.alphaTest;
  if (o.side != null) p.side = o.side;
  m = new THREE.MeshStandardMaterial(p);
  m.userData.envBase = o.env != null ? o.env : 1.0;
  m.envMapIntensity = m.userData.envBase * GFX.envIntensity;
  GFX.matCache[key] = m; GFX.matList.push(m);
  return m;
};
/* materiał bez oświetlenia (neony, znaczniki) */
GFX.basic = function (color, o) {
  o = o || {};
  return new THREE.MeshBasicMaterial(Object.assign({ color: lin(color) }, o));
};

/* ---------- tekstury proceduralne ---------- */
GFX.canvas = function (w, h, draw) {
  const c = document.createElement('canvas'); c.width = w; c.height = h;
  const g = c.getContext('2d'); draw(g, w, h); return c;
};
GFX.tex = function (canvas, o) {
  o = o || {};
  const t = new THREE.CanvasTexture(canvas);
  t.encoding = o.linear ? THREE.LinearEncoding : THREE.sRGBEncoding;
  t.anisotropy = o.aniso || 8;
  if (o.repeat) t.wrapS = t.wrapT = THREE.RepeatWrapping;
  if (o.mip === false) { t.generateMipmaps = false; t.minFilter = THREE.LinearFilter; }
  return t;
};

/* szum wartościowy, okresowy (tileable) */
GFX.noiseGrid = function (period, seed) {
  const r = mulberry(seed || 1), g = new Float32Array(period * period);
  for (let i = 0; i < g.length; i++) g[i] = r();
  return { p: period, g };
};
GFX.noise2 = function (N, x, y) {
  const p = N.p;
  const xi = Math.floor(x), yi = Math.floor(y), xf = x - xi, yf = y - yi;
  const x0 = ((xi % p) + p) % p, x1 = (x0 + 1) % p, y0 = ((yi % p) + p) % p, y1 = (y0 + 1) % p;
  const sx = xf * xf * (3 - 2 * xf), sy = yf * yf * (3 - 2 * yf);
  const a = N.g[y0 * p + x0], b = N.g[y0 * p + x1], c = N.g[y1 * p + x0], d = N.g[y1 * p + x1];
  return (a + (b - a) * sx) + ((c + (d - c) * sx) - (a + (b - a) * sx)) * sy;
};
/* wypełnia ImageData funkcją koloru z szumu fBm; fn(n, x, y) -> [r,g,b] */
GFX.fbmPaint = function (g, w, h, baseScale, octaves, seed, fn) {
  const img = g.createImageData(w, h), d = img.data;
  const grids = []; for (let o = 0; o < octaves; o++) grids.push(GFX.noiseGrid(Math.round(baseScale * Math.pow(2, o)), (seed || 1) * 31 + o));
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    let v = 0, a = 0.5, tot = 0;
    for (let o = 0; o < octaves; o++) {
      const s = baseScale * Math.pow(2, o);
      v += a * GFX.noise2(grids[o], x / w * s, y / h * s); tot += a; a *= 0.5;
    }
    v /= tot;
    const c = fn(v, x, y), i = (y * w + x) * 4;
    d[i] = c[0]; d[i + 1] = c[1]; d[i + 2] = c[2]; d[i + 3] = c[3] != null ? c[3] : 255;
  }
  g.putImageData(img, 0, 0);
};

/* ---------- scalanie geometrii (z kolorami wierzchołków) ---------- */
class GB {
  constructor() { this.p = []; this.n = []; this.u = []; this.c = []; }
  add(geo, color, o) {
    o = o || {};
    let g = geo.index ? geo.toNonIndexed() : geo;
    if (o.x != null || o.y != null || o.z != null || o.rx || o.ry || o.rz || o.sx != null || o.sy != null || o.sz != null) {
      const m = new THREE.Matrix4().compose(
        new THREE.Vector3(o.x || 0, o.y || 0, o.z || 0),
        new THREE.Quaternion().setFromEuler(new THREE.Euler(o.rx || 0, o.ry || 0, o.rz || 0, 'YXZ')),
        new THREE.Vector3(o.sx != null ? o.sx : 1, o.sy != null ? o.sy : 1, o.sz != null ? o.sz : 1));
      g = g === geo ? g.clone() : g; g.applyMatrix4(m);
    }
    const pa = g.attributes.position.array, na = g.attributes.normal.array, ua = g.attributes.uv ? g.attributes.uv.array : null;
    const col = lin(color || '#ffffff'), n = pa.length / 3;
    for (let i = 0; i < pa.length; i++) { this.p.push(pa[i]); this.n.push(na[i]); }
    for (let i = 0; i < n; i++) { this.u.push(ua ? ua[i * 2] : 0, ua ? ua[i * 2 + 1] : 0); this.c.push(col.r, col.g, col.b); }
    return this;
  }
  box(w, h, d, color, o) { return this.add(new THREE.BoxGeometry(w, h, d), color, o); }
  cyl(rt, rb, h, color, o) { return this.add(new THREE.CylinderGeometry(rt, rb, h, (o && o.seg) || 12, 1, !!(o && o.open)), color, o); }
  sph(r, color, o) { return this.add(new THREE.SphereGeometry(r, (o && o.ws) || 14, (o && o.hs) || 10, 0, Math.PI * 2, (o && o.t0) || 0, (o && o.tl) || Math.PI), color, o); }
  cone(r, h, color, o) { return this.add(new THREE.ConeGeometry(r, h, (o && o.seg) || 10), color, o); }
  plane(w, h, color, o) { return this.add(new THREE.PlaneGeometry(w, h), color, o); }
  ico(r, color, o) { return this.add(new THREE.IcosahedronGeometry(r, (o && o.detail) || 1), color, o); }
  build() {
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.Float32BufferAttribute(this.p, 3));
    g.setAttribute('normal', new THREE.Float32BufferAttribute(this.n, 3));
    g.setAttribute('uv', new THREE.Float32BufferAttribute(this.u, 2));
    g.setAttribute('color', new THREE.Float32BufferAttribute(this.c, 3));
    g.computeBoundingSphere(); g.computeBoundingBox();
    return g;
  }
}
/* gotowy mesh z kolorami wierzchołków */
GFX.meshFromGB = function (gb, o) {
  o = o || {};
  const m = new THREE.Mesh(gb.build(), o.material || GFX.mat('#ffffff', { vc: true, rough: o.rough != null ? o.rough : 0.75, metal: o.metal || 0, key: 'vc' + (o.rough || 0) + (o.metal || 0), env: o.env }));
  m.castShadow = o.cast !== false; m.receiveShadow = o.receive !== false;
  return m;
};

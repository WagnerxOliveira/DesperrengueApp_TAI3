// Gera os 3 micro-lotties da apresentacao pos-cadastro (v2.27.0).
// Autoria propria, 100% vetorial, 60 fps, sem rede. Uso: node scripts/gen_lottie_assets.mjs
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const OUT = join(dirname(fileURLToPath(import.meta.url)), '..', 'app', 'assets', 'lottie');
mkdirSync(OUT, { recursive: true });

const rgb = (hex) => [1, 3, 5].map((i) => +(parseInt(hex.slice(i, i + 2), 16) / 255).toFixed(4)).concat(1);
const EMERALD = rgb('#10B981');
const EMERALD_LIGHT = rgb('#A7F3D0');
const GOLD = rgb('#FDE68A');
const WHITE = rgb('#FFFFFF');

const EASE = { o: { x: 0.2, y: 0 }, i: { x: 0.2, y: 1 } };
const LINEAR = { o: { x: 0.5, y: 0.5 }, i: { x: 0.5, y: 0.5 } };
const stat = (k) => ({ a: 0, k });
// frames: [[t, valor|array, easing?], ...]
const anim = (frames) => ({
  a: 1,
  k: frames.map(([t, v, e], idx) => {
    const s = Array.isArray(v) ? v : [v];
    if (idx === frames.length - 1) return { t, s };
    return { t, s, ...(e ?? EASE) };
  }),
});

const tr = (o = {}) => ({
  ty: 'tr',
  p: o.p ?? stat([0, 0]),
  a: stat([0, 0]),
  s: o.s ?? stat([100, 100]),
  r: o.r ?? stat(0),
  o: o.o ?? stat(100),
  sk: stat(0),
  sa: stat(0),
});
const group = (nm, items, t) => ({ ty: 'gr', nm, it: [...items, tr(t)] });
const ellipse = (d) => ({ ty: 'el', p: stat([0, 0]), s: stat([d, d]), d: 1 });
const rect = (w, h, r, p = [0, 0]) => ({ ty: 'rc', p: stat(p), s: stat([w, h]), r: stat(r), d: 1 });
const path = (v, i, o, c = false) => ({
  ty: 'sh',
  ks: stat({ i: i ?? v.map(() => [0, 0]), o: o ?? v.map(() => [0, 0]), v, c }),
});
const fill = (c, o = stat(100)) => ({ ty: 'fl', c: stat(c), o, r: 1 });
const stroke = (c, w, o = stat(100)) => ({ ty: 'st', c: stat(c), o, w: stat(w), lc: 2, lj: 2, ml: 4 });
const trim = (end, start = stat(0)) => ({ ty: 'tm', s: start, e: end, o: stat(0), m: 1 });

let ind = 0;
const layer = (nm, shapes, ks, op) => ({
  ddd: 0,
  ind: ++ind,
  ty: 4,
  nm,
  sr: 1,
  ks: {
    o: ks.o ?? stat(100),
    r: ks.r ?? stat(0),
    p: ks.p ?? stat([100, 100]),
    a: ks.a ?? stat([0, 0]),
    s: ks.s ?? stat([100, 100]),
  },
  ao: 0,
  shapes,
  ip: 0,
  op,
  st: 0,
  bm: 0,
});
const comp = (nm, op, layers) => ({ v: '5.7.0', fr: 60, ip: 0, op, w: 200, h: 200, nm, ddd: 0, assets: [], layers });
const save = (file, json) => {
  const txt = JSON.stringify(json);
  writeFileSync(join(OUT, file), txt);
  console.log(file, (txt.length / 1024).toFixed(1) + ' KB');
};

// ---------------------------------------------------------------- check_burst (72 f = 1,2 s)
{
  const OP = 72;
  const layers = [];
  // check branco que se desenha
  layers.push(
    layer('check', [
      group('traco', [
        path([[-26, 2], [-8, 20], [27, -17]]),
        trim(anim([[26, 0], [46, 100]])),
        stroke(WHITE, 11),
      ]),
    ], { }, OP),
  );
  // 8 particulas do burst
  for (let n = 0; n < 8; n++) {
    const ang = (n * Math.PI) / 4 + Math.PI / 8;
    const r0 = 60, r1 = 88 + (n % 2) * 6;
    const dx = Math.cos(ang), dy = Math.sin(ang);
    layers.push(
      layer(`particula${n}`, [group('p', [ellipse(n % 2 ? 7 : 10), fill(n % 2 ? EMERALD_LIGHT : EMERALD)])], {
        p: anim([
          [30, [100 + dx * r0, 100 + dy * r0]],
          [62, [100 + dx * r1, 100 + dy * r1]],
        ]),
        o: anim([[30, 0, LINEAR], [34, 100, LINEAR], [48, 100, LINEAR], [62, 0]]),
        s: anim([[30, [60, 60]], [62, [30, 30]]]),
      }, OP),
    );
  }
  // anel de onda
  layers.push(
    layer('onda', [group('o', [ellipse(120), stroke(EMERALD_LIGHT, 4)])], {
      s: anim([[28, [100, 100]], [66, [150, 150]]]),
      o: anim([[28, 0, LINEAR], [32, 80, LINEAR], [66, 0]]),
    }, OP),
  );
  // disco: contorno que desenha + preenchimento + "pop"
  layers.push(
    layer('disco', [
      group('contorno', [ellipse(116), trim(anim([[0, 0], [24, 100]])), stroke(EMERALD, 8)], { r: stat(-90) }),
      group('miolo', [ellipse(116), fill(EMERALD, anim([[14, 0, LINEAR], [30, 100]]))]),
    ], {
      s: anim([[0, [90, 90]], [24, [100, 100]], [34, [110, 110]], [46, [100, 100]]]),
    }, OP),
  );
  // ordem de desenho: o primeiro item do array e o topo
  const ordered = [layers[0], ...layers.slice(1, 9), layers[10], layers[9]]; // check, particulas, disco, onda (atras)
  save('check_burst.json', comp('check_burst', OP, ordered));
}

// ---------------------------------------------------------------- lock_close (84 f = 1,4 s)
{
  const OP = 84;
  const OVER = { o: { x: 0.3, y: 0 }, i: { x: 0.6, y: 1 } };
  const layers = [];
  ind = 0;
  // pulso suave depois da trava
  layers.push(
    layer('pulso', [group('p', [ellipse(130), stroke(EMERALD_LIGHT, 5)])], {
      s: anim([[44, [70, 70]], [84, [155, 155]]]),
      o: anim([[44, 0, LINEAR], [48, 70, LINEAR], [84, 0]]),
    }, OP),
  );
  // haste (atras do corpo): desce e trava
  layers.push(
    layer('haste', [
      group('arco', [
        path(
          [[-24, 12], [-24, -22], [24, -22], [24, 12]],
          [[0, 0], [0, 0], [0, -33], [0, 0]],
          [[0, 0], [0, -33], [0, 0], [0, 0]],
        ),
        stroke(EMERALD, 13),
      ]),
    ], {
      p: anim([[4, [100, 78]], [38, [100, 104], OVER], [46, [100, 98]], [54, [100, 100]]]),
      o: anim([[0, 0, LINEAR], [8, 100]]),
    }, OP),
  );
  // corpo + buraco da fechadura
  layers.push(
    layer('corpo', [
      group('fechadura', [ellipse(13), fill(WHITE)], { p: stat([0, 14]) }),
      group('fechadura2', [rect(7, 20, 3.5, [0, 25]), fill(WHITE)]),
      group('caixa', [rect(92, 72, 18, [0, 18]), fill(EMERALD)]),
    ], {
      a: stat([0, 18]),
      p: stat([100, 118]),
      s: anim([[0, [92, 92]], [14, [100, 100]], [40, [100, 100]], [46, [105, 94]], [56, [100, 100]]]),
      o: anim([[0, 0, LINEAR], [8, 100]]),
    }, OP),
  );
  save('lock_close.json', comp('lock_close', OP, [layers[0], layers[1], layers[2]].reverse()));
}

// ---------------------------------------------------------------- sparkle_soft (96 f = 1,6 s)
{
  const OP = 96;
  ind = 0;
  const star = (r) => {
    const k = 0.2 * r;
    return path(
      [[0, -r], [k, -k], [r, 0], [k, k], [0, r], [-k, k], [-r, 0], [-k, -k]],
      [[0, 0], [0, 0], [0, 0], [0, 0], [0, 0], [0, 0], [0, 0], [0, 0]],
      [[0, 0], [0, 0], [0, 0], [0, 0], [0, 0], [0, 0], [0, 0], [0, 0]],
      true,
    );
  };
  const spec = [
    { x: 62, y: 72, r: 24, t0: 0, rot: 45 },
    { x: 142, y: 54, r: 17, t0: 18, rot: -45 },
    { x: 120, y: 142, r: 13, t0: 38, rot: 45 },
  ];
  const layers = spec.map((s, n) =>
    layer(`brilho${n}`, [group('b', [star(s.r), fill(GOLD)])], {
      p: stat([s.x, s.y]),
      s: anim([
        [s.t0, [0, 0]],
        [s.t0 + 18, [100, 100]],
        [s.t0 + 46, [0, 0]],
      ]),
      r: anim([[s.t0, 0, LINEAR], [s.t0 + 46, s.rot]]),
      o: anim([[s.t0, 0, LINEAR], [s.t0 + 6, 100, LINEAR], [s.t0 + 34, 100, LINEAR], [s.t0 + 46, 0]]),
    }, OP),
  );
  // pontinhos discretos
  [[92, 96, 5, 10], [162, 98, 4, 30], [78, 40, 4, 50]].forEach(([x, y, d, t0], n) => {
    layers.push(
      layer(`ponto${n}`, [group('p', [ellipse(d), fill(GOLD)])], {
        p: stat([x, y]),
        o: anim([[t0, 0, LINEAR], [t0 + 8, 90, LINEAR], [t0 + 30, 0]]),
        s: anim([[t0, [40, 40]], [t0 + 30, [120, 120]]]),
      }, OP),
    );
  });
  save('sparkle_soft.json', comp('sparkle_soft', OP, layers));
}

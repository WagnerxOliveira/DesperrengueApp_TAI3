#!/usr/bin/env python3
"""
Deterministic Mathematical SDF & Supersampled Vector Icon Generator for
Desperrengue CEO (br.com.desperrengue.app.founder).

Preserves 100% of the G1-continuous "Casa-Escudo D" + Central Checkmark brand DNA
while elevating it into the Sovereign Executive Edition:
  1. Canvas: Deep Jet-Black Obsidian Velvet (#05070B -> #0C1018 -> #17130C warm core)
     with an unclipped concentric 24k Gold Horological Guilloche Medallion Halo.
  2. Primary Monogram ("Casa-Escudo D"): 24k Brushed Imperial Gold (#FFFBEB -> #FDE047
     -> #F59E0B -> #D97706) with C2-smooth 3D horological bevel & specular rim lighting.
  3. Sovereign Apex Diamond Keystone: 4-facet horological diamond crowning the
     45-degree roof ridge at x = 0.490 with parallel Gestalt negative space,
     ensuring 100% silhouette distinction even in Android 13-16 Monochrome mode.
  4. Central Resolution Checkmark: Luminous Platinum-Cyan (#ECFEFF -> #67E8F9
     -> #52B7C0 -> #0891B2) representing Zero-Trust cryptographic custody & solvency.
"""

from __future__ import annotations

import math
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont


ROOT_DIR = Path(__file__).resolve().parent.parent
FOUNDER_RES_DIR = ROOT_DIR / "app" / "android" / "app" / "src" / "founder" / "res"
MAIN_RES_DIR = ROOT_DIR / "app" / "android" / "app" / "src" / "main" / "res"
PUBLIC_ICONS_DIR = ROOT_DIR / "app" / "assets" / "icons"
BRAND_DOCS_DIR = ROOT_DIR / "docs" / "brand"


def _srgb_hex(hex_str: str) -> np.ndarray:
    h = hex_str.lstrip("#")
    return np.array([int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)], dtype=np.float32)


def _dist_segment_with_grad(
    px: np.ndarray, py: np.ndarray, x0: float, y0: float, x1: float, y1: float
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    dx = x1 - x0
    dy = y1 - y0
    l2 = dx * dx + dy * dy
    t = np.clip(((px - x0) * dx + (py - y0) * dy) / l2, 0.0, 1.0)
    cx = x0 + t * dx
    cy = y0 + t * dy
    vx = px - cx
    vy = py - cy
    d = np.hypot(vx, vy)
    inv_d = 1.0 / np.maximum(d, 1e-7)
    return d, vx * inv_d, vy * inv_d


def _dist_polyline_qbezier_with_grad(
    px: np.ndarray,
    py: np.ndarray,
    x0: float,
    y0: float,
    x1: float,
    y1: float,
    x2: float,
    y2: float,
    steps: int = 20,
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    ts = np.linspace(0.0, 1.0, steps + 1, dtype=np.float32)
    omt = 1.0 - ts
    bx = omt * omt * x0 + 2.0 * omt * ts * x1 + ts * ts * x2
    by = omt * omt * y0 + 2.0 * omt * ts * y1 + ts * ts * y2

    best_d = np.full_like(px, 1e9, dtype=np.float32)
    best_gx = np.zeros_like(px, dtype=np.float32)
    best_gy = np.zeros_like(px, dtype=np.float32)

    for i in range(steps):
        d, gx, gy = _dist_segment_with_grad(
            px, py, float(bx[i]), float(by[i]), float(bx[i + 1]), float(by[i + 1])
        )
        mask = d < best_d
        best_d = np.where(mask, d, best_d)
        best_gx = np.where(mask, gx, best_gx)
        best_gy = np.where(mask, gy, best_gy)
    return best_d, best_gx, best_gy


def _dist_d_house_with_grad(
    nx: np.ndarray, ny: np.ndarray
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """
    Exact distance & outward unit gradient to the G1-continuous Casa-Escudo 'D'
    centerline in normalized [0..1] coordinates.
    """
    best_d = np.full_like(nx, 1e9, dtype=np.float32)
    best_gx = np.zeros_like(nx, dtype=np.float32)
    best_gy = np.zeros_like(nx, dtype=np.float32)

    def update(d: np.ndarray, gx: np.ndarray, gy: np.ndarray) -> None:
        nonlocal best_d, best_gx, best_gy
        m = d < best_d
        best_d = np.where(m, d, best_d)
        best_gx = np.where(m, gx, best_gx)
        best_gy = np.where(m, gy, best_gy)

    # 1. Left vertical pillar: (0.21, 0.595) -> (0.21, 0.84)
    update(*_dist_segment_with_grad(nx, ny, 0.21, 0.595, 0.21, 0.84))

    # 2. Bottom-left rounded quadratic corner: (0.21, 0.84) -> (0.21, 0.91) -> (0.28, 0.91)
    update(*_dist_polyline_qbezier_with_grad(nx, ny, 0.21, 0.84, 0.21, 0.91, 0.28, 0.91, steps=16))

    # 3. Bottom horizontal base: (0.28, 0.91) -> (0.49, 0.91)
    update(*_dist_segment_with_grad(nx, ny, 0.28, 0.91, 0.49, 0.91))

    # 4. Circular shield arc: center (0.49, 0.56), R = 0.35, angle in [-pi/4, +pi/2]
    cx, cy, r_arc = 0.49, 0.56, 0.35
    vx = nx - cx
    vy = ny - cy
    rad = np.hypot(vx, vy)
    ang = np.arctan2(vy, vx)
    in_cone = (ang >= -math.pi / 4.0) & (ang <= math.pi / 2.0)

    d_arc = np.abs(rad - r_arc)
    sgn = np.where(rad >= r_arc, 1.0, -1.0).astype(np.float32)
    inv_rad = 1.0 / np.maximum(rad, 1e-7)
    gx_arc = vx * inv_rad * sgn
    gy_arc = vy * inv_rad * sgn

    ax0, ay0 = 0.49, 0.91
    ax1 = 0.49 + 0.35 * math.cos(math.pi / 4.0)
    ay1 = 0.56 - 0.35 * math.sin(math.pi / 4.0)
    d_ep0 = np.hypot(nx - ax0, ny - ay0)
    d_ep1 = np.hypot(nx - ax1, ny - ay1)
    use_ep0 = d_ep0 < d_ep1
    d_ep = np.where(use_ep0, d_ep0, d_ep1)
    gx_ep = np.where(
        use_ep0,
        (nx - ax0) / np.maximum(d_ep0, 1e-7),
        (nx - ax1) / np.maximum(d_ep1, 1e-7),
    )
    gy_ep = np.where(
        use_ep0,
        (ny - ay0) / np.maximum(d_ep0, 1e-7),
        (ny - ay1) / np.maximum(d_ep1, 1e-7),
    )
    update(
        np.where(in_cone, d_arc, d_ep),
        np.where(in_cone, gx_arc, gx_ep),
        np.where(in_cone, gy_arc, gy_ep),
    )

    # 5. Right roof slope at -45 deg: (ax1, ay1) -> (0.555, 0.130)
    update(*_dist_segment_with_grad(nx, ny, ax1, ay1, 0.555, 0.130))

    # 6. Rounded ridge peak: (0.555, 0.130) -> (0.490, 0.065) -> (0.425, 0.130)
    update(*_dist_polyline_qbezier_with_grad(nx, ny, 0.555, 0.130, 0.490, 0.065, 0.425, 0.130, steps=20))

    # 7. Left protective roof eave at +45 deg: (0.425, 0.130) -> (0.105, 0.450)
    update(*_dist_segment_with_grad(nx, ny, 0.425, 0.130, 0.105, 0.450))

    return best_d, best_gx, best_gy


def _dist_checkmark_with_grad(
    nx: np.ndarray, ny: np.ndarray
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """
    Exact distance & outward unit gradient to the Central Resolution Checkmark:
      (0.380, 0.555) -> (0.470, 0.645) -> (0.625, 0.455)
    """
    d1, gx1, gy1 = _dist_segment_with_grad(nx, ny, 0.380, 0.555, 0.470, 0.645)
    d2, gx2, gy2 = _dist_segment_with_grad(nx, ny, 0.470, 0.645, 0.625, 0.455)
    m = d1 < d2
    return np.where(m, d1, d2), np.where(m, gx1, gx2), np.where(m, gy1, gy2)


def _sdf_sovereign_diamond(
    nx: np.ndarray,
    ny: np.ndarray,
    cx: float = 0.490,
    cy: float = -0.094,
    half_span: float = 0.088,
    corner_r: float = 0.012,
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """
    Exact Signed Distance Field for a 45-degree rotated square (Sovereign Diamond
    Keystone) with rounded horological corners.
    """
    dx = nx - cx
    dy = ny - cy
    inv_sqrt2 = 0.70710678
    rx = (dx + dy) * inv_sqrt2
    ry = (dy - dx) * inv_sqrt2

    b = (half_span - corner_r) * inv_sqrt2
    qx = np.abs(rx) - b
    qy = np.abs(ry) - b

    mx = np.maximum(qx, 0.0)
    my = np.maximum(qy, 0.0)
    out_dist = np.hypot(mx, my)
    in_dist = np.minimum(np.maximum(qx, qy), 0.0)
    sdf = out_dist + in_dist - corner_r

    eps = 1e-6
    gx_r = np.sign(rx) * np.where(out_dist > eps, mx / np.maximum(out_dist, eps), (qx > qy).astype(np.float32))
    gy_r = np.sign(ry) * np.where(out_dist > eps, my / np.maximum(out_dist, eps), (qy >= qx).astype(np.float32))
    gx = (gx_r - gy_r) * inv_sqrt2
    gy = (gx_r + gy_r) * inv_sqrt2
    norm = np.hypot(gx, gy)
    gx = gx / np.maximum(norm, 1e-7)
    gy = gy / np.maximum(norm, 1e-7)
    return sdf, gx, gy


def render_background_layer(size: int, halo_radius_frac: float = 0.298) -> np.ndarray:
    """
    Renders the Deep Obsidian Carbon-Onyx Velvet background (#05070B -> #0B0F17
    -> #19140C subtle warm golden-obsidian core) with a concentric 24k Gold
    Horological Guilloche Medallion Halo strictly inside `halo_radius_frac`.
    """
    coords = (np.arange(size, dtype=np.float32) + 0.5) / float(size)
    yy, xx = np.meshgrid(coords, coords, indexing="ij")

    dx = xx - 0.48
    dy = yy - 0.44
    r_bg = np.hypot(dx, dy) / 0.72

    c_core = _srgb_hex("#161922")
    c_mid = _srgb_hex("#0B0E15")
    c_edge = _srgb_hex("#05070B")

    t1 = np.clip(r_bg / 0.52, 0.0, 1.0)[..., None]
    t2 = np.clip((r_bg - 0.52) / 0.48, 0.0, 1.0)[..., None]
    rgb = c_core * (1.0 - t1) + c_mid * t1
    rgb = rgb * (1.0 - t2) + c_edge * t2

    cx = xx - 0.50
    cy = yy - 0.50
    rc = np.hypot(cx, cy)
    warm_glow = np.exp(-((rc / (halo_radius_frac * 0.92)) ** 2) * 1.65)[..., None]
    c_warm_gold = _srgb_hex("#2A1F0D")
    rgb = rgb * (1.0 - 0.58 * warm_glow) + c_warm_gold * (0.58 * warm_glow)

    px_unit = 1.0 / float(size)
    r_outer = halo_radius_frac
    r_inner = halo_radius_frac * 0.915

    ring_outer_w = max(1.15 * px_unit, halo_radius_frac * 0.012)
    ring_outer_alpha = np.clip(1.0 - np.abs(rc - r_outer) / ring_outer_w, 0.0, 1.0)
    theta = np.arctan2(cy, cx)
    bezel_sheen = 0.55 + 0.45 * np.cos(theta + 2.15)
    c_gold_bright = _srgb_hex("#FDE047")
    c_gold_deep = _srgb_hex("#B45309")
    bezel_rgb = (
        c_gold_bright[None, None, :] * bezel_sheen[..., None]
        + c_gold_deep[None, None, :] * (1.0 - bezel_sheen[..., None])
    )
    a_outer = (ring_outer_alpha * 0.24)[..., None]
    rgb = rgb * (1.0 - a_outer) + bezel_rgb * a_outer

    ring_inner_w = max(1.0 * px_unit, halo_radius_frac * 0.009)
    ring_inner_alpha = np.clip(1.0 - np.abs(rc - r_inner) / ring_inner_w, 0.0, 1.0)
    a_inner = (ring_inner_alpha * 0.11)[..., None]
    rgb = rgb * (1.0 - a_inner) + bezel_rgb * a_inner

    in_band = (rc >= r_inner) & (rc <= r_outer)
    band_env = np.sin(np.clip((rc - r_inner) / max(r_outer - r_inner, 1e-5), 0.0, 1.0) * math.pi)
    ticks_60 = np.clip((np.cos(theta * 60.0) - 0.72) / 0.28, 0.0, 1.0)
    ticks_12 = np.clip((np.cos(theta * 12.0) - 0.90) / 0.10, 0.0, 1.0)
    tick_alpha = np.where(in_band, band_env * (0.065 * ticks_60 + 0.11 * ticks_12), 0.0)[..., None]
    rgb = rgb * (1.0 - tick_alpha) + bezel_rgb * tick_alpha

    out = np.zeros((size, size, 4), dtype=np.float32)
    out[..., :3] = np.clip(rgb, 0.0, 255.0)
    out[..., 3] = 255.0
    return out


def render_foreground_layer(
    size: int,
    safe_zone_scale: float = 0.425,
    y_optical_shift: float = 0.068,
    monochrome: bool = False,
    with_drop_shadow: bool = True,
) -> np.ndarray:
    """
    Renders the Sovereign Synonym Foreground:
      - G1-continuous "Casa-Escudo D" in 24k Brushed Imperial Gold
      - Sovereign Apex 4-Facet Diamond Keystone crowning the roof peak at x = 0.490
      - Central Resolution Checkmark in Luminous Platinum-Cyan
    """
    coords = (np.arange(size, dtype=np.float32) + 0.5) / float(size)
    yy, xx = np.meshgrid(coords, coords, indexing="ij")

    box_size = safe_zone_scale
    left = 0.5 - box_size * 0.5
    top = 0.5 - box_size * 0.5

    nx = (xx - left) / box_size - 0.012
    ny = (yy - top) / box_size - y_optical_shift

    px_in_norm = 1.0 / (float(size) * box_size)
    aa_width = max(1.15 * px_in_norm, 1e-4)

    r_d = 0.130 * 0.5
    d_center_d, gx_d, gy_d = _dist_d_house_with_grad(nx, ny)
    sdf_d = d_center_d - r_d

    r_check = 0.122 * 0.5
    d_center_chk, gx_chk, gy_chk = _dist_checkmark_with_grad(nx, ny)
    sdf_chk = d_center_chk - r_check

    diamond_cx = 0.490
    diamond_cy = -0.094
    diamond_span = 0.088
    sdf_dia, gx_dia, gy_dia = _sdf_sovereign_diamond(
        nx, ny, cx=diamond_cx, cy=diamond_cy, half_span=diamond_span, corner_r=0.012
    )

    if monochrome:
        sdf_union = np.minimum(np.minimum(sdf_d, sdf_chk), sdf_dia)
        alpha = np.clip(0.5 - sdf_union / aa_width, 0.0, 1.0)
        out = np.zeros((size, size, 4), dtype=np.float32)
        out[..., 0] = 255.0
        out[..., 1] = 255.0
        out[..., 2] = 255.0
        out[..., 3] = alpha * 255.0
        return out

    pm_rgb = np.zeros((size, size, 3), dtype=np.float32)
    pm_a = np.zeros((size, size), dtype=np.float32)

    def blend_over(layer_rgb: np.ndarray, layer_a: np.ndarray) -> None:
        nonlocal pm_rgb, pm_a
        la = np.clip(layer_a, 0.0, 1.0)
        inv = 1.0 - la
        pm_rgb = pm_rgb * inv[..., None] + layer_rgb * la[..., None]
        pm_a = pm_a * inv + la

    if with_drop_shadow:
        sdf_all = np.minimum(np.minimum(sdf_d, sdf_chk), sdf_dia)
        sh_alpha = 0.38 * np.exp(-np.maximum(sdf_all, 0.0) / 0.045)
        sh_rgb = _srgb_hex("#020306")[None, None, :]
        blend_over(sh_rgb, sh_alpha)

    # LAYER A: 24k Brushed Imperial Gold "Casa-Escudo D"
    alpha_d = np.clip(0.5 - sdf_d / aa_width, 0.0, 1.0)

    t_gold = np.clip((nx * 0.38 + ny * 0.82 - 0.04) / 0.88, 0.0, 1.0)
    c_g0 = _srgb_hex("#FFFBEB")
    c_g1 = _srgb_hex("#FDE047")
    c_g2 = _srgb_hex("#F59E0B")
    c_g3 = _srgb_hex("#D97706")

    s1 = np.clip(t_gold / 0.28, 0.0, 1.0)[..., None]
    s2 = np.clip((t_gold - 0.28) / 0.44, 0.0, 1.0)[..., None]
    s3 = np.clip((t_gold - 0.72) / 0.28, 0.0, 1.0)[..., None]
    rgb_d = c_g0 * (1.0 - s1) + c_g1 * s1
    rgb_d = rgb_d * (1.0 - s2) + c_g2 * s2
    rgb_d = rgb_d * (1.0 - s3) + c_g3 * s3

    u_d = np.clip(-sdf_d / r_d, 0.0, 1.0)
    rim_weight_d = (np.clip(1.0 - u_d / 0.42, 0.0, 1.0) ** 2) * np.clip(u_d / 0.08, 0.0, 1.0)
    light_dot_d = -(gx_d * 0.62 + gy_d * 0.78)

    spec_rim = np.clip(light_dot_d, 0.0, 1.0) * rim_weight_d * 0.58
    shadow_rim = np.clip(-light_dot_d, 0.0, 1.0) * rim_weight_d * 0.30

    c_spec_white_gold = _srgb_hex("#FFFDF5")[None, None, :]
    c_deep_bullion = _srgb_hex("#B45309")[None, None, :]

    rgb_d = rgb_d * (1.0 - shadow_rim[..., None]) + c_deep_bullion * shadow_rim[..., None]
    rgb_d = rgb_d + (c_spec_white_gold - rgb_d) * np.clip(spec_rim[..., None], 0.0, 1.0)

    blend_over(rgb_d, alpha_d)

    # LAYER B: Sovereign Apex 4-Facet Diamond Keystone
    alpha_dia = np.clip(0.5 - sdf_dia / aa_width, 0.0, 1.0)

    fx = nx - diamond_cx
    fy = ny - diamond_cy
    px_f = max(1.2 * px_in_norm, 0.0025)
    right_w = np.clip(0.5 + fx / px_f, 0.0, 1.0)
    bot_w = np.clip(0.5 + fy / px_f, 0.0, 1.0)

    f_tl = _srgb_hex("#FFFBEB")
    f_tr = _srgb_hex("#FDE047")
    f_bl = _srgb_hex("#FACC15")
    f_br = _srgb_hex("#D97706")

    f_top = f_tl[None, None, :] * (1.0 - right_w[..., None]) + f_tr[None, None, :] * right_w[..., None]
    f_bot = f_bl[None, None, :] * (1.0 - right_w[..., None]) + f_br[None, None, :] * right_w[..., None]
    rgb_dia = f_top * (1.0 - bot_w[..., None]) + f_bot * bot_w[..., None]

    ridge_cross = np.maximum(
        np.exp(-((fx / 0.0065) ** 2)),
        np.exp(-((fy / 0.0065) ** 2)),
    )
    u_dia = np.clip(-sdf_dia / (diamond_span * 0.707), 0.0, 1.0)
    rim_weight_dia = (np.clip(1.0 - u_dia / 0.38, 0.0, 1.0) ** 2) * np.clip(u_dia / 0.08, 0.0, 1.0)
    light_dot_dia = -(gx_dia * 0.62 + gy_dia * 0.78)
    dia_rim_spec = np.clip(light_dot_dia, 0.0, 1.0) * rim_weight_dia * 0.55
    dia_hi = np.clip(0.42 * ridge_cross + dia_rim_spec, 0.0, 1.0)[..., None]
    rgb_dia = rgb_dia + (c_spec_white_gold - rgb_dia) * dia_hi

    blend_over(rgb_dia, alpha_dia)

    # LAYER C: Luminous Platinum-Cyan Central Resolution Checkmark
    alpha_chk = np.clip(0.5 - sdf_chk / aa_width, 0.0, 1.0)

    t_cyan = np.clip(((nx - 0.36) * 0.65 + (0.66 - ny) * 0.75) / 0.34, 0.0, 1.0)
    c_c0 = _srgb_hex("#0891B2")
    c_c1 = _srgb_hex("#06B6D4")
    c_c2 = _srgb_hex("#67E8F9")
    c_c3 = _srgb_hex("#ECFEFF")

    cs1 = np.clip(t_cyan / 0.35, 0.0, 1.0)[..., None]
    cs2 = np.clip((t_cyan - 0.35) / 0.40, 0.0, 1.0)[..., None]
    cs3 = np.clip((t_cyan - 0.75) / 0.25, 0.0, 1.0)[..., None]
    rgb_chk = c_c0 * (1.0 - cs1) + c_c1 * cs1
    rgb_chk = rgb_chk * (1.0 - cs2) + c_c2 * cs2
    rgb_chk = rgb_chk * (1.0 - cs3) + c_c3 * cs3

    u_chk = np.clip(-sdf_chk / r_check, 0.0, 1.0)
    rim_weight_chk = (np.clip(1.0 - u_chk / 0.42, 0.0, 1.0) ** 2) * np.clip(u_chk / 0.08, 0.0, 1.0)
    light_dot_chk = -(gx_chk * 0.62 + gy_chk * 0.78)
    chk_spec = np.clip(light_dot_chk, 0.0, 1.0) * rim_weight_chk * 0.56
    chk_sh = np.clip(-light_dot_chk, 0.0, 1.0) * rim_weight_chk * 0.26

    c_plat_white = _srgb_hex("#F8FAFC")[None, None, :]
    c_deep_teal = _srgb_hex("#0E7490")[None, None, :]
    rgb_chk = rgb_chk * (1.0 - chk_sh[..., None]) + c_deep_teal * chk_sh[..., None]
    rgb_chk = rgb_chk + (c_plat_white - rgb_chk) * np.clip(chk_spec[..., None], 0.0, 1.0)

    blend_over(rgb_chk, alpha_chk)

    out = np.zeros((size, size, 4), dtype=np.float32)
    safe_a = np.maximum(pm_a, 1e-7)
    out[..., :3] = np.clip(pm_rgb / safe_a[..., None], 0.0, 255.0)
    out[..., 3] = np.clip(pm_a * 255.0, 0.0, 255.0)
    return out


def composite_layers(bg: np.ndarray, fg: np.ndarray) -> np.ndarray:
    a = (fg[..., 3:4]) / 255.0
    rgb = bg[..., :3] * (1.0 - a) + fg[..., :3] * a
    out = np.zeros_like(bg)
    out[..., :3] = np.clip(rgb, 0.0, 255.0)
    out[..., 3] = 255.0
    return out


def to_pil(arr: np.ndarray, target_size: int | None = None) -> Image.Image:
    im = Image.fromarray(np.round(arr).astype(np.uint8), mode="RGBA")
    if target_size is not None and target_size != im.width:
        im = im.resize((target_size, target_size), Image.Resampling.LANCZOS)
    return im


def write_svg_logo(svg_path: Path) -> None:
    """Writes the canonical mathematical vector SVG for Desperrengue CEO."""
    svg_content = """<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
  <defs>
    <radialGradient id="obsidianVelvetBg" cx="48%" cy="46%" r="72%">
      <stop offset="0%" stop-color="#261C0C"/>
      <stop offset="52%" stop-color="#0B0E15"/>
      <stop offset="100%" stop-color="#05070B"/>
    </radialGradient>
    <linearGradient id="imperialGold24k" x1="15%" y1="5%" x2="85%" y2="95%">
      <stop offset="0%" stop-color="#FFFBEB"/>
      <stop offset="28%" stop-color="#FDE047"/>
      <stop offset="72%" stop-color="#F59E0B"/>
      <stop offset="100%" stop-color="#D97706"/>
    </linearGradient>
    <linearGradient id="horologicalBezel" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#FDE047" stop-opacity="0.34"/>
      <stop offset="50%" stop-color="#F59E0B" stop-opacity="0.16"/>
      <stop offset="100%" stop-color="#B45309" stop-opacity="0.28"/>
    </linearGradient>
    <linearGradient id="platinumCyanCheck" x1="0%" y1="100%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#0891B2"/>
      <stop offset="35%" stop-color="#06B6D4"/>
      <stop offset="75%" stop-color="#67E8F9"/>
      <stop offset="100%" stop-color="#ECFEFF"/>
    </linearGradient>
  </defs>

  <!-- 1. Deep Obsidian Carbon-Onyx Velvet Vault -->
  <rect width="1024" height="1024" rx="224" fill="url(#obsidianVelvetBg)"/>

  <!-- 2. Concentric Sovereign Horological Guilloche Medallion Halo -->
  <circle cx="512" cy="512" r="388" fill="none" stroke="url(#horologicalBezel)" stroke-width="3.5"/>
  <circle cx="512" cy="512" r="356" fill="none" stroke="url(#horologicalBezel)" stroke-width="1.8" stroke-dasharray="3 15.6"/>

  <!-- 3. Sovereign Synonym Monogram (Optical Safe Zone 49% = 502px, shifted +34px Y) -->
  <g transform="translate(267, 295)">
    <!-- A. Architectural G1-Continuous "Casa-Escudo D" in 24k Brushed Imperial Gold -->
    <path d="M 105.4 298.7 L 105.4 421.7 Q 105.4 456.8 140.6 456.8 L 246.0 456.8 A 175.7 175.7 0 0 0 370.2 156.9 L 278.6 65.3 Q 246.0 32.6 213.4 65.3 L 52.7 225.9"
          fill="none"
          stroke="url(#imperialGold24k)"
          stroke-width="65.3"
          stroke-linecap="round"
          stroke-linejoin="round"/>

    <!-- B. Sovereign Apex 4-Facet Diamond Keystone (Crowning Roof Peak at cx=246.0, cy=-47.2) -->
    <g>
      <polygon points="246.0,-47.2 201.8,-47.2 246.0,-91.4" fill="#FFFBEB"/>
      <polygon points="246.0,-47.2 246.0,-91.4 290.2,-47.2" fill="#FDE047"/>
      <polygon points="246.0,-47.2 246.0,-3.0 201.8,-47.2" fill="#FACC15"/>
      <polygon points="246.0,-47.2 290.2,-47.2 246.0,-3.0" fill="#D97706"/>
    </g>

    <!-- C. Luminous Platinum-Cyan Central Resolution & Custody Checkmark -->
    <path d="M 190.8 278.6 L 235.9 323.8 L 313.8 228.4"
          fill="none"
          stroke="url(#platinumCyanCheck)"
          stroke-width="61.2"
          stroke-linecap="round"
          stroke-linejoin="round"/>
  </g>
</svg>
"""
    svg_path.write_text(svg_content, encoding="utf-8")


def _apply_mask(im: Image.Image, mask_kind: str) -> Image.Image:
    w, h = im.size
    scale = 4
    mw, mh = w * scale, h * scale
    mask = Image.new("L", (mw, mh), 0)
    draw = ImageDraw.Draw(mask)
    if mask_kind == "circle":
        pad = int(mw * 0.02)
        draw.ellipse((pad, pad, mw - pad, mh - pad), fill=255)
    else:
        # Samsung One UI / iOS superellipse squircle approximation
        pad = int(mw * 0.02)
        r = int(mw * 0.24)
        draw.rounded_rectangle((pad, pad, mw - pad, mh - pad), radius=r, fill=255)
    mask = mask.resize((w, h), Image.Resampling.LANCZOS)
    out = im.copy().convert("RGBA")
    out.putalpha(mask)
    return out


def generate_showcase_board(
    ceo_1024: Image.Image,
    ceo_mono_432: Image.Image,
    ceo_mdpi_48: Image.Image,
    out_path: Path,
) -> None:
    """
    Renders an executive visual comparison board (`1800x1040`) contrasting
    Public `Desperrengue` vs. `Desperrengue CEO` across Squircle, Circle,
    Android 13-16 Monochrome Themed Icons, and 48dp home-screen size.
    """
    W, H = 1800, 1040
    board = Image.new("RGBA", (W, H), (11, 15, 23, 255))
    draw = ImageDraw.Draw(board)

    # Load public icons for side-by-side comparison
    pub_1024 = Image.open(PUBLIC_ICONS_DIR / "app_icon_padded.png").convert("RGBA")
    pub_mono = Image.open(MAIN_RES_DIR / "drawable-xxxhdpi" / "ic_launcher_monochrome.png").convert("RGBA")
    pub_mdpi = Image.open(MAIN_RES_DIR / "mipmap-mdpi" / "ic_launcher.png").convert("RGBA")

    # Subtle grid & header bar
    draw.rectangle((0, 0, W, 96), fill=(18, 24, 36, 255))
    draw.line((0, 96, W, 96), fill=(245, 158, 11, 110), width=2)

    try:
        font_title = ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf", 28)
        font_sub = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 18)
        font_card = ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf", 21)
        font_label = ImageFont.truetype("C:/Windows/Fonts/consolab.ttf", 16)
    except Exception:
        font_title = ImageFont.load_default()
        font_sub = ImageFont.load_default()
        font_card = ImageFont.load_default()
        font_label = ImageFont.load_default()

    draw.text(
        (48, 22),
        "DESPERRENGUE  vs.  DESPERRENGUE CEO  —  SOVEREIGN BRAND SEMIOTICS & LAUNCHER QA",
        fill=(253, 224, 71, 255),
        font=font_title,
    )
    draw.text(
        (48, 58),
        "100% G1-Continuous 'Casa-Escudo D' Genetic Synonym  |  < 50ms Chromatic & Silhouette Separation (Squircle, Circle, Monochrome & 48dp)",
        fill=(163, 174, 192, 255),
        font=font_sub,
    )

    # 3 Comparison Columns
    cols = [
        ("1. SAMSUNG ONE UI SQUIRCLE", 60, 560),
        ("2. PIXEL CIRCLE SAFE-ZONE", 640, 1140),
        ("3. ANDROID 13–16 MONOCHROME", 1220, 1720),
    ]

    for title, x0, x1 in cols:
        draw.rounded_rectangle((x0, 126, x1, 820), radius=24, fill=(18, 24, 34, 255), outline=(43, 54, 70, 255), width=2)
        draw.text((x0 + 28, 148), title, fill=(234, 239, 246, 255), font=font_card)
        draw.line((x0 + 24, 186, x1 - 24, 186), fill=(43, 54, 70, 255), width=1)

    icon_sz = 216

    # Column 1: Squircle Public (top) vs CEO (bottom)
    pub_sq = _apply_mask(pub_1024.resize((icon_sz, icon_sz), Image.Resampling.LANCZOS), "squircle")
    ceo_sq = _apply_mask(ceo_1024.resize((icon_sz, icon_sz), Image.Resampling.LANCZOS), "squircle")
    board.alpha_composite(pub_sq, (202, 214))
    draw.text((168, 444), "Desperrengue (Public #0F172A)", fill=(163, 174, 192, 255), font=font_label)

    board.alpha_composite(ceo_sq, (202, 504))
    draw.text((152, 736), "Desperrengue CEO (Obsidian + 24k)", fill=(253, 224, 71, 255), font=font_label)

    # Column 2: Circle Public (top) vs CEO (bottom)
    pub_ci = _apply_mask(pub_1024.resize((icon_sz, icon_sz), Image.Resampling.LANCZOS), "circle")
    ceo_ci = _apply_mask(ceo_1024.resize((icon_sz, icon_sz), Image.Resampling.LANCZOS), "circle")
    board.alpha_composite(pub_ci, (782, 214))
    draw.text((756, 444), "Public Circle Mask (108dp)", fill=(163, 174, 192, 255), font=font_label)

    board.alpha_composite(ceo_ci, (782, 504))
    draw.text((736, 736), "CEO Unclipped Guilloche Halo", fill=(103, 232, 249, 255), font=font_label)

    # Column 3: Android 13-16 Monochrome Themed Icon (tinted Material You pill)
    def build_themed_mono(mono_rgba: Image.Image, bg_color: tuple[int, int, int], fg_color: tuple[int, int, int]) -> Image.Image:
        tile = Image.new("RGBA", (icon_sz, icon_sz), (*bg_color, 255))
        # mono_rgba is 432x432 (108dp); crop central 72dp (288x288) like Android launcher does
        w_m = mono_rgba.width
        margin = int(w_m * (18.0 / 108.0))
        cropped = mono_rgba.crop((margin, margin, w_m - margin, w_m - margin)).resize((icon_sz, icon_sz), Image.Resampling.LANCZOS)
        arr = np.array(cropped, dtype=np.float32)
        alpha = arr[..., 3:4] / 255.0
        base = np.array(tile, dtype=np.float32)
        tint = np.array(fg_color, dtype=np.float32)[None, None, :]
        base[..., :3] = base[..., :3] * (1.0 - alpha) + tint * alpha
        return _apply_mask(Image.fromarray(np.round(base).astype(np.uint8), mode="RGBA"), "circle")

    pub_mono_tile = build_themed_mono(pub_mono, (28, 36, 48), (210, 228, 255))
    ceo_mono_tile = build_themed_mono(ceo_mono_432, (28, 36, 48), (254, 240, 138))
    board.alpha_composite(pub_mono_tile, (1362, 214))
    draw.text((1324, 444), "Public Monochrome Silhouette", fill=(163, 174, 192, 255), font=font_label)

    board.alpha_composite(ceo_mono_tile, (1362, 504))
    draw.text((1308, 736), "CEO Crown Keystone Silhouette!", fill=(253, 224, 71, 255), font=font_label)

    # Bottom Bar: Real 48dp (mdpi) & 72dp (hdpi) Home-Screen Dock Legibility Strip
    draw.rounded_rectangle((60, 848, 1720, 1004), radius=20, fill=(18, 24, 34, 255), outline=(43, 54, 70, 255), width=2)
    draw.text(
        (92, 888),
        "48dp (mdpi) & 72dp (hdpi) REAL HOME-SCREEN DOCK LEGIBILITY:",
        fill=(234, 239, 246, 255),
        font=font_card,
    )
    draw.text(
        (92, 926),
        "Side-by-side at physical pixel sizes — 100% instant visual distinction at a glance.",
        fill=(163, 174, 192, 255),
        font=font_sub,
    )

    pub_48_sq = _apply_mask(pub_mdpi, "squircle")
    ceo_48_sq = _apply_mask(ceo_mdpi_48, "squircle")
    board.alpha_composite(pub_48_sq, (1080, 892))
    board.alpha_composite(ceo_48_sq, (1152, 892))
    draw.text((1076, 952), "48px Pair", fill=(163, 174, 192, 255), font=font_label)

    pub_72_sq = _apply_mask(pub_1024.resize((72, 72), Image.Resampling.LANCZOS), "squircle")
    ceo_72_sq = _apply_mask(ceo_1024.resize((72, 72), Image.Resampling.LANCZOS), "squircle")
    board.alpha_composite(pub_72_sq, (1320, 876))
    board.alpha_composite(ceo_72_sq, (1416, 876))
    draw.text((1345, 958), "72px Dock Pair", fill=(253, 224, 71, 255), font=font_label)

    board.convert("RGB").save(out_path, optimize=True)


def main() -> None:
    BRAND_DOCS_DIR.mkdir(parents=True, exist_ok=True)
    FOUNDER_RES_DIR.mkdir(parents=True, exist_ok=True)

    # 1. Write canonical mathematical SVG
    svg_path = BRAND_DOCS_DIR / "desperrengue_ceo_logo.svg"
    write_svg_logo(svg_path)
    print(f"Generated {svg_path.relative_to(ROOT_DIR)}")

    # 2. Render 2048x2048 supersampled master canvases
    print("Rendering 2048x2048 supersampled SDF master layers...")
    # A) Full-bleed / Padded composite master (for 1024px brand icon & mipmap-*/ic_launcher.png)
    bg_padded_2048 = render_background_layer(2048, halo_radius_frac=0.380)
    fg_padded_2048 = render_foreground_layer(
        2048, safe_zone_scale=0.490, y_optical_shift=0.068, monochrome=False, with_drop_shadow=True
    )
    comp_padded_2048 = composite_layers(bg_padded_2048, fg_padded_2048)
    ceo_1024 = to_pil(comp_padded_2048, 1024)
    ceo_1024_path = BRAND_DOCS_DIR / "desperrengue_ceo_icon_1024.png"
    ceo_1024.save(ceo_1024_path, optimize=True)
    print(f"Generated {ceo_1024_path.relative_to(ROOT_DIR)}")

    # B) Adaptive Icon 108dp master layers (1728x1728 = 4x 432px xxxhdpi)
    # Halo strictly inside r <= 0.298 of 108dp canvas so NO mask ever clips it!
    bg_adaptive_1728 = render_background_layer(1728, halo_radius_frac=0.298)
    fg_adaptive_1728 = render_foreground_layer(
        1728, safe_zone_scale=0.425, y_optical_shift=0.068, monochrome=False, with_drop_shadow=True
    )
    mono_adaptive_1728 = render_foreground_layer(
        1728, safe_zone_scale=0.425, y_optical_shift=0.068, monochrome=True, with_drop_shadow=False
    )

    bg_adaptive_master = to_pil(bg_adaptive_1728)
    fg_adaptive_master = to_pil(fg_adaptive_1728)
    mono_adaptive_master = to_pil(mono_adaptive_1728)

    # C) Splash / Android 12 Splash master (2048x2048 -> 1024..256 transparent foreground)
    fg_splash_master = to_pil(fg_padded_2048)

    # 3. Export 1x1 background.png for drawable/ and drawable-v21/ (#07090D)
    for d_name in ("drawable", "drawable-v21"):
        d_dir = FOUNDER_RES_DIR / d_name
        d_dir.mkdir(parents=True, exist_ok=True)
        bg_1x1 = Image.new("RGB", (1, 1), (7, 9, 13))
        bg_1x1.save(d_dir / "background.png", optimize=True)

    # 4. Export mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png
    mipmap_sizes = {
        "mdpi": 48,
        "hdpi": 72,
        "xhdpi": 96,
        "xxhdpi": 144,
        "xxxhdpi": 192,
    }
    ceo_mdpi_48 = None
    for density, px in mipmap_sizes.items():
        m_dir = FOUNDER_RES_DIR / f"mipmap-{density}"
        m_dir.mkdir(parents=True, exist_ok=True)
        im_m = ceo_1024.resize((px, px), Image.Resampling.LANCZOS)
        im_m.save(m_dir / "ic_launcher.png", optimize=True)
        if density == "mdpi":
            ceo_mdpi_48 = im_m

    # 5. Export drawable-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi} adaptive & splash PNGs
    adaptive_sizes = {
        "mdpi": 108,
        "hdpi": 162,
        "xhdpi": 216,
        "xxhdpi": 324,
        "xxxhdpi": 432,
    }
    splash_sizes = {
        "mdpi": 256,
        "hdpi": 384,
        "xhdpi": 512,
        "xxhdpi": 768,
        "xxxhdpi": 1024,
    }

    ceo_mono_432 = None
    for density, a_px in adaptive_sizes.items():
        d_dir = FOUNDER_RES_DIR / f"drawable-{density}"
        d_dir.mkdir(parents=True, exist_ok=True)

        bg_im = bg_adaptive_master.resize((a_px, a_px), Image.Resampling.LANCZOS)
        fg_im = fg_adaptive_master.resize((a_px, a_px), Image.Resampling.LANCZOS)
        mono_im = mono_adaptive_master.resize((a_px, a_px), Image.Resampling.LANCZOS)

        bg_im.save(d_dir / "ic_launcher_background.png", optimize=True)
        fg_im.save(d_dir / "ic_launcher_foreground.png", optimize=True)
        mono_im.save(d_dir / "ic_launcher_monochrome.png", optimize=True)
        if density == "xxxhdpi":
            ceo_mono_432 = mono_im

        s_px = splash_sizes[density]
        sp_im = fg_splash_master.resize((s_px, s_px), Image.Resampling.LANCZOS)
        sp_im.save(d_dir / "splash.png", optimize=True)
        sp_im.save(d_dir / "android12splash.png", optimize=True)

        dn_dir = FOUNDER_RES_DIR / f"drawable-night-{density}"
        dn_dir.mkdir(parents=True, exist_ok=True)
        sp_im.save(dn_dir / "android12splash.png", optimize=True)

    # 6. Generate side-by-side Executive Showcase Board
    showcase_path = BRAND_DOCS_DIR / "desperrengue_public_vs_ceo_showcase.png"
    assert ceo_mono_432 is not None and ceo_mdpi_48 is not None
    generate_showcase_board(ceo_1024, ceo_mono_432, ceo_mdpi_48, showcase_path)
    print(f"Generated {showcase_path.relative_to(ROOT_DIR)}")
    print("All Desperrengue CEO launcher, adaptive, monochrome & splash resources generated successfully.")


if __name__ == "__main__":
    main()

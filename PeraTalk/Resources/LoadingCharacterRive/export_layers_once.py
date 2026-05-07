#!/usr/bin/env python3
"""Split loading character into Rive-oriented PNG layers (1024²).

Blush: vertical gap → two largest blobs per cheek (no center-face assignment).
Mouth: darkest low-chroma band in central ROI under centroid.
Glow: straight alpha; peach from body mean.
"""
from __future__ import annotations

import cv2
import numpy as np
from pathlib import Path


def largest_component_mask(binary_u8: np.ndarray) -> np.ndarray:
    m = (binary_u8 > 127).astype(np.uint8) * 255
    if cv2.countNonZero(m) == 0:
        return m
    n, labels, stats, _ = cv2.connectedComponentsWithStats(m)
    if n <= 1:
        return m
    areas = stats[1:, cv2.CC_STAT_AREA]
    idx = 1 + int(np.argmax(areas))
    return (labels == idx).astype(np.uint8) * 255


def blush_split_two_components(
    blush_binary: np.ndarray,
    cx: int,
    h: int,
    w: int,
) -> tuple[np.ndarray, np.ndarray]:
    """Vertical gap splits bridged mask → two cheek blobs (no Voronoi skin fill)."""
    blush_binary = (blush_binary > 127).astype(np.uint8) * 255
    bw = int(np.clip(0.051 * w, 42.0, 68.0))
    broken = blush_binary.copy()
    broken[:, max(0, cx - bw) : min(w, cx + bw)] = 0
    broken = cv2.morphologyEx(broken, cv2.MORPH_OPEN, np.ones((5, 5), np.uint8))

    n, labels, stats, centroids = cv2.connectedComponentsWithStats(broken)
    empty = np.zeros((h, w), dtype=np.uint8)
    if n < 3:
        return empty, empty

    parts = [
        (i, int(stats[i, cv2.CC_STAT_AREA]), float(centroids[i][0]))
        for i in range(1, n)
    ]
    parts.sort(key=lambda x: -x[1])
    if len(parts) < 2:
        return empty, empty

    lid, rid = parts[0][0], parts[1][0]
    if centroids[lid][0] > centroids[rid][0]:
        lid, rid = rid, lid

    mask_L = (labels == lid).astype(np.uint8) * 255
    mask_R = (labels == rid).astype(np.uint8) * 255

    mask_L = cv2.morphologyEx(mask_L, cv2.MORPH_CLOSE, np.ones((19, 19), np.uint8))
    mask_R = cv2.morphologyEx(mask_R, cv2.MORPH_CLOSE, np.ones((19, 19), np.uint8))
    mask_L = cv2.GaussianBlur(mask_L, (0, 0), sigmaX=4.0)
    mask_R = cv2.GaussianBlur(mask_R, (0, 0), sigmaX=4.0)
    return mask_L, mask_R


def main() -> None:
    src = Path(
        "/Users/gobou/.cursor/projects/Users-gobou-develop-PeraTalk/assets/"
        "image-88c6ce4b-3681-4fc6-a138-18c0c66e9aa7.png"
    )
    out_dir = Path(__file__).resolve().parent
    out_dir.mkdir(parents=True, exist_ok=True)

    bgr = cv2.imread(str(src), cv2.IMREAD_COLOR)
    if bgr is None:
        raise SystemExit(f"failed to read {src}")
    rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
    h, w = rgb.shape[:2]

    corners = np.concatenate(
        [
            rgb[:45, :45].reshape(-1, 3),
            rgb[:45, -45:].reshape(-1, 3),
            rgb[-45:, :45].reshape(-1, 3),
            rgb[-45:, -45:].reshape(-1, 3),
        ]
    )
    bg_color = np.median(corners, axis=0).astype(np.float32)
    diff = np.linalg.norm(rgb.astype(np.float32) - bg_color, axis=2)
    inside = diff >= 30

    char_mask = inside.astype(np.uint8) * 255
    char_mask = cv2.morphologyEx(char_mask, cv2.MORPH_CLOSE, np.ones((9, 9), np.uint8))
    char_mask = cv2.GaussianBlur(char_mask, (0, 0), sigmaX=2.5)
    inside_soft = char_mask > 12

    ys, xs = np.where(inside_soft)
    cx = int(np.mean(xs))
    cy = int(np.mean(ys))

    lab = cv2.cvtColor(bgr, cv2.COLOR_BGR2LAB)
    L = lab[:, :, 0].astype(np.float32)
    la = lab[:, :, 1].astype(np.float32) - 128.0
    lb = lab[:, :, 2].astype(np.float32) - 128.0
    hsv = cv2.cvtColor(bgr, cv2.COLOR_BGR2HSV)
    S = hsv[:, :, 1].astype(np.float32)

    R = rgb[:, :, 0].astype(np.float32)
    G = rgb[:, :, 1].astype(np.float32)
    B = rgb[:, :, 2].astype(np.float32)
    mx = np.maximum(np.maximum(R, G), B)
    mn = np.minimum(np.minimum(R, G), B)
    chroma = mx - mn

    yy = np.arange(h)[:, None]
    xx = np.arange(w)[None, :]

    mouth_strip = (
        inside_soft
        & (np.abs(xx.astype(np.float32) - cx) < 142)
        & (yy > cy - 28)
        & (yy < cy + 72)
    )

    cand_mouth = mouth_strip & (chroma < 46) & (S < 84)
    roi_ls = L[cand_mouth]
    if roi_ls.size < 120:
        mouth_seed = np.zeros((h, w), dtype=bool)
    else:
        thr_dark = float(np.percentile(roi_ls, 8))
        thr_dark = min(thr_dark, 138)
        mouth_seed = cand_mouth & (L <= thr_dark + 16) & (L < 148)

    mouth_mask = mouth_seed.astype(np.uint8) * 255
    mouth_mask = cv2.morphologyEx(
        mouth_mask,
        cv2.MORPH_CLOSE,
        cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9)),
    )
    mouth_mask = cv2.dilate(
        mouth_mask,
        cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (6, 6)),
        iterations=2,
    )
    mouth_mask = largest_component_mask(mouth_mask)

    blush_core = (
        inside_soft
        & (la > 5)
        & (lb > -10)
        & (S > 20)
        & (L > 136)
        & (R > G + 5)
        & (R > B + 3)
        & (yy > cy - 150)
    )
    blush_bin = blush_core.astype(np.uint8) * 255
    blush_bin = cv2.morphologyEx(blush_bin, cv2.MORPH_CLOSE, np.ones((9, 9), np.uint8))
    blush_bin = cv2.morphologyEx(blush_bin, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))

    blush_L_u8, blush_R_u8 = blush_split_two_components(blush_bin, cx, h, w)

    mouth_kill = cv2.dilate(
        mouth_mask,
        cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (34, 28)),
        iterations=1,
    )
    y_top = max(0, cy - 44)
    y_bot = min(h, cy + 63)
    mouth_kill[:y_top, :] = 0
    mouth_kill[y_bot:, :] = 0

    blush_L_u8 = cv2.bitwise_and(blush_L_u8, cv2.bitwise_not(mouth_kill))
    blush_R_u8 = cv2.bitwise_and(blush_R_u8, cv2.bitwise_not(mouth_kill))
    blush_L_u8 = cv2.GaussianBlur(blush_L_u8, (0, 0), sigmaX=3.5)
    blush_R_u8 = cv2.GaussianBlur(blush_R_u8, (0, 0), sigmaX=3.5)

    inpaint_mask = np.clip(
        mouth_mask.astype(np.int32)
        + blush_L_u8.astype(np.int32)
        + blush_R_u8.astype(np.int32),
        0,
        255,
    ).astype(np.uint8)
    inpaint_mask = cv2.dilate(
        inpaint_mask,
        cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (11, 11)),
        iterations=1,
    )

    body_bgr = cv2.inpaint(bgr, inpaint_mask, inpaintRadius=12, flags=cv2.INPAINT_NS)

    body_rgba = cv2.cvtColor(body_bgr, cv2.COLOR_BGR2RGBA)
    body_rgba[:, :, 3] = char_mask

    mouth_rgba = np.zeros((h, w, 4), dtype=np.uint8)
    mouth_rgba[:, :, :3] = np.where(mouth_mask[..., None] > 0, rgb, 0).astype(np.uint8)
    mouth_rgba[:, :, 3] = mouth_mask

    def blush_layer(mask_u8: np.ndarray) -> np.ndarray:
        out = np.zeros((h, w, 4), dtype=np.uint8)
        out[:, :, :3] = np.where(mask_u8[..., None] > 0, rgb, 0).astype(np.uint8)
        out[:, :, 3] = mask_u8
        return out

    blush_L_rgba = blush_layer(blush_L_u8)
    blush_R_rgba = blush_layer(blush_R_u8)

    sil = cv2.GaussianBlur(char_mask, (0, 0), sigmaX=5)
    sil_f = sil.astype(np.float32) / 255.0

    cm = (char_mask > 40).astype(np.uint8)
    peach_bgr = cv2.mean(bgr, mask=cm)
    peach = np.array([peach_bgr[2], peach_bgr[1], peach_bgr[0]], dtype=np.float32) / 255.0
    peach = np.clip(peach * 1.12 + np.array([0.045, 0.035, 0.03]), 0, 1)

    pad = int(max(h, w) * 0.14)
    big_h, big_w = h + 2 * pad, w + 2 * pad
    sil_big = np.zeros((big_h, big_w), dtype=np.float32)
    sil_big[pad : pad + h, pad : pad + w] = sil_f

    center = (big_w / 2, big_h / 2)
    M = cv2.getRotationMatrix2D(center, 0, 1.075)
    sil_scaled = cv2.warpAffine(sil_big, M, (big_w, big_h), flags=cv2.INTER_LINEAR)

    blur = cv2.GaussianBlur(sil_scaled, (0, 0), sigmaX=38)
    blur_crop = blur[pad : pad + h, pad : pad + w]

    opacity = 0.28
    glow_a = np.clip(blur_crop * opacity, 0, 1)

    pr = int(np.clip(peach[0] * 255.0, 0, 255))
    pg = int(np.clip(peach[1] * 255.0, 0, 255))
    pb = int(np.clip(peach[2] * 255.0, 0, 255))
    glow_rgba = np.zeros((h, w, 4), dtype=np.uint8)
    glow_rgba[:, :, 0] = pr
    glow_rgba[:, :, 1] = pg
    glow_rgba[:, :, 2] = pb
    glow_rgba[:, :, 3] = (glow_a * 255.0).astype(np.uint8)

    cv2.imwrite(str(out_dir / "Body.png"), cv2.cvtColor(body_rgba, cv2.COLOR_RGBA2BGRA))
    cv2.imwrite(str(out_dir / "Mouth.png"), cv2.cvtColor(mouth_rgba, cv2.COLOR_RGBA2BGRA))
    cv2.imwrite(str(out_dir / "Blush_L.png"), cv2.cvtColor(blush_L_rgba, cv2.COLOR_RGBA2BGRA))
    cv2.imwrite(str(out_dir / "Blush_R.png"), cv2.cvtColor(blush_R_rgba, cv2.COLOR_RGBA2BGRA))
    cv2.imwrite(str(out_dir / "Glow.png"), cv2.cvtColor(glow_rgba, cv2.COLOR_RGBA2BGRA))

    print(
        "stats mouth",
        int(cv2.countNonZero(mouth_mask)),
        "blush_L",
        int(cv2.countNonZero((blush_L_u8 > 12).astype(np.uint8))),
        "blush_R",
        int(cv2.countNonZero((blush_R_u8 > 12).astype(np.uint8))),
    )
    print("wrote", out_dir)


if __name__ == "__main__":
    main()

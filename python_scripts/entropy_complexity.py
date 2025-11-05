# -*- coding: utf-8 -*-
"""
Complexity–Entropy (Permutation-based, per paper)
-------------------------------------------------
- ไม่ใช้โมเดล/ไม่ใช้จำนวนสี/ไม่ใช้ K-Means
- ทำตามกระดาษ: นับ ordinal patterns จากหน้าต่างย่อย d_x x d_y บนภาพ grayscale
- รองรับ template mask และโหมดเลือกหน้าต่างแบบ all-4-inside (ค่าเริ่มต้น)
"""

import os, math, argparse
from pathlib import Path
import numpy as np
import pandas as pd
import cv2
import itertools
from matplotlib import pyplot as plt
# -------------------- Utils: mask --------------------
def build_mask_with_template(bgr, tmpl_keep, mode="stencil"):
    """
    - stencil: ใช้ template mask ตรง ๆ (ขาว=พื้นที่นับ, ดำ=ไม่นับ)
    - lines  : not-lines จาก Canny (ตัดเส้นออก เหลือพื้นที่ระบาย)
    - hybrid : stencil - lines (กันเส้นดำออก เหลือพื้นที่ระบาย)
    """
    if tmpl_keep is None:
        tmpl_keep = np.ones(bgr.shape[:2], np.uint8) * 255
    elif tmpl_keep.ndim == 3:
        tmpl_keep = cv2.cvtColor(tmpl_keep, cv2.COLOR_BGR2GRAY)

    gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)

    if mode == "stencil":
        mask = tmpl_keep.copy()
    elif mode == "lines":
        edges = cv2.Canny(gray, 100, 200)
        edges = cv2.dilate(edges, None, iterations=1)
        mask = cv2.bitwise_and(cv2.bitwise_not(edges), tmpl_keep)
    elif mode == "hybrid":
        blur  = cv2.GaussianBlur(gray, (3,3), 0)
        edges = cv2.Canny(blur, 80, 160)
        line_mask = cv2.dilate(edges, None, iterations=1)
        mask = cv2.bitwise_and(tmpl_keep, cv2.bitwise_not(line_mask))
    else:
        raise ValueError(f"Unknown mask mode: {mode}")

    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN,  np.ones((3,3), np.uint8))
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, np.ones((3,3), np.uint8))
    return mask

def load_template_mask(tmpldir, name):
    """พยายามโหลดไฟล์เทมเพลตชื่อ name.[png/jpg/jpeg] ถ้าไม่มีคืน None"""
    if tmpldir is None: return None
    for ext in (".png",".jpg",".jpeg"):
        p = os.path.join(tmpldir, name + ext)
        if os.path.isfile(p):
            m = cv2.imread(p, cv2.IMREAD_GRAYSCALE)
            return m
    return None

# -------------------- Core: permutation machinery --------------------
def grayscale_simple(bgr):
    rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB).astype(np.float32)
    return (rgb[:,:,0] + rgb[:,:,1] + rgb[:,:,2]) / 3.0  # simple average per paper


def all_permutations_indices(m):
    """คืนรายการ permutation ของ indices 0..m-1 ในลำดับคงที่"""
    return list(itertools.permutations(range(m)))

def window_perm_ordinal(flat_vals):
    """
    รับ array ยาว m -> คืน permutation indices ตามลำดับจากน้อยไปมาก
    ใช้ argsort(kind='stable') เพื่อ tie-breaking ตามตำแหน่งเดิม (สไตล์ Bandt & Pompe)
    """
    idx = np.argsort(flat_vals, kind='stable')
    return tuple(idx.tolist())

def count_permutation_distribution(gray, mask, dx=2, dy=2, include_rule="all4"):
    """
    เดินสไลด์หน้าต่าง dy x dx บนภาพ grayscale ภายใต้ mask
    include_rule:
      - "all4" (default): นับเฉพาะหน้าต่างที่ทุกพิกเซลอยู่ใน mask (>0)
      - "center": ใช้จุดกึ่งกลางหน้าต่างเป็นตัวตัดสิน
    คืนค่า: counts (ยาว n=(dx*dy)!), total_windows_used
    """
    H, W = gray.shape
    m = dx*dy
    perms = all_permutations_indices(m)
    n_perm = math.factorial(m)
    perm_to_idx = {p:i for i,p in enumerate(perms)}
    counts = np.zeros(n_perm, dtype=np.int64)

    total = 0
    for y in range(H - dy + 1):
        for x in range(W - dx + 1):
            block = gray[y:y+dy, x:x+dx]
            mblock = mask[y:y+dy, x:x+dx]
            if include_rule == "all4":
                if not np.all(mblock > 0):  # ต้อง 4 จุดอยู่ใน mask
                    continue
            elif include_rule == "center":
                cy, cx = y + dy//2, x + dx//2
                if mask[cy, cx] == 0:
                    continue
            else:
                raise ValueError("include_rule should be 'all4' or 'center'")

            flat = block.flatten()
            perm = window_perm_ordinal(flat)
            counts[perm_to_idx[perm]] += 1
            total += 1
    return counts, total

# -------------------- H, C per paper --------------------
def shannon_entropy(p):
    # S(P) = sum p_i ln(1/p_i), 0*ln(1/0) -> 0
    s = 0.0
    for pi in p:
        if pi > 0:
            s += pi * math.log(1.0/pi)
    return s

def entropy_normalized(p):
    n = len(p)
    if n <= 1: return 0.0
    return shannon_entropy(p) / math.log(n)

def js_divergence_to_uniform(p):
    n = len(p)
    u = np.full(n, 1.0/n, dtype=np.float64)
    m = 0.5*(p + u)
    S = shannon_entropy
    return S(m) - 0.5*S(p) - 0.5*S(u)

def D_star(n):
    # ค่าคงที่ตามกระดาษ (delta vs uniform)
    return -0.5 * ( ((n+1)/n)*math.log(n+1) + math.log(n) - 2*math.log(2*n) )

def complexity_statistical(p):
    n = len(p)
    Hn = entropy_normalized(p)
    D  = js_divergence_to_uniform(p)
    Ds = D_star(n)
    return (D*Hn/Ds if Ds > 0 else 0.0), Hn, D, Ds

# -------------------- Runner --------------------
def process_one(img_path, tmpldir=None, tmpl_name=None, maskmode="stencil",
                dx=2, dy=2, include_rule="all4"):
    bgr  = cv2.imread(img_path, cv2.IMREAD_COLOR)
    print(bgr.shape)
    
    if bgr is None:
        raise FileNotFoundError(img_path)
    
    # โชว์ภาพ R G B
    #blue  = np.zeros_like(bgr);  blue[:,:,0]  = bgr[:,:,0]    # เก็บเฉพาะ B
    #green = np.zeros_like(bgr);  green[:,:,1] = bgr[:,:,1]    # เก็บเฉพาะ G
    #red   = np.zeros_like(bgr);  red[:,:,2]   = bgr[:,:,2]    # เก็บเฉพาะ R
    #plt.figure(figsize=(12,4))
    #plt.subplot(1,3,1); plt.imshow(cv2.cvtColor(blue,  cv2.COLOR_BGR2RGB));  plt.title("Blue only")
    #plt.subplot(1,3,2); plt.imshow(cv2.cvtColor(green, cv2.COLOR_BGR2RGB));  plt.title("Green only")
    #plt.subplot(1,3,3); plt.imshow(cv2.cvtColor(red,   cv2.COLOR_BGR2RGB));  plt.title("Red only")
    #plt.show()
    
    gray = grayscale_simple(bgr)

    # แสดงภาพ grayscale ที่ได้จาก (R+G+B)/3
    #plt.figure(figsize=(5,5))
    #plt.imshow(gray, cmap="gray")
    #plt.title("Grayscale (R+G+B)/3")
    #plt.axis("off")
    #plt.show()
    
    tmpl = None
    if tmpldir and tmpl_name:
        tmpl = load_template_mask(tmpldir, tmpl_name)
    mask = build_mask_with_template(bgr, tmpl, mode=maskmode)

    counts, total = count_permutation_distribution(gray, mask, dx=dx, dy=dy, include_rule=include_rule)
    n = math.factorial(dx*dy)
    if total == 0:
        p = np.zeros(n, dtype=np.float64)
    else:
        p = counts / counts.sum()

    C, Hn, D, Ds = complexity_statistical(p)

    nonzero = int((p > 0).sum())
    return {
        "file": img_path,
        "tmpl": tmpl_name,
        "maskmode": maskmode,
        "dx": dx, "dy": dy,
        "n_perm": n,
        "windows_used": int(total),
        "bins_nonzero": nonzero,
        "H": float(Hn),
        "C": float(C),
    }

def main():
    ap = argparse.ArgumentParser("Permutation Entropy & Complexity (paper-correct)")
    ap.add_argument("--path", required=True, help="ไฟล์ภาพหรือโฟลเดอร์")
    ap.add_argument("--tmpldir", help="โฟลเดอร์ template (มี *_template.png)")
    ap.add_argument("--tmplname", help="ชื่อ template (ไม่ต้องใส่ .png)")
    ap.add_argument("--maskmode", choices=["stencil","lines","hybrid"], default="stencil")
    ap.add_argument("--dx", type=int, default=2)
    ap.add_argument("--dy", type=int, default=2)
    ap.add_argument("--include", choices=["all4","center"], default="all4",
                    help="เกณฑ์นับหน้าต่าง: all4=พิกเซลทั้งบล็อกต้องอยู่ใน mask, center=ใช้จุดกึ่งกลาง")
    ap.add_argument("--save_csv", help="บันทึกผล CSV (utf-8-sig)")
    args = ap.parse_args()

    # สร้างรายชื่อไฟล์
    if os.path.isfile(args.path):
        files = [args.path]
    else:
        files = []
        for root, _, names in os.walk(args.path):
            for n in names:
                if n.lower().endswith((".png",".jpg",".jpeg",".bmp")):
                    files.append(os.path.join(root, n))
        files.sort()

    out = []
    for f in files:
        try:
            res = process_one(
                f,
                tmpldir=args.tmpldir,
                tmpl_name=args.tmplname,
                maskmode=args.maskmode,
                dx=args.dx, dy=args.dy,
                include_rule=args.include
            )
            out.append(res)
            print(f"{Path(f).name:30s} "
                  f"[dx×dy={res['dx']}×{res['dy']} | n={res['n_perm']:>5d} | win={res['windows_used']:>7d} | nz={res['bins_nonzero']:>2d}] "
                  f"H={res['H']:.4f} | C={res['C']:.4f} | mode={res['maskmode']}")
        except Exception as e:
            out.append({"file": f, "error": str(e)})
            print(f"[ERR] {Path(f).name}: {e}")

    if args.save_csv:
        pd.DataFrame(out).to_csv(args.save_csv, index=False, encoding="utf-8-sig")
        print("saved →", args.save_csv)
        
if __name__ == "__main__":
    main()

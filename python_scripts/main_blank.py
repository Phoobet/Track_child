# main_blank_coverage.py
# วัด 'สัดส่วนพื้นที่ที่ถูกระบาย' (Coverage) เฉพาะด้านในรูป (ไม่นับเส้นดำ)
# - Coverage ∈ [0,1] : 0 = ยังไม่ระบาย, 1 = ระบายเต็ม

import cv2
import numpy as np
from tkinter import filedialog, Tk
import math

# ===== ปรับได้ตามชุดภาพจริง =====
LINE_THR = 80              # เทาเข้มกว่านี้ถือเป็นเส้นดำ
LINE_DILATE_ITER = 1       # ขยายมาสก์เส้น
L_MARGIN = 10              # เผื่อกระดาษไม่ขาวสนิท
C_SIGMA = 3.5              # ควบคุมการตรวจจับว่าสีใกล้กระดาษ
EARLY_EXIT_TOL = 0.002     # ถ้าความต่างน้อยกว่า 0.2% → ถือว่ายังว่าง

Tk().withdraw()

# ---------- functions ----------
def build_inside_and_background_masks(template_bgr):
    h, w = template_bgr.shape[:2]
    gray = cv2.cvtColor(template_bgr, cv2.COLOR_BGR2GRAY)
    white = cv2.threshold(gray, 245, 255, cv2.THRESH_BINARY)[1]
    ff_img = white.copy()
    ff_buf = np.zeros((h + 2, w + 2), np.uint8)
    cv2.floodFill(ff_img, ff_buf, (0, 0), 128)  # พื้นหลังติดขอบ → 128
    background = (ff_img == 128).astype(np.uint8) * 255
    inside = cv2.bitwise_not(background)         # พื้นที่ด้านใน (รวมเส้น)
    inside = cv2.morphologyEx(inside, cv2.MORPH_CLOSE, np.ones((5,5), np.uint8), iterations=2)
    return inside, background

def build_line_mask_from_template(template_bgr, thr=LINE_THR, dilate_iter=LINE_DILATE_ITER):
    gray = cv2.cvtColor(template_bgr, cv2.COLOR_BGR2GRAY)
    line = (gray < thr).astype(np.uint8) * 255
    if dilate_iter > 0:
        line = cv2.dilate(line, np.ones((3,3), np.uint8), iterations=dilate_iter)
    return line

def keep_inside(img_bgr, inside_mask):
    out = img_bgr.copy()
    out[inside_mask == 0] = (255, 255, 255)
    return out

def remove_lines(img_bgr):
    gray = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY)
    _, line_mask = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
    if LINE_DILATE_ITER > 0:
        line_mask = cv2.dilate(line_mask, np.ones((3,3), np.uint8), iterations=LINE_DILATE_ITER)
    out = img_bgr.copy()
    out[line_mask > 0] = (255, 255, 255)
    return out

# ---------- เลือกไฟล์ ----------
print("📁 เลือก Template Image")
tmpl_path = filedialog.askopenfilename(title="Template", filetypes=[("Image files","*.png;*.jpg;*.jpeg")])
print("🖌️ เลือก Coloring Image")
clr_path  = filedialog.askopenfilename(title="Coloring", filetypes=[("Image files","*.png;*.jpg;*.jpeg")])

# ---------- โหลด ----------
tmpl = cv2.imread(tmpl_path, cv2.IMREAD_COLOR)
clr  = cv2.imread(clr_path,  cv2.IMREAD_COLOR)
if tmpl is None or clr is None:
    raise SystemExit("❌ โหลดภาพไม่สำเร็จ")
clr = cv2.resize(clr, (tmpl.shape[1], tmpl.shape[0]))

# ---------- พื้นที่ที่ควรถูกระบาย ----------
inside_mask, background_mask = build_inside_and_background_masks(tmpl)
line_mask = build_line_mask_from_template(tmpl)
paint_area = cv2.bitwise_and(inside_mask, cv2.bitwise_not(line_mask))

tmpl_in = keep_inside(tmpl, inside_mask)
clr_in  = keep_inside(clr,  inside_mask)

# ---------- EARLY EXIT ----------
tmpl_noline = remove_lines(tmpl_in)
clr_noline  = remove_lines(clr_in)
diff = cv2.absdiff(cv2.cvtColor(tmpl_noline, cv2.COLOR_BGR2GRAY),
                   cv2.cvtColor(clr_noline,  cv2.COLOR_BGR2GRAY))
diff_bin = (diff > 8).astype(np.uint8)
paint_sel = (paint_area > 0)
diff_ratio = diff_bin[paint_sel].mean() if paint_sel.sum() else 0.0
if diff_ratio <= EARLY_EXIT_TOL:
    coverage = 0.0
else:
    # ---------- ตรวจจับ blank ด้วย Lab ----------
    lab = cv2.cvtColor(clr_in, cv2.COLOR_BGR2LAB)
    L, A, B = cv2.split(lab)

    bg_sel = (background_mask > 0)
    L_bg = L[bg_sel]; A_bg = A[bg_sel]; B_bg = B[bg_sel]
    L_thresh = float(np.mean(L_bg) - L_MARGIN)
    a_mu, b_mu = float(np.mean(A_bg)), float(np.mean(B_bg))
    a_sd, b_sd = float(np.std(A_bg)), float(np.std(B_bg))
    C_thresh = C_SIGMA * math.sqrt(a_sd*a_sd + b_sd*b_sd + 1e-6)

    da = (A.astype(np.float32) - a_mu)
    db = (B.astype(np.float32) - b_mu)
    Cdist = np.sqrt(da*da + db*db)
    blank_mask = ((L >= L_thresh) & (Cdist <= C_thresh)).astype(np.uint8) * 255

    blank_mask = cv2.morphologyEx(blank_mask, cv2.MORPH_OPEN, np.ones((3,3), np.uint8), iterations=1)

    unexpected_blank = cv2.bitwise_and(blank_mask, paint_area)

    area = int(paint_sel.sum())
    miss = int((unexpected_blank > 0).sum())

    # ✅ Coverage = สัดส่วนพื้นที่ที่ถูกระบาย
    coverage = (area - miss) / area if area > 0 else 0.0

print(f"\n🎨 Coverage: {coverage:.4f}")

# ---------- Debug ----------
cv2.imwrite("dbg_inside_mask.png", inside_mask)
cv2.imwrite("dbg_line_mask.png", line_mask)
cv2.imwrite("dbg_paint_area.png", paint_area)
cv2.imwrite("dbg_tmpl_noline.png", tmpl_noline)
cv2.imwrite("dbg_clr_noline.png", clr_noline)
cv2.imwrite("dbg_diff_bin.png", (diff_bin*255))
try:
    cv2.imwrite("dbg_blank_mask.png", blank_mask)
    cv2.imwrite("dbg_unexpected_blank.png", unexpected_blank)
except NameError:
    pass
print("📂 Debug saved")

# main_cotl_band.py  — COTL = coverage ของการระบาย "นอกเส้น" (แถบ 3 ซม. รอบรูป)
import cv2
import numpy as np
from tkinter import filedialog, Tk

DPI = 300
MARGIN_CM = 3.0

def cm_to_px(cm, dpi): 
    return int(round(cm/2.54*dpi))

def build_inside_mask_from_template(template_bgr):
    h, w = template_bgr.shape[:2]
    gray = cv2.cvtColor(template_bgr, cv2.COLOR_BGR2GRAY)
    white = cv2.threshold(gray, 245, 255, cv2.THRESH_BINARY)[1]
    ff_img = white.copy(); ff_buf = np.zeros((h+2, w+2), np.uint8)
    cv2.floodFill(ff_img, ff_buf, (0,0), 128)  # พื้นหลังติดขอบ -> 128
    background = (ff_img==128).astype(np.uint8)*255
    inside = cv2.bitwise_not(background)       # ด้านใน (รวมเส้น)
    inside = cv2.morphologyEx(inside, cv2.MORPH_CLOSE, np.ones((5,5), np.uint8), 2)
    return (inside>0).astype(np.uint8)*255

def build_outside_band(inside_mask, margin_cm, dpi):
    """ สร้าง 'วงนอก' = dilate(inside, 3ซม.) - inside """
    mpx = max(1, cm_to_px(margin_cm, dpi))
    k = 2*mpx + 1
    outer = cv2.dilate(inside_mask, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (k,k)))
    band = cv2.bitwise_and(outer, cv2.bitwise_not(inside_mask))
    return (band>0).astype(np.uint8)*255

def detect_colored(bgr):
    """จับพิกเซลที่ 'ไม่ใช่กระดาษขาว' (ทั้งสีสดและมืด)"""
    hsv = cv2.cvtColor(bgr, cv2.COLOR_BGR2HSV)
    H,S,V = cv2.split(hsv)
    # สีสด/กลาง + เฉดมืด (เงาเข้มหรือสีดำ)
    colored = ((S > 25) & (V > 70)) | (V < 110)
    # ตัดกระดาษขาวสว่างมาก
    near_white = (S < 12) & (V > 235)
    colored = colored & (~near_white)
    mask = (colored.astype(np.uint8) * 255)
    # กรองจุด noise เล็ก ๆ
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, np.ones((3,3), np.uint8), 1)
    return mask

if __name__ == "__main__":
    Tk().withdraw()
    template_path = filedialog.askopenfilename(title="Template", filetypes=[("Images","*.png;*.jpg;*.jpeg")])
    coloring_path = filedialog.askopenfilename(title="Coloring", filetypes=[("Images","*.png;*.jpg;*.jpeg")])

    template = cv2.imread(template_path)
    coloring = cv2.imread(coloring_path)
    if template is None or coloring is None:
        raise SystemExit("❌ โหลดภาพไม่สำเร็จ")

    coloring = cv2.resize(coloring, (template.shape[1], template.shape[0]))

    # 1) หาพื้นที่ด้านในจากเทมเพลต
    inside_mask = build_inside_mask_from_template(template)

    # 2) วงนอก 3 ซม. รอบรูป (ไม่นับด้านใน)
    outside_band = build_outside_band(inside_mask, MARGIN_CM, DPI)

    # 3) สีที่เกิดขึ้นจริงในภาพระบาย
    colored_mask = detect_colored(coloring)

    # 4) COTL = สัดส่วนวงนอกที่ถูกระบาย
    band_sel = outside_band > 0
    colored_outside = (colored_mask > 0) & band_sel

    band_area = int(band_sel.sum())
    outside_colored = int(colored_outside.sum())
    cotl = (outside_colored / band_area) if band_area > 0 else 0.0

    print(f"\n✅ COTL (ระบายออกนอกเส้น - แถบ 3 ซม.): {cotl:.4f}")

    # Debug (ช่วยดูว่าแถบไหนถูกนับ)
    cv2.imwrite("cotl_outside_band.png", outside_band)
    cv2.imwrite("cotl_colored_mask.png", colored_mask)
    vis = cv2.cvtColor(outside_band, cv2.COLOR_GRAY2BGR)
    vis[colored_outside] = (0,0,255)  # พิกเซลนอกเส้นที่มีสีทำเป็นแดงให้เห็นชัด
    cv2.imwrite("cotl_outside_colored_overlay.png", vis)

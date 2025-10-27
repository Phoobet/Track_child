# 📱 Track_child_development

แอปพลิเคชัน Flutter สำหรับประเมินและติดตามพัฒนาการการระบายสีของเด็ก  
โดยใช้ตัวชี้วัดหลัก 4 ด้าน ได้แก่  
- ⚪ Colorng Outside The Line — การระบายออกนอกเส้น 
- ⚪ Blank - พื้นที่ว่าง
- 📊 Shannon Entropy (H) — ความซับซ้อนของการกระจายสี  
- 🧩 Complexity (D*) — ความซับซ้อนเชิงรูปแบบตามการคำนวณเชิงทฤษฎี  
---

## ⚙️ ขั้นตอนการรันโปรเจกต์

### 1️⃣ ตรวจสอบการติดตั้ง Flutter
```bash
flutter doctor
```
### 2️⃣ เปิด Emulator (โทรศัพท์จำลอง)
```bash
flutter emulators

# เปิด Emulator ที่ต้องการ (ตัวอย่าง):
flutter emulators --launch Medium_Phone_API_36
```
### 3️⃣ รันโปรเจกต์บน Emulator
```bash
flutter run -d "sdk gphone64 x86 64"
```




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
### หน้าที่ใช้ แสดงการคำนวณ อยู่ในนี้
lib\features\processing\processing_screen.dart
### หน้าการคำนวณ
lib\services\metrics
การคำนวณจะอยู่ในนี้ทั้งหมด 
4 ค่าหลักคิดว่าเรียบร้อยแล้ว เช็คได้นะถ้าไม่ชัว
ที่เหลือคือ 
Z-Score กับ การรวมค่าอะ ทำไม่ได้จริง และการให้คะแนน


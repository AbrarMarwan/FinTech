# 💰 Mali Wallet – AI Financial Advisor

تطبيق محفظة مالية ذكية يعتمد على تحليل سلوك المستخدم باستخدام AI لتقديم توصيات مالية.

---

## 🧠 التقنيات المستخدمة

### 🔹 Backend

* Python
* FastAPI / Flask (حسب النسخة)
* SQLAlchemy
* SQLite
* OpenRouter API (للذكاء الاصطناعي)

### 🔹 Frontend

* Flutter (Dart)
* HTTP API Integration
* WebSocket (أسعار الذهب)

---

## ⚙️ تشغيل المشروع

### 🔹 أولاً: تشغيل الباك اند

1. افتح التيرمنال
2. انتقل إلى مجلد الباك اند:

```
cd Mali_Wallet-main/backend
```

3. فعّل البيئة (إذا موجودة):

```
.\.venv\Scripts\activate
```

4. ثبّت المكتبات:

```
pip install -r requirements.txt
```

أو:

```
pip install fastapi uvicorn sqlalchemy requests python-dotenv
```

5. شغّل السيرفر:

```
python main.py
```

أو (إذا FastAPI):

```
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

---

### 🔹 ثانياً: تشغيل الفرونت اند (Flutter)

1. افتح تيرمنال جديد
2. انتقل إلى مجلد المشروع:

```
cd Mali_Wallet-main
```

3. شغّل التطبيق:

```
flutter run
```

---

## 🌐 إعداد الاتصال (مهم)

عند تشغيل التطبيق على جوال حقيقي:

عدّل `baseUrl` في Flutter:

```dart
static const String baseUrl = 'http://192.168.X.X:8000';
```

واستخدم نفس IP جهازك (من ipconfig)

---

## 🔑 إعداد OpenRouter

1. أنشئ ملف `.env` داخل backend:

```
OPENROUTER_API_KEY=your_api_key_here
```

2. تأكد من تحميله في الكود:

```python
from dotenv import load_dotenv
import os

load_dotenv()
API_KEY = os.getenv("OPENROUTER_API_KEY")
```

---

## 🔗 مكونات النظام

```
Flutter App
     ↓
REST API (FastAPI / Flask)
     ↓
Business Logic + AI Engine
     ↓
Database (SQLite)
     ↓
OpenRouter (LLM)
```

---

## 🚀 مميزات المشروع

* تحليل سلوك المستخدم المالي
* حساب نسبة الادخار والمخاطر
* توصيات مالية ذكية
* دعم أسعار الذهب والعملات
* WebSocket للتحديث اللحظي

---

## ⚠️ ملاحظات مهمة

* يجب أن يكون الجوال والكمبيوتر على نفس الشبكة
* تأكد من فتح الـ Firewall
* لا تستخدم `127.0.0.1` عند تشغيل التطبيق على الجوال

---

## 👨‍💻 المطور
قائد الفريق: أبرار مروان الدبعي 
الاعضاء:
بلقيس عادل جميل
رغد اسكندر مقبل
سارة عمار الصمدي


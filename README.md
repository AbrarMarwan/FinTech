# Mali Wallet

تطبيق محفظة مالية ذكية مبني باستخدام Flutter وFastAPI وSQLite.

## المتطلبات

- 8 واجهات رئيسية كاملة
- إدارة الحالة باستخدام Provider وChangeNotifierProvider وConsumer
- CRUD كامل للمعاملات عبر REST API
- قاعدة بيانات SQLite في الخادم مع طبقة SQLite محلية للتخزين المؤقت في Flutter
- WebSocket لتحديث أسعار الذهب
- تحليل مالي ودمج خدمات الذكاء الاصطناعي

## الواجهات

1. الرئيسية
2. جميع الخدمات
3. مقدمة مالي
4. الخدمات المالية
5. تحليل المصروفات
6. الادخار
7. أسعار الذهب
8. أسعار العملات

تحتوي الواجهة الرئيسية على إدارة مباشرة للمعاملات لتنفيذ الإضافة والقراءة والتعديل والحذف.

## CRUD

المعاملات تدعم:

- POST /transactions/
- GET /transactions/
- PUT /transactions/{transaction_id}
- DELETE /transactions/{transaction_id}

## State Management

يتم توفير AppStateProvider على مستوى التطبيق باستخدام ChangeNotifierProvider، وتستخدم شاشة إدارة المعاملات Consumer للوصول إلى الحالة وتنفيذ عمليات CRUD.

## SQLite

قاعدة البيانات الأساسية في backend هي SQLite عبر SQLAlchemy، ويستخدم Flutter قاعدة SQLite محلية عبر sqflite لحفظ نسخة من المعاملات واسترجاعها عند تعذر الاتصال بالخادم.

## التشغيل

شغل الخادم من مجلد backend، ثم نفذ flutter pubget وشغل تطبيق Flutter على الجهاز أو المحاكي.
 cd backend
python -m uvicorn main:app --host 0.0.0.0 --port 8000
تأكد من أن عنوان API في lib/services/api_service.dart يشير إلى عنوان جهاز الخادم الصحيح.
 
flutter clean
flutter pub get
flutter run -d windows

# قطّه (Qattah)

> وين قطّتكم؟

تطبيق Flutter لتتبع الوجبات المشتركة بين زملاء العمل.

## الميزات

- ✅ تسجيل الحاضرين يومياً بنقرة واحدة
- ✅ حساب تلقائي للنصيب
- ✅ سجل تاريخي كامل
- ✅ تقارير شهرية
- ✅ إدارة الزملاء مع رموز إيموجي
- ✅ يعمل بدون إنترنت (SQLite)
- ✅ تصميم عربي RTL بالكامل

## المكدس التقني

| الطبقة | التقنية |
|--------|---------|
| Framework | Flutter 3.x |
| State Management | Riverpod 2.x |
| Navigation | go_router |
| Database | SQLite (sqflite) |
| Fonts | Google Fonts (Tajawal) |

## الهيكل

```
lib/
├── core/           ← ثوابت، ثيم، راوتر، DI
├── domain/         ← الكيانات + واجهات المستودعات
├── data/           ← SQLite + نماذج + تنفيذ المستودعات
└── presentation/   ← Providers + Screens + Widgets
```

## التشغيل

```bash
flutter pub get
flutter run
```

## المستقبل (جاهز للتوسع)

- [ ] Firebase Auth + تسجيل دخول
- [ ] Cloud Firestore مزامنة
- [ ] تصدير PDF
- [ ] iOS Support

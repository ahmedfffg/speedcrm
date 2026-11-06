# Speed Medical CRM

نظام CRM عربي RTL لإدارة عملاء Speed Medical والزيارات الميدانية والمبيعات والتارجت والمتابعات.

## التقنية
- واجهة HTML/CSS/JavaScript متجاوبة.
- Supabase Auth + PostgreSQL + Row Level Security.
- Supabase Edge Function لإنشاء روابط تقارير آمنة للعرض فقط.

## تشغيل المشروع
1. أنشئ مشروعًا على Supabase.
2. افتح SQL Editor وشغّل الملف [supabase/schema.sql](supabase/schema.sql).
3. انشر وظيفة المشاركة:
   ```bash
   supabase functions deploy share-report
   supabase secrets set SUPABASE_URL=... SUPABASE_ANON_KEY=... SUPABASE_SERVICE_ROLE_KEY=...
   ```
4. أنشئ حساب المستخدم الأول من Supabase Dashboard > Authentication > Users.
5. انشر المستودع على Vercel كموقع Static، أو افتح index.html عبر خادم محلي.
6. من الإعدادات داخل التطبيق أدخل Project URL وPublishable/anon key فقط.

## الأمان
- جميع جداول بيانات المستخدمين مفعّل عليها RLS بسياسات ملكية حسب auth.uid().
- جداول share_links وshare_link_permissions بلا سياسات وصول من المتصفح؛ الوصول إليها محصور بوظيفة Edge Function.
- روابط المشاركة تستخدم رموزًا عشوائية قوية، ويُخزّن SHA-256 hash فقط.
- لا تضع SUPABASE_SERVICE_ROLE_KEY في ملفات الواجهة أو GitHub.
- قبل الإنتاج: قيّد CORS على نطاق التطبيق، أضف Rate Limiting، واختبر صلاحيات المستخدمين المتعددين.

## حالة التنفيذ
النسخة الحالية تتضمن واجهة RTL متجاوبة، إعداد اتصال Supabase، تسجيل الدخول، وإدارة أساسية للعملاء والزيارات والمبيعات والمتابعات وجدول العمل. يلزم تطبيق SQL ونشر Edge Function قبل إدخال بيانات حقيقية. تقويم الزيارات، عناصر البيع التفصيلية، إدارة الروابط بالكامل، إعدادات الجدول الديناميكية، وسجل التدقيق واختبارات الإنتاج تحتاج استكمالًا قبل اعتبار النظام مكتملًا.

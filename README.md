# 🔄 نظام المزامنة والنسخ الاحتياطي الذكي
### Smart Offline-First Sync & Backup System — WPF + SQLite + Supabase

---

## 📌 نظرة عامة

نظام متكامل يجعل تطبيق WPF يعمل بشكل كامل بدون إنترنت، مع مزامنة ذكية تلقائية عند توفر الاتصال، ونسخ احتياطية مؤرخة محمية على السحابة، ولوحة تحكم ويب لمراقبة كل شيء في الوقت الفعلي.

**المبدأ الأساسي:** البيانات تعيش محلياً أولاً — السحابة نسخة احتياطية ذكية، ليست الأصل.

---

## 🏗️ المعمارية الكاملة

```
┌─────────────────────────────────────────────────────┐
│              تطبيق WPF (C#)                         │
│                                                     │
│  ┌──────────┐  ┌───────────────┐  ┌─────────────┐  │
│  │  SQLite  │  │ Change Tracker│  │ Backup Guard│  │
│  │ (أساسي) │→ │(pending_sync) │  │(حماية كارثة)│  │
│  └──────────┘  └───────────────┘  └─────────────┘  │
└─────────────────────┬───────────────────────────────┘
                      │
         ┌────────────▼────────────┐
         │    محرك المزامنة       │
         │                        │
         │ • كاشف الاتصال (30s)  │
         │ • Delta Sync           │
         │ • Conflict Resolver    │
         │ • Daily Pinger (24h)   │
         └────────────┬───────────┘
                      │
         ┌────────────▼───────────────────────────┐
         │         Supabase (مجاني)               │
         │                                        │
         │  PostgreSQL │ Storage │ Auth │ Realtime │
         └────────────────────────────────────────┘
                      │
         ┌────────────▼───────────────────────────┐
         │      لوحة تحكم الويب                  │
         │   (Next.js على Vercel — مجاني)         │
         └────────────────────────────────────────┘
```

---

## 🧩 المكونات التفصيلية

### 1. طبقة التطبيق المحلي (WPF)

#### SQLite — قاعدة البيانات الأساسية
كل جدول يحتاج عمودين إضافيين فقط:

```sql
-- إضافة دعم المزامنة لأي جدول
ALTER TABLE your_table ADD COLUMN updated_at DATETIME DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE your_table ADD COLUMN is_deleted INTEGER DEFAULT 0;

-- جدول تتبع التغييرات المعلّقة
CREATE TABLE pending_sync (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    table_name  TEXT NOT NULL,
    row_id      INTEGER NOT NULL,
    operation   TEXT NOT NULL, -- INSERT / UPDATE / DELETE
    timestamp   DATETIME DEFAULT CURRENT_TIMESTAMP,
    synced      INTEGER DEFAULT 0
);
```

#### Change Tracker
يسجّل كل تعديل تلقائياً عبر SQLite Triggers:

```sql
CREATE TRIGGER track_changes_after_update
AFTER UPDATE ON your_table
BEGIN
    INSERT INTO pending_sync (table_name, row_id, operation)
    VALUES ('your_table', NEW.id, 'UPDATE');
END;
```

#### Backup Guard — الحماية من كارثة التصفير
القاعدة الذهبية: **لا تقبل بيانات أقل من 20% من الأصل**

```csharp
public class BackupGuard
{
    public bool IsSafeToWrite(int incomingRows, int currentRows)
    {
        // رفض كامل إن كانت البيانات الواردة مشبوهة
        if (incomingRows < currentRows * 0.20)
            throw new DataIntegrityException(
                $"رُفض: {incomingRows} صف وارد مقابل {currentRows} موجود — خطر تصفير!");

        return true;
    }
}
```

---

### 2. محرك المزامنة الذكي

#### كاشف الاتصال
```csharp
NetworkChange.NetworkAvailabilityChanged += (s, e) =>
{
    if (e.IsAvailable)
        _ = SyncEngine.FlushPendingAsync(); // إرسال كل المعلّق
};
```

#### Delta Sync — المزامنة التفاضلية
يُرسَل فقط ما تغيّر، لا كل شيء:

```csharp
// استعادة فقط الصفوف الأحدث من آخر مزامنة
var changes = db.Query<Row>(
    "SELECT * FROM your_table WHERE updated_at > @lastSync",
    new { lastSync = LastSyncTimestamp }
);
```

#### Conflict Resolver — حلّ التعارضات
```
آخر updated_at يفوز (Last Write Wins)
↓
إن كانا في نفس الثانية → يُسأَل المستخدم
```

#### Daily Pinger — إبقاء Supabase حياً
```csharp
// يُنفَّذ عند بدء التطبيق — ping كل 24 ساعة
var timer = new Timer(async _ =>
{
    await supabase.From<PingTable>().Get();
}, null, TimeSpan.Zero, TimeSpan.FromHours(24));
```

> **لماذا؟** Supabase Free Tier يوقف المشروع بعد 7 أيام من الخمول — ping يومي يمنع ذلك.

---

### 3. نظام النسخ الاحتياطية المؤرخة

#### التردد والتسمية
```
backup_2025-01-15.db.gz
backup_2025-01-16.db.gz
backup_latest.db.gz      ← يُحدَّث دائماً
```

#### قواعد الحماية
- احتفاظ بـ **30 نسخة** — تُحذف الأقدم تلقائياً
- لا تُكتَب النسخة إن كانت **أصغر من السابقة بأكثر من 30%**
- ضغط GZip لتوفير مساحة التخزين

#### متى تُحفَظ النسخة؟

| الحدث | السلوك |
|---|---|
| إغلاق التطبيق + اتصال | نافذة تسأل: "هل تحفظ نسخة؟" |
| إغلاق + بلا إنترنت | تنبيه: "ستُحفَظ عند الاتصال القادم" |
| آخر نسخة اليوم موجودة | يغلق مباشرة بدون سؤال |
| تلقائي يومي | عند أول تشغيل للتطبيق |
| يدوي | زر "احفظ نسخة الآن" في الواجهة |

#### نافذة الإغلاق
```
┌─────────────────────────────────┐
│         قبل الإغلاق            │
│                                 │
│  آخر نسخة: منذ 3 أيام          │
│  ████████████░░░░  جارٍ...      │
│                                 │
│  [احفظ نسخة وأغلق]  [أغلق]    │
│         عرض سجل النسخ ↗        │
└─────────────────────────────────┘
```

---

### 4. سلوك النظام في كل حالة

| الحالة | ما يحدث بالضبط |
|---|---|
| تشغيل + اتصال | ping فوري، مزامنة كل `pending_sync` |
| عمل عادي + اتصال | كل تعديل يُزامَن فورياً |
| عمل عادي + بلا إنترنت | يعمل محلياً، التعديلات في `pending_sync` |
| عودة الإنترنت | `NetworkChange` يُطلق الإرسال تلقائياً |
| تعارض بين نسختين | آخر `updated_at` يفوز |
| بيانات مشبوهة | BackupGuard يرفض، ينبّه، يعرض الاستعادة |
| كارثة تصفير | رفض الكتابة + عرض آخر نسخة احتياطية |
| Supabase نائم | يعمل offline، ping يستأنف عند الاتصال |

---

### 5. لوحة تحكم الويب

موقع ويب مستقل يُتيح مراقبة كل شيء من أي جهاز.

#### الأقسام الرئيسية

**البطاقات العلوية:**
```
┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│  إجمالي النسخ│ │ آخر نسخة ناجحة│ │ عمليات فاشلة│ │ مساحة مستخدمة│
│     47       │ │  منذ 3 ساعات │ │      2       │ │   124 MB     │
└──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘
```

**جدول النسخ الاحتياطية:**

| التاريخ | الحجم | المصدر | الحالة | الإجراءات |
|---|---|---|---|---|
| 2025-01-15 22:32 | 2.3 MB | عند الإغلاق | ✓ ناجحة | تحميل — استعادة — حذف |
| 2025-01-14 09:15 | 2.1 MB | تلقائي | ✓ ناجحة | تحميل — استعادة — حذف |
| 2025-01-13 18:44 | 2.2 MB | يدوي | ✗ فاشلة | تفاصيل الخطأ |

**سجل العمليات:**

| الوقت | النوع | الجهاز | التفاصيل | النتيجة |
|---|---|---|---|---|
| 22:32 | نسخ احتياطي | PC-OFFICE | رُفع 2.3 MB | ✓ نجح |
| 22:31 | مزامنة | PC-OFFICE | 5 صفوف جديدة، 1 محذوف | ✓ نجح |
| 21:10 | ping | — | استجابة 142ms | ✓ نجح |
| 18:44 | نسخ احتياطي | LAPTOP-HOME | انقطع الاتصال | ✗ فشل |

**مؤشر الأمان:**
```
🟢 أخضر  → آخر نسخة منذ أقل من يومين
🟡 أصفر  → أقل من أسبوع
🔴 أحمر  → أكثر من أسبوع ← تنبيه تلقائي
```

#### مدخل الوصول للوحة
- من قائمة التطبيق: إعدادات ← النسخ الاحتياطي
- من شريط الحالة: أيقونة أسفل النافذة
- من نافذة الإغلاق: رابط "عرض سجل النسخ"
- تلقائياً: تفتح إن لم تكن هناك نسخة منذ 7 أيام

#### تجربة الاستعادة
```
1. اختر نسخة من الجدول → اضغط "استعادة"
2. تحذير: "سيتم استبدال البيانات الحالية"
3. خيار: "احفظ نسخة من الوضع الحالي أولاً"
4. شريط تقدم: جار التحميل... التحقق... الاستبدال...
5. نجح ✓ → إعادة تشغيل التطبيق تلقائياً
```

---

## 🗄️ جداول Supabase

```sql
-- النسخ الاحتياطية
CREATE TABLE backups (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at  TIMESTAMPTZ DEFAULT now(),
    file_path   TEXT NOT NULL,       -- مسار الملف في Storage
    file_size   BIGINT,              -- بالبايت
    source      TEXT,                -- 'auto' | 'manual' | 'on_close'
    status      TEXT DEFAULT 'ok',   -- 'ok' | 'failed' | 'pending'
    error_msg   TEXT,
    device_id   TEXT
);

-- سجل العمليات
CREATE TABLE sync_logs (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at  TIMESTAMPTZ DEFAULT now(),
    type        TEXT,                -- 'sync' | 'backup' | 'restore' | 'ping'
    device_id   TEXT,
    details     JSONB,
    success     BOOLEAN DEFAULT true,
    error_msg   TEXT
);

-- الأجهزة المسجلة
CREATE TABLE devices (
    id          TEXT PRIMARY KEY,
    name        TEXT,
    last_seen   TIMESTAMPTZ,
    last_sync   TIMESTAMPTZ
);

-- سجل الـ ping
CREATE TABLE ping_logs (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at  TIMESTAMPTZ DEFAULT now(),
    response_ms INTEGER,
    success     BOOLEAN
);
```

---

## 🛠️ التقنيات — صفر تكلفة

| المكوّن | التقنية | الخطة المجانية |
|---|---|---|
| قاعدة البيانات المحلية | SQLite | مجاني تماماً |
| تطبيق سطح المكتب | WPF C# (.NET 8) | مجاني تماماً |
| Supabase SDK | `supabase-csharp` | مجاني |
| PostgreSQL السحابي | Supabase | 500 MB مجاناً |
| تخزين ملفات النسخ | Supabase Storage | 1 GB مجاناً |
| المصادقة | Supabase Auth | 50,000 مستخدم مجاناً |
| التحديث الفوري | Supabase Realtime | مجاني |
| لوحة الويب | Next.js | مجاني |
| استضافة الويب | Vercel | مجاني |
| Ping احتياطي | GitHub Actions | 2000 دقيقة/شهر مجاناً |

---

## 🔒 الأمان

- كل البيانات مشفرة عبر JWT من Supabase Auth
- Row Level Security (RLS) على كل جداول Supabase
- لا يصل أحد لبياناتك إلا بحساب مصادق
- النسخ الاحتياطية مضغوطة بـ GZip ومشفرة أثناء النقل (HTTPS)

---

## 📋 خطة التنفيذ

| الخطوة | المهمة | الوقت |
|---|---|---|
| 1 | إضافة `updated_at` و`is_deleted` لجداول SQLite | 1 ساعة |
| 2 | إنشاء جدول `pending_sync` + SQLite Triggers | 1 ساعة |
| 3 | كتابة `ConnectivityWatcher` + `DailyPinger` | 1 ساعة |
| 4 | ربط Supabase SDK وإعداد الجداول | 2 ساعة |
| 5 | كتابة `SyncEngine` — الإرسال والاستقبال | 3 ساعات |
| 6 | كتابة `BackupGuard` — منطق الحماية | 2 ساعة |
| 7 | نظام النسخ المؤرخة على Supabase Storage | 2 ساعة |
| 8 | نافذة الإغلاق مع سؤال النسخ | 1 ساعة |
| 9 | جداول Supabase للوحة | 1 ساعة |
| 10 | لوحة تحكم الويب (Next.js + Vercel) | 4 ساعات |
| 11 | شريط الحالة أسفل التطبيق | 1 ساعة |
| 12 | GitHub Actions كـ ping احتياطي | 30 دقيقة |

**الإجمالي:** ~19 ساعة من العمل الفعلي

---

## 🚀 GitHub Actions — Ping الاحتياطي

ينشط يومياً حتى لو لم يُشغَّل التطبيق:

```yaml
# .github/workflows/keep-alive.yml
name: Keep Supabase Alive
on:
  schedule:
    - cron: '0 8 * * *'  # كل يوم الساعة 8 صباحاً

jobs:
  ping:
    runs-on: ubuntu-latest
    steps:
      - name: Ping Supabase
        run: |
          curl -s "${{ secrets.SUPABASE_URL }}/rest/v1/ping_logs" \
            -H "apikey: ${{ secrets.SUPABASE_ANON_KEY }}" \
            -H "Authorization: Bearer ${{ secrets.SUPABASE_ANON_KEY }}"
```

---

## 📁 هيكل المشروع

```
YourApp/
├── YourApp.WPF/
│   ├── Services/
│   │   ├── SyncEngine.cs
│   │   ├── BackupGuard.cs
│   │   ├── ConnectivityWatcher.cs
│   │   ├── DailyPinger.cs
│   │   └── SupabaseService.cs
│   ├── Windows/
│   │   ├── CloseConfirmWindow.xaml      ← نافذة سؤال النسخ
│   │   └── BackupManagerWindow.xaml     ← واجهة التحكم المحلية
│   └── Database/
│       ├── schema.sql
│       └── triggers.sql
│
├── dashboard/                           ← لوحة الويب
│   ├── pages/
│   │   ├── index.tsx                    ← الرئيسية
│   │   ├── backups.tsx                  ← جدول النسخ
│   │   └── logs.tsx                     ← سجل العمليات
│   └── vercel.json
│
└── .github/
    └── workflows/
        └── keep-alive.yml
```



التقنية المقترحة للوحة الويب
الجانبالاختيارالسببالإطارNext.js 14مجاني على Vercel، سريع، SEO جيدالتصميمTailwind CSSلا حاجة لملفات CSS منفصلةالجداولTanStack Tableأفضل جدول مجاني لـ Reactالرسوم البيانيةRechartsخفيف ومجانيالاتصال بـ Supabase@supabase/supabase-jsرسمي ومباشرالتحديث الفوريSupabase Realtime مدمجبدون مكتبة إضافية

---

*بُني هذا النظام بمبدأ: البيانات لا تُفقَد أبداً — حتى لو انقطع الإنترنت، تعطّل السحابة، أو حدثت كارثة تصفير.*

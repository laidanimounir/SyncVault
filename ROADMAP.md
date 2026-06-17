# خريطة طريق SyncVault — دراسة جدوى وخطة تنفيذ

---

## القسم 1 — ملخص تنفيذي

### الحكم النهائي

| المعيار | النتيجة |
|---------|---------|
| **قابل للتطبيق؟** | نعم — بنسبة ثقة 92% |
| **صعوبة التكامل** | **متوسطة** — لا سهلة ولا صعبة |
| **نسبة تعديل الكود الحالي** | ~40-45% من ملفات WPF تحتاج تعديلاً |
| **عدد ساعات العمل المقدرة** | **45-55 ساعة** (وليس 19 كما في README) |
| **النهج الموصى به** | **التكامل التدريجي** داخل ProManSystem مباشرة — لا بناء موازٍ |

### لماذا متوسطة وليست سهلة؟

1. **غياب حاوية DI**: كل خدمة في ProManSystem تُنشأ بـ `new` مباشرة. إدخال `Microsoft.Extensions.DependencyInjection` سيلمس كل نافذة.
2. **Code-behind الشامل**: 44+ نافذة تستخدم `new AppDbContext()` مباشرة في الكود. لا يوجد فصل Concerns.
3. **نموذجان مختلفان للفواتير**: `SalesInvoice` و`CommercialSalesInvoice` لهما أسماء خصائص مختلفة (`NumeroFacture` vs `InvoiceNumber`). كل عملية Sync ستضاعف.
4. **غياب `is_deleted`**: لا يوجد soft-delete في أي جدول. إضافته ستغير 15+ جدولاً وكل استعلاماتها.

### لماذا ليست صعبة؟

1. **SQLite موجود ويعمل**: البنية التحتية المحلية جاهزة. WAL checkpoint موجود جزئياً في `DatabaseMaintenanceService.RunWalCheckpoint()`.
2. **نظام النسخ الاحتياطي موجود**: `DatabaseMaintenanceService.CreateAutoBackup()` ينشئ نسخاً محلية. يحتاج تمديداً لا بناءً من الصفر.
3. **نظام مزامنة موجود**: `SalesInvoiceSyncService` يثبت أن المزامنة الخلفية ممكنة مع `IProgress<SyncProgress>`.
4. **لا مستخدمين متعددين**: مستخدم واحد = لا تعقيدات multi-user sync. Conflict Resolution مبسط يكفي.

---

## القسم 2 — الحالة الراهنة لـ ProManSystem

### مخطط المعمارية الحالية

```
┌────────────────────────────────────────────────────┐
│                    App.xaml.cs                     │
│  • تحقق من pending_replace.txt                     │
│  • DatabaseSetupWindow إن لم توجد قاعدة بيانات     │
│  • InitializeDatabase() + FixOldDataAutomatically()│
│  • بدء مزامنة PDF في الخلفية                       │
│  • إظهار SplashScreen                              │
└─────────────────────┬──────────────────────────────┘
                      │
┌─────────────────────▼──────────────────────────────┐
│                    HomeWindow                      │
│  • شريط جانبي (قابل للطي)                          │
│  • ContentControl للعرض الرئيسي                    │
│  • تحكم مخصص في النافذة (بدون شريط عنوان)          │
│  • CompanySwitcherDialog عند تغيير الشركة           │
└────────┬──────────────────────────────┬───────────┘
         │                              │
┌────────▼────────┐          ┌─────────▼─────────┐
│  Production     │          │   Commercial      │
│  • ClientsView  │          │  • CommProducts   │
│  • Suppliers    │          │  • CommSales      │
│  • SalesInvoices│          │  • CommPurchases  │
│  • PurchaseInv. │          │  • CommMovement   │
│  • Products     │          │  • EtatsAnnuels   │
└────────┬────────┘          └─────────┬─────────┘
         │                              │
         └──────────┬───────────────────┘
                    │
         ┌──────────▼──────────┐
         │    AppDbContext      │
         │  (ينشأ جديداً في كل  │
         │   نافذة — لا حاوية)   │
         └──────────┬──────────┘
                    │
         ┌──────────▼──────────┐
         │   SQLite (app.db)   │
         │ %LocalAppData%\     │
         │   ProManSystem\     │
         │   app.db            │
         └─────────────────────┘
```

### جميع الجداول (20 جدولاً)

| الجدول | المفتاح | الأعمدة الرئيسية | CompanyId؟ |
|--------|---------|-------------------|------------|
| Companies | CompanyId | Name, Code(unique), BusinessType, LogoBase64, 14 عموداً آخر | ❌ (جذر) |
| Customers | Id | CodeClient, NomComplet, Activite, Adresse, MatriculeFiscal, CA_HT, TauxTVA, CA_TTC, EstRadie | نعم |
| Suppliers | Id | CodeFournisseur, Designation, Activite, NumeroRC, MatriculeFiscal, Dette, EstActif | نعم |
| Units | Id | Nom, EstPredefined | ❌ (مشترك) |
| Products | Id | CodeProduit, Nom, PrixVente, StockActuel, StockMin, CoutProduction, Marge, UnitId FK | نعم |
| ProductRecipes | Id | ProductId FK, RawMaterialId FK, QuantiteNecessaire | نعم |
| ProductCategories | Id | Name, Description, DisplayOrder, IsActive | نعم |
| RawMaterials | Id | CodeMatiere, Designation, StockActuel, StockMin, PMAPA, MethodeCalculPrix, UnitId FK | نعم |
| SalesInvoices | Id | NumeroFacture, CustomerId FK, DateFacture, MontantHT, TauxTVA, MontantTTC, EstPayee | نعم |
| SalesInvoiceLines | Id | SalesInvoiceId FK, ProductId FK, Quantite, PrixUnitaire, MontantLigne | ❌ (عبر الفاتورة) |
| PurchaseInvoices | Id | NumeroFacture, SupplierId FK, DateFacture, MontantHT, TauxTVA, MontantTTC, EstPayee | نعم |
| PurchaseInvoiceLines | Id | PurchaseInvoiceId FK, RawMaterialId FK, Quantite, PrixUnitaire, MontantLigne | ❌ (عبر الفاتورة) |
| CommercialProducts | Id | Code, Barcode, Name, CategoryId FK, UnitId FK, SellingPriceRetail, StockQuantity, MinStockLevel | نعم |
| CommercialSalesInvoices | Id | InvoiceNumber, CustomerId FK, MontantHT, TauxTVA, MontantTTC, TotalCost, TotalProfit, Status, SaleType | نعم |
| CommercialSalesInvoiceLines | Id | InvoiceId FK, CommercialProductId FK, StockBatchId FK, Quantity, UnitPrice, CostPrice, TotalPrice | ❌ (عبر الفاتورة) |
| CommercialPurchaseInvoices | Id | InvoiceNumber, SupplierId FK, MontantHT, TauxTVA, MontantTTC, Status | نعم |
| CommercialPurchaseInvoiceLines | Id | InvoiceId FK, CommercialProductId FK, StockBatchId FK, Quantity, UnitPrice | ❌ (عبر الفاتورة) |
| StockBatches | Id | CommercialProductId FK, BatchNumber, PurchasePricePerUnit, QuantityReceived, QuantityRemaining, QuantitySold, Status | نعم |
| AgentLogs | Id | Timestamp, Level, Source, Message, Details, InvoiceId, CompanyId | نعم |
| AppSettings | Key (PK) | Value | ❌ (مشترك) |

### ما يعمل جيداً

- **SQLite موثوق**: 20 جدولاً بعلاقات سليمة مع EF Core
- **Multi-tenancy**: CompanyId + Global Query Filters تعمل بشكل صحيح
- **WAL checkpoint**: موجود في `DatabaseMaintenanceService.RunWalCheckpoint()` (السطر 157-168)
- **نسخ احتياطي محلي**: `CreateAutoBackup()` ينشئ نسخاً مؤرخة في `Backups\`
- **مزامنة PDF خلفية**: `SalesInvoiceSyncService` مع `IProgress<SyncProgress>` يعمل
- **استبدال قاعدة البيانات**: `ReplaceDatabase()` مع `ClearConnectionPool()` يعمل
- **تتبع التغييرات**: EF Core ChangeTracker موجود لكنه لا يُستخدم للمزامنة

### ما هو هش أو مفقود

| المشكلة | الخطورة | التفاصيل |
|---------|---------|----------|
| غياب Dependency Injection | 🔴 عالية | كل نافذة تنشئ `new AppDbContext()` مباشرة |
| مسارات صلبة الترميز | 🔴 عالية | `C:\WalidFacture\Factures\` في 3 خدمات |
| اسم شركة مقسى | 🔴 عالية | `InvoicePdfService` يكتب "بروكو سيستم" حرفياً |
| لا نظام مستخدمين | 🟡 متوسطة | المسؤول مقسى في XAML |
| 3 مكتبات PDF غير مستخدمة | 🟢 منخفضة | iText7, iTextSharp, QuestPDF حِمْل زائد |
| FixOldDataAutomatically() | 🟡 متوسطة | ALTER TABLE مع catch-all صامت — هش |
| لا soft-delete | 🔴 عالية | الحذف مادي — لا يمكن تتبع المحذوفات للمزامنة |
| لا تحديث طابع زمني تلقائي | 🔴 عالية | لا `updated_at` على أي جدول — أساس المزامنة |
| مفتاح Groq API مخزن نصاً صريحاً | 🟡 متوسطة | في جدول AppSettings |
| Nullable disabled | 🟢 منخفضة | لا حماية من null |
| مزامنة فواتير فقط | 🟡 متوسطة | لا مزامنة للمنتجات، العملاء، الموردين... |

---

## القسم 3 — المعمارية الهدف بعد SyncVault

### مخطط النظام الكامل

```
┌──────────────────────────────────────────────────────────────────┐
│                     تطبيق WPF — ProManSystem                     │
│                                                                  │
│  ┌────────────────────────────┐   ┌───────────────────────────┐ │
│  │    ProManSystem.DI         │   │  Microsoft.Extensions.DI  │ │
│  │    (حاوية جديدة)            │   │  Host Builder             │ │
│  │                            │   │                           │ │
│  │  IAppDbContext (معاد)       │   │  ISyncEngine              │ │
│  │  ICurrentCompanyService    │   │  IBackupGuard             │ │
│  │  IDatabaseMaintenance      │   │  IShadowCopyService       │ │
│  │  INotificationService      │   │  ISecureBackupService     │ │
│  │  IGroqAgentService         │   │  IBackupRotationService   │ │
│  └────────────────────────────┘   │  IDisasterRecoveryService │ │
│                                   │  IConnectivityWatcher      │ │
│  ┌──────────────────┐             │  IDailyPinger              │ │
│  │  SQLite (WAL)     │             │  IChangeTracker            │ │
│  │  main.db          │             └───────────┬───────────────┘ │
│  │  + updated_at     │                         │                 │
│  │  + is_deleted     │                         │                 │
│  │  + pending_sync   │                         │                 │
│  │  + triggers       │                         │                 │
│  └───────┬──────────┘                         │                 │
│          │                                    │                 │
│          ├── ShadowCopy ──► D:\Backup\        │                 │
│          │                  shadow.db          │                 │
│          │                                    │                 │
└──────────┼────────────────────────────────────┼─────────────────┘
           │                                    │
           ▼                                    ▼
┌──────────────────────────────────────────────────────────────────┐
│                         السحابة                                  │
│                                                                  │
│  ┌──────────────────┐  ┌───────────────┐  ┌──────────────────┐  │
│  │  Supabase        │  │  Google Drive │  │  GitHub Actions  │  │
│  │                  │  │               │  │                  │  │
│  │  • backups       │  │  نسخة أسبوعية │  │  • keep-alive   │  │
│  │  • sync_logs     │  │  مشفرة AES-256│  │    (cron يومي)  │  │
│  │  • devices       │  │               │  │                  │  │
│  │  • ping_logs     │  └───────────────┘  └──────────────────┘  │
│  │  • immutable-    │                                            │
│  │    backups       │  ┌──────────────────────────────────────┐  │
│  └──────────────────┘  │  لوحة تحكم الويب (اختياري)           │  │
│                        │  Next.js على Vercel                  │  │
│                        │  • مراقبة النسخ                       │  │
│                        │  • سجل العمليات                       │  │
│                        │  • حالة الأجهزة                       │  │
│                        └──────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

### تدفق البيانات

```
[المستخدم يُدخل بيانات]
       │
       ▼
[EF Core DbContext.SaveChanged()]
       │
       ├──► [SQLite Trigger: track_changes_*]
       │         │
       │         ▼
       │    [جدول pending_sync ← INSERT row]
       │
       ├──► [ShadowCopyService.UpdateShadowAsync()]  ← كل 30 دقيقة
       │         │
       │         ▼
       │    [D:\Backup\shadow.db]
       │
       └──► [SyncEngine.FlushPendingAsync()]  ← عن توفر الإنترنت
                 │
                 ├──► [BackupGuard.IsSafeToWrite()]  ← تحقق قبل الإرسال
                 │
                 ├──► [POST /rest/v1/{table}]
                 │
                 └──► [UPDATE pending_sync SET synced = 1]
```

---

## القسم 4 — مراحل التنفيذ

---

### المرحلة 1 — الأساس (بدون تغييرات مخربة)

#### الهدف
تجهيز المشروع للمراحل التالية دون كسر أي وظيفة حالية.

#### 1.1 إضافة حاوية Dependency Injection

**ملف جديد**: `ProManSystem\DependencyInjection\ServiceCollectionExtensions.cs`

```csharp
namespace ProManSystem.DependencyInjection;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddProManServices(this IServiceCollection services)
    {
        // Core
        services.AddSingleton<ICurrentCompanyService, CurrentCompanyService>();
        services.AddDbContext<AppDbContext>(options =>
            options.UseSqlite($"Data Source={DatabaseMaintenanceService.GetDbPath()}")
                   .UseQueryTrackingBehavior(QueryTrackingBehavior.NoTracking),
            ServiceLifetime.Scoped);

        // Existing Services → Interfaces
        services.AddSingleton<INotificationService, NotificationService>();
        services.AddSingleton<IGroqAgentService, GroqAgentService>();
        services.AddSingleton<IInventoryValidator, InventoryValidator>();
        services.AddSingleton<IAgentLogger, AgentLogger>();
        services.AddSingleton<IGroqSettingsService, GroqSettingsService>();

        // PDF
        services.AddSingleton<ISalesInvoicePdfPathService, SalesInvoicePdfPathService>();
        services.AddTransient<ISalesInvoiceExportService, SalesInvoiceExportService>();

        return services;
    }
}
```

**ملف جديد**: `ProManSystem\DependencyInjection\AppHost.cs`

```csharp
namespace ProManSystem.DependencyInjection;

public static class AppHost
{
    public static IHost Host { get; private set; }

    public static void Build()
    {
        var builder = Microsoft.Extensions.Hosting.Host.CreateDefaultBuilder();

        builder.ConfigureServices((context, services) =>
        {
            services.AddProManServices();
        });

        Host = builder.Build();
    }

    public static T GetService<T>() where T : notnull
        => Host.Services.GetRequiredService<T>();
}
```

**ملف معدّل**: `App.xaml.cs`
- أضف `AppHost.Build()` في أول `Application_Startup`
- استبدل `new AppDbContext()` المباشر في `Application_Startup` بـ DI

**ملف معدّل**: `ProManSystem.csproj`
- أضف `Microsoft.Extensions.Hosting` (الإصدار 8.0.0)
- أضف `supabase-csharp` (الإصدار الأحدث — من NuGet)

**الوقت المقدر**: 4 ساعات

---

#### 1.2 استخراج واجهات للخدمات الموجودة

لا حاجة لإنشاء ملفات جديدة — أضف واجهات للخدمات التي ستستخدمها SyncVault:

| الخدمة الحالية | الواجهة الجديدة |
|----------------|-----------------|
| `CurrentCompanyService` | `ICurrentCompanyService` — أضف `CompanyChanged` event, `GetCurrentCompanyId()`, `ClearCurrentCompany()` |
| `DatabaseMaintenanceService` | `IDatabaseMaintenanceService` — static → instance, أضف `GetBackupFolder()`, `GetWalStatus()` |
| `NotificationService` | `INotificationService` (موجود فعلاً في AI.Notifications) |
| `AppDbContext` | `IAppDbContext` — اختياري للمرحلة الأولى |

**ملفات معدّلة**:
- `Services\CurrentCompanyService.cs` — أضف `: ICurrentCompanyService`
- `Services\DatabaseMaintenanceService.cs` — حوّل static إلى instance مع واجهة

**الوقت المقدر**: 3 ساعات

---

#### 1.3 إضافة أعمدة المزامنة لكل الجداول

**ملف جديد**: `ProManSystem\Database\sync_schema.sql`

```sql
-- أضف updated_at لكل جدول يحتاج مزامنة
ALTER TABLE Customers ADD COLUMN updated_at TEXT DEFAULT (datetime('now'));
ALTER TABLE Customers ADD COLUMN is_deleted INTEGER DEFAULT 0;
ALTER TABLE Suppliers ADD COLUMN updated_at TEXT DEFAULT (datetime('now'));
ALTER TABLE Suppliers ADD COLUMN is_deleted INTEGER DEFAULT 0;
ALTER TABLE Products ADD COLUMN updated_at TEXT DEFAULT (datetime('now'));
ALTER TABLE Products ADD COLUMN is_deleted INTEGER DEFAULT 0;
ALTER TABLE RawMaterials ADD COLUMN updated_at TEXT DEFAULT (datetime('now'));
ALTER TABLE RawMaterials ADD COLUMN is_deleted INTEGER DEFAULT 0;
ALTER TABLE SalesInvoices ADD COLUMN updated_at TEXT DEFAULT (datetime('now'));
ALTER TABLE SalesInvoices ADD COLUMN is_deleted INTEGER DEFAULT 0;
ALTER TABLE PurchaseInvoices ADD COLUMN updated_at TEXT DEFAULT (datetime('now'));
ALTER TABLE PurchaseInvoices ADD COLUMN is_deleted INTEGER DEFAULT 0;
ALTER TABLE CommercialProducts ADD COLUMN updated_at TEXT DEFAULT (datetime('now'));
ALTER TABLE CommercialProducts ADD COLUMN is_deleted INTEGER DEFAULT 0;
ALTER TABLE CommercialSalesInvoices ADD COLUMN updated_at TEXT DEFAULT (datetime('now'));
ALTER TABLE CommercialSalesInvoices ADD COLUMN is_deleted INTEGER DEFAULT 0;
ALTER TABLE CommercialPurchaseInvoices ADD COLUMN updated_at TEXT DEFAULT (datetime('now'));
ALTER TABLE CommercialPurchaseInvoices ADD COLUMN is_deleted INTEGER DEFAULT 0;
ALTER TABLE StockBatches ADD COLUMN updated_at TEXT DEFAULT (datetime('now'));
ALTER TABLE StockBatches ADD COLUMN is_deleted INTEGER DEFAULT 0;
ALTER TABLE ProductRecipes ADD COLUMN updated_at TEXT DEFAULT (datetime('now'));
ALTER TABLE ProductRecipes ADD COLUMN is_deleted INTEGER DEFAULT 0;
ALTER TABLE ProductCategories ADD COLUMN updated_at TEXT DEFAULT (datetime('now'));
ALTER TABLE ProductCategories ADD COLUMN is_deleted INTEGER DEFAULT 0;
ALTER TABLE Companies ADD COLUMN updated_at TEXT DEFAULT (datetime('now'));

-- جدول تتبع التغييرات المعلقة
CREATE TABLE IF NOT EXISTS pending_sync (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    table_name  TEXT NOT NULL,
    row_id      INTEGER NOT NULL,
    company_id  INTEGER NOT NULL,       -- ⚠️ يجب أخذه من السياق
    operation   TEXT NOT NULL,          -- INSERT / UPDATE / DELETE
    old_data    TEXT,                   -- JSON للبيانات القديمة (للتراجع)
    timestamp   TEXT DEFAULT (datetime('now')),
    synced      INTEGER DEFAULT 0,
    device_id   TEXT                    -- أي جهاز قام بالتعديل
);

CREATE INDEX IF NOT EXISTS idx_pending_sync_synced
    ON pending_sync(synced, timestamp);
```

**ملف جديد**: `ProManSystem\Database\sync_triggers.sql`

```sql
-- مثال لجدول Customers — يُكرر لكل جدول

CREATE TRIGGER IF NOT EXISTS trg_customers_after_insert
AFTER INSERT ON Customers
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    VALUES ('Customers', NEW.Id, NEW.CompanyId, 'INSERT',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id'));
END;

CREATE TRIGGER IF NOT EXISTS trg_customers_after_update
AFTER UPDATE ON Customers
BEGIN
    UPDATE Customers SET updated_at = datetime('now') WHERE Id = NEW.Id;
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    VALUES ('Customers', NEW.Id, NEW.CompanyId, 'UPDATE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id'));
END;

CREATE TRIGGER IF NOT EXISTS trg_customers_before_delete
BEFORE DELETE ON Customers
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    VALUES ('Customers', OLD.Id, OLD.CompanyId, 'DELETE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id'));
END;
```

**ملف معدّل**: `AppDbContext.cs`
- أضف `DbSet<PendingSync> PendingSyncRecords` 
- أضف `modelBuilder.Entity<PendingSync>().ToTable("pending_sync")` في `OnModelCreating`
- نفّذ `sync_schema.sql` و `sync_triggers.sql` في `FixOldDataAutomatically()` أو Migration جديد

**تحذير معماري**: SQLite Triggers لا تستطيع الوصول إلى EF Core ChangeTracker. `CompanyId` في trigger يُؤخذ من `NEW.CompanyId` مباشرة (موجود في الصف). لكن `device_id` يحتاج أن يُخزّن في `AppSettings` أولاً.

**الوقت المقدر**: 4 ساعات (لكثرة الجداول)

---

#### 1.4 تفعيل WAL Mode

**ملف معدّل**: `DatabaseMaintenanceService.cs`
- أضف في `InitializeDatabase()`:
```csharp
db.Database.ExecuteSqlRaw("PRAGMA journal_mode=WAL;");
db.Database.ExecuteSqlRaw("PRAGMA synchronous=FULL;");
db.Database.ExecuteSqlRaw("PRAGMA busy_timeout=5000;");
db.Database.ExecuteSqlRaw("PRAGMA foreign_keys=ON;");
```

**الوقت المقدر**: 0.5 ساعة

---

### المرحلة 2 — محرك المزامنة

#### 2.1 ConnectivityWatcher.cs

**ملف جديد**: `ProManSystem\Services\Sync\ConnectivityWatcher.cs`

```csharp
namespace ProManSystem.Services.Sync;

public interface IConnectivityWatcher
{
    bool IsOnline { get; }
    event EventHandler<bool> ConnectivityChanged;
    void Start();
    void Stop();
}

public class ConnectivityWatcher : IConnectivityWatcher, IDisposable
{
    public bool IsOnline => System.Net.NetworkInformation.NetworkInterface
        .GetIsNetworkAvailable();

    public event EventHandler<bool>? ConnectivityChanged;

    private System.Timers.Timer? _timer;

    public void Start()
    {
        NetworkChange.NetworkAvailabilityChanged += OnNetworkChange;
        _timer = new System.Timers.Timer(30_000); // كل 30 ثانية
        _timer.Elapsed += (_, _) =>
        {
            var online = IsOnline;
            ConnectivityChanged?.Invoke(this, online);
        };
        _timer.Start();
    }

    public void Stop()
    {
        NetworkChange.NetworkAvailabilityChanged -= OnNetworkChange;
        _timer?.Stop();
    }

    private void OnNetworkChange(object? sender, NetworkAvailabilityEventArgs e)
    {
        ConnectivityChanged?.Invoke(this, e.IsAvailable);
    }

    public void Dispose() => Stop();
}
```

**الوقت المقدر**: 1.5 ساعة

---

#### 2.2 DailyPinger.cs

**ملف جديد**: `ProManSystem\Services\Sync\DailyPinger.cs`

```csharp
namespace ProManSystem.Services.Sync;

public interface IDailyPinger
{
    void Start();
    Task PingAsync();
}

public class DailyPinger : IDailyPinger
{
    private readonly ISupabaseClient _supabase;
    private PeriodicTimer? _timer;
    private CancellationTokenSource? _cts;

    public DailyPinger(ISupabaseClient supabase)
    {
        _supabase = supabase;
    }

    public void Start()
    {
        _cts = new CancellationTokenSource();
        _timer = new PeriodicTimer(TimeSpan.FromHours(24));
        _ = RunAsync(_cts.Token);
    }

    private async Task RunAsync(CancellationToken ct)
    {
        await PingAsync(); // ping فوري عند البدء
        while (await _timer!.WaitForNextTickAsync(ct))
        {
            await PingAsync();
        }
    }

    public async Task PingAsync()
    {
        try
        {
            var response = await _supabase
                .From<PingLog>()
                .Insert(new PingLog
                {
                    Id = Guid.NewGuid(),
                    CreatedAt = DateTimeOffset.UtcNow,
                    Success = true
                });
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"[Pinger] فشل: {ex.Message}");
        }
    }
}
```

**الوقت المقدر**: 1.5 ساعة

---

#### 2.3 SyncEngine.cs

**ملف جديد**: `ProManSystem\Services\Sync\SyncEngine.cs`

```csharp
namespace ProManSystem.Services.Sync;

public interface ISyncEngine
{
    event EventHandler<SyncProgressEventArgs>? SyncProgressChanged;
    Task FlushPendingAsync();
    Task<int> GetPendingCountAsync();
    DateTime? LastSyncTime { get; }
}

public class SyncProgressEventArgs : EventArgs
{
    public int Total { get; set; }
    public int Done { get; set; }
    public int Failed { get; set; }
    public string CurrentTable { get; set; } = "";
    public string Status { get; set; } = "";
}

public class SyncEngine : ISyncEngine
{
    private readonly IDbContextFactory<AppDbContext> _dbFactory;
    private readonly ISupabaseClient _supabase;
    private readonly IBackupGuard _backupGuard;
    private readonly ILogger<SyncEngine> _logger;

    public event EventHandler<SyncProgressEventArgs>? SyncProgressChanged;
    public DateTime? LastSyncTime { get; private set; }

    public SyncEngine(
        IDbContextFactory<AppDbContext> dbFactory,
        ISupabaseClient supabase,
        IBackupGuard backupGuard,
        ILogger<SyncEngine> logger)
    {
        _dbFactory = dbFactory;
        _supabase = supabase;
        _backupGuard = backupGuard;
        _logger = logger;
    }

    public async Task<int> GetPendingCountAsync()
    {
        using var db = await _dbFactory.CreateDbContextAsync();
        return await db.Set<PendingSync>()
            .CountAsync(p => p.Synced == 0);
    }

    public async Task FlushPendingAsync()
    {
        using var db = await _dbFactory.CreateDbContextAsync();

        var pending = await db.Set<PendingSync>()
            .Where(p => p.Synced == 0)
            .OrderBy(p => p.Timestamp)
            .Take(200) // دفعات لا تزيد عن 200
            .ToListAsync();

        if (!pending.Any()) return;

        var total = pending.Count;
        var done = 0;
        var failed = 0;

        foreach (var item in pending)
        {
            try
            {
                await SyncSingleRecordAsync(db, item);
                item.Synced = 1;
                done++;
            }
            catch (Exception ex)
            {
                failed++;
                _logger.LogError(ex, "فشلت مزامنة {Table}#{Row}", item.TableName, item.RowId);
            }

            SyncProgressChanged?.Invoke(this, new SyncProgressEventArgs
            {
                Total = total, Done = done, Failed = failed,
                CurrentTable = item.TableName
            });
        }

        await db.SaveChangesAsync();
        LastSyncTime = DateTime.UtcNow;
    }

    private async Task SyncSingleRecordAsync(AppDbContext db, PendingSync item)
    {
        switch (item.Operation)
        {
            case "INSERT":
            case "UPDATE":
                // اقرأ الصف الكامل من SQLite
                var row = await GetRowByIdAsync(db, item.TableName, item.RowId);
                if (row == null) return;

                // أرسل إلى Supabase كـ Upsert
                await _supabase
                    .From(item.TableName.ToLower())
                    .Upsert(row);
                break;

            case "DELETE":
                // أرسل soft-delete إلى Supabase
                await _supabase
                    .From(item.TableName.ToLower())
                    .Update(new { is_deleted = true, updated_at = DateTime.UtcNow });
                break;
        }
    }

    private async Task<Dictionary<string, object?>?> GetRowByIdAsync(
        AppDbContext db, string tableName, int rowId)
    {
        // استخدام ADO.NET الخام لقراءة أي جدول
        var conn = db.Database.GetDbConnection();
        await conn.OpenAsync();
        var cmd = conn.CreateCommand();
        cmd.CommandText = $"SELECT * FROM {tableName} WHERE Id = @id";
        cmd.Parameters.Add(new SqliteParameter("@id", rowId));

        using var reader = await cmd.ExecuteReaderAsync();
        if (!await reader.ReadAsync()) return null;

        var row = new Dictionary<string, object?>();
        for (int i = 0; i < reader.FieldCount; i++)
        {
            var val = reader.IsDBNull(i) ? null : reader.GetValue(i);
            row[reader.GetName(i)] = val;
        }
        return row;
    }
}
```

**ملاحظة مهمة**: `GetRowByIdAsync` تستخدم SQL خام لأن SyncEngine يجب أن يعمل مع أي جدول دون معرفة نماذج EF Core مسبقاً. هذا مقصود — يجب ألا يعتمد SyncEngine على نماذج محددة.

**الوقت المقدر**: 8 ساعات (الجزء الأصعب — edge cases للتزامن والقطع)

---

#### 2.4 ربط Supabase SDK

**ملف جديد**: `ProManSystem\Services\Sync\SupabaseClientFactory.cs`

```csharp
namespace ProManSystem.Services.Sync;

public static class SupabaseClientFactory
{
    public static Supabase.Client Create()
    {
        var url = Environment.GetEnvironmentVariable("SUPABASE_URL")
            ?? throw new InvalidOperationException("SUPABASE_URL not set");

        var key = Environment.GetEnvironmentVariable("SUPABASE_ANON_KEY")
            ?? throw new InvalidOperationException("SUPABASE_ANON_KEY not set");

        var options = new Supabase.SupabaseOptions
        {
            AutoConnectRealtime = true,
            AutoRefreshToken = true
        };

        var client = new Supabase.Client(url, key, options);
        client.InitializeAsync().GetAwaiter().GetResult();
        return client;
    }
}
```

**الآن تم ربط DI**:
```csharp
services.AddSingleton(Sp => SupabaseClientFactory.Create());
services.AddSingleton<ISyncEngine, SyncEngine>();
services.AddSingleton<IConnectivityWatcher, ConnectivityWatcher>();
services.AddSingleton<IDailyPinger, DailyPinger>();
```

**الوقت المقدر**: 2 ساعة

---

### المرحلة 3 — نظام النسخ الاحتياطي

#### 3.1 BackupGuard.cs

**ملف جديد**: `ProManSystem\Services\Sync\BackupGuard.cs`

```csharp
namespace ProManSystem.Services.Sync;

public interface IBackupGuard
{
    bool IsSafeToWrite(int incomingRows, int currentRows);
    bool IsBackupSizeValid(long newSize, long previousSize);
}

public class DataIntegrityException : Exception
{
    public DataIntegrityException(string message) : base(message) { }
}

public class BackupGuard : IBackupGuard
{
    private readonly double _minSizeRatio;
    private readonly double _guardThreshold;

    public BackupGuard(double minSizeRatio = 0.70, double guardThreshold = 0.20)
    {
        _minSizeRatio = minSizeRatio;
        _guardThreshold = guardThreshold;
    }

    public bool IsSafeToWrite(int incomingRows, int currentRows)
    {
        if (incomingRows < currentRows * _guardThreshold)
            throw new DataIntegrityException(
                $"رُفض: {incomingRows} صف وارد مقابل {currentRows} موجود — خطر تصفير!");

        return true;
    }

    public bool IsBackupSizeValid(long newSize, long previousSize)
    {
        if (previousSize == 0) return true;
        return newSize >= previousSize * _minSizeRatio;
    }
}
```

**الوقت المقدر**: 2 ساعة

---

#### 3.2 ShadowCopyService.cs

**ملف جديد**: `ProManSystem\Services\Sync\ShadowCopyService.cs`

```csharp
namespace ProManSystem.Services.Sync;

public interface IShadowCopyService
{
    Task UpdateShadowAsync();
    string GetShadowPath();
}

public class ShadowCopyService : IShadowCopyService
{
    private readonly string _primaryDb;
    private readonly string _shadowDb;

    public ShadowCopyService()
    {
        _primaryDb = DatabaseMaintenanceService.GetDbPath();

        var shadowBase = Environment.GetEnvironmentVariable("SHADOW_DB_PATH")
            ?? Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "ProManSystem", "Backups");

        _shadowDb = Path.Combine(
            Path.GetDirectoryName(shadowBase)!,
            "shadow.db");
    }

    public string GetShadowPath() => _shadowDb;

    public async Task UpdateShadowAsync()
    {
        var dir = Path.GetDirectoryName(_shadowDb);
        if (!Directory.Exists(dir)) Directory.CreateDirectory(dir!);

        // WAL checkpoint أولاً للتأكد من سلامة البيانات
        using (var db = new AppDbContext())
        {
            await db.Database.ExecuteSqlRawAsync("PRAGMA wal_checkpoint(TRUNCATE)");
        }

        // استنساخ باستخدام SQLite Backup API
        using var source = new SqliteConnection($"Data Source={_primaryDb}");
        using var dest = new SqliteConnection($"Data Source={_shadowDb}");

        await source.OpenAsync();
        await dest.OpenAsync();

        source.BackupDatabase(dest);
    }
}
```

**الوقت المقدر**: 2 ساعة

---

#### 3.3 SecureBackupService.cs (AES-256-GCM)

**ملف جديد**: `ProManSystem\Services\Sync\SecureBackupService.cs`

```csharp
namespace ProManSystem.Services.Sync;

public interface ISecureBackupService
{
    Task<string> EncryptAndUploadAsync(string dbPath);
    Task<byte[]> DecryptBackupAsync(byte[] encryptedData);
    byte[] GetOrCreateSalt();
}

public class SecureBackupService : ISecureBackupService
{
    private readonly ISupabaseClient _supabase;
    private readonly IBackupGuard _backupGuard;
    private readonly string _bucket;

    public SecureBackupService(
        ISupabaseClient supabase,
        IBackupGuard backupGuard)
    {
        _supabase = supabase;
        _backupGuard = backupGuard;
        _bucket = Environment.GetEnvironmentVariable("SUPABASE_STORAGE_BUCKET")
            ?? "backups";
    }

    public byte[] GetOrCreateSalt()
    {
        // خزّن في Windows Credential Manager
        var credential = CredentialManager.ReadCredential("SyncVault_Salt");
        if (credential != null)
            return Convert.FromBase64String(credential.Password);

        var salt = RandomNumberGenerator.GetBytes(32);
        CredentialManager.WriteCredential(
            "SyncVault_Salt",
            "SyncVault",
            Convert.ToBase64String(salt));
        return salt;
    }

    private byte[] DeriveKey(string? password = null)
    {
        var salt = GetOrCreateSalt();

        // ⚠️ كلمة السر يجب أن يطلبها من المستخدم عند أول تشغيل
        // هنا نستخدم مفتاحاً مشتقاً من الـ salt فقط كإجراء افتراضي
        // يُستبدل عندما يضبط المستخدم كلمة السر في BackupManagerWindow
        var passwordBytes = password != null
            ? Encoding.UTF8.GetBytes(password)
            : salt;

        using var kdf = new Rfc2898DeriveBytes(
            passwordBytes, salt,
            iterations: 600_000,
            HashAlgorithmName.SHA256);
        return kdf.GetBytes(32);
    }

    public async Task<string> EncryptAndUploadAsync(string dbPath)
    {
        var key = DeriveKey();

        // 1. اقرأ وضغط
        var dbBytes = await File.ReadAllBytesAsync(dbPath);
        var compressed = Compress(dbBytes);

        // 2. شفّر
        using var aes = new AesGcm(key, AesGcm.TagByteSizes.MaxSize);
        var nonce = RandomNumberGenerator.GetBytes(12);
        var tag = new byte[16];
        var ciphertext = new byte[compressed.Length];

        aes.Encrypt(nonce, compressed, ciphertext, tag);

        // 3. ابنِ الملف: [nonce(12)] + [tag(16)] + [ciphertext]
        var final = new byte[12 + 16 + ciphertext.Length];
        Buffer.BlockCopy(nonce, 0, final, 0, 12);
        Buffer.BlockCopy(tag, 0, final, 12, 16);
        Buffer.BlockCopy(ciphertext, 0, final, 28, ciphertext.Length);

        // 4. تحقق من BackupGuard قبل الرفع
        var previousSize = await GetLatestBackupSizeAsync();
        if (!_backupGuard.IsBackupSizeValid(final.Length, previousSize))
            throw new DataIntegrityException("النسخة المشفرة أصغر من المتوقع — رُفض الرفع");

        // 5. ارفع
        var fileName = $"backup_{DateTime.UtcNow:yyyy-MM-dd_HH-mm}.enc";
        await _supabase.Storage
            .From(_bucket)
            .Upload(final, fileName);

        return fileName;
    }

    public async Task<byte[]> DecryptBackupAsync(byte[] encryptedData)
    {
        var key = DeriveKey();

        var nonce = new byte[12];
        var tag = new byte[16];
        var ciphertext = new byte[encryptedData.Length - 28];

        Buffer.BlockCopy(encryptedData, 0, nonce, 0, 12);
        Buffer.BlockCopy(encryptedData, 12, tag, 0, 16);
        Buffer.BlockCopy(encryptedData, 28, ciphertext, 0, ciphertext.Length);

        using var aes = new AesGcm(key, AesGcm.TagByteSizes.MaxSize);
        var decrypted = new byte[ciphertext.Length];
        aes.Decrypt(nonce, ciphertext, tag, decrypted);

        return Decompress(decrypted);
    }

    private byte[] Compress(byte[] data)
    {
        using var output = new MemoryStream();
        using var gzip = new GZipStream(output, CompressionLevel.Optimal);
        gzip.Write(data, 0, data.Length);
        gzip.Flush();
        return output.ToArray();
    }

    private byte[] Decompress(byte[] data)
    {
        using var input = new MemoryStream(data);
        using var gzip = new GZipStream(input, CompressionMode.Decompress);
        using var output = new MemoryStream();
        gzip.CopyTo(output);
        return output.ToArray();
    }

    private async Task<long> GetLatestBackupSizeAsync()
    {
        try
        {
            var files = await _supabase.Storage
                .From(_bucket)
                .List();
            return files?.FirstOrDefault()?.Size ?? 0;
        }
        catch { return 0; }
    }
}
```

**⚠️ تحذير هام**: `CredentialManager.ReadCredential` و `WriteCredential` تستخدمان P/Invoke إلى `advapi32.dll`. تحتاج إلى إنشاء `NativeMethods.cs`:

```csharp
// ProManSystem\Services\Sync\CredentialManager.cs
[DllImport("advapi32.dll", EntryPoint = "CredReadW", CharSet = CharSet.Unicode, SetLastError = true)]
private static extern bool CredRead(string target, CredentialType type, int flags,
    out IntPtr credentialPtr);
```

**الوقت المقدر**: 6 ساعات (التشفير + Credential Manager + اختبار)

---

#### 3.4 BackupRotationService.cs

**ملف جديد**: `ProManSystem\Services\Sync\BackupRotationService.cs`

```csharp
namespace ProManSystem.Services.Sync;

public interface IBackupRotationService
{
    Task RotateIfSafeAsync(string newBackupPath);
    Task<int> GetBackupCountAsync();
}

public class BackupRotationService : IBackupRotationService
{
    private readonly ISupabaseClient _supabase;
    private readonly string _bucket;
    private readonly int _retentionCount;
    private long _lastKnownRowCount;

    public BackupRotationService(ISupabaseClient supabase)
    {
        _supabase = supabase;
        _bucket = Environment.GetEnvironmentVariable("SUPABASE_STORAGE_BUCKET")
            ?? "backups";
        _retentionCount = int.Parse(
            Environment.GetEnvironmentVariable("BACKUP_RETENTION_COUNT") ?? "30");
    }

    public async Task RotateIfSafeAsync(string newBackupPath)
    {
        // 1. تحقق من سلامة النسخة الجديدة
        if (!await IsBackupValidAsync(newBackupPath))
            throw new DataIntegrityException(
                "النسخة الجديدة فاسدة أو ناقصة — لن أحذف القديمة!");

        // 2. فقط بعد التحقق — احذف الأقدم
        await DeleteOldestIfNeededAsync();
    }

    public async Task<int> GetBackupCountAsync()
    {
        var files = await _supabase.Storage.From(_bucket).List();
        return files?.Count ?? 0;
    }

    private async Task<bool> IsBackupValidAsync(string path)
    {
        try
        {
            // حمّل النسخة المشفرة مؤقتاً
            var encrypted = await _supabase.Storage
                .From(_bucket)
                .Download(path, null);

            // فك التشفير (بسيط — فقط تحقق من الحجم)
            // في الإصدار النهائي: فك تشفير كامل وفتح SQLite
            return encrypted.Length > 0;
        }
        catch
        {
            return false;
        }
    }

    private async Task DeleteOldestIfNeededAsync()
    {
        var files = await _supabase.Storage.From(_bucket).List();
        if (files == null || files.Count <= _retentionCount) return;

        // احذف الأقدم (أبجدياً — لأن الاسم يحتوي التاريخ)
        var oldest = files.OrderBy(f => f.Name).First();
        await _supabase.Storage.From(_bucket).Remove(new[] { oldest.Name });
    }
}
```

**الوقت المقدر**: 3 ساعات

---

#### 3.5 DisasterRecoveryService.cs

**ملف جديد**: `ProManSystem\Services\Sync\DisasterRecoveryService.cs`

```csharp
namespace ProManSystem.Services.Sync;

public enum DisasterType { CorruptedDb, DriveFailure, TotalLoss }

public interface IDisasterRecoveryService
{
    Task<bool> RecoverAsync(DisasterType type);
    Task<bool> ValidateRestoredDataAsync();
}

public class DisasterRecoveryService : IDisasterRecoveryService
{
    private readonly IShadowCopyService _shadowCopy;
    private readonly ISecureBackupService _backup;
    private readonly IDbContextFactory<AppDbContext> _dbFactory;

    public async Task<bool> RecoverAsync(DisasterType type)
    {
        switch (type)
        {
            case DisasterType.CorruptedDb:
                var shadowPath = _shadowCopy.GetShadowPath();
                if (!File.Exists(shadowPath)) return false;
                File.Copy(shadowPath, DatabaseMaintenanceService.GetDbPath(), overwrite: true);
                break;

            case DisasterType.DriveFailure:
                // تحميل من Supabase وفك تشفير
                // (يحتاج اتصال إنترنت)
                var latestEnc = await DownloadLatestBackupAsync();
                if (latestEnc == null) return false;
                var decrypted = await _backup.DecryptBackupAsync(latestEnc);
                await File.WriteAllBytesAsync(DatabaseMaintenanceService.GetDbPath(), decrypted);
                break;

            case DisasterType.TotalLoss:
                // محاولة الاستعادة من Google Drive
                // (تُنفذ لاحقاً في المرحلة 6)
                return false;
        }

        DatabaseMaintenanceService.ClearConnectionPool();
        return await ValidateRestoredDataAsync();
    }

    public async Task<bool> ValidateRestoredDataAsync()
    {
        using var db = await _dbFactory.CreateDbContextAsync();
        var count = await db.Companies.CountAsync();
        return count > 0;
    }
}
```

**الوقت المقدر**: 3 ساعات

---

### المرحلة 4 — تكامل واجهة المستخدم

#### 4.1 CloseConfirmWindow.xaml

**ملف جديد**: `ProManSystem\Views\CloseConfirmWindow.xaml`

نافذة تظهر عند إغلاق التطبيق:
- ~~عرض~~: آخر نسخة (متى كانت؟)
- ~~شريط تقدم~~: "جارٍ حفظ النسخة..."
- ~~زر~~: [احفظ نسخة وأغلق]
- ~~زر~~: [أغلق بدون حفظ]
- ~~رابط~~: "عرض سجل النسخ" يفتح BackupManagerWindow

**وقت التقدير**: 2 ساعة

#### 4.2 BackupManagerWindow.xaml

**ملف جديد**: `ProManSystem\Views\BackupManagerWindow.xaml`

نافذة إدارة النسخ محلياً:
- ~~جدول النسخ المحلية~~ (التاريخ، الحجم، الحالة)
- ~~جدول النسخ السحابية~~ (إن توفر اتصال)
- ~~زر~~: [احفظ نسخة الآن]
- ~~زر~~: [استعادة نسخة...]
- ~~إعدادات~~: عدد النسخ للاحتفاظ، التشفير، كلمة السر
- ~~حالة~~: آخر مزامنة، عدد الصفوف المعلقة

**وقت التقدير**: 4 ساعات

#### 4.3 StatusBar Component (أسفل HomeWindow)

**ملف معدّل**: `HomeWindow.xaml`
- أضف شريط حالة أسفل النافذة:
  - 🟢/🔴 حالة الاتصال
  - ⬆️ عدد الصفوف المعلقة للمزامنة
  - 💾 آخر نسخة احتياطية (منذ كم)
  - نقر على الأيقونة يفتح BackupManagerWindow

**وقت التقدير**: 2 ساعة

---

### المرحلة 5 — لوحة تحكم الويب (اختيارية)

#### 5.1 هيكل مشروع Next.js

```
SyncVault-dashboard/
├── package.json
├── next.config.js
├── tailwind.config.ts
├── app/
│   ├── layout.tsx           # Shell مع Supabase Realtime
│   ├── page.tsx             # البطاقات العلوية
│   ├── backups/
│   │   └── page.tsx         # جدول النسخ الاحتياطية
│   └── logs/
│       └── page.tsx         # سجل العمليات
├── components/
│   ├── StatusCard.tsx
│   ├── BackupTable.tsx
│   ├── LogsTable.tsx
│   └── HealthIndicator.tsx
└── lib/
    └── supabase.ts
```

#### 5.2 جداول Supabase (SQL جاهز)

```sql
-- شغّل هذا في SQL Editor بلوحة Supabase

-- جدول النسخ الاحتياطية
CREATE TABLE backups (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at  TIMESTAMPTZ DEFAULT now(),
    file_path   TEXT NOT NULL,
    file_size   BIGINT,
    source      TEXT,              -- 'auto' | 'manual' | 'on_close'
    status      TEXT DEFAULT 'ok',
    error_msg   TEXT,
    device_id   TEXT
);

-- سجل العمليات
CREATE TABLE sync_logs (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at  TIMESTAMPTZ DEFAULT now(),
    type        TEXT,              -- 'sync' | 'backup' | 'restore' | 'ping'
    device_id   TEXT,
    details     JSONB,
    success     BOOLEAN DEFAULT true,
    error_msg   TEXT
);

-- الأجهزة
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

-- ⚠️ مهم: تفعيل RLS
ALTER TABLE backups ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE ping_logs ENABLE ROW LEVEL SECURITY;

-- سياسات RLS — المستخدم يرى بياناته فقط
CREATE POLICY "Users see own data" ON backups
    FOR ALL USING (auth.uid() = device_id::uuid);

CREATE POLICY "Users see own logs" ON sync_logs
    FOR ALL USING (auth.uid() = device_id::uuid);
```

#### 5.3 نشر Vercel

```bash
npx create-next-app@latest syncvault-dashboard --typescript --tailwind --app
cd syncvault-dashboard
npm install @supabase/supabase-js @tanstack/react-table recharts
# ... كتابة الصفحات ...
npx vercel --prod
```

**الوقت المقدر**: 8-10 ساعات للوحة كاملة، أو 4 ساعات للنسخة الأساسية

---

### المرحلة 6 — التحصين

#### 6.1 Conflict Resolver محسّن

**ملف معدّل**: `SyncEngine.cs` — أضف:
- `DeviceId` لكل صف في `pending_sync`
- مقارنة `device_id` عند التعارض
- `ConflictLog` table لتسجيل التعارضات
- `AskUser(...)` dialog للتعارضات المتزامنة

**الوقت المقدر**: 4 ساعات

#### 6.2 Salt Backup Strategy

**ملف جديد**: `ProManSystem\Services\Sync\SaltManager.cs`

```csharp
public class SaltManager
{
    // خيار 1: تصدير QR Code عند الإعداد
    public void ExportSaltAsQr(byte[] salt) { ... }

    // خيار 2: حفظ في Windows Credential Manager
    // (مُنفذ في SecureBackupService)

    // خيار 3: ملف recovery مشفر
    public void ExportRecoveryFile(byte[] salt, string password) { ... }
}
```

**الوقت المقدر**: 2 ساعة

#### 6.3 Immutable Backups على Supabase

**على لوحة Supabase**:
1. إنشاء bucket جديد `immutable-backups`
2. تعيين سياسة: `DELETE = ممنوع للجميع`
3. رفع نسخة أسبوعية مشفرة

**الوقت المقدر**: 1 ساعة

#### 6.4 GitHub Actions Workflow

**ملف جديد**: `SyncVault\.github\workflows\keep-alive.yml`

```yaml
name: Keep Supabase Alive
on:
  schedule:
    - cron: '0 8 * * *'  # يومياً 8 صباحاً

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

**الوقت المقدر**: 0.5 ساعة

---

## القسم 5 — قائمة إعداد Supabase

- [ ] أنشئ مشروع Supabase جديد من https://supabase.com/dashboard
- [ ] انسخ `SUPABASE_URL` و `SUPABASE_ANON_KEY` إلى `.env`
- [ ] افتح SQL Editor ونفّذ SQL لإنشاء 4 جداول (من القسم 5.2)
- [ ] فعّل RLS على كل الجداول الأربعة
- [ ] أنشئ Storage bucket باسم `backups`
- [ ] أنشئ Storage bucket باسم `immutable-backups`
- [ ] اجعل `immutable-backups` للقراءة فقط (سياسة DELETE = ممنوع)
- [ ] انسخ مفاتيح Supabase إلى `.env` في مجلد SyncVault
- [ ] اختبر الاتصال: `curl $SUPABASE_URL/rest/v1/ping_logs -H "apikey: $SUPABASE_ANON_KEY"`

---

## القسم 6 — سجل المخاطر

| المخاطرة | الشدة | الاحتمال | خطة التخفيف |
|----------|-------|----------|-------------|
| **كسر النوافذ الحالية عند إدخال DI** | 🔴 عالية | 90% | البدء بـ 3 نوافذ فقط كتجربة، ثم التوسع تدريجياً. الاحتفاظ بـ `new AppDbContext()` كخيار تراجعي. |
| **SQLite Triggers تتعارض مع EF Core** | 🔴 عالية | 60% | Triggers على مستوى SQLite فقط لا يراها EF Core مباشرة. اختبار شامل بعد كل Trigger. تعطيل triggers مؤقتاً أثناء الـ migration. |
| **فقدان البيانات أثناء أول مزامنة** | 🔴 عالية | 30% | BackupGuard يمنع الكتابة إن كانت البيانات أقل من 20%. إنشاء نسخة يدوية قبل تشغيل أول مزامنة. |
| **مفتاح التشفير (salt) يضيع مع القرص** | 🟡 متوسطة | 40% | SaltManager مع 3 استراتيجيات: QR Code، Windows Credential، Recovery File. طباعة QR عند الإعداد الأول. |
| **تضارب Supabase C# SDK مع EF Core** | 🟡 متوسطة | 40% | الـ SDK يستخدم HTTP مباشرة، وEF Core يستخدم SQLite مباشرة — لا تداخل. لكن قد يكون هناك تعارض في إصدارات `System.Text.Json`. |
| **توقف Supabase المجاني عن العمل** | 🟢 منخفضة | 20% | DailyPinger + GitHub Actions يمنعان الإيقاف. إن توقف، البيانات محفوظة محلياً كاملة. |
| **مسارات صلبة الترميز تكسر التطبيق** | 🔴 عالية | 100% (موجودة فعلاً) | استبدال `C:\WalidFacture\` بمتغير بيئة `PDF_EXPORT_PATH`. لكن هذا خارج نطاق SyncVault. |
| **تزامن ساعات الأجهزة المختلفة** | 🟡 متوسطة | 50% | Conflict Resolver مع `device_id` يحل معظم الحالات. تحذير المستخدم إن كان فرق التوقيت > 5 دقائق. |
| **حجم قاعدة البيانات يتجاوز 500 MB (الحد المجاني)** | 🟢 منخفضة | 15% | قاعدة بيانات تطبيق واحد نادراً تتجاوز 100 MB. الضغط + التشفير لا يزيدان الحجم كثيراً. |
| **عدم وجود نظام مستخدمين في ProManSystem** | 🟡 متوسطة | 100% (غياب كامل) | SyncVault يستخدم `DEVICE_ID` وليس `USER_ID`. لكن إن أريد متعدد المستخدمين لاحقاً، سيكون refactor كبير. |

---

## القسم 7 — الجدول الزمني

| الأسبوع | المرحلة | التسليمات |
|---------|---------|-----------|
| **الأسبوع 1** | الأساس | DI Container، واجهات الخدمات، أعمدة `updated_at` + `is_deleted`، جدول `pending_sync`، SQLite Triggers، WAL Mode |
| **الأسبوع 2** | محرك المزامنة | ConnectivityWatcher، DailyPinger، SyncEngine، SupabaseClient، أول مزامنة ناجحة |
| **الأسبوع 3** | نظام النسخ الاحتياطي | BackupGuard، ShadowCopyService، SecureBackupService (AES-256)، BackupRotationService، DisasterRecoveryService |
| **الأسبوع 4** | تكامل واجهة المستخدم | CloseConfirmWindow، BackupManagerWindow، شريط الحالة، ربط الأحداث |
| **الأسبوع 5** | لوحة الويب (اختياري) | Next.js Dashboard، Supabase tables، Vercel Deployment |
| **الأسبوع 6** | تحصين واختبار | Conflict Resolver محسّن، Salt Backup، Immutable Backups، GitHub Actions، اختبار كامل شامل |

**الساعات الإجمالية المقدرة**: 45-55 ساعة عمل فعلية

---

## القسم 8 — أسئلة مفتوحة تحتاج قراراً من المطور

1. **هل نستخدم DI Container كاملاً (Microsoft.Extensions.DependencyInjection) أم نبدأ تدريجياً ببعض الخدمات فقط؟**
   - توصية: تدريجي — نبدأ بـ 5 خدمات جديدة فقط في المرحلة الأولى.

2. **هل نضيف `is_deleted` بنمط soft-delete لكل الجداول أم للجداول الرئيسية فقط؟**
   - توصية: كل الجداول الـ 13 التي لها `CompanyId`. جداول مثل `Units` و `TvaRates` لا تحتاج.

3. **كيف نتعامل مع المسار الصلب `C:\WalidFacture\Factures\`؟**
   - توصية: متغير بيئة `PDF_EXPORT_PATH` مع قيمة افتراضية للمسار القديم. يُنقل إلى الإعدادات في مرحلة لاحقة.

4. **هل يحتاج المستخدم كلمة سر للتشفير AES-256 أم نستخدم مفتاحاً مشتقاً من الجهاز فقط؟**
   - توصية: نبدأ بمفتاح مشتق من الـ salt فقط (بدون كلمة سر). نضيف كلمة سر اختيارية لاحقاً في BackupManagerWindow.

5. **هل نبني لوحة الويب (Next.js) الآن أم نؤجلها؟**
   - توصية: **نؤجل**. نافذة BackupManagerWindow المحلية كافية. لوحة الويب تضيف 8-10 ساعات. تُضاف فقط إن احتاجها المستخدم فعلاً.

6. **Google Drive كطبقة ثالثة — هل هو ضروري؟**
   - توصية: نؤجل أيضاً. نظام 2-1 (محلي + Supabase) كافٍ حالياً. تُضاف Google Drive في المرحلة 6+.

7. **هل نعدّل `SalesInvoiceSyncService` ليكون جزءاً من `SyncEngine` الجديد أم نبقيه منفصلاً؟**
   - توصية: نبقيه منفصلاً. مزامنة PDF لها منطق مختلف تماماً عن مزامنة قاعدة البيانات. دمجها سيعقد الكود.

8. **كيف نتعامل مع `FixOldDataAutomatically()` — هل نستبدله بـ EF Core Migrations؟**
   - توصية: نبقيه كما هو للمرحلة الأولى. استبداله بـ Migrations سليم هو مشروع منفصل يحتاج 4-6 ساعات.

9. **هل نضيف `device_id` كعمود فعلي في كل جدول أم نكتفي بـ `pending_sync`؟**
   - توصية: نكتفي بـ `pending_sync` فقط. إضافته لكل الجداول يعقد النماذج والواجهات دون فائدة للمستخدم الواحد.

10. **ماذا عن `CompanyId` في المزامنة — هل نزامن كل شركة على حدة؟**
    - توصية: نزامن كل شيء مرة واحدة. `CompanyId` موجود في كل صف. Supabase ستخزنه كمفتاح أجنبي منطقي.

---

## ملحق — NuGet Packages الجديدة المطلوبة

| الحزمة | الغرض | الإصدار |
|--------|-------|---------|
| `Microsoft.Extensions.Hosting` | DI Container + Host Builder | 8.0.0 |
| `supabase-csharp` | Supabase Client SDK | أحدث إصدار |
| `Microsoft.Data.Sqlite` | SQLite Backup API (موجودة مسبقاً) | — |

**حزم يمكن إزالتها** (تحسين للنظام):
- `itext7` — غير مستخدم
- `iTextSharp.LGPLv2.Core` — غير مستخدم
- `QuestPDF` — غير مستخدم
- `PdfSharpCore` — مكرر مع `PDFsharp-MigraDoc-GDI`

---

## ملحق — جدول مقارنة: ما يُعاد استخدامه وما يُبنى من الصفر

### يُعاد استخدامه (موجود في ProManSystem)

| الموجود | يطابق في SyncVault | التعديل المطلوب |
|---------|-------------------|-----------------|
| `DatabaseMaintenanceService.GetDbPath()` | `LOCAL_DB_PATH` | أضف متغير بيئة |
| `DatabaseMaintenanceService.RunWalCheckpoint()` | WAL Mode | موجود فعلاً ✅ |
| `DatabaseMaintenanceService.CreateAutoBackup()` | ShadowCopy | مدد لنسخ إلى مجلدين |
| `DatabaseMaintenanceService.BackupDatabase()` | Backup Engine | أضف GZip |
| `DatabaseMaintenanceService.ReplaceDatabase()` | Recovery | أضف فك تشفير |
| `SalesInvoiceSyncService` (نمط المزامنة) | SyncEngine | مختلف — هذا PDF فقط |
| `CurrentCompanyService.Instance` | Multi-tenant Context | حوّل إلى DI |
| `NotificationService` | تنبيهات المستخدم | موجود فعلاً ✅ |
| `AppDbContext` + 20 DbSet | كل الجداول | أضف updated_at, is_deleted |
| `AgentLogger` | سجل الأخطاء | موجود فعلاً ✅ |

### يُبنى من الصفر (ملفات جديدة تماماً)

| الملف الجديد | المسؤولية | الساعات |
|-------------|-----------|---------|
| `ServiceCollectionExtensions.cs` | تسجيل جميع الخدمات في DI | 2 |
| `AppHost.cs` | Host Builder entry point | 1 |
| `ICurrentCompanyService.cs` | واجهة للخدمة الموجودة | 0.5 |
| `IDatabaseMaintenanceService.cs` | واجهة للخدمة الموجودة | 0.5 |
| `ConnectivityWatcher.cs` | كشف الاتصال بالإنترنت | 1.5 |
| `DailyPinger.cs` | إبقاء Supabase حياً | 1.5 |
| `SyncEngine.cs` | محرك المزامنة الرئيسي | 8 |
| `SupabaseClientFactory.cs` | إنشاء عميل Supabase | 1 |
| `BackupGuard.cs` | حماية من التصفير | 2 |
| `ShadowCopyService.cs` | نسخة محلية على قرص آخر | 2 |
| `SecureBackupService.cs` | تشفير AES-256-GCM | 6 |
| `BackupRotationService.cs` | تدوير النسخ بذكاء | 3 |
| `DisasterRecoveryService.cs` | استعادة من الكوارث | 3 |
| `CredentialManager.cs` | Windows Credential Manager P/Invoke | 1.5 |
| `SaltManager.cs` | إدارة ملح التشفير | 2 |
| `CloseConfirmWindow.xaml/.cs` | نافذة سؤال النسخ عند الإغلاق | 2 |
| `BackupManagerWindow.xaml/.cs` | واجهة إدارة النسخ | 4 |
| `sync_schema.sql` | تعديلات مخطط SQLite | 1 |
| `sync_triggers.sql` | مشغلات تتبع التغييرات | 2 |
| `keep-alive.yml` | GitHub Actions workflow | 0.5 |

---

## ملحق — خريطة التعارضات المعمارية

| التعارض | الوصف | الحل |
|---------|-------|------|
| **نمط الإنشاء المباشر vs DI** | كل نافذة تنشئ `new AppDbContext()` — هذا يناقض فكرة DI | نضيف `IDbContextFactory<AppDbContext>` في DI. النوافذ تطلبها عبر `AppHost.GetService<T>()` |
| **Static services vs Injectable** | `DatabaseMaintenanceService` static — لا يمكن حقنها | نحوّلها إلى instance مع واجهة `IDatabaseMaintenanceService` |
| **Singleton DbContext vs Scoped** | كل نافذة لها DbContext خاص — هذا صحيح. لكن `SyncEngine` يحتاج DbContext منفصل | نستخدم `IDbContextFactory<AppDbContext>` بدل `IServiceProvider` المباشر |
| **NoTracking vs المزامنة** | `QueryTrackingBehavior.NoTracking` عالمي — التعديلات تحتاج `AsTracking()` صريح | لا تعارض — المزامنة تقرأ فقط، لا تعدل مباشرة |
| **CompanyId في triggers** | Trigger يحتاج CompanyId لكنه لا يملك سياق EF Core | `NEW.CompanyId` موجود في الصف نفسه — لا مشكلة |
| **مسار PDF صلب** | `C:\WalidFacture\Factures\` مقسى في 3 خدمات | ليس نطاق SyncVault — لكن يُنصح بإصلاحه قبل المزامنة |
| **اسم الشركة مقسى** | `InvoicePdfService` يكتب "بروكو سيستم" | ليس نطاق SyncVault — لكنه سيُنتج فواتير خاطئة عند المزامنة |

---


## المرحلة 5 — لوحة تحكم الويب (بالتزامن مع واجهة WPF)

### المبدأ الأساسي

لوحة الويب ليست بديلاً عن BackupManagerWindow — هي **نفس البيانات، نفس العرض**، لكن من أي متصفح وأي جهاز.
كلاهما يقرآن من Supabase مباشرة — لا مزامنة إضافية مطلوبة.
WPF BackupManagerWindow ──┐

├──► Supabase (مصدر الحقيقة الوحيد) ◄── لوحة الويب

تطبيق WPF (SyncEngine) ───┘

---

### 5.1 ما تعرضه لوحة الويب (مطابق لـ WPF تماماً)

| القسم في WPF | المقابل في الويب |
|---|---|
| بطاقة "آخر نسخة" | StatusCard — نفس التاريخ والحجم |
| جدول النسخ المحلية + السحابية | BackupTable — نفس السجلات من جدول `backups` |
| عدد الصفوف المعلقة | SyncStatusCard — من جدول `sync_logs` |
| حالة الاتصال 🟢/🔴 | HealthIndicator — من جدول `devices` |
| سجل العمليات | LogsTable — من جدول `sync_logs` |
| مؤشر الأمان | SecurityBadge — أخضر/أصفر/أحمر |

---

### 5.2 هيكل المشروع الكامل
syncvault-dashboard/

├── .env.local                        ← مفاتيح Supabase

├── package.json

├── next.config.ts

├── tailwind.config.ts

│

├── app/

│   ├── layout.tsx                    ← Shell + Supabase Realtime provider

│   ├── page.tsx                      ← الصفحة الرئيسية (البطاقات العلوية)

│   ├── backups/

│   │   └── page.tsx                  ← جدول النسخ الاحتياطية

│   └── logs/

│       └── page.tsx                  ← سجل العمليات الكامل

│

├── components/

│   ├── StatusCard.tsx                ← بطاقة إحصائية واحدة

│   ├── SecurityBadge.tsx             ← مؤشر 🟢🟡🔴

│   ├── BackupTable.tsx               ← جدول النسخ مع أزرار

│   ├── LogsTable.tsx                 ← جدول العمليات

│   ├── SyncStatusCard.tsx            ← حالة المزامنة الحية

│   └── DeviceCard.tsx                ← بطاقة الجهاز + آخر ظهور

│

└── lib/

├── supabase.ts                   ← إنشاء Supabase client

└── types.ts                      ← أنواع TypeScript للجداول

---

### 5.3 ملف `.env.local`

```env
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key-here
```

---

### 5.4 الملفات الأساسية

#### `lib/supabase.ts`
```typescript
import { createClient } from '@supabase/supabase-js'

export const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
)
```

#### `lib/types.ts`
```typescript
export type Backup = {
  id: string
  created_at: string
  file_path: string
  file_size: number
  source: 'auto' | 'manual' | 'on_close'
  status: 'ok' | 'failed' | 'pending'
  error_msg: string | null
  device_id: string
}

export type SyncLog = {
  id: string
  created_at: string
  type: 'sync' | 'backup' | 'restore' | 'ping'
  device_id: string
  details: Record<string, unknown>
  success: boolean
  error_msg: string | null
}

export type Device = {
  id: string
  name: string
  last_seen: string
  last_sync: string
}
```

---

#### `app/layout.tsx` — الـ Shell مع Realtime
```typescript
import { supabase } from '@/lib/supabase'

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="ar" dir="rtl">
      <body className="bg-gray-950 text-gray-100 min-h-screen">
        <nav className="border-b border-gray-800 px-6 py-4 flex items-center gap-6">
          <span className="font-bold text-lg">🔄 SyncVault</span>
          <a href="/" className="text-gray-400 hover:text-white text-sm">الرئيسية</a>
          <a href="/backups" className="text-gray-400 hover:text-white text-sm">النسخ الاحتياطية</a>
          <a href="/logs" className="text-gray-400 hover:text-white text-sm">سجل العمليات</a>
        </nav>
        <main className="p-6">{children}</main>
      </body>
    </html>
  )
}
```

---

#### `app/page.tsx` — الصفحة الرئيسية
```typescript
import { supabase } from '@/lib/supabase'
import StatusCard from '@/components/StatusCard'
import SecurityBadge from '@/components/SecurityBadge'
import DeviceCard from '@/components/DeviceCard'
import SyncStatusCard from '@/components/SyncStatusCard'

export default async function HomePage() {
  // جلب البيانات من Supabase مباشرة
  const { data: backups } = await supabase
    .from('backups')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(1)

  const { count: totalBackups } = await supabase
    .from('backups')
    .select('*', { count: 'exact', head: true })

  const { count: failedOps } = await supabase
    .from('sync_logs')
    .select('*', { count: 'exact', head: true })
    .eq('success', false)

  const { data: devices } = await supabase
    .from('devices')
    .select('*')
    .order('last_seen', { ascending: false })

  const lastBackup = backups?.[0] ?? null
  const lastBackupDate = lastBackup
    ? new Date(lastBackup.created_at)
    : null

  // حساب مؤشر الأمان
  const daysSinceBackup = lastBackupDate
    ? Math.floor((Date.now() - lastBackupDate.getTime()) / 86400000)
    : 999

  const securityLevel =
    daysSinceBackup < 2 ? 'green' :
    daysSinceBackup < 7 ? 'yellow' : 'red'

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">لوحة التحكم</h1>
        <SecurityBadge level={securityLevel} daysSince={daysSinceBackup} />
      </div>

      {/* البطاقات العلوية — نفس WPF تماماً */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <StatusCard
          title="إجمالي النسخ"
          value={totalBackups ?? 0}
          icon="💾"
        />
        <StatusCard
          title="آخر نسخة ناجحة"
          value={lastBackupDate
            ? `منذ ${daysSinceBackup} يوم`
            : 'لا توجد'}
          icon="✅"
        />
        <StatusCard
          title="عمليات فاشلة"
          value={failedOps ?? 0}
          icon="⚠️"
          highlight={failedOps! > 0}
        />
        <StatusCard
          title="مساحة مستخدمة"
          value={formatBytes(
            backups?.reduce((sum, b) => sum + (b.file_size ?? 0), 0) ?? 0
          )}
          icon="📦"
        />
      </div>

      {/* الأجهزة */}
      <div>
        <h2 className="text-lg font-semibold mb-3">الأجهزة المتصلة</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {devices?.map(device => (
            <DeviceCard key={device.id} device={device} />
          ))}
        </div>
      </div>

      {/* آخر 5 عمليات */}
      <SyncStatusCard />
    </div>
  )
}

function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
  return `${(bytes / 1024 / 1024).toFixed(1)} MB`
}
```

---

#### `app/backups/page.tsx` — جدول النسخ
```typescript
import { supabase } from '@/lib/supabase'
import BackupTable from '@/components/BackupTable'

export default async function BackupsPage() {
  const { data: backups } = await supabase
    .from('backups')
    .select('*')
    .order('created_at', { ascending: false })

  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-bold">النسخ الاحتياطية</h1>
      <BackupTable backups={backups ?? []} />
    </div>
  )
}
```

---

#### `app/logs/page.tsx` — سجل العمليات
```typescript
import { supabase } from '@/lib/supabase'
import LogsTable from '@/components/LogsTable'

export default async function LogsPage() {
  const { data: logs } = await supabase
    .from('sync_logs')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(100)

  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-bold">سجل العمليات</h1>
      <LogsTable logs={logs ?? []} />
    </div>
  )
}
```

---

#### `components/StatusCard.tsx`
```typescript
export default function StatusCard({
  title, value, icon, highlight = false
}: {
  title: string
  value: string | number
  icon: string
  highlight?: boolean
}) {
  return (
    <div className={`rounded-xl border p-4 space-y-1
      ${highlight
        ? 'border-red-500 bg-red-950'
        : 'border-gray-800 bg-gray-900'}`}>
      <div className="text-2xl">{icon}</div>
      <div className="text-2xl font-bold">{value}</div>
      <div className="text-sm text-gray-400">{title}</div>
    </div>
  )
}
```

---

#### `components/SecurityBadge.tsx`
```typescript
export default function SecurityBadge({
  level, daysSince
}: {
  level: 'green' | 'yellow' | 'red'
  daysSince: number
}) {
  const config = {
    green: { bg: 'bg-green-900', text: 'text-green-400',
             dot: 'bg-green-400', label: 'آمن' },
    yellow: { bg: 'bg-yellow-900', text: 'text-yellow-400',
              dot: 'bg-yellow-400', label: 'تنبيه' },
    red: { bg: 'bg-red-900', text: 'text-red-400',
           dot: 'bg-red-400', label: 'خطر' },
  }[level]

  return (
    <div className={`flex items-center gap-2 px-4 py-2 rounded-full ${config.bg}`}>
      <span className={`w-2 h-2 rounded-full ${config.dot} animate-pulse`} />
      <span className={`text-sm font-medium ${config.text}`}>
        {config.label} — آخر نسخة منذ {daysSince} يوم
      </span>
    </div>
  )
}
```

---

#### `components/BackupTable.tsx`
```typescript
import type { Backup } from '@/lib/types'

export default function BackupTable({ backups }: { backups: Backup[] }) {
  return (
    <div className="rounded-xl border border-gray-800 overflow-hidden">
      <table className="w-full text-sm">
        <thead className="bg-gray-900 text-gray-400">
          <tr>
            <th className="px-4 py-3 text-right">التاريخ</th>
            <th className="px-4 py-3 text-right">الحجم</th>
            <th className="px-4 py-3 text-right">المصدر</th>
            <th className="px-4 py-3 text-right">الجهاز</th>
            <th className="px-4 py-3 text-right">الحالة</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-gray-800">
          {backups.map(b => (
            <tr key={b.id} className="bg-gray-950 hover:bg-gray-900 transition">
              <td className="px-4 py-3">
                {new Date(b.created_at).toLocaleString('ar-DZ')}
              </td>
              <td className="px-4 py-3 text-gray-400">
                {(b.file_size / 1024 / 1024).toFixed(2)} MB
              </td>
              <td className="px-4 py-3">
                <SourceBadge source={b.source} />
              </td>
              <td className="px-4 py-3 text-gray-400 font-mono text-xs">
                {b.device_id}
              </td>
              <td className="px-4 py-3">
                {b.status === 'ok'
                  ? <span className="text-green-400">✓ ناجحة</span>
                  : <span className="text-red-400">✗ فاشلة</span>}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

function SourceBadge({ source }: { source: string }) {
  const labels: Record<string, string> = {
    auto: 'تلقائي',
    manual: 'يدوي',
    on_close: 'عند الإغلاق',
  }
  return (
    <span className="px-2 py-1 rounded text-xs bg-gray-800 text-gray-300">
      {labels[source] ?? source}
    </span>
  )
}
```

---

#### `components/LogsTable.tsx`
```typescript
import type { SyncLog } from '@/lib/types'

export default function LogsTable({ logs }: { logs: SyncLog[] }) {
  return (
    <div className="rounded-xl border border-gray-800 overflow-hidden">
      <table className="w-full text-sm">
        <thead className="bg-gray-900 text-gray-400">
          <tr>
            <th className="px-4 py-3 text-right">الوقت</th>
            <th className="px-4 py-3 text-right">النوع</th>
            <th className="px-4 py-3 text-right">الجهاز</th>
            <th className="px-4 py-3 text-right">التفاصيل</th>
            <th className="px-4 py-3 text-right">النتيجة</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-gray-800">
          {logs.map(log => (
            <tr key={log.id} className="bg-gray-950 hover:bg-gray-900 transition">
              <td className="px-4 py-3 text-gray-400 text-xs">
                {new Date(log.created_at).toLocaleString('ar-DZ')}
              </td>
              <td className="px-4 py-3">
                <TypeBadge type={log.type} />
              </td>
              <td className="px-4 py-3 font-mono text-xs text-gray-400">
                {log.device_id ?? '—'}
              </td>
              <td className="px-4 py-3 text-gray-300 text-xs">
                {JSON.stringify(log.details ?? {})}
              </td>
              <td className="px-4 py-3">
                {log.success
                  ? <span className="text-green-400">✓ نجح</span>
                  : <span className="text-red-400">✗ فشل</span>}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

function TypeBadge({ type }: { type: string }) {
  const colors: Record<string, string> = {
    sync: 'bg-blue-900 text-blue-300',
    backup: 'bg-purple-900 text-purple-300',
    restore: 'bg-orange-900 text-orange-300',
    ping: 'bg-gray-800 text-gray-400',
  }
  const labels: Record<string, string> = {
    sync: 'مزامنة',
    backup: 'نسخ',
    restore: 'استعادة',
    ping: 'ping',
  }
  return (
    <span className={`px-2 py-1 rounded text-xs ${colors[type] ?? 'bg-gray-800'}`}>
      {labels[type] ?? type}
    </span>
  )
}
```

---

#### `components/DeviceCard.tsx`
```typescript
import type { Device } from '@/lib/types'

export default function DeviceCard({ device }: { device: Device }) {
  const lastSeen = new Date(device.last_seen)
  const minutesAgo = Math.floor((Date.now() - lastSeen.getTime()) / 60000)
  const isOnline = minutesAgo < 5

  return (
    <div className="rounded-xl border border-gray-800 bg-gray-900 p-4">
      <div className="flex items-center gap-3">
        <span className={`w-3 h-3 rounded-full
          ${isOnline ? 'bg-green-400' : 'bg-gray-600'}`} />
        <div>
          <div className="font-medium">{device.name}</div>
          <div className="text-xs text-gray-500 font-mono">{device.id}</div>
        </div>
      </div>
      <div className="mt-3 grid grid-cols-2 gap-2 text-xs text-gray-400">
        <div>
          <div>آخر ظهور</div>
          <div className="text-gray-300">
            {minutesAgo < 60
              ? `منذ ${minutesAgo} دقيقة`
              : lastSeen.toLocaleString('ar-DZ')}
          </div>
        </div>
        <div>
          <div>آخر مزامنة</div>
          <div className="text-gray-300">
            {device.last_sync
              ? new Date(device.last_sync).toLocaleString('ar-DZ')
              : '—'}
          </div>
        </div>
      </div>
    </div>
  )
}
```

---

#### `components/SyncStatusCard.tsx` — مع Realtime
```typescript
'use client'

import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'
import type { SyncLog } from '@/lib/types'

export default function SyncStatusCard() {
  const [logs, setLogs] = useState<SyncLog[]>([])

  useEffect(() => {
    // جلب أول مرة
    supabase
      .from('sync_logs')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(5)
      .then(({ data }) => setLogs(data ?? []))

    // الاشتراك في التحديثات الفورية
    const channel = supabase
      .channel('sync_logs_realtime')
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'sync_logs',
      }, payload => {
        setLogs(prev => [payload.new as SyncLog, ...prev.slice(0, 4)])
      })
      .subscribe()

    return () => { supabase.removeChannel(channel) }
  }, [])

  return (
    <div className="rounded-xl border border-gray-800 bg-gray-900 p-4">
      <h2 className="font-semibold mb-3 flex items-center gap-2">
        <span className="w-2 h-2 bg-green-400 rounded-full animate-pulse" />
        آخر العمليات — مباشر
      </h2>
      <div className="space-y-2">
        {logs.map(log => (
          <div key={log.id}
            className="flex items-center justify-between text-sm py-2
                       border-b border-gray-800 last:border-0">
            <span className="text-gray-400 text-xs">
              {new Date(log.created_at).toLocaleTimeString('ar-DZ')}
            </span>
            <span className="text-gray-300">{log.type}</span>
            <span>{log.success
              ? <span className="text-green-400">✓</span>
              : <span className="text-red-400">✗</span>}
            </span>
          </div>
        ))}
        {logs.length === 0 && (
          <div className="text-gray-600 text-sm text-center py-4">
            لا توجد عمليات بعد
          </div>
        )}
      </div>
    </div>
  )
}
```

---

### 5.5 خطوات النشر

```bash
# 1. أنشئ المشروع
npx create-next-app@latest syncvault-dashboard \
  --typescript --tailwind --app --src-dir=false

# 2. انتقل للمجلد وثبّت المكتبات
cd syncvault-dashboard
npm install @supabase/supabase-js

# 3. أنشئ ملف البيئة
echo "NEXT_PUBLIC_SUPABASE_URL=https://xxx.supabase.co" >> .env.local
echo "NEXT_PUBLIC_SUPABASE_ANON_KEY=your-key" >> .env.local

# 4. شغّل محلياً للتجربة
npm run dev

# 5. انشر على Vercel
npx vercel --prod
```

---

### 5.6 تفعيل Realtime في Supabase

في لوحة Supabase — Database → Replication — فعّل هذه الجداول:

| الجدول | Realtime |
|---|---|
| backups | ✅ فعّل |
| sync_logs | ✅ فعّل |
| devices | ✅ فعّل |
| ping_logs | ❌ اختياري |

---

### 5.7 الوقت المقدر

| المهمة | الساعات |
|---|---|
| إعداد المشروع + Supabase | 1 |
| الصفحة الرئيسية + البطاقات | 2 |
| جدول النسخ الاحتياطية | 1 |
| سجل العمليات | 1 |
| Realtime في SyncStatusCard | 1 |
| DeviceCard + SecurityBadge | 1 |
| نشر Vercel + اختبار | 0.5 |
| **الإجمالي** | **7.5 ساعة** |


*آخر تحديث: يونيو 2026*
*المشروع: SyncVault v1.0 — خارطة طريق التكامل مع ProManSystem (ATELIO)*

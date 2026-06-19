# SyncVault — Session 01 Progress Report

**Date:** June 18, 2026
**Git branches:** ProManSystem `master` (ahead of origin by 20 commits), SyncVault `main`
**Status:** Phase 1-4 + 6 code complete. Phase 2 sync engine confirmed functional. One open bug remains.

---

## CURRENT WORKING STATE

### SQLite Local DB
- Path: `C:\Users\Mounir\AppData\Local\ProManSystem\app.db`
- 20 data tables + `pending_sync` tracking table
- 36 SQLite triggers across 12 business tables (INSERT/UPDATE/DELETE on each)
- WAL mode active, `busy_timeout=5000`, `synchronous=FULL` applied via `SqlitePragmaInterceptor` on all EF Core connections
- `device_id` auto-generated on first launch: `PC-MOUNIR-MAIN-4e2365fd`

### Supabase Cloud
- Project: `ProManSystem-Sync` (qlcwuxovpcaknxbdzuby)
- **21 tables total**: 4 infrastructure (backups, sync_logs, devices, ping_logs) + 17 data tables matching local schema
- All 17 data tables have `id` (BIGINT PK), `device_id` (TEXT), `updated_at` (TEXT), other columns TEXT
- Connectivity detection works: pings `/rest/v1/` → 401 Unauthorized → classified as Online

### UI Status Bar
- `TxtConnectionStatus`: updates via `App.ConnectivityStateChanged` event + reads `App.IsOnline` on load (race condition fix applied)
- `TxtPendingSync`: updates via `DispatcherTimer` every 10s reading `SyncEngine.GetPendingCountAsync()`
- `TxtLastBackup`: reads `SyncEngine.LastSyncTime` property

### Sync Pipeline (confirmed working)
```
User saves in UI → EF Core SaveChanges → SQLite trigger fires → INSERT pending_sync
→ FlushPendingAsync reads row → reads full row from SQLite → JSON serialize
→ POST /rest/v1/{table}?on_conflict=id (with Prefer: merge-duplicates header)
→ Supabase inserts/upserts → EF Core marks synced=1 → SaveChanges persists flag
```

---

## BUGS FIXED THIS SESSION (chronological)

### 1. .env not loaded at runtime
- **Root cause:** WPF doesn't load `.env` files; Supabase env vars were null
- **Fix:** Created `DotEnvLoader.cs` that reads `.env` and calls `Environment.SetEnvironmentVariable()`. Called before `AppHost.Build()` in `App.xaml.cs`
- **Commit:** `fix: load .env variables before DI container initialization`

### 2. Deadlock: SupabaseClientFactory.InitializeAsync blocking UI thread
- **Root cause:** `InitializeAsync().GetAwaiter().GetResult()` called synchronously on UI thread
- **Fix:** Changed to `Task.Run(async () => await client.InitializeAsync())` — fire and forget
- **Commit:** `fix: restore main window visibility after DI initialization`

### 3. EF Core constructor ambiguity
- **Root cause:** `AddDbContextFactory` couldn't resolve between 2 AppDbContext constructors
- **Fix:** Replaced `AddDbContextFactory<T>` with custom `AppDbContextFactory : IDbContextFactory<AppDbContext>` that calls `new AppDbContext()` directly. Added `DbContextOptions` constructor guarded by `IsConfigured`.
- **Commit:** `fix: remove duplicate AppDbContext constructors`

### 4. ConnectivityWatcher always Offline
- **Root cause 1:** `NetworkInterface.GetIsNetworkAvailable()` unreliable on Windows
- **Root cause 2:** Background `Task.Run(async () => await CheckAndNotify())` — exceptions swallowed
- **Fix:** Replaced with real HTTP ping to Supabase `/rest/v1/`. Added `ConnLog()` file logging.
- **Commit:** `fix: replace NetworkInterface check with real HTTP ping`

### 5. SQLite triggers never executed
- **Root cause:** `DatabaseFacade.ExecuteSqlRaw()` doesn't exist in EF Core 8 SQLite — all SQL statements failed silently inside try-catch
- **Fix:** Rewrote `ExecuteSyncSchema` and `ExecuteSyncTriggers` to use ADO.NET `DbCommand.ExecuteNonQuery()`. Created `SplitSqlStatements()` that parses `CREATE TRIGGER...END;` as whole blocks.
- **Applied 36 triggers manually to live DB** via ad-hoc console app

### 6. busy_timeout=0 on EF Core connections
- **Root cause:** PRAGMAs are per-connection; `InitializeDatabase` only set them on its own connection
- **Fix:** Created `SqlitePragmaInterceptor : DbConnectionInterceptor` that applies `busy_timeout=5000`, `journal_mode=WAL`, `synchronous=FULL`, `foreign_keys=ON` on every connection open
- **Commit:** `fix: apply SQLite PRAGMAs on every EF Core connection`

### 7. Status bar never updated
- **Root cause:** `TxtPendingSync` and `TxtLastBackup` were static text in XAML — no code-behind to update them
- **Fix:** Added `RefreshStatusBarAsync()` method + `DispatcherTimer` (10s). Reads `SyncEngine.GetPendingCountAsync()` and `SyncEngine.LastSyncTime`. Injected `ISyncEngine` into HomeWindow.
- **Commit:** `wire HomeWindow status bar with live pending count`

### 8. Race condition: HomeWindow misses Online event
- **Root cause:** ConnectivityWatcher fires Online via `Task.Run` before HomeWindow subscribes to event
- **Fix:** Added `OnConnectivityStateChanged(App.IsOnline)` via `Dispatcher.BeginInvoke` in constructor
- **Commit:** `fix race condition read App.IsOnline on load`

### 9. C:\ file write access denied
- **Root cause:** Debug logs wrote to `C:\env_debug.txt`, `C:\conn_debug.txt` — requires admin
- **Fix:** Changed all paths to `%LocalAppData%\ProManSystem\`
- **Commit:** `fix debug log paths from C drive to LocalAppData`

### 10. EF Core `no such column: p.CompanyId` in pending_sync query
- **Root cause:** `PendingSync` model uses PascalCase properties but SQLite table has snake_case columns (created via raw SQL, not EF Core)
- **Fix:** Added `[Column("snake_name")]` attributes: `table_name`, `row_id`, `company_id`, `old_data`, `device_id`
- **Commit:** `fix column mappings for pending_sync snake_case`

### 11. 404 Not Found on Supabase upsert
- **Root cause:** Supabase only had 4 infrastructure tables — 17 ProManSystem data tables never created
- **Fix:** Created 17 tables via Supabase migration matching local schema (all columns TEXT for max compatibility)
- **MCP:** `create_promanager_data_tables` migration

### 12. 400 Bad Request on upsert
- **Root cause 1:** `on_conflict=Id` (PascalCase) — Postgres column is `id` (lowercase)
- **Root cause 2:** Missing `Prefer: resolution=merge-duplicates` header for upsert
- **Root cause 3:** `device_id` column missing from Supabase tables (SyncEngine adds it to every row)
- **Fix:** Changed to `on_conflict=id`, added `Prefer` header in HttpClient defaults, added `device_id TEXT` to all 17 tables
- **Commit:** `fix upsert request casing and add merge-duplicates header`

### 13. DELETE path 400 + response body not captured
- **Root cause:** `Id=eq.{id}` (PascalCase) + `EnsureSuccessStatusCode()` didn't log body
- **Fix:** Changed to `id=eq.{id}` (lowercase), accept 404 as success (row doesn't exist = already deleted), log response body on failure
- **Commit:** `fix delete path accept 404 and enable tracking for synced flag`

### 14. synced=1 not persisted after successful flush
- **Root cause:** `QueryTrackingBehavior.NoTracking` — setting `item.Synced = 1` not tracked by EF Core, `SaveChanges()` had no effect
- **Fix:** Added `.AsTracking()` to pending_sync query in `FlushPendingAsync`
- **Commit:** `fix delete path accept 404 and enable tracking` (same commit as #13)

---

## OPEN PROBLEM — NOT YET FIXED

### No automatic sync after startup

**Observed:** New customer added → Pending: 1 | Online | Last sync: — (stays forever)

**Diagnosis confirmed:**
- `FlushPendingAsync` is called only 3 times during the app lifecycle:
  1. Startup (immediate, fire-and-forget)
  2. Startup + 3 seconds (delayed, fire-and-forget)
  3. On connectivity change from Offline → Online (event-driven)
- **No periodic timer calls FlushPendingAsync** — the `_statusBarTimer` (10s) only READS pending count, never flushes
- **No event fires when new rows appear in pending_sync** — triggers operate at SQL level only, C# layer is not notified
- Since the app is already Online after startup, no connectivity state change occurs → no subsequent flush

**Root cause:** Zero automatic sync mechanism after initial startup flushes complete.

---

## SUGGESTED NEXT STEPS (options, not decisions)

### Option A: Periodic timer approach
Add a `System.Threading.Timer` in `App.xaml.cs` that calls `FlushPendingAsync` every N seconds (e.g., 30s) regardless of connectivity, using the same try-catch pattern as startup. Simplest fix, guaranteed to work.

### Option B: Event-driven approach  
Override `SaveChanges()` in AppDbContext to fire a `DataChanged` event after every successful save. App.xaml.cs subscribes and calls `FlushPendingAsync` with a short debounce delay (e.g., 2s).

### Option C: Both
Periodic timer (30s) as safety net + event-driven for immediate sync. Most robust, slightly more complex.

### Recommendation
Start with Option A (one timer, 5 lines of code) since it's the simplest guaranteed fix. Add Option B later if low-latency sync is needed.

---

## HOW TO RESUME TESTING TONIGHT

### 1. Start the app
```
Run: bin\Debug\net8.0-windows\ProManSystem.exe
Or: dotnet run --project C:\Users\Mounir\source\repos\ProManSystem\ProManSystem
```
Kill any stale processes first: `Get-Process ProManSystem | Stop-Process -Force`

### 2. Check current pending count
- Look at status bar (bottom of HomeWindow): "Pending: N"
- Or open BackupManagerWindow (click status bar) → Sync Log tab

### 3. Manually trigger a flush for testing
- Turn WiFi off, wait 2 seconds, turn WiFi on → connectivity change triggers sync
- Or add code temporarily (since sync isn't automatic yet — see Open Problem above)

### 4. Debug files (all in `%LocalAppData%\ProManSystem\`)
| File | What it tells you |
|------|-------------------|
| `env_debug.txt` | Whether SUPABASE_URL and KEY loaded from .env |
| `conn_debug.txt` | ConnectivityWatcher ping results (URL, status code, Online/Offline) |
| `sync_errors.txt` | SyncEngine flush logs: STARTED, errors with stacktraces, completed |

### 5. Check Supabase directly
- Tables → customers, products, etc. to see if rows arrived
- SQL Editor: `SELECT COUNT(*) FROM customers; SELECT * FROM customers ORDER BY id DESC LIMIT 5;`

### 6. Check local pending_sync
- Use DB Browser for SQLite or any SQLite tool
- Query: `SELECT id, table_name, row_id, operation, synced FROM pending_sync WHERE synced = 0;`
- synced=0 rows = still pending, synced=1 = flushed to Supabase

---

## KEY FILE LOCATIONS

### Data files
| File | Path |
|------|------|
| Local DB | `%LocalAppData%\ProManSystem\app.db` |
| .env config | `C:\Users\Mounir\Desktop\SyncVault\.env` |
| .env in output | `bin\Debug\net8.0-windows\.env` |
| Local backup | `%LocalAppData%\ProManSystem\Backups\app_backup_20260618_164337.db` (792 KB) |
| Debug logs | `%LocalAppData%\ProManSystem\env_debug.txt`, `conn_debug.txt`, `sync_errors.txt` |

### Source files touched this session
| File | What changed |
|------|-------------|
| `Services/Sync/ConnectivityWatcher.cs` | HTTP ping, file logging, race condition fix |
| `Services/Sync/SyncEngine.cs` | Upsert logic, DELETE 404 handling, .AsTracking(), entry logging, column casing |
| `Services/Sync/SupabaseClientFactory.cs` | Non-blocking InitializeAsync |
| `Services/Sync/DailyPinger.cs` | Supabase ping model |
| `Services/Sync/BackupGuard.cs` | Data integrity checks |
| `Services/DatabaseMaintenanceService.cs` | WAL mode, device_id auto-gen, SQL execution fix |
| `Data/AppDbContext.cs` | PragmaInterceptor, PendingSync DbSet, DbContextOptions constructor |
| `Data/AppDbContextFactory.cs` | Custom factory for DI (avoids constructor ambiguity) |
| `Data/SqlitePragmaInterceptor.cs` | Per-connection PRAGMA application |
| `Models/PendingSync.cs` | Column mappings (snake_case → PascalCase) |
| `DependencyInjection/DotEnvLoader.cs` | .env file loader |
| `DependencyInjection/ServiceCollectionExtensions.cs` | All DI registrations |
| `DependencyInjection/AppHost.cs` | Host builder entry point |
| `App.xaml.cs` | Startup sequence, connectivity hooks, forced flush, debug logs |
| `HomeWindow.xaml.cs` | Status bar timer, connectivity subscription, RefreshStatusBarAsync |
| `HomeWindow.xaml` | Status bar RowDefinition + controls |
| `Views/CloseConfirmWindow.xaml/.cs` | Backup prompt on close |
| `Views/BackupManagerWindow.xaml/.cs` | Backup/sync management UI |
| `Database/sync_schema.sql` | ALTER TABLE + CREATE pending_sync |
| `Database/sync_triggers.sql` | 36 triggers for automatic change tracking |
| `ProManSystem.csproj` | NuGet packages, .env auto-copy, SQL file output |

### Supabase (MCP — no files)
| Migration | What |
|-----------|------|
| `create_syncvault_tables` | 4 infrastructure tables + RLS + Realtime |
| `create_promanager_data_tables` | 17 data tables matching local SQLite |
| `add_device_id_to_data_tables` | device_id column on all 17 data tables |
| Storage buckets: `backups`, `immutable-backups` | Backup file storage |

---

## GIT LOG — ProManSystem (last 10 commits)

```
f60cb98 fix delete path accept 404 and enable tracking for synced flag persistence
3a739ef add response body to sync error logging
af5b0bd fix upsert request casing and add merge-duplicates header
16573ba fix column mappings for pending_sync snake_case to EF Core PascalCase
f2b7ebb add file logs around startup flush to trace execution
9d1fa2b fix race condition read App.IsOnline on load and add flush entry logging
cfe0667 fix debug log paths from C drive to LocalAppData
94dacd7 fix auto-copy dotenv to output add sync error logging and forced startup flush
d5668b0 add debug logging for dotenv and connectivity checks to file
d365421 fix apply SQLite PRAGMAs on every EF Core connection via interceptor
```

---

## GIT LOG — SyncVault (last 3 commits)

```
0e77458 scaffold Next.js dashboard with Tailwind Supabase client and all pages
ecba277 add GitHub Actions keep-alive workflow and sync SQL documentation files
6f020a3 add session 01 progress report
```





توقفت هنا و ماللشكال و الضافتا المكتشة هنا 

# SyncVault — Session 02 Roadmap
**Date:** June 19, 2026  
**Status:** Session 01 complete — pipeline working. Session 02 = fixes + new features.

---

## ✅ ما اكتمل في Session 01

| المكوّن | الحالة |
|---|---|
| 48 trigger على 16 جدول | ✅ |
| Sync كل 30 ثانية | ✅ |
| Backfill كامل (كل الجداول) | ✅ |
| sync_logs يُكتب على Supabase | ✅ |
| devices مسجل على Supabase | ✅ |
| DailyPinger (ping_logs) | ✅ |
| ShadowCopy كل 30 دقيقة | ✅ |
| CloseConfirmWindow | ✅ |
| Status bar في Sidebar | ✅ |

---

## 🔴 المشاكل المكتشفة في Session 01

### المشكلة 1 — DELETE لا يحذف من Supabase
**السبب:** SyncEngine يرسل `PATCH is_deleted=true` بدل `DELETE` حقيقي.  
**النتيجة:** الصف يبقى في Supabase إلى الأبد.  
**الحل:** تغيير 5 أسطر في `SyncEngine.cs` — استبدال PATCH بـ DELETE.  
**الوقت:** 30 دقيقة.

---

### المشكلة 2 — Backup لا يُرفع على Supabase Storage
**السبب:** `SecureBackupService.EncryptAndUploadAsync()` موجود لكن لا أحد يستدعيه تلقائياً.  
**النتيجة:** جدول `backups` فارغ دائماً.  
**الحل:** إضافة `_backupTimer` في `App.xaml.cs` كل 24 ساعة + كتابة في جدول `backups`.  
**الوقت:** 2 ساعة.

---

### المشكلة 3 — Dashboard لا يعرض بيانات
**السبب:** صفحات Next.js بدون `'use client'` — تعمل كـ Server Components، والـ Supabase client يحتاج browser.  
**النتيجة:** لا يتحدث مع Supabase أبداً.  
**الحل:** إضافة `'use client'` في 4 ملفات.  
**الوقت:** 10 دقائق.

---

## 🟡 الميزات الجديدة المطلوبة

### الميزة 1 — Pull Sync
**الهدف:** ما يوجد على Supabase ينزل محلياً تلقائياً.

**سيناريوهات الاستخدام:**
- العميل يعمل نهاراً → بياناته تصعد Supabase → أنت تفتح ليلاً → تنزل بياناته
- أنت تصحح خطأ ليلاً → يصعد Supabase → العميل يفتح صباحاً → ينزل التصحيح
- تلفت `app.db` محلياً → Pull كامل من Supabase → تعود البيانات كاملة

**كيف يعمل:**
```
عند فتح البرنامج:
1. Push أولاً — ارفع كل pending محلي
2. انتظر 5 ثوانٍ
3. Pull — اسحب كل updated_at > last_pull_timestamp من Supabase
4. احفظ last_pull_timestamp الجديد
```

**قاعدة التعارض:** آخر `updated_at` يفوز — بسيطة وآمنة.  
**الوقت:** 4 ساعات.

---

### الميزة 2 — Daily Backup على Supabase Storage
**الهدف:** نسخة يومية من `app.db` مشفرة ومرفوعة.

**التفاصيل:**
- كل 24 ساعة → GZip + AES-256 → Supabase Storage
- عند إغلاق التطبيق → نسخة فورية
- كل نسخة تُسجَّل في جدول `backups`
- احتفاظ بـ 30 نسخة — تُحذف الأقدم تلقائياً

**الوقت:** 2 ساعة.

---

### الميزة 3 — Immutable Backups + زر إيقاف Sync
**الهدف:** حماية من كارثة البيانات (العميل يخرب البيانات → تصعد Supabase → كارثة).

**الحل:**
```
زر STOP SYNC في Dashboard
        ↓
devices.sync_paused = true على Supabase
        ↓
WPF app يقرأ الـ flag كل 60 ثانية → يوقف FlushPendingAsync
        ↓
تختار نسخة سليمة → تستعيدها
        ↓
sync_paused = false → يعود كل شيء
```

**خطة الاستعادة الكاملة:**
1. اضغط STOP SYNC في Dashboard
2. اختر نسخة من قائمة Backups
3. تحميل + فك تشفير + تحقق من سلامة البيانات
4. استبدال `app.db` المحلي
5. `last_pull_timestamp = MinValue` → Pull كامل
6. إعادة تشغيل التطبيق → RESUME SYNC

**الوقت:** 6 ساعات.

---

### الميزة 4 — Google Drive (Phase 6+)
**الهدف:** طبقة احتياطية ثانية خارج Supabase.
- نسخة أسبوعية → Google Drive → محمية 6 أشهر
- لا يمكن حذفها إلا يدوياً
- **مؤجلة** — Supabase يكفي للمرحلة الأولى.

---

## 📋 ترتيب التنفيذ

| # | المهمة | يعتمد على | الوقت | السبب |
|---|---|---|---|---|
| 1 | Dashboard fix (`'use client'`) | لا شيء | 10 دقائق | فوري — يفتح التحقق من كل شيء |
| 2 | Hard DELETE | لا شيء | 30 دقيقة | أبسط إصلاح — يجب قبل Pull |
| 3 | Pull Sync | #2 | 4 ساعات | القلب المفقود — يحل سيناريوهات العميل |
| 4 | Daily Backup | #3 | 2 ساعة | Backup مفيد فقط مع Pull للاستعادة |
| 5 | STOP SYNC + Restore | #3 + #4 | 6 ساعات | حماية الكارثة — يحتاج Pull و Backup |
| 6 | Google Drive | #4 | مؤجل | Phase 6+ |

**الإجمالي: ~13 ساعة عمل فعلي**

---

## 🗂️ الملفات التي ستتغير

| الملف | التغيير |
|---|---|
| `Services/Sync/SyncEngine.cs` | DELETE → hard delete |
| `Services/Sync/PullSyncService.cs` | ملف جديد |
| `App.xaml.cs` | _backupTimer + Pull startup + STOP SYNC polling |
| `dashboard/app/page.tsx` | إضافة `'use client'` |
| `dashboard/app/logs/page.tsx` | إضافة `'use client'` |
| `dashboard/app/backups/page.tsx` | إضافة `'use client'` |
| `dashboard/components/SyncStatusCard.tsx` | إضافة `'use client'` |

---

## 🧪 خطة التجريب بعد كل إصلاح

### بعد Fix 1 (DELETE):
1. أضف زبون → تحقق Supabase ✅
2. احذفه → تحقق Supabase → يجب أن يختفي ✅

### بعد Fix 2 (Dashboard):
1. افتح `localhost:3000`
2. يجب أن يظهر: 80+ نشاط، 1 جهاز ✅

### بعد Fix 3 (Backup):
1. انتظر 24 ساعة أو استدع يدوياً
2. تحقق Supabase Storage → ملف موجود ✅
3. تحقق جدول `backups` → صف مسجل ✅

### بعد Pull Sync:
1. عدّل بيانات على Supabase مباشرة
2. أغلق وافتح التطبيق
3. تحقق محلياً → التعديل موجود ✅
4. احذف `app.db` → أعد التشغيل → Pull كامل ✅

---

## 📝 ملاحظات مهمة

- **triggers تُعيد الحصول**: عند Pull، الـ INSERT في SQLite يُطلق trigger → pending_sync. هذا لا يسبب مشكلة لأن Push يحدث قبل Pull، وأي trigger جديد سيُرسل لـ Supabase مرة أخرى بنفس البيانات (upsert = لا تكرار).
- **app.db الحجم**: 792KB → بعد GZip ~200KB → Supabase Storage 1GB مجاني = 5000+ نسخة.
- **STOP SYNC**: يتحقق منه WPF كل 60 ثانية. إذا نُسي مفعّلاً → يُلغى تلقائياً بعد 24 ساعة.
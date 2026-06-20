# SyncVault — Technical Report

## 1. Project Overview

SyncVault is an offline-first sync and backup system built on top of ProManSystem, a WPF C# (.NET 8) desktop application for manufacturing and commercial management. It enables automatic cloud synchronization of business data to Supabase (PostgreSQL), provides encrypted backups, and offers a web dashboard for monitoring.

**Problem solved:** Before SyncVault, ProManSystem was a purely local application. Data lived exclusively in a SQLite file on a single machine. There was no cloud backup, no multi-machine sync, and no visibility into the health of the system. A hard drive failure would mean total data loss.

**Solution:** SyncVault adds a complete data pipeline: local SQLite → change-tracking triggers → pending_sync queue → periodic HTTP push to Supabase → pull from Supabase on startup. An encrypted backup system copies the database to Supabase Storage daily. A Next.js dashboard provides real-time monitoring from any device.

---

## 2. System Architecture

```
┌─────────────────────────────────────────────┐
│              WPF Desktop App                 │
│  (ProManSystem + SyncVault services)        │
│                                              │
│  SQLite (app.db) ← triggers → pending_sync  │
│         ↓                                    │
│  SyncEngine (push every 30s)                │
│  PullSyncService (pull on startup)          │
│  ShadowCopyService (mirror every 30min)     │
│  SecureBackupService (AES-256 + upload)     │
│  BackfillService (one-time historical sync) │
│  ConnectivityWatcher (HTTP ping every 30s)  │
│  DailyPinger (keeps Supabase alive)         │
│         ↓                                    │
│  ┌──────────────┐   ┌───────────────────┐   │
│  │   Supabase    │   │  Supabase Storage │   │
│  │  (PostgreSQL) │   │  (encrypted .enc) │   │
│  └──────────────┘   └───────────────────┘   │
│         ↓                                    │
│  ┌──────────────────────────────────────┐    │
│  │      Next.js Dashboard (Vercel)      │    │
│  │   localhost:3000 (dev)               │    │
│  └──────────────────────────────────────┘    │
└─────────────────────────────────────────────┘
```

Three projects compose the system:
- **ProManSystem** (`C:\Users\Mounir\source\repos\ProManSystem\ProManSystem\`) — WPF desktop app + all SyncVault C# services
- **SyncVault** (`C:\Users\Mounir\Desktop\SyncVault\`) — configuration files, documentation, dashboard source
- **Supabase** (`qlcwuxovpcaknxbdzuby`) — cloud PostgreSQL + storage buckets

Data flow is strictly: SQLite is the source of truth. Supabase is a mirror. Changes originate locally, push to cloud, and pull back on other machines.

---

## 3. All Components Built

### 3.1 SyncEngine (`Services/Sync/SyncEngine.cs`)

The core of the sync pipeline. Runs on a 30-second timer. For each pending_sync row:

- **INSERT / UPDATE:** Reads the full row from local SQLite via ADO.NET. Lowercases all column names, adds `device_id` and `updated_at`, serializes to JSON, and sends `POST /rest/v1/{table}?on_conflict=id` with `Prefer: resolution=merge-duplicates` header. Marks `synced=1` on success.

- **DELETE:** Sends `DELETE /rest/v1/{table}?id=eq.{rowId}`. Accepts 404 (Not Found) as success — the row doesn't exist on Supabase, which is the desired state. Throws on any other error status.

After each operation: posts a `sync_logs` entry to Supabase. After each batch: posts a `sync_batch` summary. Updates `last_sync` on the `devices` table.

### 3.2 PullSyncService (`Services/Sync/PullSyncService.cs`)

Runs once on startup, 8 seconds after the initial push flushes. Reads `last_pull_timestamp` from local AppSettings (first run = DateTimeOffset.MinValue). For each of 16 tables: queries `GET /rest/v1/{table}?updated_at=gt.{ts}&device_id=neq.{deviceId}` to fetch only rows modified by other devices since the last pull. Upserts each row into local SQLite using `INSERT OR REPLACE` via raw ADO.NET. Filters out Supabase columns (`device_id`, `updated_at`, `is_deleted`) that don't exist on local tables. Saves a new `last_pull_timestamp` after completion.

### 3.3 SQLite Triggers (`Database/sync_triggers.sql`)

48 triggers across 16 tables. Three per table: AFTER INSERT, AFTER UPDATE, BEFORE DELETE. Each trigger inserts a row into the `pending_sync` table with: table name, row ID, company ID, operation type, device ID (from AppSettings). The UPDATE trigger also sets `updated_at = datetime('now')` on the modified row. For InvoiceLines tables (no CompanyId column), company_id is hardcoded to 0.

Tables covered: customers, suppliers, products, productrecipes, productcategories, rawmaterials, salesinvoices, purchaseinvoices, commercialproducts, commercialsalesinvoices, commercialpurchaseinvoices, stockbatches, salesinvoicelines, purchaseinvoicelines, commercialsalesinvoicelines, commercialpurchaseinvoicelines.

### 3.4 ShadowCopyService (`Services/Sync/ShadowCopyService.cs`)

Creates a byte-for-byte copy of the live SQLite database to a secondary path. Runs `PRAGMA wal_checkpoint(TRUNCATE)` before copying to ensure all WAL journal data is flushed to the main file. Uses SQLite's built-in `BackupDatabase()` API for safe atomic copy while the database is in use. Target path: `D:\Backup\ProManSystem\shadow.db` (from `.env` SHADOW_DB_PATH) or `%LocalAppData%\ProManSystem\Backups\shadow.db` as fallback.

### 3.5 SecureBackupService (`Services/Sync/SecureBackupService.cs`)

Encrypts the database file and uploads it to Supabase Storage. Pipeline: read `app.db` → GZip compress → AES-256-GCM encrypt (with 12-byte nonce, 16-byte auth tag) → upload to `backups` bucket. File format: `[nonce(12)] + [tag(16)] + [ciphertext]`. Encryption key is derived from a salt stored in Windows Credential Manager using PBKDF2 (600,000 iterations, SHA-256). File naming: `backup_{yyyy-MM-dd_HH-mm}.enc`. Includes BackupGuard validation: rejects uploads smaller than 70% of the previous backup's size.

### 3.6 BackfillService (`Services/Sync/BackfillService.cs`)

One-time historical data sync. Reads all rows from all 16 tables via ADO.NET and upserts them to Supabase. Controlled by a flag in AppSettings (`backfill_v2_completed`). Runs once and never again. Logs per-table progress to `backfill_debug.txt`.

### 3.7 ConnectivityWatcher (`Services/Sync/ConnectivityWatcher.cs`)

Detects internet connectivity by sending an HTTP GET to `{SUPABASE_URL}/rest/v1/` every 30 seconds. Treats 401 Unauthorized as "Online" (the endpoint requires authentication but the connection works). Sets `App.IsOnline` and fires `ConnectivityStateChanged` event. Logs to `conn_debug.txt`.

### 3.8 DailyPinger (`Services/Sync/DailyPinger.cs`)

Prevents Supabase from being paused after 7 days of inactivity (free tier limitation). Waits 30 seconds after startup for the Supabase client to initialize, then inserts a row into the `ping_logs` table. Repeats every 24 hours. Uses supabase-csharp SDK with `[Table("ping_logs")]` mapping.

### 3.9 DotEnvLoader (`DependencyInjection/DotEnvLoader.cs`)

Loads environment variables from a `.env` file before the DI container initializes. Searches: `C:\Users\Mounir\Desktop\SyncVault\.env` (dev path), `{exeDir}\.env`, `{exeDir}\SyncVault\.env`, `%SYNCVAULT_ENV_PATH%`. Expands embedded environment variables (e.g., `%LocalAppData%`).

### 3.10 SqlitePragmaInterceptor (`Data/SqlitePragmaInterceptor.cs`)

EF Core connection interceptor that applies `PRAGMA busy_timeout=5000`, `PRAGMA journal_mode=WAL`, `PRAGMA synchronous=FULL`, and `PRAGMA foreign_keys=ON` on every database connection open. This ensures all EF Core connections (from the 44 code-behind windows) have the correct settings.

### 3.11 BackupGuard (`Services/Sync/BackupGuard.cs`)

Data integrity validation for backups. `IsSafeToWrite(incomingRows, currentRows)` throws if incoming row count is less than 20% of current — prevents data-zeroing disasters. `IsBackupSizeValid(newSize, previousSize)` returns false if the new backup is less than 70% of the previous — prevents uploading corrupted files.

### 3.12 DatabaseMaintenanceService (`Services/DatabaseMaintenanceService.cs`)

Database lifecycle management. Initializes the SQLite database, runs PRAGMA statements, executes the sync schema and triggers SQL files, auto-generates device IDs, validates and copies database files, creates local backups, replaces databases, and handles WAL checkpoints.

### 3.13 AppDbContext + AppDbContextFactory (`Data/`)

Custom `IDbContextFactory<AppDbContext>` that creates fresh DbContext instances for every window. Avoids the EF Core constructor ambiguity issue by using a simple `new AppDbContext()` pattern. DbContext uses `QueryTrackingBehavior.NoTracking` globally; SyncEngine explicitly adds `.AsTracking()` when it needs to persist changes.

### 3.14 Dependency Injection (`DependencyInjection/`)

`ServiceCollectionExtensions.AddProManServices()` registers all 14 SyncVault services plus the existing ProManSystem services. `AppHost.Build()` creates the Generic Host. `AppHost.GetService<T>()` provides service location for code-behind windows that can't use constructor injection.

---

## 4. All Supabase Tables

### Infrastructure Tables (4)

| Table | Purpose | Written By |
|-------|---------|------------|
| `sync_logs` | Records every sync operation (per-row and per-batch) | SyncEngine.FlushPendingAsync(), SyncEngine.PostSyncLogAsync() |
| `devices` | Registered machines with online/sync status and pause toggle | SyncEngine.RegisterDeviceAsync(), SyncEngine.UpdateDeviceLastSeenAsync() |
| `backups` | Metadata for every backup uploaded to Storage | App.xaml.cs PostBackupRecord() |
| `ping_logs` | Daily keep-alive pings to prevent Supabase from pausing | DailyPinger.PingAsync() |

All 4 tables have RLS policy `dev_allow_all` with `USING (true)` for development.

### Data Tables (17)

All 17 tables mirror the local SQLite schema with all columns typed as TEXT (max compatibility). The `id` column is BIGINT PRIMARY KEY. All tables have `device_id TEXT`, `updated_at TEXT`, and `is_deleted TEXT` columns added via Supabase migrations.

### Storage Buckets (2)

| Bucket | Purpose | Policy |
|--------|---------|--------|
| `backups` | Daily encrypted database backups | Private |
| `immutable-backups` | Weekly backups that cannot be deleted | Private, DELETE denied |

---

## 5. All Background Timers

| Timer | Interval | Service | What It Does |
|-------|----------|---------|--------------|
| `_syncTimer` | 30 seconds | SyncEngine | Calls FlushPendingAsync() — pushes pending_sync rows to Supabase |
| `_shadowTimer` | 30 minutes | ShadowCopyService | Copies app.db to shadow path on secondary drive |
| `_backupTimer` | 24 hours | SecureBackupService | Encrypts app.db and uploads to Supabase Storage |
| `_pauseCheckTimer` | 60 seconds | HttpClient | Polls Supabase devices table for sync_paused flag |
| `_connectivityTimer` | 30 seconds | ConnectivityWatcher | HTTP ping to Supabase to check internet connectivity |
| `_dailyPingTimer` | 24 hours | DailyPinger | Inserts row into ping_logs to keep Supabase active |
| `_statusBarTimer` | 10 seconds | DispatcherTimer | Reads pending count and updates UI (HomeWindow) |
| `_shadowStartup` | 60 seconds delay | ShadowCopyService | One-time shadow copy on startup |
| `_backupStartup` | 120 seconds delay | SecureBackupService | One-time encrypted backup on startup |

---

## 6. Startup Sequence

When the WPF application launches, the following operations execute in order:

1. **DotEnvLoader.Load()** — reads `.env` file, sets environment variables (SUPABASE_URL, SUPABASE_ANON_KEY, DEVICE_ID, etc.)

2. **AppHost.Build()** — creates the DI container, registers all services

3. **Service Resolution** — resolves all singleton services: ConnectivityWatcher, DailyPinger, SyncEngine, ShadowCopyService, BackfillService, PullSyncService, SecureBackupService

4. **ConnectivityWatcher.Start()** — begins HTTP ping to Supabase every 30s

5. **DailyPinger.Start()** — waits 30s, then pings Supabase every 24h

6. **Database Setup** — checks for existing database, shows DatabaseSetupWindow if missing, calls InitializeDatabase() (creates tables, applies WAL mode, runs schema/trigger SQL)

7. **Device ID Generation** — EnsureDeviceId() generates a GUID if none exists, stores in AppSettings

8. **PDF Sync** — SalesInvoiceSyncService regenerates missing invoice PDFs (legacy feature)

9. **Startup Push** (immediate, fire-and-forget) — FlushPendingAsync() processes any pending_sync rows from before shutdown

10. **Delayed Push** (3 seconds) — second FlushPendingAsync() to catch rows created during PDF sync

11. **Backfill Check** (5 seconds) — runs BackfillService if backfill_v2_completed flag is false

12. **Pull Sync** (8 seconds) — PullSyncService.RunAsync() queries Supabase for changes from other devices since last pull, upserts into local SQLite

13. **Device Registration** (10 seconds) — RegisterDeviceAsync() upserts the device into Supabase devices table

14. **Shadow Copy Startup** (60 seconds) — one-time shadow database copy

15. **Backup Startup** (120 seconds) — one-time encrypted backup upload to Supabase Storage

16. **SplashScreen** displays, then HomeWindow opens

17. **Periodic Timers Begin** — sync (30s), shadow (30min), backup (24h), pause check (60s), connectivity (30s), pinger (24h)

All startup operations run on background threads via `Task.Run()`. The UI thread is never blocked.

---

## 7. Testing Map

### Test 1: Confirm Online Status

1. Launch ProManSystem
2. Check sidebar status panel: green dot should appear with "Online" text
3. If Offline: check `conn_debug.txt` at `%LocalAppData%\ProManSystem\` for ping results
4. Verify `SUPABASE_URL` is set in `.env`

### Test 2: Confirm Local Triggers Fire

1. Add a new customer via the UI
2. Wait 10 seconds
3. Check sidebar: "Pending: 1" should appear
4. Open `%LocalAppData%\ProManSystem\app.db` in DB Browser
5. Query: `SELECT * FROM pending_sync ORDER BY id DESC LIMIT 5;` — should show the new row with `synced=0`

### Test 3: Confirm Push Sync Works

1. Continue from Test 2 — wait 30 seconds
2. Sidebar should show "Pending: 0" and "Last sync: {time}"
3. Query Supabase: `SELECT * FROM customers ORDER BY id DESC LIMIT 1;` — should show the new customer
4. Verify `device_id` column matches `PC-MOUNIR-MAIN-...`

### Test 4: Confirm DELETE Works (Hard Delete)

1. Delete a customer via the UI
2. Wait 30 seconds for sync timer
3. Query Supabase: `SELECT * FROM customers WHERE id = {deleted_id};` — should return empty (0 rows)
4. The row should be physically removed, not soft-deleted

### Test 5: Confirm Pull Sync Works

1. Use Supabase SQL Editor to manually INSERT a test row into customers: `INSERT INTO customers (id, codeclient, nomcomplet, companyid, device_id, updated_at) VALUES (9999, 'TEST', 'Pull Sync Test', 1, 'other-device', '2026-06-19T00:00:00Z');`
2. Close and restart ProManSystem
3. Check `pull_debug.txt` — should show "customers: 1 rows pulled"
4. Open local SQLite: `SELECT * FROM customers WHERE id = 9999;` — should return the test row

### Test 6: Confirm Sync Pause / Resume

1. Navigate to dashboard at `http://localhost:3000`
2. Click "Pause Sync" button on DeviceCard
3. Wait up to 60 seconds
4. Check WPF sidebar: should show red "⚠ SYNC PAUSED" text
5. Add a customer in WPF — sidebar shows "Pending: 1" but never goes to 0
6. Click "Resume Sync" on dashboard
7. Within 60 seconds: "⚠ SYNC PAUSED" disappears, "Pending: 0" appears, data reaches Supabase

### Test 7: Confirm Shadow Copy

1. Wait at least 30 minutes after app launch
2. Check file exists: `D:\Backup\ProManSystem\shadow.db` (or `%LocalAppData%\ProManSystem\Backups\shadow.db`)
3. File size should match or be close to `app.db` size (~792 KB)
4. Check `shadow_debug.txt` for "Shadow copy OK"

### Test 8: Confirm Encrypted Backup

1. Wait at least 120 seconds after app launch
2. Check Supabase Storage → `backups` bucket — should contain at least one `.enc` file
3. Check Supabase `backups` table: `SELECT * FROM backups ORDER BY created_at DESC LIMIT 1;` — should show one row with `source='auto'` and `status='ok'`
4. File should be encrypted — downloading and opening in a text editor should show binary gibberish

### Test 9: Confirm DailyPinger

1. Wait at least 30 seconds after app launch
2. Check `ping_debug.txt` — should show either "Ping OK — {ms}ms" or "Ping SKIPPED — Client not ready"
3. If showing OK: query Supabase `ping_logs` table — should have at least one row
4. If showing SKIPPED: wait for next cycle (24h) or check `SupabaseClientFactory.IsReady` timing

### Test 10: Confirm Dashboard Shows Data

1. Ensure Next.js dev server is running: `cd dashboard && npm run dev`
2. Open `http://localhost:3000`
3. Home page should show: 1 device (DESKTOP-R8KNC47), sync activity in Recent Activity section, 0 backups
4. Click "Logs" — should show sync operations (type, device, success/fail)
5. Click "Backups" — should show backup entries if Test 8 completed

### Test 11: Confirm Close Window with Backup

1. Click the close button (red X) on HomeWindow
2. If no backup today: CloseConfirmWindow appears showing "Last backup: {time}" with two buttons
3. Click "Save and Close" — progress bar appears, app closes
4. Check Supabase `backups` table — new row with `source='on_close'`
5. If a backup was already saved today: app closes directly without prompt

### Test 12: Full Disaster Recovery Simulation

1. Close ProManSystem
2. Rename `%LocalAppData%\ProManSystem\app.db` to `app.db.bak`
3. Launch ProManSystem — DatabaseSetupWindow should appear (no database found)
4. Option A: Create new empty database, then PullSync will pull everything from Supabase
5. Option B: Restore from `shadow.db` using DatabaseMaintenanceWindow
6. Verify all 36 customers, 29 products, 89 sales invoices are restored

---

*Report generated: June 19, 2026*
*Project: SyncVault v2.0 — Integrated with ProManSystem (ATELIO)*
*Supabase project: qlcwuxovpcaknxbdzuby (ProManSystem-Sync)*

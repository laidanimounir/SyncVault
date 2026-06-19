-- SyncVault: أعمدة المزامنة لكل الجداول
-- يُنفَّذ تلقائياً عند تهيئة قاعدة البيانات

ALTER TABLE Companies ADD COLUMN updated_at TEXT;
ALTER TABLE Customers ADD COLUMN updated_at TEXT;
ALTER TABLE Customers ADD COLUMN is_deleted INTEGER DEFAULT 0;
ALTER TABLE Suppliers ADD COLUMN updated_at TEXT;
ALTER TABLE Suppliers ADD COLUMN is_deleted INTEGER DEFAULT 0;
ALTER TABLE Products ADD COLUMN updated_at TEXT;
ALTER TABLE Products ADD COLUMN is_deleted INTEGER DEFAULT 0;
ALTER TABLE ProductRecipes ADD COLUMN updated_at TEXT;
ALTER TABLE ProductRecipes ADD COLUMN is_deleted INTEGER DEFAULT 0;
ALTER TABLE ProductCategories ADD COLUMN updated_at TEXT;
ALTER TABLE ProductCategories ADD COLUMN is_deleted INTEGER DEFAULT 0;
ALTER TABLE RawMaterials ADD COLUMN updated_at TEXT;
ALTER TABLE RawMaterials ADD COLUMN is_deleted INTEGER DEFAULT 0;
ALTER TABLE SalesInvoices ADD COLUMN updated_at TEXT;
ALTER TABLE SalesInvoices ADD COLUMN is_deleted INTEGER DEFAULT 0;
ALTER TABLE PurchaseInvoices ADD COLUMN updated_at TEXT;
ALTER TABLE PurchaseInvoices ADD COLUMN is_deleted INTEGER DEFAULT 0;
ALTER TABLE CommercialProducts ADD COLUMN updated_at TEXT;
ALTER TABLE CommercialProducts ADD COLUMN is_deleted INTEGER DEFAULT 0;
ALTER TABLE CommercialSalesInvoices ADD COLUMN updated_at TEXT;
ALTER TABLE CommercialSalesInvoices ADD COLUMN is_deleted INTEGER DEFAULT 0;
ALTER TABLE CommercialPurchaseInvoices ADD COLUMN updated_at TEXT;
ALTER TABLE CommercialPurchaseInvoices ADD COLUMN is_deleted INTEGER DEFAULT 0;
ALTER TABLE StockBatches ADD COLUMN updated_at TEXT;
ALTER TABLE StockBatches ADD COLUMN is_deleted INTEGER DEFAULT 0;

CREATE TABLE IF NOT EXISTS pending_sync (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    table_name  TEXT NOT NULL,
    row_id      INTEGER NOT NULL,
    company_id  INTEGER NOT NULL,
    operation   TEXT NOT NULL,
    old_data    TEXT,
    timestamp   TEXT DEFAULT (datetime('now')),
    synced      INTEGER DEFAULT 0,
    device_id   TEXT
);

CREATE INDEX IF NOT EXISTS idx_pending_sync_synced
    ON pending_sync(synced, timestamp);

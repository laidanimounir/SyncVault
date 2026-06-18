-- SyncVault: مشغلات تتبع التغييرات التلقائية
-- يُنفَّذ بعد sync_schema.sql

CREATE TRIGGER IF NOT EXISTS trg_companies_after_update
AFTER UPDATE ON Companies
BEGIN
    UPDATE Companies SET updated_at = datetime('now') WHERE CompanyId = NEW.CompanyId;
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    VALUES ('Companies', NEW.CompanyId, NEW.CompanyId, 'UPDATE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id'));
END;

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

CREATE TRIGGER IF NOT EXISTS trg_suppliers_after_insert
AFTER INSERT ON Suppliers
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    VALUES ('Suppliers', NEW.Id, NEW.CompanyId, 'INSERT',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id'));
END;

CREATE TRIGGER IF NOT EXISTS trg_suppliers_after_update
AFTER UPDATE ON Suppliers
BEGIN
    UPDATE Suppliers SET updated_at = datetime('now') WHERE Id = NEW.Id;
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    VALUES ('Suppliers', NEW.Id, NEW.CompanyId, 'UPDATE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id'));
END;

CREATE TRIGGER IF NOT EXISTS trg_suppliers_before_delete
BEFORE DELETE ON Suppliers
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    VALUES ('Suppliers', OLD.Id, OLD.CompanyId, 'DELETE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id'));
END;

CREATE TRIGGER IF NOT EXISTS trg_products_after_insert
AFTER INSERT ON Products
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    VALUES ('Products', NEW.Id, NEW.CompanyId, 'INSERT',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id'));
END;

CREATE TRIGGER IF NOT EXISTS trg_products_after_update
AFTER UPDATE ON Products
BEGIN
    UPDATE Products SET updated_at = datetime('now') WHERE Id = NEW.Id;
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    VALUES ('Products', NEW.Id, NEW.CompanyId, 'UPDATE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id'));
END;

CREATE TRIGGER IF NOT EXISTS trg_products_before_delete
BEFORE DELETE ON Products
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    VALUES ('Products', OLD.Id, OLD.CompanyId, 'DELETE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id'));
END;

CREATE TRIGGER IF NOT EXISTS trg_rawmaterials_after_insert
AFTER INSERT ON RawMaterials
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    VALUES ('RawMaterials', NEW.Id, NEW.CompanyId, 'INSERT',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id'));
END;

CREATE TRIGGER IF NOT EXISTS trg_rawmaterials_after_update
AFTER UPDATE ON RawMaterials
BEGIN
    UPDATE RawMaterials SET updated_at = datetime('now') WHERE Id = NEW.Id;
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    VALUES ('RawMaterials', NEW.Id, NEW.CompanyId, 'UPDATE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id'));
END;

CREATE TRIGGER IF NOT EXISTS trg_rawmaterials_before_delete
BEFORE DELETE ON RawMaterials
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    VALUES ('RawMaterials', OLD.Id, OLD.CompanyId, 'DELETE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id'));
END;

CREATE TRIGGER IF NOT EXISTS trg_salesinvoices_after_insert
AFTER INSERT ON SalesInvoices
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    VALUES ('SalesInvoices', NEW.Id, NEW.CompanyId, 'INSERT',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id'));
END;

CREATE TRIGGER IF NOT EXISTS trg_salesinvoices_after_update
AFTER UPDATE ON SalesInvoices
BEGIN
    UPDATE SalesInvoices SET updated_at = datetime('now') WHERE Id = NEW.Id;
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    VALUES ('SalesInvoices', NEW.Id, NEW.CompanyId, 'UPDATE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id'));
END;

CREATE TRIGGER IF NOT EXISTS trg_salesinvoices_before_delete
BEFORE DELETE ON SalesInvoices
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    VALUES ('SalesInvoices', OLD.Id, OLD.CompanyId, 'DELETE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id'));
END;

CREATE TRIGGER IF NOT EXISTS trg_purchaseinvoices_after_insert
AFTER INSERT ON PurchaseInvoices
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    VALUES ('PurchaseInvoices', NEW.Id, NEW.CompanyId, 'INSERT',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id'));
END;

CREATE TRIGGER IF NOT EXISTS trg_purchaseinvoices_after_update
AFTER UPDATE ON PurchaseInvoices
BEGIN
    UPDATE PurchaseInvoices SET updated_at = datetime('now') WHERE Id = NEW.Id;
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    VALUES ('PurchaseInvoices', NEW.Id, NEW.CompanyId, 'UPDATE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id'));
END;

CREATE TRIGGER IF NOT EXISTS trg_purchaseinvoices_before_delete
BEFORE DELETE ON PurchaseInvoices
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    VALUES ('PurchaseInvoices', OLD.Id, OLD.CompanyId, 'DELETE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id'));
END;

CREATE TRIGGER IF NOT EXISTS trg_commercialproducts_after_insert
AFTER INSERT ON CommercialProducts
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    VALUES ('CommercialProducts', NEW.Id, NEW.CompanyId, 'INSERT',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id'));
END;

CREATE TRIGGER IF NOT EXISTS trg_commercialproducts_after_update
AFTER UPDATE ON CommercialProducts
BEGIN
    UPDATE CommercialProducts SET updated_at = datetime('now') WHERE Id = NEW.Id;
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    VALUES ('CommercialProducts', NEW.Id, NEW.CompanyId, 'UPDATE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id'));
END;

CREATE TRIGGER IF NOT EXISTS trg_commercialproducts_before_delete
BEFORE DELETE ON CommercialProducts
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    VALUES ('CommercialProducts', OLD.Id, OLD.CompanyId, 'DELETE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id'));
END;

CREATE TRIGGER IF NOT EXISTS trg_commercialsalesinvoices_after_insert
AFTER INSERT ON CommercialSalesInvoices
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    VALUES ('CommercialSalesInvoices', NEW.Id, NEW.CompanyId, 'INSERT',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id'));
END;

CREATE TRIGGER IF NOT EXISTS trg_commercialsalesinvoices_after_update
AFTER UPDATE ON CommercialSalesInvoices
BEGIN
    UPDATE CommercialSalesInvoices SET updated_at = datetime('now') WHERE Id = NEW.Id;
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    VALUES ('CommercialSalesInvoices', NEW.Id, NEW.CompanyId, 'UPDATE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id'));
END;

CREATE TRIGGER IF NOT EXISTS trg_commercialsalesinvoices_before_delete
BEFORE DELETE ON CommercialSalesInvoices
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    VALUES ('CommercialSalesInvoices', OLD.Id, OLD.CompanyId, 'DELETE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id'));
END;

CREATE TRIGGER IF NOT EXISTS trg_commercialpurchaseinvoices_after_insert
AFTER INSERT ON CommercialPurchaseInvoices
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    VALUES ('CommercialPurchaseInvoices', NEW.Id, NEW.CompanyId, 'INSERT',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id'));
END;

CREATE TRIGGER IF NOT EXISTS trg_commercialpurchaseinvoices_after_update
AFTER UPDATE ON CommercialPurchaseInvoices
BEGIN
    UPDATE CommercialPurchaseInvoices SET updated_at = datetime('now') WHERE Id = NEW.Id;
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    VALUES ('CommercialPurchaseInvoices', NEW.Id, NEW.CompanyId, 'UPDATE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id'));
END;

CREATE TRIGGER IF NOT EXISTS trg_commercialpurchaseinvoices_before_delete
BEFORE DELETE ON CommercialPurchaseInvoices
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    VALUES ('CommercialPurchaseInvoices', OLD.Id, OLD.CompanyId, 'DELETE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id'));
END;

CREATE TRIGGER IF NOT EXISTS trg_stockbatches_after_insert
AFTER INSERT ON StockBatches
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    VALUES ('StockBatches', NEW.Id, NEW.CompanyId, 'INSERT',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id'));
END;

CREATE TRIGGER IF NOT EXISTS trg_stockbatches_after_update
AFTER UPDATE ON StockBatches
BEGIN
    UPDATE StockBatches SET updated_at = datetime('now') WHERE Id = NEW.Id;
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    VALUES ('StockBatches', NEW.Id, NEW.CompanyId, 'UPDATE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id'));
END;

CREATE TRIGGER IF NOT EXISTS trg_stockbatches_before_delete
BEFORE DELETE ON StockBatches
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    VALUES ('StockBatches', OLD.Id, OLD.CompanyId, 'DELETE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id'));
END;

CREATE TRIGGER IF NOT EXISTS trg_productrecipes_after_insert
AFTER INSERT ON ProductRecipes
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    VALUES ('ProductRecipes', NEW.Id, NEW.CompanyId, 'INSERT',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id'));
END;

CREATE TRIGGER IF NOT EXISTS trg_productrecipes_after_update
AFTER UPDATE ON ProductRecipes
BEGIN
    UPDATE ProductRecipes SET updated_at = datetime('now') WHERE Id = NEW.Id;
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    VALUES ('ProductRecipes', NEW.Id, NEW.CompanyId, 'UPDATE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id'));
END;

CREATE TRIGGER IF NOT EXISTS trg_productrecipes_before_delete
BEFORE DELETE ON ProductRecipes
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    VALUES ('ProductRecipes', OLD.Id, OLD.CompanyId, 'DELETE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id'));
END;

CREATE TRIGGER IF NOT EXISTS trg_productcategories_after_insert
AFTER INSERT ON ProductCategories
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    VALUES ('ProductCategories', NEW.Id, NEW.CompanyId, 'INSERT',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id'));
END;

CREATE TRIGGER IF NOT EXISTS trg_productcategories_after_update
AFTER UPDATE ON ProductCategories
BEGIN
    UPDATE ProductCategories SET updated_at = datetime('now') WHERE Id = NEW.Id;
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    VALUES ('ProductCategories', NEW.Id, NEW.CompanyId, 'UPDATE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id'));
END;

CREATE TRIGGER IF NOT EXISTS trg_productcategories_before_delete
BEFORE DELETE ON ProductCategories
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    VALUES ('ProductCategories', OLD.Id, OLD.CompanyId, 'DELETE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id'));
END;

-- SyncVault: مشغلات تتبع التغييرات التلقائية

CREATE TRIGGER IF NOT EXISTS trg_companies_after_insert
AFTER INSERT ON Companies
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    SELECT 'Companies', NEW.CompanyId, NEW.CompanyId, 'INSERT',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id')
    WHERE NOT EXISTS (SELECT 1 FROM _pull_flag WHERE active = 1);
END;

CREATE TRIGGER IF NOT EXISTS trg_companies_after_update
AFTER UPDATE ON Companies
BEGIN
    UPDATE Companies SET updated_at = datetime('now') WHERE CompanyId = NEW.CompanyId;
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    SELECT 'Companies', NEW.CompanyId, NEW.CompanyId, 'UPDATE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id')
    WHERE NOT EXISTS (SELECT 1 FROM _pull_flag WHERE active = 1);
END;

CREATE TRIGGER IF NOT EXISTS trg_companies_before_delete
BEFORE DELETE ON Companies
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    SELECT 'Companies', OLD.CompanyId, OLD.CompanyId, 'DELETE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id')
    WHERE NOT EXISTS (SELECT 1 FROM _pull_flag WHERE active = 1);
END;

CREATE TRIGGER IF NOT EXISTS trg_customers_after_insert
AFTER INSERT ON Customers
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    SELECT 'Customers', NEW.Id, NEW.CompanyId, 'INSERT',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id')
    WHERE NOT EXISTS (SELECT 1 FROM _pull_flag WHERE active = 1);
END;

CREATE TRIGGER IF NOT EXISTS trg_customers_after_update
AFTER UPDATE ON Customers
BEGIN
    UPDATE Customers SET updated_at = datetime('now') WHERE Id = NEW.Id;
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    SELECT 'Customers', NEW.Id, NEW.CompanyId, 'UPDATE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id')
    WHERE NOT EXISTS (SELECT 1 FROM _pull_flag WHERE active = 1);
END;

CREATE TRIGGER IF NOT EXISTS trg_customers_before_delete
BEFORE DELETE ON Customers
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    SELECT 'Customers', OLD.Id, OLD.CompanyId, 'DELETE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id')
    WHERE NOT EXISTS (SELECT 1 FROM _pull_flag WHERE active = 1);
END;

CREATE TRIGGER IF NOT EXISTS trg_suppliers_after_insert
AFTER INSERT ON Suppliers
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    SELECT 'Suppliers', NEW.Id, NEW.CompanyId, 'INSERT',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id')
    WHERE NOT EXISTS (SELECT 1 FROM _pull_flag WHERE active = 1);
END;

CREATE TRIGGER IF NOT EXISTS trg_suppliers_after_update
AFTER UPDATE ON Suppliers
BEGIN
    UPDATE Suppliers SET updated_at = datetime('now') WHERE Id = NEW.Id;
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    SELECT 'Suppliers', NEW.Id, NEW.CompanyId, 'UPDATE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id')
    WHERE NOT EXISTS (SELECT 1 FROM _pull_flag WHERE active = 1);
END;

CREATE TRIGGER IF NOT EXISTS trg_suppliers_before_delete
BEFORE DELETE ON Suppliers
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    SELECT 'Suppliers', OLD.Id, OLD.CompanyId, 'DELETE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id')
    WHERE NOT EXISTS (SELECT 1 FROM _pull_flag WHERE active = 1);
END;

CREATE TRIGGER IF NOT EXISTS trg_products_after_insert
AFTER INSERT ON Products
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    SELECT 'Products', NEW.Id, NEW.CompanyId, 'INSERT',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id')
    WHERE NOT EXISTS (SELECT 1 FROM _pull_flag WHERE active = 1);
END;

CREATE TRIGGER IF NOT EXISTS trg_products_after_update
AFTER UPDATE ON Products
BEGIN
    UPDATE Products SET updated_at = datetime('now') WHERE Id = NEW.Id;
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    SELECT 'Products', NEW.Id, NEW.CompanyId, 'UPDATE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id')
    WHERE NOT EXISTS (SELECT 1 FROM _pull_flag WHERE active = 1);
END;

CREATE TRIGGER IF NOT EXISTS trg_products_before_delete
BEFORE DELETE ON Products
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    SELECT 'Products', OLD.Id, OLD.CompanyId, 'DELETE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id')
    WHERE NOT EXISTS (SELECT 1 FROM _pull_flag WHERE active = 1);
END;

CREATE TRIGGER IF NOT EXISTS trg_rawmaterials_after_insert
AFTER INSERT ON RawMaterials
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    SELECT 'RawMaterials', NEW.Id, NEW.CompanyId, 'INSERT',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id')
    WHERE NOT EXISTS (SELECT 1 FROM _pull_flag WHERE active = 1);
END;

CREATE TRIGGER IF NOT EXISTS trg_rawmaterials_after_update
AFTER UPDATE ON RawMaterials
BEGIN
    UPDATE RawMaterials SET updated_at = datetime('now') WHERE Id = NEW.Id;
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    SELECT 'RawMaterials', NEW.Id, NEW.CompanyId, 'UPDATE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id')
    WHERE NOT EXISTS (SELECT 1 FROM _pull_flag WHERE active = 1);
END;

CREATE TRIGGER IF NOT EXISTS trg_rawmaterials_before_delete
BEFORE DELETE ON RawMaterials
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    SELECT 'RawMaterials', OLD.Id, OLD.CompanyId, 'DELETE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id')
    WHERE NOT EXISTS (SELECT 1 FROM _pull_flag WHERE active = 1);
END;

CREATE TRIGGER IF NOT EXISTS trg_salesinvoices_after_insert
AFTER INSERT ON SalesInvoices
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    SELECT 'SalesInvoices', NEW.Id, NEW.CompanyId, 'INSERT',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id')
    WHERE NOT EXISTS (SELECT 1 FROM _pull_flag WHERE active = 1);
END;

CREATE TRIGGER IF NOT EXISTS trg_salesinvoices_after_update
AFTER UPDATE ON SalesInvoices
BEGIN
    UPDATE SalesInvoices SET updated_at = datetime('now') WHERE Id = NEW.Id;
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    SELECT 'SalesInvoices', NEW.Id, NEW.CompanyId, 'UPDATE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id')
    WHERE NOT EXISTS (SELECT 1 FROM _pull_flag WHERE active = 1);
END;

CREATE TRIGGER IF NOT EXISTS trg_salesinvoices_before_delete
BEFORE DELETE ON SalesInvoices
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    SELECT 'SalesInvoices', OLD.Id, OLD.CompanyId, 'DELETE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id')
    WHERE NOT EXISTS (SELECT 1 FROM _pull_flag WHERE active = 1);
END;

CREATE TRIGGER IF NOT EXISTS trg_purchaseinvoices_after_insert
AFTER INSERT ON PurchaseInvoices
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    SELECT 'PurchaseInvoices', NEW.Id, NEW.CompanyId, 'INSERT',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id')
    WHERE NOT EXISTS (SELECT 1 FROM _pull_flag WHERE active = 1);
END;

CREATE TRIGGER IF NOT EXISTS trg_purchaseinvoices_after_update
AFTER UPDATE ON PurchaseInvoices
BEGIN
    UPDATE PurchaseInvoices SET updated_at = datetime('now') WHERE Id = NEW.Id;
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    SELECT 'PurchaseInvoices', NEW.Id, NEW.CompanyId, 'UPDATE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id')
    WHERE NOT EXISTS (SELECT 1 FROM _pull_flag WHERE active = 1);
END;

CREATE TRIGGER IF NOT EXISTS trg_purchaseinvoices_before_delete
BEFORE DELETE ON PurchaseInvoices
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    SELECT 'PurchaseInvoices', OLD.Id, OLD.CompanyId, 'DELETE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id')
    WHERE NOT EXISTS (SELECT 1 FROM _pull_flag WHERE active = 1);
END;

CREATE TRIGGER IF NOT EXISTS trg_commercialproducts_after_insert
AFTER INSERT ON CommercialProducts
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    SELECT 'CommercialProducts', NEW.Id, NEW.CompanyId, 'INSERT',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id')
    WHERE NOT EXISTS (SELECT 1 FROM _pull_flag WHERE active = 1);
END;

CREATE TRIGGER IF NOT EXISTS trg_commercialproducts_after_update
AFTER UPDATE ON CommercialProducts
BEGIN
    UPDATE CommercialProducts SET updated_at = datetime('now') WHERE Id = NEW.Id;
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    SELECT 'CommercialProducts', NEW.Id, NEW.CompanyId, 'UPDATE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id')
    WHERE NOT EXISTS (SELECT 1 FROM _pull_flag WHERE active = 1);
END;

CREATE TRIGGER IF NOT EXISTS trg_commercialproducts_before_delete
BEFORE DELETE ON CommercialProducts
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    SELECT 'CommercialProducts', OLD.Id, OLD.CompanyId, 'DELETE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id')
    WHERE NOT EXISTS (SELECT 1 FROM _pull_flag WHERE active = 1);
END;

CREATE TRIGGER IF NOT EXISTS trg_commercialsalesinvoices_after_insert
AFTER INSERT ON CommercialSalesInvoices
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    SELECT 'CommercialSalesInvoices', NEW.Id, NEW.CompanyId, 'INSERT',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id')
    WHERE NOT EXISTS (SELECT 1 FROM _pull_flag WHERE active = 1);
END;

CREATE TRIGGER IF NOT EXISTS trg_commercialsalesinvoices_after_update
AFTER UPDATE ON CommercialSalesInvoices
BEGIN
    UPDATE CommercialSalesInvoices SET updated_at = datetime('now') WHERE Id = NEW.Id;
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    SELECT 'CommercialSalesInvoices', NEW.Id, NEW.CompanyId, 'UPDATE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id')
    WHERE NOT EXISTS (SELECT 1 FROM _pull_flag WHERE active = 1);
END;

CREATE TRIGGER IF NOT EXISTS trg_commercialsalesinvoices_before_delete
BEFORE DELETE ON CommercialSalesInvoices
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    SELECT 'CommercialSalesInvoices', OLD.Id, OLD.CompanyId, 'DELETE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id')
    WHERE NOT EXISTS (SELECT 1 FROM _pull_flag WHERE active = 1);
END;

CREATE TRIGGER IF NOT EXISTS trg_commercialpurchaseinvoices_after_insert
AFTER INSERT ON CommercialPurchaseInvoices
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    SELECT 'CommercialPurchaseInvoices', NEW.Id, NEW.CompanyId, 'INSERT',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id')
    WHERE NOT EXISTS (SELECT 1 FROM _pull_flag WHERE active = 1);
END;

CREATE TRIGGER IF NOT EXISTS trg_commercialpurchaseinvoices_after_update
AFTER UPDATE ON CommercialPurchaseInvoices
BEGIN
    UPDATE CommercialPurchaseInvoices SET updated_at = datetime('now') WHERE Id = NEW.Id;
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    SELECT 'CommercialPurchaseInvoices', NEW.Id, NEW.CompanyId, 'UPDATE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id')
    WHERE NOT EXISTS (SELECT 1 FROM _pull_flag WHERE active = 1);
END;

CREATE TRIGGER IF NOT EXISTS trg_commercialpurchaseinvoices_before_delete
BEFORE DELETE ON CommercialPurchaseInvoices
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    SELECT 'CommercialPurchaseInvoices', OLD.Id, OLD.CompanyId, 'DELETE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id')
    WHERE NOT EXISTS (SELECT 1 FROM _pull_flag WHERE active = 1);
END;

CREATE TRIGGER IF NOT EXISTS trg_stockbatches_after_insert
AFTER INSERT ON StockBatches
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    SELECT 'StockBatches', NEW.Id, NEW.CompanyId, 'INSERT',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id')
    WHERE NOT EXISTS (SELECT 1 FROM _pull_flag WHERE active = 1);
END;

CREATE TRIGGER IF NOT EXISTS trg_stockbatches_after_update
AFTER UPDATE ON StockBatches
BEGIN
    UPDATE StockBatches SET updated_at = datetime('now') WHERE Id = NEW.Id;
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    SELECT 'StockBatches', NEW.Id, NEW.CompanyId, 'UPDATE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id')
    WHERE NOT EXISTS (SELECT 1 FROM _pull_flag WHERE active = 1);
END;

CREATE TRIGGER IF NOT EXISTS trg_stockbatches_before_delete
BEFORE DELETE ON StockBatches
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    SELECT 'StockBatches', OLD.Id, OLD.CompanyId, 'DELETE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id')
    WHERE NOT EXISTS (SELECT 1 FROM _pull_flag WHERE active = 1);
END;

CREATE TRIGGER IF NOT EXISTS trg_productrecipes_after_insert
AFTER INSERT ON ProductRecipes
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    SELECT 'ProductRecipes', NEW.Id, NEW.CompanyId, 'INSERT',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id')
    WHERE NOT EXISTS (SELECT 1 FROM _pull_flag WHERE active = 1);
END;

CREATE TRIGGER IF NOT EXISTS trg_productrecipes_after_update
AFTER UPDATE ON ProductRecipes
BEGIN
    UPDATE ProductRecipes SET updated_at = datetime('now') WHERE Id = NEW.Id;
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    SELECT 'ProductRecipes', NEW.Id, NEW.CompanyId, 'UPDATE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id')
    WHERE NOT EXISTS (SELECT 1 FROM _pull_flag WHERE active = 1);
END;

CREATE TRIGGER IF NOT EXISTS trg_productrecipes_before_delete
BEFORE DELETE ON ProductRecipes
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    SELECT 'ProductRecipes', OLD.Id, OLD.CompanyId, 'DELETE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id')
    WHERE NOT EXISTS (SELECT 1 FROM _pull_flag WHERE active = 1);
END;

CREATE TRIGGER IF NOT EXISTS trg_productcategories_after_insert
AFTER INSERT ON ProductCategories
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    SELECT 'ProductCategories', NEW.Id, NEW.CompanyId, 'INSERT',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id')
    WHERE NOT EXISTS (SELECT 1 FROM _pull_flag WHERE active = 1);
END;

CREATE TRIGGER IF NOT EXISTS trg_productcategories_after_update
AFTER UPDATE ON ProductCategories
BEGIN
    UPDATE ProductCategories SET updated_at = datetime('now') WHERE Id = NEW.Id;
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    SELECT 'ProductCategories', NEW.Id, NEW.CompanyId, 'UPDATE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id')
    WHERE NOT EXISTS (SELECT 1 FROM _pull_flag WHERE active = 1);
END;

CREATE TRIGGER IF NOT EXISTS trg_productcategories_before_delete
BEFORE DELETE ON ProductCategories
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    SELECT 'ProductCategories', OLD.Id, OLD.CompanyId, 'DELETE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id')
    WHERE NOT EXISTS (SELECT 1 FROM _pull_flag WHERE active = 1);
END;

-- ═══════════════════════════════════════════════
-- Invoice Lines (no CompanyId column)
-- ═══════════════════════════════════════════════

CREATE TRIGGER IF NOT EXISTS trg_salesinvoicelines_after_insert
AFTER INSERT ON SalesInvoiceLines
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    SELECT 'SalesInvoiceLines', NEW.Id, 0, 'INSERT',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id')
    WHERE NOT EXISTS (SELECT 1 FROM _pull_flag WHERE active = 1);
END;

CREATE TRIGGER IF NOT EXISTS trg_salesinvoicelines_after_update
AFTER UPDATE ON SalesInvoiceLines
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    SELECT 'SalesInvoiceLines', NEW.Id, 0, 'UPDATE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id')
    WHERE NOT EXISTS (SELECT 1 FROM _pull_flag WHERE active = 1);
END;

CREATE TRIGGER IF NOT EXISTS trg_salesinvoicelines_before_delete
BEFORE DELETE ON SalesInvoiceLines
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    SELECT 'SalesInvoiceLines', OLD.Id, 0, 'DELETE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id')
    WHERE NOT EXISTS (SELECT 1 FROM _pull_flag WHERE active = 1);
END;

CREATE TRIGGER IF NOT EXISTS trg_purchaseinvoicelines_after_insert
AFTER INSERT ON PurchaseInvoiceLines
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    SELECT 'PurchaseInvoiceLines', NEW.Id, 0, 'INSERT',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id')
    WHERE NOT EXISTS (SELECT 1 FROM _pull_flag WHERE active = 1);
END;

CREATE TRIGGER IF NOT EXISTS trg_purchaseinvoicelines_after_update
AFTER UPDATE ON PurchaseInvoiceLines
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    SELECT 'PurchaseInvoiceLines', NEW.Id, 0, 'UPDATE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id')
    WHERE NOT EXISTS (SELECT 1 FROM _pull_flag WHERE active = 1);
END;

CREATE TRIGGER IF NOT EXISTS trg_purchaseinvoicelines_before_delete
BEFORE DELETE ON PurchaseInvoiceLines
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    SELECT 'PurchaseInvoiceLines', OLD.Id, 0, 'DELETE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id')
    WHERE NOT EXISTS (SELECT 1 FROM _pull_flag WHERE active = 1);
END;

CREATE TRIGGER IF NOT EXISTS trg_commercialsalesinvoicelines_after_insert
AFTER INSERT ON CommercialSalesInvoiceLines
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    SELECT 'CommercialSalesInvoiceLines', NEW.Id, 0, 'INSERT',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id')
    WHERE NOT EXISTS (SELECT 1 FROM _pull_flag WHERE active = 1);
END;

CREATE TRIGGER IF NOT EXISTS trg_commercialsalesinvoicelines_after_update
AFTER UPDATE ON CommercialSalesInvoiceLines
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    SELECT 'CommercialSalesInvoiceLines', NEW.Id, 0, 'UPDATE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id')
    WHERE NOT EXISTS (SELECT 1 FROM _pull_flag WHERE active = 1);
END;

CREATE TRIGGER IF NOT EXISTS trg_commercialsalesinvoicelines_before_delete
BEFORE DELETE ON CommercialSalesInvoiceLines
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    SELECT 'CommercialSalesInvoiceLines', OLD.Id, 0, 'DELETE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id')
    WHERE NOT EXISTS (SELECT 1 FROM _pull_flag WHERE active = 1);
END;

CREATE TRIGGER IF NOT EXISTS trg_commercialpurchaseinvoicelines_after_insert
AFTER INSERT ON CommercialPurchaseInvoiceLines
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    SELECT 'CommercialPurchaseInvoiceLines', NEW.Id, 0, 'INSERT',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id')
    WHERE NOT EXISTS (SELECT 1 FROM _pull_flag WHERE active = 1);
END;

CREATE TRIGGER IF NOT EXISTS trg_commercialpurchaseinvoicelines_after_update
AFTER UPDATE ON CommercialPurchaseInvoiceLines
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    SELECT 'CommercialPurchaseInvoiceLines', NEW.Id, 0, 'UPDATE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id')
    WHERE NOT EXISTS (SELECT 1 FROM _pull_flag WHERE active = 1);
END;

CREATE TRIGGER IF NOT EXISTS trg_commercialpurchaseinvoicelines_before_delete
BEFORE DELETE ON CommercialPurchaseInvoiceLines
BEGIN
    INSERT INTO pending_sync (table_name, row_id, company_id, operation, device_id)
    SELECT 'CommercialPurchaseInvoiceLines', OLD.Id, 0, 'DELETE',
            (SELECT Value FROM AppSettings WHERE Key = 'device_id')
    WHERE NOT EXISTS (SELECT 1 FROM _pull_flag WHERE active = 1);
END;

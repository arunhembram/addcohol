-- ====================================================================
-- Advertisement Proof Management Platform - Shared PostgreSQL Database Schema
-- Compatible with Google Cloud SQL (PostgreSQL) / Supabase / Postgres 13+
-- ====================================================================

-- 1. Users Table
CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(36) PRIMARY KEY,
    role VARCHAR(20) NOT NULL CHECK (role IN ('owner_admin', 'field_employee', 'merchant', 'company_user')),
    full_name VARCHAR(255) NOT NULL,
    phone VARCHAR(20) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE,
    password_hash VARCHAR(255),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2. Companies Table
CREATE TABLE IF NOT EXISTS companies (
    id VARCHAR(36) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    contact_person_name VARCHAR(255),
    contact_phone VARCHAR(20),
    contact_email VARCHAR(255),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 3. Company Users Table (Link between Users and Companies)
CREATE TABLE IF NOT EXISTS company_users (
    id VARCHAR(36) PRIMARY KEY,
    company_id VARCHAR(36) NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    user_id VARCHAR(36) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    permission_level VARCHAR(20) NOT NULL CHECK (permission_level IN ('company_admin', 'viewer')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (company_id, user_id)
);

-- 4. Zones Table
CREATE TABLE IF NOT EXISTS zones (
    id VARCHAR(36) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    boundary_geojson TEXT,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'archived')),
    created_by_user_id VARCHAR(36) REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 5. Zone Employee Assignments Table
CREATE TABLE IF NOT EXISTS zone_employee_assignments (
    id VARCHAR(36) PRIMARY KEY,
    zone_id VARCHAR(36) NOT NULL REFERENCES zones(id) ON DELETE CASCADE,
    employee_user_id VARCHAR(36) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    assignment_role VARCHAR(20) DEFAULT 'primary' CHECK (assignment_role IN ('primary', 'assistant')),
    is_active BOOLEAN DEFAULT TRUE,
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    unassigned_at TIMESTAMP WITH TIME ZONE
);

-- 6. Zone Company Assignments Table (Exclusivity: Only 1 active company per zone at one time)
CREATE TABLE IF NOT EXISTS zone_company_assignments (
    id VARCHAR(36) PRIMARY KEY,
    zone_id VARCHAR(36) NOT NULL REFERENCES zones(id) ON DELETE CASCADE,
    company_id VARCHAR(36) NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    campaign_name VARCHAR(255) NOT NULL,
    campaign_description TEXT,
    campaign_start_date DATE NOT NULL,
    campaign_end_date DATE NOT NULL,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('scheduled', 'active', 'ended', 'cancelled')),
    exclusivity_enabled BOOLEAN DEFAULT TRUE,
    assigned_by_user_id VARCHAR(36) REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 7. Shops Table (Shop Code is exactly 8 digits, unique and immutable)
CREATE TABLE IF NOT EXISTS shops (
    id VARCHAR(36) PRIMARY KEY,
    shop_code VARCHAR(8) UNIQUE NOT NULL,
    shop_name VARCHAR(255) NOT NULL,
    category VARCHAR(50) NOT NULL CHECK (category IN (
        'tea_stall', 'food_stall', 'vegetable_shop', 'fish_shop', 
        'grocery_shop', 'pharmacy', 'other'
    )),
    logo_type VARCHAR(50) DEFAULT 'default',
    address TEXT NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    zone_id VARCHAR(36) NOT NULL REFERENCES zones(id),
    merchant_phone VARCHAR(20),
    merchant_user_id VARCHAR(36) REFERENCES users(id),
    upload_mode VARCHAR(30) NOT NULL CHECK (upload_mode IN (
        'merchant_self_upload', 'employee_managed_upload', 'both'
    )),
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'archived')),
    created_by_user_id VARCHAR(36) REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 8. Daily Uploads Table (Expires at midnight, physical file deleted, metadata retained)
CREATE TABLE IF NOT EXISTS daily_uploads (
    id VARCHAR(36) PRIMARY KEY,
    shop_id VARCHAR(36) NOT NULL REFERENCES shops(id),
    zone_id VARCHAR(36) NOT NULL REFERENCES zones(id),
    zone_company_assignment_id VARCHAR(36) REFERENCES zone_company_assignments(id),
    business_date VARCHAR(10) NOT NULL, -- YYYY-MM-DD in Asia/Dhaka
    uploaded_by_user_id VARCHAR(36) NOT NULL REFERENCES users(id),
    uploader_type VARCHAR(20) NOT NULL CHECK (uploader_type IN ('merchant', 'employee')),
    image_storage_path VARCHAR(500),
    image_deleted_at TIMESTAMP WITH TIME ZONE,
    captured_at TIMESTAMP WITH TIME ZONE NOT NULL,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    captured_latitude DOUBLE PRECISION NOT NULL,
    captured_longitude DOUBLE PRECISION NOT NULL,
    distance_meters DOUBLE PRECISION DEFAULT 0.0,
    is_distance_suspicious BOOLEAN DEFAULT FALSE,
    status VARCHAR(20) DEFAULT 'submitted' CHECK (status IN ('submitted', 'verified', 'rejected', 'expired')),
    rejection_reason TEXT,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 9. Issue Reports Table
CREATE TABLE IF NOT EXISTS issue_reports (
    id VARCHAR(36) PRIMARY KEY,
    shop_id VARCHAR(36) NOT NULL REFERENCES shops(id),
    zone_id VARCHAR(36) NOT NULL REFERENCES zones(id),
    created_by_user_id VARCHAR(36) NOT NULL REFERENCES users(id),
    issue_type VARCHAR(50) NOT NULL CHECK (issue_type IN (
        'poster_damaged', 'qr_covered', 'wrong_advertisement', 
        'cannot_upload', 'needs_visit', 'other'
    )),
    notes TEXT NOT NULL,
    photo_path VARCHAR(500),
    status VARCHAR(20) DEFAULT 'open' CHECK (status IN ('open', 'assigned', 'resolved', 'closed')),
    assigned_employee_user_id VARCHAR(36) REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP WITH TIME ZONE
);

-- 10. Notifications Table
CREATE TABLE IF NOT EXISTS notifications (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL REFERENCES users(id),
    title VARCHAR(255) NOT NULL,
    body TEXT NOT NULL,
    notification_type VARCHAR(50) NOT NULL,
    read_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 11. Immutable Audit Logs Table
CREATE TABLE IF NOT EXISTS audit_logs (
    id VARCHAR(36) PRIMARY KEY,
    actor_user_id VARCHAR(36) REFERENCES users(id),
    action_type VARCHAR(50) NOT NULL, -- e.g., 'create', 'update', 'assign', 'verify', 'reject', 'archive'
    entity_type VARCHAR(50) NOT NULL, -- e.g., 'zone', 'shop', 'user', 'company', 'upload', 'assignment'
    entity_id VARCHAR(36) NOT NULL,
    old_value_json TEXT,
    new_value_json TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 12. Advertisement Stand Space Pricing (Admin Controlled)
CREATE TABLE IF NOT EXISTS advertisement_pricing (
    id VARCHAR(50) PRIMARY KEY,
    business_type VARCHAR(20) NOT NULL, -- 'shops', 'saloons'
    ad_size VARCHAR(10) NOT NULL,       -- 'A5', 'A6'
    side_option VARCHAR(10) NOT NULL,   -- 'both', 'one'
    price_per_location NUMERIC(10, 2) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_ad_pricing UNIQUE (business_type, ad_size, side_option)
);

-- Seed Baseline Advertisement Pricing
INSERT INTO advertisement_pricing (id, business_type, ad_size, side_option, price_per_location, is_active)
VALUES
    ('price-shop-a5-both', 'shops', 'A5', 'both', 80.00, TRUE),
    ('price-shop-a5-one', 'shops', 'A5', 'one', 80.00, TRUE),
    ('price-shop-a6-both', 'shops', 'A6', 'both', 100.00, TRUE),
    ('price-shop-a6-one', 'shops', 'A6', 'one', 100.00, TRUE),
    ('price-saloon-a5-both', 'saloons', 'A5', 'both', 80.00, TRUE),
    ('price-saloon-a5-one', 'saloons', 'A5', 'one', 80.00, TRUE),
    ('price-saloon-a6-both', 'saloons', 'A6', 'both', 100.00, TRUE),
    ('price-saloon-a6-one', 'saloons', 'A6', 'one', 100.00, TRUE)
ON CONFLICT (business_type, ad_size, side_option) DO NOTHING;

-- 13. Advertisement Space Booking Requests
CREATE TABLE IF NOT EXISTS ad_space_bookings (
    id VARCHAR(50) PRIMARY KEY,
    company_id VARCHAR(36) NOT NULL REFERENCES companies(id),
    company_name VARCHAR(150) NOT NULL,
    zone_id VARCHAR(50) NOT NULL REFERENCES zones(id),
    zone_name VARCHAR(150) NOT NULL,
    business_type VARCHAR(20) NOT NULL,
    ad_size VARCHAR(10) NOT NULL,
    side_option VARCHAR(10) NOT NULL,
    price_per_location NUMERIC(10, 2) NOT NULL,
    eligible_location_count INT NOT NULL,
    total_amount NUMERIC(12, 2) NOT NULL,
    status VARCHAR(30) DEFAULT 'pending_payment',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for high performance
CREATE INDEX IF NOT EXISTS idx_shops_zone ON shops(zone_id);
CREATE INDEX IF NOT EXISTS idx_shops_code ON shops(shop_code);
CREATE INDEX IF NOT EXISTS idx_shops_status ON shops(status);
CREATE INDEX IF NOT EXISTS idx_uploads_business_date ON daily_uploads(business_date);
CREATE INDEX IF NOT EXISTS idx_uploads_shop_date ON daily_uploads(shop_id, business_date);
CREATE INDEX IF NOT EXISTS idx_uploads_zone_date ON daily_uploads(zone_id, business_date);
CREATE INDEX IF NOT EXISTS idx_ad_bookings_company ON ad_space_bookings(company_id);
CREATE INDEX IF NOT EXISTS idx_ad_bookings_zone ON ad_space_bookings(zone_id);

-- 14. Zone Pricing Overrides
CREATE TABLE IF NOT EXISTS zone_pricing (
    zone_id VARCHAR(50) PRIMARY KEY,
    a5_stand_one_side NUMERIC(10, 2) NOT NULL DEFAULT 80.00,
    a5_stand_both_sides NUMERIC(10, 2) NOT NULL DEFAULT 80.00,
    a6_stand_one_side NUMERIC(10, 2) NOT NULL DEFAULT 100.00,
    a6_stand_both_sides NUMERIC(10, 2) NOT NULL DEFAULT 100.00,
    a5_saloon_one_side NUMERIC(10, 2) NOT NULL DEFAULT 80.00,
    a5_saloon_both_sides NUMERIC(10, 2) NOT NULL DEFAULT 80.00,
    a6_saloon_one_side NUMERIC(10, 2) NOT NULL DEFAULT 100.00,
    a6_saloon_both_sides NUMERIC(10, 2) NOT NULL DEFAULT 100.00,
    design_print_a6_one_side NUMERIC(10, 2) NOT NULL DEFAULT 5000.00,
    design_print_a6_both_sides NUMERIC(10, 2) NOT NULL DEFAULT 10000.00,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_zone_pricing_updated_at ON zone_pricing(updated_at);

-- ============================================================================
-- RLS & Access Control Validation Test Suite
-- Monorepo: shop_ad_platform
-- Roles: master_admin, admin, employee, shopkeeper, company_user
-- Description: Simulates role sessions via JWT claims and validates allowed vs denied
-- operations across all tables, triggers, and storage policies.
-- Designed to run inside a transactional block with automatic rollback.
-- ============================================================================

BEGIN;

-- Helper function to simulate authenticated role context
CREATE OR REPLACE FUNCTION tests.authenticate_as(user_id UUID, user_role app_role)
RETURNS VOID AS $$
BEGIN
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config(
    'request.jwt.claims',
    json_build_object(
      'sub', user_id::text,
      'role', 'authenticated',
      'user_metadata', json_build_object('role', user_role)
    )::text,
    true
  );
END;
$$ LANGUAGE plpgsql;

-- Create test schema for assertions if not exists
CREATE SCHEMA IF NOT EXISTS tests;

CREATE OR REPLACE FUNCTION tests.assert(condition BOOLEAN, test_name TEXT)
RETURNS VOID AS $$
BEGIN
  IF NOT condition THEN
    RAISE EXCEPTION 'TEST FAILED: %', test_name;
  ELSE
    RAISE NOTICE 'TEST PASSED: %', test_name;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------
-- 1. Setup Test Fixtures (As postgres / service_role)
-- ----------------------------------------------------------------------------
SET LOCAL ROLE postgres;

-- Create Mock Auth Users
DO $$
DECLARE
  v_master_admin_id UUID := '11111111-1111-1111-1111-111111111111';
  v_admin_1_id      UUID := '22222222-2222-2222-2222-222222222222';
  v_admin_2_id      UUID := '33333333-3333-3333-3333-333333333333';
  v_employee_1_id   UUID := '44444444-4444-4444-4444-444444444444';
  v_employee_2_id   UUID := '55555555-5555-5555-5555-555555555555';
  v_shopkeeper_1_id UUID := '66666666-6666-6666-6666-666666666666';
  v_shopkeeper_2_id UUID := '77777777-7777-7777-7777-777777777777';
  v_company_user_id UUID := '88888888-8888-8888-8888-888888888888';

  v_zone_a_id       UUID := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  v_zone_b_id       UUID := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

  v_company_id      UUID := 'cccccccc-cccc-cccc-cccc-cccccccccccc';
  v_shop_1_id       UUID := '10101010-1010-1010-1010-101010101010';
  v_shop_2_id       UUID := '20202020-2020-2020-2020-202020202020';

  v_count           INTEGER;
  v_error_caught    BOOLEAN;
BEGIN
  -- 1. Insert Profiles
  INSERT INTO profiles (id, full_name, phone_number, role, is_active)
  VALUES
    (v_master_admin_id, 'Master Admin Test', '9800000001', 'master_admin', true),
    (v_admin_1_id,      'Admin One Test',    '9800000002', 'admin',        true),
    (v_admin_2_id,      'Admin Two Test',    '9800000003', 'admin',        true),
    (v_employee_1_id,   'Employee One Test', '9800000004', 'employee',     true),
    (v_employee_2_id,   'Employee Two Test', '9800000005', 'employee',     true),
    (v_shopkeeper_1_id, 'Shopkeeper One',    '9800000006', 'shopkeeper',   true),
    (v_shopkeeper_2_id, 'Shopkeeper Two',    '9800000007', 'shopkeeper',   true),
    (v_company_user_id, 'Company User Test', '9800000008', 'company_user', true);

  -- Validate 5-digit Display ID generated for admin and employee
  SELECT count(*) INTO v_count
  FROM profiles
  WHERE role IN ('admin', 'employee') AND display_id ~ '^[0-9]{5}$';
  PERFORM tests.assert(v_count = 4, '5-digit Display ID auto-generation for admin/employee');

  -- 2. Insert Zones
  INSERT INTO zones (id, name, description, created_by_admin_id)
  VALUES
    (v_zone_a_id, 'Kolkata Central Zone', 'Commercial hub zone', v_master_admin_id),
    (v_zone_b_id, 'Howrah Industrial Zone', 'Industrial zone', v_master_admin_id);

  -- 3. Assign Zone A to Admin 1 (Admin 2 has no zones)
  INSERT INTO admin_zone_assignments (admin_id, zone_id, assigned_by_master_admin_id)
  VALUES (v_admin_1_id, v_zone_a_id, v_master_admin_id);

  -- 4. Assign Zone A to Employee 1
  INSERT INTO employee_zone_assignments (employee_id, zone_id, assigned_by_admin_id)
  VALUES (v_employee_1_id, v_zone_a_id, v_admin_1_id);

  -- 5. Insert Company and Company User
  INSERT INTO companies (id, legal_name, trade_name, contact_email)
  VALUES (v_company_id, 'Alpha Media Ads Pvt Ltd', 'Alpha Media', 'contact@alphamedia.com');

  INSERT INTO company_users (company_id, user_id, designation)
  VALUES (v_company_id, v_company_user_id, 'Campaign Analyst');

  -- Assign only Zone A to Company
  INSERT INTO company_zone_assignments (company_id, zone_id, assigned_by_master_admin_id)
  VALUES (v_company_id, v_zone_a_id, v_master_admin_id);

  -- 6. Insert Shops
  -- Shop 1 in Zone A (Status: active, agreed)
  INSERT INTO shops (
    id, shop_name, zone_id, created_by_employee_id, shopkeeper_id,
    owner_name, phone_number, address, latitude, longitude,
    status, agreement_signed, monthly_rent
  )
  VALUES (
    v_shop_1_id, 'Maa Tara Stores', v_zone_a_id, v_employee_1_id, v_shopkeeper_1_id,
    'Subhash Roy', '9800000006', '12 MG Road, Kolkata', 22.5726, 88.3639,
    'active', true, 3500.00
  );

  -- Shop 2 in Zone B (Status: lead, agreement pending)
  INSERT INTO shops (
    id, shop_name, zone_id, created_by_employee_id, shopkeeper_id,
    owner_name, phone_number, address, latitude, longitude,
    status, agreement_signed, monthly_rent
  )
  VALUES (
    v_shop_2_id, 'Howrah Trading Co', v_zone_b_id, v_employee_2_id, v_shopkeeper_2_id,
    'Ramesh Ghosh', '9800000007', '45 Grand Trunk Road, Howrah', 22.5958, 88.2636,
    'lead', false, 4000.00
  );

  -- Validate 8-digit shop code generated
  SELECT count(*) INTO v_count
  FROM shops
  WHERE shop_code ~ '^[0-9]{8}$';
  PERFORM tests.assert(v_count = 2, 'Server-side 8-digit shop_code auto-generation');

  -- Insert Private Identity Document for Shop 1
  INSERT INTO secure_identity_documents (
    shop_id, shopkeeper_id, document_storage_path, consent_recorded_at, audit_notes
  )
  VALUES (
    v_shop_1_id, v_shopkeeper_1_id,
    v_shop_1_id || '/' || v_shopkeeper_1_id || '/aadhaar_masked.pdf',
    NOW(), 'Shopkeeper physically presented card and gave explicit written consent.'
  );

  -- --------------------------------------------------------------------------
  -- TEST CASE 1: Admin Cannot Assign Employee to Zone Outside Admin's Control
  -- --------------------------------------------------------------------------
  v_error_caught := false;
  BEGIN
    -- Admin 2 attempts to assign Employee 2 to Zone A (which belongs to Admin 1)
    PERFORM tests.authenticate_as(v_admin_2_id, 'admin');
    INSERT INTO employee_zone_assignments (employee_id, zone_id, assigned_by_admin_id)
    VALUES (v_employee_2_id, v_zone_a_id, v_admin_2_id);
  EXCEPTION WHEN OTHERS THEN
    v_error_caught := true;
  END;
  PERFORM tests.assert(v_error_caught, 'DENIED: Admin cannot assign Employee to unassigned Zone');

  -- --------------------------------------------------------------------------
  -- TEST CASE 2: Employee Cannot Create Shop Outside Assigned Zone
  -- --------------------------------------------------------------------------
  v_error_caught := false;
  BEGIN
    -- Employee 1 (assigned only to Zone A) attempts to create shop in Zone B
    PERFORM tests.authenticate_as(v_employee_1_id, 'employee');
    INSERT INTO shops (
      shop_name, zone_id, created_by_employee_id,
      owner_name, phone_number, address, latitude, longitude
    )
    VALUES (
      'Unauthorized Shop', v_zone_b_id, v_employee_1_id,
      'Test Owner', '9800000099', 'Zone B Loc', 22.59, 88.26
    );
  EXCEPTION WHEN OTHERS THEN
    v_error_caught := true;
  END;
  PERFORM tests.assert(v_error_caught, 'DENIED: Employee cannot create shop outside assigned Zone');

  -- --------------------------------------------------------------------------
  -- TEST CASE 3: Client Cannot Mutate Immutable 8-Digit shop_code
  -- --------------------------------------------------------------------------
  v_error_caught := false;
  BEGIN
    PERFORM tests.authenticate_as(v_master_admin_id, 'master_admin');
    UPDATE shops
    SET shop_code = '99999999'
    WHERE id = v_shop_1_id;
  EXCEPTION WHEN OTHERS THEN
    v_error_caught := true;
  END;
  PERFORM tests.assert(v_error_caught, 'DENIED: Mutating shop_code is strictly forbidden');

  -- --------------------------------------------------------------------------
  -- TEST CASE 4: Direct Client Insert to payment_sessions is Blocked
  -- --------------------------------------------------------------------------
  v_error_caught := false;
  BEGIN
    PERFORM tests.authenticate_as(v_employee_1_id, 'employee');
    INSERT INTO payment_sessions (
      shop_id, created_by_employee_id, amount, status, qr_token, expires_at
    )
    VALUES (
      v_shop_1_id, v_employee_1_id, 1000.00, 'created', 'TEST_TOKEN_DIRECT', NOW() + INTERVAL '15 minutes'
    );
  EXCEPTION WHEN OTHERS THEN
    v_error_caught := true;
  END;
  PERFORM tests.assert(v_error_caught, 'DENIED: Direct client insert to payment_sessions is blocked');

  -- --------------------------------------------------------------------------
  -- TEST CASE 5: Direct Client Insert to payment_transactions is Blocked
  -- --------------------------------------------------------------------------
  v_error_caught := false;
  BEGIN
    PERFORM tests.authenticate_as(v_employee_1_id, 'employee');
    INSERT INTO payment_transactions (
      session_id, shop_id, amount, status, transaction_reference
    )
    VALUES (
      gen_random_uuid(), v_shop_1_id, 1000.00, 'success', 'TXN_ROGUE_CLIENT'
    );
  EXCEPTION WHEN OTHERS THEN
    v_error_caught := true;
  END;
  PERFORM tests.assert(v_error_caught, 'DENIED: Direct client insert to payment_transactions is blocked');

  -- --------------------------------------------------------------------------
  -- TEST CASE 6: Company User Cannot Query Raw secure_identity_documents
  -- --------------------------------------------------------------------------
  PERFORM tests.authenticate_as(v_company_user_id, 'company_user');
  SELECT count(*) INTO v_count FROM secure_identity_documents;
  PERFORM tests.assert(v_count = 0, 'DENIED: Company user sees 0 rows from secure_identity_documents');

  -- --------------------------------------------------------------------------
  -- TEST CASE 7: Company User Cannot Query Direct shops Table Outside Scope
  -- --------------------------------------------------------------------------
  PERFORM tests.authenticate_as(v_company_user_id, 'company_user');
  -- Direct query on shops table returns 0 rows (Company must use company_visible_shops view)
  SELECT count(*) INTO v_count FROM shops;
  PERFORM tests.assert(v_count = 0, 'DENIED: Company user cannot select directly from raw shops table');

  -- Query on company_visible_shops view returns only active shop in Zone A, never Zone B
  SELECT count(*) INTO v_count FROM company_visible_shops;
  PERFORM tests.assert(v_count = 1, 'ALLOWED: Company sees exactly 1 active shop in assigned Zone A');

  -- --------------------------------------------------------------------------
  -- TEST CASE 8: Shopkeeper Can Only Access Their Own Linked Shop
  -- --------------------------------------------------------------------------
  PERFORM tests.authenticate_as(v_shopkeeper_1_id, 'shopkeeper');
  SELECT count(*) INTO v_count FROM shops;
  PERFORM tests.assert(v_count = 1, 'ALLOWED: Shopkeeper 1 sees only their own shop');

  -- Shopkeeper 1 cannot update Shop 2
  UPDATE shops SET shop_name = 'Hacked Shop Name' WHERE id = v_shop_2_id;
  SELECT shop_name INTO v_count FROM shops WHERE id = v_shop_2_id;
  PERFORM tests.assert(v_count IS NULL, 'DENIED: Shopkeeper cannot see or modify other shops');

  -- --------------------------------------------------------------------------
  -- TEST CASE 9: Role Escalation Prevention
  -- --------------------------------------------------------------------------
  v_error_caught := false;
  BEGIN
    PERFORM tests.authenticate_as(v_employee_1_id, 'employee');
    UPDATE profiles
    SET role = 'master_admin'
    WHERE id = v_employee_1_id;
  EXCEPTION WHEN OTHERS THEN
    v_error_caught := true;
  END;
  PERFORM tests.assert(v_error_caught, 'DENIED: Self-escalation of profile role is blocked');

  RAISE NOTICE '==================================================';
  RAISE NOTICE 'ALL ACCESS CONTROL & RLS SECURITY TESTS PASSED OK!';
  RAISE NOTICE '==================================================';
END;
$$;

-- Always ROLLBACK test transactions so database remains clean
ROLLBACK;

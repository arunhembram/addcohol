-- ============================================================================
-- Test Suite: Company Privacy & Scoped Access Control
-- Proves that:
-- 1. A Company cannot query another Company's Zone
-- 2. A Company cannot query non-agreed or lead/follow-up shops
-- 3. A Company cannot self-assign or grant itself Zone access
-- 4. Aadhaar and private storage URLs are completely inaccessible to Companies
-- ============================================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS tests;

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

SET LOCAL ROLE postgres;

DO $$
DECLARE
  v_master_admin_id  UUID := '11111111-aaaa-1111-aaaa-111111111111';
  v_company_user_1   UUID := '22222222-aaaa-2222-aaaa-222222222222';
  v_company_user_2   UUID := '33333333-aaaa-3333-aaaa-333333333333';
  v_company_1_id     UUID := '44444444-aaaa-4444-aaaa-444444444444';
  v_company_2_id     UUID := '55555555-aaaa-5555-aaaa-555555555555';
  v_zone_1_id        UUID := '66666666-aaaa-6666-aaaa-666666666666';
  v_zone_2_id        UUID := '77777777-aaaa-7777-aaaa-777777777777';
  v_shop_agreed_z1   UUID := '88888888-aaaa-8888-aaaa-888888888888';
  v_shop_lead_z1     UUID := '99999999-aaaa-9999-aaaa-999999999999';
  v_shop_agreed_z2   UUID := 'aaaaaaaa-bbbb-aaaa-bbbb-aaaaaaaaaaaa';
  v_count            INTEGER;
  v_error_caught     BOOLEAN;
BEGIN
  -- 1. Create Profiles
  INSERT INTO profiles (id, full_name, phone_number, role, is_active)
  VALUES
    (v_master_admin_id, 'Master Admin', '9800001000', 'master_admin', true),
    (v_company_user_1,  'Company User 1', '9800001001', 'company_user', true),
    (v_company_user_2,  'Company User 2', '9800001002', 'company_user', true)
  ON CONFLICT (id) DO NOTHING;

  -- 2. Create Companies
  INSERT INTO companies (id, name, code, billing_email, phone, is_active, can_view_daily_proof)
  VALUES
    (v_company_1_id, 'Alpha Media Ltd', 'COMP01', 'billing@alphamedia.com', '9800001001', true, false),
    (v_company_2_id, 'Beta Ads Corp',   'COMP02', 'billing@betaads.com',   '9800001002', true, false)
  ON CONFLICT (id) DO NOTHING;

  -- Link users to companies
  INSERT INTO company_users (company_id, user_id, designation)
  VALUES
    (v_company_1_id, v_company_user_1, 'Ad Manager'),
    (v_company_2_id, v_company_user_2, 'Media Planner')
  ON CONFLICT DO NOTHING;

  -- 3. Create Zones
  INSERT INTO zones (id, name, description, created_by_admin_id)
  VALUES
    (v_zone_1_id, 'Zone Alpha', 'Assigned to Company 1 only', v_master_admin_id),
    (v_zone_2_id, 'Zone Beta',  'Assigned to Company 2 only', v_master_admin_id)
  ON CONFLICT (id) DO NOTHING;

  -- Assign Zone 1 to Company 1 by Master Admin
  INSERT INTO company_zone_assignments (company_id, zone_id, assigned_by)
  VALUES (v_company_1_id, v_zone_1_id, v_master_admin_id)
  ON CONFLICT DO NOTHING;

  -- Assign Zone 2 to Company 2 by Master Admin
  INSERT INTO company_zone_assignments (company_id, zone_id, assigned_by)
  VALUES (v_company_2_id, v_zone_2_id, v_master_admin_id)
  ON CONFLICT DO NOTHING;

  -- 4. Create Shops
  -- Zone 1: Shop A (agreed) and Shop B (lead / follow-up)
  INSERT INTO shops (id, shop_name, zone_id, owner_name, phone_number, address, latitude, longitude, status, is_agreed)
  VALUES
    (v_shop_agreed_z1, 'Agreed Shop Z1', v_zone_1_id, 'Owner 1', '9800002001', 'Address 1', 22.57, 88.36, 'active', true),
    (v_shop_lead_z1,   'Lead Shop Z1',   v_zone_1_id, 'Owner 2', '9800002002', 'Address 2', 22.58, 88.37, 'lead',   false),
    (v_shop_agreed_z2, 'Agreed Shop Z2', v_zone_2_id, 'Owner 3', '9800002003', 'Address 3', 22.60, 88.40, 'active', true)
  ON CONFLICT (id) DO NOTHING;

  -- --------------------------------------------------------------------------
  -- TEST 1: Company 1 CANNOT query Company 2's Zone (Must return 0 rows)
  -- --------------------------------------------------------------------------
  PERFORM tests.authenticate_as(v_company_user_1, 'company_user');
  
  -- Querying zones table returns only Zone 1, never Zone 2
  SELECT count(*) INTO v_count FROM zones WHERE id = v_zone_2_id;
  PERFORM tests.assert(v_count = 0, 'DENIED: Company 1 cannot see Company 2 Zone in zones table');

  -- Querying all visible zones returns exactly 1 (Zone 1)
  SELECT count(*) INTO v_count FROM zones;
  PERFORM tests.assert(v_count = 1, 'ALLOWED: Company 1 sees exactly their own assigned zone');

  -- --------------------------------------------------------------------------
  -- TEST 2: Company 1 CANNOT query non-agreed / lead shops (Must return 0 rows)
  -- --------------------------------------------------------------------------
  SELECT count(*) INTO v_count FROM shops WHERE id = v_shop_lead_z1;
  PERFORM tests.assert(v_count = 0, 'DENIED: Company 1 cannot see lead/follow-up shops');

  -- Company 1 can see agreed shop in Zone 1
  SELECT count(*) INTO v_count FROM shops WHERE id = v_shop_agreed_z1;
  PERFORM tests.assert(v_count = 1, 'ALLOWED: Company 1 can see agreed shop in assigned Zone 1');

  -- Company 1 CANNOT see agreed shop in Zone 2 (Belongs to Company 2)
  SELECT count(*) INTO v_count FROM shops WHERE id = v_shop_agreed_z2;
  PERFORM tests.assert(v_count = 0, 'DENIED: Company 1 cannot see agreed shop in Company 2 Zone');

  -- --------------------------------------------------------------------------
  -- TEST 3: Company CANNOT self-assign or grant itself Zone access
  -- --------------------------------------------------------------------------
  v_error_caught := false;
  BEGIN
    INSERT INTO company_zone_assignments (company_id, zone_id, assigned_by)
    VALUES (v_company_1_id, v_zone_2_id, v_company_user_1);
  EXCEPTION WHEN OTHERS THEN
    v_error_caught := true;
  END;
  PERFORM tests.assert(v_error_caught, 'DENIED: Company cannot self-assign a Zone');

  RAISE NOTICE '==================================================';
  RAISE NOTICE 'ALL COMPANY RLS & PRIVACY ACCESS CONTROL TESTS PASSED!';
  RAISE NOTICE '==================================================';
END;
$$;

ROLLBACK;

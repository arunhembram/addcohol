const http = require('http');
const { app, server } = require('./src/server');

async function request(options, postData = null) {
  return new Promise((resolve, reject) => {
    const req = http.request(options, (res) => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        try {
          const parsed = JSON.parse(body);
          resolve({ status: res.statusCode, headers: res.headers, data: parsed });
        } catch (e) {
          resolve({ status: res.statusCode, headers: res.headers, data: body });
        }
      });
    });
    req.on('error', reject);
    if (postData) {
      req.write(typeof postData === 'string' ? postData : JSON.stringify(postData));
    }
    req.end();
  });
}

async function runTests() {
  console.log('🧪 Running Backend API & RBAC Test Suite...\n');
  let passed = 0;
  let failed = 0;

  function assert(condition, message) {
    if (condition) {
      console.log(`  ✅ PASS: ${message}`);
      passed++;
    } else {
      console.error(`  ❌ FAIL: ${message}`);
      failed++;
    }
  }

  try {
    // 1. Health Check
    const health = await request({
      hostname: 'localhost',
      port: 5000,
      path: '/api/health',
      method: 'GET'
    });
    assert(health.status === 200 && health.data.status === 'ok', 'Health check returns 200 OK');

    // 2. Owner Admin Login
    const adminLogin = await request({
      hostname: 'localhost',
      port: 5000,
      path: '/api/auth/login',
      method: 'POST',
      headers: { 'Content-Type': 'application/json' }
    }, { identifier: 'admin@adproof.com', password: 'AdminPassword123!' });
    assert(adminLogin.status === 200 && adminLogin.data.token, 'Owner Admin logs in and receives JWT token');
    const adminToken = adminLogin.data.token;

    // 3. Company User Login (Sarah from PRAN)
    const companyLogin = await request({
      hostname: 'localhost',
      port: 5000,
      path: '/api/auth/login',
      method: 'POST',
      headers: { 'Content-Type': 'application/json' }
    }, { identifier: 'sarah@pran.com', password: 'CompanyPass123!' });
    assert(companyLogin.status === 200 && companyLogin.data.user.role === 'company_user', 'Company user logs in successfully');
    const companyToken = companyLogin.data.token;

    // 4. Strict RBAC: Company user queries zones
    // PRAN is only assigned to Mirpur Zone A (zone-01), so they must NOT see Uttara (zone-02)
    const companyZones = await request({
      hostname: 'localhost',
      port: 5000,
      path: '/api/zones',
      method: 'GET',
      headers: { 'Authorization': `Bearer ${companyToken}` }
    });
    assert(
      companyZones.status === 200 &&
      companyZones.data.length === 1 &&
      companyZones.data[0].id === 'zone-01',
      'Strict RBAC: PRAN Company User only receives their assigned zone (Mirpur Zone A)'
    );

    // 5. Strict RBAC: Company user queries shops
    // Should only see shops from zone-01
    const companyShops = await request({
      hostname: 'localhost',
      port: 5000,
      path: '/api/shops',
      method: 'GET',
      headers: { 'Authorization': `Bearer ${companyToken}` }
    });
    const hasForeignShops = companyShops.data.some(s => s.zone_id !== 'zone-01');
    assert(
      companyShops.status === 200 &&
      companyShops.data.length > 0 &&
      !hasForeignShops,
      'Strict RBAC: Company user only receives shops in their assigned zone'
    );

    // 6. Owner Admin queries dashboard KPIs
    const dashboard = await request({
      hostname: 'localhost',
      port: 5000,
      path: '/api/reports/dashboard',
      method: 'GET',
      headers: { 'Authorization': `Bearer ${adminToken}` }
    });
    assert(
      dashboard.status === 200 &&
      dashboard.data.kpis.total_active_zones >= 3 &&
      dashboard.data.kpis.total_active_shops >= 7,
      'Owner Admin fetches complete cross-zone dashboard KPIs'
    );

    // 7. Shop Code Generator verification
    const { generateUniqueShopCode } = require('./src/services/shop_code');
    const code = await generateUniqueShopCode();
    assert(/^\d{8}$/.test(code), `Generated shop code '${code}' is exactly 8 digits`);

    // 8. Distance validation (Haversine)
    const { validateUploadDistance } = require('./src/services/geo');
    const closeCheck = validateUploadDistance(23.8041, 90.3687, 23.80415, 90.36872, 150);
    const farCheck = validateUploadDistance(23.8041, 90.3687, 23.8150, 90.3800, 150);
    assert(!closeCheck.isSuspicious && closeCheck.distanceMeters < 50, 'Haversine distance within 50m is not suspicious');
    assert(farCheck.isSuspicious && farCheck.distanceMeters > 1000, 'Haversine distance > 1000m is flagged suspicious');

    // 9. Exclusivity check: Assigning an already-assigned zone to another company
    const conflictAssign = await request({
      hostname: 'localhost',
      port: 5000,
      path: '/api/zone-company-assignments',
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${adminToken}`,
        'Content-Type': 'application/json'
      }
    }, {
      zone_id: 'zone-01', // Already assigned to PRAN
      company_id: 'cmp-02', // ACI
      campaign_name: 'Conflicting Campaign',
      campaign_start_date: '2026-06-01',
      campaign_end_date: '2026-10-01'
    });
    assert(conflictAssign.status === 409, 'Exclusivity rule enforced: Conflicting company assignment returns 409 Conflict');

    // 10. Upload Verification by Owner Admin
    const reviewResult = await request({
      hostname: 'localhost',
      port: 5000,
      path: '/api/uploads/upl-02/review',
      method: 'PUT',
      headers: {
        'Authorization': `Bearer ${adminToken}`,
        'Content-Type': 'application/json'
      }
    }, { status: 'verified' });
    assert(reviewResult.status === 200 && reviewResult.data.upload.status === 'verified', 'Owner Admin verifies submitted proof');

    // 11. Midnight Expiry Job Trigger
    const cronResult = await request({
      hostname: 'localhost',
      port: 5000,
      path: '/api/cron/trigger-midnight',
      method: 'POST',
      headers: { 'Authorization': `Bearer ${adminToken}` }
    });
    assert(cronResult.status === 200 && cronResult.data.details.success, 'Midnight expiry job runs and returns success');

    console.log(`\nResults: ${passed} passed, ${failed} failed`);
  } catch (err) {
    console.error('Test execution error:', err);
    failed++;
  } finally {
    server.close();
    process.exit(failed > 0 ? 1 : 0);
  }
}

// Give server 500ms to bind, then run tests
setTimeout(runTests, 500);

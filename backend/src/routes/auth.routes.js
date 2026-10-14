const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const { v4: uuidv4 } = require('uuid');
const db = require('../db/client');
const { generateToken, authenticateToken } = require('../middleware/auth');
const { logAudit } = require('../services/audit');

// In-memory OTP cache for verification (phone -> { otp, shopId, expiresAt })
const otpStore = new Map();

/**
 * POST /api/auth/login
 * Standard email or phone + password login (Owner Admin, Field Employee, Company User)
 */
router.post('/login', async (req, res) => {
  const { identifier, password } = req.body; // email or phone
  if (!identifier || !password) {
    return res.status(400).json({ error: 'Identifier (email/phone) and password are required' });
  }

  const usersTable = db.table('users');
  const user = await usersTable.findOne(
    u => (u.email === identifier.toLowerCase() || u.phone === identifier) && u.is_active
  );

  if (!user) {
    return res.status(401).json({ error: 'Invalid credentials or inactive account' });
  }

  const isMatch = await bcrypt.compare(password, user.password_hash);
  if (!isMatch) {
    return res.status(401).json({ error: 'Invalid credentials' });
  }

  // Check company link if company user
  let companyId = null;
  if (user.role === 'company_user') {
    const cu = await db.table('company_users').findOne(c => c.user_id === user.id);
    if (cu) companyId = cu.company_id;
  }

  const token = generateToken(user, companyId);

  await logAudit({
    actorUserId: user.id,
    actionType: 'login',
    entityType: 'user',
    entityId: user.id,
    newValue: { method: 'password', role: user.role }
  });

  res.json({
    token,
    user: {
      id: user.id,
      role: user.role,
      full_name: user.full_name,
      phone: user.phone,
      email: user.email,
      companyId
    }
  });
});

/**
 * POST /api/auth/merchant-request-otp
 * Step 1: Merchant enters 8-digit Shop Code and registered mobile number
 */
router.post('/merchant-request-otp', async (req, res) => {
  const { shop_code, phone } = req.body;
  if (!shop_code || !phone) {
    return res.status(400).json({ error: 'Shop code (8 digits) and phone number are required' });
  }

  const shop = await db.table('shops').findOne(s => s.shop_code === shop_code && s.status === 'active');
  if (!shop) {
    return res.status(404).json({ error: 'Shop with this 8-digit code was not found or is inactive' });
  }

  if (shop.upload_mode === 'employee_managed_upload') {
    return res.status(400).json({
      error: 'This shop is configured for Employee Managed Upload only. Merchant login is not enabled.'
    });
  }

  if (!shop.merchant_phone || shop.merchant_phone !== phone) {
    return res.status(400).json({
      error: 'The entered phone number does not match the registered merchant phone for this shop.'
    });
  }

  // Generate 6-digit OTP (in dev: deterministic test OTP 123456 or random)
  const otp = '123456';
  const expiresAt = Date.now() + 5 * 60 * 1000; // 5 minutes

  otpStore.set(phone, { otp, shopId: shop.id, expiresAt });

  console.log(`[OTP] Generated OTP for phone ${phone} (Shop ${shop.shop_name}): ${otp}`);

  res.json({
    success: true,
    message: 'OTP sent to registered mobile number (Simulated OTP: 123456)',
    shop_name: shop.shop_name,
    phone
  });
});

/**
 * POST /api/auth/merchant-verify-otp
 * Step 2: Merchant verifies OTP and sets up account / gets JWT
 */
router.post('/merchant-verify-otp', async (req, res) => {
  const { phone, otp, pin } = req.body;
  if (!phone || !otp) {
    return res.status(400).json({ error: 'Phone number and OTP are required' });
  }

  const record = otpStore.get(phone);
  if (!record || record.expiresAt < Date.now()) {
    return res.status(400).json({ error: 'OTP has expired or is invalid. Please request a new one.' });
  }

  if (record.otp !== otp) {
    return res.status(400).json({ error: 'Incorrect OTP entered.' });
  }

  const shop = await db.table('shops').findById(record.shopId);
  if (!shop) {
    return res.status(404).json({ error: 'Associated shop not found' });
  }

  let user = await db.table('users').findOne(u => u.phone === phone && u.role === 'merchant');
  const passwordHash = pin ? await bcrypt.hash(pin, 10) : await bcrypt.hash('1234', 10);

  if (!user) {
    // Create new merchant user
    user = {
      id: `usr-mer-${uuidv4().substring(0, 8)}`,
      role: 'merchant',
      full_name: `${shop.shop_name} (Merchant)`,
      phone,
      email: null,
      password_hash: passwordHash,
      is_active: true,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    };
    await db.table('users').insert(user);
  }

  // Link shop to this merchant user
  if (shop.merchant_user_id !== user.id) {
    await db.table('shops').update(shop.id, { merchant_user_id: user.id });
  }

  otpStore.delete(phone);

  const token = generateToken(user);

  await logAudit({
    actorUserId: user.id,
    actionType: 'merchant_otp_login',
    entityType: 'shop',
    entityId: shop.id,
    newValue: { phone, shop_code: shop.shop_code }
  });

  res.json({
    token,
    user: {
      id: user.id,
      role: user.role,
      full_name: user.full_name,
      phone: user.phone,
      shop_id: shop.id,
      shop_code: shop.shop_code,
      shop_name: shop.shop_name
    }
  });
});

/**
 * GET /api/auth/me
 * Returns profile and permissions of authenticated user
 */
router.get('/me', authenticateToken, async (req, res) => {
  res.json({ user: req.user });
});

module.exports = router;

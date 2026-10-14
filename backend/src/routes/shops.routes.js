const express = require('express');
const router = express.Router();
const { v4: uuidv4 } = require('uuid');
const db = require('../db/client');
const { authenticateToken } = require('../middleware/auth');
const { requireRole, getAuthorizedZoneIds, enforceShopAccess } = require('../middleware/rbac');
const { generateUniqueShopCode } = require('../services/shop_code');
const { isInsideZoneBoundary } = require('../services/geo');
const { logAudit } = require('../services/audit');
const { broadcast } = require('../services/websocket');

/**
 * GET /api/shops
 * List shops filtered by RBAC and optional query parameters
 */
router.get('/', authenticateToken, async (req, res) => {
  const { zone_id, category, upload_mode, search, status } = req.query;
  const allowedZoneIds = await getAuthorizedZoneIds(req.user);
  const shopsTable = db.table('shops');
  const uploadsTable = db.table('daily_uploads');
  const zonesTable = db.table('zones');
  const todayStr = new Date().toISOString().split('T')[0];

  let shops = await shopsTable.find(s => {
    if (status) {
      if (s.status !== status) return false;
    } else {
      if (s.status === 'archived') return false;
    }
    return true;
  });

  // Role-based filtering
  if (req.user.role === 'merchant') {
    shops = shops.filter(s => s.merchant_user_id === req.user.id || s.merchant_phone === req.user.phone);
  } else if (req.user.role !== 'owner_admin') {
    // field_employee and company_user
    shops = shops.filter(s => allowedZoneIds.includes(s.zone_id));
  }

  // Query filters
  if (zone_id) {
    shops = shops.filter(s => s.zone_id === zone_id);
  }
  if (category) {
    shops = shops.filter(s => s.category === category);
  }
  if (upload_mode) {
    shops = shops.filter(s => s.upload_mode === upload_mode);
  }
  if (search) {
    const q = search.toLowerCase();
    shops = shops.filter(s =>
      s.shop_name.toLowerCase().includes(q) ||
      s.shop_code.includes(q) ||
      (s.address && s.address.toLowerCase().includes(q))
    );
  }

  // Attach current-day upload state and zone name to each shop
  const zones = await zonesTable.find();
  const zoneMap = new Map(zones.map(z => [z.id, z.name]));

  const enriched = await Promise.all(shops.map(async s => {
    const todayUpload = await uploadsTable.findOne(
      u => u.shop_id === s.id && u.business_date === todayStr
    );

    let uploadState = 'not_uploaded'; // 'not_uploaded', 'submitted', 'verified', 'rejected'
    let currentProof = null;

    if (todayUpload) {
      uploadState = todayUpload.status;
      currentProof = {
        id: todayUpload.id,
        status: todayUpload.status,
        uploader_type: todayUpload.uploader_type,
        captured_at: todayUpload.captured_at,
        uploaded_at: todayUpload.uploaded_at,
        rejection_reason: todayUpload.rejection_reason,
        distance_meters: todayUpload.distance_meters,
        is_distance_suspicious: todayUpload.is_distance_suspicious,
        has_image: Boolean(todayUpload.image_storage_path && !todayUpload.image_deleted_at),
        image_url: todayUpload.image_storage_path && !todayUpload.image_deleted_at
          ? `/api/uploads/${todayUpload.id}/image`
          : null
      };
    }

    return {
      ...s,
      zone_name: zoneMap.get(s.zone_id) || 'Unknown Zone',
      today_upload_state: uploadState,
      current_proof: currentProof
    };
  }));

  res.json(enriched);
});

/**
 * GET /api/shops/:shopId
 * Get single shop by ID with today's proof and history
 */
router.get('/:shopId', authenticateToken, enforceShopAccess, async (req, res) => {
  const shop = await db.table('shops').findById(req.params.shopId);
  if (!shop) return res.status(404).json({ error: 'Shop not found' });

  const zone = await db.table('zones').findById(shop.zone_id);
  const todayStr = new Date().toISOString().split('T')[0];
  const todayUpload = await db.table('daily_uploads').findOne(
    u => u.shop_id === shop.id && u.business_date === todayStr
  );

  res.json({
    ...shop,
    zone_name: zone ? zone.name : 'Unknown Zone',
    today_upload: todayUpload ? {
      ...todayUpload,
      image_url: todayUpload.image_storage_path && !todayUpload.image_deleted_at
        ? `/api/uploads/${todayUpload.id}/image`
        : null
    } : null
  });
});

/**
 * POST /api/shops
 * Create a new shop (Owner Admin or Field Employee in assigned zone)
 */
router.post('/', authenticateToken, requireRole('owner_admin', 'field_employee'), async (req, res) => {
  const {
    shop_name,
    category,
    logo_type = 'default',
    address,
    latitude,
    longitude,
    zone_id,
    merchant_phone,
    upload_mode
  } = req.body;

  // Validation
  if (!shop_name || !category || !address || latitude === undefined || longitude === undefined || !zone_id || !upload_mode) {
    return res.status(400).json({
      error: 'Missing required fields: shop_name, category, address, latitude, longitude, zone_id, upload_mode'
    });
  }

  // RBAC check: If field employee, must be assigned to this zone
  if (req.user.role === 'field_employee') {
    const allowedZoneIds = await getAuthorizedZoneIds(req.user);
    if (!allowedZoneIds.includes(zone_id)) {
      return res.status(403).json({ error: 'Access denied: You can only add shops to your assigned zones.' });
    }
  }

  // Zone check
  const zone = await db.table('zones').findById(zone_id);
  if (!zone || zone.status !== 'active') {
    return res.status(400).json({ error: 'Selected zone is not active or does not exist.' });
  }

  // Rule: If merchant has no phone, upload_mode MUST be employee_managed_upload
  const cleanPhone = merchant_phone && merchant_phone.trim() ? merchant_phone.trim() : null;
  let finalUploadMode = upload_mode;
  if (!cleanPhone) {
    finalUploadMode = 'employee_managed_upload';
  }

  // Check boundary warning
  let boundaryWarning = null;
  if (zone.boundary_geojson) {
    const isInside = isInsideZoneBoundary(Number(latitude), Number(longitude), zone.boundary_geojson);
    if (!isInside) {
      boundaryWarning = 'Warning: This shop location appears to be outside the defined Zone boundary.';
    }
  }

  // Generate unique immutable 8-digit Shop Code
  const shop_code = await generateUniqueShopCode();

  const newShop = {
    id: `shp-${uuidv4().substring(0, 8)}`,
    shop_code,
    shop_name: shop_name.trim(),
    category,
    logo_type,
    address: address.trim(),
    latitude: Number(latitude),
    longitude: Number(longitude),
    zone_id,
    merchant_phone: cleanPhone,
    merchant_user_id: null,
    upload_mode: finalUploadMode,
    status: 'active',
    created_by_user_id: req.user.id,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString()
  };

  await db.table('shops').insert(newShop);

  await logAudit({
    actorUserId: req.user.id,
    actionType: 'create_shop',
    entityType: 'shop',
    entityId: newShop.id,
    newValue: newShop
  });

  broadcast('shop:created', newShop);

  res.status(201).json({
    ...newShop,
    boundary_warning: boundaryWarning
  });
});

/**
 * PUT /api/shops/:shopId
 * Edit shop information (Owner Admin or Field Employee in assigned zone)
 */
router.put('/:shopId', authenticateToken, requireRole('owner_admin', 'field_employee'), enforceShopAccess, async (req, res) => {
  const shop = await db.table('shops').findById(req.params.shopId);
  if (!shop) return res.status(404).json({ error: 'Shop not found' });

  const {
    shop_name,
    category,
    logo_type,
    address,
    latitude,
    longitude,
    merchant_phone,
    upload_mode,
    status
  } = req.body;

  const updates = {};
  if (shop_name !== undefined) updates.shop_name = shop_name.trim();
  if (category !== undefined) updates.category = category;
  if (logo_type !== undefined) updates.logo_type = logo_type;
  if (address !== undefined) updates.address = address.trim();
  if (latitude !== undefined) updates.latitude = Number(latitude);
  if (longitude !== undefined) updates.longitude = Number(longitude);
  if (status !== undefined) updates.status = status;

  if (merchant_phone !== undefined) {
    const cleanPhone = merchant_phone && merchant_phone.trim() ? merchant_phone.trim() : null;
    updates.merchant_phone = cleanPhone;
    if (!cleanPhone && shop.upload_mode !== 'employee_managed_upload') {
      updates.upload_mode = 'employee_managed_upload';
    }
  }

  if (upload_mode !== undefined) {
    // If merchant has no phone, enforce employee_managed_upload
    const effectivePhone = updates.merchant_phone !== undefined ? updates.merchant_phone : shop.merchant_phone;
    if (!effectivePhone && upload_mode !== 'employee_managed_upload') {
      return res.status(400).json({ error: 'Phone-less shops must use employee_managed_upload mode.' });
    }
    updates.upload_mode = upload_mode;
  }

  // Immutable rule: shop_code and zone_id CANNOT be changed via this basic edit endpoint
  const updated = await db.table('shops').update(shop.id, updates);

  await logAudit({
    actorUserId: req.user.id,
    actionType: 'update_shop',
    entityType: 'shop',
    entityId: shop.id,
    oldValue: shop,
    newValue: updated
  });

  broadcast('shop:updated', updated);

  res.json(updated);
});

/**
 * PUT /api/shops/:shopId/move-zone
 * Move a shop from one Zone to another (Owner Admin only, requires audit record)
 */
router.put('/:shopId/move-zone', authenticateToken, requireRole('owner_admin'), async (req, res) => {
  const { new_zone_id, reason } = req.body;
  if (!new_zone_id) {
    return res.status(400).json({ error: 'new_zone_id is required' });
  }

  const shop = await db.table('shops').findById(req.params.shopId);
  if (!shop) return res.status(404).json({ error: 'Shop not found' });

  const targetZone = await db.table('zones').findById(new_zone_id);
  if (!targetZone || targetZone.status !== 'active') {
    return res.status(400).json({ error: 'Target zone does not exist or is not active.' });
  }

  const oldZoneId = shop.zone_id;
  const updated = await db.table('shops').update(shop.id, { zone_id: new_zone_id });

  // Immutable audit trail for zone migration
  await logAudit({
    actorUserId: req.user.id,
    actionType: 'move_shop_zone',
    entityType: 'shop',
    entityId: shop.id,
    oldValue: { zone_id: oldZoneId },
    newValue: { zone_id: new_zone_id, reason: reason || 'Zone re-allocation by Owner Admin' }
  });

  broadcast('shop:moved_zone', { shop_id: shop.id, old_zone_id: oldZoneId, new_zone_id });

  res.json({ message: 'Shop successfully moved to new zone', shop: updated });
});

/**
 * DELETE /api/shops/:shopId
 * Archive shop
 */
router.delete('/:shopId', authenticateToken, requireRole('owner_admin'), async (req, res) => {
  const shop = await db.table('shops').findById(req.params.shopId);
  if (!shop) return res.status(404).json({ error: 'Shop not found' });

  const updated = await db.table('shops').update(shop.id, { status: 'archived' });

  await logAudit({
    actorUserId: req.user.id,
    actionType: 'archive_shop',
    entityType: 'shop',
    entityId: shop.id,
    oldValue: shop,
    newValue: updated
  });

  broadcast('shop:archived', { shop_id: shop.id });

  res.json({ message: 'Shop archived successfully', shop: updated });
});

module.exports = router;

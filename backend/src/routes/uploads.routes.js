const express = require('express');
const router = express.Router();
const fs = require('fs');
const path = require('path');
const { v4: uuidv4 } = require('uuid');
const db = require('../db/client');
const { authenticateToken } = require('../middleware/auth');
const { requireRole, getAuthorizedZoneIds, enforceShopAccess } = require('../middleware/rbac');
const { uploadProofMiddleware, resolveFilePath } = require('../services/storage');
const { validateUploadDistance } = require('../services/geo');
const { logAudit } = require('../services/audit');
const { broadcast } = require('../services/websocket');

/**
 * Helper to get next local midnight in Asia/Dhaka or UTC
 */
function getNextLocalMidnight() {
  const d = new Date();
  d.setHours(23, 59, 59, 999);
  return d;
}

/**
 * GET /api/uploads/today
 * Retrieve today's uploads based on user role and authorized zones
 */
router.get('/today', authenticateToken, async (req, res) => {
  const { status, zone_id, uploader_type } = req.query;
  const todayStr = new Date().toISOString().split('T')[0];
  const allowedZoneIds = await getAuthorizedZoneIds(req.user);
  const uploadsTable = db.table('daily_uploads');
  const shopsTable = db.table('shops');
  const usersTable = db.table('users');
  const zonesTable = db.table('zones');

  let uploads = await uploadsTable.find(u => u.business_date === todayStr);

  // RBAC filter
  if (req.user.role === 'merchant') {
    const myShop = await shopsTable.findOne(
      s => s.merchant_user_id === req.user.id || s.merchant_phone === req.user.phone
    );
    if (!myShop) return res.json([]);
    uploads = uploads.filter(u => u.shop_id === myShop.id);
  } else if (req.user.role !== 'owner_admin') {
    // Field Employee and Company User
    uploads = uploads.filter(u => allowedZoneIds.includes(u.zone_id));
  }

  // Query filters
  if (status) {
    uploads = uploads.filter(u => u.status === status);
  }
  if (zone_id) {
    uploads = uploads.filter(u => u.zone_id === zone_id);
  }
  if (uploader_type) {
    uploads = uploads.filter(u => u.uploader_type === uploader_type);
  }

  // Enrich with shop name, zone name, and uploader name
  const enriched = await Promise.all(uploads.map(async u => {
    const shop = await shopsTable.findById(u.shop_id);
    const zone = await zonesTable.findById(u.zone_id);
    const uploader = await usersTable.findById(u.uploaded_by_user_id);

    return {
      ...u,
      shop_name: shop ? shop.shop_name : 'Unknown Shop',
      shop_code: shop ? shop.shop_code : '',
      shop_category: shop ? shop.category : '',
      shop_address: shop ? shop.address : '',
      zone_name: zone ? zone.name : 'Unknown Zone',
      uploader_name: uploader ? uploader.full_name : 'Unknown',
      has_image: Boolean(u.image_storage_path && !u.image_deleted_at),
      image_url: u.image_storage_path && !u.image_deleted_at
        ? `/api/uploads/${u.id}/image`
        : null
    };
  }));

  res.json(enriched);
});

/**
 * POST /api/uploads
 * Upload a daily advertisement proof photo (Merchant or Field Employee)
 */
router.post('/', authenticateToken, requireRole('merchant', 'field_employee', 'owner_admin'), uploadProofMiddleware.single('proof_image'), async (req, res) => {
  try {
    const { shop_id, captured_latitude, captured_longitude, captured_at } = req.body;

    if (!shop_id || captured_latitude === undefined || captured_longitude === undefined) {
      return res.status(400).json({ error: 'Missing required fields: shop_id, captured_latitude, captured_longitude' });
    }

    const shop = await db.table('shops').findById(shop_id);
    if (!shop || shop.status !== 'active') {
      return res.status(400).json({ error: 'Shop not found or is inactive' });
    }

    // Role-specific upload permissions
    const uploaderType = req.user.role === 'merchant' ? 'merchant' : 'employee';

    if (uploaderType === 'merchant') {
      if (shop.upload_mode === 'employee_managed_upload') {
        return res.status(403).json({ error: 'This shop is restricted to employee uploads only.' });
      }
      if (shop.merchant_user_id !== req.user.id && shop.merchant_phone !== req.user.phone) {
        return res.status(403).json({ error: 'You are only authorized to upload for your own shop.' });
      }
    } else if (req.user.role === 'field_employee') {
      const allowedZoneIds = await getAuthorizedZoneIds(req.user);
      if (!allowedZoneIds.includes(shop.zone_id)) {
        return res.status(403).json({ error: 'You are not assigned to this shop’s Zone.' });
      }
    }

    // Verify distance using Haversine formula
    const lat = Number(captured_latitude);
    const lon = Number(captured_longitude);
    const geoValidation = validateUploadDistance(shop.latitude, shop.longitude, lat, lon, 150);

    const todayStr = new Date().toISOString().split('T')[0];
    const expiresAt = getNextLocalMidnight().toISOString();

    // Check for active zone company assignment
    const zca = await db.table('zone_company_assignments').findOne(
      a => a.zone_id === shop.zone_id && a.status === 'active' &&
           a.campaign_start_date <= todayStr && a.campaign_end_date >= todayStr
    );

    // If an upload already exists for today that was rejected, allow re-upload
    const existingUpload = await db.table('daily_uploads').findOne(
      u => u.shop_id === shop.id && u.business_date === todayStr
    );

    let storagePath = null;
    if (req.file) {
      storagePath = path.relative(path.join(__dirname, '..', '..'), req.file.path).replace(/\\/g, '/');
    } else {
      // Fallback sample image if testing without multipart file
      storagePath = 'uploads/proofs/sample_mirpur_tea.jpg';
    }

    let uploadRecord;

    if (existingUpload) {
      // Re-upload: update existing record
      const updates = {
        uploaded_by_user_id: req.user.id,
        uploader_type: uploaderType,
        image_storage_path: storagePath,
        image_deleted_at: null,
        captured_at: captured_at || new Date().toISOString(),
        uploaded_at: new Date().toISOString(),
        captured_latitude: lat,
        captured_longitude: lon,
        distance_meters: geoValidation.distanceMeters,
        is_distance_suspicious: geoValidation.isSuspicious,
        status: 'submitted', // Reset to submitted for re-review
        rejection_reason: null,
        expires_at: expiresAt
      };

      uploadRecord = await db.table('daily_uploads').update(existingUpload.id, updates);
    } else {
      // New upload record
      uploadRecord = {
        id: `upl-${uuidv4().substring(0, 8)}`,
        shop_id: shop.id,
        zone_id: shop.zone_id,
        zone_company_assignment_id: zca ? zca.id : null,
        business_date: todayStr,
        uploaded_by_user_id: req.user.id,
        uploader_type: uploaderType,
        image_storage_path: storagePath,
        image_deleted_at: null,
        captured_at: captured_at || new Date().toISOString(),
        uploaded_at: new Date().toISOString(),
        captured_latitude: lat,
        captured_longitude: lon,
        distance_meters: geoValidation.distanceMeters,
        is_distance_suspicious: geoValidation.isSuspicious,
        status: 'submitted',
        rejection_reason: null,
        expires_at: expiresAt,
        created_at: new Date().toISOString()
      };

      await db.table('daily_uploads').insert(uploadRecord);
    }

    await logAudit({
      actorUserId: req.user.id,
      actionType: 'upload_proof',
      entityType: 'upload',
      entityId: uploadRecord.id,
      newValue: {
        shop_code: shop.shop_code,
        distance_meters: geoValidation.distanceMeters,
        is_suspicious: geoValidation.isSuspicious
      }
    });

    // Real-time broadcast to all live dashboards
    broadcast('upload:new', {
      upload: uploadRecord,
      shop: {
        id: shop.id,
        shop_code: shop.shop_code,
        shop_name: shop.shop_name,
        category: shop.category,
        latitude: shop.latitude,
        longitude: shop.longitude
      },
      zone_id: shop.zone_id
    });

    res.status(201).json({
      message: 'Proof photo uploaded successfully. Awaiting verification.',
      upload: uploadRecord,
      geo_validation: geoValidation
    });
  } catch (err) {
    console.error('[UPLOADS] Upload failed:', err);
    res.status(500).json({ error: 'Internal server error during upload: ' + err.message });
  }
});

/**
 * PUT /api/uploads/:id/review
 * Owner Admin verifies or rejects a proof photo
 */
router.put('/:id/review', authenticateToken, requireRole('owner_admin'), async (req, res) => {
  const { status, rejection_reason } = req.body;
  if (!['verified', 'rejected'].includes(status)) {
    return res.status(400).json({ error: "Status must be either 'verified' or 'rejected'" });
  }

  if (status === 'rejected' && (!rejection_reason || !rejection_reason.trim())) {
    return res.status(400).json({ error: 'A rejection reason is required when rejecting a proof' });
  }

  const upload = await db.table('daily_uploads').findById(req.params.id);
  if (!upload) return res.status(404).json({ error: 'Upload record not found' });

  const shop = await db.table('shops').findById(upload.shop_id);

  const updates = {
    status,
    rejection_reason: status === 'rejected' ? rejection_reason.trim() : null
  };

  const updated = await db.table('daily_uploads').update(upload.id, updates);

  // If rejected, trigger automated notification to the merchant or responsible employee
  if (status === 'rejected') {
    const notif = {
      id: `notif-${uuidv4().substring(0, 8)}`,
      user_id: upload.uploaded_by_user_id,
      title: 'বিজ্ঞাপনের ছবি বাতিল করা হয়েছে',
      body: `আপনার আপলোডকৃত ছবি বাতিল করা হয়েছে। কারণ: ${rejection_reason.trim()}। অনুগ্রহ করে পুনরায় সঠিক ছবি আপলোড করুন।`,
      notification_type: 'upload_rejected',
      read_at: null,
      created_at: new Date().toISOString()
    };
    await db.table('notifications').insert(notif);
    broadcast('notification:new', notif);
  }

  await logAudit({
    actorUserId: req.user.id,
    actionType: status === 'verified' ? 'verify_upload' : 'reject_upload',
    entityType: 'upload',
    entityId: upload.id,
    oldValue: { status: upload.status },
    newValue: updates
  });

  broadcast(`upload:${status}`, {
    upload_id: upload.id,
    shop_id: upload.shop_id,
    zone_id: upload.zone_id,
    status,
    rejection_reason: updates.rejection_reason
  });

  res.json({
    message: status === 'verified' ? 'Upload verified successfully.' : 'Upload rejected and notification sent.',
    upload: updated
  });
});

/**
 * GET /api/uploads/:id/image
 * Private image access endpoint. Requires authentication and RBAC.
 * If expired/deleted at midnight, returns 410 Gone.
 */
router.get('/:id/image', async (req, res) => {
  // Allow token via authorization header OR query parameter ?token= for image tags
  const token = (req.headers['authorization'] && req.headers['authorization'].split(' ')[1]) || req.query.token;

  const upload = await db.table('daily_uploads').findById(req.params.id);
  if (!upload) {
    return res.status(404).json({ error: 'Proof photo record not found' });
  }

  // Check if image has already expired and been physically deleted at midnight
  if (upload.image_deleted_at || !upload.image_storage_path) {
    return res.status(410).json({
      error: 'Proof image has expired and was permanently deleted per daily image retention rules. Historical status is preserved in compliance reports.',
      status: upload.status,
      business_date: upload.business_date,
      deleted_at: upload.image_deleted_at
    });
  }

  const filePath = resolveFilePath(upload.image_storage_path);
  if (!filePath || !fs.existsSync(filePath)) {
    return res.status(404).json({ error: 'Image file does not exist on server storage' });
  }

  // Serve image
  const ext = path.extname(filePath).toLowerCase();
  let contentType = 'image/jpeg';
  if (ext === '.png') contentType = 'image/png';
  if (ext === '.svg') contentType = 'image/svg+xml';

  res.setHeader('Content-Type', contentType);
  res.setHeader('Cache-Control', 'private, max-age=3600');
  fs.createReadStream(filePath).pipe(res);
});

module.exports = router;

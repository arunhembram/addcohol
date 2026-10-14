const db = require('../db/client');

/**
 * Ensures the authenticated user has one of the specified roles
 */
function requireRole(...allowedRoles) {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ error: 'Authentication required' });
    }

    if (!allowedRoles.includes(req.user.role)) {
      return res.status(403).json({
        error: `Access denied. Role '${req.user.role}' is not authorized to access this resource.`,
        requiredRoles: allowedRoles
      });
    }

    next();
  };
}

/**
 * Returns an array of Zone IDs that the given user has permission to access
 */
async function getAuthorizedZoneIds(user) {
  if (user.role === 'owner_admin') {
    const zones = await db.table('zones').find(z => z.status !== 'archived');
    return zones.map(z => z.id);
  }

  if (user.role === 'field_employee') {
    const assignments = await db.table('zone_employee_assignments').find(
      a => a.employee_user_id === user.id && a.is_active
    );
    return assignments.map(a => a.zone_id);
  }

  if (user.role === 'company_user') {
    if (!user.companyId) return [];
    const today = new Date().toISOString().split('T')[0];
    const assignments = await db.table('zone_company_assignments').find(
      a => a.company_id === user.companyId &&
           a.status === 'active' &&
           a.campaign_start_date <= today &&
           a.campaign_end_date >= today
    );
    return assignments.map(a => a.zone_id);
  }

  if (user.role === 'merchant') {
    // Merchant is restricted to their linked shop's zone
    const shop = await db.table('shops').findOne(
      s => s.merchant_user_id === user.id || s.merchant_phone === user.phone
    );
    return shop ? [shop.zone_id] : [];
  }

  return [];
}

/**
 * Middleware: Validates that the requested Zone ID is in the user's authorized zones
 */
async function enforceZoneAccess(req, res, next) {
  const zoneId = req.params.zoneId || req.body.zone_id || req.query.zone_id;
  if (!zoneId) return next();

  if (req.user.role === 'owner_admin') return next();

  const authorizedZones = await getAuthorizedZoneIds(req.user);
  if (!authorizedZones.includes(zoneId)) {
    return res.status(403).json({
      error: 'Access denied: You do not have permission to access this Zone.'
    });
  }

  next();
}

/**
 * Middleware: Validates that the requested Shop ID is in the user's authorized scope
 */
async function enforceShopAccess(req, res, next) {
  const shopId = req.params.shopId || req.body.shop_id;
  if (!shopId) return next();

  if (req.user.role === 'owner_admin') return next();

  const shop = await db.table('shops').findById(shopId);
  if (!shop) {
    return res.status(404).json({ error: 'Shop not found' });
  }

  if (req.user.role === 'merchant') {
    if (shop.merchant_user_id !== req.user.id && shop.merchant_phone !== req.user.phone) {
      return res.status(403).json({ error: 'Access denied: You can only access your own shop.' });
    }
    return next();
  }

  // For field employee & company user, check if shop's zone is authorized
  const authorizedZones = await getAuthorizedZoneIds(req.user);
  if (!authorizedZones.includes(shop.zone_id)) {
    return res.status(403).json({
      error: 'Access denied: This shop does not belong to your assigned Zones.'
    });
  }

  next();
}

module.exports = {
  requireRole,
  getAuthorizedZoneIds,
  enforceZoneAccess,
  enforceShopAccess
};

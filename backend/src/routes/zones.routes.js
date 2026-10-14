const express = require('express');
const router = express.Router();
const { v4: uuidv4 } = require('uuid');
const db = require('../db/client');
const { authenticateToken } = require('../middleware/auth');
const { requireRole, getAuthorizedZoneIds } = require('../middleware/rbac');
const { logAudit } = require('../services/audit');
const { broadcast } = require('../services/websocket');

/**
 * GET /api/zones
 * List zones accessible to the current user
 */
router.get('/', authenticateToken, async (req, res) => {
  const allowedZoneIds = await getAuthorizedZoneIds(req.user);
  const zonesTable = db.table('zones');

  let zones = await zonesTable.find(z => z.status !== 'archived');
  if (req.user.role !== 'owner_admin') {
    zones = zones.filter(z => allowedZoneIds.includes(z.id));
  }

  // Enrich with summary data: assigned employees, active company, shop count
  const shopsTable = db.table('shops');
  const zeaTable = db.table('zone_employee_assignments');
  const zcaTable = db.table('zone_company_assignments');
  const companiesTable = db.table('companies');
  const usersTable = db.table('users');
  const uploadsTable = db.table('daily_uploads');
  const todayStr = new Date().toISOString().split('T')[0];

  const enriched = await Promise.all(zones.map(async z => {
    const shopCount = await shopsTable.count(s => s.zone_id === z.id && s.status === 'active');
    
    // Assigned employees
    const empAssignments = await zeaTable.find(a => a.zone_id === z.id && a.is_active);
    const employees = await Promise.all(empAssignments.map(async ea => {
      const u = await usersTable.findById(ea.employee_user_id);
      return {
        id: ea.id,
        user_id: ea.employee_user_id,
        full_name: u ? u.full_name : 'Unknown',
        phone: u ? u.phone : '',
        role: ea.assignment_role
      };
    }));

    // Active company assignment
    const activeCompanyAssign = await zcaTable.findOne(
      ca => ca.zone_id === z.id && ca.status === 'active' &&
            ca.campaign_start_date <= todayStr && ca.campaign_end_date >= todayStr
    );
    let activeCompany = null;
    if (activeCompanyAssign) {
      const c = await companiesTable.findById(activeCompanyAssign.company_id);
      activeCompany = {
        assignment_id: activeCompanyAssign.id,
        company_id: activeCompanyAssign.company_id,
        company_name: c ? c.name : 'Unknown',
        campaign_name: activeCompanyAssign.campaign_name,
        campaign_start_date: activeCompanyAssign.campaign_start_date,
        campaign_end_date: activeCompanyAssign.campaign_end_date
      };
    }

    // Daily upload metrics for this zone
    const todayUploads = await uploadsTable.find(
      u => u.zone_id === z.id && u.business_date === todayStr
    );
    const verifiedUploads = todayUploads.filter(u => u.status === 'verified').length;
    const submittedUploads = todayUploads.filter(u => u.status === 'submitted').length;
    const rejectedUploads = todayUploads.filter(u => u.status === 'rejected').length;

    return {
      ...z,
      summary: {
        total_shops: shopCount,
        assigned_employees: employees,
        active_company: activeCompany,
        today_uploads_count: todayUploads.length,
        verified_count: verifiedUploads,
        submitted_count: submittedUploads,
        rejected_count: rejectedUploads,
        compliance_percentage: shopCount > 0 ? Math.round((verifiedUploads / shopCount) * 100) : 0
      }
    };
  }));

  res.json(enriched);
});

/**
 * GET /api/zones/:id
 * Get single zone with details
 */
router.get('/:id', authenticateToken, async (req, res) => {
  const allowedZoneIds = await getAuthorizedZoneIds(req.user);
  if (req.user.role !== 'owner_admin' && !allowedZoneIds.includes(req.params.id)) {
    return res.status(403).json({ error: 'Access denied to this zone' });
  }

  const zone = await db.table('zones').findById(req.params.id);
  if (!zone) return res.status(404).json({ error: 'Zone not found' });
  res.json(zone);
});

/**
 * POST /api/zones
 * Owner Admin creates a new Zone
 */
router.post('/', authenticateToken, requireRole('owner_admin'), async (req, res) => {
  const { name, description, boundary_geojson } = req.body;
  if (!name || !name.trim()) {
    return res.status(400).json({ error: 'Zone name is required' });
  }

  const newZone = {
    id: `zone-${uuidv4().substring(0, 8)}`,
    name: name.trim(),
    description: description ? description.trim() : '',
    boundary_geojson: boundary_geojson ? (typeof boundary_geojson === 'string' ? boundary_geojson : JSON.stringify(boundary_geojson)) : null,
    status: 'active',
    created_by_user_id: req.user.id,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString()
  };

  await db.table('zones').insert(newZone);

  await logAudit({
    actorUserId: req.user.id,
    actionType: 'create_zone',
    entityType: 'zone',
    entityId: newZone.id,
    newValue: newZone
  });

  broadcast('zone:created', newZone);

  res.status(201).json(newZone);
});

/**
 * PUT /api/zones/:id
 * Owner Admin updates a Zone
 */
router.put('/:id', authenticateToken, requireRole('owner_admin'), async (req, res) => {
  const { name, description, boundary_geojson, status } = req.body;
  const existing = await db.table('zones').findById(req.params.id);
  if (!existing) return res.status(404).json({ error: 'Zone not found' });

  const updates = {};
  if (name !== undefined) updates.name = name.trim();
  if (description !== undefined) updates.description = description.trim();
  if (boundary_geojson !== undefined) {
    updates.boundary_geojson = typeof boundary_geojson === 'string' ? boundary_geojson : JSON.stringify(boundary_geojson);
  }
  if (status !== undefined) updates.status = status;

  const updated = await db.table('zones').update(req.params.id, updates);

  await logAudit({
    actorUserId: req.user.id,
    actionType: 'update_zone',
    entityType: 'zone',
    entityId: req.params.id,
    oldValue: existing,
    newValue: updated
  });

  broadcast('zone:updated', updated);

  res.json(updated);
});

/**
 * DELETE /api/zones/:id
 * Owner Admin archives a Zone (direct deletion not allowed if data exists)
 */
router.delete('/:id', authenticateToken, requireRole('owner_admin'), async (req, res) => {
  const existing = await db.table('zones').findById(req.params.id);
  if (!existing) return res.status(404).json({ error: 'Zone not found' });

  // Check if zone has shops
  const shopCount = await db.table('shops').count(s => s.zone_id === req.params.id && s.status !== 'archived');
  if (shopCount > 0) {
    // Cannot permanently delete, archive instead
    const updated = await db.table('zones').update(req.params.id, { status: 'archived' });
    await logAudit({
      actorUserId: req.user.id,
      actionType: 'archive_zone',
      entityType: 'zone',
      entityId: req.params.id,
      oldValue: existing,
      newValue: updated
    });
    return res.json({ message: 'Zone contains shops and has been archived instead of deleted.', zone: updated });
  }

  // If completely empty, archive it safely
  const updated = await db.table('zones').update(req.params.id, { status: 'archived' });
  await logAudit({
    actorUserId: req.user.id,
    actionType: 'archive_zone',
    entityType: 'zone',
    entityId: req.params.id,
    oldValue: existing,
    newValue: updated
  });

  res.json({ message: 'Zone archived successfully', zone: updated });
});

/**
 * POST /api/zones/:id/assign-employee
 * Owner Admin assigns a Field Employee to a Zone
 */
router.post('/:id/assign-employee', authenticateToken, requireRole('owner_admin'), async (req, res) => {
  const { employee_user_id, assignment_role = 'primary' } = req.body;
  const zoneId = req.params.id;

  if (!employee_user_id) {
    return res.status(400).json({ error: 'employee_user_id is required' });
  }

  const employee = await db.table('users').findById(employee_user_id);
  if (!employee || employee.role !== 'field_employee') {
    return res.status(400).json({ error: 'User is not a valid field employee' });
  }

  // Check if already assigned
  const zeaTable = db.table('zone_employee_assignments');
  const existing = await zeaTable.findOne(a => a.zone_id === zoneId && a.employee_user_id === employee_user_id && a.is_active);
  if (existing) {
    return res.status(400).json({ error: 'Employee is already assigned to this zone' });
  }

  const assignment = {
    id: `zea-${uuidv4().substring(0, 8)}`,
    zone_id: zoneId,
    employee_user_id,
    assignment_role,
    is_active: true,
    assigned_at: new Date().toISOString(),
    unassigned_at: null
  };

  await zeaTable.insert(assignment);

  await logAudit({
    actorUserId: req.user.id,
    actionType: 'assign_employee_to_zone',
    entityType: 'zone_employee_assignment',
    entityId: assignment.id,
    newValue: assignment
  });

  broadcast('zone:employee_assigned', assignment);

  res.status(201).json(assignment);
});

/**
 * DELETE /api/zones/:id/unassign-employee/:employeeId
 * Owner Admin unassigns a Field Employee from a Zone
 */
router.delete('/:id/unassign-employee/:employeeId', authenticateToken, requireRole('owner_admin'), async (req, res) => {
  const { id: zoneId, employeeId } = req.params;
  const zeaTable = db.table('zone_employee_assignments');
  
  const existing = await zeaTable.findOne(a => a.zone_id === zoneId && a.employee_user_id === employeeId && a.is_active);
  if (!existing) {
    return res.status(404).json({ error: 'Active assignment not found' });
  }

  const updated = await zeaTable.update(existing.id, {
    is_active: false,
    unassigned_at: new Date().toISOString()
  });

  await logAudit({
    actorUserId: req.user.id,
    actionType: 'unassign_employee_from_zone',
    entityType: 'zone_employee_assignment',
    entityId: existing.id,
    oldValue: existing,
    newValue: updated
  });

  res.json({ message: 'Employee unassigned successfully' });
});

module.exports = router;

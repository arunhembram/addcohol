const express = require('express');
const router = express.Router();
const { v4: uuidv4 } = require('uuid');
const db = require('../db/client');
const { authenticateToken } = require('../middleware/auth');
const { requireRole } = require('../middleware/rbac');
const { logAudit } = require('../services/audit');
const { broadcast } = require('../services/websocket');

/**
 * GET /api/zone-company-assignments
 * List all zone company assignments (Owner Admin only)
 */
router.get('/', authenticateToken, requireRole('owner_admin'), async (req, res) => {
  const assignments = await db.table('zone_company_assignments').find();
  const zonesTable = db.table('zones');
  const companiesTable = db.table('companies');

  const enriched = await Promise.all(assignments.map(async a => {
    const zone = await zonesTable.findById(a.zone_id);
    const company = await companiesTable.findById(a.company_id);
    return {
      ...a,
      zone_name: zone ? zone.name : 'Unknown Zone',
      company_name: company ? company.name : 'Unknown Company'
    };
  }));

  res.json(enriched);
});

/**
 * POST /api/zone-company-assignments
 * Assign a complete Zone to a Company (Owner Admin only)
 * Enforces EXCLUSIVITY: Only one active Company per Zone at one time.
 */
router.post('/', authenticateToken, requireRole('owner_admin'), async (req, res) => {
  const {
    zone_id,
    company_id,
    campaign_name,
    campaign_description = '',
    campaign_start_date,
    campaign_end_date,
    exclusivity_enabled = true
  } = req.body;

  if (!zone_id || !company_id || !campaign_name || !campaign_start_date || !campaign_end_date) {
    return res.status(400).json({
      error: 'Missing required fields: zone_id, company_id, campaign_name, campaign_start_date, campaign_end_date'
    });
  }

  if (campaign_start_date > campaign_end_date) {
    return res.status(400).json({ error: 'campaign_start_date cannot be after campaign_end_date' });
  }

  // Verify Zone exists and is active
  const zone = await db.table('zones').findById(zone_id);
  if (!zone || zone.status !== 'active') {
    return res.status(400).json({ error: 'Selected Zone is not active or does not exist.' });
  }

  // Verify Company exists and is active
  const company = await db.table('companies').findById(company_id);
  if (!company || !company.is_active) {
    return res.status(400).json({ error: 'Selected Company is inactive or does not exist.' });
  }

  // Check Exclusivity: Does this Zone already have an active or overlapping assignment?
  const zcaTable = db.table('zone_company_assignments');
  const existingAssignments = await zcaTable.find(
    a => a.zone_id === zone_id && (a.status === 'active' || a.status === 'scheduled')
  );

  for (const existing of existingAssignments) {
    // Check date overlap: (StartA <= EndB) and (EndA >= StartB)
    const overlaps = (campaign_start_date <= existing.campaign_end_date) && (campaign_end_date >= existing.campaign_start_date);
    if (overlaps) {
      const conflictingCompany = await db.table('companies').findById(existing.company_id);
      return res.status(409).json({
        error: `Exclusivity conflict: Zone '${zone.name}' is already assigned to '${conflictingCompany ? conflictingCompany.name : 'Another Company'}' for campaign '${existing.campaign_name}' (${existing.campaign_start_date} to ${existing.campaign_end_date}). Only one company is allowed per zone at a time.`
      });
    }
  }

  const todayStr = new Date().toISOString().split('T')[0];
  let initialStatus = 'active';
  if (campaign_start_date > todayStr) {
    initialStatus = 'scheduled';
  }

  const newAssignment = {
    id: `zca-${uuidv4().substring(0, 8)}`,
    zone_id,
    company_id,
    campaign_name: campaign_name.trim(),
    campaign_description: campaign_description.trim(),
    campaign_start_date,
    campaign_end_date,
    status: initialStatus,
    exclusivity_enabled: Boolean(exclusivity_enabled),
    assigned_by_user_id: req.user.id,
    created_at: new Date().toISOString()
  };

  await zcaTable.insert(newAssignment);

  await logAudit({
    actorUserId: req.user.id,
    actionType: 'assign_zone_to_company',
    entityType: 'zone_company_assignment',
    entityId: newAssignment.id,
    newValue: newAssignment
  });

  broadcast('zone:company_assigned', {
    ...newAssignment,
    zone_name: zone.name,
    company_name: company.name
  });

  res.status(201).json({
    message: `Zone '${zone.name}' assigned to '${company.name}' successfully.`,
    assignment: newAssignment
  });
});

/**
 * PUT /api/zone-company-assignments/:id/end
 * End or cancel an active assignment immediately (Owner Admin only)
 * Immediately stops company access to the Zone!
 */
router.put('/:id/end', authenticateToken, requireRole('owner_admin'), async (req, res) => {
  const assignment = await db.table('zone_company_assignments').findById(req.params.id);
  if (!assignment) return res.status(404).json({ error: 'Assignment not found' });

  const updated = await db.table('zone_company_assignments').update(assignment.id, {
    status: 'ended'
  });

  await logAudit({
    actorUserId: req.user.id,
    actionType: 'end_zone_company_assignment',
    entityType: 'zone_company_assignment',
    entityId: assignment.id,
    oldValue: assignment,
    newValue: updated
  });

  broadcast('zone:company_unassigned', {
    assignment_id: assignment.id,
    zone_id: assignment.zone_id,
    company_id: assignment.company_id
  });

  res.json({ message: 'Assignment ended immediately. Company access revoked.', assignment: updated });
});

module.exports = router;

const express = require('express');
const router = express.Router();
const { v4: uuidv4 } = require('uuid');
const db = require('../db/client');
const { authenticateToken } = require('../middleware/auth');
const { requireRole, getAuthorizedZoneIds } = require('../middleware/rbac');
const { logAudit } = require('../services/audit');
const { broadcast } = require('../services/websocket');

/**
 * GET /api/issues
 * List issue reports filtered by RBAC
 */
router.get('/', authenticateToken, async (req, res) => {
  const allowedZoneIds = await getAuthorizedZoneIds(req.user);
  const issuesTable = db.table('issue_reports');
  const shopsTable = db.table('shops');
  const zonesTable = db.table('zones');
  const usersTable = db.table('users');

  let issues = await issuesTable.find();

  if (req.user.role === 'merchant') {
    const shop = await shopsTable.findOne(
      s => s.merchant_user_id === req.user.id || s.merchant_phone === req.user.phone
    );
    if (!shop) return res.json([]);
    issues = issues.filter(i => i.shop_id === shop.id);
  } else if (req.user.role !== 'owner_admin') {
    issues = issues.filter(i => allowedZoneIds.includes(i.zone_id));
  }

  const enriched = await Promise.all(issues.map(async i => {
    const shop = await shopsTable.findById(i.shop_id);
    const zone = await zonesTable.findById(i.zone_id);
    const reporter = await usersTable.findById(i.created_by_user_id);
    const assignedEmp = i.assigned_employee_user_id ? await usersTable.findById(i.assigned_employee_user_id) : null;

    return {
      ...i,
      shop_name: shop ? shop.shop_name : 'Unknown Shop',
      shop_code: shop ? shop.shop_code : '',
      zone_name: zone ? zone.name : 'Unknown Zone',
      reporter_name: reporter ? reporter.full_name : 'Unknown',
      assigned_employee_name: assignedEmp ? assignedEmp.full_name : null
    };
  }));

  res.json(enriched);
});

/**
 * POST /api/issues
 * Submit an issue report (Merchant, Field Employee, Owner Admin)
 */
router.post('/', authenticateToken, async (req, res) => {
  const { shop_id, issue_type, notes, photo_path } = req.body;
  if (!shop_id || !issue_type || !notes) {
    return res.status(400).json({ error: 'Missing required fields: shop_id, issue_type, notes' });
  }

  const shop = await db.table('shops').findById(shop_id);
  if (!shop) return res.status(404).json({ error: 'Shop not found' });

  // Check assigned employee for this zone to automatically assign
  const zea = await db.table('zone_employee_assignments').findOne(
    a => a.zone_id === shop.zone_id && a.is_active && a.assignment_role === 'primary'
  );

  const newIssue = {
    id: `iss-${uuidv4().substring(0, 8)}`,
    shop_id,
    zone_id: shop.zone_id,
    created_by_user_id: req.user.id,
    issue_type,
    notes: notes.trim(),
    photo_path: photo_path || null,
    status: 'open',
    assigned_employee_user_id: zea ? zea.employee_user_id : null,
    created_at: new Date().toISOString(),
    resolved_at: null
  };

  await db.table('issue_reports').insert(newIssue);

  // Send notification to the assigned employee
  if (newIssue.assigned_employee_user_id) {
    const notif = {
      id: `notif-${uuidv4().substring(0, 8)}`,
      user_id: newIssue.assigned_employee_user_id,
      title: 'নতুন সমস্যা রিপোর্ট নির্ধারণ করা হয়েছে',
      body: `দোকান "${shop.shop_name}" এর জন্য একটি নতুন সমস্যা রিপোর্ট করা হয়েছে (${issue_type})।`,
      notification_type: 'issue_assigned',
      read_at: null,
      created_at: new Date().toISOString()
    };
    await db.table('notifications').insert(notif);
    broadcast('notification:new', notif);
  }

  await logAudit({
    actorUserId: req.user.id,
    actionType: 'create_issue_report',
    entityType: 'issue_report',
    entityId: newIssue.id,
    newValue: newIssue
  });

  broadcast('issue:new', newIssue);

  res.status(201).json(newIssue);
});

/**
 * PUT /api/issues/:id/status
 * Update issue status (assigned, resolved, closed)
 */
router.put('/:id/status', authenticateToken, requireRole('owner_admin', 'field_employee'), async (req, res) => {
  const { status, resolution_notes, assigned_employee_user_id } = req.body;
  const issue = await db.table('issue_reports').findById(req.params.id);
  if (!issue) return res.status(404).json({ error: 'Issue report not found' });

  const updates = {};
  if (status) updates.status = status;
  if (resolution_notes) updates.notes = `${issue.notes}\n[Resolution]: ${resolution_notes}`;
  if (assigned_employee_user_id) updates.assigned_employee_user_id = assigned_employee_user_id;
  if (status === 'resolved' || status === 'closed') {
    updates.resolved_at = new Date().toISOString();
  }

  const updated = await db.table('issue_reports').update(issue.id, updates);

  await logAudit({
    actorUserId: req.user.id,
    actionType: 'update_issue_status',
    entityType: 'issue_report',
    entityId: issue.id,
    oldValue: { status: issue.status },
    newValue: updates
  });

  broadcast('issue:updated', updated);

  res.json(updated);
});

module.exports = router;

const express = require('express');
const router = express.Router();
const db = require('../db/client');
const { authenticateToken } = require('../middleware/auth');
const { requireRole } = require('../middleware/rbac');

/**
 * GET /api/audit-logs
 * Immutable audit logs viewer (Owner Admin only)
 */
router.get('/', authenticateToken, requireRole('owner_admin'), async (req, res) => {
  const { entity_type, action_type, limit = 100 } = req.query;
  const auditTable = db.table('audit_logs');
  const usersTable = db.table('users');

  let logs = await auditTable.find();

  if (entity_type) {
    logs = logs.filter(l => l.entity_type === entity_type);
  }
  if (action_type) {
    logs = logs.filter(l => l.action_type === action_type);
  }

  // Sort newest first
  logs.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
  logs = logs.slice(0, Number(limit));

  const enriched = await Promise.all(logs.map(async l => {
    const actor = l.actor_user_id ? await usersTable.findById(l.actor_user_id) : null;
    return {
      ...l,
      actor_name: actor ? actor.full_name : (l.actor_user_id === 'system-cron' ? 'System Scheduler' : 'System')
    };
  }));

  res.json(enriched);
});

module.exports = router;

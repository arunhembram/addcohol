const { v4: uuidv4 } = require('uuid');
const db = require('../db/client');

/**
 * Log an immutable audit record
 */
async function logAudit({
  actorUserId,
  actionType,
  entityType,
  entityId,
  oldValue = null,
  newValue = null
}) {
  try {
    const record = {
      id: `aud-${uuidv4().substring(0, 8)}`,
      actor_user_id: actorUserId || null,
      action_type: actionType,
      entity_type: entityType,
      entity_id: entityId,
      old_value_json: oldValue ? JSON.stringify(oldValue) : null,
      new_value_json: newValue ? JSON.stringify(newValue) : null,
      created_at: new Date().toISOString()
    };

    await db.table('audit_logs').insert(record);
    return record;
  } catch (err) {
    console.error('[AUDIT] Error logging audit action:', err);
  }
}

module.exports = { logAudit };

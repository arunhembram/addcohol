const express = require('express');
const router = express.Router();
const { authenticateToken } = require('../middleware/auth');
const { requireRole } = require('../middleware/rbac');
const { executeMidnightExpiryJob, BUSINESS_TIMEZONE } = require('../services/midnight_cron');

/**
 * POST /api/cron/trigger-midnight
 * Manually trigger midnight image expiration (Owner Admin only)
 */
router.post('/trigger-midnight', authenticateToken, requireRole('owner_admin'), async (req, res) => {
  try {
    const result = await executeMidnightExpiryJob(req.user.id);
    res.json({
      message: 'Midnight expiry job executed successfully.',
      details: result
    });
  } catch (err) {
    console.error('[CRON ROUTE] Error executing job:', err);
    res.status(500).json({ error: 'Failed to execute midnight expiry job: ' + err.message });
  }
});

/**
 * GET /api/cron/status
 * Get status of business timezone and cron job
 */
router.get('/status', authenticateToken, async (req, res) => {
  res.json({
    business_timezone: BUSINESS_TIMEZONE,
    schedule: '0 0 * * * (Midnight Asia/Dhaka)',
    current_server_time: new Date().toISOString()
  });
});

module.exports = router;

const cron = require('node-cron');
const db = require('../db/client');
const { deletePhysicalFile } = require('./storage');
const { broadcast } = require('./websocket');
const { logAudit } = require('./audit');

const BUSINESS_TIMEZONE = process.env.BUSINESS_TIMEZONE || 'Asia/Dhaka';

/**
 * Execute the midnight expiration job:
 * 1. Find all uploads where expires_at <= NOW() and image_deleted_at IS NULL
 * 2. Delete the actual image files from private storage
 * 3. Set image_deleted_at = NOW()
 * 4. Update status to 'expired' if it was still 'submitted'
 * 5. Retain all metadata (shop, zone, uploader, timestamps, GPS, verification status)
 * 6. Broadcast day reset event to all connected dashboards
 */
async function executeMidnightExpiryJob(actorId = 'system-cron') {
  console.log(`[CRON] Running Midnight Image Expiry Job for timezone: ${BUSINESS_TIMEZONE}...`);
  const now = new Date();
  const uploadsTable = db.table('daily_uploads');

  const pendingExpirations = await uploadsTable.find(
    u => !u.image_deleted_at && (new Date(u.expires_at) <= now || u.image_storage_path)
  );

  let deletedFilesCount = 0;

  for (const upload of pendingExpirations) {
    // Delete the physical file from disk
    if (upload.image_storage_path) {
      const deleted = deletePhysicalFile(upload.image_storage_path);
      if (deleted) deletedFilesCount++;
    }

    // Update database record
    const updates = {
      image_deleted_at: now.toISOString(),
      // If it was still pending verification when midnight arrived, mark as expired
      status: upload.status === 'submitted' ? 'expired' : upload.status,
      image_storage_path: null // Clear path reference
    };

    await uploadsTable.update(upload.id, updates);
  }

  // Audit log the midnight cleanup run
  await logAudit({
    actorUserId: actorId,
    actionType: 'midnight_expiry_run',
    entityType: 'system_job',
    entityId: `expiry-${now.toISOString().split('T')[0]}`,
    newValue: {
      deletedFilesCount,
      totalProcessed: pendingExpirations.length,
      executedAt: now.toISOString()
    }
  });

  console.log(`[CRON] Midnight job completed. Deleted ${deletedFilesCount} physical files. Reset business day.`);

  // Broadcast real-time reset event to live maps and dashboards
  broadcast('day:reset', {
    businessDate: now.toISOString().split('T')[0],
    message: 'New business day started. Upload statuses reset to Not Uploaded Yet.',
    deletedCount: deletedFilesCount
  });

  return {
    success: true,
    deletedFilesCount,
    totalProcessed: pendingExpirations.length,
    executedAt: now.toISOString()
  };
}

/**
 * Initializes the automated cron schedule
 */
function initMidnightCron() {
  // Run at 00:00:00 every day in Asia/Dhaka timezone
  cron.schedule('0 0 * * *', async () => {
    try {
      await executeMidnightExpiryJob('system-cron');
    } catch (err) {
      console.error('[CRON] Error during midnight expiry job:', err);
    }
  }, {
    scheduled: true,
    timezone: BUSINESS_TIMEZONE
  });

  console.log(`[CRON] Scheduled midnight image expiry worker for 00:00 ${BUSINESS_TIMEZONE}`);
}

module.exports = {
  initMidnightCron,
  executeMidnightExpiryJob,
  BUSINESS_TIMEZONE
};

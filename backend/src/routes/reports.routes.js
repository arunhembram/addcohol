const express = require('express');
const router = express.Router();
const db = require('../db/client');
const { authenticateToken } = require('../middleware/auth');
const { getAuthorizedZoneIds } = require('../middleware/rbac');

/**
 * GET /api/reports/dashboard
 * Aggregated KPIs tailored to the caller's role
 */
router.get('/dashboard', authenticateToken, async (req, res) => {
  const allowedZoneIds = await getAuthorizedZoneIds(req.user);
  const todayStr = new Date().toISOString().split('T')[0];

  const zonesTable = db.table('zones');
  const shopsTable = db.table('shops');
  const uploadsTable = db.table('daily_uploads');
  const issuesTable = db.table('issue_reports');
  const zeaTable = db.table('zone_employee_assignments');
  const usersTable = db.table('users');

  let zones = await zonesTable.find(z => z.status === 'active');
  let shops = await shopsTable.find(s => s.status === 'active');
  let uploads = await uploadsTable.find(u => u.business_date === todayStr);
  let issues = await issuesTable.find(i => i.status === 'open' || i.status === 'assigned');

  // Role restriction
  if (req.user.role !== 'owner_admin') {
    zones = zones.filter(z => allowedZoneIds.includes(z.id));
    shops = shops.filter(s => allowedZoneIds.includes(s.zone_id));
    uploads = uploads.filter(u => allowedZoneIds.includes(u.zone_id));
    issues = issues.filter(i => allowedZoneIds.includes(i.zone_id));
  }

  // Upload metrics for today
  const uploadedShopIds = new Set(uploads.map(u => u.shop_id));
  const verifiedUploads = uploads.filter(u => u.status === 'verified');
  const submittedUploads = uploads.filter(u => u.status === 'submitted');
  const rejectedUploads = uploads.filter(u => u.status === 'rejected');

  const totalShops = shops.length;
  const uploadedTodayCount = uploads.length;
  const notUploadedTodayCount = Math.max(0, totalShops - uploadedTodayCount);
  const compliancePercentage = totalShops > 0 ? Math.round((verifiedUploads.length / totalShops) * 100) : 0;

  // Zone-wise compliance breakdown
  const zoneCompliance = await Promise.all(zones.map(async z => {
    const zShops = shops.filter(s => s.zone_id === z.id);
    const zUploads = uploads.filter(u => u.zone_id === z.id);
    const zVerified = zUploads.filter(u => u.status === 'verified').length;
    const zSubmitted = zUploads.filter(u => u.status === 'submitted').length;
    const zRejected = zUploads.filter(u => u.status === 'rejected').length;
    const zNotUploaded = Math.max(0, zShops.length - zUploads.length);

    return {
      zone_id: z.id,
      zone_name: z.name,
      total_shops: zShops.length,
      uploaded: zUploads.length,
      verified: zVerified,
      submitted: zSubmitted,
      rejected: zRejected,
      not_uploaded: zNotUploaded,
      compliance_percentage: zShops.length > 0 ? Math.round((zVerified / zShops.length) * 100) : 0
    };
  }));

  // Employee-wise pending tasks (for Owner Admin & Employees)
  const employeeTasks = [];
  if (req.user.role === 'owner_admin' || req.user.role === 'field_employee') {
    const employees = await usersTable.find(u => u.role === 'field_employee' && u.is_active);
    for (const emp of employees) {
      if (req.user.role === 'field_employee' && emp.id !== req.user.id) continue;

      const empAssignments = await zeaTable.find(a => a.employee_user_id === emp.id && a.is_active);
      const empZoneIds = empAssignments.map(a => a.zone_id);

      const empShops = shops.filter(s => empZoneIds.includes(s.zone_id));
      const empUploadedShopIds = new Set(uploads.filter(u => empZoneIds.includes(u.zone_id)).map(u => u.shop_id));
      const pendingShops = empShops.filter(s => !empUploadedShopIds.has(s.id));
      const empIssues = issues.filter(i => empZoneIds.includes(i.zone_id) && i.status !== 'resolved');

      employeeTasks.push({
        employee_id: emp.id,
        employee_name: emp.full_name,
        assigned_zones_count: empZoneIds.length,
        total_shops_count: empShops.length,
        pending_shops_count: pendingShops.length,
        pending_phone_less_count: pendingShops.filter(s => s.upload_mode === 'employee_managed_upload').length,
        open_issues_count: empIssues.length
      });
    }
  }

  res.json({
    kpis: {
      total_active_zones: zones.length,
      total_active_shops: totalShops,
      uploaded_today: uploadedTodayCount,
      not_uploaded_today: notUploadedTodayCount,
      verified_today: verifiedUploads.length,
      submitted_today: submittedUploads.length,
      rejected_today: rejectedUploads.length,
      pending_issues: issues.length,
      overall_compliance_percentage: compliancePercentage
    },
    zone_compliance: zoneCompliance,
    employee_tasks: employeeTasks
  });
});

/**
 * GET /api/reports/compliance
 * Historical compliance reports (persists historical status even after images expire)
 */
router.get('/compliance', authenticateToken, async (req, res) => {
  const { start_date, end_date, zone_id } = req.query;
  const allowedZoneIds = await getAuthorizedZoneIds(req.user);
  const uploadsTable = db.table('daily_uploads');

  let uploads = await uploadsTable.find();

  if (req.user.role !== 'owner_admin') {
    uploads = uploads.filter(u => allowedZoneIds.includes(u.zone_id));
  }

  if (zone_id) {
    uploads = uploads.filter(u => u.zone_id === zone_id);
  }

  if (start_date) {
    uploads = uploads.filter(u => u.business_date >= start_date);
  }

  if (end_date) {
    uploads = uploads.filter(u => u.business_date <= end_date);
  }

  res.json({
    total_records: uploads.length,
    records: uploads.map(u => ({
      id: u.id,
      shop_id: u.shop_id,
      zone_id: u.zone_id,
      business_date: u.business_date,
      status: u.status,
      uploader_type: u.uploader_type,
      distance_meters: u.distance_meters,
      is_distance_suspicious: u.is_distance_suspicious,
      image_deleted: Boolean(u.image_deleted_at),
      rejection_reason: u.rejection_reason,
      created_at: u.created_at
    }))
  });
});

module.exports = router;

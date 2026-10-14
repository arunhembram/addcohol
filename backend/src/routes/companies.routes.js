const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const { v4: uuidv4 } = require('uuid');
const db = require('../db/client');
const { authenticateToken } = require('../middleware/auth');
const { requireRole } = require('../middleware/rbac');
const { logAudit } = require('../services/audit');

/**
 * GET /api/companies
 * List companies (Owner Admin only)
 */
router.get('/', authenticateToken, requireRole('owner_admin'), async (req, res) => {
  const companies = await db.table('companies').find();
  const zcaTable = db.table('zone_company_assignments');
  const zonesTable = db.table('zones');
  const usersTable = db.table('users');
  const cuTable = db.table('company_users');

  const enriched = await Promise.all(companies.map(async c => {
    // Assignments for this company
    const assignments = await zcaTable.find(a => a.company_id === c.id);
    const activeAssignments = assignments.filter(a => a.status === 'active');
    
    // Users for this company
    const companyUsers = await cuTable.find(cu => cu.company_id === c.id);
    const userDetails = await Promise.all(companyUsers.map(async cu => {
      const u = await usersTable.findById(cu.user_id);
      return {
        id: cu.id,
        user_id: cu.user_id,
        full_name: u ? u.full_name : 'Unknown',
        email: u ? u.email : '',
        phone: u ? u.phone : '',
        permission_level: cu.permission_level
      };
    }));

    return {
      ...c,
      active_zones_count: activeAssignments.length,
      total_assignments_count: assignments.length,
      users: userDetails
    };
  }));

  res.json(enriched);
});

/**
 * POST /api/companies
 * Create new company (Owner Admin only)
 */
router.post('/', authenticateToken, requireRole('owner_admin'), async (req, res) => {
  const { name, contact_person_name, contact_phone, contact_email } = req.body;
  if (!name || !name.trim()) {
    return res.status(400).json({ error: 'Company name is required' });
  }

  const newCompany = {
    id: `cmp-${uuidv4().substring(0, 8)}`,
    name: name.trim(),
    contact_person_name: contact_person_name ? contact_person_name.trim() : null,
    contact_phone: contact_phone ? contact_phone.trim() : null,
    contact_email: contact_email ? contact_email.trim() : null,
    is_active: true,
    created_at: new Date().toISOString()
  };

  await db.table('companies').insert(newCompany);

  await logAudit({
    actorUserId: req.user.id,
    actionType: 'create_company',
    entityType: 'company',
    entityId: newCompany.id,
    newValue: newCompany
  });

  res.status(201).json(newCompany);
});

/**
 * POST /api/companies/:id/users
 * Create a user account for a company (Owner Admin only)
 */
router.post('/:id/users', authenticateToken, requireRole('owner_admin'), async (req, res) => {
  const companyId = req.params.id;
  const { full_name, email, phone, password, permission_level = 'company_admin' } = req.body;

  if (!full_name || !phone || !password) {
    return res.status(400).json({ error: 'Full name, phone, and password are required' });
  }

  const company = await db.table('companies').findById(companyId);
  if (!company) return res.status(404).json({ error: 'Company not found' });

  // Check unique phone/email
  const existingUser = await db.table('users').findOne(
    u => u.phone === phone || (email && u.email === email.toLowerCase())
  );
  if (existingUser) {
    return res.status(400).json({ error: 'A user with this phone or email already exists' });
  }

  const passwordHash = await bcrypt.hash(password, 10);
  const newUser = {
    id: `usr-comp-${uuidv4().substring(0, 8)}`,
    role: 'company_user',
    full_name: full_name.trim(),
    phone: phone.trim(),
    email: email ? email.trim().toLowerCase() : null,
    password_hash: passwordHash,
    is_active: true,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString()
  };

  await db.table('users').insert(newUser);

  const newCompanyUser = {
    id: `cu-${uuidv4().substring(0, 8)}`,
    company_id: companyId,
    user_id: newUser.id,
    permission_level,
    created_at: new Date().toISOString()
  };

  await db.table('company_users').insert(newCompanyUser);

  await logAudit({
    actorUserId: req.user.id,
    actionType: 'create_company_user',
    entityType: 'company_user',
    entityId: newCompanyUser.id,
    newValue: { company_id: companyId, user_id: newUser.id, email: newUser.email }
  });

  res.status(201).json({
    message: 'Company user account created successfully',
    user: {
      id: newUser.id,
      full_name: newUser.full_name,
      phone: newUser.phone,
      email: newUser.email,
      permission_level
    }
  });
});

/**
 * GET /api/companies/:id/assignments
 * View active and historical Zone assignments for a Company
 */
router.get('/:id/assignments', authenticateToken, requireRole('owner_admin'), async (req, res) => {
  const companyId = req.params.id;
  const assignments = await db.table('zone_company_assignments').find(a => a.company_id === companyId);
  const zonesTable = db.table('zones');

  const enriched = await Promise.all(assignments.map(async a => {
    const z = await zonesTable.findById(a.zone_id);
    return {
      ...a,
      zone_name: z ? z.name : 'Unknown Zone'
    };
  }));

  res.json(enriched);
});

module.exports = router;

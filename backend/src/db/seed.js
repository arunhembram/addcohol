const fs = require('fs');
const path = require('path');
const bcrypt = require('bcryptjs');
const db = require('./client');

async function seed() {
  console.log('[SEED] Starting database seeding...');

  const passwordHash = await bcrypt.hash('AdminPassword123!', 10);
  const employeeHash = await bcrypt.hash('EmployeePass123!', 10);
  const companyHash = await bcrypt.hash('CompanyPass123!', 10);
  const merchantPinHash = await bcrypt.hash('1234', 10);

  const todayStr = new Date().toISOString().split('T')[0];
  const nextMidnight = new Date();
  nextMidnight.setHours(23, 59, 59, 999);

  // 1. Users
  const users = [
    {
      id: 'usr-admin-01',
      role: 'owner_admin',
      full_name: 'Ariful Rahman (Owner)',
      phone: '01711000001',
      email: 'admin@adproof.com',
      password_hash: passwordHash,
      is_active: true,
      created_at: new Date('2026-01-01').toISOString(),
      updated_at: new Date('2026-01-01').toISOString()
    },
    {
      id: 'usr-emp-01',
      role: 'field_employee',
      full_name: 'Tariqul Islam',
      phone: '01711000002',
      email: 'tariq@adproof.com',
      password_hash: employeeHash,
      is_active: true,
      created_at: new Date('2026-01-05').toISOString(),
      updated_at: new Date('2026-01-05').toISOString()
    },
    {
      id: 'usr-emp-02',
      role: 'field_employee',
      full_name: 'Kamal Hossain',
      phone: '01711000003',
      email: 'kamal@adproof.com',
      password_hash: employeeHash,
      is_active: true,
      created_at: new Date('2026-01-05').toISOString(),
      updated_at: new Date('2026-01-05').toISOString()
    },
    {
      id: 'usr-mer-01',
      role: 'merchant',
      full_name: 'Abdul Gafur (Mirpur Tea)',
      phone: '01811000001',
      email: null,
      password_hash: merchantPinHash,
      is_active: true,
      created_at: new Date('2026-02-01').toISOString(),
      updated_at: new Date('2026-02-01').toISOString()
    },
    {
      id: 'usr-mer-02',
      role: 'merchant',
      full_name: 'Rahim Mia (Uttara Store)',
      phone: '01811000002',
      email: null,
      password_hash: merchantPinHash,
      is_active: true,
      created_at: new Date('2026-02-01').toISOString(),
      updated_at: new Date('2026-02-01').toISOString()
    },
    {
      id: 'usr-comp-01',
      role: 'company_user',
      full_name: 'Sarah Khan (PRAN)',
      phone: '01911000001',
      email: 'sarah@pran.com',
      password_hash: companyHash,
      is_active: true,
      created_at: new Date('2026-02-10').toISOString(),
      updated_at: new Date('2026-02-10').toISOString()
    },
    {
      id: 'usr-comp-02',
      role: 'company_user',
      full_name: 'Zakir Ahmed (ACI)',
      phone: '01911000002',
      email: 'zakir@aci.com',
      password_hash: companyHash,
      is_active: true,
      created_at: new Date('2026-02-10').toISOString(),
      updated_at: new Date('2026-02-10').toISOString()
    }
  ];

  // 2. Companies
  const companies = [
    {
      id: 'cmp-01',
      name: 'PRAN-RFL Group',
      contact_person_name: 'Sarah Khan',
      contact_phone: '01911000001',
      contact_email: 'sarah@pran.com',
      is_active: true,
      created_at: new Date('2026-02-10').toISOString()
    },
    {
      id: 'cmp-02',
      name: 'ACI Consumer Brands',
      contact_person_name: 'Zakir Ahmed',
      contact_phone: '01911000002',
      contact_email: 'zakir@aci.com',
      is_active: true,
      created_at: new Date('2026-02-10').toISOString()
    }
  ];

  // 3. Company Users
  const company_users = [
    {
      id: 'cu-01',
      company_id: 'cmp-01',
      user_id: 'usr-comp-01',
      permission_level: 'company_admin',
      created_at: new Date('2026-02-10').toISOString()
    },
    {
      id: 'cu-02',
      company_id: 'cmp-02',
      user_id: 'usr-comp-02',
      permission_level: 'company_admin',
      created_at: new Date('2026-02-10').toISOString()
    }
  ];

  // 4. Zones
  const zones = [
    {
      id: 'zone-01',
      name: 'Mirpur Zone A',
      description: 'Mirpur 1, 2, and 10 Commercial Corridor',
      boundary_geojson: JSON.stringify({
        type: 'Polygon',
        coordinates: [[[90.355, 23.795], [90.380, 23.795], [90.380, 23.820], [90.355, 23.820], [90.355, 23.795]]]
      }),
      status: 'active',
      created_by_user_id: 'usr-admin-01',
      created_at: new Date('2026-01-10').toISOString(),
      updated_at: new Date('2026-01-10').toISOString()
    },
    {
      id: 'zone-02',
      name: 'Uttara Zone B',
      description: 'Uttara Sector 3, 7, and 9 Retail Hub',
      boundary_geojson: JSON.stringify({
        type: 'Polygon',
        coordinates: [[[90.370, 23.865], [90.395, 23.865], [90.395, 23.885], [90.370, 23.885], [90.370, 23.865]]]
      }),
      status: 'active',
      created_by_user_id: 'usr-admin-01',
      created_at: new Date('2026-01-10').toISOString(),
      updated_at: new Date('2026-01-10').toISOString()
    },
    {
      id: 'zone-03',
      name: 'Dhanmondi Zone C',
      description: 'Dhanmondi Road 27 & Satmasjid Road Cafes and Outlets',
      boundary_geojson: JSON.stringify({
        type: 'Polygon',
        coordinates: [[[90.365, 23.735], [90.385, 23.735], [90.385, 23.755], [90.365, 23.755], [90.365, 23.735]]]
      }),
      status: 'active',
      created_by_user_id: 'usr-admin-01',
      created_at: new Date('2026-01-10').toISOString(),
      updated_at: new Date('2026-01-10').toISOString()
    }
  ];

  // 5. Zone Employee Assignments
  const zone_employee_assignments = [
    {
      id: 'zea-01',
      zone_id: 'zone-01',
      employee_user_id: 'usr-emp-01',
      assignment_role: 'primary',
      is_active: true,
      assigned_at: new Date('2026-01-15').toISOString(),
      unassigned_at: null
    },
    {
      id: 'zea-02',
      zone_id: 'zone-02',
      employee_user_id: 'usr-emp-02',
      assignment_role: 'primary',
      is_active: true,
      assigned_at: new Date('2026-01-15').toISOString(),
      unassigned_at: null
    }
  ];

  // 6. Zone Company Assignments (Only 1 active per zone)
  const zone_company_assignments = [
    {
      id: 'zca-01',
      zone_id: 'zone-01',
      company_id: 'cmp-01',
      campaign_name: 'PRAN Frooto Summer 2026',
      campaign_description: 'Branded QR sticker campaign across tea stalls and food outlets',
      campaign_start_date: '2026-05-01',
      campaign_end_date: '2026-12-31',
      status: 'active',
      exclusivity_enabled: true,
      assigned_by_user_id: 'usr-admin-01',
      created_at: new Date('2026-04-20').toISOString()
    },
    {
      id: 'zca-02',
      zone_id: 'zone-02',
      company_id: 'cmp-02',
      campaign_name: 'ACI Pure Salt Campaign 2026',
      campaign_description: 'Exclusive retail counter branding in Uttara grocery outlets',
      campaign_start_date: '2026-06-01',
      campaign_end_date: '2026-11-30',
      status: 'active',
      exclusivity_enabled: true,
      assigned_by_user_id: 'usr-admin-01',
      created_at: new Date('2026-05-25').toISOString()
    }
  ];

  // 7. Shops (All with 8-digit unique Shop Code)
  const shops = [
    {
      id: 'shp-01',
      shop_code: '10849201',
      shop_name: 'Gafur Bhaiyer Cha (গফুর ভাইয়ের চা)',
      category: 'tea_stall',
      logo_type: 'tea',
      address: 'Plot 12, Road 4, Mirpur 1, Dhaka',
      latitude: 23.8041,
      longitude: 90.3687,
      zone_id: 'zone-01',
      merchant_phone: '01811000001',
      merchant_user_id: 'usr-mer-01',
      upload_mode: 'both',
      status: 'active',
      created_by_user_id: 'usr-emp-01',
      created_at: new Date('2026-02-01').toISOString(),
      updated_at: new Date('2026-02-01').toISOString()
    },
    {
      id: 'shp-02',
      shop_code: '20938472',
      shop_name: 'Bismillah General Store (বিসমিল্লাহ জেনারেল স্টোর)',
      category: 'grocery_shop',
      logo_type: 'grocery',
      address: 'Shop 5, Mirpur 10 Circle, Dhaka',
      latitude: 23.8072,
      longitude: 90.3695,
      zone_id: 'zone-01',
      merchant_phone: null, // Phone-less: MUST use employee_managed_upload
      merchant_user_id: null,
      upload_mode: 'employee_managed_upload',
      status: 'active',
      created_by_user_id: 'usr-emp-01',
      created_at: new Date('2026-02-02').toISOString(),
      updated_at: new Date('2026-02-02').toISOString()
    },
    {
      id: 'shp-03',
      shop_code: '30495821',
      shop_name: 'Dhaka Biryani House (ঢাকা বিরিয়ানি হাউজ)',
      category: 'food_stall',
      logo_type: 'food',
      address: 'Main Road, Mirpur 2, Dhaka',
      latitude: 23.8025,
      longitude: 90.3618,
      zone_id: 'zone-01',
      merchant_phone: '01811000003',
      merchant_user_id: null,
      upload_mode: 'merchant_self_upload',
      status: 'active',
      created_by_user_id: 'usr-emp-01',
      created_at: new Date('2026-02-05').toISOString(),
      updated_at: new Date('2026-02-05').toISOString()
    },
    {
      id: 'shp-04',
      shop_code: '40192837',
      shop_name: 'Medilife Pharmacy (মেডিলাইফ ফার্মেসি)',
      category: 'pharmacy',
      logo_type: 'pharmacy',
      address: 'Sector 3, Jashimuddin Road, Uttara, Dhaka',
      latitude: 23.8725,
      longitude: 90.3812,
      zone_id: 'zone-02',
      merchant_phone: '01811000004',
      merchant_user_id: null,
      upload_mode: 'both',
      status: 'active',
      created_by_user_id: 'usr-emp-02',
      created_at: new Date('2026-02-10').toISOString(),
      updated_at: new Date('2026-02-10').toISOString()
    },
    {
      id: 'shp-05',
      shop_code: '50293841',
      shop_name: 'Rahim Vegetable Corner (রহিম কাঁচাবাজার)',
      category: 'vegetable_shop',
      logo_type: 'vegetable',
      address: 'Sector 7 Market, Uttara, Dhaka',
      latitude: 23.8768,
      longitude: 90.3845,
      zone_id: 'zone-02',
      merchant_phone: '01811000002',
      merchant_user_id: 'usr-mer-02',
      upload_mode: 'merchant_self_upload',
      status: 'active',
      created_by_user_id: 'usr-emp-02',
      created_at: new Date('2026-02-12').toISOString(),
      updated_at: new Date('2026-02-12').toISOString()
    },
    {
      id: 'shp-06',
      shop_code: '60384729',
      shop_name: 'Fresh Fish Center (তাজা মাছের আড়ত)',
      category: 'fish_shop',
      logo_type: 'fish',
      address: 'Sector 9 Bazar, Uttara, Dhaka',
      latitude: 23.8795,
      longitude: 90.3782,
      zone_id: 'zone-02',
      merchant_phone: null, // Phone-less
      merchant_user_id: null,
      upload_mode: 'employee_managed_upload',
      status: 'active',
      created_by_user_id: 'usr-emp-02',
      created_at: new Date('2026-02-15').toISOString(),
      updated_at: new Date('2026-02-15').toISOString()
    },
    {
      id: 'shp-07',
      shop_code: '70482910',
      shop_name: 'Al-Madina Departmental (আল-মদিনা ডিপার্টমেন্টাল)',
      category: 'grocery_shop',
      logo_type: 'grocery',
      address: 'Road 27, Dhanmondi, Dhaka',
      latitude: 23.7482,
      longitude: 90.3725,
      zone_id: 'zone-03',
      merchant_phone: '01811000005',
      merchant_user_id: null,
      upload_mode: 'both',
      status: 'active',
      created_by_user_id: 'usr-admin-01',
      created_at: new Date('2026-03-01').toISOString(),
      updated_at: new Date('2026-03-01').toISOString()
    }
  ];

  // 8. Daily Uploads (Today's current proof photos)
  const daily_uploads = [
    {
      id: 'upl-01',
      shop_id: 'shp-01',
      zone_id: 'zone-01',
      zone_company_assignment_id: 'zca-01',
      business_date: todayStr,
      uploaded_by_user_id: 'usr-mer-01',
      uploader_type: 'merchant',
      image_storage_path: 'uploads/proofs/sample_mirpur_tea.jpg',
      image_deleted_at: null,
      captured_at: new Date().toISOString(),
      uploaded_at: new Date().toISOString(),
      captured_latitude: 23.80415,
      captured_longitude: 90.36872,
      distance_meters: 6.2,
      is_distance_suspicious: false,
      status: 'verified',
      rejection_reason: null,
      expires_at: nextMidnight.toISOString(),
      created_at: new Date().toISOString()
    },
    {
      id: 'upl-02',
      shop_id: 'shp-02',
      zone_id: 'zone-01',
      zone_company_assignment_id: 'zca-01',
      business_date: todayStr,
      uploaded_by_user_id: 'usr-emp-01',
      uploader_type: 'employee',
      image_storage_path: 'uploads/proofs/sample_mirpur_grocery.jpg',
      image_deleted_at: null,
      captured_at: new Date().toISOString(),
      uploaded_at: new Date().toISOString(),
      captured_latitude: 23.80718,
      captured_longitude: 90.36948,
      distance_meters: 3.1,
      is_distance_suspicious: false,
      status: 'submitted', // Awaiting Owner Admin review
      rejection_reason: null,
      expires_at: nextMidnight.toISOString(),
      created_at: new Date().toISOString()
    },
    {
      id: 'upl-03',
      shop_id: 'shp-05',
      zone_id: 'zone-02',
      zone_company_assignment_id: 'zca-02',
      business_date: todayStr,
      uploaded_by_user_id: 'usr-mer-02',
      uploader_type: 'merchant',
      image_storage_path: 'uploads/proofs/sample_uttara_veg.jpg',
      image_deleted_at: null,
      captured_at: new Date().toISOString(),
      uploaded_at: new Date().toISOString(),
      captured_latitude: 23.87675,
      captured_longitude: 90.38448,
      distance_meters: 5.8,
      is_distance_suspicious: false,
      status: 'rejected',
      rejection_reason: 'বিজ্ঞাপন পোস্টারটি স্পষ্ট নয়, QR কোডের পাশে পুরো পোস্টার ফ্রেম সহ পুনরায় ছবি তুলুন।',
      expires_at: nextMidnight.toISOString(),
      created_at: new Date().toISOString()
    }
  ];

  // 9. Issue Reports
  const issue_reports = [
    {
      id: 'iss-01',
      shop_id: 'shp-03',
      zone_id: 'zone-01',
      created_by_user_id: 'usr-emp-01',
      issue_type: 'poster_damaged',
      notes: 'বৃষ্টির কারণে পোস্টারের নিচের অংশ ছিঁড়ে গেছে, নতুন পোস্টার প্রয়োজন।',
      photo_path: null,
      status: 'open',
      assigned_employee_user_id: 'usr-emp-01',
      created_at: new Date().toISOString(),
      resolved_at: null
    }
  ];

  // 10. Notifications
  const notifications = [
    {
      id: 'notif-01',
      user_id: 'usr-mer-02',
      title: 'বিজ্ঞাপনের ছবি বাতিল করা হয়েছে',
      body: 'আপনার আজকের বিজ্ঞাপনের ছবি অনুমোদন করা হয়নি। কারণ: পোস্টারটি স্পষ্ট নয়। অনুগ্রহ করে পুনরায় ছবি তুলুন।',
      notification_type: 'upload_rejected',
      read_at: null,
      created_at: new Date().toISOString()
    },
    {
      id: 'notif-02',
      user_id: 'usr-emp-01',
      title: 'মিরপুর জোন এ তে নতুন সমস্যা রিপোর্ট',
      body: 'ঢাকা বিরিয়ানি হাউজ এর পোস্টার ক্ষতিগ্রস্ত হয়েছে। অনুগ্রহ করে পরিদর্শন করুন।',
      notification_type: 'issue_reported',
      read_at: null,
      created_at: new Date().toISOString()
    }
  ];

  // 11. Audit Logs
  const audit_logs = [
    {
      id: 'aud-01',
      actor_user_id: 'usr-admin-01',
      action_type: 'create',
      entity_type: 'zone',
      entity_id: 'zone-01',
      old_value_json: null,
      new_value_json: JSON.stringify({ name: 'Mirpur Zone A' }),
      created_at: new Date('2026-01-10T10:00:00Z').toISOString()
    },
    {
      id: 'aud-02',
      actor_user_id: 'usr-admin-01',
      action_type: 'assign',
      entity_type: 'zone_company_assignment',
      entity_id: 'zca-01',
      old_value_json: null,
      new_value_json: JSON.stringify({ company_id: 'cmp-01', zone_id: 'zone-01', campaign: 'PRAN Frooto Summer 2026' }),
      created_at: new Date('2026-04-20T11:30:00Z').toISOString()
    },
    {
      id: 'aud-03',
      actor_user_id: 'usr-admin-01',
      action_type: 'verify',
      entity_type: 'upload',
      entity_id: 'upl-01',
      old_value_json: JSON.stringify({ status: 'submitted' }),
      new_value_json: JSON.stringify({ status: 'verified' }),
      created_at: new Date().toISOString()
    }
  ];

  const initialData = {
    users,
    companies,
    company_users,
    zones,
    zone_employee_assignments,
    zone_company_assignments,
    shops,
    daily_uploads,
    issue_reports,
    notifications,
    audit_logs
  };

  db.resetEmbeddedData(initialData);

  // If Postgres is connected, insert into tables
  if (db.isPg) {
    // Read and run schema.sql
    const fs = require('fs');
    const path = require('path');
    const schemaSql = fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8');
    await db.query(schemaSql);

    for (const u of users) await db.table('users').insert(u);
    for (const c of companies) await db.table('companies').insert(c);
    for (const cu of company_users) await db.table('company_users').insert(cu);
    for (const z of zones) await db.table('zones').insert(z);
    for (const zea of zone_employee_assignments) await db.table('zone_employee_assignments').insert(zea);
    for (const zca of zone_company_assignments) await db.table('zone_company_assignments').insert(zca);
    for (const s of shops) await db.table('shops').insert(s);
    for (const u of daily_uploads) await db.table('daily_uploads').insert(u);
    for (const i of issue_reports) await db.table('issue_reports').insert(i);
    for (const n of notifications) await db.table('notifications').insert(n);
    for (const a of audit_logs) await db.table('audit_logs').insert(a);
  }

  // Also create a couple of sample placeholder image files so proof viewer has real photos
  const uploadsDir = path.join(__dirname, '..', '..', 'uploads', 'proofs');
  if (!fs.existsSync(uploadsDir)) fs.mkdirSync(uploadsDir, { recursive: true });

  const placeholderSvg = `<svg xmlns="http://www.w3.org/2000/svg" width="600" height="400" viewBox="0 0 600 400">
    <rect width="600" height="400" fill="#1e293b"/>
    <rect x="50" y="50" width="220" height="300" rx="10" fill="#0f766e" stroke="#14b8a6" stroke-width="4"/>
    <text x="160" y="180" font-family="Arial, sans-serif" font-size="20" font-weight="bold" fill="#ffffff" text-anchor="middle">PRAN Frooto</text>
    <text x="160" y="210" font-family="Arial, sans-serif" font-size="14" fill="#ccfbf1" text-anchor="middle">Advertisement Banner</text>
    
    <rect x="320" y="80" width="230" height="240" rx="8" fill="#ffffff"/>
    <rect x="350" y="110" width="60" height="60" fill="#000000"/>
    <rect x="460" y="110" width="60" height="60" fill="#000000"/>
    <rect x="350" y="220" width="60" height="60" fill="#000000"/>
    <rect x="430" y="190" width="30" height="30" fill="#000000"/>
    <text x="435" y="300" font-family="Arial, sans-serif" font-size="16" font-weight="bold" fill="#000000" text-anchor="middle">bKash Merchant QR</text>
    <text x="300" y="380" font-family="Arial, sans-serif" font-size="14" fill="#94a3b8" text-anchor="middle">Location: Mirpur 1, Dhaka • GPS Validated</text>
  </svg>`;

  fs.writeFileSync(path.join(uploadsDir, 'sample_mirpur_tea.jpg'), placeholderSvg);
  fs.writeFileSync(path.join(uploadsDir, 'sample_mirpur_grocery.jpg'), placeholderSvg);
  fs.writeFileSync(path.join(uploadsDir, 'sample_uttara_veg.jpg'), placeholderSvg);

  console.log('[SEED] Database seeding completed successfully with 7 users, 2 companies, 3 zones, 7 shops, and sample uploads.');
}

if (require.main === module) {
  seed()
    .then(() => process.exit(0))
    .catch(err => {
      console.error('[SEED] Failed:', err);
      process.exit(1);
    });
}

module.exports = seed;

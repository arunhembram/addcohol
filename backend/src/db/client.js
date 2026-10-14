const fs = require('fs');
const path = require('path');
const { Pool } = require('pg');

const DATA_DIR = path.join(__dirname, '..', '..', 'data');
const DB_FILE = path.join(DATA_DIR, 'db.json');

// Ensure data directory exists
if (!fs.existsSync(DATA_DIR)) {
  fs.mkdirSync(DATA_DIR, { recursive: true });
}

let pool = null;
const isPg = Boolean(process.env.DATABASE_URL);

if (isPg) {
  pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false
  });
  console.log('[DB] Configured for PostgreSQL (Cloud SQL / Supabase / Remote)');
} else {
  console.log('[DB] Using embedded relational JSON engine (data/db.json)');
}

// In-memory / file cache for embedded engine
let embeddedData = {
  users: [],
  companies: [],
  company_users: [],
  zones: [],
  zone_employee_assignments: [],
  zone_company_assignments: [],
  shops: [],
  daily_uploads: [],
  issue_reports: [],
  notifications: [],
  audit_logs: []
};

function loadEmbeddedData() {
  if (fs.existsSync(DB_FILE)) {
    try {
      const content = fs.readFileSync(DB_FILE, 'utf8');
      embeddedData = { ...embeddedData, ...JSON.parse(content) };
    } catch (err) {
      console.error('[DB] Error reading embedded db.json:', err);
    }
  }
}

function saveEmbeddedData() {
  try {
    fs.writeFileSync(DB_FILE, JSON.stringify(embeddedData, null, 2), 'utf8');
  } catch (err) {
    console.error('[DB] Error writing embedded db.json:', err);
  }
}

loadEmbeddedData();

/**
 * Universal query interface.
 * Supports:
 * - Direct Postgres queries when DATABASE_URL is set
 * - Table operations for embedded engine
 */
const db = {
  isPg,

  async query(text, params = []) {
    if (isPg && pool) {
      const res = await pool.query(text, params);
      return res;
    }

    // Basic SQL simulator for embedded data if raw SQL is executed
    return { rows: [] };
  },

  // Helper table methods for reliable cross-engine operation
  table(tableName) {
    const table = embeddedData[tableName] || [];

    return {
      async find(predicate = () => true) {
        if (isPg && pool) {
          // In PG mode, we fallback to custom queries
          const res = await pool.query(`SELECT * FROM ${tableName}`);
          return res.rows.filter(predicate);
        }
        return table.filter(predicate);
      },

      async findOne(predicate) {
        if (isPg && pool) {
          const res = await pool.query(`SELECT * FROM ${tableName}`);
          return res.rows.find(predicate) || null;
        }
        return table.find(predicate) || null;
      },

      async findById(id) {
        return this.findOne(r => r.id === id);
      },

      async insert(record) {
        if (isPg && pool) {
          const keys = Object.keys(record);
          const values = Object.values(record);
          const placeholders = keys.map((_, i) => `$${i + 1}`).join(', ');
          const sql = `INSERT INTO ${tableName} (${keys.join(', ')}) VALUES (${placeholders}) RETURNING *`;
          const res = await pool.query(sql, values);
          return res.rows[0];
        }

        table.push(record);
        saveEmbeddedData();
        return record;
      },

      async update(id, updates) {
        if (isPg && pool) {
          const keys = Object.keys(updates);
          const values = Object.values(updates);
          const setClause = keys.map((k, i) => `${k} = $${i + 1}`).join(', ');
          const sql = `UPDATE ${tableName} SET ${setClause}, updated_at = NOW() WHERE id = $${keys.length + 1} RETURNING *`;
          const res = await pool.query(sql, [...values, id]);
          return res.rows[0];
        }

        const idx = table.findIndex(r => r.id === id);
        if (idx !== -1) {
          table[idx] = { ...table[idx], ...updates, updated_at: new Date().toISOString() };
          saveEmbeddedData();
          return table[idx];
        }
        return null;
      },

      async delete(id) {
        if (isPg && pool) {
          await pool.query(`DELETE FROM ${tableName} WHERE id = $1`, [id]);
          return true;
        }

        const idx = table.findIndex(r => r.id === id);
        if (idx !== -1) {
          table.splice(idx, 1);
          saveEmbeddedData();
          return true;
        }
        return false;
      },

      async count(predicate = () => true) {
        const rows = await this.find(predicate);
        return rows.length;
      }
    };
  },

  getRawData() {
    return embeddedData;
  },

  resetEmbeddedData(newData) {
    embeddedData = newData;
    saveEmbeddedData();
  }
};

module.exports = db;

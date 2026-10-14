const jwt = require('jsonwebtoken');
const db = require('../db/client');

const JWT_SECRET = process.env.JWT_SECRET || 'adproof-super-secret-key-2026';

/**
 * Generates a signed JWT token for a user
 */
function generateToken(user, companyId = null) {
  return jwt.sign(
    {
      id: user.id,
      role: user.role,
      phone: user.phone,
      email: user.email,
      companyId: companyId
    },
    JWT_SECRET,
    { expiresIn: '30d' }
  );
}

/**
 * Middleware: Requires a valid Bearer JWT
 */
async function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Authentication required. No token provided.' });
  }

  jwt.verify(token, JWT_SECRET, async (err, decoded) => {
    if (err) {
      return res.status(403).json({ error: 'Invalid or expired authentication token.' });
    }

    const user = await db.table('users').findById(decoded.id);
    if (!user || !user.is_active) {
      return res.status(403).json({ error: 'User account is inactive or not found.' });
    }

    // Attach user and companyId (if company_user)
    req.user = {
      id: user.id,
      role: user.role,
      full_name: user.full_name,
      phone: user.phone,
      email: user.email,
      companyId: decoded.companyId || null
    };

    // If company user and no companyId in token, look up from company_users table
    if (user.role === 'company_user' && !req.user.companyId) {
      const cu = await db.table('company_users').findOne(c => c.user_id === user.id);
      if (cu) {
        req.user.companyId = cu.company_id;
        req.user.permission_level = cu.permission_level;
      }
    }

    next();
  });
}

module.exports = {
  generateToken,
  authenticateToken,
  JWT_SECRET
};

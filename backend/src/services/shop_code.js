const crypto = require('crypto');
const db = require('../db/client');

/**
 * Generates an exactly 8-digit unique Shop Code.
 * Checks for collision against existing shops.
 */
async function generateUniqueShopCode() {
  const shopsTable = db.table('shops');
  let code = '';
  let isUnique = false;
  let attempts = 0;

  while (!isUnique && attempts < 10) {
    attempts++;
    // Generate random 8-digit number between 10000000 and 99999999
    const num = crypto.randomInt(10000000, 100000000);
    code = num.toString();

    const existing = await shopsTable.findOne(s => s.shop_code === code);
    if (!existing) {
      isUnique = true;
    }
  }

  if (!isUnique) {
    throw new Error('Failed to generate a unique 8-digit shop code after 10 attempts');
  }

  return code;
}

module.exports = { generateUniqueShopCode };

const jwt = require('jsonwebtoken');
const SECRET = process.env.JWT_SECRET || 'dev_secret';

function signLicense(lic) {
  return jwt.sign(
    { sub: lic.id, key: lic.license_key, role: lic.role },
    SECRET,
    { expiresIn: '30d' }
  );
}

function verifyToken(token) {
  return jwt.verify(token, SECRET);
}

module.exports = { signLicense, verifyToken };

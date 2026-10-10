const { verifyToken } = require('./jwt');

function requireToken(req, res, next) {
  const h = req.headers.authorization || '';
  const token = h.startsWith('Bearer ') ? h.slice(7) : null;
  if (!token) {
    return res.status(401).json({
      success: false,
      error: { name: 'unauthorized', message: 'Token requerido' }
    });
  }
  try {
    req.lic = verifyToken(token);
    next();
  } catch (err) {
    res.status(401).json({
      success: false,
      error: { name: 'unauthorized', message: 'Token inválido' }
    });
  }
}

function requireAdmin(req, res, next) {
  const adminToken = req.headers['x-admin-token'];
  if (!adminToken || adminToken !== process.env.ADMIN_TOKEN) {
    return res.status(401).json({
      success: false,
      error: { name: 'unauthorized', message: 'Admin token inválido' }
    });
  }
  next();
}

module.exports = { requireToken, requireAdmin };

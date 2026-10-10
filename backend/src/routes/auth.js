const express = require('express');
const pool = require('../db');
const { signLicense } = require('../jwt');
const { requireToken } = require('../middleware');

const router = express.Router();
const fail = (name, message) => ({ success: false, error: { name, message } });

// POST /api/v1/auth
router.post('/auth', async (req, res) => {
  const { license_key, hwid } = req.body || {};
  if (!license_key || !hwid) {
    return res.status(400).json(fail('missing', 'Faltan license_key o hwid'));
  }

  try {
    const key = String(license_key).trim().toUpperCase();
    const { rows } = await pool.query('SELECT * FROM licenses WHERE license_key = $1', [key]);
    if (!rows.length) {
      return res.status(401).json(fail('invalid', 'Clave no válida'));
    }
    const lic = rows[0];

    if (lic.banned) {
      return res.status(403).json(fail('banned', 'Licencia baneada'));
    }

    if (!lic.hwid) {
      const expiresAt = lic.duration_hours != null
        ? new Date(Date.now() + lic.duration_hours * 3600 * 1000)
        : null;
      await pool.query(
        'UPDATE licenses SET hwid = $1, activated_at = NOW(), expires_at = $2, last_used_at = NOW() WHERE id = $3',
        [hwid, expiresAt, lic.id]
      );
      lic.hwid = hwid;
      lic.expires_at = expiresAt;
    } else if (lic.hwid !== hwid) {
      return res.status(403).json(fail('hwid_mismatch', 'Dispositivo no coincide (locked)'));
    } else {
      await pool.query('UPDATE licenses SET last_used_at = NOW() WHERE id = $1', [lic.id]);
    }

    if (lic.expires_at && new Date(lic.expires_at) < new Date()) {
      return res.status(403).json(fail('expired', 'Licencia expirada'));
    }

    const token = signLicense(lic);
    return res.json({
      success: true,
      message: 'Activación correcta',
      data: {
        token,
        license: {
          id: String(lic.id),
          license_key: lic.license_key,
          role: lic.role,
          hwid: lic.hwid,
          expires_at: lic.expires_at ? new Date(lic.expires_at).toISOString() : null,
          duration_hours: lic.duration_hours,
          is_lifetime: lic.expires_at === null
        }
      }
    });
  } catch (error) {
    console.error('Error en /auth:', error);
    return res.status(500).json(fail('server_error', 'Error interno del servidor'));
  }
});

// GET /api/v1/heartbeat
router.get('/heartbeat', requireToken, async (req, res) => {
  try {
    const { rows } = await pool.query('SELECT * FROM licenses WHERE id = $1', [req.lic.sub]);
    if (!rows.length) {
      return res.status(401).json(fail('unauthorized', 'Licencia inexistente'));
    }
    const lic = rows[0];

    if (lic.banned) {
      return res.status(403).json(fail('banned', 'Licencia baneada'));
    }

    let remaining = null;
    if (lic.expires_at) {
      remaining = Math.floor((new Date(lic.expires_at) - Date.now()) / 1000);
      if (remaining <= 0) {
        return res.status(403).json(fail('expired', 'Licencia expirada'));
      }
    }

    await pool.query('UPDATE licenses SET last_used_at = NOW() WHERE id = $1', [lic.id]);
    return res.json({
      success: true,
      message: 'OK',
      data: {
        status: 'active',
        license_key: lic.license_key,
        expires_at: lic.expires_at ? new Date(lic.expires_at).toISOString() : null,
        remaining_seconds: remaining,
        last_checked_at: new Date().toISOString()
      }
    });
  } catch (error) {
    console.error('Error en /heartbeat:', error);
    return res.status(500).json(fail('server_error', 'Error interno del servidor'));
  }
});

module.exports = router;

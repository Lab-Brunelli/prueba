const express = require('express');
const pool = require('../db');
const { generateKey } = require('../keygen');
const { requireAdmin } = require('../middleware');

const router = express.Router();
router.use(requireAdmin);

// POST /api/v1/admin/keys
router.post('/keys', async (req, res) => {
  const { count = 1, duration_hours = null, role = 'user', note = null } = req.body || {};
  const created = [];
  try {
    for (let i = 0; i < Math.min(count, 100); i++) {
      const key = generateKey();
      const { rows } = await pool.query(
        'INSERT INTO licenses (license_key, role, duration_hours, note) VALUES ($1, $2, $3, $4) RETURNING *',
        [key, role, duration_hours, note]
      );
      created.push(rows[0]);
    }
    res.json({
      success: true,
      message: `${created.length} clave(s) creada(s)`,
      data: created
    });
  } catch (error) {
    console.error('Error al generar claves:', error);
    res.status(500).json({ success: false, error: { name: 'server_error', message: 'Error interno' } });
  }
});

// GET /api/v1/admin/keys
router.get('/keys', async (req, res) => {
  try {
    const { rows } = await pool.query('SELECT * FROM licenses ORDER BY created_at DESC');
    res.json({ success: true, data: rows });
  } catch (error) {
    console.error('Error al listar claves:', error);
    res.status(500).json({ success: false, error: { name: 'server_error', message: 'Error interno' } });
  }
});

// POST /api/v1/admin/ban
router.post('/ban', async (req, res) => {
  const { license_key, banned = true } = req.body || {};
  if (!license_key) {
    return res.status(400).json({ success: false, error: { name: 'missing', message: 'Falta license_key' } });
  }
  try {
    const { rows } = await pool.query(
      'UPDATE licenses SET banned = $1 WHERE license_key = $2 RETURNING *',
      [banned, String(license_key).toUpperCase()]
    );
    if (!rows.length) {
      return res.status(404).json({ success: false, error: { name: 'not_found', message: 'Clave inexistente' } });
    }
    res.json({ success: true, data: rows[0] });
  } catch (error) {
    console.error('Error al banear clave:', error);
    res.status(500).json({ success: false, error: { name: 'server_error', message: 'Error interno' } });
  }
});

// POST /api/v1/admin/reset-hwid
router.post('/reset-hwid', async (req, res) => {
  const { license_key } = req.body || {};
  if (!license_key) {
    return res.status(400).json({ success: false, error: { name: 'missing', message: 'Falta license_key' } });
  }
  try {
    const { rows } = await pool.query(
      'UPDATE licenses SET hwid = NULL, activated_at = NULL, expires_at = NULL WHERE license_key = $1 RETURNING *',
      [String(license_key).toUpperCase()]
    );
    if (!rows.length) {
      return res.status(404).json({ success: false, error: { name: 'not_found', message: 'Clave inexistente' } });
    }
    res.json({ success: true, message: 'HWID liberado', data: rows[0] });
  } catch (error) {
    console.error('Error al reiniciar HWID:', error);
    res.status(500).json({ success: false, error: { name: 'server_error', message: 'Error interno' } });
  }
});

module.exports = router;

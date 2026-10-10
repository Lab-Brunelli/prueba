const express = require('express');
const cors = require('cors');
require('dotenv').config();

const authRoutes = require('./routes/auth');
const adminRoutes = require('./routes/admin');

const app = express();
app.use(cors());
app.use(express.json());

app.get('/', (req, res) => res.json({ ok: true, app: 'Node-Locked License Backend' }));

app.use('/api/v1', authRoutes);
app.use('/api/v1/admin', adminRoutes);

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Backend de licencias ejecutándose en http://localhost:${PORT}`));

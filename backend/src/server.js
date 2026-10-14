require('dotenv').config();
const http = require('http');
const express = require('express');
const cors = require('cors');
const path = require('path');

const { initWebSocket } = require('./services/websocket');
const { initMidnightCron } = require('./services/midnight_cron');

// Routes
const authRoutes = require('./routes/auth.routes');
const zonesRoutes = require('./routes/zones.routes');
const shopsRoutes = require('./routes/shops.routes');
const companiesRoutes = require('./routes/companies.routes');
const assignmentsRoutes = require('./routes/assignments.routes');
const uploadsRoutes = require('./routes/uploads.routes');
const issuesRoutes = require('./routes/issues.routes');
const reportsRoutes = require('./routes/reports.routes');
const auditRoutes = require('./routes/audit.routes');
const cronRoutes = require('./routes/cron.routes');

const app = express();
const server = http.createServer(app);

// Initialize WebSocket hub
initWebSocket(server);

// Initialize midnight expiry cron scheduler (Asia/Dhaka timezone)
initMidnightCron();

// Middleware
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));

app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Health Check
app.get('/api/health', (req, res) => {
  res.json({
    status: 'ok',
    service: 'Advertisement Proof Management Shared Backend',
    version: '1.0.0',
    timestamp: new Date().toISOString()
  });
});

// Register API Routes
app.use('/api/auth', authRoutes);
app.use('/api/zones', zonesRoutes);
app.use('/api/shops', shopsRoutes);
app.use('/api/companies', companiesRoutes);
app.use('/api/zone-company-assignments', assignmentsRoutes);
app.use('/api/uploads', uploadsRoutes);
app.use('/api/issues', issuesRoutes);
app.use('/api/reports', reportsRoutes);
app.use('/api/audit-logs', auditRoutes);
app.use('/api/cron', cronRoutes);

// Serve Flutter Web Owner Admin App if built
const fs = require('fs');
const adminWebBuildPath = path.join(__dirname, '..', '..', 'apps', 'owner_admin_app', 'build', 'web');
if (fs.existsSync(adminWebBuildPath)) {
  app.use(express.static(adminWebBuildPath));
  app.get('*', (req, res, next) => {
    if (req.path.startsWith('/api')) return next();
    res.sendFile(path.join(adminWebBuildPath, 'index.html'));
  });
  console.log('[WEB] Serving Owner Admin Web Dashboard at root /');
}

// Error Handler
app.use((err, req, res, next) => {
  console.error('[SERVER ERROR]', err);
  res.status(err.status || 500).json({
    error: err.message || 'Internal Server Error'
  });
});

const PORT = process.env.PORT || 5000;

server.listen(PORT, () => {
  console.log(`====================================================`);
  console.log(`🚀 AdProof Shared Backend running on port ${PORT}`);
  console.log(`🌐 HTTP API: http://localhost:${PORT}/api/health`);
  console.log(`⚡ WebSocket: ws://localhost:${PORT}`);
  console.log(`====================================================`);
});

module.exports = { app, server };

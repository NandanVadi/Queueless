const express = require('express');
const cors = require('cors');
const authRoutes = require('./routes/auth.routes');
const servicesRoutes = require('./routes/services.routes');
const queueRoutes = require('./routes/queue.routes');
const appointmentRoutes = require('./routes/appointment.routes');
const operatorRoutes = require('./routes/operator.routes');
const adminServicesRoutes = require('./routes/admin_services.routes');
const adminDashboardRoutes = require('./routes/admin_dashboard.routes');
const authenticate = require('./middleware/auth.middleware');
const requireAdmin = require('./middleware/admin.middleware');

const app = express();

// Middleware
app.use(cors({
  origin: [/^http:\/\/localhost(:\d+)?$/, /^http:\/\/127\.0\.0\.1(:\d+)?$/],
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));
app.use(express.json());

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/services', servicesRoutes);
app.use('/api/admin/services', authenticate, requireAdmin, adminServicesRoutes);
app.use('/api/admin/dashboard', authenticate, requireAdmin, adminDashboardRoutes);
app.use('/api/queue', authenticate, queueRoutes);
app.use('/api/appointments', authenticate, appointmentRoutes);
app.use('/api/operator', operatorRoutes);

// 404 Handler
app.use((req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

module.exports = app;

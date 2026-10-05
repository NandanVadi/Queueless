const authRepository = require('../repositories/auth.repository');

async function requireAdmin(req, res, next) {
  if (!req.userId) {
    return res.status(401).json({ error: 'Unauthorized: No token provided' });
  }

  try {
    const user = await authRepository.findById(req.userId);
    if (!user) {
      return res.status(401).json({ error: 'Unauthorized: Invalid token' });
    }

    if (user.role !== 'admin') {
      return res.status(403).json({ error: 'Forbidden: Admin access required' });
    }

    next();
  } catch (error) {
    console.error('Admin authorization error:', error);
    return res.status(500).json({ error: 'Internal Server Error' });
  }
}

module.exports = requireAdmin;

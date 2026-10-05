const authRepository = require('../repositories/auth.repository');

async function requireOperator(req, res, next) {
  // Assume authenticate middleware has already run and set req.userId
  if (!req.userId) {
    return res.status(401).json({ error: 'Unauthorized: No token provided' });
  }

  try {
    const user = await authRepository.findById(req.userId);
    if (!user) {
      return res.status(401).json({ error: 'Unauthorized: Invalid token' });
    }

    if (user.role !== 'operator') {
      return res.status(403).json({ error: 'Forbidden: Operator access required' });
    }

    // Role is valid, proceed
    next();
  } catch (error) {
    console.error('Operator authorization error:', error);
    return res.status(500).json({ error: 'Internal Server Error' });
  }
}

module.exports = requireOperator;

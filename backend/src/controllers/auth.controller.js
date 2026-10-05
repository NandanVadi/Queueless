const authService = require('../services/auth.service');

class AuthController {
  async register(req, res) {
    try {
      const result = await authService.register(req.body);
      res.status(201).json(result);
    } catch (error) {
      console.error('Error during registration:', error);
      const statusCode = error.statusCode || 500;
      res.status(statusCode).json({ error: error.message || 'Internal Server Error' });
    }
  }

  async login(req, res) {
    try {
      const { email, password } = req.body;
      const result = await authService.login(email, password);
      res.status(200).json(result);
    } catch (error) {
      console.error('Error during login:', error);
      const statusCode = error.statusCode || 500;
      res.status(statusCode).json({ error: error.message || 'Internal Server Error' });
    }
  }

  async getCurrentUser(req, res) {
    try {
      // req.userId is set by the authMiddleware
      const user = await authService.getCurrentUser(req.userId);
      res.status(200).json({ user });
    } catch (error) {
      console.error('Error fetching current user:', error);
      const statusCode = error.statusCode || 500;
      res.status(statusCode).json({ error: error.message || 'Internal Server Error' });
    }
  }

  async updateProfile(req, res) {
    try {
      // Intentionally ignore any provided userId or role in req.body
      const user = await authService.updateProfile(req.userId, req.body);
      res.status(200).json({ user });
    } catch (error) {
      console.error('Error updating profile:', error);
      const statusCode = error.statusCode || 500;
      res.status(statusCode).json({ error: error.message || 'Internal Server Error' });
    }
  }

  async changePassword(req, res) {
    try {
      const { currentPassword, newPassword } = req.body;
      await authService.changePassword(req.userId, currentPassword, newPassword);
      res.status(200).json({ message: 'Password updated successfully' });
    } catch (error) {
      console.error('Error changing password:', error);
      const statusCode = error.statusCode || 500;
      res.status(statusCode).json({ error: error.message || 'Internal Server Error' });
    }
  }
}

module.exports = new AuthController();

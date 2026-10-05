const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const authRepository = require('../repositories/auth.repository');

const JWT_SECRET = process.env.JWT_SECRET || 'queueless_secret_dev';

class AuthService {
  async register(data) {
    const { name, email, password } = data;

    if (!name || !email || !password) {
      const error = new Error('Name, email, and password are required');
      error.statusCode = 400;
      throw error;
    }

    const normalizedEmail = email.toLowerCase().trim();

    const existingUser = await authRepository.findByEmail(normalizedEmail);
    if (existingUser) {
      const error = new Error('Email is already registered');
      error.statusCode = 409;
      throw error;
    }

    if (password.length < 6) {
      const error = new Error('Password must be at least 6 characters');
      error.statusCode = 400;
      throw error;
    }

    const saltRounds = 10;
    const passwordHash = await bcrypt.hash(password, saltRounds);

    const user = await authRepository.createUser({
      name: name.trim(),
      email: normalizedEmail,
      passwordHash
    });

    const token = this._generateToken(user);
    return { user: this._safeUser(user), token };
  }

  async login(email, password) {
    if (!email || !password) {
      const error = new Error('Email and password are required');
      error.statusCode = 400;
      throw error;
    }

    const normalizedEmail = email.toLowerCase().trim();
    const user = await authRepository.findByEmail(normalizedEmail);

    if (!user) {
      // Use generic error for security
      const error = new Error('Invalid email or password');
      error.statusCode = 401;
      throw error;
    }

    const passwordMatch = await bcrypt.compare(password, user.passwordHash);
    if (!passwordMatch) {
      const error = new Error('Invalid email or password');
      error.statusCode = 401;
      throw error;
    }

    const token = this._generateToken(user);
    return { user: this._safeUser(user), token };
  }

  async getCurrentUser(id) {
    const user = await authRepository.findById(id);
    if (!user) {
      const error = new Error('User not found');
      error.statusCode = 404;
      throw error;
    }
    return this._safeUser(user);
  }

  async updateProfile(id, data) {
    const { name } = data;
    if (!name || name.trim().length === 0) {
      const error = new Error('Name is required and cannot be empty');
      error.statusCode = 400;
      throw error;
    }
    if (name.trim().length > 100) {
      const error = new Error('Name is too long');
      error.statusCode = 400;
      throw error;
    }

    const updatedUser = await authRepository.updateUser(id, { name: name.trim() });
    return this._safeUser(updatedUser);
  }

  async changePassword(id, currentPassword, newPassword) {
    if (!currentPassword || !newPassword) {
      const error = new Error('Current password and new password are required');
      error.statusCode = 400;
      throw error;
    }

    if (newPassword.length < 6) {
      const error = new Error('New password must be at least 6 characters');
      error.statusCode = 400;
      throw error;
    }

    const user = await authRepository.findById(id);
    if (!user) {
      const error = new Error('User not found');
      error.statusCode = 404;
      throw error;
    }

    const passwordMatch = await bcrypt.compare(currentPassword, user.passwordHash);
    if (!passwordMatch) {
      const error = new Error('Incorrect current password');
      error.statusCode = 401; // Following existing login convention
      throw error;
    }

    const saltRounds = 10;
    const newPasswordHash = await bcrypt.hash(newPassword, saltRounds);

    await authRepository.updateUser(id, { passwordHash: newPasswordHash });
  }

  _generateToken(user) {
    return jwt.sign({ userId: user.id }, JWT_SECRET, { expiresIn: '7d' });
  }

  _safeUser(user) {
    const { passwordHash, ...safeUser } = user;
    return safeUser;
  }
}

module.exports = new AuthService();

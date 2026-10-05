import 'package:flutter/material.dart';
import '../models/user.dart';
import '../repositories/auth_repository.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'change_password_screen.dart';
import '../services/socket_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthRepository _authRepo = AuthRepository(ApiService());
  User? _user;
  bool _isLoading = true;
  String? _error;

  final TextEditingController _nameController = TextEditingController();
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = await _authRepo.getCurrentUser();
      if (!mounted) return;
      setState(() {
        _user = user;
        if (user != null) {
          _nameController.text = user.name;
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final updatedUser = await _authRepo.updateProfile(newName);
      if (!mounted) return;
      setState(() {
        _user = updatedUser;
        _nameController.text = updatedUser.name;
        _isEditing = false;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _logout() async {
    await _authRepo.logout();
    SocketService.instance.disconnect();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  String _formatRole(String role) {
    if (role == 'admin') return 'Administrator';
    if (role == 'operator') return 'Operator';
    return 'Customer';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Failed to load profile', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadUser,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_user == null) {
      return const Center(child: Text('Not logged in.'));
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const Text(
          'Profile Information',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        
        // Name
        if (_isEditing)
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
          )
        else
          ListTile(
            title: const Text('Name'),
            subtitle: Text(_user!.name),
            contentPadding: EdgeInsets.zero,
          ),
          
        const SizedBox(height: 16),
        
        // Email (Read-only)
        ListTile(
          title: const Text('Email'),
          subtitle: Text(_user!.email),
          contentPadding: EdgeInsets.zero,
          trailing: const Icon(Icons.lock_outline, size: 16, color: Colors.grey),
        ),
        const Divider(),
        
        // Role
        ListTile(
          title: const Text('Role'),
          subtitle: Text(_formatRole(_user!.role)),
          contentPadding: EdgeInsets.zero,
          trailing: const Icon(Icons.shield_outlined, size: 16, color: Colors.grey),
        ),
        const Divider(),

        const SizedBox(height: 24),
        
        if (_isEditing)
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _isEditing = false;
                      _nameController.text = _user!.name;
                    });
                  },
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
          )
        else
          FilledButton.icon(
            onPressed: () {
              setState(() {
                _isEditing = true;
              });
            },
            icon: const Icon(Icons.edit),
            label: const Text('Edit Profile'),
          ),

        const SizedBox(height: 16),
        
        OutlinedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
            );
          },
          icon: const Icon(Icons.lock),
          label: const Text('Change Password'),
        ),
        
        const SizedBox(height: 48),
        
        OutlinedButton.icon(
          onPressed: _logout,
          icon: const Icon(Icons.logout, color: Colors.red),
          label: const Text('Logout', style: TextStyle(color: Colors.red)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.red),
          ),
        ),
      ],
    );
  }
}

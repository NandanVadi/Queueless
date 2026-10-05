import 'package:flutter/material.dart';
import '../models/dashboard.dart';
import '../services/api_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final ApiService _apiService = ApiService();
  DashboardData? _dashboard;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      final data = await _apiService.getAdminDashboard();
      if (mounted) {
        setState(() {
          _dashboard = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
            Text('Failed to load dashboard', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadDashboard,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_dashboard == null) {
      return const Center(child: Text('No dashboard data available.'));
    }

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildUsersSection(),
          const SizedBox(height: 24),
          _buildQueueSection(),
          const SizedBox(height: 24),
          _buildAppointmentsSection(),
          const SizedBox(height: 24),
          Text('Service Overview', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ..._dashboard!.services.map(_buildServiceSection),
        ],
      ),
    );
  }

  Widget _buildUsersSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Users', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat('Total Users', _dashboard!.users.total.toString()),
                _buildStat('Operators', _dashboard!.users.operators.toString()),
                _buildStat('Admins', _dashboard!.users.admins.toString()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Queue Overview', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.spaceAround,
              children: [
                _buildStat('Today\'s Tokens', _dashboard!.queue.today.toString()),
                _buildStat('Waiting', _dashboard!.queue.waiting.toString(), color: Colors.orange),
                _buildStat('Serving', _dashboard!.queue.serving.toString(), color: Colors.blue),
                _buildStat('Completed', _dashboard!.queue.completed.toString(), color: Colors.green),
                _buildStat('Cancelled', _dashboard!.queue.cancelled.toString(), color: Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Appointments', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.spaceAround,
              children: [
                _buildStat('Today\'s', _dashboard!.appointments.today.toString()),
                _buildStat('Scheduled', _dashboard!.appointments.scheduled.toString(), color: Colors.blue),
                _buildStat('Completed', _dashboard!.appointments.completed.toString(), color: Colors.green),
                _buildStat('Cancelled', _dashboard!.appointments.cancelled.toString(), color: Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceSection(ServiceAnalytics service) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    service.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      decoration: service.isActive ? null : TextDecoration.lineThrough,
                      color: service.isActive ? null : Colors.grey,
                    ),
                  ),
                ),
                if (!service.isActive)
                  const Chip(label: Text('Inactive'), backgroundColor: Colors.redAccent, labelStyle: TextStyle(color: Colors.white)),
              ],
            ),
            const Divider(),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildStat('Waiting', service.peopleWaiting.toString(), color: Colors.orange),
                _buildStat('Serving', service.currentServingToken != null ? '#${service.currentServingToken}' : 'None', color: Colors.blue),
                _buildStat('Today\'s tokens', service.queue.today.toString()),
                _buildStat('Completed', service.queue.completed.toString(), color: Colors.green),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

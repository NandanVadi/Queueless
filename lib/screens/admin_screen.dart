import 'package:flutter/material.dart';
import '../models/service.dart';
import '../repositories/service_repository.dart';
import '../widgets/service_form.dart';
import 'admin_dashboard_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final ServiceRepository _serviceRepository = ServiceRepository();
  List<Service> _services = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      final services = await _serviceRepository.getAllServicesForAdmin();
      if (mounted) {
        setState(() {
          _services = services;
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

  void _showCreateServiceModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Create Service', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              ServiceForm(
                onSubmit: (name, description, icon) async {
                  await _serviceRepository.createService(Service(
                    name: name,
                    description: description,
                    icon: icon,
                    isActive: true,
                  ));
                  if (context.mounted) {
                    Navigator.pop(context);
                    _loadServices();
                  }
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  void _showEditServiceModal(Service service) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Edit Service', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              ServiceForm(
                initialService: service,
                onSubmit: (name, description, icon) async {
                  await _serviceRepository.updateService(
                    service.id!,
                    service.copyWith(name: name, description: description, icon: icon),
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    _loadServices();
                  }
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleServiceStatus(Service service) async {
    try {
      await _serviceRepository.setServiceActive(service.id!, !service.isActive);
      _loadServices();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'bank': return Icons.account_balance;
      case 'hospital': return Icons.local_hospital;
      case 'medical': return Icons.medical_services;
      case 'government': return Icons.account_balance;
      case 'store': return Icons.store;
      default: return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Console'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Dashboard'),
              Tab(text: 'Services'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadServices,
            ),
          ],
        ),
        floatingActionButton: Builder(
          builder: (context) {
            final tabController = DefaultTabController.of(context);
            return AnimatedBuilder(
              animation: tabController,
              builder: (context, child) {
                if (tabController.index == 1) {
                  return FloatingActionButton.extended(
                    onPressed: _showCreateServiceModal,
                    icon: const Icon(Icons.add),
                    label: const Text('New Service'),
                  );
                }
                return const SizedBox.shrink();
              },
            );
          },
        ),
        body: TabBarView(
          children: [
            const AdminDashboardScreen(),
            _buildBody(),
          ],
        ),
      ),
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
            Text('Failed to load services', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadServices,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_services.isEmpty) {
      return const Center(child: Text('No services found.'));
    }

    return RefreshIndicator(
      onRefresh: _loadServices,
      child: ListView.builder(
        itemCount: _services.length,
        itemBuilder: (context, index) {
          final service = _services[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: service.isActive ? null : Colors.grey.shade200,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: service.isActive ? Theme.of(context).primaryColor : Colors.grey,
                child: Icon(_getIconData(service.icon), color: Colors.white),
              ),
              title: Text(
                service.name,
                style: TextStyle(
                  decoration: service.isActive ? null : TextDecoration.lineThrough,
                  color: service.isActive ? null : Colors.grey.shade600,
                ),
              ),
              subtitle: Text(
                service.isActive ? 'Active' : 'Inactive',
                style: TextStyle(
                  color: service.isActive ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _showEditServiceModal(service),
                    tooltip: 'Edit Service',
                  ),
                  Switch(
                    value: service.isActive,
                    onChanged: (value) => _toggleServiceStatus(service),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

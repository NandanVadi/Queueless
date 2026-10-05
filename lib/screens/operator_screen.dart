import 'package:flutter/material.dart';
import 'dart:async';
import '../models/service.dart';
import '../models/queue_token.dart';
import '../repositories/service_repository.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class OperatorScreen extends StatefulWidget {
  const OperatorScreen({super.key});

  @override
  State<OperatorScreen> createState() => _OperatorScreenState();
}

class _OperatorScreenState extends State<OperatorScreen> {
  final _serviceRepo = ServiceRepository();
  final _apiService = ApiService();
  
  StreamSubscription<int>? _queueSubscription;

  List<Service> _services = [];
  Service? _selectedService;
  bool _isLoading = true;
  String? _errorMessage;
  
  QueueToken? _currentlyServing;
  QueueToken? _nextWaiting;
  List<QueueToken> _queueList = [];

  @override
  void initState() {
    super.initState();
    _loadServices();
    _queueSubscription = SocketService.instance.onQueueUpdated.listen(_handleQueueUpdated);
  }

  @override
  void dispose() {
    _queueSubscription?.cancel();
    super.dispose();
  }

  void _handleQueueUpdated(int serviceId) {
    if (_selectedService != null && _selectedService!.id == serviceId) {
      _loadQueueState();
    }
  }

  Future<void> _loadServices() async {
    try {
      final services = await _serviceRepo.getServices();
      setState(() {
        _services = services;
        _isLoading = false;
        if (_services.isNotEmpty) {
          _selectedService = _services.first;
          _loadQueueState();
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load services';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadQueueState() async {
    if (_selectedService == null || _selectedService!.id == null) return;
    
    try {
      final tokens = await _apiService.getServiceQueue(_selectedService!.id!);
      
      final servingTokens = tokens.where((t) => t.status == 'serving').toList();
      final waitingTokens = tokens.where((t) => t.status == 'waiting').toList();

      if (!mounted) return;
      setState(() {
        _currentlyServing = servingTokens.isNotEmpty ? servingTokens.first : null;
        _nextWaiting = waitingTokens.isNotEmpty ? waitingTokens.first : null;
        _queueList = waitingTokens;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading queue: $e')),
      );
    }
  }

  Future<void> _callNextToken() async {
    if (_selectedService == null || _selectedService!.id == null) return;
    try {
      await _apiService.callNextToken(_selectedService!.id!);
      _loadQueueState();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _completeToken() async {
    if (_currentlyServing == null || _currentlyServing!.id == null) return;
    try {
      await _apiService.completeToken(_currentlyServing!.id!);
      _loadQueueState();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage != null) {
      return Scaffold(body: Center(child: Text(_errorMessage!)));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Operator Dashboard')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButton<Service>(
              value: _selectedService,
              isExpanded: true,
              items: _services.map((Service service) {
                return DropdownMenuItem<Service>(
                  value: service,
                  child: Text(service.name),
                );
              }).toList(),
              onChanged: (Service? newValue) {
                setState(() {
                  _selectedService = newValue;
                  _currentlyServing = null;
                  _nextWaiting = null;
                  _queueList = [];
                });
                _loadQueueState();
              },
            ),
            const SizedBox(height: 24),
            
            // Currently Serving Card
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text('Currently Serving', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      _currentlyServing != null ? '#${_currentlyServing!.tokenNumber}' : 'None',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _currentlyServing != null ? _completeToken : null,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: const Text('Complete Token', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Next Waiting Card
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text('Next Waiting', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      _nextWaiting != null ? '#${_nextWaiting!.tokenNumber}' : 'None',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _nextWaiting != null && _currentlyServing == null ? _callNextToken : null,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                      child: const Text('Call Next', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            const Text('Queue:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _queueList.length,
                itemBuilder: (context, index) {
                  final token = _queueList[index];
                  return ListTile(
                    leading: CircleAvatar(child: Text('${token.tokenNumber}')),
                    title: Text('Token #${token.tokenNumber}'),
                    subtitle: Text('Status: ${token.status}'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

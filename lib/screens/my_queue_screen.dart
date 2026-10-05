import 'package:flutter/material.dart';
import '../models/queue_token.dart';
import '../models/service.dart';
import '../repositories/queue_repository.dart';
import '../database/database_helper.dart';
import '../utils/app_colors.dart';
import '../widgets/empty_state.dart';
import '../widgets/queue_token_card.dart';
import '../services/socket_service.dart';
import 'dart:async';

class MyQueueScreen extends StatefulWidget {
  final bool isActive;
  
  const MyQueueScreen({super.key, this.isActive = false});

  @override
  State<MyQueueScreen> createState() => _MyQueueScreenState();
}

class _MyQueueScreenState extends State<MyQueueScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<QueueToken> _activeTokens = [];
  Map<int, Service> _servicesMap = {};
  final QueueRepository _queueRepository = QueueRepository();
  StreamSubscription<int>? _socketSubscription;

  @override
  void initState() {
    super.initState();
    _loadQueue();
    _socketSubscription = SocketService.instance.onQueueUpdated.listen((serviceId) {
      if (mounted && widget.isActive) {
        _loadQueue();
      }
    });
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(MyQueueScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _loadQueue();
    }
  }

  Future<void> _loadQueue() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final tokens = await _queueRepository.getActiveQueueTokens();
      final allServices = await DatabaseHelper.instance.getServices();
      
      final servicesMap = {for (var s in allServices) s.id!: s};
      
      if (!mounted) return;
      
      setState(() {
        _activeTokens = tokens;
        _servicesMap = servicesMap;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load your queue. Please try again.';
      });
    }
  }

  Future<void> _leaveQueue(QueueToken token) async {
    try {
      if (token.id == null) return;
      await _queueRepository.cancelQueueToken(token.id!);
      _loadQueue();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to leave queue. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('My Queue'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadQueue,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.statusCancelled),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loadQueue,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_activeTokens.isEmpty) {
      return const EmptyState(
        icon: Icons.confirmation_number_outlined,
        title: 'No Active Queue',
        message: 'Take a token from a service on the Home screen to see your queue position here.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadQueue,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 24, top: 8),
        itemCount: _activeTokens.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.wifi_tethering, size: 16, color: AppColors.statusActive),
                  SizedBox(width: 8),
                  Text(
                    'Live Queue • Updating automatically',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.statusActive,
                    ),
                  ),
                ],
              ),
            );
          }

          final token = _activeTokens[index - 1];
          final service = _servicesMap[token.serviceId];
          
          if (service == null) return const SizedBox.shrink();

          return QueueTokenCard(
            token: token,
            service: service,
            onLeave: () => _leaveQueue(token),
          );
        },
      ),
    );
  }
}

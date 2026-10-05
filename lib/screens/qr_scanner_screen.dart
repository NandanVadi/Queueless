import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../utils/app_colors.dart';
import '../utils/qr_payload.dart';
import '../database/database_helper.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );

  bool _isProcessing = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first;
    final String? rawValue = barcode.rawValue;

    if (rawValue == null || rawValue.isEmpty) return;

    setState(() {
      _isProcessing = true;
    });

    _scannerController.stop();

    try {
      final payload = QrPayloadService.decodeAndValidate(rawValue);
      await _verifyPayload(payload);
    } catch (e) {
      _showResultDialog(
        title: 'Invalid QR Code',
        message: e.toString(),
        isSuccess: false,
      );
    }
  }

  Future<void> _verifyPayload(Map<String, dynamic> payload) async {
    final type = payload['type'];
    final id = payload['id'] as int;
    final db = DatabaseHelper.instance;

    if (type == QrPayloadService.typeQueueToken) {
      final token = await db.getQueueTokenById(id);
      if (token == null) {
        _showResultDialog(
          title: 'Not Found',
          message: 'This queue token does not exist in the database.',
          isSuccess: false,
        );
        return;
      }
      
      final service = await db.getServiceById(token.serviceId);
      final serviceName = service?.name ?? 'Unknown Service';

      final isActive = token.status == 'waiting' || token.status == 'serving';

      _showResultDialog(
        title: isActive ? 'Valid Queue Token' : 'Invalid Queue Token',
        message: 'Token: #${token.tokenNumber}\nService: $serviceName\nStatus: ${token.status.toUpperCase()}',
        isSuccess: isActive,
      );
    } else if (type == QrPayloadService.typeAppointment) {
      final appointment = await db.getAppointmentById(id);
      if (appointment == null) {
        _showResultDialog(
          title: 'Not Found',
          message: 'This appointment does not exist in the database.',
          isSuccess: false,
        );
        return;
      }

      final service = await db.getServiceById(appointment.serviceId);
      final serviceName = service?.name ?? 'Unknown Service';

      final isActive = appointment.status == 'scheduled' || appointment.status == 'pending' || appointment.status == 'confirmed';

      _showResultDialog(
        title: isActive ? 'Valid Appointment' : 'Invalid Appointment',
        message: 'Service: $serviceName\nDate: ${appointment.appointmentDate}\nTime: ${appointment.appointmentTime}\nStatus: ${appointment.status.toUpperCase()}',
        isSuccess: isActive,
      );
    }
  }

  void _showResultDialog({
    required String title,
    required String message,
    required bool isSuccess,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          isSuccess ? Icons.check_circle_outline : Icons.error_outline,
          color: isSuccess ? AppColors.statusActive : AppColors.statusCancelled,
          size: 48,
        ),
        title: Text(title),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() {
                _isProcessing = false;
              });
              _scannerController.start();
            },
            child: const Text('Scan Another'),
          ),
          OutlinedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan QR Code'),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _scannerController,
              builder: (context, state, child) {
                switch (state.torchState) {
                  case TorchState.off:
                    return const Icon(Icons.flash_off, color: Colors.grey);
                  case TorchState.on:
                    return const Icon(Icons.flash_on, color: Colors.yellow);
                  case TorchState.unavailable:
                  default:
                    return const Icon(Icons.flash_off, color: Colors.grey);
                }
              },
            ),
            onPressed: () => _scannerController.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch_outlined),
            onPressed: () => _scannerController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'Scanner Error: ${error.errorCode.name}\n\nCamera might not be supported on this platform.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          
          // Scanner Overlay
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withAlpha(100), width: 2),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          
          // Processing overlay
          if (_isProcessing)
            Container(
              color: Colors.black.withAlpha(150),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
            
          // Helper text
          Positioned(
            bottom: 48,
            left: 24,
            right: 24,
            child: Text(
              'Align the QR code within the frame to verify it.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withAlpha(200),
                fontSize: 14,
                backgroundColor: Colors.black.withAlpha(100),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

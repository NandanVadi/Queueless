import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  /// Resolves the correct base URL for local development depending on the platform.
  /// 
  /// - Web: uses localhost
  /// - Android Emulator: uses 10.0.2.2 to access the host machine's localhost
  /// - iOS Simulator / macOS / Windows / Linux: uses localhost
  /// 
  /// Note: Real physical devices will need the host machine's actual IP address.
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000/api';
    }
    if (Platform.isAndroid) {
      // Android emulator maps 10.0.2.2 to the host machine's localhost (127.0.0.1)
      return 'http://10.0.2.2:3000/api';
    }
    // Default for iOS Simulator, macOS, etc.
    return 'http://localhost:3000/api';
  }
}

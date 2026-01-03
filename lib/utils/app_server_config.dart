import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

class AppServerConfig {
  static String get baseUrl {
    // TODO: Replace with your actual API base URL
    // Example: 'https://api.yourdomain.com' or 'http://localhost:8000' for local development
    // Make sure the URL includes the protocol (http:// or https://) and does NOT end with a slash

    if (kReleaseMode) {
      // Production API URL
      return 'https://mobile.cycle-menstruel.com'; // Production API URL
    } else if (kProfileMode) {
      // Staging/Profile API URL
      return 'https://mobile.cycle-menstruel.com'; // Staging/Profile API URL
    } else {
      // Development API URL
      // For Android: Use 10.0.2.2 for emulator (maps to host's localhost)
      // For iOS Simulator: Use localhost (works directly)
      // For Physical Android Device: Use your computer's IP address (e.g., 192.168.1.100)
      // For Web: Use localhost

      if (kIsWeb) {
        return 'http://localhost:8000';
      } else if (Platform.isAndroid) {
        // Android Emulator uses 10.0.2.2 to access host machine's localhost
        // For physical device, use your computer's IP address (must be on same network)
        // To find your IP: Run 'ipconfig' (Windows) or 'ifconfig' (Mac/Linux)
        // Look for IPv4 Address under your active network adapter

        // IMPORTANT: Choose the correct option based on your setup:
        // Uncomment ONE of the following lines:

        // return 'http://10.0.2.2:8000'; // For Android Emulator
        return 'https://mobile.cycle-menstruel.com'; // Base URL for API calls
      } else if (Platform.isIOS) {
        // iOS Simulator can use localhost directly
        // For physical iOS device, use your computer's IP address
        return 'http://localhost:8000'; // For iOS Simulator
        // return 'http://192.168.1.XXX:8000'; // For Physical iOS Device - Replace XXX with your IP
      } else {
        return 'http://localhost:8000';
      }
    }
  }
}

import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConfig {
  // Cho phép ghi đè hoàn toàn qua --dart-define=BASE_URL=http://...
  static const String customBaseUrl = String.fromEnvironment('BASE_URL');

  // Cổng dự kiến của backend Schema33Trial; vẫn cần xác minh runtime riêng.
  static const String apiPort = String.fromEnvironment(
    'API_PORT',
    defaultValue: '5003',
  );

  // 1. IP cho Android Emulator
  static const String emulatorIp = '10.0.2.2';

  // 2. IP của máy tính khi cắm điện thoại thật (hỗ trợ cả qua Wi-Fi 172.16.0.54 hoặc qua ADB reverse 127.0.0.1)
  static const String physicalDeviceIp = String.fromEnvironment(
    'DEVICE_HOST',
    defaultValue: '127.0.0.1',
  );
  // 3. Đổi biến này thành `true` khi build lên điện thoại thật
  static const bool isPhysicalDevice = true;

  static String get baseUrl {
    if (customBaseUrl.isNotEmpty) {
      return customBaseUrl;
    }

    if (kIsWeb) {
      return 'http://localhost:$apiPort';
    }

    if (Platform.isAndroid) {
      return isPhysicalDevice
          ? 'http://$physicalDeviceIp:$apiPort'
          : 'http://$emulatorIp:$apiPort';
    }

    // Fallback cho Windows app / iOS
    return 'http://localhost:$apiPort';
  }
}

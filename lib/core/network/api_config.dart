import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConfig {
  // 1. IP cho Android Emulator (Mac/Windows host đều dùng IP này)
  static const String emulatorIp = '10.0.2.2';
  
  // 2. IP LAN của máy Windows khi cắm điện thoại thật (VD: Samsung A15)
  // BẠN CẦN THAY ĐỔI DÒNG NÀY THÀNH IPv4 THỰC TẾ TRÊN MÁY BẠN.
  // Mở terminal Windows gõ: ipconfig
  static const String physicalDeviceIp = '127.0.0.1'; 
  
  // 3. Đổi biến này thành `true` khi bạn build lên điện thoại thật
  static const bool isPhysicalDevice = true;

  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000';
    }
    
    if (Platform.isAndroid) {
      return isPhysicalDevice 
          ? 'http://$physicalDeviceIp:5000' 
          : 'http://$emulatorIp:5000';
    }
    
    // Fallback cho Windows app / iOS
    return 'http://localhost:5000';
  }
}

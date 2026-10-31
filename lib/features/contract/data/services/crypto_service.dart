import 'package:flutter/services.dart';

class CryptoService {
  static const MethodChannel _channel = MethodChannel('vn.rentcam.rentcam/crypto');

  Future<String> generateKeyPair(String alias) async {
    final String publicKey = await _channel.invokeMethod('generateKeyPair', {'alias': alias});
    return publicKey;
  }

  Future<String> signData(String alias, String data) async {
    final String signature = await _channel.invokeMethod('signData', {
      'alias': alias,
      'data': data,
    });
    return signature;
  }

  Future<bool> verifySignature(String alias, String data, String signature) async {
    final bool isVerified = await _channel.invokeMethod('verifySignature', {
      'alias': alias,
      'data': data,
      'signature': signature,
    });
    return isVerified;
  }
}

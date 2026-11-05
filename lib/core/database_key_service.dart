import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DatabaseKeyService {
  static const String _keyName = 'qattah_database_key_v1';
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      storageNamespace: 'qattah_secure_storage',
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    mOptions: MacOsOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      usesDataProtectionKeychain: false,
    ),
  );

  const DatabaseKeyService();

  Future<String> getOrCreateKey() async {
    final existingKey = await _storage.read(key: _keyName);
    if (existingKey != null && existingKey.isNotEmpty) {
      return existingKey;
    }

    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final key = base64UrlEncode(bytes);
    await _storage.write(key: _keyName, value: key);
    return key;
  }
}

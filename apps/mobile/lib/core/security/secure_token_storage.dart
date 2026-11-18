import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nam_cinema/core/constants/app_constants.dart';

class SecureTokenStorage {
  final FlutterSecureStorage _storage;

  const SecureTokenStorage(this._storage);

  Future<String?> readAccessToken() {
    return _storage.read(key: AppConstants.accessTokenKey);
  }

  Future<String?> readRefreshToken() {
    return _storage.read(key: AppConstants.refreshTokenKey);
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: AppConstants.accessTokenKey, value: accessToken);
    await _storage.write(
      key: AppConstants.refreshTokenKey,
      value: refreshToken,
    );
  }

  Future<void> saveCachedUserJson(String userJson) async {
    await _storage.write(key: AppConstants.userJsonKey, value: userJson);
  }

  Future<String?> readCachedUserJson() {
    return _storage.read(key: AppConstants.userJsonKey);
  }

  Future<void> clearAll() async {
    await _storage.delete(key: AppConstants.accessTokenKey);
    await _storage.delete(key: AppConstants.refreshTokenKey);
    await _storage.delete(key: AppConstants.userJsonKey);
  }
}

final secureTokenStorageProvider = Provider<SecureTokenStorage>((ref) {
  const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  return const SecureTokenStorage(storage);
});

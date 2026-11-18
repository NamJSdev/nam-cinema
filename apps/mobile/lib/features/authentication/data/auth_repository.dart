import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nam_cinema/core/network/api_client.dart';
import 'package:nam_cinema/core/security/secure_token_storage.dart';
import 'package:nam_cinema/features/authentication/domain/auth_models.dart';

class AuthRepository {
  final ApiClient _apiClient;
  final SecureTokenStorage _tokenStorage;

  const AuthRepository({
    required ApiClient apiClient,
    required SecureTokenStorage tokenStorage,
  })  : _apiClient = apiClient,
        _tokenStorage = tokenStorage;

  Future<AuthUser> register({
    required String email,
    required String fullName,
    required String password,
  }) async {
    try {
      final response = await _apiClient.rawDio.post<Map<String, dynamic>>(
        '/auth/register',
        data: {
          'email': email.trim(),
          'full_name': fullName.trim(),
          'password': password,
          'preferred_language': 'vi-VN',
        },
      );
      return _persistAuthResponse(response.data!);
    } catch (error) {
      throw _apiClient.mapDioError(error);
    }
  }

  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiClient.rawDio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {
          'email': email.trim(),
          'password': password,
          'device_info': 'Nam Cinema Flutter Mobile',
        },
      );
      return _persistAuthResponse(response.data!);
    } catch (error) {
      throw _apiClient.mapDioError(error);
    }
  }

  static const AuthUser defaultPersonalUser = AuthUser(
    id: '00000000-0000-0000-0000-000000000001',
    email: 'personal@namcinema.vn',
    fullName: 'Nam Cinema Cá Nhân 4K',
    preferredLanguage: 'vi-VN',
  );

  Future<AuthUser?> restoreSession() async {
    try {
      final response = await _apiClient.rawDio.get<Map<String, dynamic>>(
        '/auth/me',
      );
      final user = AuthUser.fromJson(response.data!);
      await _tokenStorage.saveCachedUserJson(jsonEncode(user.toJson()));
      return user;
    } catch (_) {
      final cachedJson = await _tokenStorage.readCachedUserJson();
      if (cachedJson != null && cachedJson.isNotEmpty) {
        return AuthUser.fromJson(
          jsonDecode(cachedJson) as Map<String, dynamic>,
        );
      }
      return defaultPersonalUser;
    }
  }

  Future<void> logout() async {
    try {
      final refreshToken = await _tokenStorage.readRefreshToken();
      await _apiClient.rawDio.post<Map<String, dynamic>>(
        '/auth/logout',
        data: {'refresh_token': refreshToken},
      );
    } catch (_) {
      // Clear local tokens even if network is offline during logout
    } finally {
      await _tokenStorage.clearAll();
    }
  }

  Future<AuthUser> _persistAuthResponse(Map<String, dynamic> data) async {
    final accessToken = data['access_token'] as String;
    final refreshToken = data['refresh_token'] as String;
    final userMap = data['user'] as Map<String, dynamic>;
    final user = AuthUser.fromJson(userMap);

    await _tokenStorage.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
    await _tokenStorage.saveCachedUserJson(jsonEncode(user.toJson()));
    return user;
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    apiClient: ref.watch(apiClientProvider),
    tokenStorage: ref.watch(secureTokenStorageProvider),
  );
});

class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthController(this._repository) : super(const AuthState(isLoading: true)) {
    _initialize();
  }

  Future<void> _initialize() async {
    final restored = await _repository.restoreSession();
    state = AuthState(user: restored, isLoading: false);
  }

  Future<bool> login({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _repository.login(email: email, password: password);
      state = AuthState(user: user, isLoading: false);
      return true;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String fullName,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _repository.register(
        email: email,
        fullName: fullName,
        password: password,
      );
      state = AuthState(user: user, isLoading: false);
      return true;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );
      return false;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    await _repository.logout();
    state = const AuthState(user: null, isLoading: false);
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});

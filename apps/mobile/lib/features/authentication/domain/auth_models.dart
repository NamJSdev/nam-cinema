import 'package:flutter/foundation.dart';

@immutable
class AuthUser {
  final String id;
  final String email;
  final String fullName;
  final String? avatarUrl;
  final String preferredLanguage;

  const AuthUser({
    required this.id,
    required this.email,
    required this.fullName,
    this.avatarUrl,
    this.preferredLanguage = 'vi-VN',
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: (json['id'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      fullName: (json['full_name'] as String?) ?? '',
      avatarUrl: json['avatar_url'] as String?,
      preferredLanguage: (json['preferred_language'] as String?) ?? 'vi-VN',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'preferred_language': preferredLanguage,
    };
  }
}

@immutable
class AuthState {
  final AuthUser? user;
  final bool isLoading;
  final String? errorMessage;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    AuthUser? user,
    bool clearUser = false,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

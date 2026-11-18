import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nam_cinema/core/config/env_config.dart';
import 'package:nam_cinema/core/theme/app_theme.dart';
import 'package:nam_cinema/core/widgets/cinematic_widgets.dart';
import 'package:nam_cinema/features/authentication/data/auth_repository.dart';

class AuthScreen extends ConsumerStatefulWidget {
  final bool initialRegisterMode;

  const AuthScreen({super.key, this.initialRegisterMode = false});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  late bool _isRegisterMode;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _isRegisterMode = widget.initialRegisterMode;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(authControllerProvider.notifier);

    final bool success;
    if (_isRegisterMode) {
      success = await notifier.register(
        email: _emailController.text,
        fullName: _nameController.text,
        password: _passwordController.text,
      );
    } else {
      success = await notifier.login(
        email: _emailController.text,
        password: _passwordController.text,
      );
    }

    if (success && mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: NamCinemaColors.primaryAccent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'NAM CINEMA',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                            Text(
                              AppEnvConfig.appTagline,
                              style: TextStyle(
                                color: NamCinemaColors.secondaryText,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 36),
                    Text(
                      _isRegisterMode ? 'Tạo tài khoản mới' : 'Đăng nhập',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isRegisterMode
                          ? 'Đồng bộ danh sách xem và lịch sử phát trên mọi thiết bị.'
                          : 'Chào mừng trở lại với rạp phim cá nhân của bạn.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    if (authState.errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.redAccent.withOpacity(0.5),
                          ),
                        ),
                        child: Text(
                          authState.errorMessage!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_isRegisterMode) ...[
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Họ và tên',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().length < 2) {
                            return 'Vui lòng nhập họ tên hợp lệ.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.alternate_email_rounded),
                      ),
                      validator: (v) {
                        if (v == null || !v.contains('@')) {
                          return 'Vui lòng nhập địa chỉ email hợp lệ.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.length < 8) {
                          return 'Mật khẩu phải có tối thiểu 8 ký tự.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    PremiumButton(
                      label: _isRegisterMode ? 'Đăng Ký' : 'Đăng Nhập',
                      isLoading: authState.isLoading,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 14),
                    TextButton(
                      onPressed: () {
                        setState(() => _isRegisterMode = !_isRegisterMode);
                      },
                      child: Text(
                        _isRegisterMode
                            ? 'Đã có tài khoản? Đăng nhập ngay'
                            : 'Chưa có tài khoản? Đăng ký miễn phí',
                        style: const TextStyle(
                          color: NamCinemaColors.primaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

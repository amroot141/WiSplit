import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../providers/auth_provider.dart';

enum AuthMode { signUp, signIn, verifyOtp }

class AuthScreen extends ConsumerStatefulWidget {
  final VoidCallback onAuthenticated;

  const AuthScreen({super.key, required this.onAuthenticated});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  AuthMode _mode = AuthMode.signUp;
  bool _isLoading = false;
  String? _errorMessage;
  String? _infoMessage;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _otpController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  // App Brand Logo
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/images/wisplit_logo.png',
                        width: 72,
                        height: 72,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'WiSplit',
                    textAlign: TextAlign.center,
                    style: AppTypography.displayHeroMobile.copyWith(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _mode == AuthMode.verifyOtp
                        ? 'Enter the 6-digit code sent to your email'
                        : (_mode == AuthMode.signUp
                            ? 'Create your minimalist expense account'
                            : 'Sign in to your WiSplit account'),
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMd.copyWith(color: AppColors.outline),
                  ),
                  const SizedBox(height: 24),

                  // ── Segmented Tab Switcher (Sign Up | Sign In | Enter OTP) ──
                  Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.surfaceContainerHighest.withValues(alpha: 0.5),
                      ),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        _buildTabButton('Sign Up', AuthMode.signUp),
                        _buildTabButton('Sign In', AuthMode.signIn),
                        _buildTabButton('Enter OTP', AuthMode.verifyOtp),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (_infoMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primaryContainer.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.mark_email_read, color: AppColors.primaryContainer, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _infoMessage!,
                              style: AppTypography.bodyMd.copyWith(color: AppColors.primaryContainer),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.errorContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: AppTypography.bodyMd.copyWith(color: AppColors.error),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── OTP Verification Mode ─────────────────────────────────
                  if (_mode == AuthMode.verifyOtp) ...[
                    // Editable Email Field
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: AppTypography.bodyLg,
                        decoration: InputDecoration(
                          hintText: 'Your registered email',
                          hintStyle: AppTypography.bodyLg.copyWith(color: AppColors.subtleGray),
                          prefixIcon: const Icon(Icons.email_outlined, color: AppColors.outline),
                          border: InputBorder.none,
                          labelText: 'Email Address',
                          labelStyle: const TextStyle(color: AppColors.outline),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // OTP Input Field
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primaryContainer.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '6-DIGIT VERIFICATION CODE',
                            style: AppTypography.labelSm.copyWith(
                              letterSpacing: 1.5,
                              color: AppColors.outline,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            maxLength: 6,
                            autofocus: true,
                            style: AppTypography.displayHeroMobile.copyWith(
                              letterSpacing: 12.0,
                              fontSize: 32,
                              color: AppColors.primaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                            cursorColor: AppColors.primaryContainer,
                            decoration: InputDecoration(
                              hintText: '000000',
                              hintStyle: AppTypography.displayHeroMobile.copyWith(
                                letterSpacing: 12.0,
                                fontSize: 32,
                                color: AppColors.subtleGray,
                              ),
                              counterText: '',
                              border: InputBorder.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleVerifyOtp,
                      child: _isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Verify & Enter WiSplit'),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _mode = AuthMode.signIn;
                              _errorMessage = null;
                              _infoMessage = null;
                            });
                          },
                          child: const Text('Back to Sign In', style: TextStyle(color: AppColors.outline)),
                        ),
                        TextButton(
                          onPressed: _isLoading ? null : _handleResendOtp,
                          child: const Text('Resend Code', style: TextStyle(color: AppColors.primaryContainer)),
                        ),
                      ],
                    ),
                  ] else ...[
                    // ── Sign Up or Sign In Mode ─────────────────────────────
                    if (_mode == AuthMode.signUp) ...[
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: TextField(
                          controller: _nameController,
                          style: AppTypography.bodyLg,
                          decoration: InputDecoration(
                            hintText: 'Full Name',
                            hintStyle: AppTypography.bodyLg.copyWith(color: AppColors.subtleGray),
                            prefixIcon: const Icon(Icons.person_outline, color: AppColors.outline),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: AppTypography.bodyLg,
                        decoration: InputDecoration(
                          hintText: 'Email Address',
                          hintStyle: AppTypography.bodyLg.copyWith(color: AppColors.subtleGray),
                          prefixIcon: const Icon(Icons.email_outlined, color: AppColors.outline),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: TextField(
                        controller: _passwordController,
                        obscureText: true,
                        style: AppTypography.bodyLg,
                        decoration: InputDecoration(
                          hintText: 'Password (min 6 characters)',
                          hintStyle: AppTypography.bodyLg.copyWith(color: AppColors.subtleGray),
                          prefixIcon: const Icon(Icons.lock_outline, color: AppColors.outline),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : (_mode == AuthMode.signUp ? _handleSignUp : _handleSignIn),
                      child: _isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(_mode == AuthMode.signUp ? 'Create Account & Send Code' : 'Sign In'),
                    ),
                    const SizedBox(height: 14),

                    // Direct helper to enter OTP
                    Center(
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _mode = AuthMode.verifyOtp;
                            _errorMessage = null;
                            _infoMessage = 'Enter the 6-digit code received in your email.';
                          });
                        },
                        icon: const Icon(Icons.pin, size: 16, color: AppColors.primaryContainer),
                        label: Text(
                          'Have a verification code? Enter OTP',
                          style: AppTypography.labelMd.copyWith(color: AppColors.primaryContainer),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Divider with "OR"
                    Row(
                      children: [
                        const Expanded(child: Divider(color: AppColors.surfaceContainerHighest)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text('OR', style: AppTypography.labelSm.copyWith(color: AppColors.outline)),
                        ),
                        const Expanded(child: Divider(color: AppColors.surfaceContainerHighest)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Instant Local Guest Access Button
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : _handleGuestAccess,
                      icon: const Icon(Icons.bolt, color: AppColors.primaryContainer),
                      label: const Text('Instant Demo / Guest Access'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryContainer,
                        side: const BorderSide(color: AppColors.primaryContainer),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(String label, AuthMode tab) {
    final isSelected = _mode == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _mode = tab;
            _errorMessage = null;
            _infoMessage = null;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surfaceContainerHighest : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: AppTypography.labelSm.copyWith(
              color: isSelected ? AppColors.primaryContainer : AppColors.outline,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSignUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    if (email.isEmpty || password.length < 6 || name.isEmpty) {
      setState(() => _errorMessage = 'Please provide full name, valid email, and 6+ char password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      final session = await ref.read(userSessionProvider.notifier).signUp(
            email: email,
            password: password,
            fullName: name,
          );

      if (!session.isLoggedIn) {
        // Verification email sent, stay on screen and show OTP view!
        setState(() {
          _mode = AuthMode.verifyOtp;
          _isLoading = false;
          _infoMessage = 'Verification code sent to $email. Please enter the 6-digit code below.';
        });
      } else {
        widget.onAuthenticated();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _handleSignIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email and password');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(userSessionProvider.notifier).signIn(
            email: email,
            password: password,
          );
      widget.onAuthenticated();
    } catch (e) {
      final errStr = e.toString().replaceAll('Exception: ', '');
      if (errStr.toLowerCase().contains('email not confirmed')) {
        setState(() {
          _isLoading = false;
          _mode = AuthMode.verifyOtp;
          _infoMessage = 'Email not confirmed yet. Enter the 6-digit code sent to $email.';
          _errorMessage = null;
        });
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = errStr;
      });
    }
  }

  Future<void> _handleVerifyOtp() async {
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();

    if (email.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email address');
      return;
    }

    if (otp.length != 6) {
      setState(() => _errorMessage = 'Please enter the 6-digit code');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(userSessionProvider.notifier).verifyOtp(
            email: email,
            token: otp,
          );
      widget.onAuthenticated();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _handleResendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email first');
      return;
    }

    try {
      await ref.read(authServiceProvider).resendOtp(email: email);
      if (!mounted) return;
      setState(() => _infoMessage = 'A new 6-digit code has been sent to $email');
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _handleGuestAccess() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(userSessionProvider.notifier).continueAsGuest(name: 'Demo User');
      widget.onAuthenticated();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }
}

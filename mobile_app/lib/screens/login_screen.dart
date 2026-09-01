import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_service.dart';
import '../utils/notification_helper.dart';
import '../widgets/auth_components.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (credential.user != null) {
        // Sync user profile with backend (creates if not exists)
        try {
          await ApiService.post('/auth/sync', {
            'name': credential.user!.displayName ?? _emailController.text.trim().split('@')[0],
            'email': _emailController.text.trim(),
          });
        } catch (_) {}

        try {
          final profileResponse = await ApiService.get('/users/me');
          if (profileResponse != null && profileResponse is Map) {
            final status = profileResponse['status'] ?? 'ACTIVE';
            if (status == 'PENDING_APPROVAL') {
              await FirebaseAuth.instance.signOut();
              setState(() {
                _errorMessage = 'Your account is pending preacher approval.';
                _isLoading = false;
              });
              return;
            }
          }
        } catch (_) {}

        if (mounted) {
          NotificationHelper.loginUser(credential.user!.uid).catchError((_) {});
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Auth Header
                  const AuthHeader(
                    title: 'Sadhana Track',
                    subtitle: 'Welcome back! Sign in to continue',
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Main Form Card Container
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      border: Border.all(color: AppColors.border),
                      boxShadow: AppShadows.surface,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Error Banner
                          if (_errorMessage != null) ...[
                            AuthStatusBanner(
                              message: _errorMessage!,
                              isError: true,
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ],

                          // Email Field (No decorative prefix icon)
                          AuthTextField(
                            controller: _emailController,
                            label: 'Email Address',
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                  .hasMatch(value)) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.md + 2),

                          // Password Field (With functional eye toggle suffix icon)
                          AuthPasswordField(
                            controller: _passwordController,
                            label: 'Password',
                            obscureText: _obscurePassword,
                            onToggleObscure: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            textInputAction: TextInputAction.done,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => _handleLogin(),
                          ),
                          const SizedBox(height: AppSpacing.xs + 2),

                          // Forgot Password Text Button
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                final email = _emailController.text.trim();
                                if (email.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Please enter your email address first!\nपासवर्ड बदलने के लिए कृपया अपना ईमेल पहले भरें।'),
                                      backgroundColor: AppColors.primary,
                                    ),
                                  );
                                  return;
                                }
                                Navigator.pushNamed(
                                  context,
                                  '/reset-password',
                                  arguments: email,
                                );
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),

                          // Sign In Button
                          AuthPrimaryButton(
                            label: 'Sign In',
                            isLoading: _isLoading,
                            onPressed: _handleLogin,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg + 4),

                  // Footer Link
                  AuthTextButton(
                    leadingText: "Don't have an account? ",
                    actionText: 'Create Account',
                    actionColor: AppColors.secondary,
                    onTap: () {
                      Navigator.pushReplacementNamed(context, '/signup');
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

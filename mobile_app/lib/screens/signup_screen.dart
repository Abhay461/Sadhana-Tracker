import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../widgets/auth_components.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _dobController = TextEditingController();
  final _joiningDateController = TextEditingController();

  String _role = 'folk_boy'; // Default role
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  String? _successMessage;

  List<dynamic> _preachers = [];
  Map<String, dynamic>? _selectedPreacher;
  String _searchTerm = '';

  // Signup flow dates
  DateTime? _selectedDob;
  DateTime? _selectedJoiningDate;

  @override
  void initState() {
    super.initState();
    _fetchPreachers();
  }

  final _otpController = TextEditingController();
  String? _verificationId;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _whatsappController.dispose();
    _dobController.dispose();
    _joiningDateController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _fetchPreachers() async {
    try {
      final data = await ApiService.get('/users/preachers');
      if (!mounted) return;
      setState(() {
        _preachers = data is List ? data : [];
      });
    } catch (err) {
      debugPrint('Error fetching preachers: $err');
    }
  }

  Future<void> _handleSignup() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final String email = _emailController.text.trim();

    try {
      final res = await ApiService.post('/auth/send-email-otp', {'email': email})
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _showOtpDialog(email);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _showOtpDialog(String email) {
    _otpController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            bool isVerifying = false;
            String? modalError;

            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 24,
                left: 24,
                right: 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.sheet),
                  topRight: Radius.circular(AppRadius.sheet),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Enter 6-Digit Email OTP',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'We sent a 6-digit verification code to your email:\n$email',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (modalError != null) ...[
                    Text(
                      modalError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                  ],
                  AuthTextField(
                    controller: _otpController,
                    label: '6-Digit OTP',
                    hintText: 'e.g. 482910',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: isVerifying
                        ? null
                        : () async {
                            final otpCode = _otpController.text.trim();
                            if (otpCode.length != 6) {
                              setModalState(() {
                                modalError = 'Please enter 6-digit OTP code';
                              });
                              return;
                            }
                            setModalState(() {
                              isVerifying = true;
                              modalError = null;
                            });
                            try {
                              await ApiService.post('/auth/verify-email-otp', {
                                'email': email,
                                'otp': otpCode,
                              });
                              Navigator.pop(context);
                              await _completeRegistration();
                            } catch (err) {
                              setModalState(() {
                                isVerifying = false;
                                modalError = err.toString().replaceAll('Exception: ', '');
                              });
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isVerifying
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Verify OTP & Register',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _completeRegistration() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;

      if (user != null) {
        final String rawWhatsapp = _whatsappController.text.trim();
        final String dobStr = _selectedDob != null ? DateFormat('yyyy-MM-dd').format(_selectedDob!) : 'N/A';
        final String joinStr = _selectedJoiningDate != null ? DateFormat('yyyy-MM-dd').format(_selectedJoiningDate!) : 'N/A';
        final String formattedWhatsappWithDates = '$rawWhatsapp | DOB:$dobStr | JOIN:$joinStr';

        await ApiService.post('/auth/sync', {
          'name': _nameController.text.trim(),
          'role': _role,
          'preacherId': _selectedPreacher?['id'] ?? _selectedPreacher?['_id'],
          'phoneNumber': formattedWhatsappWithDates,
          'email': email,
        });
      }

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _successMessage = 'Email verified & registration successful!';
      });

      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _showPreacherPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final filteredPreachers = _preachers.where((p) {
              final name = (p['name'] ?? '').toString().toLowerCase();
              return name.contains(_searchTerm.toLowerCase());
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.72,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.sheet),
                  topRight: Radius.circular(AppRadius.sheet),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
              child: Column(
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md + 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select Assigned Preacher',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm + 6),
                  TextField(
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search preacher by name...',
                      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
                      filled: true,
                      fillColor: AppColors.inputFill,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                    onChanged: (value) {
                      setModalState(() {
                        _searchTerm = value;
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.md + 2),
                  Expanded(
                    child: filteredPreachers.isNotEmpty
                        ? ListView.separated(
                            itemCount: filteredPreachers.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final p = filteredPreachers[index];
                              final isSelected = _selectedPreacher?['id'] == p['id'];
                              return AnimatedContainer(
                                duration: AppAnimation.duration,
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedPreacher = p;
                                    });
                                    Navigator.pop(context);
                                  },
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFFFFFBEB) : AppColors.inputFill,
                                      borderRadius: BorderRadius.circular(AppRadius.md),
                                      border: Border.all(
                                        color: isSelected ? AppColors.primary : AppColors.border,
                                        width: isSelected ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 22,
                                          backgroundImage: p['photo_url'] != null
                                              ? NetworkImage(p['photo_url'])
                                              : null,
                                          backgroundColor: const Color(0xFFFEF3C7),
                                          child: p['photo_url'] == null
                                              ? Text(
                                                  (p['name'] ?? 'P')[0].toUpperCase(),
                                                  style: const TextStyle(
                                                    fontFamily: 'Poppins',
                                                    color: AppColors.primary,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Text(
                                            p['name'] ?? '',
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                              fontSize: 15,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                        if (isSelected)
                                          const Icon(
                                            Icons.check_circle_rounded,
                                            color: AppColors.primary,
                                            size: 22,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          )
                        : const Center(
                            child: Text(
                              'No preachers found',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSinglePageForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ==========================================
        // SECTION 1: PERSONAL INFORMATION
        // ==========================================
        AuthSectionCard(
          title: 'Personal Information',
          subtitle: 'Your basic identity details',
          children: [
            // Full Name Field (No decorative prefix icon)
            AuthTextField(
              controller: _nameController,
              label: 'Full Name',
              keyboardType: TextInputType.name,
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your name';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md + 2),

            // Email Address Field (No decorative prefix icon)
            AuthTextField(
              controller: _emailController,
              label: 'Email Address',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md + 2),

            // WhatsApp Number Field (No decorative prefix icon)
            AuthTextField(
              controller: _whatsappController,
              label: 'WhatsApp Number',
              hintText: '10-digit phone number',
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter WhatsApp number';
                }
                if (!RegExp(r'^[0-9]{10}$').hasMatch(value)) {
                  return 'Enter a valid 10-digit number';
                }
                return null;
              },
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        // ==========================================
        // SECTION 2: SPIRITUAL INFORMATION
        // ==========================================
        AuthSectionCard(
          title: 'Spiritual Information',
          subtitle: 'Your journey & mentor details',
          children: [
            // Date of Birth Field (Functional Calendar Suffix Icon)
            AuthTextField(
              controller: _dobController,
              label: 'Date of Birth',
              readOnly: true,
              suffixIcon: const Icon(Icons.calendar_today_rounded, color: AppColors.textMuted, size: 18),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select your Date of Birth';
                }
                return null;
              },
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDob ?? DateTime(2000, 1, 1),
                  firstDate: DateTime(1950),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() {
                    _selectedDob = date;
                    _dobController.text = DateFormat('dd MMMM yyyy').format(date);
                  });
                }
              },
            ),
            const SizedBox(height: AppSpacing.md + 2),

            // Folk Joining Date Field (Functional Calendar Suffix Icon)
            AuthTextField(
              controller: _joiningDateController,
              label: 'FOLK Joining Date',
              readOnly: true,
              suffixIcon: const Icon(Icons.calendar_today_rounded, color: AppColors.textMuted, size: 18),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select your Folk Joining Date';
                }
                return null;
              },
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedJoiningDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now().add(const Duration(days: 30)),
                );
                if (date != null) {
                  setState(() {
                    _selectedJoiningDate = date;
                    _joiningDateController.text = DateFormat('dd MMMM yyyy').format(date);
                  });
                }
              },
            ),
            const SizedBox(height: AppSpacing.md + 4),

            // Assigned Preacher Trigger Tile
            const Text(
              'Assigned Preacher',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
            const SizedBox(height: AppSpacing.sm + 2),
            AuthDropdownTile(
              selectedPreacher: _selectedPreacher,
              onTap: _showPreacherPicker,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        // ==========================================
        // SECTION 3: ACCOUNT SECURITY
        // ==========================================
        AuthSectionCard(
          title: 'Account Security',
          subtitle: 'Set up a password for logging in',
          children: [
            // Password Field (Functional Eye Toggle Suffix Icon)
            AuthPasswordField(
              controller: _passwordController,
              label: 'Password',
              obscureText: _obscurePassword,
              onToggleObscure: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md + 2),

            // Confirm Password Field (Functional Eye Toggle Suffix Icon)
            AuthPasswordField(
              controller: _confirmPasswordController,
              label: 'Confirm Password',
              obscureText: _obscureConfirmPassword,
              onToggleObscure: () {
                setState(() {
                  _obscureConfirmPassword = !_obscureConfirmPassword;
                });
              },
              textInputAction: TextInputAction.done,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please confirm your password';
                }
                if (value != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        // Error Banner
        if (_errorMessage != null) ...[
          AuthStatusBanner(
            message: _errorMessage!,
            isError: true,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],

        // Success Banner
        if (_successMessage != null) ...[
          AuthStatusBanner(
            message: _successMessage!,
            isError: false,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],

        // Complete Registration Button
        AuthPrimaryButton(
          label: 'Send SMS OTP',
          isLoading: _isLoading,
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            if (_selectedPreacher == null) {
              setState(() {
                _errorMessage = 'Please select your preacher';
              });
              return;
            }
            if (_selectedDob == null) {
              setState(() {
                _errorMessage = 'Please select your Date of Birth';
              });
              return;
            }
            setState(() {
              _errorMessage = null;
            });
            _handleSignup();
          },
        ),
      ],
    );
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
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Auth Header
                    const AuthHeader(
                      title: 'Create Account',
                      subtitle: 'Join our community & start your spiritual journey',
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Sectioned Form
                    _buildSinglePageForm(),

                    const SizedBox(height: AppSpacing.xl),

                    // Footer Link
                    AuthTextButton(
                      leadingText: "Already have an account? ",
                      actionText: 'Sign In',
                      actionColor: AppColors.secondary,
                      onTap: () {
                        Navigator.pushReplacementNamed(context, '/login');
                      },
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

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../utils/notification_helper.dart';
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
  final _occupationController = TextEditingController();
  final _collegeController = TextEditingController();
  final _courseYearController = TextEditingController();
  final _cityController = TextEditingController();

  String _role = 'folk_boy'; // Default role
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  String? _successMessage;

  List<dynamic> _preachers = [];
  Map<String, dynamic>? _selectedPreacher;
  String _searchTerm = '';
  int _currentStep = 0; // 0 for Account Credentials card, 1 for Personal Details card

  // Signup flow dates
  DateTime? _selectedDob;
  DateTime? _selectedJoiningDate;

  // Occupation options
  String _selectedOccupation = 'Student';
  final List<String> _occupationOptions = [
    'Student',
    'Working Professional',
    'Business / Self-Employed',
    'Job Seeker / Other',
  ];

  @override
  void initState() {
    super.initState();
    _occupationController.text = 'Student';
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
    _occupationController.dispose();
    _collegeController.dispose();
    _courseYearController.dispose();
    _cityController.dispose();
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
          .timeout(const Duration(seconds: 45));
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _showOtpDialog(email);
    } catch (e) {
      if (!mounted) return;
      final String rawErr = e is ApiException ? e.message : e.toString().replaceAll('Exception: ', '');
      setState(() {
        _isLoading = false;
        if (rawErr.contains('already linked') || rawErr.contains('ACCOUNT_CONFLICT') || rawErr.contains('email-already-in-use')) {
          _errorMessage = 'An account with this email already exists! Please tap Sign In below.';
        } else {
          _errorMessage = rawErr;
        }
      });
    }
  }


  void _showOtpDialog(String email) {
    _otpController.clear();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            bool isVerifying = false;
            String? modalError;

            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Verify Email OTP',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Enter the 6-digit verification code sent to:\n$email',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Error Banner
                      if (modalError != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: Text(
                            modalError!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: Color(0xFF991B1B),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // OTP Input Field
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '6-Digit OTP',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 5),
                          TextFormField(
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 18,
                              letterSpacing: 4,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                            decoration: InputDecoration(
                              hintText: '000000',
                              hintStyle: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                letterSpacing: 4,
                                color: Color(0xFFCBD5E1),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Verify Button
                      SizedBox(
                        height: 44,
                        child: ElevatedButton(
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
                                      modalError = err is ApiException
                                          ? err.message
                                          : err.toString().replaceAll('Exception: ', '');
                                    });
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: isVerifying
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'Verify & Register',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Cancel Button
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
        final String occStr = _selectedOccupation;
        final String clgStr = (_selectedOccupation == 'Student' && _collegeController.text.trim().isNotEmpty) ? _collegeController.text.trim() : 'N/A';
        final String crsStr = (_selectedOccupation == 'Student' && _courseYearController.text.trim().isNotEmpty) ? _courseYearController.text.trim() : 'N/A';
        final String cityStr = _cityController.text.trim().isNotEmpty ? _cityController.text.trim() : 'N/A';

        final String formattedWhatsappWithDates = '$rawWhatsapp | DOB:$dobStr | JOIN:$joinStr | OCC:$occStr | CLG:$clgStr | CRS:$crsStr | CITY:$cityStr';

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
      final String rawErr = e is ApiException ? e.message : e.toString().replaceAll('Exception: ', '');
      setState(() {
        _isLoading = false;
        if (rawErr.contains('already linked') || rawErr.contains('ACCOUNT_CONFLICT') || rawErr.contains('email-already-in-use')) {
          _errorMessage = 'An account with this email already exists! Please tap Sign In below.';
        } else {
          _errorMessage = rawErr;
        }
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
              height: MediaQuery.of(context).size.height * 0.70,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select Assigned Preacher',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: 'Search preacher by name...',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 20),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                      ),
                    ),
                    onChanged: (value) {
                      setModalState(() {
                        _searchTerm = value;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: filteredPreachers.isNotEmpty
                        ? ListView.separated(
                            itemCount: filteredPreachers.length,
                            separatorBuilder: (context, index) => const Divider(color: Color(0xFFF1F5F9), height: 1),
                            itemBuilder: (context, index) {
                              final p = filteredPreachers[index];
                              final isSelected = _selectedPreacher?['id'] == p['id'] || _selectedPreacher?['_id'] == p['_id'];
                              return InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedPreacher = p;
                                  });
                                  Navigator.pop(context);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          p['name'] ?? '',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                            fontSize: 15,
                                            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF334155),
                                          ),
                                        ),
                                      ),
                                      if (isSelected)
                                        const Icon(
                                          Icons.check_rounded,
                                          color: Color(0xFF0F172A),
                                          size: 18,
                                        ),
                                    ],
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
                                color: Color(0xFF64748B),
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

  Future<void> _selectDob(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime(2002, 1, 1),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0F172A),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDob = picked;
        _dobController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _selectJoiningDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedJoiningDate ?? DateTime.now(),
      firstDate: DateTime(2010),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0F172A),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedJoiningDate = picked;
        _joiningDateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Widget _buildSimpleTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          readOnly: readOnly,
          onTap: onTap,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: Color(0xFF94A3B8),
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildPageOne() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Full Name Field
        _buildSimpleTextField(
          controller: _nameController,
          label: 'Full Name',
          hintText: 'Enter your full name',
          keyboardType: TextInputType.name,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your full name';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),

        // 2. Email Address Field
        _buildSimpleTextField(
          controller: _emailController,
          label: 'Email Address',
          hintText: 'Enter your email address',
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your email address';
            }
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
              return 'Please enter a valid email address';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),

        // 3. Assigned Preacher Field
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Assigned Preacher',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 5),
            InkWell(
              onTap: _showPreacherPicker,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _selectedPreacher != null ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                    width: _selectedPreacher != null ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _selectedPreacher != null
                            ? (_selectedPreacher!['name'] ?? 'Selected Preacher')
                            : 'Select assigned preacher',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: _selectedPreacher != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                          fontWeight: _selectedPreacher != null ? FontWeight.w600 : FontWeight.w400,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF64748B),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 4. Password Field
        _buildSimpleTextField(
          controller: _passwordController,
          label: 'Password',
          hintText: 'Enter your password',
          obscureText: true,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your password';
            }
            if (value.trim().length < 6) {
              return 'Password must be at least 6 characters';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),

        // 5. Confirm Password Field
        _buildSimpleTextField(
          controller: _confirmPasswordController,
          label: 'Confirm Password',
          hintText: 'Re-enter your password',
          obscureText: true,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please confirm your password';
            }
            if (value.trim() != _passwordController.text.trim()) {
              return 'Passwords do not match';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Error Banner
        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: Color(0xFF991B1B),
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Next Button
        SizedBox(
          height: 44,
          child: ElevatedButton(
            onPressed: () {
              if (_nameController.text.trim().isEmpty) {
                setState(() => _errorMessage = 'Please enter your full name');
                return;
              }
              if (_emailController.text.trim().isEmpty || !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(_emailController.text.trim())) {
                setState(() => _errorMessage = 'Please enter a valid email address');
                return;
              }
              if (_selectedPreacher == null) {
                setState(() => _errorMessage = 'Please select your assigned preacher');
                return;
              }
              if (_passwordController.text.trim().length < 6) {
                setState(() => _errorMessage = 'Password must be at least 6 characters');
                return;
              }
              if (_passwordController.text.trim() != _confirmPasswordController.text.trim()) {
                setState(() => _errorMessage = 'Passwords do not match');
                return;
              }
              setState(() {
                _errorMessage = null;
                _currentStep = 1;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Next: Personal Details',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOccupationDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Occupation / Status',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 5),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedOccupation,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 20),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: Color(0xFF0F172A),
              ),
              items: _occupationOptions.map((String option) {
                return DropdownMenuItem<String>(
                  value: option,
                  child: Text(option),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedOccupation = newValue;
                    _occupationController.text = newValue;
                    if (newValue != 'Student') {
                      _collegeController.clear();
                      _courseYearController.clear();
                    }
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPageTwo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. WhatsApp / Mobile Number Field
        _buildSimpleTextField(
          controller: _whatsappController,
          label: 'WhatsApp / Mobile Number',
          hintText: 'Enter 10-digit WhatsApp number',
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your WhatsApp number';
            }
            final cleaned = value.trim().replaceAll(RegExp(r'\D'), '');
            if (cleaned.length < 10) {
              return 'Please enter a valid 10-digit mobile number';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),

        // 2. Date of Birth (DOB) Field
        _buildSimpleTextField(
          controller: _dobController,
          label: 'Date of Birth (DOB)',
          hintText: 'Select your date of birth',
          readOnly: true,
          onTap: () => _selectDob(context),
          suffixIcon: const Icon(Icons.calendar_today_rounded, color: Color(0xFF64748B), size: 18),
          validator: (value) {
            if (value == null || value.trim().isEmpty || _selectedDob == null) {
              return 'Please select your Date of Birth';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),

        // 3. FOLK Joining Date Field
        _buildSimpleTextField(
          controller: _joiningDateController,
          label: 'FOLK Joining Date',
          hintText: 'Select your FOLK joining date',
          readOnly: true,
          onTap: () => _selectJoiningDate(context),
          suffixIcon: const Icon(Icons.calendar_month_rounded, color: Color(0xFF64748B), size: 18),
          validator: (value) {
            if (value == null || value.trim().isEmpty || _selectedJoiningDate == null) {
              return 'Please select your FOLK Joining Date';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),

        // 4. Occupation / Status Dropdown Field
        _buildOccupationDropdown(),
        const SizedBox(height: 12),

        // 5. College / University Name Field & 6. Course & Year Field (Shown only if Student)
        if (_selectedOccupation == 'Student') ...[
          _buildSimpleTextField(
            controller: _collegeController,
            label: 'College / University Name',
            hintText: 'e.g. GLA University / Mathura College',
            validator: (value) {
              if (_selectedOccupation == 'Student' && (value == null || value.trim().isEmpty)) {
                return 'Please enter your College / University name';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          _buildSimpleTextField(
            controller: _courseYearController,
            label: 'Course & Year',
            hintText: 'e.g. B.Tech 3rd Year / BCA 2nd Year',
            validator: (value) {
              if (_selectedOccupation == 'Student' && (value == null || value.trim().isEmpty)) {
                return 'Please enter your Course & Year';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
        ],

        // 7. City / Native Hometown Field
        _buildSimpleTextField(
          controller: _cityController,
          label: 'City / Native Hometown',
          hintText: 'e.g. Mathura / Vrindavan / Agra / Delhi',
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your City / Hometown';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Error Banner
        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: Color(0xFF991B1B),
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Success Banner
        if (_successMessage != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF86EFAC)),
            ),
            child: Text(
              _successMessage!,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: Color(0xFF166534),
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Action Buttons Row: Back & Create Account
        Row(
          children: [
            SizedBox(
              height: 44,
              width: 80,
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _currentStep = 0;
                    _errorMessage = null;
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F172A),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.arrow_back_rounded, size: 16, color: Color(0xFF0F172A)),
                    SizedBox(width: 4),
                    Text(
                      'Back',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          if (_whatsappController.text.trim().isEmpty) {
                            setState(() => _errorMessage = 'Please enter your WhatsApp number');
                            return;
                          }
                          final cleanedPhone = _whatsappController.text.trim().replaceAll(RegExp(r'\D'), '');
                          if (cleanedPhone.length < 10) {
                            setState(() => _errorMessage = 'Please enter a valid 10-digit mobile number');
                            return;
                          }
                          if (_selectedDob == null) {
                            setState(() => _errorMessage = 'Please select your Date of Birth');
                            return;
                          }
                          if (_selectedJoiningDate == null) {
                            setState(() => _errorMessage = 'Please select your FOLK Joining Date');
                            return;
                          }
                          if (_selectedOccupation == 'Student') {
                            if (_collegeController.text.trim().isEmpty) {
                              setState(() => _errorMessage = 'Please enter your College / University Name');
                              return;
                            }
                            if (_courseYearController.text.trim().isEmpty) {
                              setState(() => _errorMessage = 'Please enter your Course & Year');
                              return;
                            }
                          }
                          if (_cityController.text.trim().isEmpty) {
                            setState(() => _errorMessage = 'Please enter your City / Native Hometown');
                            return;
                          }
                          setState(() {
                            _errorMessage = null;
                          });
                          _handleSignup();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Create Account',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSignupForm() {
    return _currentStep == 0 ? _buildPageOne() : _buildPageTwo();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Top Logo & Header
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.asset(
                          'assets/logo.jpg',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Create Account',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Enter your details to create an account',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: Color(0xFF64748B),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),

                    // Clean Direct Screen Multi-Step Form
                    _buildSignupForm(),

                    const SizedBox(height: 24),

                    // Footer Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Already have an account? ",
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushReplacementNamed(context, '/login');
                          },
                          child: const Text(
                            'Sign In',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
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

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../utils/security_utils.dart';

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

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _whatsappController.dispose();
    _dobController.dispose();
    _joiningDateController.dispose();
    super.dispose();
  }

  Future<void> _fetchPreachers() async {
    try {
      final List<dynamic> data = await Supabase.instance.client
          .from('profiles')
          .select('id, name, photo_url')
          .eq('role', 'preacher')
          .order('name');

      if (!mounted) return;
      setState(() {
        _preachers = data;
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

    try {
      final String rawWhatsapp = _whatsappController.text.trim();
      final String dobStr = _selectedDob != null ? DateFormat('yyyy-MM-dd').format(_selectedDob!) : 'N/A';
      final String joinStr = _selectedJoiningDate != null ? DateFormat('yyyy-MM-dd').format(_selectedJoiningDate!) : 'N/A';
      final String formattedWhatsappWithDates = '$rawWhatsapp | DOB:$dobStr | JOIN:$joinStr';

      // 1. Sign up the user in Supabase Auth
      final AuthResponse response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        data: {
          'name': _nameController.text.trim(),
          'role': 'pending_$_role',
          'preacher_id': _selectedPreacher?['id'],
          'whatsapp_number': formattedWhatsappWithDates,
        },
      );

      final user = response.user;
      if (user != null) {
        // 2. Ensure profile exists in profiles table
        try {
          await Supabase.instance.client.from('profiles').insert({
            'id': user.id,
            'name': _nameController.text.trim(),
            'role': 'pending_$_role',
            'preacher_id': _selectedPreacher?['id'],
            'whatsapp_number': formattedWhatsappWithDates,
            'email': _emailController.text.trim(),
          });
        } on PostgrestException catch (error) {
          if (error.code != '23505' && error.code != '42501') rethrow;
        }

        if (!mounted) return;
        setState(() {
          _successMessage =
              'Registration successful! Your account is pending preacher approval. Please verify your email if required and wait for your preacher to approve your account before logging in.';
        });

        // Redirect after 5 seconds
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/login');
          }
        });
      }
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = SecurityUtils.sanitizeErrorMessage(error.message);
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _errorMessage = SecurityUtils.sanitizeErrorMessage(err);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select Preacher',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by name...',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) {
                      setModalState(() {
                        _searchTerm = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: filteredPreachers.isNotEmpty
                        ? ListView.builder(
                            itemCount: filteredPreachers.length,
                            itemBuilder: (context, index) {
                              final p = filteredPreachers[index];
                              final isSelected =
                                  _selectedPreacher?['id'] == p['id'];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: p['photo_url'] != null
                                      ? NetworkImage(p['photo_url'])
                                      : null,
                                  backgroundColor: const Color(0xFFEEF2F6),
                                  child: p['photo_url'] == null
                                      ? Text(
                                          (p['name'] ?? 'P')[0].toUpperCase(),
                                          style: const TextStyle(
                                            color: Color(0xFF6366F1),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : null,
                                ),
                                title: Text(
                                  p['name'] ?? '',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                trailing: isSelected
                                    ? const Icon(Icons.check_circle,
                                        color: Color(0xFF6366F1))
                                    : null,
                                selected: isSelected,
                                selectedColor: const Color(0xFF6366F1),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                onTap: () {
                                  setState(() {
                                    _selectedPreacher = p;
                                  });
                                  Navigator.pop(context);
                                },
                              );
                            },
                          )
                        : const Center(
                            child: Text(
                              'No mentors found',
                              style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Full Name Field
        TextFormField(
          controller: _nameController,
          keyboardType: TextInputType.name,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'Full Name',
            prefixIcon: const Icon(
              Icons.person_outline,
              color: Color(0xFF6366F1),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your name';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Email Field
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'Email',
            prefixIcon: const Icon(
              Icons.mail_outline,
              color: Color(0xFF10B981),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
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
        const SizedBox(height: 16),

        // Date of Birth Field
        TextFormField(
          controller: _dobController,
          readOnly: true,
          decoration: InputDecoration(
            labelText: 'Date of Birth',
            prefixIcon: const Icon(
              Icons.cake_outlined,
              color: Colors.pink,
            ),
            suffixIcon: const Icon(Icons.calendar_today, color: Colors.grey, size: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
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
        const SizedBox(height: 16),

        // Folk Joining Date Field
        TextFormField(
          controller: _joiningDateController,
          readOnly: true,
          decoration: InputDecoration(
            labelText: 'Folk Joining Date',
            prefixIcon: const Icon(
              Icons.flag_outlined,
              color: Colors.blue,
            ),
            suffixIcon: const Icon(Icons.calendar_today, color: Colors.grey, size: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
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
        const SizedBox(height: 16),

        // Password Field
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(
              Icons.lock_outline,
              color: Color(0xFFF43F5E),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: const Color(0xFF64748B),
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
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
        const SizedBox(height: 16),

        // Confirm Password Field
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'Confirm Password',
            prefixIcon: const Icon(
              Icons.lock_outline,
              color: Color(0xFFF43F5E),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: const Color(0xFF64748B),
              ),
              onPressed: () {
                setState(() {
                  _obscureConfirmPassword = !_obscureConfirmPassword;
                });
              },
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
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
        const SizedBox(height: 16),

        // WhatsApp Field
        TextFormField(
          controller: _whatsappController,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: 'WhatsApp Number',
            prefixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 12),
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Color(0xFF25D366),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.phone,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
            hintText: '10 digit number',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
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
        const SizedBox(height: 16),

        // Role Selector (Folk Boy / Residency)
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'I am registering as',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _role == 'folk_boy'
                      ? const Color(0xFF6366F1)
                      : Colors.white,
                  foregroundColor: _role == 'folk_boy'
                      ? Colors.white
                      : const Color(0xFF475569),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: _role == 'folk_boy'
                          ? Colors.transparent
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
                onPressed: () {
                  setState(() {
                    _role = 'folk_boy';
                  });
                },
                child: const Text('Folk Boy'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _role == 'residency'
                      ? const Color(0xFF6366F1)
                      : Colors.white,
                  foregroundColor: _role == 'residency'
                      ? Colors.white
                      : const Color(0xFF475569),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: _role == 'residency'
                          ? Colors.transparent
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
                onPressed: () {
                  setState(() {
                    _role = 'residency';
                  });
                },
                child: const Text('Residency'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Preacher Selector Trigger
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Select Your Preacher',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _showPreacherPicker,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFCBD5E1)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _selectedPreacher != null
                    ? Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundImage: _selectedPreacher!['photo_url'] != null
                                ? NetworkImage(_selectedPreacher!['photo_url'])
                                : null,
                            child: _selectedPreacher!['photo_url'] == null
                                ? Text(
                                    _selectedPreacher!['name'][0].toUpperCase(),
                                    style: const TextStyle(fontSize: 10),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _selectedPreacher!['name'] ?? '',
                            style: const TextStyle(
                              color: Color(0xFF6366F1),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    : const Text(
                        'Click to choose preacher...',
                        style: TextStyle(color: Colors.grey),
                      ),
                const Icon(Icons.search, color: Colors.grey),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Register Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : () {
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
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Register',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.person_add_outlined, size: 18),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF1F5F9),
              Color(0xFFE2E8F0),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: Card(
              elevation: 8,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 36.0,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo Image
                      Container(
                        height: 90,
                        width: 90,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 20,
                              offset: Offset(0, 8),
                            )
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            'assets/logo.jpg',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      const Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Create your account to get started',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      // Error message banner
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFFECACA),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Color(0xFFEF4444),
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: Color(0xFF991B1B),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Success message banner
                      if (_successMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1FAE5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFA7F3D0),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle_outline,
                                color: Color(0xFF10B981),
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _successMessage!,
                                  style: const TextStyle(
                                    color: Color(0xFF065F46),
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // RENDER FORM DIRECTLY
                      _buildSinglePageForm(),

                      const SizedBox(height: 24),

                      // Footer
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Already have an account? ",
                            style: TextStyle(color: Color(0xFF64748B)),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.pushReplacementNamed(context, '/login');
                            },
                            child: const Text(
                              'Sign In',
                              style: TextStyle(
                                color: Color(0xFF6366F1),
                                fontWeight: FontWeight.bold,
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
      ),
    );
  }
}

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/constants.dart';
import '../utils/security_utils.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  bool _isAdminVerified = false;

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _whatsappController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminAccess() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      debugPrint('Admin Access Denied: no user');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/home');
      });
      return;
    }

    try {
      // Server-side role verification from database
      final profile = await supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null || profile['role'] != 'admin') {
        debugPrint('Admin Access Denied: insufficient role');
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
        return;
      }

      if (mounted) {
        setState(() {
          _isAdminVerified = true;
        });
      }
    } catch (e) {
      debugPrint('Admin access check failed: $e');
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    }
  }

  Future<void> _handleCreatePreacher() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final name = _nameController.text.trim();
      final email = _emailController.text.trim();
      
      // Auto-generate unique 6-character preacher code
      final random = Random();
      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
      final randomStr = List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
      final code = 'PRCH-$randomStr';

      final whatsapp = _whatsappController.text.trim();
      final password = _passwordController.text.trim();

      // Create a secondary client to avoid logging out the current admin
      final tempClient = SupabaseClient(
        Constants.supabaseUrl,
        Constants.supabaseAnonKey,
      );

      // Sign up the new preacher using the temp client
      final AuthResponse response = await tempClient.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'role': 'preacher',
          'preacher_code': code,
          'whatsapp_number': whatsapp,
        },
      );

      final newUser = response.user;
      if (newUser == null) {
        throw Exception('User creation failed.');
      }

      try {
        await tempClient.from('profiles').insert({
          'id': newUser.id,
          'name': name,
          'role': 'preacher',
          'preacher_code': code,
          'whatsapp_number': whatsapp,
          'email': email,
        });
      } on PostgrestException catch (error) {
        if (error.code != '23505' && error.code != '42501') rethrow;
      }

      final profile = await tempClient
          .from('profiles')
          .select('id')
          .eq('id', newUser.id)
          .maybeSingle();

      if (profile == null) {
        throw Exception(
          'Auth user was created, but preacher profile was not created. Check profiles RLS/trigger.',
        );
      }

      if (!mounted) return;
      setState(() {
        _successMessage = 'Preacher created successfully! Code: $code.';
        _nameController.clear();
        _emailController.clear();
        _whatsappController.clear();
        _passwordController.clear();
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = SecurityUtils.sanitizeErrorMessage(e.message);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = SecurityUtils.sanitizeErrorMessage(e);
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
    if (!_isAdminVerified) {
      return const Scaffold(
        backgroundColor: Color(0xFFF1F5F9),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF059669)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Card(
            elevation: 8,
            shadowColor: Colors.black12,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Elegant Header
                Container(
                  width: double.infinity,
                  color: const Color(0xFF059669), // Emerald 600
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
                            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 16),
                            label: const Text(
                              'Back to Dashboard',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          ),
                          IconButton(
                            icon: const Icon(Icons.logout, color: Colors.white, size: 20),
                            tooltip: 'Logout',
                            onPressed: () {
                              try {
                                supabase.auth.signOut().catchError((_) {});
                              } catch (_) {}
                              Navigator.pushReplacementNamed(context, '/login');
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Row(
                        children: [
                          Icon(Icons.admin_panel_settings, color: Colors.white, size: 32),
                          SizedBox(width: 12),
                          Text(
                            'Admin Portal',
                            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Create and manage preacher accounts',
                        style: TextStyle(color: Color(0xFFA7F3D0), fontSize: 13),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Success message banner
                        if (_successMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD1FAE5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFA7F3D0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _successMessage!,
                                        style: const TextStyle(color: Color(0xFF065F46), fontSize: 13, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Please share the credentials and code with the preacher.',
                                  style: TextStyle(color: Color(0xFF047857), fontSize: 11, fontWeight: FontWeight.w600),
                                )
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Error message banner
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Preacher Name
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Preacher Name',
                            prefixIcon: const Icon(Icons.person_outline, color: Colors.grey),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (value) => value == null || value.isEmpty ? 'Enter preacher name' : null,
                        ),
                        const SizedBox(height: 16),

                        // Email Address
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Email Address',
                            prefixIcon: const Icon(Icons.mail_outline, color: Colors.grey),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Enter email address';
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                              return 'Enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),



                        // WhatsApp Number
                        TextFormField(
                          controller: _whatsappController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'WhatsApp Number',
                            prefixIcon: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12.0),
                              child: Text('  💬 ', style: TextStyle(fontSize: 16)),
                            ),
                            hintText: 'e.g. 9876543210',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Enter WhatsApp number';
                            if (!RegExp(r'^[0-9]{10}$').hasMatch(value)) {
                              return 'Enter valid 10-digit number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Initial Password
                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'Initial Password',
                            prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Enter password';
                            if (value.length < 6) return 'Password must be at least 6 characters';
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // Create Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleCreatePreacher,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 2,
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text('Create Preacher Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

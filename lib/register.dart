import 'package:flutter/material.dart';

import 'database.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Form Controllers
  final _studentIdController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _contactController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _loading = false;

  // Color Palette
  static const Color headerNavy = Color(0xFF0F1A44);
  static const Color primaryNavy = Color(0xFF1B297E);
  static const Color labelColor = Color(0xFF1B285D);
  static const Color subtitleGrey = Color(0xFF909CBE);
  static const Color borderColor = Color(0xFFDDE2E8);

  @override
  void dispose() {
    _studentIdController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _contactController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final studentId = _studentIdController.text.trim();
    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final contact = _contactController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (studentId.isEmpty ||
        fullName.isEmpty ||
        email.isEmpty ||
        contact.isEmpty ||
        password.isEmpty) {
      _showMessage('Please fill in all fields.');
      return;
    }
    if (password != confirm) {
      _showMessage('Passwords do not match.');
      return;
    }
    if (password.length < 6) {
      _showMessage('Password must be at least 6 characters.');
      return;
    }

    setState(() => _loading = true);
    String? error;
    try {
      error = await DatabaseHelper.instance.register(
        studentId: studentId,
        fullName: fullName,
        email: email,
        contact: contact,
        password: password,
      );
    } catch (e) {
      error = 'Unable to save account: $e';
    }
    if (!mounted) return;
    setState(() => _loading = false);

    if (error != null) {
      _showMessage(error);
      return;
    }

    _showMessage('Account created! You can now log in.');
    Navigator.pop(context);
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          // Dark Navy Header Section
          Container(
            color: headerNavy,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(left: 8, right: 8, top: 4, bottom: 18),
                child: Column(
                  children: [
                    // Top Row: Back Button, Title, Options Icon
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          onPressed: () => Navigator.canPop(context) ? Navigator.pop(context) : null,
                        ),
                        const Expanded(
                          child: Center(
                            child: Text(
                              'Student Registration',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Subtitle
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        'Create your SmartQR student account to start queuing.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: subtitleGrey,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Scrollable Registration Form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildInputField(
                    label: 'STUDENT ID',
                    hintText: 'e.g. 2025-00123',
                    controller: _studentIdController,
                  ),
                  const SizedBox(height: 16),

                  _buildInputField(
                    label: 'FULL NAME',
                    hintText: 'e.g. Juan Dela Cruz',
                    controller: _fullNameController,
                  ),
                  const SizedBox(height: 16),

                  _buildInputField(
                    label: 'SCHOOL EMAIL',
                    hintText: 'e.g. juan.delacruz@school.edu',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),

                  _buildInputField(
                    label: 'CONTACT NUMBER',
                    hintText: 'e.g. 09171234567',
                    controller: _contactController,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),

                  _buildInputField(
                    label: 'PASSWORD',
                    hintText: '••••••••',
                    controller: _passwordController,
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),

                  _buildInputField(
                    label: 'CONFIRM PASSWORD',
                    hintText: '••••••••',
                    controller: _confirmPasswordController,
                    obscureText: true,
                  ),
                  const SizedBox(height: 32),

                  // Create Account Button
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryNavy,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'CREATE ACCOUNT',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper Widget for Form Fields
  Widget _buildInputField({
    required String label,
    required String hintText,
    required TextEditingController controller,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: labelColor,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 14,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: borderColor, width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: primaryNavy, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

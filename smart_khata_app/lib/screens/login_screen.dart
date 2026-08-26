import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isRegisterMode = false;
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  
  // Registration specific controllers
  final _nameController = TextEditingController();
  final _storeNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final String _selectedStoreType = 'Kiryana / General Store';

  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = ApiClient();
      final response = await client.post('/auth/login', {
        'username': _usernameController.text.trim(),
        'password': _passwordController.text,
      });

      final token = response['access_token'];
      final role = response['role'] ?? 'owner';
      final name = response['name'] ?? 'Owner';
      final storeName = response['store_name'] ?? 'Smart Khata Store';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.tokenKey, token);
      await prefs.setString(AppConstants.userRoleKey, role);
      await prefs.setString(AppConstants.userNameKey, name);
      await prefs.setString(AppConstants.storeNameKey, storeName);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('HttpException: ', '').replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleRegister() async {
    if (_usernameController.text.trim().isEmpty ||
        _passwordController.text.isEmpty ||
        _nameController.text.trim().isEmpty ||
        _storeNameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'تمام ضروری خانے پُر کریں (Please fill all fields)';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = ApiClient();
      final response = await client.post('/auth/register', {
        'username': _usernameController.text.trim(),
        'password': _passwordController.text,
        'name': _nameController.text.trim(),
        'role': 'owner',
        'store_name': _storeNameController.text.trim(),
        'store_type': _selectedStoreType,
        'phone': _phoneController.text.trim(),
        'city': 'Sahiwal',
      });

      final token = response['access_token'];
      final role = response['role'] ?? 'owner';
      final name = response['name'] ?? _nameController.text.trim();
      final storeName = response['store_name'] ?? _storeNameController.text.trim();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.tokenKey, token);
      await prefs.setString(AppConstants.userRoleKey, role);
      await prefs.setString(AppConstants.userNameKey, name);
      await prefs.setString(AppConstants.storeNameKey, storeName);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('HttpException: ', '').replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showServerSettingsDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUrl = prefs.getString(AppConstants.customServerUrlKey) ?? AppConstants.baseUrl;
    final serverController = TextEditingController(text: currentUrl);

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppConstants.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.cloud_sync_outlined, color: AppConstants.deepEmerald),
            const SizedBox(width: 8),
            Text(
              'Server Connection',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your Free Render Cloud API URL or local LAN IP:',
              style: GoogleFonts.inter(fontSize: 13, color: AppConstants.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: serverController,
              decoration: const InputDecoration(
                hintText: 'https://smart-khata-api.onrender.com/api',
                labelText: 'API Base URL',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('Localhost'),
                  onPressed: () => serverController.text = 'http://127.0.0.1:8000/api',
                ),
                ActionChip(
                  label: const Text('Emulator (10.0.2.2)'),
                  onPressed: () => serverController.text = 'http://10.0.2.2:8000/api',
                ),
                ActionChip(
                  label: const Text('Render Cloud'),
                  onPressed: () => serverController.text = AppConstants.defaultCloudUrl,
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppConstants.deepEmerald),
            onPressed: () async {
              final newUrl = serverController.text.trim();
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(ctx);
              if (newUrl.isNotEmpty) {
                await prefs.setString(AppConstants.customServerUrlKey, newUrl);
                AppConstants.customServerUrl = newUrl;
              }
              navigator.pop();
              messenger.showSnackBar(
                SnackBar(
                  content: Text('Server URL set to: $newUrl'),
                  backgroundColor: AppConstants.deepEmerald,
                ),
              );
            },
            child: const Text('Save Server', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.creamBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Brand Logo Header & Server Settings Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10.0),
                          decoration: BoxDecoration(
                            color: AppConstants.deepEmerald,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.storefront,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'smart khata',
                          style: GoogleFonts.inter(
                            color: AppConstants.charcoal,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings_ethernet, color: AppConstants.deepEmerald),
                      tooltip: 'Configure Server URL',
                      onPressed: _showServerSettingsDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 36),

                // Welcome / Register Header (Instrument Serif)
                Text(
                  _isRegisterMode ? 'Create Store' : 'Welcome back',
                  style: GoogleFonts.instrumentSerif(
                    color: AppConstants.charcoal,
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _isRegisterMode
                      ? 'نیا کھاتہ رجسٹر کریں (Register your retail dukaan)'
                      : 'اپنے اسمارٹ کھاتہ میں لاگ ان کریں (Sign in to your account)',
                  style: GoogleFonts.inter(
                    color: AppConstants.textMuted,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),

                if (_errorMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppConstants.softRedChip,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppConstants.alertRed.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: GoogleFonts.inter(color: AppConstants.alertRed, fontSize: 13),
                    ),
                  ),

                // ── Registration specific fields ──────────────────────────────
                if (_isRegisterMode) ...[
                  Text(
                    'Store Name (دکان کا نام)',
                    style: GoogleFonts.inter(
                      color: AppConstants.charcoal,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _storeNameController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Madina Kiryana Store',
                      prefixIcon: Icon(Icons.store, color: AppConstants.textMuted, size: 20),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text(
                    'Owner Full Name (مالک کا نام)',
                    style: GoogleFonts.inter(
                      color: AppConstants.charcoal,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Tariq Mahmood',
                      prefixIcon: Icon(Icons.person_outline, color: AppConstants.textMuted, size: 20),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text(
                    'Phone Number (موبائل نمبر)',
                    style: GoogleFonts.inter(
                      color: AppConstants.charcoal,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      hintText: '03001234567',
                      prefixIcon: Icon(Icons.phone_outlined, color: AppConstants.textMuted, size: 20),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Username / Phone Label & Input
                Text(
                  _isRegisterMode ? 'Choose Username (یوزر نیم)' : 'Username or Phone number',
                  style: GoogleFonts.inter(
                    color: AppConstants.charcoal,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _usernameController,
                  style: GoogleFonts.inter(color: AppConstants.charcoal, fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: 'e.g. admin or mykiryana',
                    prefixIcon: Icon(Icons.badge_outlined, color: AppConstants.textMuted, size: 20),
                  ),
                ),
                const SizedBox(height: 14),

                // Password / PIN Label & Input
                Text(
                  'Password / PIN (پاس ورڈ)',
                  style: GoogleFonts.inter(
                    color: AppConstants.charcoal,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: GoogleFonts.inter(color: AppConstants.charcoal, fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: '••••••••',
                    prefixIcon: Icon(Icons.lock_outline, color: AppConstants.textMuted, size: 20),
                  ),
                ),
                const SizedBox(height: 24),

                // Primary Action Button (Login or Register)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : (_isRegisterMode ? _handleRegister : _handleLogin),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.deepEmerald,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _isRegisterMode ? 'Register Store (کھاتہ بنائیں)' : 'Sign In (لاگ ان)',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                // Switch between Login and Register Mode
                Center(
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _isRegisterMode = !_isRegisterMode;
                        _errorMessage = null;
                      });
                    },
                    child: RichText(
                      text: TextSpan(
                        text: _isRegisterMode
                            ? 'Already have an account? '
                            : 'New store owner? ',
                        style: GoogleFonts.inter(color: AppConstants.textMuted, fontSize: 13),
                        children: [
                          TextSpan(
                            text: _isRegisterMode ? 'Sign In' : 'Create Store (نیا اکاؤنٹ)',
                            style: GoogleFonts.inter(
                              color: AppConstants.deepEmerald,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
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

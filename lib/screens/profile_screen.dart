import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'admin_screen.dart';
import '../widgets/app_footer.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isLoggedIn = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (mounted) {
      setState(() {
        _isLoggedIn = token != null && token.isNotEmpty;
      });
    }
  }

  void _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please fill all fields')));
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      await ApiService.login(username, password);
      
      if (mounted) {
        setState(() {
          _isLoggedIn = true; 
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        String errorMessage = 'Login Failed';
        bool isAlreadyLoggedIn = e.toString().contains('Another admin is currently active');
        
        if (isAlreadyLoggedIn) {
          _showSessionConflictDialog(username, password);
          return;
        }

        if (e.toString().contains('Invalid')) {
           errorMessage = 'Invalid Username or Password';
        } else if (e.toString().contains('SocketException') || e.toString().contains('Connection refused') || e.toString().contains('ClientException')) {
           errorMessage = 'Cannot connect to Server. Check connection or IP.';
        } else if (e.toString().contains('TimeoutException')) {
           errorMessage = 'Server is taking too long to respond. It might be waking up. Please try again in a moment.';
        } else {
           errorMessage = 'Error: ${e.toString().replaceAll("Exception:", "").trim()}';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(errorMessage, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.red.shade800,
          duration: Duration(seconds: 4),
        ));
      }
    }
  }

  void _showSessionConflictDialog(String username, String password) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 10),
            Text('Session Conflict', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
          ],
        ),
        content: Text(
          'Another admin is already logged in for this account. Only one active session is allowed.',
          style: GoogleFonts.outfit(fontSize: 14),
        ),
        actions: [
          TextButton(
            child: Text('CANCEL', style: GoogleFonts.outfit(color: Colors.grey, fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade800,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
            ),
            child: Text('FORCE RESET', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                await ApiService.resetSession(username, password);
                _login();
              } catch (err) {
                setState(() => _isLoading = false);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to reset: $err')));
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    setState(() => _isLoading = true);
    await ApiService.logout();
    if (mounted) {
      setState(() {
        _isLoggedIn = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryBlue = Color(0xFF2563EB);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLoggedIn ? 'ADMIN ACCOUNT' : 'ADMIN PORTAL', 
          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.5)
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          double cardWidth = constraints.maxWidth > 500 ? 450 : constraints.maxWidth * 0.9;
          
          return Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: cardWidth),
                child: Column(
                  children: [
                    _isLoggedIn ? _buildProfileUI(primaryBlue) : _buildLoginUI(primaryBlue),
                    SizedBox(height: 32),
                    AppFooter(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileUI(Color primaryBlue) {
    return Card(
      elevation: 8,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(color: primaryBlue.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(Icons.admin_panel_settings_rounded, size: 60, color: primaryBlue),
            ),
            SizedBox(height: 24),
            Text('ADMIN ACCESS', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: primaryBlue)),
            SizedBox(height: 8),
            Text('Welcome back! Your dashboard is ready.', textAlign: TextAlign.center, style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12)),
            SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                  elevation: 4,
                ),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminScreen())),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.speed),
                    SizedBox(width: 8),
                    Text('GO TO DASHBOARD', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13)),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            TextButton(
              onPressed: _logout,
              child: Text('SIGN OUT', style: GoogleFonts.outfit(color: Colors.red, fontWeight: FontWeight.w900, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginUI(Color primaryBlue) {
    return Card(
      elevation: 12,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(color: primaryBlue.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(Icons.admin_panel_settings_rounded, size: 48, color: primaryBlue),
            ),
            SizedBox(height: 24),
            Text('ADMINISTRATOR', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: primaryBlue)),
            SizedBox(height: 8),
            Text('Secure gateway for match officials', style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12)),
            SizedBox(height: 32),
            _buildTextField(_usernameController, 'USERNAME', Icons.person_outline),
            SizedBox(height: 20),
            _buildTextField(_passwordController, 'PASSWORD', Icons.lock_outline, isPassword: true),
            SizedBox(height: 32),
            if (_isLoading)
              CircularProgressIndicator(color: primaryBlue)
            else
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    elevation: 4,
                  ),
                  onPressed: _login,
                  child: Text('AUTHORIZE ACCESS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13)),
                ),
              ),
            if (!_isLoading) ...[
              SizedBox(height: 24),
              Divider(),
              SizedBox(height: 16),
              Text('Viewer access does not require authentication.', textAlign: TextAlign.center, style: GoogleFonts.outfit(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isPassword = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 8),
          child: Text(label, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey)),
        ),
        TextField(
          controller: controller,
          obscureText: isPassword && _obscurePassword,
          style: GoogleFonts.outfit(fontSize: 14),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20),
            suffixIcon: isPassword ? IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ) : null,
            filled: true,
            fillColor: Colors.grey.withOpacity(0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(100), borderSide: BorderSide.none),
            contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
        ),
      ],
    );
  }
}

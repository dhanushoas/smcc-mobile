import 'package:flutter/material.dart';
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
      // Removed redundant prefs load
      
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
          content: Text(errorMessage, style: TextStyle(fontWeight: FontWeight.bold)),
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
            Text('Active Session Found', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Another admin is already logged in for this account. Only one active session is allowed.\n\nWas that session closed unexpectedly? You can force reset it to log in here.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            child: Text('CANCEL', style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade800,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('FORCE RESET & LOGIN'),
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                await ApiService.resetSession(username, password);
                _login(); // Retry login after reset
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
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(_isLoggedIn ? 'Admin Account' : 'Admin Portal', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.blue.shade900,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          double cardWidth = constraints.maxWidth > 500 ? 450 : constraints.maxWidth * 0.9;
          
          return Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: cardWidth),
                child: Column(
                  children: [
                    _isLoggedIn ? _buildProfileUI() : _buildLoginUI(),
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

  Widget _buildProfileUI() {
    return Card(
      elevation: 8,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.blue.shade50,
              child: Icon(Icons.admin_panel_settings, size: 60, color: Colors.blue.shade800),
            ),
            SizedBox(height: 24),
            Text('Welcome, Admin', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.blue.shade900)),
            SizedBox(height: 8),
            Text('You have full access to manage matches.', style: TextStyle(color: Colors.grey, fontSize: 14)),
            SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade800,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 5,
                ),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminScreen())),
                child: Text('GO TO DASHBOARD', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
              ),
            ),
            SizedBox(height: 15),
            TextButton(
              onPressed: _logout,
              child: Text('Sign Out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginUI() {
    return Card(
      elevation: 8,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Hero(tag: 'logo', child: Image.asset('assets/logo.png', height: 80)),
            SizedBox(height: 24),
            Text('Admin Login', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.blue.shade900)),
            SizedBox(height: 8),
            Text('Sign in to manage live scores', style: TextStyle(color: Colors.grey, fontSize: 12)),
            SizedBox(height: 30),
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: 'Username',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            SizedBox(height: 15),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            SizedBox(height: 30),
            _isLoading
              ? Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 10),
                    Text('Waking up server...', style: TextStyle(color: Colors.blue.shade800, fontSize: 12)),
                    Text('This may take up to 60 seconds on first run.', style: TextStyle(color: Colors.grey, fontSize: 10)),
                  ],
                )
              : SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade800,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 5,
                    ),
                    onPressed: _login,
                    child: Text('SIGN IN', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                  ),
                ),
            SizedBox(height: 20),
            Text('Server: ${ApiService.baseUrl.split('/api')[0]}', 
                 style: TextStyle(color: Colors.grey.shade400, fontSize: 9, fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }


}

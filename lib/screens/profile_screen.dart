import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'admin_screen.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isLoggedIn = false;

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
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please fill all fields')));
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      await ApiService.login(_usernameController.text, _passwordController.text);
      final prefs = await SharedPreferences.getInstance();
      
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
        if (e.toString().contains('Invalid')) {
           errorMessage = 'Invalid Username or Password';
        } else if (e.toString().contains('SocketException') || e.toString().contains('Connection refused') || e.toString().contains('ClientException')) {
           errorMessage = 'Cannot connect to Server. Check connection or IP.';
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

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    if (mounted) {
      setState(() {
        _isLoggedIn = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoggedIn) {
      return Scaffold(
        appBar: AppBar(
          title: Text('My Profile', style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.bold)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          iconTheme: IconThemeData(color: Colors.blue.shade900),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.admin_panel_settings, size: 80, color: Colors.blue.shade800),
                SizedBox(height: 16),
                Text('Welcome, Admin', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.blue.shade900)),
                Text('You have full access to manage matches.', style: TextStyle(color: Colors.grey)),
                SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminScreen())),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade800,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Go to Admin Dashboard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: OutlinedButton(
                    onPressed: _logout,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Logout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: Colors.blue.shade900),
        title: Text('Profile', style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(Icons.settings, color: Colors.grey),
                    onPressed: _showServerDialog,
                    tooltip: 'Server Settings',
                  )
                ],
              ),
              Image.asset('assets/logo.png', height: 100),
              SizedBox(height: 24),
              Text('Admin Login', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.blue.shade900)),
              Text('Public users do not need to login', style: TextStyle(color: Colors.grey)),
              SizedBox(height: 48),
              
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                obscureText: true,
              ),
              SizedBox(height: 32),
              
              _isLoading
                  ? CircularProgressIndicator()
                  : SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade800,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                        child: Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
  }

  void _showServerDialog() {
    final _urlController = TextEditingController(text: ApiService.baseUrl.replaceAll('/api', ''));
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Server Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter your backend URL (e.g. 192.168.1.5:5000 or my-app.onrender.com)', style: TextStyle(fontSize: 12, color: Colors.grey)),
            SizedBox(height: 10),
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'Server Host',
                border: OutlineInputBorder(),
                prefixText: _urlController.text.startsWith('http') ? '' : 'http://'
              ),
            ),
          ],
        ),
        actions: [
          TextButton(child: Text('Cancel'), onPressed: () => Navigator.pop(context)),
          ElevatedButton(
            child: Text('Save'),
            onPressed: () async {
              String url = _urlController.text.trim();
              if (!url.startsWith('http')) url = 'http://$url';
              await ApiService.setUrl(url);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Server URL updated to $url')));
            },
          )
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:park_genie/DatabaseHelper.dart';
import 'package:park_genie/data/services/ApiConfig.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/services/AuthService.dart';
import 'SignupPage.dart';
import 'SyncPage.dart'; // Import the new sync page

class LoginPage extends StatefulWidget {

  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isEmailLogin = true;
  bool _otpSent = false;

  void _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      Map<String, dynamic> response;

      if (_isEmailLogin) {
        response = await AuthService().login(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      } else {
        if (!_otpSent) {
          response = await AuthService().requestOtp(_mobileController.text.trim());
          setState(() => _isLoading = false);

          if (response["success"]) {
            setState(() => _otpSent = true);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("OTP sent successfully"),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(response["message"] ?? "Failed to send OTP"),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        } else {
          response = await AuthService().verifyOtp(
            _mobileController.text.trim(),
            _otpController.text.trim(),
          );
        }
      }

      setState(() => _isLoading = false);
      print("Login ResponseS: $response"); // Debugging

      if (response["success"]) {
        // Get token from response
        final token = response["data"]?["token"] ?? response["token"] ?? "";

        // Get user data
        final user = response["data"]?["user"] ?? response["user"];

        if (user != null && token.isNotEmpty) {
          // Save token to SharedPreferences
          SharedPreferences prefs = await SharedPreferences.getInstance();
          prefs.setString("token", token);
          prefs.setString("userName", user["name"] ?? "Guest");
          prefs.setString("userId", user["id"] ?? "");
          print("Token stored: ${prefs.getString("token")}");

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Login Successful"),
              backgroundColor: Colors.green,
            ),
          );

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => SyncPage(
                  baseUrl: ApiConfig.baseUrl
              ),
            ), (route) => false,
          );

        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Invalid user data received"),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response["message"] ?? "Login failed"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      print("Login error: $e"); // Debugging
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("An error occurred. Please try again."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // App Logo or Icon
                        Icon(
                          Icons.local_parking,
                          size: 80,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(height: 16),

                        // App Name or Title
                        Text(
                          "Parking App",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Subtitle
                        Text(
                          "Sign in to your account",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Toggle between email and mobile login
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _isEmailLogin = true;
                                    _otpSent = false;
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: _isEmailLogin ? Colors.white : Theme.of(context).primaryColor,
                                  backgroundColor: _isEmailLogin ? Theme.of(context).primaryColor : Colors.white,
                                  elevation: _isEmailLogin ? 2 : 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(
                                      color: Theme.of(context).primaryColor,
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Text("Email"),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _isEmailLogin = false;
                                    _otpSent = false;
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: !_isEmailLogin ? Colors.white : Theme.of(context).primaryColor,
                                  backgroundColor: !_isEmailLogin ? Theme.of(context).primaryColor : Colors.white,
                                  elevation: !_isEmailLogin ? 2 : 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(
                                      color: Theme.of(context).primaryColor,
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Text("Mobile"),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        if (_isEmailLogin) ...[
                          // Email field
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: "Email",
                              hintText: "your.email@example.com",
                              prefixIcon: const Icon(Icons.email_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "Email is required";
                              }
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                return "Please enter a valid email";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Password field
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: "Password",
                              hintText: "Your password",
                              prefixIcon: const Icon(Icons.lock_outlined),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  color: Colors.grey,
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
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "Password is required";
                              }
                              if (value.length < 6) {
                                return "Password must be at least 6 characters";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),

                          // Forgot Password
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                // Implement forgot password functionality
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Forgot password feature coming soon")),
                                );
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(50, 30),
                              ),
                              child: const Text("Forgot Password?"),
                            ),
                          ),
                        ] else ...[
                          // Mobile field
                          TextFormField(
                            controller: _mobileController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: "Mobile Number",
                              hintText: "Your mobile number",
                              prefixIcon: const Icon(Icons.phone_android),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "Mobile number is required";
                              }
                              // Add your phone number validation regex here
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          if (_otpSent) ...[
                            // OTP field
                            TextFormField(
                              controller: _otpController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: "OTP",
                                hintText: "Enter OTP sent to your mobile",
                                prefixIcon: const Icon(Icons.lock_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return "OTP is required";
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 8),

                            // Resend OTP
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _isLoading ? null : () async {
                                  setState(() => _isLoading = true);
                                  try {
                                    final response = await AuthService().requestOtp(_mobileController.text.trim());
                                    setState(() => _isLoading = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            response["success"]
                                                ? "OTP resent successfully"
                                                : (response["message"] ?? "Failed to resend OTP")
                                        ),
                                        backgroundColor: response["success"] ? Colors.green : Colors.red,
                                      ),
                                    );
                                  } catch (e) {
                                    setState(() => _isLoading = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Failed to resend OTP"),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(50, 30),
                                ),
                                child: const Text("Resend OTP"),
                              ),
                            ),
                          ],
                        ],
                        const SizedBox(height: 24),

                        // Login/Request OTP button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Theme.of(context).primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                                : Text(
                              _isEmailLogin
                                  ? "LOGIN"
                                  : (_otpSent ? "VERIFY OTP" : "REQUEST OTP"),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Sign up link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account?",
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => SignupPage()),
                              ),
                              child: const Text(
                                "Sign up",
                                style: TextStyle(fontWeight: FontWeight.bold),
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
      ),
    );
  }
}
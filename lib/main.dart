import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:park_genie/presentation/screens/LockScreenPage.dart';
import 'package:park_genie/presentation/screens/LoginPage.dart';
import 'package:park_genie/presentation/screens/SyncPage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'data/services/ApiConfig.dart';

void main() async {
  final WidgetsBinding binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set up the server URL
  await _setupServerUrl(ApiConfig.baseUrl);

  runApp(const MyApp());
}

Future<void> _setupServerUrl(String baseUrl) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  // Only set the URL if it's not already set
  if (prefs.getString('baseUrl') == null) {
    await prefs.setString('baseUrl', baseUrl);
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Future<bool> _isLoggedIn;

  @override
  void initState() {
    super.initState();
    _isLoggedIn = _checkLoginStatus();
  }

  Future<bool> _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Artificial delay for smoother UX (optional)
    await Future.delayed(const Duration(milliseconds: 300));

    // Remove splash screen after loading
    FlutterNativeSplash.remove();

    // Check if token exists in SharedPreferences to determine login status
    String? token = prefs.getString("token");
    return token != null;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Park Genie',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A73E8),
          brightness: Brightness.light,
        ),
        // Additional theme customizations can be added here
      ),
      home: FutureBuilder<bool>(
        future: _isLoggedIn,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // While checking login status, show loading indicator
            return const Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Loading Park Genie...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          } else {
            // Check if user is logged in and navigate accordingly
            // Check if user is logged in and navigate accordingly
            final isLoggedIn = snapshot.data == true;

            return isLoggedIn
                ? LockScreenPage()
                : LoginPage(); // Navigate to login screen if not logged in
          }
        },
      ),
    );
  }
}
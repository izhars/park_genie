import 'dart:convert';
import 'package:http/http.dart' as http;

import 'ApiConfig.dart';

class AuthService {
  final String _url = ApiConfig.baseUrl; // Use loginUrl for all API calls

  Future<Map<String, dynamic>> login(String email, String password) async {
    final url = '$_url/users/login';
    final body = {"email": email, "password": password};
    print("[POST] $url\nPayload: $body");

    final response = await http.post(
      Uri.parse(url),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    print("Response: ${response.statusCode} ${response.body}");
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> signup(String name, String email, String password) async {
    final url = '$_url/users/register';
    final body = {"name": name, "email": email, "password": password};
    print("[POST] $url\nPayload: $body");

    final response = await http.post(
      Uri.parse(url),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    print("Response: ${response.statusCode} ${response.body}");
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> requestOtp(String mobile) async {
    final url = '$_url/users/request-otp';
    final body = {"mobile": mobile};
    print("[POST] $url\nPayload: $body");

    final response = await http.post(
      Uri.parse(url),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    print("Response-otp: ${response.statusCode} ${response.body}");
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> verifyOtp(String mobile, String otp) async {
    final url = '$_url/users/login-otp';
    final body = {"mobile": mobile, "otp": otp};
    print("[POST] $url\nPayload: $body");

    final response = await http.post(
      Uri.parse(url),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    print("Response: ${response.statusCode} ${response.body}");
    return _handleResponse(response);
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final data = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return {"success": true, "data": data};
    } else {
      return {
        "success": false,
        "message": data["message"] ?? "Something went wrong",
        "data": data
      };
    }
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final dynamic details;

  const ApiException({
    required this.statusCode,
    required this.message,
    this.details,
  });

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  final String baseUrl;
  final http.Client _httpClient;
  String? _authToken;

  ApiClient({
    String? baseUrl,
    http.Client? httpClient,
  })  : baseUrl = baseUrl ?? _defaultBaseUrl(),
        _httpClient = httpClient ?? http.Client();

  static String _defaultBaseUrl() {
    const customUrl = String.fromEnvironment('API_BASE_URL');
    if (customUrl.isNotEmpty) return customUrl;
    if (Platform.isAndroid) {
      // Host machine Wi-Fi IP for physical Android device
      return 'http://10.0.32.126:8000';
    }
    return 'http://localhost:8000';
  }

  void setAuthToken(String? token) {
    _authToken = token;
  }

  Map<String, String> _headers() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  Future<dynamic> get(String path, {Map<String, String>? queryParams}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: queryParams);
    try {
      final response = await _httpClient.get(uri, headers: _headers());
      return _processResponse(response);
    } on SocketException catch (e) {
      throw ApiException(statusCode: 0, message: 'Network unreachable: ${e.message}');
    }
  }

  Future<dynamic> post(String path, {dynamic body}) async {
    final uri = Uri.parse('$baseUrl$path');
    try {
      final response = await _httpClient.post(
        uri,
        headers: _headers(),
        body: body != null ? jsonEncode(body) : null,
      );
      return _processResponse(response);
    } on SocketException catch (e) {
      throw ApiException(statusCode: 0, message: 'Network unreachable: ${e.message}');
    }
  }

  dynamic _processResponse(http.Response response) {
    dynamic jsonBody;
    if (response.body.isNotEmpty) {
      try {
        jsonBody = jsonDecode(response.body);
      } catch (_) {
        jsonBody = response.body;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonBody;
    }

    String errorMessage = 'Request failed with status ${response.statusCode}';
    if (jsonBody is Map<String, dynamic> && jsonBody.containsKey('detail')) {
      errorMessage = jsonBody['detail'].toString();
    }

    throw ApiException(
      statusCode: response.statusCode,
      message: errorMessage,
      details: jsonBody,
    );
  }
}

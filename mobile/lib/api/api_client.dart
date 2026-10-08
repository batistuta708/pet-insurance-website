import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'models.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

/// Thin wrapper around the Flask JSON API (see app/routes/api_routes.py).
class ApiClient {
  ApiClient({http.Client? httpClient, this.baseUrl = apiBaseUrl})
      : _http = httpClient ?? http.Client();

  final http.Client _http;
  final String baseUrl;

  /// Bearer token; set after login, cleared on logout.
  String? token;

  // Generous: a sleeping free-tier server can take ~1 minute to wake up.
  static const _timeout = Duration(seconds: 60);

  /// Headers needed to load protected resources such as claim photos.
  Map<String, String> get authHeaders =>
      token == null ? const {} : {'Authorization': 'Bearer $token'};

  Future<dynamic> _send(String method, String path, {Object? body}) {
    final request = http.Request(method, Uri.parse('$baseUrl$path'));
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    return _execute(request);
  }

  Future<dynamic> _execute(http.BaseRequest request) async {
    request.headers['Accept'] = 'application/json';
    request.headers.addAll(authHeaders);

    final http.Response response;
    try {
      final streamed = await _http.send(request).timeout(_timeout);
      response = await http.Response.fromStream(streamed).timeout(_timeout);
    } on TimeoutException {
      throw ApiException('The server is taking too long to respond. Please try again in a moment.');
    } on SocketException {
      throw ApiException('Cannot reach the server. Check your internet connection.');
    } on http.ClientException {
      throw ApiException('Cannot reach the server. Check your internet connection.');
    }

    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        throw ApiException(
          'Unexpected response from the server (${response.statusCode}).',
          statusCode: response.statusCode,
        );
      }
    }

    if (response.statusCode >= 400) {
      final message = decoded is Map && decoded['error'] is String
          ? decoded['error'] as String
          : 'Request failed (${response.statusCode}).';
      throw ApiException(message, statusCode: response.statusCode);
    }
    return decoded;
  }

  List<T> _list<T>(dynamic data, T Function(Map<String, dynamic>) fromJson) =>
      (data as List).map((e) => fromJson(e as Map<String, dynamic>)).toList();

  // ---- auth & account ----

  Future<AuthResult> login(String email, String password) async => AuthResult.fromJson(
      await _send('POST', '/auth/login', body: {'email': email, 'password': password}));

  Future<AuthResult> register(String email, String password) async => AuthResult.fromJson(
      await _send('POST', '/auth/register', body: {'email': email, 'password': password}));

  Future<User> me() async => User.fromJson(await _send('GET', '/me'));

  Future<void> deleteAccount() => _send('DELETE', '/me');

  Future<void> changePassword({required String current, required String newPassword}) =>
      _send('POST', '/me/password', body: {
        'current_password': current,
        'new_password': newPassword,
      });

  // ---- quotes & pets ----

  Future<Quote> quote(String type, int age) async =>
      Quote.fromJson(await _send('POST', '/quote', body: {'type': type, 'age': age}));

  Future<List<Pet>> pets() async => _list(await _send('GET', '/pets'), Pet.fromJson);

  Future<Pet> addPet({required String name, required String type, required int age}) async =>
      Pet.fromJson(await _send('POST', '/pets', body: {'name': name, 'type': type, 'age': age}));

  /// Edits a pet; the server recalculates its premium.
  Future<Pet> updatePet(int id, {required String name, required String type, required int age}) async =>
      Pet.fromJson(await _send('PATCH', '/pets/$id', body: {'name': name, 'type': type, 'age': age}));

  Future<void> deletePet(int id) => _send('DELETE', '/pets/$id');

  Future<List<Policy>> policies() async => _list(await _send('GET', '/policies'), Policy.fromJson);

  // ---- claims ----

  Future<List<Claim>> claims() async => _list(await _send('GET', '/claims'), Claim.fromJson);

  Future<Claim> submitClaim({
    required int policyId,
    required String description,
    required double amount,
  }) async =>
      Claim.fromJson(await _send('POST', '/claims', body: {
        'policy_id': policyId,
        'description': description,
        'amount': amount,
      }));

  /// Attaches (or replaces) the photo of a claim. JPEG, PNG or WebP, up to 5 MB.
  Future<Claim> uploadClaimPhoto(int claimId, Uint8List bytes, {String filename = 'photo.jpg'}) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/claims/$claimId/photo'))
      ..files.add(http.MultipartFile.fromBytes('photo', bytes, filename: filename));
    return Claim.fromJson(await _execute(request));
  }

  /// URL of a claim's photo; load it with [authHeaders].
  String claimPhotoUrl(int claimId) => '$baseUrl/claims/$claimId/photo';
}

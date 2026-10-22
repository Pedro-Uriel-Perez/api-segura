/// Sends authenticated requests to the versioned Task Manager API.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../storage/token_store.dart';

/// A safe API failure with a user-displayable message.
class ApiException implements Exception {
  /// Creates an API exception.
  const ApiException(this.message, {this.statusCode});

  /// A safe message that does not contain server internals.
  final String message;

  /// HTTP status code, when available.
  final int? statusCode;

  @override
  String toString() => message;
}

/// Builds requests, attaches tokens, and performs one refresh-and-retry cycle.
class ApiClient {
  /// Creates a client with injectable HTTP and token-storage dependencies.
  ApiClient(this._http, this._tokens, {this.onSessionExpired, String? baseUrl})
      : _baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  final http.Client _http;
  final TokenStore _tokens;
  final String _baseUrl;

  /// Called after refresh fails and local credentials have been cleared.
  final VoidCallback? onSessionExpired;

  Future<bool>? _refreshInFlight;

  static const _authPaths = {
    'auth/refresh',
    'auth/login',
    'auth/register',
    'auth/logout',
  };

  /// Builds a fresh request so the request can safely be retried.
  Future<http.Request> _buildRequest(
    String method,
    String path,
    Map<String, dynamic>? body, {
    bool withAuth = true,
  }) async {
    final base = Uri.parse(_baseUrl);
    final target = Uri.parse(path);
    final joinedPath = '${base.path}/${target.path}'.replaceAll(RegExp(r'/+'), '/');
    final uri = base.replace(
      path: joinedPath,
      query: target.hasQuery ? target.query : null,
    );
    final request = http.Request(method, uri)
      ..headers['accept'] = 'application/json'
      ..headers['content-type'] = 'application/json';

    if (withAuth) {
      final token = await _tokens.readAccessToken();
      if (token != null) request.headers['authorization'] = 'Bearer $token';
    }
    if (body != null) request.body = jsonEncode(body);
    return request;
  }

  /// Sends a JSON request and returns its decoded response object.
  ///
  /// A protected request that receives 401 may refresh once and retry once.
  /// Throws [ApiException] for unsuccessful responses or malformed JSON.
  Future<Map<String, dynamic>> send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final isAuthPath = _authPaths.contains(path);
    var response = await _sendRequest(
      await _buildRequest(method, path, body, withAuth: !isAuthPath),
    );

    if (response.statusCode == 401 && !isAuthPath) {
      if (await _refreshTokens()) {
        response = await _sendRequest(
          await _buildRequest(method, path, body),
        );
      } else {
        throw const ApiException(
          'Your session has expired. Please sign in again.',
          statusCode: 401,
        );
      }
    }

    return _decodeResponse(response, path);
  }

  Future<http.Response> _sendRequest(http.Request request) async {
    try {
      final streamed = await _http.send(request).timeout(
            const Duration(seconds: 15),
          );
      return await http.Response.fromStream(streamed);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        'Could not connect to the server. Check your connection and try again.',
      );
    }
  }

  Future<Map<String, dynamic>> _decodeResponse(
    http.Response response,
    String path,
  ) async {
    final status = response.statusCode;
    if (status == 401) {
      throw ApiException(
        path == 'auth/login'
            ? 'Invalid email or password.'
            : 'Your session has expired. Please sign in again.',
        statusCode: 401,
      );
    }
    if (status < 200 || status >= 300) {
      throw ApiException(_messageFor(status), statusCode: status);
    }
    if (status == 204 || response.body.isEmpty) return {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const ApiException('The server returned unexpected data.');
      }
      return decoded;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('The server returned unexpected data.');
    }
  }

  /// Maps status codes to safe messages without exposing the raw server body.
  static String _messageFor(int status) => switch (status) {
        400 => 'Check the submitted values and try again.',
        404 => 'That item no longer exists.',
        409 => 'An account with this email already exists.',
        429 => 'Too many attempts. Wait a few minutes and try again.',
        _ => 'The request could not be completed. Try again.',
      };

  /// Refreshes credentials once; concurrent callers share the same operation.
  Future<bool> _refreshTokens() {
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight;
    final refresh = _performRefresh();
    _refreshInFlight = refresh;
    return refresh.whenComplete(() => _refreshInFlight = null);
  }

  Future<bool> _performRefresh() async {
    try {
      final refreshToken = await _tokens.readRefreshToken();
      if (refreshToken == null) throw const ApiException('Session expired.');
      final request = await _buildRequest(
        'POST',
        'auth/refresh',
        {'refreshToken': refreshToken},
        withAuth: false,
      );
      final response = await _sendRequest(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const ApiException('Session expired.');
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final accessToken = decoded['accessToken'];
      final newRefreshToken = decoded['refreshToken'];
      if (accessToken is! String || newRefreshToken is! String) {
        throw const ApiException('Session expired.');
      }
      await _tokens.saveTokens(accessToken, newRefreshToken);
      return true;
    } catch (_) {
      await _tokens.clear();
      onSessionExpired?.call();
      return false;
    }
  }
}

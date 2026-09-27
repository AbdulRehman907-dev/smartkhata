import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';

class ApiClient {
  // ── Token helper ──────────────────────────────────────────────────────────
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.tokenKey);
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await getToken();
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // ── Candidate base URLs (tried in order) ─────────────────────────────────
  Future<List<String>> _getCandidateUrls() async {
    final prefs = await SharedPreferences.getInstance();
    final customUrl = prefs.getString(AppConstants.customServerUrlKey);
    final urls = <String>[];
    if (customUrl != null && customUrl.trim().isNotEmpty) {
      if (customUrl.contains('railway.app') || customUrl.contains('railway.internal')) {
        await prefs.remove(AppConstants.customServerUrlKey);
        AppConstants.customServerUrl = null;
      } else {
        urls.add(customUrl.trim());
      }
    }
    if (!urls.contains(AppConstants.baseUrl)) {
      urls.add(AppConstants.baseUrl);
    }
    for (final fallback in ['http://127.0.0.1:8000/api', 'http://10.0.2.2:8000/api', 'http://192.168.100.12:8000/api']) {
      if (!urls.contains(fallback)) {
        urls.add(fallback);
      }
    }
    return urls;
  }

  static const Duration _requestTimeout = Duration(seconds: 35);

  // ── GET ───────────────────────────────────────────────────────────────────
  Future<dynamic> get(String endpoint) async {
    final headers = await _getHeaders();
    final candidateUrls = await _getCandidateUrls();

    for (final base in candidateUrls) {
      try {
        final res = await http
            .get(Uri.parse('$base$endpoint'), headers: headers)
            .timeout(_requestTimeout);
        return _handleResponse(res);
      } on SocketException catch (_) {
        continue;
      } on TimeoutException catch (_) {
        continue;
      } on HttpException catch (e) {
        if (e.message.contains('502') || e.message.contains('503') || e.message.contains('504')) {
          continue;
        }
        rethrow;
      } catch (e) {
        rethrow;
      }
    }
    throw const SocketException(
        'Backend unreachable. Check Wi-Fi / Cloud connection or run the backend server.');
  }

  // ── POST ──────────────────────────────────────────────────────────────────
  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    final headers = await _getHeaders();
    final candidateUrls = await _getCandidateUrls();

    for (final base in candidateUrls) {
      try {
        final res = await http
            .post(
              Uri.parse('$base$endpoint'),
              headers: headers,
              body: jsonEncode(body),
            )
            .timeout(_requestTimeout);
        return _handleResponse(res);
      } on SocketException catch (_) {
        continue;
      } on TimeoutException catch (_) {
        continue;
      } on HttpException catch (e) {
        if (e.message.contains('502') || e.message.contains('503') || e.message.contains('504')) {
          continue;
        }
        rethrow;
      } catch (e) {
        rethrow;
      }
    }
    throw const SocketException('Backend unreachable.');
  }

  // ── PUT ───────────────────────────────────────────────────────────────────
  Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    final headers = await _getHeaders();
    final candidateUrls = await _getCandidateUrls();

    for (final base in candidateUrls) {
      try {
        final res = await http
            .put(
              Uri.parse('$base$endpoint'),
              headers: headers,
              body: jsonEncode(body),
            )
            .timeout(_requestTimeout);
        return _handleResponse(res);
      } on SocketException catch (_) {
        continue;
      } on TimeoutException catch (_) {
        continue;
      } on HttpException catch (e) {
        if (e.message.contains('502') || e.message.contains('503') || e.message.contains('504')) {
          continue;
        }
        rethrow;
      } catch (e) {
        rethrow;
      }
    }
    throw const SocketException('Backend unreachable.');
  }

  // ── DELETE ────────────────────────────────────────────────────────────────
  Future<dynamic> delete(String endpoint) async {
    final headers = await _getHeaders();
    final candidateUrls = await _getCandidateUrls();

    for (final base in candidateUrls) {
      try {
        final res = await http
            .delete(Uri.parse('$base$endpoint'), headers: headers)
            .timeout(_requestTimeout);
        return _handleResponse(res);
      } on SocketException catch (_) {
        continue;
      } on TimeoutException catch (_) {
        continue;
      } on HttpException catch (e) {
        if (e.message.contains('502') || e.message.contains('503') || e.message.contains('504')) {
          continue;
        }
        rethrow;
      } catch (e) {
        rethrow;
      }
    }
    throw const SocketException('Backend unreachable.');
  }

  // ── POST Multipart (audio upload for Whisper STT) ─────────────────────────
  /// Uploads an audio file to the backend's Whisper STT endpoint.
  /// [endpoint] — e.g. '/ai/stt-intent'
  /// [filePath]  — absolute path to the recorded audio file on the device
  Future<dynamic> postAudioFile(String endpoint, String filePath) async {
    final token = await getToken();
    final candidateUrls = await _getCandidateUrls();

    for (final base in candidateUrls) {
      try {
        final uri = Uri.parse('$base$endpoint');
        final request = http.MultipartRequest('POST', uri);

        if (token != null && token.isNotEmpty) {
          request.headers['Authorization'] = 'Bearer $token';
        }

        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            filePath,
            filename: filePath.split(Platform.pathSeparator).last,
          ),
        );

        final streamed = await request.send().timeout(
          const Duration(seconds: AppConstants.voiceApiTimeoutSeconds),
        );
        final response = await http.Response.fromStream(streamed);
        return _handleResponse(response);
      } on SocketException catch (_) {
        continue;
      } on TimeoutException catch (_) {
        continue;
      } catch (e) {
        rethrow;
      }
    }
    throw const SocketException('Backend unreachable for audio upload.');
  }

  // ── Response handler ──────────────────────────────────────────────────────
  dynamic _handleResponse(http.Response response) {
    final body = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    final detail = (body is Map && body.containsKey('detail'))
        ? body['detail']
        : 'Server Error (${response.statusCode})';
    throw HttpException(detail.toString());
  }
}

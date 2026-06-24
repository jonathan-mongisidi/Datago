import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Gunakan IP 10.0.2.2 khusus untuk Android Emulator agar bisa mengakses localhost PC
  static const String baseUrl = 'http://10.0.2.2:8000/api';

  // Menyimpan token ke lokal storage
  Future<void> saveTokens(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', accessToken);
    await prefs.setString('refresh_token', refreshToken);
  }

  // Mengambil access token
  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  // Menghapus token (Logout)
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
  }

  // --- Fitur Autentikasi ---

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': email, // Di backend kita set username = email
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await saveTokens(data['access'], data['refresh']);
      return {'success': true};
    } else {
      return {'success': false, 'message': 'Email atau password salah.'};
    }
  }

  Future<Map<String, dynamic>> register(String name, String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'first_name': name,
        'username': email,
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 201) {
      // Jika berhasil register, otomatis login
      return await login(email, password);
    } else {
      return {'success': false, 'message': 'Gagal mendaftar. Email mungkin sudah digunakan.'};
    }
  }

  Future<Map<String, dynamic>> resetPassword(String email, String newPassword) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/reset-password/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'new_password': newPassword,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['success'] ?? 'Berhasil diubah'};
      } else {
        return {'success': false, 'message': data['error'] ?? 'Gagal mereset kata sandi'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan jaringan.'};
    }
  }

  Future<Map<String, dynamic>> uploadProfilePicture(String filePath) async {
    final token = await getAccessToken();
    if (token == null) return {'success': false, 'message': 'Not authenticated'};

    var request = http.MultipartRequest(
      'PUT', 
      Uri.parse('$baseUrl/auth/profile-picture/')
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath('profile_picture', filePath));

    try {
      var response = await request.send();
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true};
      } else {
        return {'success': false, 'message': 'Gagal mengunggah foto profil (Status: ${response.statusCode})'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>?> fetchCurrentUser() async {
    final token = await getAccessToken();
    if (token == null) return null;

    final response = await http.get(
      Uri.parse('$baseUrl/auth/me/'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  // --- Fitur Data ---

  Future<Map<String, dynamic>> fetchDashboardStats() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/stats/'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'error': 'Failed to load stats'};
      }
    } catch (e) {
      return {'error': 'Network error'};
    }
  }

  Future<List<dynamic>> fetchDatasets() async {
    final token = await getAccessToken();
    
    final headers = {
      'Content-Type': 'application/json',
    };
    
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await http.get(
      Uri.parse('$baseUrl/datasets/'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Gagal memuat dataset');
    }
  }

  Future<Map<String, dynamic>?> fetchDatasetStats(int datasetId) async {
    final token = await getAccessToken();
    final headers = {'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';

    final response = await http.get(
      Uri.parse('$baseUrl/datasets/$datasetId/stats/'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      return {'error': 'API Error ${response.statusCode}: ${response.body}'};
    }
  }

  Future<Map<String, dynamic>> createDataset(String title, String description, String visibility, String license) async {
    final token = await getAccessToken();
    if (token == null) return {'success': false, 'message': 'Not authenticated'};

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/datasets/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'title': title,
          'description': description,
          'visibility': visibility == 'Public (Anyone can view)' ? 'public' : 'private',
          'license': license,
        }),
      );

      if (response.statusCode == 201) {
        return {'success': true, 'dataset': jsonDecode(response.body)};
      } else {
        return {'success': false, 'message': 'Gagal membuat dataset'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan jaringan.'};
    }
  }

  Future<Map<String, dynamic>> uploadDatasetFile(int datasetId, String filePath, String versionTag) async {
    final token = await getAccessToken();
    if (token == null) return {'success': false, 'message': 'Not authenticated'};

    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/files/'));
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['dataset'] = datasetId.toString();
      request.fields['version_tag'] = versionTag;
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        return {'success': true};
      } else {
        return {'success': false, 'message': 'Gagal mengunggah file'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan jaringan.'};
    }
  }

  Future<Map<String, dynamic>> deleteDataset(int datasetId) async {
    final token = await getAccessToken();
    if (token == null) return {'success': false, 'message': 'Not authenticated'};

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/datasets/$datasetId/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 204) {
        return {'success': true};
      } else {
        return {'success': false, 'message': 'Gagal menghapus dataset'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan jaringan.'};
    }
  }

  Future<Map<String, dynamic>> deleteDatasetFile(int fileId) async {
    final token = await getAccessToken();
    if (token == null) return {'success': false, 'message': 'Not authenticated'};

    final response = await http.delete(
      Uri.parse('$baseUrl/files/$fileId/'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 204) {
      return {'success': true};
    } else {
      return {'success': false, 'message': 'Gagal menghapus file: ${response.body}'};
    }
  }

  Future<Map<String, dynamic>> cleanDatasetFile(int fileId) async {
    final token = await getAccessToken();
    if (token == null) return {'success': false, 'message': 'Not authenticated'};

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/files/$fileId/clean/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'success': false, 'message': 'Gagal membersihkan file: ${response.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  Future<Map<String, dynamic>?> findMatchingDatasets(int requestId) async {
    final token = await getAccessToken();
    if (token == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/requests/$requestId/match/'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  Future<void> incrementDownloadCount(int fileId) async {
    final token = await getAccessToken();
    final headers = {'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      await http.post(
        Uri.parse('$baseUrl/files/$fileId/increment_download/'),
        headers: headers,
      );
    } catch (e) {
      // Abaikan error jaringan untuk increment download
    }
  }

  Future<List<dynamic>> fetchDatasetRequests() async {
    final token = await getAccessToken();
    final headers = {'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/requests/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> updateDatasetRequestStatus(int reqId, String newStatus) async {
    final token = await getAccessToken();
    final headers = {'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/requests/$reqId/'),
        headers: headers,
        body: jsonEncode({'status': newStatus}),
      );

      if (response.statusCode == 200) {
        return {'success': true};
      } else {
        return {'success': false, 'message': 'Gagal memperbarui status'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan jaringan.'};
    }
  }

  Future<Map<String, dynamic>> fulfillDatasetRequest(int reqId, int fileId) async {
    final token = await getAccessToken();
    final headers = {'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/requests/$reqId/fulfill/'),
        headers: headers,
        body: jsonEncode({'file_id': fileId}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['error'] ?? 'Gagal mengirim ke IC'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan jaringan.'};
    }
  }
}

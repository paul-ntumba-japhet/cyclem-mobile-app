import 'dart:convert';
import 'package:http/http.dart' as http;
import '../extensions/shared_pref.dart' show getStringAsync, setValue, removeKey;

/// Service to manage API authentication token
/// This token is required for all authenticated API requests
class AuthTokenService {
  // API endpoint for authentication
  static const String _baseURL =
      "https://www.quickshare-apps.com/gateway-quickshare-api/apicyclem/authenticate";

  // Credentials for API authentication
  static const String _userName = 'cyclem-fe';
  static const String _password =
      'eyJzdWIiOiJzZG0iLCJleHAiOjE2NzY0MzY1NDgsImlhdCI6MTY3NjQwMDU0OH0';

  // Cache key for token in SharedPreferences
  static const String _tokenCacheKey = 'API_AUTH_TOKEN';
  static const String _tokenExpiryKey = 'API_AUTH_TOKEN_EXPIRY';

  /// Get authentication token
  /// Returns cached token if valid, otherwise fetches a new one
  Future<String> getToken() async {
    try {
      // Check if we have a cached token that's still valid
      String? cachedToken = getStringAsync(_tokenCacheKey);
      String? expiryStr = getStringAsync(_tokenExpiryKey);

      if (cachedToken.isNotEmpty && expiryStr.isNotEmpty) {
        try {
          DateTime expiry = DateTime.parse(expiryStr);
          // Check if token is still valid (with 5 minute buffer)
          if (expiry.isAfter(DateTime.now().add(Duration(minutes: 5)))) {
            print('Using cached API token');
            return cachedToken;
          }
        } catch (e) {
          print('Error parsing token expiry: $e');
        }
      }

      // Fetch new token
      print('Fetching new API token...');
      String newToken = await _fetchToken();
      
      // Cache the token (assume 24 hour validity, adjust based on your API)
      await setValue(_tokenCacheKey, newToken);
      await setValue(_tokenExpiryKey, DateTime.now().add(Duration(hours: 24)).toIso8601String());

      return newToken;
    } catch (e) {
      print('Error getting API token: $e');
      // Return cached token even if expired as fallback
      String? cachedToken = getStringAsync(_tokenCacheKey);
      if (cachedToken.isNotEmpty) {
        print('Using expired cached token as fallback');
        return cachedToken;
      }
      rethrow;
    }
  }

  /// Fetch new authentication token from API
  Future<String> _fetchToken() async {
    try {
      final url = Uri.parse(_baseURL);
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'userName': _userName,
          'password': _password,
        }),
      );

      if (response.statusCode == 200) {
        // Parse response - adjust based on your API response structure
        try {
          final responseData = jsonDecode(response.body);
          
          // Handle different response structures
          String token;
          if (responseData is Map) {
            // If response is a map, check common fields
            if (responseData.containsKey('token')) {
              token = responseData['token'].toString();
            } else if (responseData.containsKey('data') && responseData['data'] is Map) {
              token = responseData['data']['token']?.toString() ?? response.body;
            } else if (responseData.containsKey('accessToken')) {
              token = responseData['accessToken'].toString();
            } else if (responseData.containsKey('access_token')) {
              token = responseData['access_token'].toString();
            } else {
              // If token is in responseData itself
              token = response.body;
            }
          } else if (responseData is String) {
            token = responseData;
          } else {
            token = response.body;
          }

          if (token.isEmpty) {
            throw Exception('Token is empty in API response');
          }

          print('Successfully fetched API token');
          return token.trim();
        } catch (e) {
          print('Error parsing token response: $e');
          // If parsing fails, try using the raw response body
          if (response.body.isNotEmpty) {
            return response.body.trim();
          }
          throw Exception('Failed to parse token from response: $e');
        }
      } else {
        throw Exception(
            'Failed to get token: HTTP ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error fetching API token: $e');
      throw Exception('Failed to authenticate: ${e.toString()}');
    }
  }

  /// Clear cached token (useful for logout or token refresh)
  Future<void> clearToken() async {
    await removeKey(_tokenCacheKey);
    await removeKey(_tokenExpiryKey);
    print('API token cleared');
  }

  /// Force refresh token (clear cache and fetch new)
  Future<String> refreshToken() async {
    await clearToken();
    return await getToken();
  }

  /// Check if token is cached
  bool hasCachedToken() {
    String? token = getStringAsync(_tokenCacheKey);
    return token.isNotEmpty;
  }
}

/// Global instance
final authTokenService = AuthTokenService();


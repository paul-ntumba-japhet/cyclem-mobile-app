import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/app_common.dart';
import '../service/auth_token_service.dart';

class PhoneVerificationService {
  // API base URLs for OTP
  static const String _sendOTPBaseURL =
      "https://www.quickshare-apps.com/gateway-quickshare-api/apicyclem/transaction/otp";
  static const String _verifyOTPBaseURL =
      "https://www.quickshare-apps.com/gateway-quickshare-api/apicyclem/transaction/otp/check";
  static const String _subscriptionBaseURL =
      "https://www.quickshare-apps.com/gateway-quickshare-api/apicyclem/souscription";
  
  String? _verificationId;
  String? _phoneNumber; // Store phone number for verification
  String? _phoneForAPI; // Store phone number in API format (without +)

  /// Send OTP to phone number via API
  Future<String?> sendOTP(String phoneNumber, String countryCode, 
      {Function(String)? onCodeSent, Function(String)? onError}) async {
    try {
      // Format phone number with country code
      String fullPhoneNumber = '$countryCode$phoneNumber';
      
      // Remove any spaces or special characters except +
      fullPhoneNumber = fullPhoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      
      // Ensure it starts with +
      if (!fullPhoneNumber.startsWith('+')) {
        fullPhoneNumber = '+$fullPhoneNumber';
      }

      // Remove + and any non-digit characters for API call
      // The API endpoint expects just the digits: /otp/1234567890
      String phoneForAPI = fullPhoneNumber.replaceAll(RegExp(r'[^\d]'), '');

      // Validate phone number format
      if (phoneForAPI.length < 10 || phoneForAPI.length > 15) {
        String error = 'Phone number must be between 10 and 15 digits including country code';
        print('Phone number validation failed: $fullPhoneNumber (length: ${phoneForAPI.length})');
        if (onError != null) {
          onError(error);
        } else {
          toast(error);
        }
        return null;
      }

      print('Sending OTP to: $fullPhoneNumber (API format: $phoneForAPI)');
      
      // Get authentication token
      String authToken;
      try {
        authToken = await authTokenService.getToken();
      } catch (e) {
        String error = 'Failed to get authentication token. Please try again.';
        print('Auth token error: $e');
        if (onError != null) {
          onError(error);
        } else {
          toast(error);
        }
        return null;
      }

      // Build API URL with phone number
      String apiUrl = '$_sendOTPBaseURL/$phoneForAPI';
      final url = Uri.parse(apiUrl);

      print('Calling OTP API: $apiUrl');
      
      // Make API request with bearer token
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      );

      print('OTP API Response - Status: ${response.statusCode}');
      print('OTP API Response - Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Success - OTP sent
        try {
          final responseData = jsonDecode(response.body);
          
          // Extract verification ID or session ID from response if available
          String verificationId;
          if (responseData is Map) {
            // Check for common response fields
            if (responseData.containsKey('verificationId')) {
              verificationId = responseData['verificationId'].toString();
            } else if (responseData.containsKey('sessionId')) {
              verificationId = responseData['sessionId'].toString();
            } else if (responseData.containsKey('transactionId')) {
              verificationId = responseData['transactionId'].toString();
            } else if (responseData.containsKey('data') && responseData['data'] is Map) {
              verificationId = responseData['data']['verificationId']?.toString() ?? phoneForAPI;
            } else {
              // Use phone number as verification ID
              verificationId = phoneForAPI;
            }
          } else {
            verificationId = phoneForAPI;
          }

          _verificationId = verificationId;
          _phoneNumber = fullPhoneNumber;
          _phoneForAPI = phoneForAPI; // Store for verification

          print('OTP sent successfully. Verification ID: $verificationId');
          
          if (onCodeSent != null) {
            onCodeSent(verificationId);
          }
          
          return verificationId;
        } catch (e) {
          // If parsing fails, still consider it success if status is 200
          print('Warning: Could not parse response, but status is 200: $e');
          _verificationId = phoneForAPI;
          _phoneNumber = fullPhoneNumber;
          _phoneForAPI = phoneForAPI; // Store for verification
          
          if (onCodeSent != null) {
            onCodeSent(phoneForAPI);
          }
          
          return phoneForAPI;
        }
      } else {
        // Error response
        String errorMessage = _getApiErrorMessage(response.statusCode, response.body);
        print('OTP API Error - Status: ${response.statusCode}, Body: ${response.body}');
        
        if (onError != null) {
          onError(errorMessage);
        } else {
          toast(errorMessage);
        }
      return null;
    }
    } catch (e, stackTrace) {
      String errorMessage = 'Error sending OTP: ${e.toString()}';
      print('OTP send exception: $e');
      print('Stack trace: $stackTrace');
      
      if (onError != null) {
        onError(errorMessage);
      } else {
        toast(errorMessage);
      }
      return null;
    }
  }

  /// Get user-friendly error message from API response
  static String _getApiErrorMessage(int statusCode, String responseBody) {
    try {
      final errorData = jsonDecode(responseBody);
      if (errorData is Map && errorData.containsKey('message')) {
        return errorData['message'].toString();
      } else if (errorData is Map && errorData.containsKey('error')) {
        return errorData['error'].toString();
      }
    } catch (e) {
      // Ignore parsing errors
    }

    switch (statusCode) {
      case 400:
        return 'Invalid phone number format. Please check and try again.';
      case 401:
        return 'Authentication failed. Please try again.';
      case 403:
        return 'Access denied. Please contact support.';
      case 404:
        return 'OTP service not found. Please contact support.';
      case 429:
        return 'Too many requests. Please wait a moment before trying again.';
      case 500:
      case 502:
      case 503:
        return 'Server error. Please try again later.';
      default:
        return 'Failed to send OTP. Please try again. (Error: $statusCode)';
    }
  }

  /// Verify OTP code via API
  Future<bool> verifyOTP(String verificationId, String otpCode) async {
    try {
      // Validate OTP format
      if (otpCode.length != 4 || !RegExp(r'^\d{4}$').hasMatch(otpCode)) {
        toast('Invalid OTP code. Please enter a 4-digit code.');
        return false;
      }

      // Get phone number for API (use stored value or from verificationId)
      String phoneForAPI = _phoneForAPI ?? verificationId;
      
      if (phoneForAPI.isEmpty) {
        toast('Phone number not found. Please request a new OTP.');
        return false;
      }

      print('Verifying OTP for phone: $phoneForAPI, OTP: $otpCode');

      // Get authentication token
      String authToken;
      try {
        authToken = await authTokenService.getToken();
      } catch (e) {
        String error = 'Failed to get authentication token. Please try again.';
        print('Auth token error: $e');
        toast(error);
        return false;
      }

      // Build API URL: /transaction/otp/check/{phone}/{otp}
      String apiUrl = '$_verifyOTPBaseURL/$phoneForAPI/$otpCode';
      final url = Uri.parse(apiUrl);

      print('Calling OTP Verify API: $apiUrl');

      // Make API request with bearer token
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      );

      print('OTP Verify API Response - Status: ${response.statusCode}');
      print('OTP Verify API Response - Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Success - OTP verified
        try {
          final responseData = jsonDecode(response.body);
          
          // Check if response indicates success
          bool isVerified = false;
          if (responseData is Map) {
            // Check for common success indicators
            if (responseData.containsKey('status')) {
              isVerified = responseData['status'] == true || responseData['status'] == 'success';
            } else if (responseData.containsKey('verified')) {
              isVerified = responseData['verified'] == true;
            } else if (responseData.containsKey('success')) {
              isVerified = responseData['success'] == true;
            } else if (responseData.containsKey('data') && responseData['data'] is Map) {
              var data = responseData['data'];
              if (data.containsKey('status')) {
                isVerified = data['status'] == true || data['status'] == 'success';
              } else if (data.containsKey('verified')) {
                isVerified = data['verified'] == true;
              } else {
                // If we get 200 and data exists, assume success
                isVerified = true;
              }
            } else {
              // If response is 200, assume verification successful
              isVerified = true;
            }
          } else {
            // If response is 200, assume verification successful
            isVerified = true;
          }

          if (isVerified) {
            print('OTP verified successfully via API');
            
            // After successful OTP verification, call subscription API
            bool subscriptionSuccess = await _createSubscription(phoneForAPI);
            if (!subscriptionSuccess) {
              // If subscription fails, verification is still successful but user cannot proceed
              print('Subscription API failed, but OTP is verified');
              return false; // Return false to prevent proceeding to next step
            }
            
            return true;
          } else {
            toast('Invalid OTP code. Please check and try again.');
            return false;
          }
        } catch (e) {
          // If parsing fails but status is 200, assume OTP verification successful
          print('Warning: Could not parse verify response, but status is 200: $e');
          print('Assuming OTP verification successful');
          
          // After successful OTP verification, call subscription API
          bool subscriptionSuccess = await _createSubscription(phoneForAPI);
          if (!subscriptionSuccess) {
            // If subscription fails, verification is still successful but user cannot proceed
            print('Subscription API failed, but OTP is verified');
            return false; // Return false to prevent proceeding to next step
          }
          
          return true;
        }
      } else if (response.statusCode == 400 || response.statusCode == 404) {
        // Invalid OTP
        String errorMessage = _getApiErrorMessage(response.statusCode, response.body);
        print('OTP verification failed: $errorMessage');
        toast('Invalid OTP code. Please check and try again.');
        return false;
      } else {
        // Other errors
        String errorMessage = _getApiErrorMessage(response.statusCode, response.body);
        print('OTP Verify API Error - Status: ${response.statusCode}, Body: ${response.body}');
        toast(errorMessage);
        return false;
      }
    } catch (e, stackTrace) {
      String errorMessage = 'Error verifying OTP: ${e.toString()}';
      print('OTP verify exception: $e');
      print('Stack trace: $stackTrace');
      toast(errorMessage);
      return false;
    }
  }

  /// Resend OTP
  Future<String?> resendOTP(String phoneNumber, String countryCode,
      {Function(String)? onCodeSent, Function(String)? onError}) async {
    return await sendOTP(phoneNumber, countryCode, 
        onCodeSent: onCodeSent, onError: onError);
  }

  /// Create subscription after successful OTP verification
  Future<bool> _createSubscription(String phoneNumber) async {
    try {
      print('Creating subscription for phone: $phoneNumber');

      // Get authentication token
      String authToken;
      try {
        authToken = await authTokenService.getToken();
      } catch (e) {
        String error = 'Failed to get authentication token for subscription. Please try again.';
        print('Auth token error: $e');
        toast(error);
        return false;
      }

      // Get current date/time in ISO 8601 format
      String currentDate = DateTime.now().toUtc().toIso8601String();

      // Build subscription request body
      Map<String, dynamic> requestBody = {
        "identifiantMarchand": "CY-6585526235-WEB",
        "infoSouscription": {
          "montantPaye": 0,
          "numeroMMClient": "",
          "numeroBillingClient": phoneNumber,
          "emailClient": "",
          "nomClient": "",
          "devise": "USD",
          "dateRegles": "",
          "questionnaires": {
            "questionUn": "true",
            "questionDeux": "true",
            "questionTrois": "false",
            "questionReponse": "true"
          }
        },
        "dateDecreation": currentDate,
        "actionActive": "SACN",
        "source": {
          "source": "WEB"
        }
      };

      final url = Uri.parse(_subscriptionBaseURL);

      print('Calling Subscription API: $_subscriptionBaseURL');
      print('Request body: ${jsonEncode(requestBody)}');

      // Make POST request with bearer token
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode(requestBody),
      );

      print('Subscription API Response - Status: ${response.statusCode}');
      print('Subscription API Response - Body: ${response.body}');

      if (response.statusCode == 200) {
        print('Subscription created successfully');
        return true;
      } else {
        // Subscription failed
        String errorMessage = _getApiErrorMessage(response.statusCode, response.body);
        print('Subscription API Error - Status: ${response.statusCode}, Body: ${response.body}');
        toast('Failed to complete subscription: $errorMessage');
        return false;
      }
    } catch (e, stackTrace) {
      String errorMessage = 'Error creating subscription: ${e.toString()}';
      print('Subscription exception: $e');
      print('Stack trace: $stackTrace');
      toast(errorMessage);
      return false;
    }
  }

  /// Create subscription with questionnaire answers after questions are completed
  /// This is called after the user answers all 3 Yes/No questions
  static Future<bool> createSubscriptionWithAnswers({
    required String phoneNumber,
    required String email,
    required String name,
    required bool question1Answer,
    required bool question2Answer,
    required bool question3Answer,
  }) async {
    try {
      print('Creating subscription with questionnaire answers');
      print('Phone: $phoneNumber, Email: $email, Name: $name');
      print('Q1: $question1Answer, Q2: $question2Answer, Q3: $question3Answer');

      // Get authentication token
      String authToken;
      try {
        authToken = await authTokenService.getToken();
      } catch (e) {
        String error = 'Failed to get authentication token for subscription. Please try again.';
        print('Auth token error: $e');
        toast(error);
        return false;
      }

      // Get current date/time in ISO 8601 format
      //String currentDate = DateTime.now().toIso8601String();
      String currentDate = DateTime.now().toUtc().toIso8601String();

      // Format phone number (remove + and non-digits for API)
      String phoneForAPI = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

      // Build subscription request body with questionnaire answers
      Map<String, dynamic> requestBody = {
        "identifiantMarchand": "CY-6585526235-WEB",
        "infoSouscription": {
          "montantPaye": 0,
          "numeroMMClient": "",
          "numeroBillingClient": phoneForAPI,
          "emailClient": email,
          "nomClient": name,
          "devise": "USD",
          "dateRegles": "",
          "questionnaires": {
            "questionUn": question1Answer.toString(),
            "questionDeux": question2Answer.toString(),
            "questionTrois": question3Answer.toString(),
            "questionReponse": "true"
          }
        },
        "dateDecreation": currentDate,
        "actionActive": "SACQ",
        "source": {
          "source": "WEB"
        }
      };

      final url = Uri.parse(_subscriptionBaseURL);

      print('Calling Subscription API (with answers): $_subscriptionBaseURL');
      print('Request body: ${jsonEncode(requestBody)}');

      // Make POST request with bearer token
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode(requestBody),
      );

      print('Subscription API Response - Status: ${response.statusCode}');
      print('Subscription API Response - Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('Subscription with questionnaire answers created successfully');
        return true;
      } else {
        // Subscription failed
        String errorMessage = _getApiErrorMessage(response.statusCode, response.body);
        print('Subscription API Error - Status: ${response.statusCode}, Body: ${response.body}');
        toast('Failed to complete subscription: $errorMessage');
        return false;
      }
    } catch (e, stackTrace) {
      String errorMessage = 'Error creating subscription: ${e.toString()}';
      print('Subscription exception: $e');
      print('Stack trace: $stackTrace');
      toast(errorMessage);
      return false;
    }
  }

  /// Create subscription with period date after date selection
  /// This is called after the user selects their last period date
  static Future<bool> createSubscriptionWithPeriodDate({
    required String phoneNumber,
    required String periodDate,
    required bool question1Answer,
    required bool question2Answer,
    required bool question3Answer,
  }) async {
    try {
      print('Creating subscription with period date');
      print('Phone: $phoneNumber, Period Date: $periodDate');
      print('Q1: $question1Answer, Q2: $question2Answer, Q3: $question3Answer');

      // Get authentication token
      String authToken;
      try {
        authToken = await authTokenService.getToken();
      } catch (e) {
        String error = 'Failed to get authentication token for subscription. Please try again.';
        print('Auth token error: $e');
        toast(error);
        return false;
      }

      // Get current date/time in ISO 8601 format
      String currentDate = DateTime.now().toUtc().toIso8601String();

      // Format phone number (remove + and non-digits for API)
      String phoneForAPI = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

      // Build subscription request body with period date
      Map<String, dynamic> requestBody = {
        "identifiantMarchand": "CY-6585526235-WEB",
        "infoSouscription": {
          "montantPaye": 0,
          "numeroMMClient": "",
          "numeroBillingClient": phoneForAPI,
          "emailClient": "",
          "nomClient": "",
          "devise": "USD",
          "dateRegles": periodDate,
          "questionnaires": {
            "questionUn": question1Answer.toString(),
            "questionDeux": question2Answer.toString(),
            "questionTrois": question3Answer.toString(),
            "questionReponse": "true"
          }
        },
        "dateDecreation": currentDate,
        "actionActive": "SACR",
        "source": {
          "source": "WEB"
        }
      };

      final url = Uri.parse(_subscriptionBaseURL);

      print('Calling Subscription API (with period date): $_subscriptionBaseURL');
      print('Request body: ${jsonEncode(requestBody)}');

      // Make POST request with bearer token
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode(requestBody),
      );

      print('Subscription API Response - Status: ${response.statusCode}');
      print('Subscription API Response - Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('Subscription with period date created successfully');
        return true;
      } else {
        // Subscription failed
        String errorMessage = _getApiErrorMessage(response.statusCode, response.body);
        print('Subscription API Error - Status: ${response.statusCode}, Body: ${response.body}');
        toast('Failed to complete subscription: $errorMessage');
        return false;
      }
    } catch (e, stackTrace) {
      String errorMessage = 'Error creating subscription: ${e.toString()}';
      print('Subscription exception: $e');
      print('Stack trace: $stackTrace');
      toast(errorMessage);
      return false;
    }
  }

  /// Get current verification ID
  String? get verificationId => _verificationId;

  /// Get stored phone number
  String? get phoneNumber => _phoneNumber;
}


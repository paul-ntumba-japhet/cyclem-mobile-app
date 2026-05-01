import 'dart:convert';
import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:terminate_restart/terminate_restart.dart';
import 'package:era_flutter/extensions/extensions.dart';
import 'package:era_flutter/model/user/faq_model.dart';
import 'package:era_flutter/service/reminder_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart' show Response;

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../extensions/shared_pref.dart';
import '../../extensions/extension_util/string_extensions.dart';
import '../languageConfiguration/ServerLanguageResponse.dart';
import '../main.dart';
import '../model/bookmark_response_model.dart';
import '../model/common/app_setting_model.dart';
import '../model/common/default_message_response.dart';
import '../model/doctor/doctor_models/doctor_dashboard_model.dart';
import '../model/doctor/doctor_models/doctor_response.dart';
import '../model/doctor/doctor_models/health_expert_model.dart';
import '../model/common/article_models/article_response.dart';
import '../model/user/bookmark_model.dart';
import '../model/user/calculator_model.dart';
import '../model/user/category_models/all_category_model.dart';
import '../model/user/category_models/category_data_response.dart';
import '../model/user/category_models/comment_list_response.dart';
import '../model/user/category_models/secret_chat_response.dart';
import '../model/user/dashboard_article_model.dart';
import '../model/user/dashboard_response.dart';
import '../model/model.dart';
import '../model/user/expert_question_list_model.dart';
import '../model/user/rest_app_pin_model.dart';
import '../model/user/restore_data_model.dart';
import '../model/user/update_user_model.dart';
import '../model/user/user_models/user_model.dart';
import '../model/user/user_models/user_response_model.dart';
import '../model/user/user_profile_data_model.dart';
import '../model/user/cycle_info_model.dart';
import '../model/user/subscription_info_model.dart';
import '../model/user/user_transaction_model.dart';
import '../model/user/payment_status_model.dart';
import '../model/user/payment_plan_model.dart';
import '../model/user/chat_backend_auth_model.dart';
import '../model/user/chat_message_response_model.dart';
import '../model/user/stripe_config_model.dart';
import '../model/user/stripe_customer_model.dart';
import '../model/user/stripe_setup_intent_payment_method_model.dart';
import '../model/user/quickshare_stripe_subscription_model.dart';
import '../model/user/mobile_payment_initialization_model.dart';
import '../model/user/question_model.dart';
import '../utils/app_constants.dart';
import '../utils/app_common.dart';
import '../utils/app_images.dart';
import '../service/auth_token_service.dart';
import '../utils/utils.dart';
import '../extensions/extension_util/date_time_extensions.dart';
import 'network_utils.dart';
// import 'network_utils.dart';

// FOR Token(Authorization) Please remove comment from the network_utils.dart file

Future<DoctorResponse> logInApi(request) async {
  Response response = await buildHttpResponse('login',
      request: request, method: HttpMethod.post);
  if (!response.statusCode.isSuccessful()) {
    if (response.body.isJson()) {
      var json = jsonDecode(response.body);
      json = json['responseData'];

      if (json.containsKey('code') &&
          json['code'].toString().contains('invalid_username')) {
        throw 'invalid_username';
      }
    }
  }

  return await handleResponse(response).then((value) async {
    value = value['responseData'];
    DoctorResponse userModel = DoctorResponse.fromJson(value);
    DoctorResponse? userResponse = userModel;

    saveDoctorData(userResponse);
    await userStore.setLogin(true);
    return userModel;
  });
}

Future<UserResponse> logInAsUserApi(request) async {
  // Refresh QuickShare token before login to ensure Laravel backend has a valid token
  // when it authenticates with QuickShare API
  try {
    print('Refreshing QuickShare token before login...');
    await authTokenService.refreshToken();
    print('✅ QuickShare token refreshed successfully');
  } catch (e) {
    print('⚠️ Warning: Failed to refresh QuickShare token before login: $e');
    // Continue with login attempt - Laravel backend may handle token refresh internally
  }
  
  // Login endpoint is public - no API auth token needed
  // Laravel backend handles QuickShare authentication internally
  Response response = await buildHttpResponse('login',
      request: request, method: HttpMethod.post, requiresAuth: false);
  
  print('Login API Response Status: ${response.statusCode}');
  print('Login API Response Body: ${response.body}');
  
  // Only check for errors if status code is NOT successful
  if (!response.statusCode.isSuccessful()) {
    print('Login failed with status: ${response.statusCode}');
    if (response.body.isJson()) {
      var json = jsonDecode(response.body);
      // Laravel returns direct response, not wrapped in responseData
      var responseData = json['responseData'] ?? json;
      
      // Extract error message from response
      String? errorMessage;
      if (responseData is Map) {
        errorMessage = responseData['message']?.toString() ?? 
                      responseData['error']?.toString();
        
        print('Error message extracted: $errorMessage');
        
        // Check for specific error codes
        if (responseData.containsKey('code') &&
            responseData['code'].toString().contains('invalid_username')) {
          throw 'invalid_username';
        }
        
        // Check for "user not registered" error (French) - ONLY if message contains it
        if (errorMessage != null && 
            (errorMessage.contains("n'est pas enregistre") ||
             errorMessage.contains("not registered") ||
             errorMessage.contains("not enrolled"))) {
          throw Exception('USER_NOT_REGISTERED: $errorMessage');
        }
        
        // Throw the error message if available
        if (errorMessage != null && errorMessage.isNotEmpty) {
          throw Exception(errorMessage);
        }
      }
    }
  } else {
    print('Login successful with status: ${response.statusCode}');
  }

  return await handleResponse(response).then((value) async {
    print('handleResponse returned value type: ${value.runtimeType}');
    print('handleResponse value: $value');
    // Laravel API returns direct response without responseData wrapper
    // Response structure: { "message": "...", "code": "...", "token": "...", "api_token": "..." }
    Map<String, dynamic> responseData;
    
    if (value is Map<String, dynamic>) {
      // Check if responseData wrapper exists (old format) or use value directly (Laravel format)
      if (value.containsKey('responseData') && value['responseData'] != null) {
        responseData = value['responseData'] as Map<String, dynamic>;
      } else {
        // Laravel direct response format
        responseData = value;
      }
    } else {
      throw Exception('Invalid response format: Expected Map but got ${value.runtimeType}');
    }
    
    // Extract token from Laravel response
    String? token = responseData['token']?.toString() ?? 
                    responseData['api_token']?.toString();
    
    if (token == null || token.isEmpty) {
      throw Exception('Login successful but no token received');
    }
    
    // Extract phone number from request
    String? phoneNumber = request['username']?.toString() ?? 
                         request['phone_number']?.toString();
    if (phoneNumber == null || phoneNumber.isEmpty) {
      throw Exception('Phone number is required for login');
    }
    
    // Format phone number (remove non-digits)
    String phoneForAPI = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    // Check if user information exists for this phone number
    QuestionsModel? existingQuestionData = loadQuestionDataForPhone(phoneForAPI);
    CycleInfoModel? existingCycleInfo = loadCycleInfoForPhone(phoneForAPI);
    SubscriptionInfoModel? existingSubscriptionInfo = loadSubscriptionInfoForPhone(phoneForAPI);
    
    bool hasExistingUserData = existingQuestionData != null && 
                                existingCycleInfo != null && 
                                existingSubscriptionInfo != null;
    
    QuestionsModel questionsModelData;
    CycleInfoModel? cycleInfoData;
    SubscriptionInfoModel? subscriptionInfoData;
    
    if (hasExistingUserData) {
      // All user data exists - use existing data
      print('✅ All user data found for phone: $phoneForAPI');
      print('Using existing QuestionData, CycleInfo, and SubscriptionInfo');
      questionsModelData = existingQuestionData;
      cycleInfoData = existingCycleInfo;
      subscriptionInfoData = existingSubscriptionInfo;
      
      // Load into userStore
      await userStore.setCycleInfo(cycleInfoData);
      await userStore.setSubscriptionInfo(subscriptionInfoData);
      print('✅ Existing user data loaded into userStore');
    } else {
      // User data doesn't exist or is incomplete - create/fetch new data
      print('ℹ️ User data not found or incomplete for phone: $phoneForAPI');
      
      // 1. Handle QuestionsModel - use existing if available, otherwise create with defaults
      if (existingQuestionData != null) {
        print('Using existing QuestionData');
        questionsModelData = existingQuestionData;
      } else {
        print('Creating QuestionData with default values');
        // Get country code from request if available
        String? countryCode = request['country_code']?.toString();
        
        // Create QuestionData with minimal defaults
        questionsModelData = createQuestionDataFromSubscription(
          subscriptionInfo: SubscriptionInfoModel(
            numeroClient: phoneForAPI,
            nomClient: '',
            emailClient: '',
            dateTransaction: '',
            dateDernierRegles: '',
            dateDernierPayJour: '',
            dateDernierPayMois: '',
            statusClient: '0',
            reqType: 'R',
          ),
          phoneNumber: phoneNumber,
          countryCode: countryCode,
        );
        // Save the new QuestionData for this phone number
        await saveQuestionDataForPhone(phoneForAPI, questionsModelData);
        print('✅ QuestionData with defaults created and saved for phone: $phoneForAPI');
      }
      
      // 2. Fetch CycleInfo and SubscriptionInfo via API using phone number
      print('Fetching CycleInfo and SubscriptionInfo via API for phone: $phoneForAPI');
      
      // Fetch cycle info
      try {
        cycleInfoData = await getCycleInfoDirectApi(phoneNumber);
        await userStore.setCycleInfo(cycleInfoData);
        await saveCycleInfoForPhone(phoneForAPI, cycleInfoData);
        print('✅ CycleInfo fetched and saved for phone: $phoneForAPI');
      } catch (e) {
        print('⚠️ Error fetching cycle info: $e');
        // Continue - cycleInfoData will remain null
      }
      
      // Fetch subscription info
      try {
        subscriptionInfoData = await getSubscriptionInfoApi(phoneNumber);
        await userStore.setSubscriptionInfo(subscriptionInfoData);
        await saveSubscriptionInfoForPhone(phoneForAPI, subscriptionInfoData);
        print('✅ SubscriptionInfo fetched and saved for phone: $phoneForAPI');
      } catch (e) {
        print('⚠️ Error fetching subscription info: $e');
        // Continue - subscriptionInfoData will remain null
      }
    }
    
    // Set token in userStore temporarily so we can make authenticated requests
    userStore.setToken(token);
    setValue(TOKEN, token);
    
    // Extract data from questionsModelData to construct UserModel
    String? fullName = questionsModelData.step3PersonalInfo.fullName;
    List<String> nameParts = fullName?.trim().split(' ') ?? [];
    String firstName = nameParts.isNotEmpty ? nameParts.first : '';
    String lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
    
    // Extract email
    String? email = questionsModelData.step3PersonalInfo.email ?? '';
    
    // Age no longer collected in onboarding; use 0
    int age = 0;
    
    // Create UserModel with data from QuestionData
    final userModel = UserModel(
      id: 0, // Will be updated when user details are fetched or when backend returns it
      apiToken: token,
      status: statusActive, // 'active' - required for login check
      userType: 'app_user',
      firstName: firstName,
      lastName: lastName,
      email: email,
      age: age,
      phoneNumber: phoneForAPI,
      goalType: questionsModelData.step1.selectedOption ?? 0,
      cycleLength: questionsModelData.step4.selectedOption ?? DEFAULT_CYCLE_LENGTH,
      periodLength: questionsModelData.step5.selectedOption ?? DEFAULT_PERIOD_LENGTH,
      lutealPhase: questionsModelData.step6.selectedOption != -1 
          ? questionsModelData.step6.selectedOption 
          : 0,
      periodStartDate: questionsModelData.step3.selectedLastPeriodDate?.isNotEmpty == true
          ? questionsModelData.step3.selectedLastPeriodDate
          : getDateTimeString(DateTime.now()),
    );
    
    // Map Laravel response to UserResponse format
    final userResponse = UserResponse(
      status: responseData['code']?.toString() == '200' || 
              responseData['code']?.toString() == '201' ||
              responseData.containsKey('token'),
      message: responseData['message']?.toString() ?? 'Login successful',
      data: userModel,
    );

    saveUserData(userResponse.data);
    await userStore.setLogin(true);
    
    // If we already loaded existing data, we're done - no need to fetch again
    // If data didn't exist, it was already fetched in the else block above
    // _fetchCycleInfoAfterLogin is only called as a backup/refresh if needed
    // (it will check if data exists first before fetching)
    
    return userResponse;
  });
}

/// Signup/Register API with phone number and password (no codeAcces)
/// This calls Laravel proxy endpoint which validates with QuickShare API /register
/// and returns a Sanctum token
Future<UserResponse> loginWithPhoneAndCode({
  required String phoneNumber,
  required String password,
}) async {
  try {
    // Format phone number (remove + and non-digits for API)
    String phoneForAPI = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    // Build request body (codeAcces removed from Login and Register)
    Map<String, dynamic> requestBody = {
      "username": phoneForAPI,
      "password": password,
      "actionDem": "LoginAct"
    };

    // Use Laravel API endpoint
    final url = Uri.parse("https://mobile.cycle-menstruel.com/api/register");

    print('Calling Laravel Login API: $url');
    print('Request body: ${jsonEncode(requestBody)}');

    // Make POST request (no bearer token needed for login)
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(requestBody),
    );

    print('Login API Response - Status: ${response.statusCode}');
    print('Login API Response - Body: ${response.body}');

    if (!response.statusCode.isSuccessful()) {
      // Parse error response
      try {
        final errorData = jsonDecode(response.body);
        String errorMessage = errorData['message']?.toString() ?? 
            errorData['error']?.toString() ?? 
            'Login failed. Please check your credentials.';
        throw Exception(errorMessage);
      } catch (e) {
        throw Exception('Login failed: HTTP ${response.statusCode}');
      }
    }

    // Parse successful response
    final responseData = jsonDecode(response.body);
    
    // Extract Sanctum token from Laravel response
    String? sanctumToken = responseData['token']?.toString() ?? 
                          responseData['api_token']?.toString();
    
    if (sanctumToken == null || sanctumToken.isEmpty) {
      throw Exception('Login successful but no token received');
    }

    print('Sanctum Token received from Laravel: ${sanctumToken.length > 50 ? sanctumToken.substring(0, 50) + "..." : sanctumToken}');

    // Format phone number (remove non-digits) - phoneForAPI already defined above
    // String phoneForAPI = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    // Check if questionsModel has been populated with user data from onboarding process
    // Check if phone is verified or if personal info has been filled
    bool hasOnboardingData = questionsModel.step2Phone.isVerified == true ||
        (questionsModel.step2Phone.phoneNumber != null && 
         questionsModel.step2Phone.phoneNumber!.isNotEmpty) ||
        (questionsModel.step3PersonalInfo.fullName != null && 
         questionsModel.step3PersonalInfo.fullName!.isNotEmpty) ||
        (questionsModel.step3PersonalInfo.email != null && 
         questionsModel.step3PersonalInfo.email!.isNotEmpty);
    
    QuestionsModel questionsModelData;
    
    if (hasOnboardingData) {
      // Use existing questionsModel from onboarding process
      print('Using existing QuestionData from onboarding process for phone: $phoneForAPI');
      questionsModelData = questionsModel;
      
      // Save the existing QuestionData for this phone number (phone-specific only)
      await saveQuestionDataForPhone(phoneForAPI, questionsModelData);
      print('Existing QuestionData saved for phone: $phoneForAPI');
    } else {
      // No onboarding data found - create new one with defaults
      print('No onboarding data found. Creating new QuestionData for phone: $phoneForAPI');
      
      // Extract country code from phone number if available
      String? countryCode = phoneNumber.contains('+') 
          ? phoneNumber.substring(0, phoneNumber.indexOf(RegExp(r'\d')))
          : null;
      
      // Create new QuestionData with minimal defaults for registration
      questionsModelData = createQuestionDataFromSubscription(
        subscriptionInfo: SubscriptionInfoModel(
          numeroClient: phoneForAPI,
          nomClient: '',
          emailClient: '',
          dateTransaction: '',
          dateDernierRegles: '',
          dateDernierPayJour: '',
          dateDernierPayMois: '',
          statusClient: '0',
          reqType: 'R',
        ),
        phoneNumber: phoneNumber,
        countryCode: countryCode,
      );
      
      // Save the new QuestionData for this phone number (phone-specific only)
      await saveQuestionDataForPhone(phoneForAPI, questionsModelData);
      print('New QuestionData created and saved for phone: $phoneForAPI');
    }
    
    // Extract name from step3PersonalInfo
    String? fullName = questionsModelData.step3PersonalInfo.fullName;
    List<String> nameParts = fullName?.trim().split(' ') ?? [];
    String firstName = nameParts.isNotEmpty ? nameParts.first : '';
    String lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
    
    // Extract email
    String? email = questionsModelData.step3PersonalInfo.email ?? '';
    
    // Age no longer collected in onboarding; use 0
    int age = 0;
    
    // Construct UserModel with Sanctum token from Laravel
    final Map<String, dynamic> userDataMap = {
      'id': 0, // Will be set by backend on first sync
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'age': age,
      'phone_number': phoneForAPI,
      'goal_type': questionsModelData.step1.selectedOption ?? 0,
      'user_type': 'app_user',
      'period_start_date': questionsModelData.step3.selectedLastPeriodDate?.isNotEmpty == true
          ? questionsModelData.step3.selectedLastPeriodDate
          : getDateTimeString(DateTime.now()),
      'cycle_length': questionsModelData.step4.selectedOption ?? DEFAULT_CYCLE_LENGTH,
      'period_length': questionsModelData.step5.selectedOption ?? DEFAULT_PERIOD_LENGTH,
      'luteal_phase': questionsModelData.step6.selectedOption != -1 
          ? questionsModelData.step6.selectedOption 
          : 0,
      'api_token': sanctumToken, // Sanctum token from Laravel
      'status': 'active',
    };
    
    final userResponse = UserResponse(
      status: true,
      message: responseData['message']?.toString() ?? 'Login successful',
      data: UserModel.fromJson(userDataMap),
    );

    if (userResponse.status == true && userResponse.data != null) {
      // Check if this is a different user BEFORE saving new user data
      UserModel? previousUser = await getUserFromLocalStorage();
      String newPhone = userResponse.data!.phoneNumber?.replaceAll(RegExp(r'[^\d]'), '') ?? '';
      
      if (previousUser != null && previousUser.phoneNumber != null) {
        String previousPhone = previousUser.phoneNumber!.replaceAll(RegExp(r'[^\d]'), '');
        if (previousPhone.isNotEmpty && newPhone.isNotEmpty && previousPhone != newPhone) {
          print('🔄 Different user detected during login! Previous: $previousPhone, New: $newPhone');
          print('ℹ️ Previous user data preserved - using phone-specific keys for new user');
          
          // Clear from userStore (will be loaded for new user)
          // Note: Phone-specific data for previous user is preserved in SharedPreferences
          // Each user's data is stored separately by phone number, so no need to clear old data
          await userStore.setCycleInfo(null);
          await userStore.setSubscriptionInfo(null);
          
          print('✅ UserStore cleared - new user data will be loaded');
        }
      }
      
      saveUserData(userResponse.data);
      await userStore.setLogin(true);
      
      // Fetch cycle info after successful login (non-blocking)
      // Laravel will get phone from authenticated user session
      _fetchCycleInfoAfterLogin();
      
      return userResponse;
    } else {
      throw Exception(userResponse.message ?? 'Login failed');
    }
  } catch (e) {
    print('Login API Error: $e');
    rethrow;
  }
}

/// Helper method to fetch cycle info after login (non-blocking)
/// Gets phone number from userStore and calls QuickShare API directly
/// Only fetches if data doesn't already exist for this phone number
Future<void> _fetchCycleInfoAfterLogin() async {
  try {
    // Get phone number from user model
    String? phoneNumber = userStore.user?.phoneNumber;
    if (phoneNumber == null || phoneNumber.isEmpty) {
      print('Cannot fetch cycle info: phone number not available');
      return;
    }
    
    // Format phone number for storage (remove non-digits)
    String phoneForAPI = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    // Check if cycle info and subscription info already exist for this phone number
    CycleInfoModel? existingCycleInfo = loadCycleInfoForPhone(phoneForAPI);
    SubscriptionInfoModel? existingSubscriptionInfo = loadSubscriptionInfoForPhone(phoneForAPI);
    
    if (existingCycleInfo != null && existingSubscriptionInfo != null) {
      // Data already exists - load it into userStore
      print('✅ CycleInfo and SubscriptionInfo already exist for phone: $phoneForAPI');
      await userStore.setCycleInfo(existingCycleInfo);
      await userStore.setSubscriptionInfo(existingSubscriptionInfo);
      print('✅ Existing data loaded into userStore');
      return;
    }
    
    // Data doesn't exist - fetch from API
    print('Fetching cycle info and subscription info for authenticated user with phone: $phoneNumber');
    
    // Fetch cycle info
    try {
      final cycleInfo = await getCycleInfoDirectApi(phoneNumber);
      await userStore.setCycleInfo(cycleInfo);
      // Save cycle info to SharedPreferences using phone-specific key only
      await saveCycleInfoForPhone(phoneForAPI, cycleInfo);
      print('Cycle info fetched and saved successfully for phone: $phoneForAPI');
      
      // Schedule cycle stage notifications
      await scheduleCycleStageNotifications();
    } catch (e) {
      print('Error fetching cycle info after login: $e');
      // Continue even if cycle info fails
    }
    
    // Fetch subscription info
    try {
      final subscriptionInfo = await getSubscriptionInfoApi(phoneNumber);
      await userStore.setSubscriptionInfo(subscriptionInfo);
      // Save subscription info to SharedPreferences using phone-specific key only
      await saveSubscriptionInfoForPhone(phoneForAPI, subscriptionInfo);
      print('Subscription info fetched and saved successfully for phone: $phoneForAPI');
    } catch (e) {
      print('Error fetching subscription info after login: $e');
      // Continue even if subscription info fails
    }
  } catch (e) {
    print('Error in _fetchCycleInfoAfterLogin: $e');
    // Don't throw - this is a non-critical operation
  }
}

Future<void> saveUserData(UserModel? userModel) async {
  if (userModel == null) return;
  
  if (userModel.apiToken.validate().isNotEmpty)
    await userStore.setToken(userModel.apiToken.validate());

  await userStore.setToken(userModel.apiToken.validate());
  await userStore.setUserID(userModel.id.validate());
  await userStore.setUserEmail(userModel.email.validate());
  await userStore.setFirstName(userModel.firstName.validate());
  await userStore.setLastName(userModel.lastName.validate());
  
  // Save complete UserModel to SharedPreferences for app restart persistence
  await saveUserToLocalStorage(userModel);
  // Also set in userStore
  await userStore.setUserModelData(userModel);
}

//working
Future<Either<DefaultMessageResponse, UserModel>> registerApi(
    Map<String, dynamic> req) async {
  try {
    final response = await buildHttpResponse(
      'register',
      request: req,
      method: HttpMethod.post,
    );

    final v = await handleResponse(response);
    final responseData = v["responseData"];

    if (responseData['status'] == true) {
      final userModel = UserModel.fromJson(responseData['data']);
      return Right(userModel);
    } else {
      final errorResponse = DefaultMessageResponse.fromJson(responseData);
      return Left(errorResponse);
    }
  } catch (e) {
    // Handle any unexpected errors
    return Left(DefaultMessageResponse(
      status: false,
      message: e.toString(),
    ));
  }
}

//working
Future<UpdateUserModel> updateProfileApi(Map req) async {
  var response = await handleResponse(await buildHttpResponse('update-profile',
      request: req, method: HttpMethod.post));
  response = response['responseData'];

  return UpdateUserModel.fromJson(response);
}

/// Working
///  Backup data API
Future<DefaultMessageResponse> backupUserData(Map req) async {
  var response = await handleResponse(await buildHttpResponse('backup-data',
      method: HttpMethod.post, request: req));
  // response = response['responseData'];

  return DefaultMessageResponse.fromJson(response);
}

/// MANUAL BACKUP
Future<DefaultMessageResponse> manualBackupData(Map req) async {
  var response = await handleResponse(await buildHttpResponse('manual-backup',
      method: HttpMethod.post, request: req));
  // response = response['responseData'];
  return DefaultMessageResponse.fromJson(response);
}

Future<Either<DefaultMessageResponse, BackupRestoreResponse>>
    restoreBackupApi() async {
  try {
    var response = await handleResponse(
        await buildHttpResponse('restore-data', method: HttpMethod.get));

    // final responseData = response['responseData'];
    if (response['status'] == true) {
      return Right(BackupRestoreResponse.fromJson(response));
    } else {
      return Left(DefaultMessageResponse.fromJson(response));
    }
  } catch (e) {
    return Left(DefaultMessageResponse(
      status: false,
      message: 'An error occurred',
    ));
  }
}

//working
Future<void> updateUserStatusApi(Map req) async {
  var id = req["id"];
  await handleResponse(await buildHttpResponse(
    'update-user-status?id=$id',
    request: req,
    method: HttpMethod.post,
  ));
}

//working
Future<BookmarkResponseModel> getBookmarkApi() async {
  var response = await handleResponse(await buildHttpResponse(
      'get-bookmark-articles-list',
      method: HttpMethod.get));
  response = response["responseData"];
  return BookmarkResponseModel.fromJson(response);
}

//working
Future<AddBookmarkResponse> updateBookMarkStatus(Map req) async {
  var response = await handleResponse(await buildHttpResponse(
      'bookmark-articles',
      request: req,
      method: HttpMethod.post));
  response = response['responseData'];
  return AddBookmarkResponse.fromJson(response);
}

//working
Future<List<Symptoms>> AddSubSymptoms() async {
  List<Symptoms> userSymptoms = [];
  var res = await handleResponse(
      await buildHttpResponse('sub-symptoms-list', method: HttpMethod.get));
  res = res['responseData'];
  if (res['data'] != null) {
    res['data'].forEach((v) {
      userSymptoms.add(new Symptoms.fromJson(v));
    });
  }
  return userSymptoms;
}

//not used in app
Future<UserResponse> getUserDetailsApi({int? id}) async {
  var response = await (handleResponse(
      await buildHttpResponse("user-detail?id=$id", method: HttpMethod.get)));
  response = response['responseData'];
  return UserResponse.fromJson(response);
}

//working
/// categorylist
Future<CategoryListResponse> getCategoryListApi({int? id}) async {
  var response = await handleResponse(await buildHttpResponse(
      "category-list?goal_type=$id",
      method: HttpMethod.post));
  response = response['responseData'];
  return CategoryListResponse.fromJson(response);
}

/// categoryData
Future<CategoryDataResponse> getCategoryDetailsApi({int? categoryId}) async {
  var response = await (handleResponse(await buildHttpResponse(
      "get-category-data?category_id=$categoryId",
      method: HttpMethod.get)));
  response = response['responseData'];
  return CategoryDataResponse.fromJson(response);
}

//working
/// Dashboard
Future<DashboardResponse> getDashboardListApi(Map request) async {
  var response = await handleResponse(await buildHttpResponse(
      request: request, "dashboard-list", method: HttpMethod.post));
  response = response['responseData'];
  return DashboardResponse.fromJson(response);
}

//working
///Delete User
Future<DefaultMessageResponse> deleteUserAccountApi() async {
  var response = await handleResponse(
      await buildHttpResponse('delete-user-account', method: HttpMethod.post));
  response = response['responseData'];
  return DefaultMessageResponse.fromJson(response);
}

//working
///Doctor Detail
Future<DoctorResponse> getDoctorDetailsApi() async {
  var response = await handleResponse(
      await buildHttpResponse('doctor-detail', method: HttpMethod.get));
  response = response['responseData'];
  return DoctorResponse.fromJson(response);
}

//working
///Change Password
Future<DefaultMessageResponse> changeHealthExpertPasswordApi(Map req) async {
  var response = await handleResponse(await buildHttpResponse('change-password',
      request: req, method: HttpMethod.post));
  response = response['responseData'];
  return DefaultMessageResponse.fromJson(response);
}

/// Forgot Password                     
Future<DefaultMessageResponse> forgotPasswordApi(Map req) async {
  var response = await handleResponse(await buildHttpResponse('forget-password',
      request: req, method: HttpMethod.post));
  response = response['responseData'];
  return DefaultMessageResponse.fromJson(response);
}

//working
///Doctor Article List
Future<ArticleList> getHealthExpertArticleListApi({int page = 1}) async {
  var response = await handleResponse(await buildHttpResponse(
      'article-list?page=$page',
      method: HttpMethod.get));
  response = response['responseData'];
  return ArticleList.fromJson(response);
}

//working
///DeleteHealthExpert
Future<DefaultMessageResponse> deleteHealthExpertAccountApi() async {
  var response = await handleResponse(
      await buildHttpResponse('delete-user-account', method: HttpMethod.post));
  response = response['responseData'];
  return DefaultMessageResponse.fromJson(response);
}

//working
Future<HealthExpert> getHealthExpertListApi() async {
  var response = await handleResponse(
      await buildHttpResponse('health-expert-list', method: HttpMethod.get));
  response = response['responseData'];
  return HealthExpert.fromJson(response);
}

//working
Future<ArticleResponse> deleteArticleDataApi(int? id) async {
  var response = await handleResponse(
      await buildHttpResponse('article-delete/$id', method: HttpMethod.post));
  response = response['responseData'];
  return ArticleResponse.fromJson(response);
}

//working
///Calculator
Future<CalculatorResponse> fetchCalculatorToolsListApi() async {
  var response = await handleResponse(
      await buildHttpResponse("calculator-tool-list", method: HttpMethod.get));
  response = response['responseData'];
  return CalculatorResponse.fromJson(response);
}

///FAQ
//working
Future<FaqResponse> fetchFAQListApi() async {
  var response = await handleResponse(
      await buildHttpResponse("faq-list", method: HttpMethod.get));
  response = response['responseData'];
  return FaqResponse.fromJson(response);
}

/// Save question to expert
Future<DefaultMessageResponse> saveQuestionToExpertApi(Map req) async {
  var response = await handleResponse(await buildHttpResponse('askexpert-save',
      method: HttpMethod.post, request: req));
  response = response['responseData'];
  return DefaultMessageResponse.fromJson(response);
}

Future<DashboardArticle> DashboardArticleList(Map request,
    {int page = 2}) async {
  String url = 'dashboard-article-list?page=$page';
  var response = await handleResponse(
    await buildHttpResponse(
      url,
      method: HttpMethod.post,
      request: request,
    ),
  );
  return DashboardArticle.fromJson(response);
}

Future<DashboardArticle> TagArticleList(Map request, {int page = 1}) async {
  String url = 'tag-article-list?page=$page';
  var response = await handleResponse(
    await buildHttpResponse(
      url,
      method: HttpMethod.post,
      request: request,
    ),
  );
  return DashboardArticle.fromJson(response);
}

/// Get Expert Question List
Future<ExpertQuestionListModel> getQuestionToExpertApi({int page = 1}) async {
  var response = await handleResponse(await buildHttpResponse(
      "assigndoctor-list?page=$page",
      method: HttpMethod.get));
  response = response['responseData'];
  return ExpertQuestionListModel.fromJson(response);
}

Future<ExpertQuestionListModel> getPendingQuestionToExpertApi(
    {int page = 1}) async {
  var response = await handleResponse(await buildHttpResponse(
      "askexpert-list?page=$page",
      method: HttpMethod.get));
  response = response['responseData'];
  return ExpertQuestionListModel.fromJson(response);
}

Future<DefaultMessageResponse> deleteAskDataApi(int? id) async {
  var response = await handleResponse(
      await buildHttpResponse("askexpert-delete/$id", method: HttpMethod.post));
  response = response['responseData'];
  return DefaultMessageResponse.fromJson(response);
}

Future<DefaultMessageResponse> updateAskDataApi(String? id, Map req) async {
  var response = await handleResponse(await buildHttpResponse(
      "askexpert-update/$id",
      method: HttpMethod.post,
      request: req));
  response = response['responseData'];
  return DefaultMessageResponse.fromJson(response);
}

//working
//reset pin
Future<ResetAppPinModel> resetPinApi(Map req) async {
  var response = await handleResponse(await buildHttpResponse('send-code',
      request: req, method: HttpMethod.post));
  response = response['responseData'];
  return ResetAppPinModel.fromJson(response);
}

/// Clear all cache data including phone-specific user data
/// This is useful for testing the signup/signin process
Future<void> clearAllCacheData() async {
  try {
    print('🧹 Starting cache cleanup...');
    
    // Get all SharedPreferences keys
    Set<String> allKeys = sharedPreferences.getKeys();
    int removedCount = 0;
    
    // Remove all phone-specific user data keys
    for (String key in allKeys) {
      // Remove phone-specific question data keys (question_data_{phone})
      if (key.startsWith(KEY_QUESTION_DATA_PREFIX)) {
        await sharedPreferences.remove(key);
        removedCount++;
        print('Removed: $key');
      }
      // Remove phone-specific cycle info keys (cycle_info_{phone})
      else if (key.startsWith(KEY_CYCLE_INFO_PREFIX)) {
        await sharedPreferences.remove(key);
        removedCount++;
        print('Removed: $key');
      }
      // Remove phone-specific subscription info keys (subscription_info_{phone})
      else if (key.startsWith(KEY_SUBSCRIPTION_INFO_PREFIX)) {
        await sharedPreferences.remove(key);
        removedCount++;
        print('Removed: $key');
      }
      // Remove chat history
      else if (key == 'CHAT_MESSAGES_HISTORY') {
        await sharedPreferences.remove(key);
        removedCount++;
        print('Removed: $key');
      }
    }
    
    // Clear userStore data
    await userStore.setCycleInfo(null);
    await userStore.setSubscriptionInfo(null);
    
    // Clear session cache
    await clearSessionCache();
    
    // Clear ChatGPT cache
    await clearAllChatGptCache();
    
    print('✅ Cache cleanup complete. Removed $removedCount phone-specific keys');
  } catch (e) {
    print('❌ Error clearing cache: $e');
    rethrow;
  }
}

Future<void> clearSessionCache() async {
  final cacheDir = await getTemporaryDirectory();
  final crispCache = Directory('${cacheDir.path}/im.crisp.client');
  if (crispCache.existsSync()) {
    crispCache.deleteSync(recursive: true);
  }

  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('im.crisp.client.internal.cache.Preferences');
}

Future<void> clearAllChatGptCache() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    final chatGptKeys = keys.where((key) =>
    key.startsWith('chatgpt_cycle_') ||
        key.startsWith('chatgpt_pregnancy_'));

    for (final key in chatGptKeys) {
      await prefs.remove(key);
    }
  } catch (e) {
    print('Error clearing ChatGPT cache: $e');
  }
}

/// Get user profile data from QuickShare API via Laravel proxy
/// GET /api/user-profile-data
Future<UserProfileDataModel> getUserProfileData() async {
  try {
    var response = await handleResponse(
      await buildHttpResponse('user-profile-data', method: HttpMethod.get),
    );
    
    response = response['responseData'];
    
    if (response['status'] == true && response['data'] != null) {
      return UserProfileDataModel.fromJson(response['data']);
    } else {
      throw Exception(response['message'] ?? 'Failed to fetch user profile data');
    }
  } catch (e) {
    print('Error fetching user profile data: $e');
    rethrow;
  }
}

Future<void> logout(
    {bool isFromLogin = false, required BuildContext context}) async {
  resetAllReminders();
  await sharedPreferences.remove(IS_LOGIN);
  await sharedPreferences.remove(IS_USER_SIGNED_UP);
  await sharedPreferences.remove(TOKEN);
// await sharedPreferences.remove(QUE_lIST);
  await sharedPreferences.remove(IS_USER_COMPLETED_QUE);
  await sharedPreferences.remove(USER_ID);
  await sharedPreferences.remove(USER_TYPE);
  await sharedPreferences.remove(UID);
  await sharedPreferences.remove(USER_PROFILE_IMG);
  await sharedPreferences.remove(EMAIL);
  await sharedPreferences.remove(FIRSTNAME);
  await sharedPreferences.remove(PASSWORD);
  await sharedPreferences.remove(KEY_PHONE_NUMBER);
  await sharedPreferences.remove(KEY_REMINDER_DATA);
  // Note: KEY_QUESTION_DATA global key removal - no longer used since we use phone-specific keys
  // Phone-specific question data (question_data_{phone}) is preserved during logout
  await sharedPreferences.remove(IS_PASS_LOCK_SET);
  await sharedPreferences.remove(KEY_LAST_KNOWN_APP_LIFECYCLE_STATE);
  await sharedPreferences.remove(KEY_APP_BACKGROUND_TIME);
  await sharedPreferences.remove(IS_FINGERPRINT_LOCK_SET);
  await sharedPreferences.remove(IS_AUTHENTICATED);
  await sharedPreferences.remove(GOAL);
  await sharedPreferences.remove(PASSWORD);
  await sharedPreferences.remove(LAST_DATA_SYNC_DATETIME);
  await sharedPreferences.remove(IS_BACKUP_ENABLED);
  await sharedPreferences.remove(IS_BACKUP_POP_DISPLAYED);
  await sharedPreferences.remove(CURRENT_USER_PREGNANCY_WEEK);
  await sharedPreferences.remove(CURRENT_USER_CYCLE_DAY);
  await sharedPreferences.remove(IS_USER_LOCATION_UPDATED);
  
  // Clear cycle info and subscription info from userStore only (keep phone-specific data in SharedPreferences)
  // User information is preserved during logout - phone-specific keys are not removed
  await userStore.setCycleInfo(null);
  await userStore.setSubscriptionInfo(null);
  
  // Note: We don't remove phone-specific keys (cycle_info_{phone}, subscription_info_{phone}, question_data_{phone})
  // These are preserved so user data persists when they log back in with the same phone number
  
  // Clear all caches
  await clearSessionCache();
  await clearAllChatGptCache();
  
  // Clear Google Sign In if signed in
  if (await GoogleSignIn().isSignedIn()) {
    await GoogleSignIn().signOut();
  }
  
  // Clear user store login state and user data
  userStore.setLogin(false);
  // Note: userStore.user will be cleared on app restart, but we can also clear it here
  // Since app restarts anyway, this is optional but good for consistency
  
  // Full app restart to ensure all cached data is cleared
  await TerminateRestart.instance.restartApp(
    options: const TerminateRestartOptions(
      terminate: true,
    ),
  );
}

Future<void> saveDoctorData(DoctorResponse? doctorData) async {
  await userStore.setDrName(doctorData!.data!.name.validate());
  await userStore.setUserDrEmail(doctorData.data!.email.validate());
  await userStore.setDrCareer(doctorData.data!.career.validate());
  await userStore.setDrExpertise(doctorData.data!.areaExpertise.validate());
  await userStore.setDrTagline(doctorData.data!.tagLine.validate());
  await userStore.setDrAwards(doctorData.data!.awardsAchievements.validate());
  await userStore.setDrDesc(doctorData.data!.shortDescription.validate());
  await userStore.setDrEducation(doctorData.data!.education.validate());
  await userStore
      .setDRprofileImage(doctorData.data!.healthExpertsImage.validate());
}

//working
// Subscribe
Future<DefaultMessageResponse> subscribeForPremium(Map req) async {
  var response = await handleResponse(
    await buildHttpResponse(
      'subscription-save',
      method: HttpMethod.post,
      request: req,
    ),
  );
  response = response['responseData'];
  return DefaultMessageResponse.fromJson(response);
}

// Doctor dashboard
Future<DoctorDashboardResponseData> getDoctorDashboard() async {
  var response = await handleResponse(
      await buildHttpResponse('doctor-dashboard', method: HttpMethod.get));
  response = response['responseData'];
  return DoctorDashboardResponseData.fromJson(response);
}

//working
// Language Data
Future<ServerLanguageResponse> getLanguageList(String? versionNo) async {
  var response = await handleResponse(await buildHttpResponse(
      "language-table-list?version_no=$versionNo",
      method: HttpMethod.get));
  response = response['responseData'];
  return ServerLanguageResponse.fromJson(response);
}

// AppSetting
Future<AppSettings> getAppSettings() async {
  var response = await handleResponse(
          await buildHttpResponse('appsetting', method: HttpMethod.get))
      .then((value) => value);
  var responseData = response['responseData'];
  
  return AppSettings.fromJson(responseData);
}

// Fetch Menstrual Cycle Widget Keys
Future<Map<String, dynamic>?> getMenstrualCycleWidgetKeys() async {
  try {
    var response = await handleResponse(
            await buildHttpResponse('keys/menstrual_cycle_widget', method: HttpMethod.get))
        .then((value) => value);
    var responseData = response['responseData'];
    return responseData;
  } catch (e) {
    log('⚠️ Error fetching MenstrualCycleWidget keys: $e');
    return null;
  }
}

Future<AllCategoryList> fetchAllCategoryApi() async {
  var response = await handleResponse(
    await buildHttpResponse("all-category-list", method: HttpMethod.get),
  );
  return AllCategoryList.fromJson(response);
}

Future<SecretChatResponse> getLatestPost() async {
  var response = await handleResponse(
    await buildHttpResponse("latest-chatlist", method: HttpMethod.get),
  );
  return SecretChatResponse.fromJson(response);
}

Future<SecretChatResponse> deletePostApi(int secretchat_id) async {
  return SecretChatResponse.fromJson(
    await handleResponse(
      await buildHttpResponse(
        'delete-userchat/$secretchat_id',
        method: HttpMethod.post,
      ),
    ),
  );
}

Future<DefaultMessageResponse> likePostApi(Map req) async {
  return DefaultMessageResponse.fromJson(await handleResponse(
      await buildHttpResponse('like-userchat',
          request: req, method: HttpMethod.post)));
}

Future<DefaultMessageResponse> savePostApi(Map req) async {
  return DefaultMessageResponse.fromJson(await handleResponse(
      await buildHttpResponse('bookmark-secretchat',
          request: req, method: HttpMethod.post)));
}

Future<DefaultMessageResponse> followApi(Map req) async {
  return DefaultMessageResponse.fromJson(await handleResponse(
      await buildHttpResponse('follwing-category',
          request: req, method: HttpMethod.post)));
}

Future<DefaultMessageResponse> saveCommentApi(Map req) async {
  return DefaultMessageResponse.fromJson(await handleResponse(
      await buildHttpResponse('save-comment',
          request: req, method: HttpMethod.post)));
}

Future<DefaultMessageResponse> saveReCommentApi(Map req) async {
  return DefaultMessageResponse.fromJson(await handleResponse(
      await buildHttpResponse('save-comment-reply',
          request: req, method: HttpMethod.post)));
}

Future<CommentListResponse> commentListApi(int id, int? page) async {
  return CommentListResponse.fromJson(await handleResponse(
      await buildHttpResponse('comment-list?secretchat_id=$id&page=$page',
          method: HttpMethod.get)));
}

Future<CommentListResponse> deleteReCommentApi(Map req) async {
  return CommentListResponse.fromJson(await handleResponse(
      await buildHttpResponse('delete-comment',
          request: req, method: HttpMethod.post)));
}

Future<CommentListResponse> deleteCommentReplyApi(Map req) async {
  return CommentListResponse.fromJson(await handleResponse(
      await buildHttpResponse('delete-comment-reply',
          request: req, method: HttpMethod.post)));
}

Future<SecretChatResponse> categoryPostApi(Map req) async {
  return SecretChatResponse.fromJson(await handleResponse(
      await buildHttpResponse('category-chatlist',
          request: req, method: HttpMethod.post)));
}

Future<DefaultMessageResponse> updateCommentApi(Map req) async {
  return DefaultMessageResponse.fromJson(await handleResponse(
      await buildHttpResponse('update-comment',
          request: req, method: HttpMethod.post)));
}

Future<DefaultMessageResponse> hidePostApi(Map req) async {
  return DefaultMessageResponse.fromJson(await handleResponse(
      await buildHttpResponse('hide-userchat',
          request: req, method: HttpMethod.post)));
}


/// Get subscription information from QuickShare API directly (without Laravel)
/// Endpoint: https://www.quickshare-apps.com/gateway-quickshare-api/apicyclem/souscription/numero/{phoneNumber}
/// This is a direct call to QuickShare API, not through Laravel proxy
Future<SubscriptionInfoModel> getSubscriptionInfoApi(String phoneNumber) async {
  try {
    // Format phone number (remove + and any non-digit characters)
    String phoneForAPI = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    if (phoneForAPI.isEmpty) {
      throw Exception('Invalid phone number format');
    }

    // Get authentication token
    String authToken;
    try {
      authToken = await authTokenService.getToken();
    } catch (e) {
      throw Exception('Failed to get authentication token: ${e.toString()}');
    }

    // Build API URL
    String apiUrl = 'https://www.quickshare-apps.com/gateway-quickshare-api/apicyclem/souscription/numero/$phoneForAPI';
    final url = Uri.parse(apiUrl);

    print('Calling Subscription Info API: $apiUrl');

    // Make GET request with bearer token
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
    );

    print('Subscription Info API Response - Status: ${response.statusCode}');
    print('Subscription Info API Response - Body: ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      try {
        final responseData = jsonDecode(response.body);
        
        // Handle different response structures
        Map<String, dynamic> subscriptionData;
        if (responseData is Map<String, dynamic>) {
          // If response is wrapped in a data field
          if (responseData.containsKey('data') && responseData['data'] is Map) {
            subscriptionData = responseData['data'] as Map<String, dynamic>;
          } else {
            // Response is the subscription data directly
            subscriptionData = responseData;
          }
        } else {
          throw Exception('Invalid response format: expected Map but got ${responseData.runtimeType}');
        }

        return SubscriptionInfoModel.fromJson(subscriptionData);
      } catch (e) {
        print('Error parsing subscription info response: $e');
        throw Exception('Failed to parse subscription info: ${e.toString()}');
      }
    } else {
      // Error response
      String errorMessage = 'Failed to fetch subscription info';
      try {
        final errorData = jsonDecode(response.body);
        if (errorData is Map && errorData.containsKey('message')) {
          errorMessage = errorData['message'].toString();
        } else if (errorData is Map && errorData.containsKey('error')) {
          errorMessage = errorData['error'].toString();
        }
      } catch (e) {
        // Ignore parsing errors, use default message
      }
      
      // Don't throw USER_NOT_REGISTERED for subscription API - it's expected for new users
      // Just throw a generic exception that will be caught and handled gracefully
      throw Exception('SUBSCRIPTION_API_ERROR: $errorMessage');
    }
  } catch (e) {
    print('Error fetching subscription info: $e');
    rethrow;
  }
}

/// Get current cycle period information from QuickShare API directly (without Laravel)
/// Endpoint: https://www.quickshare-apps.com/gateway-quickshare-api/apicyclem/numeroclient/curperiod/{phoneNumber}
/// This is a direct call to QuickShare API, not through Laravel proxy
Future<CycleInfoModel> getCycleInfoDirectApi(String phoneNumber) async {
  try {
    // Format phone number (remove + and any non-digit characters)
    String phoneForAPI = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    if (phoneForAPI.isEmpty) {
      throw Exception('Invalid phone number format');
    }

    // Get authentication token
    String authToken;
    try {
      authToken = await authTokenService.getToken();
    } catch (e) {
      throw Exception('Failed to get authentication token: ${e.toString()}');
    }

    // Build API URL
    String apiUrl = 'https://www.quickshare-apps.com/gateway-quickshare-api/apicyclem/numeroclient/curperiod/$phoneForAPI';
    final url = Uri.parse(apiUrl);

    print('Calling Cycle Info Direct API: $apiUrl');

    // Make GET request with bearer token
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
    );

    print('Cycle Info Direct API Response - Status: ${response.statusCode}');
    print('Cycle Info Direct API Response - Body: ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      try {
        final responseData = jsonDecode(response.body);
        
        // Handle different response structures
        Map<String, dynamic> cycleData;
        if (responseData is Map<String, dynamic>) {
          // If response is wrapped in a data field
          if (responseData.containsKey('data') && responseData['data'] is Map) {
            cycleData = responseData['data'] as Map<String, dynamic>;
          } else {
            // Response is the cycle data directly
            cycleData = responseData;
          }
        } else {
          throw Exception('Invalid response format: expected Map but got ${responseData.runtimeType}');
        }

        return CycleInfoModel.fromJson(cycleData);
      } catch (e) {
        print('Error parsing cycle info response: $e');
        throw Exception('Failed to parse cycle info: ${e.toString()}');
      }
    } else {
      // Error response
      String errorMessage = 'Failed to fetch cycle info';
      try {
        final errorData = jsonDecode(response.body);
        if (errorData is Map && errorData.containsKey('message')) {
          errorMessage = errorData['message'].toString();
        } else if (errorData is Map && errorData.containsKey('error')) {
          errorMessage = errorData['error'].toString();
        }
      } catch (e) {
        // Ignore parsing errors, use default message
      }
      
      throw Exception('HTTP ${response.statusCode}: $errorMessage');
    }
  } catch (e) {
    print('Error fetching cycle info: $e');
    rethrow;
  }
}

/// Get chat message from QuickShare API
/// Endpoint: https://www.quickshare-apps.com/gateway-quickshare-api/apicyclem/v1/message/chat/{phoneNumber}/{language}
/// Returns a map with 'message' and 'code' fields
Future<Map<String, dynamic>> getChatMessageApi(String phoneNumber, String languageCode) async {
  try {
    // Format phone number (remove + and any non-digit characters)
    String phoneForAPI = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    if (phoneForAPI.isEmpty) {
      throw Exception('Invalid phone number format');
    }

    // Get authentication token
    String authToken;
    try {
      authToken = await authTokenService.getToken();
    } catch (e) {
      throw Exception('Failed to get authentication token: ${e.toString()}');
    }

    // Build API URL
    String apiUrl = 'https://www.quickshare-apps.com/gateway-quickshare-api/apicyclem/v1/message/chat/$phoneForAPI/$languageCode';
    final url = Uri.parse(apiUrl);

    print('Calling Chat Message API: $apiUrl');

    // Make GET request with bearer token
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
    );

    print('Chat Message API Response - Status: ${response.statusCode}');
    print('Chat Message API Response - Body: ${response.body}');

    // Handle 403 Forbidden - token might be expired, try to refresh and retry
    if (response.statusCode == 403) {
      try {
        print('Received 403 (Token expired), attempting to refresh API token...');
        // Clear cached token to force refresh
        await authTokenService.clearToken();
        // Get a fresh token
        authToken = await authTokenService.getToken();
        
        // Retry the request with new token
        print('Retrying Chat Message API with new token: $apiUrl');
        final retryResponse = await http.get(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $authToken',
          },
        );
        
        print('Chat Message API Retry Response - Status: ${retryResponse.statusCode}');
        print('Chat Message API Retry Response - Body: ${retryResponse.body}');
        
        // Use the retry response
        if (retryResponse.statusCode == 200 || retryResponse.statusCode == 201) {
          final responseData = jsonDecode(retryResponse.body);
          
          Map<String, dynamic> chatData;
          if (responseData is Map<String, dynamic>) {
            if (responseData.containsKey('data') && responseData['data'] is Map) {
              chatData = responseData['data'] as Map<String, dynamic>;
            } else {
              chatData = responseData;
            }
          } else {
            throw Exception('Invalid response format: expected Map but got ${responseData.runtimeType}');
          }

          return {
            'message': chatData['message']?.toString() ?? '',
            'code': chatData['code'],
          };
        } else {
          // Still failed after retry
          String errorMessage = 'Failed to fetch chat message after token refresh';
          try {
            final errorData = jsonDecode(retryResponse.body);
            if (errorData is Map && errorData.containsKey('message')) {
              errorMessage = errorData['message'].toString();
            } else if (errorData is Map && errorData.containsKey('error')) {
              errorMessage = errorData['error'].toString();
            }
          } catch (e) {
            // Ignore parsing errors
          }
          
          throw Exception('HTTP ${retryResponse.statusCode}: $errorMessage');
        }
      } catch (e) {
        print('Failed to refresh token and retry: $e');
        throw Exception('Token expired and refresh failed: ${e.toString()}');
      }
    }

    if (response.statusCode == 200 || response.statusCode == 201) {
      try {
        final responseData = jsonDecode(response.body);
        
        // Handle different response structures
        Map<String, dynamic> chatData;
        if (responseData is Map<String, dynamic>) {
          // If response is wrapped in a data field
          if (responseData.containsKey('data') && responseData['data'] is Map) {
            chatData = responseData['data'] as Map<String, dynamic>;
          } else {
            // Response is the chat data directly
            chatData = responseData;
          }
        } else {
          throw Exception('Invalid response format: expected Map but got ${responseData.runtimeType}');
        }

        // Extract message and code
        return {
          'message': chatData['message']?.toString() ?? '',
          'code': chatData['code'],
        };
      } catch (e) {
        print('Error parsing chat message response: $e');
        throw Exception('Failed to parse chat message: ${e.toString()}');
      }
    } else {
      // Error response
      String errorMessage = 'Failed to fetch chat message';
      try {
        final errorData = jsonDecode(response.body);
        if (errorData is Map && errorData.containsKey('message')) {
          errorMessage = errorData['message'].toString();
        } else if (errorData is Map && errorData.containsKey('error')) {
          errorMessage = errorData['error'].toString();
        }
      } catch (e) {
        // Ignore parsing errors, use default message
      }
      
      throw Exception('HTTP ${response.statusCode}: $errorMessage');
    }
  } catch (e) {
    print('Error fetching chat message: $e');
    rethrow;
  }
}

/// Get user transactions from QuickShare API directly (without Laravel)
/// Endpoint: https://www.quickshare-apps.com/gateway-quickshare-api/apicyclem/transaction/ids/{phoneNumber}
/// This is a direct call to QuickShare API, not through Laravel proxy
/// Returns a list of UserTransaction objects
Future<List<UserTransaction>> getUserTransactionsApi(String phoneNumber) async {
  try {
    // Format phone number (remove + and any non-digit characters)
    String phoneForAPI = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    if (phoneForAPI.isEmpty) {
      throw Exception('Invalid phone number format');
    }

    // Get authentication token
    String authToken;
    try {
      authToken = await authTokenService.getToken();
    } catch (e) {
      throw Exception('Failed to get authentication token: ${e.toString()}');
    }

    // Build API URL
    String apiUrl = 'https://www.quickshare-apps.com/gateway-quickshare-api/apicyclem/transaction/ids/$phoneForAPI';
    final url = Uri.parse(apiUrl);

    print('Calling User Transactions API: $apiUrl');

    // Make GET request with bearer token
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
    );

    print('User Transactions API Response - Status: ${response.statusCode}');
    print('User Transactions API Response - Body: ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      try {
        final responseData = jsonDecode(response.body);
        
        // Handle different response structures
        List<dynamic> transactionsList;
        if (responseData is List) {
          // Response is directly a list
          transactionsList = responseData;
        } else if (responseData is Map<String, dynamic>) {
          // If response is wrapped in a data field
          if (responseData.containsKey('data') && responseData['data'] is List) {
            transactionsList = responseData['data'] as List<dynamic>;
          } else if (responseData.containsKey('transactions') && responseData['transactions'] is List) {
            transactionsList = responseData['transactions'] as List<dynamic>;
          } else {
            // Try to find any list in the response
            var listValue = responseData.values.firstWhere(
              (value) => value is List,
              orElse: () => [],
            );
            transactionsList = listValue is List ? listValue : [];
          }
        } else {
          throw Exception('Invalid response format: expected List or Map but got ${responseData.runtimeType}');
        }

        // Convert list of JSON to list of UserTransaction
        List<UserTransaction> transactions = transactionsList
            .map((json) => UserTransaction.fromJson(json as Map<String, dynamic>))
            .toList();

        return transactions;
      } catch (e) {
        print('Error parsing user transactions response: $e');
        throw Exception('Failed to parse user transactions: ${e.toString()}');
      }
    } else {
      // Error response
      String errorMessage = 'Failed to fetch user transactions';
      try {
        final errorData = jsonDecode(response.body);
        if (errorData is Map && errorData.containsKey('message')) {
          errorMessage = errorData['message'].toString();
        } else if (errorData is Map && errorData.containsKey('error')) {
          errorMessage = errorData['error'].toString();
        }
      } catch (e) {
        // Ignore parsing errors, use default message
      }
      
      throw Exception('HTTP ${response.statusCode}: $errorMessage');
    }
  } catch (e) {
    print('Error fetching user transactions: $e');
    rethrow;
  }
}

/// Get payment status from QuickShare API directly (without Laravel)
/// Endpoint: https://www.quickshare-apps.com/gateway-quickshare-api/apicyclem/paiement/ids/{phoneNumber}
/// This is a direct call to QuickShare API, not through Laravel proxy
/// Returns PaymentStatusModel with message and code
Future<PaymentStatusModel> getPaymentStatusApi(String phoneNumber) async {
  try {
    // Format phone number (remove + and any non-digit characters)
    String phoneForAPI = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    if (phoneForAPI.isEmpty) {
      throw Exception('Invalid phone number format');
    }

    // Get authentication token
    String authToken;
    try {
      authToken = await authTokenService.getToken();
    } catch (e) {
      throw Exception('Failed to get authentication token: ${e.toString()}');
    }

    // Build API URL
    String apiUrl = 'https://www.quickshare-apps.com/gateway-quickshare-api/apicyclem/paiement/ids/$phoneForAPI';
    final url = Uri.parse(apiUrl);

    print('Calling Payment Status API: $apiUrl');

    // Make GET request with bearer token
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
    );

    print('Payment Status API Response - Status: ${response.statusCode}');
    print('Payment Status API Response - Body: ${response.body}');

    // Try to parse response body for any status code (including 403)
    try {
      final responseData = jsonDecode(response.body);
      
      // Handle different response structures
      Map<String, dynamic> paymentData;
      if (responseData is Map<String, dynamic>) {
        // If response is wrapped in a data field
        if (responseData.containsKey('data') && responseData['data'] is Map) {
          paymentData = responseData['data'] as Map<String, dynamic>;
        } else {
          // Response is the payment data directly
          paymentData = responseData;
        }
      } else {
        // If not a Map, only proceed if status is 200/201
        if (response.statusCode == 200 || response.statusCode == 201) {
          throw Exception('Invalid response format: expected Map but got ${responseData.runtimeType}');
        } else {
          // For error status codes, throw exception if body is not parseable
          throw Exception('Invalid response format for error status');
        }
      }

      // Check if code is "300" (payment inactive)
      // If so, return PaymentStatusModel even for 403 or other error status codes
      String? codeValue = paymentData['code']?.toString();
      if (codeValue == "300") {
        print('⚠️ Payment inactive (code 300) detected, returning PaymentStatusModel even for status ${response.statusCode}');
        return PaymentStatusModel.fromJson(paymentData);
      }

      // For 200/201 status codes, always return the model
      if (response.statusCode == 200 || response.statusCode == 201) {
        return PaymentStatusModel.fromJson(paymentData);
      }

      // For other status codes and non-300 codes, throw exception
      String errorMessage = 'Failed to fetch payment status';
      if (paymentData.containsKey('message')) {
        errorMessage = paymentData['message'].toString();
      } else if (paymentData.containsKey('error')) {
        errorMessage = paymentData['error'].toString();
      }
      
      throw Exception('HTTP ${response.statusCode}: $errorMessage');
    } catch (e) {
      // If parsing failed and status is not 200/201, throw error
      if (response.statusCode != 200 && response.statusCode != 201) {
        // Re-throw parsing errors for non-200 status codes (unless it was already an Exception from above)
        if (e is Exception && !e.toString().contains('HTTP')) {
          // Try to extract error message from response body if possible
          String errorMessage = 'Failed to fetch payment status';
          try {
            final errorData = jsonDecode(response.body);
            if (errorData is Map && errorData.containsKey('message')) {
              errorMessage = errorData['message'].toString();
            } else if (errorData is Map && errorData.containsKey('error')) {
              errorMessage = errorData['error'].toString();
            }
          } catch (parseError) {
            // Ignore parsing errors, use default message
          }
          throw Exception('HTTP ${response.statusCode}: $errorMessage');
        }
        rethrow;
      }
      
      // For 200/201 status codes, throw parsing error
      print('Error parsing payment status response: $e');
      throw Exception('Failed to parse payment status: ${e.toString()}');
    }
  } catch (e) {
    print('Error fetching payment status: $e');
    rethrow;
  }
}

/// Get payment plans/amounts from QuickShare API directly (without Laravel)
/// Endpoint: https://www.quickshare-apps.com/gateway-quickshare-api/apicyclem/paiement/montants/{currency}
/// This is a direct call to QuickShare API, not through Laravel proxy
/// Returns a list of PaymentPlanModel objects
/// currency: Currency code (e.g., "USD", "EUR", etc.)
Future<List<PaymentPlanModel>> getPaymentPlansApi(String currency) async {
  try {
    // Validate currency code
    if (currency.isEmpty) {
      currency = 'USD'; // Default to USD
    }
    
    // Uppercase currency code
    currency = currency.toUpperCase();

    // Get authentication token
    String authToken;
    try {
      authToken = await authTokenService.getToken();
    } catch (e) {
      throw Exception('Failed to get authentication token: ${e.toString()}');
    }

    // Build API URL
    String apiUrl = 'https://www.quickshare-apps.com/gateway-quickshare-api/apicyclem/paiement/montants/$currency';
    final url = Uri.parse(apiUrl);

    print('Calling Payment Plans API: $apiUrl');

    // Make GET request with bearer token
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
    );

    print('Payment Plans API Response - Status: ${response.statusCode}');
    print('Payment Plans API Response - Body: ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      try {
        final responseData = jsonDecode(response.body);
        
        // Handle different response structures
        List<dynamic> plansList;
        if (responseData is List) {
          // Response is directly a list
          plansList = responseData;
        } else if (responseData is Map<String, dynamic>) {
          // If response is wrapped in a data field
          if (responseData.containsKey('data') && responseData['data'] is List) {
            plansList = responseData['data'] as List<dynamic>;
          } else if (responseData.containsKey('plans') && responseData['plans'] is List) {
            plansList = responseData['plans'] as List<dynamic>;
          } else {
            // Try to find any list in the response
            var listValue = responseData.values.firstWhere(
              (value) => value is List,
              orElse: () => [],
            );
            plansList = listValue is List ? listValue : [];
          }
        } else {
          throw Exception('Invalid response format: expected List or Map but got ${responseData.runtimeType}');
        }

        // Convert list of JSON to list of PaymentPlanModel
        List<PaymentPlanModel> plans = plansList
            .map((json) => PaymentPlanModel.fromJson(json as Map<String, dynamic>))
            .toList();

        print('✅ Fetched ${plans.length} payment plans for currency: $currency');
        return plans;
      } catch (e) {
        print('Error parsing payment plans response: $e');
        throw Exception('Failed to parse payment plans: ${e.toString()}');
      }
    } else {
      // Error response
      String errorMessage = 'Failed to fetch payment plans';
      try {
        final errorData = jsonDecode(response.body);
        if (errorData is Map && errorData.containsKey('message')) {
          errorMessage = errorData['message'].toString();
        } else if (errorData is Map && errorData.containsKey('error')) {
          errorMessage = errorData['error'].toString();
        }
      } catch (e) {
        // Ignore parsing errors, use default message
      }
      
      throw Exception('HTTP ${response.statusCode}: $errorMessage');
    }
  } catch (e) {
    print('Error fetching payment plans: $e');
    rethrow;
  }
}

/// Get Stripe configuration from QuickShare API
/// Endpoint: https://www.quickshare-apps.com/gateway-quickshare-api/stripe/config
/// Returns StripeConfigModel containing the publishable key
Future<StripeConfigModel> getStripeConfigApi() async {
  try {
    // Get authentication token
    String authToken;
    try {
      authToken = await authTokenService.getToken();
    } catch (e) {
      throw Exception('Failed to get authentication token: ${e.toString()}');
    }

    // Build API URL
    String apiUrl = 'https://www.quickshare-apps.com/gateway-quickshare-api/stripe/config';
    final url = Uri.parse(apiUrl);

    print('Calling Stripe Config API: $apiUrl');

    // Make GET request with bearer token
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
    );

    print('Stripe Config API Response - Status: ${response.statusCode}');
    print('Stripe Config API Response - Body: ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      try {
        final responseData = jsonDecode(response.body);
        
        print('📋 Raw API Response: $responseData');
        
        // Handle different response structures
        Map<String, dynamic> configData;
        if (responseData is Map<String, dynamic>) {
          // If response is wrapped in a data field
          if (responseData.containsKey('data') && responseData['data'] is Map) {
            configData = responseData['data'] as Map<String, dynamic>;
            print('📦 Found data wrapper, extracted: $configData');
          } else {
            // Response is the config data directly
            configData = responseData;
            print('📦 Using response directly: $configData');
          }
        } else {
          throw Exception('Invalid response format: expected Map but got ${responseData.runtimeType}');
        }

        // Try to find publishable key with different possible field names
        String? publishableKey;
        if (configData.containsKey('publishableKey')) {
          publishableKey = configData['publishableKey']?.toString();
          print('✅ Found publishableKey field');
        } else {
          print('⚠️  Available keys in response: ${configData.keys.toList()}');
          throw Exception('Publishable key not found in response. Available keys: ${configData.keys.toList()}');
        }

        if (publishableKey == null || publishableKey.isEmpty) {
          throw Exception('Publishable key is null or empty');
        }

        print('✅ Extracted publishable key (length: ${publishableKey.length}): ${publishableKey.length > 20 ? publishableKey.substring(0, 20) + "..." : publishableKey}');

        StripeConfigModel config = StripeConfigModel(
          publishableKey: publishableKey,
        );
        print('✅ Created StripeConfigModel successfully');
        return config;
      } catch (e) {
        print('Error parsing Stripe config response: $e');
        throw Exception('Failed to parse Stripe config: ${e.toString()}');
      }
    } else {
      // Error response
      String errorMessage = 'Failed to fetch Stripe config';
      try {
        final errorData = jsonDecode(response.body);
        if (errorData is Map && errorData.containsKey('message')) {
          errorMessage = errorData['message'].toString();
        } else if (errorData is Map && errorData.containsKey('error')) {
          errorMessage = errorData['error'].toString();
        }
      } catch (e) {
        // Ignore parsing errors, use default message
      }
      
      throw Exception('HTTP ${response.statusCode}: $errorMessage');
    }
  } catch (e) {
    print('Error fetching Stripe config: $e');
    rethrow;
  }
}

/// Create Stripe customer via QuickShare API
/// Endpoint: POST https://www.quickshare-apps.com/gateway-quickshare-api/stripe/create-customer
/// Returns StripeCustomerModel containing the customer ID
Future<StripeCustomerModel> createStripeCustomerApi({
  required String name,
  required String email,
  required String phone,
  required String description,
}) async {
  try {
    // Get authentication token
    String authToken;
    try {
      authToken = await authTokenService.getToken();
    } catch (e) {
      throw Exception('Failed to get authentication token: ${e.toString()}');
    }

    // Build API URL
    String apiUrl = 'https://www.quickshare-apps.com/gateway-quickshare-api/stripe/create-customer';
    final url = Uri.parse(apiUrl);

    print('Calling Stripe Create Customer API: $apiUrl');
    print('Request body: {name: $name, email: $email, phone: $phone, description: $description}');

    // Prepare request body
    final requestBody = jsonEncode({
      'name': name,
      'email': email,
      'phone': phone,
      'description': description,
    });

    // Make POST request with bearer token
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: requestBody,
    );

    print('Stripe Create Customer API Response - Status: ${response.statusCode}');
    print('Stripe Create Customer API Response - Body: ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      try {
        final responseData = jsonDecode(response.body);
        
        print('📋 Raw API Response: $responseData');
        
        // Handle different response structures
        Map<String, dynamic> customerData;
        if (responseData is Map<String, dynamic>) {
          // If response is wrapped in a data field
          if (responseData.containsKey('data') && responseData['data'] is Map) {
            customerData = responseData['data'] as Map<String, dynamic>;
            print('📦 Found data wrapper, extracted: $customerData');
          } else {
            // Response is the customer data directly
            customerData = responseData;
            print('📦 Using response directly: $customerData');
          }
        } else {
          throw Exception('Invalid response format: expected Map but got ${responseData.runtimeType}');
        }

        // Extract customer ID
        String? customerId;
        if (customerData.containsKey('customer')) {
          customerId = customerData['customer']?.toString();
          print('✅ Found customer field');
        } else {
          print('⚠️  Available keys in response: ${customerData.keys.toList()}');
          throw Exception('Customer ID not found in response. Available keys: ${customerData.keys.toList()}');
        }

        if (customerId == null || customerId.isEmpty) {
          throw Exception('Customer ID is null or empty');
        }

        print('✅ Extracted customer ID: $customerId');

        StripeCustomerModel customer = StripeCustomerModel(
          customer: customerId,
        );
        print('✅ Created StripeCustomerModel successfully');
        return customer;
      } catch (e) {
        print('Error parsing Stripe customer response: $e');
        throw Exception('Failed to parse Stripe customer response: ${e.toString()}');
      }
    } else {
      // Error response
      String errorMessage = 'Failed to create Stripe customer';
      try {
        final errorData = jsonDecode(response.body);
        if (errorData is Map && errorData.containsKey('message')) {
          errorMessage = errorData['message'].toString();
        } else if (errorData is Map && errorData.containsKey('error')) {
          errorMessage = errorData['error'].toString();
        }
      } catch (e) {
        // Ignore parsing errors, use default message
      }
      
      throw Exception('HTTP ${response.statusCode}: $errorMessage');
    }
  } catch (e) {
    print('Error creating Stripe customer: $e');
    rethrow;
  }
}

/// Create Stripe setup-intent + payment method context via Cycle Menstruel API
/// Endpoint: POST https://mobile.cycle-menstruel.com/api/stripe/setup-intent/payment-method
/// Uses current user's Laravel Sanctum token in Authorization header.
Future<StripeSetupIntentPaymentMethodModel> createStripeSetupIntentPaymentMethodApi({
  required String name,
  required String email,
  required String phone,
}) async {
  try {
    final String sanctumToken = userStore.token.trim();
    if (sanctumToken.isEmpty) {
      throw Exception('Sanctum token not available for current user');
    }

    const String apiUrl =
        'https://mobile.cycle-menstruel.com/api/stripe/setup-intent';
    final Uri url = Uri.parse(apiUrl);

    final String requestBody = jsonEncode({
      'name': name,
      'email': email,
      'phone': phone,
    });

    print('Calling Stripe Setup Intent Payment Method API: $apiUrl');
    print('Request body: $requestBody');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $sanctumToken',
      },
      body: requestBody,
    );

    print(
        'Stripe Setup Intent Payment Method API Response - Status: ${response.statusCode}');
    print(
        'Stripe Setup Intent Payment Method API Response - Body: ${response.body}');

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception(
          'Invalid response format: expected Map but got ${decoded.runtimeType}');
    }

    if (response.statusCode == 200 || response.statusCode == 201) {
      final model = StripeSetupIntentPaymentMethodModel.fromJson(decoded);
      if (!model.status) {
        throw Exception('Setup intent API returned status=false');
      }
      if (model.data.customerId.isEmpty || model.data.clientSecret.isEmpty) {
        throw Exception(
            'Missing required setup intent fields (customerId/clientSecret)');
      }
      return model;
    } else {
      String errorMessage = 'Failed to create setup intent payment method';
      if (decoded['message'] != null) {
        errorMessage = decoded['message'].toString();
      } else if (decoded['error'] != null) {
        errorMessage = decoded['error'].toString();
      }
      throw Exception('HTTP ${response.statusCode}: $errorMessage');
    }
  } catch (e) {
    print('Error creating setup intent payment method: $e');
    rethrow;
  }
}

/// Create Stripe subscription via QuickShare API
/// Endpoint: POST https://www.quickshare-apps.com/gateway-quickshare-api/stripe/create-subscription
/// Request body: { "customerId": "...", "priceId": "...", "paymentMethodId": "..." }
/// Returns: { "clientSecret": "pi_xxx_secret_xxx" }
Future<Map<String, dynamic>> createStripeSubscriptionApi({
  required String customerId,
  required String priceId,
  required String paymentMethodId,
}) async {
  try {
    String authToken;
    try {
      authToken = await authTokenService.getToken();
    } catch (e) {
      throw Exception('Failed to get authentication token: ${e.toString()}');
    }

    String apiUrl = 'https://www.quickshare-apps.com/gateway-quickshare-api/stripe/create-subscription';
    final url = Uri.parse(apiUrl);

    final requestBody = jsonEncode({
      'customerId': customerId,
      'priceId': priceId,
      'paymentMethodId': paymentMethodId,
    });

    print('Calling Stripe Create Subscription API: $apiUrl');
    print('Request body: $requestBody');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: requestBody,
    );

    print('Stripe Create Subscription API Response - Status: ${response.statusCode}');
    print('Stripe Create Subscription API Response - Body: ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      try {
        final responseData = jsonDecode(response.body);
        if (responseData is! Map<String, dynamic>) {
          throw Exception('Invalid response format: expected Map but got ${responseData.runtimeType}');
        }
        String? clientSecret = responseData['clientSecret']?.toString();
        if (clientSecret == null || clientSecret.isEmpty) {
          throw Exception('clientSecret not found in response');
        }
        return {'clientSecret': clientSecret};
      } catch (e) {
        print('Error parsing Stripe create-subscription response: $e');
        throw Exception('Failed to parse create-subscription response: ${e.toString()}');
      }
    } else {
      String errorMessage = 'Failed to create Stripe subscription';
      try {
        final errorData = jsonDecode(response.body);
        if (errorData is Map && errorData.containsKey('message')) {
          errorMessage = errorData['message'].toString();
        } else if (errorData is Map && errorData.containsKey('error')) {
          errorMessage = errorData['error'].toString();
        }
      } catch (e) {
        // Ignore parsing errors
      }
      throw Exception('HTTP ${response.statusCode}: $errorMessage');
    }
  } catch (e) {
    print('Error creating Stripe subscription: $e');
    rethrow;
  }
}

/// Create Stripe subscription via Cycle Menstruel Laravel API (Sanctum token)
/// Endpoint: POST https://mobile.cycle-menstruel.com/api/quickshare/stripe/create-subscription
/// Request body: { "customerId": "...", "priceId": "...", "paymentMethodId": "..." }
Future<QuickshareStripeSubscriptionModel> createQuickshareStripeSubscriptionApi({
  required String customerId,
  required String priceId,
  required String paymentMethodId,
}) async {
  try {
    final String sanctumToken = userStore.token.trim();
    if (sanctumToken.isEmpty) {
      throw Exception('Sanctum token not available for current user');
    }

    const String apiUrl =
        'https://mobile.cycle-menstruel.com/api/quickshare/stripe/create-subscription';
    final Uri url = Uri.parse(apiUrl);

    final String requestBody = jsonEncode({
      'customerId': customerId,
      'priceId': priceId,
      'paymentMethodId': paymentMethodId,
    });

    print('Calling Quickshare Stripe Create Subscription API: $apiUrl');
    print('Request body: $requestBody');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $sanctumToken',
      },
      body: requestBody,
    );

    print(
        'Quickshare Stripe Create Subscription API Response - Status: ${response.statusCode}');
    print(
        'Quickshare Stripe Create Subscription API Response - Body: ${response.body}');

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception(
          'Invalid response format: expected Map but got ${decoded.runtimeType}');
    }

    if (response.statusCode == 200 || response.statusCode == 201) {
      final model = QuickshareStripeSubscriptionModel.fromJson(decoded);
      if (!model.status) {
        throw Exception('Quickshare create-subscription returned status=false');
      }
      if (model.data.clientSecret.isEmpty) {
        throw Exception('clientSecret not found in response');
      }
      return model;
    }

    String errorMessage = 'Failed to create Quickshare Stripe subscription';
    if (decoded['message'] != null) {
      errorMessage = decoded['message'].toString();
    } else if (decoded['error'] != null) {
      errorMessage = decoded['error'].toString();
    }
    throw Exception('HTTP ${response.statusCode}: $errorMessage');
  } catch (e) {
    print('Error creating Quickshare Stripe subscription: $e');
    rethrow;
  }
}

/// Load QuestionData for a specific phone number
/// Returns null if not found
QuestionsModel? loadQuestionDataForPhone(String phoneNumber) {
  try {
    String key = getQuestionDataKeyForPhone(phoneNumber);
    Map<String, dynamic> questionData = getJSONAsync(key);
    
    if (questionData.isNotEmpty) {
      return QuestionsModel.fromJson(questionData);
    }
    return null;
  } catch (e) {
    print('Error loading question data for phone $phoneNumber: $e');
    return null;
  }
}

/// Save QuestionData for a specific phone number
Future<void> saveQuestionDataForPhone(String phoneNumber, QuestionsModel questionsModel) async {
  try {
    String key = getQuestionDataKeyForPhone(phoneNumber);
    await setValue(key, questionsModel.toJson());
    print('QuestionData saved for phone: $phoneNumber');
  } catch (e) {
    print('Error saving question data for phone $phoneNumber: $e');
    rethrow;
  }
}

/// Save QuestionData to phone-specific key only (if user is logged in and has phone number)
/// Never saves to global key - all user data is phone-specific
Future<void> saveQuestionDataUniversal(QuestionsModel questionsModel) async {
  try {
    // Only save to phone-specific key if user is logged in and has phone number
    if (userStore.isLoggedIn && userStore.user?.phoneNumber != null) {
      String phoneNumber = userStore.user!.phoneNumber!;
      String phoneForAPI = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
      if (phoneForAPI.isNotEmpty) {
        await saveQuestionDataForPhone(phoneForAPI, questionsModel);
        print('✅ QuestionsModel saved via saveQuestionDataUniversal for phone: $phoneForAPI');
      } else {
        print('⚠️ Cannot save questionsModel: phone number is empty after cleaning');
      }
    } else {
      print('⚠️ Cannot save questionsModel: user not logged in or phone number not available');
    }
  } catch (e) {
    print('Error saving question data: $e');
    rethrow;
  }
}

/// Load CycleInfo for a specific phone number
/// Returns null if not found
CycleInfoModel? loadCycleInfoForPhone(String phoneNumber) {
  try {
    String key = getCycleInfoKeyForPhone(phoneNumber);
    Map<String, dynamic> cycleInfoData = getJSONAsync(key);
    
    if (cycleInfoData.isNotEmpty) {
      return CycleInfoModel.fromJson(cycleInfoData);
    }
    return null;
  } catch (e) {
    print('Error loading cycle info for phone $phoneNumber: $e');
    return null;
  }
}

/// Save CycleInfo for a specific phone number
Future<void> saveCycleInfoForPhone(String phoneNumber, CycleInfoModel cycleInfo) async {
  try {
    String key = getCycleInfoKeyForPhone(phoneNumber);
    await setValue(key, cycleInfo.toJson());
    print('CycleInfo saved for phone: $phoneNumber');
  } catch (e) {
    print('Error saving cycle info for phone $phoneNumber: $e');
    rethrow;
  }
}

/// Load SubscriptionInfo for a specific phone number
/// Returns null if not found
SubscriptionInfoModel? loadSubscriptionInfoForPhone(String phoneNumber) {
  try {
    String key = getSubscriptionInfoKeyForPhone(phoneNumber);
    Map<String, dynamic> subscriptionInfoData = getJSONAsync(key);
    
    if (subscriptionInfoData.isNotEmpty) {
      return SubscriptionInfoModel.fromJson(subscriptionInfoData);
    }
    return null;
  } catch (e) {
    print('Error loading subscription info for phone $phoneNumber: $e');
    return null;
  }
}

/// Save SubscriptionInfo for a specific phone number
Future<void> saveSubscriptionInfoForPhone(String phoneNumber, SubscriptionInfoModel subscriptionInfo) async {
  try {
    String key = getSubscriptionInfoKeyForPhone(phoneNumber);
    await setValue(key, subscriptionInfo.toJson());
    print('SubscriptionInfo saved for phone: $phoneNumber');
  } catch (e) {
    print('Error saving subscription info for phone $phoneNumber: $e');
    rethrow;
  }
}

/// Convert date from DD-MM-YYYY format to YYYY-MM-DD format
String convertDateToAppFormat(String dateString) {
  if (dateString.isEmpty) return "";
  
  try {
    // Try parsing DD-MM-YYYY format
    List<String> parts = dateString.split('-');
    if (parts.length == 3) {
      String day = parts[0].padLeft(2, '0');
      String month = parts[1].padLeft(2, '0');
      String year = parts[2];
      
      // Convert to YYYY-MM-DD format (ISO format)
      return '$year-$month-$day';
    }
  } catch (e) {
    print('Error converting date format: $e');
  }
  
  // Return as-is if conversion fails
  return dateString;
}

/// Create a new QuestionsModel from SubscriptionInfoModel with defaults
QuestionsModel createQuestionDataFromSubscription({
  required SubscriptionInfoModel subscriptionInfo,
  required String phoneNumber,
  String? countryCode,
}) {
  // Step 1: Using Era - Set to option for user (not doctor)
  // Option 0 = "Yes, for tracking" (user option)
  Step1 newStep1 = Step1(
    title: "${language.areYouUsing} CycleM ${language.forYourself} ?",
    options: ["${language.yesForTracking}. ", "${language.yesAsADoctor}."],
    selectedOption: 0, // User option (not doctor)
    isConfirm: true,
    isSkip: false,
  );

  // Step 2: Goal Type - Use default (Track Cycle)
  Step2 newStep2 = Step2(
    title: "${language.whatIsYourGoalType}?",
    desc: "${language.allFeatureswWillBeAvailable}",
    options: [
      GoalTypeModel(
        img: ic_track_cycle,
        title: "${language.trackCycle}",
        desc: "${language.stayPreparedForYourNextPeriod}."),
      GoalTypeModel(
        img: ic_track_pregnancy,
        title: "${language.trackPregnancy}",
        desc: "${language.monitorChangesInYourBody}.")
    ],
    selectedOption: 0, // Default: Track Cycle
    isConfirm: true,
    isSkip: false,
  );

  // Step 2 Phone: Set phone number and mark as verified
  Step2Phone newStep2Phone = Step2Phone(
    phoneNumber: phoneNumber.replaceAll(RegExp(r'[^\d]'), ''),
    countryCode: countryCode ?? "+243",
    verificationId: null,
    isVerified: true, // Already verified through login
    otpCode: null,
  );

  // Step 3 Personal Info: Use data from SubscriptionInfoModel
  Step3PersonalInfo newStep3PersonalInfo = Step3PersonalInfo(
    fullName: subscriptionInfo.nomClient.isNotEmpty 
        ? subscriptionInfo.nomClient 
        : null,
    email: subscriptionInfo.emailClient.isNotEmpty 
        ? subscriptionInfo.emailClient 
        : null,
    isCompleted: true,
  );

  // Step 4 Questions: Use "yes", "yes", "no" as specified
  Step4Question1 newStep4Question1 = Step4Question1(
    question: "Do you have any existing health conditions?",
    answer: true, // "yes"
    isCompleted: true,
  );

  Step4Question2 newStep4Question2 = Step4Question2(
    question: "Are you currently taking any medications?",
    answer: true, // "yes"
    isCompleted: true,
  );

  Step4Question3 newStep4Question3 = Step4Question3(
    question: "Have you consulted a doctor about your cycle recently?",
    answer: false, // "no"
    isCompleted: true,
  );

  // Step 3: Period Information - Use dateDernierRegles from SubscriptionInfoModel
  String periodDate = subscriptionInfo.dateDernierRegles.isNotEmpty
      ? convertDateToAppFormat(subscriptionInfo.dateDernierRegles)
      : ""; // Empty if not available (user can skip)

  Step3 newStep3 = Step3(
    title: "${language.whenDidYourLastPeriod}",
    desc: "${language.provideThisInformationSoThatWeCanPredict}.",
    selectedLastPeriodDate: periodDate,
    isSkip: periodDate.isEmpty, // Skip if no date available
    isConfirm: periodDate.isNotEmpty,
  );

  // Step 4: Cycle Length - Use default
  Step4 newStep4 = Step4(
    title: "${language.whatIsYourCycleLength} ?",
    cycleLengthList: getCycleLengthList(),
    selectedOption: DEFAULT_CYCLE_LENGTH, // Default: 28 days
    isConfirm: true,
    isSkip: false,
  );

  // Step 5: Period Duration - Use default
  Step5 newStep5 = Step5(
    title: "${language.whatIsYourPeriodDuration} ?",
    desc: "${language.whatIsYourPeriodDurationDescription}.",
    periodLengthList: getPeriodLengthList(),
    selectedOption: DEFAULT_PERIOD_LENGTH, // Default: 5 days
    isConfirm: true,
    isSkip: false,
  );

  // Step 6: Luteal Phase - Use default (skip, selectedOption = -1)
  Step6 newStep6 = Step6(
    title: "What is Luteal Phase?",
    desc: "The luteal phase is the duration between ovulation and the start of your period. Logging its length helps improve the accuracy of ovulation predictions.",
    lutealLengthList: getLutealLengthList(),
    selectedOption: -1, // Not selected (skipped)
    isConfirm: false,
    isSkip: true,
  );

  // Step 7: Additional Information - Use defaults (skip)
  Step7 newStep7 = Step7(
    title: "Complete Your Profile",
    desc: "Help us personalize your experience by providing your age",
    question1: null,
    question2: "What year were you born?",
    answerToQuestion1: null,
    answerToQuestion2: null,
    confirm: false,
    skip: true,
  );

  // Create and return the complete QuestionsModel
  return QuestionsModel(
    step1: newStep1,
    step2: newStep2,
    step2Phone: newStep2Phone,
    step3PersonalInfo: newStep3PersonalInfo,
    step4Question1: newStep4Question1,
    step4Question2: newStep4Question2,
    step4Question3: newStep4Question3,
    step3: newStep3,
    step4: newStep4,
    step5: newStep5,
    step6: newStep6,
    step7: newStep7,
  );
}

/// Get authentication code from QuickShare API
/// Endpoint: https://www.quickshare-apps.com/gateway-quickshare-api/apicyclem/numeroclient/{phoneNumber}
/// Returns a five-digit number as a string
/// This is a direct call to QuickShare API, not through Laravel proxy
Future<String> autenticationCode(String phoneNumber) async {
  try {
    // Format phone number (remove + and any non-digit characters)
    String phoneForAPI = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    if (phoneForAPI.isEmpty) {
      throw Exception('Invalid phone number format');
    }

    // Get authentication token
    String authToken;
    try {
      authToken = await authTokenService.getToken();
    } catch (e) {
      throw Exception('Failed to get authentication token: ${e.toString()}');
    }

    // Build API URL
    String apiUrl = 'https://www.quickshare-apps.com/gateway-quickshare-api/apicyclem/numeroclient/$phoneForAPI';
    final url = Uri.parse(apiUrl);

    print('Calling Authentication Code API: $apiUrl');

    // Make GET request with bearer token
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
    );

    print('Authentication Code API Response - Status: ${response.statusCode}');
    print('Authentication Code API Response - Body: ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      try {
        // The response body should contain a five-digit number
        String code = response.body.trim();
        
        // Validate that it's a five-digit number
        if (code.length == 5 && RegExp(r'^\d{5}$').hasMatch(code)) {
          print('✅ Successfully retrieved authentication code: $code');
          return code;
        } else {
          // Try to parse as JSON in case the response is wrapped
          try {
            final responseData = jsonDecode(response.body);
            if (responseData is Map<String, dynamic>) {
              // Check common field names for the code
              if (responseData.containsKey('code')) {
                code = responseData['code'].toString().trim();
              } else if (responseData.containsKey('data')) {
                code = responseData['data'].toString().trim();
              } else if (responseData.containsKey('authenticationCode')) {
                code = responseData['authenticationCode'].toString().trim();
              } else {
                // Try to find any 5-digit value in the response
                for (var value in responseData.values) {
                  String valueStr = value.toString().trim();
                  if (valueStr.length == 5 && RegExp(r'^\d{5}$').hasMatch(valueStr)) {
                    code = valueStr;
                    break;
                  }
                }
              }
            } else if (responseData is String) {
              code = responseData.trim();
            }
            
            // Validate the extracted code
            if (code.length == 5 && RegExp(r'^\d{5}$').hasMatch(code)) {
              print('✅ Successfully extracted authentication code: $code');
              return code;
            }
          } catch (e) {
            print('Error parsing JSON response: $e');
          }
          
          throw Exception('Invalid authentication code format: expected 5 digits but got "$code"');
        }
      } catch (e) {
        print('Error parsing authentication code response: $e');
        throw Exception('Failed to parse authentication code: ${e.toString()}');
      }
    } else {
      // Error response
      String errorMessage = 'Failed to fetch authentication code';
      try {
        final errorData = jsonDecode(response.body);
        if (errorData is Map && errorData.containsKey('message')) {
          errorMessage = errorData['message'].toString();
        } else if (errorData is Map && errorData.containsKey('error')) {
          errorMessage = errorData['error'].toString();
        }
      } catch (e) {
        // Ignore parsing errors, use default message
      }
      
      throw Exception('HTTP ${response.statusCode}: $errorMessage');
    }
  } catch (e) {
    print('Error fetching authentication code: $e');
    rethrow;
  }
}

/// Reset password via QuickShare API
/// Endpoint: POST https://www.quickshare-apps.com/gateway-quickshare-api/apicyclem/login
/// Request body: { "username": "phoneNumber", "password": "newPassword", "codeAcces": "", "actionDem": "ResetPassAct" }
/// Returns: { "message": "...", "code": "200", "role": "USER_ROLE" }
/// This is a direct call to QuickShare API, not through Laravel proxy
Future<Map<String, dynamic>> resetPassword({
  required String phoneNumber,
  required String newPassword,
}) async {
  try {
    // Format phone number (remove + and any non-digit characters)
    String phoneForAPI = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    if (phoneForAPI.isEmpty) {
      throw Exception('Invalid phone number format');
    }

    if (newPassword.isEmpty) {
      throw Exception('Password cannot be empty');
    }
    // Get authentication token
    String authToken;
    try {
      authToken = await authTokenService.getToken();
    } catch (e) {
      throw Exception('Failed to get authentication token: ${e.toString()}');
    }

    // Build API URL
    String apiUrl = 'https://www.quickshare-apps.com/gateway-quickshare-api/apicyclem/login';
    final url = Uri.parse(apiUrl);

    // Build request body
    Map<String, dynamic> requestBody = {
      "username": phoneForAPI,
      "password": newPassword,
      "codeAcces": "",
      "actionDem": "ResetPassAct"
    };

    print('Calling Reset Password API: $apiUrl');
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

    print('Reset Password API Response - Status: ${response.statusCode}');
    print('Reset Password API Response - Body: ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      try {
        final responseData = jsonDecode(response.body);
        
        // Handle different response structures
        Map<String, dynamic> resetData;
        if (responseData is Map<String, dynamic>) {
          // If response is wrapped in a data field
          if (responseData.containsKey('data') && responseData['data'] is Map) {
            resetData = responseData['data'] as Map<String, dynamic>;
          } else {
            // Response is the reset data directly
            resetData = responseData;
          }
        } else {
          throw Exception('Invalid response format: expected Map but got ${responseData.runtimeType}');
        }

        // Extract message, code, and role
        String message = resetData['message']?.toString() ?? '';
        String code = resetData['code']?.toString() ?? '';
        String role = resetData['role']?.toString() ?? '';

        print('✅ Password reset successful: $message');
        print('Response code: $code, Role: $role');

        return {
          'message': message,
          'code': code,
          'role': role,
          'status': code == '200' || code == '201',
        };
      } catch (e) {
        print('Error parsing reset password response: $e');
        throw Exception('Failed to parse reset password response: ${e.toString()}');
      }
    } else {
      // Error response
      String errorMessage = 'Failed to reset password';
      try {
        final errorData = jsonDecode(response.body);
        if (errorData is Map && errorData.containsKey('message')) {
          errorMessage = errorData['message'].toString();
        } else if (errorData is Map && errorData.containsKey('error')) {
          errorMessage = errorData['error'].toString();
        }
      } catch (e) {
        // Ignore parsing errors, use default message
      }
      
      throw Exception('HTTP ${response.statusCode}: $errorMessage');
    }
  } catch (e) {
    print('Error resetting password: $e');
    rethrow;
  }
}

/// Chat backend auth login
/// Endpoint: POST https://www.quickshare-apps.com/chat-backend/api/auth/login
/// Body: { "username": "admin", "password": "admin123" }
/// Response: { "token": "...", "tokenType": "Bearer" }
/// On success, the token is stored for future chat requests (KEY_CHAT_BACKEND_TOKEN).
Future<ChatBackendAuthModel> chatBackendApi() async {
  try {
    const String apiUrl =
        'https://www.quickshare-apps.com/chat-backend/api/auth/login';
    final url = Uri.parse(apiUrl);

    final Map<String, dynamic> requestBody = {
      'username': 'admin',
      'password': 'admin123',
    };

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(requestBody),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final responseData = jsonDecode(response.body);
      final Map<String, dynamic> data = responseData is Map<String, dynamic>
          ? responseData
          : responseData is Map
              ? Map<String, dynamic>.from(responseData)
              : throw Exception('Invalid response format: expected Map');

      final auth = ChatBackendAuthModel.fromJson(data);
      if (auth.token.isEmpty) {
        throw Exception('Chat backend login: token missing in response');
      }
      await setValue(KEY_CHAT_BACKEND_TOKEN, auth.token);
      return auth;
    }

    String errorMessage = 'Chat backend login failed';
    try {
      final errorData = jsonDecode(response.body);
      if (errorData is Map && errorData.containsKey('message')) {
        errorMessage = errorData['message'].toString();
      } else if (errorData is Map && errorData.containsKey('error')) {
        errorMessage = errorData['error'].toString();
      }
    } catch (_) {}

    throw Exception('HTTP ${response.statusCode}: $errorMessage');
  } catch (e) {
    rethrow;
  }
}

/// Mobile payment local-number authentication.
/// Endpoint: POST https://api.quickshare-app.io/quickshare-api/connector/api/authenticate
/// The returned token is stored in SharedPreferences using [KEY_MOBILE_PAYMENT_TOKEN].
Future<Map<String, dynamic>> authenticateMobilePaymentLocalNumber({
  required String phoneNumber,
}) async {
  try {
    const String apiUrl =
        'https://api.quickshare-app.io/quickshare-api/connector/api/authenticate';
    final url = Uri.parse(apiUrl);

    // Kept for signature compatibility and future use.
    final String phoneForApi = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    if (phoneForApi.isEmpty) {
      throw Exception('Invalid phone number format');
    }

    final Map<String, dynamic> requestBody = {
      'id': 3,
      'accountID': '243827130000',
      'userName': 'cycle',
      'email': 'test2@test.com',
      'ipAddresse': '10.1.22.24',
      'name': 'BusinessName1',
      'businessCountry': 'RDC',
      'passe': 'cycle123',
    };

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(requestBody),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final responseData = jsonDecode(response.body);
      final Map<String, dynamic> data = responseData is Map<String, dynamic>
          ? responseData
          : responseData is Map
              ? Map<String, dynamic>.from(responseData)
              : throw Exception('Invalid response format: expected Map');

      final dynamic objectData = data['object'];
      String token = '';

      if (objectData is Map<String, dynamic>) {
        token = objectData['tokken']?.toString() ?? '';
      } else if (objectData is Map) {
        token = objectData['tokken']?.toString() ?? '';
      }

      if (token.isEmpty) {
        throw Exception('Mobile payment authentication: token missing in response');
      }

      await setValue(KEY_MOBILE_PAYMENT_TOKEN, token);
      return data;
    }

    String errorMessage = 'Mobile payment authentication failed';
    try {
      final errorData = jsonDecode(response.body);
      if (errorData is Map && errorData.containsKey('resultDesc')) {
        final dynamic resultDesc = errorData['resultDesc'];
        if (resultDesc != null && resultDesc.toString().isNotEmpty) {
          errorMessage = resultDesc.toString();
        }
      }
      if (errorData is Map && errorData.containsKey('message')) {
        errorMessage = errorData['message'].toString();
      } else if (errorData is Map && errorData.containsKey('error')) {
        errorMessage = errorData['error'].toString();
      }
    } catch (_) {}

    throw Exception('HTTP ${response.statusCode}: $errorMessage');
  } catch (e) {
    rethrow;
  }
}



/// Chatbot message API. Call after obtaining token via [chatBackendApi].
/// Endpoint: POST https://www.quickshare-apps.com/chat-backend/api/chat/message
/// Uses [KEY_CHAT_BACKEND_TOKEN] for Authorization. Returns [text] and [choices] for next chat steps; [choices] can be [].
Future<ChatMessageResponseModel> sendChatMessageApi({
  required String userId,
  required String lang,
  required String phone,
  required String currentKey,
  String flowId = '',
  String input = '',
}) async {
  try {
    const String apiUrl =
        'https://www.quickshare-apps.com/chat-backend/api/chat/message';
    final url = Uri.parse(apiUrl);

    final Map<String, dynamic> requestBody = {
      'userId': userId,
      'lang': lang,
      'msisdn': phone,
      'key': currentKey,
      'flowId': flowId,
      'input': input,
    };

    final token = getStringAsync(KEY_CHAT_BACKEND_TOKEN);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    var response = await http.post(
      url,
      headers: headers,
      body: jsonEncode(requestBody),
    );

    // If token expired (401/403), refresh token and retry once
    if (response.statusCode == 401 || response.statusCode == 403) {
      // Refresh token
      await chatBackendApi();
      
      // Retry with new token
      final newToken = getStringAsync(KEY_CHAT_BACKEND_TOKEN);
      final retryHeaders = <String, String>{
        'Content-Type': 'application/json',
        if (newToken.isNotEmpty) 'Authorization': 'Bearer $newToken',
      };
      
      response = await http.post(
        url,
        headers: retryHeaders,
        body: jsonEncode(requestBody),
      );
    }

    if (response.statusCode == 200 || response.statusCode == 201) {
      final responseData = jsonDecode(response.body);
      final Map<String, dynamic> data = responseData is Map<String, dynamic>
          ? responseData
          : responseData is Map
              ? Map<String, dynamic>.from(responseData)
              : throw Exception('Invalid chat message response: expected Map');

      return ChatMessageResponseModel.fromJson(data);
    }

    String errorMessage = 'Chat message request failed';
    try {
      final errorData = jsonDecode(response.body);
      if (errorData is Map && errorData.containsKey('message')) {
        errorMessage = errorData['message'].toString();
      } else if (errorData is Map && errorData.containsKey('error')) {
        errorMessage = errorData['error'].toString();
      }
    } catch (_) {}

    throw Exception('HTTP ${response.statusCode}: $errorMessage');
  } catch (e) {
    rethrow;
  }
}


/// Returns stored mobile payment auth token.
String getStoredMobilePaymentToken() {
  return getStringAsync(KEY_MOBILE_PAYMENT_TOKEN);
}

/// Create a mobile money account for the provided msisdn.
/// Endpoint: POST https://api.quickshare-app.io/quickshare-api/connector/api/v1/{msisdn}/accountcreate
Future<Map<String, dynamic>> createMobilePaymentAccountApi({
  required String msisdn,
  required String name,
  required String phone,
}) async {
  try {
    final String normalizedPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (msisdn.trim().isEmpty) {
      throw Exception('Invalid msisdn');
    }

    final String token = getStoredMobilePaymentToken();
    if (token.isEmpty) {
      throw Exception('Mobile payment token not found. Authenticate first.');
    }

    final String apiUrl =
        'https://api.quickshare-app.io/quickshare-api/connector/api/v1/{msisdn}/accountcreate';
    final Uri url = Uri.parse(apiUrl);

    final Map<String, dynamic> requestBody = {
      'noms': name,
      'prenom': name,
      'countrylocation': 'CD',
      'pinapplication': null,
      'translimit': null,
      'phoneserial': null,
      'updateddate': null,
      'contactnumber': normalizedPhone,
    };

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(requestBody),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final responseData = jsonDecode(response.body);
      return responseData is Map<String, dynamic>
          ? responseData
          : responseData is Map
              ? Map<String, dynamic>.from(responseData)
              : <String, dynamic>{'raw': response.body};
    }

    String errorMessage = 'Account creation failed';
    try {
      final errorData = jsonDecode(response.body);
      if (errorData is Map && errorData.containsKey('resultDesc')) {
        final dynamic resultDesc = errorData['resultDesc'];
        if (resultDesc != null && resultDesc.toString().isNotEmpty) {
          errorMessage = resultDesc.toString();
        }
      }
      if (errorData is Map && errorData.containsKey('message')) {
        errorMessage = errorData['message'].toString();
      } else if (errorData is Map && errorData.containsKey('error')) {
        errorMessage = errorData['error'].toString();
      }
    } catch (_) {}

    throw Exception('HTTP ${response.statusCode}: $errorMessage');
  } catch (e) {
    rethrow;
  }
}

/// Initialize mobile payment after account creation.
/// Endpoint: POST https://api.quickshare-app.io/quickshare-api/connector/api/v1/852112327/payInSender
/// Expected success response:
/// {"responsecode":"001","responsedesc":"Paiement Initié","transactionid":"..."}
Future<MobilePaymentInitializationModel> initializeMobilePaymentApi({
  required String phone,
  required String name,
  required String amount,
}) async {
  try {
    final String normalizedPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (normalizedPhone.isEmpty) {
      throw Exception('Invalid phone number');
    }

    final String token = getStoredMobilePaymentToken();
    if (token.isEmpty) {
      throw Exception('Mobile payment token not found. Authenticate first.');
    }

    final String apiUrl =
        'https://api.quickshare-app.io/quickshare-api/connector/api/v1/$normalizedPhone/payInSender';
    final Uri url = Uri.parse(apiUrl);

    final Map<String, dynamic> requestBody = {
      'mobilesender': normalizedPhone,
      'codepin': 'OMoney-Direct',
      'expiredperiod': '2020-12-28;B587M',
      'mobilereceiver': normalizedPhone,
      'amountpaid': '$amount.0',
      'quickaction': 'ePayment-Marchand',
      'clientid': normalizedPhone,
      'countrylocation': 'CD',
      'trcomments_nbre': '+$normalizedPhone',
      'trcomments': 'null',
      'udevise': 'USD',
      'saccountnumber': normalizedPhone,
      'noms': name,
    };

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(requestBody),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final responseData = jsonDecode(response.body);
      if (responseData is Map<String, dynamic>) {
        return MobilePaymentInitializationModel.fromJson(responseData);
      }
      if (responseData is Map) {
        return MobilePaymentInitializationModel.fromJson(
          Map<String, dynamic>.from(responseData),
        );
      }
      throw Exception('Invalid mobile payment initialization response');
    }

    String errorMessage = 'Payment initialization failed';
    try {
      final errorData = jsonDecode(response.body);
      if (errorData is Map && errorData.containsKey('responsedesc')) {
        final dynamic responseDesc = errorData['responsedesc'];
        if (responseDesc != null && responseDesc.toString().isNotEmpty) {
          errorMessage = responseDesc.toString();
        }
      }
      if (errorData is Map && errorData.containsKey('resultDesc')) {
        final dynamic resultDesc = errorData['resultDesc'];
        if (resultDesc != null && resultDesc.toString().isNotEmpty) {
          errorMessage = resultDesc.toString();
        }
      }
      if (errorData is Map && errorData.containsKey('message')) {
        errorMessage = errorData['message'].toString();
      } else if (errorData is Map && errorData.containsKey('error')) {
        errorMessage = errorData['error'].toString();
      }
    } catch (_) {}

    throw Exception('HTTP ${response.statusCode}: $errorMessage');
  } catch (e) {
    rethrow;
  }
}

/// Validate mobile payment status.
/// Endpoint: GET https://api.quickshare-app.io/quickshare-api/connector/api/{sysTID}/v1/validatePayment
/// Expected response:
/// {"responsecode":"002","responsedesc":"Paiement En Cours","transactionid":"..."}
Future<MobilePaymentInitializationModel> validateMobilePaymentApi({
  required String transactionId,
}) async {
  try {
    final String normalizedTransactionId = transactionId.trim();
    if (normalizedTransactionId.isEmpty) {
      throw Exception('Invalid transaction id');
    }

    final String token = getStoredMobilePaymentToken();
    if (token.isEmpty) {
      throw Exception('Mobile payment token not found. Authenticate first.');
    }

    final String apiUrl =
        'https://api.quickshare-app.io/quickshare-api/connector/api/$normalizedTransactionId/v1/validatePayment';
    final Uri url = Uri.parse(apiUrl);

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final responseData = jsonDecode(response.body);
      if (responseData is Map<String, dynamic>) {
        return MobilePaymentInitializationModel.fromJson(responseData);
      }
      if (responseData is Map) {
        return MobilePaymentInitializationModel.fromJson(
          Map<String, dynamic>.from(responseData),
        );
      }
      throw Exception('Invalid mobile payment validation response');
    }

    String errorMessage = 'Payment validation failed';
    try {
      final errorData = jsonDecode(response.body);
      if (errorData is Map && errorData.containsKey('responsedesc')) {
        final dynamic responseDesc = errorData['responsedesc'];
        if (responseDesc != null && responseDesc.toString().isNotEmpty) {
          errorMessage = responseDesc.toString();
        }
      }
      if (errorData is Map && errorData.containsKey('resultDesc')) {
        final dynamic resultDesc = errorData['resultDesc'];
        if (resultDesc != null && resultDesc.toString().isNotEmpty) {
          errorMessage = resultDesc.toString();
        }
      }
      if (errorData is Map && errorData.containsKey('message')) {
        errorMessage = errorData['message'].toString();
      } else if (errorData is Map && errorData.containsKey('error')) {
        errorMessage = errorData['error'].toString();
      }
    } catch (_) {}

    throw Exception('HTTP ${response.statusCode}: $errorMessage');
  } catch (e) {
    rethrow;
  }
}


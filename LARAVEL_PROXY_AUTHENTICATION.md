# Laravel Proxy Authentication with QuickShare API

## Problem Statement

- **QuickShare API:** Handles login at `https://www.quickshare-apps.com/gateway-quickshare-api/apicyclem/login`
  - Returns: `{"message": "Connecte avec succes !", "code": "200", "role": "USER_ROLE"}`
  - **NO TOKEN** is returned
  - **CANNOT BE MODIFIED** (external API)

- **Laravel Backend:** Uses Sanctum authentication (`auth:sanctum` middleware)
  - All dashboard routes require a Sanctum token
  - **FULL CONTROL** over Laravel code

- **Challenge:** How to securely authenticate users when QuickShare API doesn't return tokens?

## Solution: Laravel Proxy Authentication

Create a **proxy/login endpoint in Laravel** that:
1. Receives login credentials from mobile app
2. Validates credentials with QuickShare API
3. Finds/creates user in Laravel database
4. Generates and returns Sanctum token
5. Mobile app uses this Sanctum token for all authenticated requests

---

## Architecture Overview

```
Mobile App
    │
    ├─→ Login Request (credentials)
    │   └─→ Laravel Proxy Endpoint: POST /api/login
    │       ├─→ Validates with QuickShare API
    │       ├─→ Finds/Creates user in Laravel DB
    │       └─→ Returns Sanctum Token
    │
    └─→ Authenticated Requests (Bearer Token)
        └─→ Laravel API Routes (auth:sanctum)
            └─→ Returns data
```

---

## Laravel Implementation

### 1. Create Login Proxy Controller

Create `app/Http/Controllers/API/AuthController.php`:

```php
<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    /**
     * QuickShare API base URL
     */
    private const QUICKSHARE_API_URL = 'https://www.quickshare-apps.com/gateway-quickshare-api/apicyclem';
    
    /**
     * QuickShare API authentication credentials
     */
    private const QUICKSHARE_USERNAME = 'cyclem-fe';
    private const QUICKSHARE_PASSWORD = 'eyJzdWIiOiJzZG0iLCJleHAiOjE2NzY0MzY1NDgsImlhdCI6MTY3NjQwMDU0OH0';
    
    /**
     * Cache key for QuickShare token
     */
    private const TOKEN_CACHE_KEY = 'quickshare_api_token';
    private const TOKEN_EXPIRY_KEY = 'quickshare_api_token_expiry';
    
    /**
     * Get QuickShare API authentication token
     * Fetches token dynamically and caches it for 24 hours
     */
    private function getQuickShareAuthToken()
    {
        // Check if we have a cached token that's still valid
        $cachedToken = Cache::get(self::TOKEN_CACHE_KEY);
        $expiry = Cache::get(self::TOKEN_EXPIRY_KEY);
        
        if ($cachedToken && $expiry && now()->lt($expiry)) {
            // Token is still valid (with 5 minute buffer)
            if (now()->addMinutes(5)->lt($expiry)) {
                \Log::info('Using cached QuickShare API token');
                return $cachedToken;
            }
        }
        
        // Token expired or doesn't exist, fetch new one
        \Log::info('QuickShare API token expired or missing. Fetching new token...');
        return $this->fetchQuickShareToken();
    }
    
    /**
     * Fetch authentication token from QuickShare API
     */
    private function fetchQuickShareToken()
    {
        try {
            $response = Http::withHeaders([
                'Content-Type' => 'application/json',
            ])->post(self::QUICKSHARE_API_URL . '/authenticate', [
                'userName' => self::QUICKSHARE_USERNAME,
                'password' => self::QUICKSHARE_PASSWORD,
            ]);
            
            if (!$response->successful()) {
                \Log::error('Failed to fetch QuickShare token: HTTP ' . $response->status());
                throw new \Exception('Failed to authenticate with QuickShare API');
            }
            
            // The token is the entire response body
            $token = $response->body();
            
            if (empty($token)) {
                throw new \Exception('Token not found in QuickShare API response');
            }
            
            // Cache token for 24 hours (with 5 minute buffer for safety)
            $expiry = now()->addHours(24)->subMinutes(5);
            Cache::put(self::TOKEN_CACHE_KEY, $token, $expiry);
            Cache::put(self::TOKEN_EXPIRY_KEY, $expiry, $expiry);
            
            \Log::info('QuickShare API token fetched and cached successfully');
            
            return $token;
            
        } catch (\Exception $e) {
            \Log::error('Error fetching QuickShare token: ' . $e->getMessage());
            
            // If cache exists but expired, try to use it as fallback
            $cachedToken = Cache::get(self::TOKEN_CACHE_KEY);
            if ($cachedToken) {
                \Log::warning('Using expired cached token as fallback');
                return $cachedToken;
            }
            
            throw new \Exception('Failed to fetch QuickShare API token: ' . $e->getMessage());
        }
    }

    /**
     * Login proxy endpoint
     * POST /api/login
     * 
     * Validates credentials with QuickShare API,
     * then generates Laravel Sanctum token
     */
    public function login(Request $request)
    {
        // Validate request
        $request->validate([
            'username' => 'required|string', // Phone number (digits only)
            'password' => 'required|string',
            'codeAcces' => 'required|string|size:5', // 5-digit access code
            'actionDem' => 'required|string',
        ]);

        // Step 1: Validate credentials with QuickShare API
        $quickShareResponse = $this->validateWithQuickShare(
            $request->username,
            $request->password,
            $request->codeAcces,
            $request->actionDem
        );

        if (!$quickShareResponse['success']) {
            return response()->json([
                'message' => $quickShareResponse['message'] ?? 'Invalid credentials',
                'code' => '401'
            ], 401);
        }

        // Step 2: Find or create user in Laravel database
        $user = $this->findOrCreateUser($request->username, $quickShareResponse['role'] ?? 'USER_ROLE');

        // Step 3: Revoke existing tokens (optional - for single device login)
        // $user->tokens()->delete();

        // Step 4: Generate Sanctum token
        $token = $user->createToken('mobile-app-token')->plainTextToken;

        // Step 5: Return success response with token
        return response()->json([
            'message' => 'Login successful',
            'code' => '200',
            'role' => $quickShareResponse['role'] ?? 'USER_ROLE',
            'token' => $token,
            'api_token' => $token, // For mobile app compatibility
        ], 200);
    }

    /**
     * Validate credentials with QuickShare API
     */
    private function validateWithQuickShare($username, $password, $codeAcces, $actionDem)
    {
        try {
            $response = Http::withHeaders([
                'Content-Type' => 'application/json',
                'Authorization' => 'Bearer ' . $this->getQuickShareAuthToken(),
            ])->post(self::QUICKSHARE_API_URL . '/login', [
                'username' => $username,
                'password' => $password,
                'codeAcces' => $codeAcces,
                'actionDem' => $actionDem,
            ]);

            $responseData = $response->json();

            // Check if login was successful
            if ($response->successful() && 
                isset($responseData['code']) && 
                $responseData['code'] == '200') {
                
                return [
                    'success' => true,
                    'message' => $responseData['message'] ?? 'Login successful',
                    'role' => $responseData['role'] ?? 'USER_ROLE',
                ];
            }

            return [
                'success' => false,
                'message' => $responseData['message'] ?? 'Invalid credentials',
            ];

        } catch (\Exception $e) {
            \Log::error('QuickShare API Error: ' . $e->getMessage());
            
            return [
                'success' => false,
                'message' => 'Authentication service temporarily unavailable',
            ];
        }
    }

    /**
     * Find or create user in Laravel database
     */
    private function findOrCreateUser($phoneNumber, $role)
    {
        // Clean phone number (remove + and non-digits)
        $cleanPhone = preg_replace('/[^\d]/', '', $phoneNumber);

        // Try to find user by phone number
        $user = User::where('phone_number', $cleanPhone)
            ->orWhere('phone_number', '+' . $cleanPhone)
            ->first();

        if (!$user) {
            // Create new user
            $user = User::create([
                'phone_number' => $cleanPhone,
                'email' => $cleanPhone . '@temp.email', // Temporary email, can be updated later
                'password' => Hash::make(Str::random(32)), // Random password, won't be used
                'role' => $role,
                'status' => 'active',
                'name' => 'User', // Default name, can be updated later
            ]);
        } else {
            // Update role if changed
            if ($user->role != $role) {
                $user->update(['role' => $role]);
            }
        }

        return $user;
    }

    /**
     * Logout endpoint
     * POST /api/logout
     */
    public function logout(Request $request)
    {
        // Revoke current token
        $request->user()->currentAccessToken()->delete();

        return response()->json([
            'message' => 'Logged out successfully',
            'code' => '200'
        ], 200);
    }
}
```

### 2. Add Routes

In `routes/api.php`:

```php
use App\Http\Controllers\API\AuthController;

// Public routes (no authentication required)
Route::post('login', [AuthController::class, 'login']);

// Protected routes (require Sanctum authentication)
Route::middleware('auth:sanctum')->group(function () {
    Route::post('logout', [AuthController::class, 'logout']);
    
    // All your existing protected routes
    Route::get('user-detail', [API\UserController::class, 'userDetail']);
    Route::get('doctor-detail', [API\UserController::class, 'doctorDetail']);
    Route::get('doctor-dashboard', [API\DashboardController::class, 'doctorDashboard']);
    Route::post('dashboard-list', [API\DashboardController::class, 'dashboard']);
    // ... all other routes with auth:sanctum
});
```

### 3. QuickShare API Token Configuration

**No configuration needed!** The token is fetched dynamically and cached automatically.

The credentials are hardcoded in the controller (as they are static):
- Username: `cyclem-fe`
- Password: `eyJzdWIiOiJzZG0iLCJleHAiOjE2NzY0MzY1NDgsImlhdCI6MTY3NjQwMDU0OH0`

The token is:
- Fetched from QuickShare API on first use
- Cached for 24 hours (with 5-minute buffer for safety)
- Automatically refreshed when expired
- Stored in Laravel's cache system

**Cache Configuration:**
Ensure your Laravel cache is configured properly (in `.env`):
```env
CACHE_DRIVER=file  # or redis, database, etc.
```

If using Redis (recommended for production):
```env
CACHE_DRIVER=redis
REDIS_HOST=127.0.0.1
REDIS_PASSWORD=null
REDIS_PORT=6379
```

### 4. Update User Model

Ensure your User model uses Sanctum:

```php
<?php

namespace App\Models;

use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable;

    protected $fillable = [
        'name',
        'email',
        'password',
        'phone_number',
        'role',
        'status',
        // ... other fields
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected $casts = [
        'email_verified_at' => 'datetime',
    ];
}
```

### 5. Run Migration (if needed)

Ensure users table has `phone_number` field:

```php
Schema::table('users', function (Blueprint $table) {
    $table->string('phone_number')->unique()->nullable();
    $table->string('role')->default('USER_ROLE');
    // ... other fields
});
```

---

## Mobile App Changes

### Update Login Endpoint URL

The mobile app should call **Laravel's login endpoint** instead of QuickShare API directly.

**File:** `lib/network/rest_api.dart`

Update the `loginWithPhoneAndCode` function:

```dart
/// Login API with phone number, password, and access code
/// This calls Laravel proxy endpoint which validates with QuickShare API
Future<UserResponse> loginWithPhoneAndCode({
  required String phoneNumber,
  required String password,
  required String accessCode,
}) async {
  try {
    // Format phone number (remove + and non-digits for API)
    String phoneForAPI = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    // Build request body
    Map<String, dynamic> requestBody = {
      "username": phoneForAPI,
      "password": password,
      "codeAcces": accessCode,
      "actionDem": "LoginAct"
    };

    // Use Laravel API endpoint (NOT QuickShare API directly)
    // This should match your Laravel API base URL
    final url = Uri.parse("$APP_BASE_URL/api/login"); // Adjust to your Laravel API URL

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
    
    // Laravel should return token in response
    String? sanctumToken = responseData['token']?.toString() ?? 
                          responseData['api_token']?.toString();
    
    if (sanctumToken == null || sanctumToken.isEmpty) {
      throw Exception('Login successful but no token received');
    }

    // Get data from questionsModel to construct UserModel
    final Map<String, dynamic>? questionData = getJSONAsync(KEY_QUESTION_DATA);
    if (questionData == null || questionData.isEmpty) {
      throw Exception('Cannot construct user data: Question data not found.');
    }
    
    final QuestionsModel questionsModelData = QuestionsModel.fromJson(questionData);
    
    // ... (extract user data from questionsModel) ...
    
    // Construct UserModel with Sanctum token from Laravel
    final Map<String, dynamic> userDataMap = {
      // ... (user data fields) ...
      'api_token': sanctumToken, // Sanctum token from Laravel
      'status': 'active',
    };
    
    final userResponse = UserResponse(
      status: true,
      message: responseData['message']?.toString() ?? 'Login successful',
      data: UserModel.fromJson(userDataMap),
    );

    if (userResponse.status == true && userResponse.data != null) {
      saveUserData(userResponse.data);
      await userStore.setLogin(true);
      return userResponse;
    } else {
      throw Exception(userResponse.message ?? 'Login failed');
    }
  } catch (e) {
    print('Login API Error: $e');
    rethrow;
  }
}
```

### Update API Base URL Configuration

Ensure your mobile app uses Laravel API URL, not QuickShare API URL directly.

**File:** `lib/utils/app_config.dart` or wherever `APP_BASE_URL` is defined:

```dart
const String APP_BASE_URL = "https://your-laravel-domain.com"; // Your Laravel API URL
```

---

## Security Considerations

### 1. **Rate Limiting**

Add rate limiting to prevent brute force attacks:

```php
// In routes/api.php
Route::post('login', [AuthController::class, 'login'])
    ->middleware('throttle:5,1'); // 5 attempts per minute
```

### 2. **HTTPS Only**

Ensure all API communication uses HTTPS.

### 3. **Token Expiration**

Configure token expiration in `config/sanctum.php`:

```php
'expiration' => 60 * 24 * 30, // 30 days in minutes
```

### 4. **Secure Token Storage**

The QuickShare API bearer token should be:
- Stored in `.env` file (never commit to git)
- Rotated regularly
- Used only server-side (never exposed to mobile app)

### 5. **Error Handling**

Don't expose QuickShare API errors directly to clients:

```php
try {
    $quickShareResponse = $this->validateWithQuickShare(...);
} catch (\Exception $e) {
    \Log::error('QuickShare API Error: ' . $e->getMessage());
    // Return generic error to client
    return response()->json([
        'message' => 'Authentication service temporarily unavailable',
    ], 503);
}
```

---

## Flow Diagram

```
┌─────────────┐
│ Mobile App  │
└──────┬──────┘
       │
       │ POST /api/login
       │ { username, password, codeAcces, actionDem }
       ▼
┌─────────────────────┐
│ Laravel Proxy       │
│ POST /api/login     │
│ 1. Get QuickShare   │
│    Token (cached)   │
└──────┬──────────────┘
       │
       │ (If token expired/missing)
       │ POST /apicyclem/authenticate
       │ { userName: "cyclem-fe", password: "..." }
       │
       │ POST /apicyclem/login
       │ Authorization: Bearer {quickshare_token}
       │ { username, password, codeAcces, actionDem }
       ▼
┌─────────────────────┐
│ QuickShare API      │
│ (External)          │
└──────┬──────────────┘
       │
       │ { message, code: "200", role }
       ▼
┌─────────────────────┐
│ Laravel Proxy       │
│ - Find/Create User  │
│ - Generate Token    │
└──────┬──────────────┘
       │
       │ { token, api_token, message, code, role }
       ▼
┌─────────────┐
│ Mobile App  │
│ Stores Token│
└─────────────┘

┌─────────────┐
│ Mobile App  │
└──────┬──────┘
       │
       │ GET /api/user-detail
       │ Authorization: Bearer {sanctum_token}
       ▼
┌─────────────────────┐
│ Laravel API         │
│ auth:sanctum        │
│ - Validates Token   │
│ - Returns Data      │
└─────────────────────┘
```

---

## Testing

### 1. Test Laravel Login Endpoint

```bash
curl -X POST https://your-laravel-domain.com/api/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "1234567890",
    "password": "user_password",
    "codeAcces": "12345",
    "actionDem": "LoginAct"
  }'
```

**Expected Response:**
```json
{
  "message": "Login successful",
  "code": "200",
  "role": "USER_ROLE",
  "token": "1|xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "api_token": "1|xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
}
```

### 2. Test Authenticated Endpoint

```bash
curl -X GET https://your-laravel-domain.com/api/user-detail \
  -H "Authorization: Bearer {sanctum_token_from_login}"
```

---

## Advantages of This Approach

1. ✅ **Security:** All authentication goes through Laravel (your control)
2. ✅ **Flexibility:** Can add additional validation, logging, rate limiting
3. ✅ **User Management:** Laravel manages users and tokens
4. ✅ **Consistency:** Single authentication mechanism (Sanctum)
5. ✅ **Maintainability:** Centralized authentication logic
6. ✅ **Scalability:** Can add features like refresh tokens, multi-device support
7. ✅ **Monitoring:** Can log all authentication attempts
8. ✅ **Separation:** Mobile app doesn't need QuickShare API credentials

---

## Migration Steps

1. ✅ Create `AuthController` in Laravel (with dynamic token fetching)
2. ✅ Add login route to `routes/api.php`
3. ✅ Configure cache driver in `.env` (file, redis, etc.)
4. ✅ Update User model (if needed) - add `HasApiTokens` trait
5. ✅ Run migrations (if needed) - ensure `phone_number` field exists
6. ✅ Update mobile app to call Laravel endpoint
7. ✅ Test login flow (token should be fetched automatically)
8. ✅ Monitor cache for token storage
9. ✅ Deploy and monitor

**Note:** No need to configure QuickShare token in `.env` - it's fetched dynamically!

---

## Summary

**QuickShare API** (external, cannot modify):
- `/authenticate` endpoint: Returns bearer token (expires in 24 hours)
  - Request: `{ "userName": "cyclem-fe", "password": "..." }`
  - Response: Token string (or JSON with token)
- `/login` endpoint: Validates user credentials
  - Returns: `{ "message": "...", "code": "200", "role": "USER_ROLE" }`
  - **NO TOKEN** returned

**Laravel Proxy** (your control):
- **Fetches QuickShare token dynamically** from `/authenticate` endpoint
- **Caches token for 24 hours** (with 5-minute buffer)
- **Automatically refreshes** expired tokens
- Receives credentials from mobile app
- Validates with QuickShare API (using cached token)
- Finds/creates user in Laravel database
- Generates Sanctum token
- Returns Sanctum token to mobile app

**Mobile App**:
- Calls Laravel login endpoint (NOT QuickShare directly)
- Receives Sanctum token
- Uses Sanctum token for all authenticated Laravel routes

## Key Features

1. ✅ **Dynamic Token Management:** QuickShare token fetched automatically
2. ✅ **Smart Caching:** 24-hour cache with automatic refresh
3. ✅ **Seamless Integration:** Mobile app doesn't need QuickShare credentials
4. ✅ **Secure:** QuickShare token never exposed to mobile app
5. ✅ **Maintainable:** Centralized authentication logic in Laravel
6. ✅ **Resilient:** Fallback to expired cache if fetch fails

This architecture provides secure, maintainable authentication while working around the limitations of the external QuickShare API! 🚀


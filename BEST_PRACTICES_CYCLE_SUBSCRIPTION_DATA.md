# Best Practices: Accessing Cycle Info and Subscription Data

## Current Implementation

### Cycle Info (✅ Good)
- **Storage**: `userStore.cycleInfo` (MobX observable)
- **Access**: `userStore.cycleInfo` directly
- **Reactive**: Yes - wrapped in `Observer` widgets
- **Fetched**: Automatically after login via `_fetchCycleInfoAfterLogin()`

### Subscription Info (⚠️ Needs Improvement)
- **Storage**: Not stored in store
- **Access**: Must call `getSubscriptionInfoApi(phoneNumber)` each time
- **Reactive**: No - requires manual API calls
- **Fetched**: Only when explicitly called

## Recommended Best Practices

### 1. Store Subscription Info in UserStore (Recommended)

**Why:**
- Consistent with cycle info pattern
- Reactive updates via MobX
- Avoids repeated API calls
- Single source of truth

**Implementation:**
```dart
// In user_store.dart
@observable
SubscriptionInfoModel? subscriptionInfo = null;

@action
Future<void> setSubscriptionInfo(SubscriptionInfoModel? subscriptionInfoData,
    {bool isInitialization = false}) async {
  subscriptionInfo = subscriptionInfoData;
}
```

**Fetch after login:**
```dart
// In rest_api.dart - add to _fetchCycleInfoAfterLogin()
Future<void> _fetchCycleInfoAfterLogin() async {
  try {
    String? phoneNumber = userStore.user?.phoneNumber;
    if (phoneNumber == null || phoneNumber.isEmpty) {
      return;
    }
    
    // Fetch both cycle info and subscription info
    final cycleInfo = await getCycleInfoDirectApi(phoneNumber);
    final subscriptionInfo = await getSubscriptionInfoApi(phoneNumber);
    
    await userStore.setCycleInfo(cycleInfo);
    await userStore.setSubscriptionInfo(subscriptionInfo);
  } catch (e) {
    print('Error fetching user data: $e');
  }
}
```

### 2. Access Data in Widget (Recommended Pattern)

**Current Pattern (Cycle Info):**
```dart
Observer(
  builder: (_) {
    final cycleInfo = userStore.cycleInfo;
    // Use cycleInfo here
  },
)
```

**Recommended Pattern (Both):**
```dart
Observer(
  builder: (_) {
    final cycleInfo = userStore.cycleInfo;
    final subscriptionInfo = userStore.subscriptionInfo;
    
    // Both are reactive and update automatically
    // Use both here
  },
)
```

### 3. Helper Methods in Widget (Optional)

**For computed values:**
```dart
// In circular_beads_diagram.dart
int getTodayBeadNumber() {
  final cycleInfo = userStore.cycleInfo;
  // Calculate from cycleInfo
}

String? getUserName() {
  final subscriptionInfo = userStore.subscriptionInfo;
  return subscriptionInfo?.nomClient;
}
```

### 4. Error Handling

**Check for null:**
```dart
if (userStore.cycleInfo == null) {
  // Show loading or fetch data
}

if (userStore.subscriptionInfo == null) {
  // Show loading or fetch data
}
```

## Comparison: Current vs Recommended

### Current Approach (Subscription Info)
```dart
// ❌ Must fetch each time
Future<void> getSubscriptionData() async {
  final phoneNumber = userStore.user?.phoneNumber;
  if (phoneNumber == null) return;
  
  try {
    final subscriptionInfo = await getSubscriptionInfoApi(phoneNumber);
    // Use subscriptionInfo
  } catch (e) {
    // Handle error
  }
}
```

### Recommended Approach (Subscription Info)
```dart
// ✅ Access from store (reactive)
Observer(
  builder: (_) {
    final subscriptionInfo = userStore.subscriptionInfo;
    if (subscriptionInfo == null) {
      return CircularProgressIndicator();
    }
    // Use subscriptionInfo directly
  },
)
```

## Implementation Steps

1. **Add to UserStore:**
   - Add `SubscriptionInfoModel? subscriptionInfo` observable
   - Add `setSubscriptionInfo()` action

2. **Fetch After Login:**
   - Update `_fetchCycleInfoAfterLogin()` to also fetch subscription info
   - Store both in userStore

3. **Update Widget:**
   - Access via `userStore.subscriptionInfo`
   - Wrap in `Observer` for reactive updates

4. **Run Code Generation:**
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

## Benefits

✅ **Reactive Updates**: Data updates automatically when changed
✅ **Performance**: No repeated API calls
✅ **Consistency**: Same pattern for both cycle and subscription data
✅ **Simplicity**: Direct access from store
✅ **Type Safety**: MobX ensures type safety

## Example Usage in circular_beads_diagram.dart

```dart
Observer(
  builder: (_) {
    final cycleInfo = userStore.cycleInfo;
    final subscriptionInfo = userStore.subscriptionInfo;
    
    if (cycleInfo == null) {
      return Text('Loading cycle info...');
    }
    
    // Use cycleInfo.dateRegle for calculations
    final todayBead = getTodayBeadNumber();
    
    // Use subscriptionInfo.nomClient for display
    final userName = subscriptionInfo?.nomClient ?? 'User';
    
    return Column(
      children: [
        Text('Hello $userName'),
        Text('Today bead: $todayBead'),
        // ... rest of UI
      ],
    );
  },
)
```





















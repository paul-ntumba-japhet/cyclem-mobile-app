# Step Identification: `cycle_eligible` Response

This document identifies the exact step in the IK Chatbot process where the API returns the response object with `key: "cycle_eligible"`.

## Response Object

```json
{
    "sessionId": "a45ca3f6-50db-4ca1-8e22-cb024a92b85d",
    "userId": "243840042618",
    "lang": "fr",
    "key": "cycle_eligible",
    "state": "WAITING_INPUT",
    "type": "INPUT",
    "text": "Entrez la date du 1er jour de vos dernières règles (YYYY-MM-DD) :",
    "choices": [],
    "nextExpectedInput": true,
    "timestamp": "2026-02-25T11:15:59.558227212"
}
```

## Step in the Process

### **Location in Code:**
- **File:** `lib/screens/user/ikchatbot_screen.dart`
- **Method:** `_sendChoiceReply()` (lines 315-402)
- **Specific Line:** The response is processed at **line 363-370** when `sendChatMessageApi()` returns

### **Flow Sequence:**

1. **Initial Welcome Message**
   - User sees welcome message with "Oui" and "Non" smart replies
   - **Location:** `_fetchInitialWelcomeMessage()` (lines 142-180)

2. **User Taps "Oui" (Yes)**
   - Calls `_fetchCycleStartResponse()` with `currentKey: 'cycle_start'`
   - **Location:** `_fetchCycleStartResponse()` (lines 213-270)
   - Bot asks: **"Votre cycle est-il régulier ?"** with choices "Oui" / "Non"
   - Response has `key: "cycle_q1_regular"`

3. **User Answers Cycle Regularity Question**
   - User taps "Oui" or "Non" smart reply
   - Calls `_sendChoiceReply()` with `choice.nextKey` from the previous response
   - **Location:** `_sendChoiceReply()` (lines 315-402)
   - If "Oui" (regular): Bot asks **"Allaitez-vous actuellement ?"** with `key: "cycle_q2_breastfeeding"`
   - If "Non" (irregular): May lead to `cycle_not_eligible` or other paths

4. **User Answers Breastfeeding Question (if cycle is regular)**
   - User taps "Oui" or "Non" smart reply
   - Calls `_sendChoiceReply()` again
   - **If user taps "Non" (not breastfeeding):**
     - The `choice.nextKey` from the breastfeeding question response is `"cycle_eligible"`
     - API request is made with `key: "cycle_eligible"` and `input: ""`
     - **This is where the `cycle_eligible` response object is returned**

5. **Bot Requests Period Date**
   - The API returns the response with:
     - `key: "cycle_eligible"`
     - `type: "INPUT"`
     - `text: "Entrez la date du 1er jour de vos dernières règles (YYYY-MM-DD) :"`
     - `choices: []` (empty - no smart replies)
     - `state: "WAITING_INPUT"`
   - **Location:** Response is processed at line 374-386 in `_sendChoiceReply()`
   - The bot message is displayed asking for the period date

## Exact Code Flow

### When the Response is Received:

```dart
// In _sendChoiceReply() method (line 363-370)
final response = await sendChatMessageApi(
  userId: phoneNumber,
  lang: 'fr',
  phone: phoneNumber,
  currentKey: keyToUse,  // This is choice.nextKey = "cycle_eligible"
  flowId: '',
  input: '',  // Always empty string
);

// Response is processed (line 374-386)
setState(() {
  _messages.removeAt(0);  // Remove loading animation
  final choiceLabels = response.choices.take(2).map((c) => c.label).toList();
  _messages.insert(0, ChatMessage(
    text: response.text,  // "Entrez la date du 1er jour de vos dernières règles (YYYY-MM-DD) :"
    isUser: false,
    timestamp: DateTime.now(),
    smartReplies: choiceLabels.isEmpty ? null : choiceLabels,  // null because choices is empty
    choices: response.choices.isEmpty ? null : response.choices,  // null because choices is empty
    responseKey: response.key,  // "cycle_eligible"
  ));
});
```

## Summary

**The `cycle_eligible` response is returned at Step 4 of the chatbot flow:**

- **After:** User has answered "Oui" to cycle regularity question AND "Non" to breastfeeding question
- **When:** The API call is made with `key: "cycle_eligible"` (from `choice.nextKey` of the breastfeeding question)
- **Result:** Bot displays the message asking for the period date in YYYY-MM-DD format
- **State:** The chatbot is now in `WAITING_INPUT` state, expecting the user to provide the period date

**Note:** Since `choices: []` is empty, no smart reply buttons are displayed. The user would need to use the text input field (if enabled) or the system may handle this differently based on the `type: "INPUT"` state.










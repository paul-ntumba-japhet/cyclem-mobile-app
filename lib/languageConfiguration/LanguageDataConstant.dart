import 'dart:convert';
import 'dart:ui';


import '../extensions/common.dart';
import 'ServerLanguageResponse.dart' as prefix0;

/*import 'package:era_flutter/LanguageConfiguration/ServerLanguageResponse.dart'
    as prefix0 hide ContentData;*/
import 'package:era_flutter/languageConfiguration/ServerLanguageResponse.dart'
    as prefix1;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../extensions/shared_pref.dart';
import '../main.dart';
import '../utils/app_config.dart';
import 'LanguageDefaultJson.dart';
import 'LocalLanguageResponse.dart';

const LanguageJsonDataRes = 'LanguageJsonDataRes'; // DO NOT CHANGE
const CURRENT_LAN_VERSION = 'LanguageData'; // DO NOT CHANGE
const LanguageVersion = '0'; // DO NOT CHANGE
const SELECTED_LANGUAGE_CODE = 'selected_language_code'; // DO NOT CHANGE
const SELECTED_LANGUAGE_COUNTRY_CODE =
    'selected_language_country_code'; // DO NOT CHANGE
const IS_SELECTED_LANGUAGE_CHANGE = 'isSelectedLanguageChange';

Locale defaultLanguageLocale = Locale(defaultLanguageCode);

Locale setDefaultLocate() {
  String getJsonData = getStringAsync(LanguageJsonDataRes, defaultValue: "");
  if (getJsonData.isNotEmpty) {
    prefix0.ServerLanguageResponse languageSettings =
        prefix0.ServerLanguageResponse.fromJson(
            json.decode(getJsonData.trim()));
    if (languageSettings.data!.length > 0) {
      defaultServerLanguageData = languageSettings.data;
      performLanguageOperation(defaultServerLanguageData);
    }
  }
  if (defaultServerLanguageData != null &&
      defaultServerLanguageData!.length > 0) {
    performLanguageOperation(defaultServerLanguageData);
  }

  return defaultLanguageLocale;
}

performLanguageOperation(
    List<prefix0.LanguageJsonData>? _defaultServerLanguageData) {
  String selectedLanguageCode =
      getStringAsync(SELECTED_LANGUAGE_CODE, defaultValue: "");
  bool isFoundLocalSelectedLanguage = false;
  bool isFoundSelectedLanguageFromServer = false;

  for (int index = 0; index < _defaultServerLanguageData!.length; index++) {
    if (selectedLanguageCode.isNotEmpty) {
      if (_defaultServerLanguageData[index].languageCode ==
          selectedLanguageCode) {
        isFoundLocalSelectedLanguage = true;
        defaultLanguageLocale = Locale(
            _defaultServerLanguageData[index].languageCode!,
            _defaultServerLanguageData[index].countryCode!);
        selectedServerLanguageData = _defaultServerLanguageData[index];
        break;
      }
    }
    if (_defaultServerLanguageData[index].isDefaultLanguage == 1) {
      isFoundSelectedLanguageFromServer = true;
      defaultLanguageLocale = Locale(
          _defaultServerLanguageData[index].languageCode!,
          _defaultServerLanguageData[index].countryCode!);
      selectedServerLanguageData = _defaultServerLanguageData[index];
    }
  }
  if (!isFoundLocalSelectedLanguage && !isFoundSelectedLanguageFromServer) {
    selectedServerLanguageData = null;
  }

  updateMenstrualWidgetLanguage();
}

List<Locale> getSupportedLocales() {
  List<Locale> list = [];
  if (defaultServerLanguageData != null &&
      defaultServerLanguageData!.length > 0) {
    for (int index = 0; index < defaultServerLanguageData!.length; index++) {
      list.add(Locale(defaultServerLanguageData![index].languageCode!, ''));
    }
  } else {
    list.add(defaultLanguageLocale);
  }
  return list;
}

String getContentValueFromKey(int keywordId) {
  String defaultKeyValue = defaultKeyNotFoundValue;
  bool isFoundKey = false;
  
  // Priority 1: Check JSON file data first (local translations)
  for (int index = 0; index < defaultLanguageDataKeys.length; index++) {
    if (defaultLanguageDataKeys[index].keywordId == keywordId) {
      defaultKeyValue = defaultLanguageDataKeys[index].keywordValue!;
      isFoundKey = true;
      break;
    }
  }
  
  // Priority 2: Fallback to server data if not found in JSON files
  if (!isFoundKey && selectedServerLanguageData != null) {
    for (int index = 0;
        index < selectedServerLanguageData!.contentData!.length;
        index++) {
      if (selectedServerLanguageData!.contentData![index].keywordId ==
          keywordId) {
        defaultKeyValue =
            selectedServerLanguageData!.contentData![index].keywordValue!;
        isFoundKey = true;
        break;
      }
    }
  }
  
  if (!isFoundKey) {
    defaultKeyValue = defaultKeyValue + "($keywordId)";
  }
  return defaultKeyValue.toString().trim();
}

initJsonFile() async {
  String langCode = getStringAsync(SELECTED_LANGUAGE_CODE, defaultValue: defaultLanguageCode);
  
  // Determine which JSON file to load based on language code
  String jsonFileName;
  switch (langCode.toLowerCase()) {
    case 'fr':
      jsonFileName = 'assets/staticjson/keyword_list_fr.json';
      break;
    case 'en':
    default:
      jsonFileName = 'assets/staticjson/keyword_list_en.json';
      break;
  }

  try {
    // Use the determined jsonFileName instead of hardcoded English file
    final String jsonString = await rootBundle.loadString(jsonFileName);
    final list = json.decode(jsonString) as List;
    List<LocalLanguageResponse> finalList = list
        .map((jsonElement) => LocalLanguageResponse.fromJson(jsonElement))
        .toList();
    defaultLanguageDataKeys.clear();
    for (int index = 0; index < finalList.length; index++) {
      if (finalList[index].keywordData != null) {
        for (int i = 0; i < finalList[index].keywordData!.length; i++) {
          defaultLanguageDataKeys.add(
            prefix1.ContentData(
                keywordId: finalList[index].keywordData![i].keywordId,
                keywordName: finalList[index].keywordData![i].keywordName,
                keywordValue: finalList[index].keywordData![i].keywordValue),
          );
        }
      }
    }
    print('Successfully loaded language file: $jsonFileName (${defaultLanguageDataKeys.length} keywords)');
  } catch (e) {
    print('Error loading language file $jsonFileName: $e');
    print('Falling back to English...');
    try {
      final String jsonString = 
          await rootBundle.loadString('assets/staticjson/keyword_list_en.json');
      final list = json.decode(jsonString) as List;
      List<LocalLanguageResponse> finalList = list
          .map((jsonElement) => LocalLanguageResponse.fromJson(jsonElement))
          .toList();
      defaultLanguageDataKeys.clear();
      for (int index = 0; index < finalList.length; index++) {
        if (finalList[index].keywordData != null) {
          for (int i = 0; i < finalList[index].keywordData!.length; i++) {
            defaultLanguageDataKeys.add(
              prefix1.ContentData(
                  keywordId: finalList[index].keywordData![i].keywordId,
                  keywordName: finalList[index].keywordData![i].keywordName,
                  keywordValue: finalList[index].keywordData![i].keywordValue),
            );
          }
        }
      }
      print('Successfully loaded fallback English file (${defaultLanguageDataKeys.length} keywords)');
    } catch (fallbackError) {
      print('Error loading fallback English file: $fallbackError');
    }
  }
}

// DO NOT CHANGE

String getCountryCode() {
  String defaultCode = countryCode!;
  String selectedLang =
      getStringAsync(SELECTED_LANGUAGE_CODE, defaultValue: defaultLanguageCode);
  if (defaultServerLanguageData != null &&
      defaultServerLanguageData!.length > 0) {
    for (int index = 0; index < defaultServerLanguageData!.length; index++) {
      if (selectedLang == defaultServerLanguageData![index].languageCode) {
        List<String> selectedCoutry =
            defaultServerLanguageData![index].countryCode!.split("-");
        if (selectedCoutry.length > 0) {
          defaultCode = selectedCoutry[1];
        }
      }
    }
  }

  return defaultCode;
}

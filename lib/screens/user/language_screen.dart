import 'package:era_flutter/extensions/extension_util/context_extensions.dart';
import 'package:era_flutter/languageConfiguration/LanguageDataConstant.dart';
import 'package:era_flutter/languageConfiguration/LanguageDefaultJson.dart';
import 'package:era_flutter/languageConfiguration/ServerLanguageResponse.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../extensions/animated_list/animated_list_view.dart';
import '../../extensions/extension_util/string_extensions.dart';
import '../../extensions/extensions.dart';
import '../../extensions/new_colors.dart';
import '../../main.dart';
import '../../utils/app_common.dart';

class LanguageScreen extends StatefulWidget {
  final bool isFromDoctor;

  const LanguageScreen({super.key, required this.isFromDoctor});

  @override
  _LanguageScreenState createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  // Static language list with French and English
  List<LanguageJsonData> get _staticLanguages {
    return [
      LanguageJsonData(
        id: 1,
        languageName: 'Français',
        languageCode: 'fr',
        countryCode: 'FR',
        isDefaultLanguage: 1,
        isRtl: 0,
      ),
      LanguageJsonData(
        id: 2,
        languageName: 'English',
        languageCode: 'en',
        countryCode: 'US',
        isDefaultLanguage: 0,
        isRtl: 0,
      ),
    ];
  }

  // Get available languages (server data or static fallback)
  List<LanguageJsonData> get _availableLanguages {
    if (defaultServerLanguageData != null && defaultServerLanguageData!.isNotEmpty) {
      // Filter to only show French and English from server data
      List<LanguageJsonData> filtered = defaultServerLanguageData!
          .where((lang) => lang.languageCode == 'fr' || lang.languageCode == 'en')
          .toList();
      
      // If we have both languages from server, use them
      if (filtered.length >= 2) {
        return filtered;
      }
      
      // Otherwise, merge with static languages
      List<LanguageJsonData> result = [];
      bool hasFrench = filtered.any((lang) => lang.languageCode == 'fr');
      bool hasEnglish = filtered.any((lang) => lang.languageCode == 'en');
      
      // Add French (from server if available, otherwise static)
      if (hasFrench) {
        result.add(filtered.firstWhere((lang) => lang.languageCode == 'fr'));
      } else {
        result.add(_staticLanguages.firstWhere((lang) => lang.languageCode == 'fr'));
      }
      
      // Add English (from server if available, otherwise static)
      if (hasEnglish) {
        result.add(filtered.firstWhere((lang) => lang.languageCode == 'en'));
      } else {
        result.add(_staticLanguages.firstWhere((lang) => lang.languageCode == 'en'));
      }
      
      return result;
    } else {
      // Use static languages if server data is not available
      return _staticLanguages;
    }
  }

  @override
  void initState() {
    super.initState();
    logScreenView("Language screen");
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: kPrimaryColor,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Column(
            children: [
              Container(
                color: kPrimaryColor,
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          icon: Icon(
                            CupertinoIcons.back,
                            color: mainColorText,
                          ),
                        ),
                        Text(
                          language.languages,
                          style: boldTextStyle(
                            size: textFontSize_18,
                            weight: FontWeight.w500,
                            color: mainColorText,
                          ),
                        ),
                      ],
                    ),
                    10.height,
                  ],
                ),
              ),
              // Scrollable Content
              Expanded(
                child: Container(
                  width: context.width(),
                  decoration: const BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: AnimatedListView(
                    itemCount: _availableLanguages.length,
                    padding: const EdgeInsets.all(16),
                    shrinkWrap: true,
                    itemBuilder: (context, index) {
                      LanguageJsonData data = _availableLanguages[index];
                      bool isSelected = getStringAsync(
                            SELECTED_LANGUAGE_CODE,
                            defaultValue: defaultLanguageCode,
                          ) ==
                          data.languageCode.validate();

                      return GestureDetector(
                        onTap: () async {
                          // Store navigator reference and check canPop BEFORE update to avoid deactivated widget error
                          final navigator = Navigator.of(context);
                          final canPop = navigator.canPop();
                          final rootContext = navigatorKey.currentContext;
                          
                          // Update language configuration
                          await updateAppLanguageConfiguration(
                            data: data,
                            context: rootContext,
                          );
                          
                          // Pop immediately using stored navigator reference (don't check context.mounted after update)
                          if (canPop) {
                            navigator.pop();
                          }
                          
                          // Wait a bit for the language to load and app to rebuild
                          await Future.delayed(const Duration(milliseconds: 300));
                          
                          // Show success message using root context after navigation
                          final currentRootContext = navigatorKey.currentContext;
                          if (currentRootContext != null && currentRootContext.mounted) {
                            ScaffoldMessenger.of(currentRootContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${language.languages}: ${data.languageName.validate()}',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                backgroundColor: mainColor,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? mainColor.withValues(alpha: 0.1)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                            border: Border.all(
                              color: isSelected
                                  ? mainColor.withValues(alpha:  0.5)
                          : Colors.grey.shade200,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Flag icon (uncomment if you want to include)
                              // ClipRRect(
                              //   borderRadius: BorderRadius.circular(8),
                              //   child: Image.asset(
                              //     data.flag.validate(),
                              //     width: 28,
                              //     height: 28,
                              //     fit: BoxFit.cover,
                              //   ),
                              // ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  data.languageName.validate(),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color:
                                        isSelected ? mainColor : Colors.black87,
                                  ),
                                ),
                              ),
                              AnimatedScale(
                                duration: const Duration(milliseconds: 200),
                                scale: isSelected ? 1.1 : 1.0,
                                child: Icon(
                                  isSelected
                                      ? Icons.check_circle
                                      : Icons.circle_outlined,
                                  size: 24,
                                  color: isSelected
                                      ? mainColor
                                      : Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

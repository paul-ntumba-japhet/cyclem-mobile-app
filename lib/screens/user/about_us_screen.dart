import 'package:era_flutter/extensions/extension_util/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../extensions/extension_util/string_extensions.dart';
import '../../extensions/extensions.dart';
import '../../extensions/new_colors.dart';
import '../../extensions/shared_pref.dart';
import '../../languageConfiguration/LanguageDataConstant.dart';
import '../../main.dart';
import '../../utils/app_config.dart';
import '../../utils/dynamic_theme.dart';
import '../../utils/utils.dart';

class AboutUsScreen extends StatefulWidget {
  final bool isFromDoctor;

  const AboutUsScreen({super.key, required this.isFromDoctor});

  @override
  State<AboutUsScreen> createState() => _AboutUsScreenState();
}

class _AboutUsScreenState extends State<AboutUsScreen> {
  bool isLoading = true;

  // Static about content for CycleM
  String get _staticAboutContentFrench => '''CycleM est une application complète de suivi du cycle menstruel conçue pour vous aider à mieux comprendre et gérer votre santé reproductive.

NOS FONCTIONNALITÉS PRINCIPALES :

• Suivi du cycle menstruel : Enregistrez vos périodes et suivez votre cycle avec précision

• Prédiction des règles : Recevez des prévisions précises de vos prochaines règles

• Fenêtre de fertilité : Identifiez vos jours les plus fertiles pour planifier ou éviter une grossesse

• Calendrier menstruel : Visualisez votre cycle sur un calendrier interactif

• Graphiques et rapports : Analysez vos données de cycle avec des graphiques détaillés

• Notifications personnalisées : Recevez des rappels pour les étapes importantes de votre cycle

• Articles et blog : Accédez à des informations éducatives sur la santé menstruelle

• Assistant IA : Obtenez des réponses à vos questions sur votre cycle

• Suivi de la santé : Enregistrez vos symptômes et vos observations

NOTRE MISSION :

CycleM s'engage à fournir des outils précis et fiables pour vous aider à prendre le contrôle de votre santé reproductive. Nous croyons que chaque femme mérite d'avoir accès à des informations claires et personnalisées sur son cycle menstruel.

CONFIDENTIALITÉ ET SÉCURITÉ :

Vos données sont importantes pour nous. Nous utilisons des mesures de sécurité avancées pour protéger vos informations personnelles et respectons strictement notre politique de confidentialité.''';

  String get _staticAboutContentEnglish => '''CycleM is a comprehensive menstrual cycle tracking application designed to help you better understand and manage your reproductive health.

OUR KEY FEATURES:

• Cycle Tracking: Record your periods and track your cycle with precision

• Period Prediction: Receive accurate predictions of your next period

• Fertility Window: Identify your most fertile days for planning or avoiding pregnancy

• Menstrual Calendar: Visualize your cycle on an interactive calendar

• Charts & Reports: Analyze your cycle data with detailed charts

• Personalized Notifications: Receive reminders for important stages of your cycle

• Articles & Blog: Access educational information about menstrual health

• AI Assistant: Get answers to your questions about your cycle

• Health Tracking: Record your symptoms and observations

OUR MISSION:

CycleM is committed to providing accurate and reliable tools to help you take control of your reproductive health. We believe every woman deserves access to clear and personalized information about her menstrual cycle.

PRIVACY & SECURITY:

Your data matters to us. We use advanced security measures to protect your personal information and strictly adhere to our privacy policy.''';

  String _getAboutContent() {
    String siteDescription = getStringAsync(SITE_DESCRIPTION, defaultValue: '');
    if (siteDescription.isNotEmpty) {
      return siteDescription;
    }
    
    // Get current language code
    String currentLanguage = getStringAsync(SELECTED_LANGUAGE_CODE, defaultValue: DEFAULT_LANGUAGE);
    
    // Return appropriate language version
    if (currentLanguage == 'en') {
      return _staticAboutContentEnglish;
    } else {
      return _staticAboutContentFrench;
    }
  }

  String _getSiteName() {
    String siteName = getStringAsync(SITE_NAME, defaultValue: '');
    return siteName.isNotEmpty ? siteName : APP_NAME;
  }

  @override
  void initState() {
    super.initState();
    logScreenView("About Us Screen");
  }

  Widget mSocialOption(var value, String key, {var color}) {
    String url = getStringAsync(key);
    if (url.isEmpty) return const SizedBox.shrink();
    return Image.asset(value, height: 30, width: 30, color: color)
        .paddingAll(8)
        .onTap(() => launchUrls(url));
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
              // Custom Header
              Container(
                color: kPrimaryColor,
                child: Column(
                  children: [
                    10.height,
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
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
                          language.about,
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
              // Scrollable Content and Fixed Bottom Container
              Expanded(
                child: Container(
                  width: context.width(),
                  decoration: const BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Stack(
                    children: [
                      SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 150),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            4.height,
                            Text(
                              _getSiteName(),
                              style: boldTextStyle(
                                color: ColorUtils.colorPrimary,
                                size: textFontSize_18,
                              ),
                            ),
                            10.height,
                            Text(
                              _getAboutContent(),
                              style: primaryTextStyle(),
                            ),
                            16.height,
                            Row(
                              children: [
                                Icon(
                                  MaterialIcons.mail_outline,
                                  color: textSecondaryColorGlobal,
                                ),
                                8.width,
                                Text(
                                  getStringAsync(CONTACT_EMAIL,
                                      defaultValue: language.noEmailAvailable),
                                  style: secondaryTextStyle(),
                                ).onTap(() {
                                  commonLaunchUrl(
                                      "mailto:${getStringAsync(CONTACT_EMAIL)}");
                                }),
                              ],
                            ),
                            16.height,
                            Row(
                              children: [
                                Icon(
                                  MaterialIcons.support_agent,
                                  color: textSecondaryColorGlobal,
                                ),
                                8.width,
                                TextButton(
                                  onPressed: () {
                                    commonLaunchUrl(getStringAsync(HELP_SUPPORT,
                                        defaultValue: ''));
                                  },
                                  child: Text(
                                    language.contactSupport,
                                    style:
                                        secondaryTextStyle(color: Colors.blue),
                                  ),
                                ),
                              ],
                            ),
                            16.height,
                            Row(
                              children: [
                                Icon(
                                  Ionicons.md_call_outline,
                                  color: textSecondaryColorGlobal,
                                ),
                                8.width,
                                Text(
                                  getStringAsync(CONTACT_NUMBER,
                                      defaultValue: language.noNumberAvailable),
                                  style: secondaryTextStyle(),
                                ),
                              ],
                            ),
                            16.height,
                          ],
                        ).paddingSymmetric(horizontal: 16, vertical: 8),
                      ),
                      // Fixed Bottom Container
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Center(
                          child: Container(
                            width: context.width() * 0.9,
                            height: 130,
                            child: Column(
                              children: [
                                FutureBuilder<PackageInfo>(
                                  future: PackageInfo.fromPlatform(),
                                  builder: (_, snap) {
                                    if (snap.hasData) {
                                      return Text(
                                        'V ${snap.data!.version.validate()}.${snap.data!.buildNumber.validate()}',
                                        style: primaryTextStyle(),
                                      );
                                    }
                                    return const SizedBox();
                                  },
                                ),
                                16.height,
                                Text(
                                  language.followUs,
                                  style:
                                      primaryTextStyle(size: textFontSize_14),
                                ),
                                2.height,
                                SizedBox(
                                  height: 50,
                                  child: ListView(
                                    shrinkWrap: true,
                                    scrollDirection: Axis.horizontal,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          mSocialOption(
                                                  ic_facebook, FACEBOOK_URL)
                                              .paddingOnly(left: 16, right: 16),
                                          mSocialOption(
                                                  ic_instagram, INSTAGRAM_URL)
                                              .paddingRight(16),
                                          mSocialOption(ic_twitter, TWITTER_URL)
                                              .paddingRight(16),
                                          mSocialOption(ic_linkedin, LINKED_URL)
                                              .paddingRight(16),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                2.height,
                                Text(
                                  getStringAsync(SITE_COPYRIGHT),
                                  style:
                                      secondaryTextStyle(size: textFontSize_12),
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
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

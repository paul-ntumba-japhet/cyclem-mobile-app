import 'package:era_flutter/extensions/extension_util/context_extensions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import '../../extensions/extensions.dart';
import '../../extensions/new_colors.dart';
import '../../extensions/shared_pref.dart';
import '../../languageConfiguration/LanguageDataConstant.dart';
import '../../main.dart';
import '../../utils/app_common.dart';
import '../../utils/app_config.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  // Static privacy policy content extracted from https://cycle-menstruel.com/politique_de_la_protection_des_donnees_personnelles
  String get _staticPrivacyPolicyFrench => '''
    <div style="padding: 20px; font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
      <h1 style="color: #2c3e50; font-size: 24px; margin-bottom: 20px; border-bottom: 2px solid #3498db; padding-bottom: 10px;">Politique de protection des données personnelles</h1>
      
      <h2 style="color: #34495e; font-size: 20px; margin-top: 30px; margin-bottom: 15px;">1. Préambule</h2>
      <p style="margin-bottom: 15px; text-align: justify;">
        En utilisant notre site web et toutes les applications fournies par <strong>CycleM</strong> et en nous fournissant vos données personnelles, vous consentez à ce que toutes ces données soient traitées par nous de la manière et pour les finalités définies dans les règles de confidentialités ci-dessous et conformément aux lois et réglementations en vigueur sur les données personnelles.
      </p>
      
      <h2 style="color: #34495e; font-size: 20px; margin-top: 30px; margin-bottom: 15px;">2. Règles</h2>
      
      <h3 style="color: #34495e; font-size: 18px; margin-top: 25px; margin-bottom: 12px;">a. Respect de la vie privée</h3>
      <p style="margin-bottom: 15px; text-align: justify;">
        <strong>CycleM</strong> s'engage à respecter et à protéger votre vie privée. Certaines informations essentielles sont conservées pendant toute la durée de votre visite sur notre site; nous comprenons l'importance de garder ces données confidentielles et de vous informer de ce que nous en ferons.
      </p>
      
      <h3 style="color: #34495e; font-size: 18px; margin-top: 25px; margin-bottom: 12px;">b. Sécurité et confidentialité des données</h3>
      <p style="margin-bottom: 15px; text-align: justify;">
        La sécurité et la confidentialité de vos données personnelles reste notre principale priorité. CycleM veille à mettre en œuvre les mesures de sécurité nécessaires pour protéger vos données personnelles contre tout accès et toute divulgation, modification, endommagement ou destruction non autorisés.
      </p>
      <p style="margin-bottom: 15px; text-align: justify;">
        Le responsable de traitement met en place des mesures physiques, techniques, informatiques, cryptées et organisationnelles appropriées pour assurer la sécurité et la confidentialité du site, des services et de toute donnée y figurant notamment les données personnelles.
      </p>
      
      <h3 style="color: #34495e; font-size: 18px; margin-top: 25px; margin-bottom: 12px;">c. Vos droits</h3>
      <p style="margin-bottom: 10px; text-align: justify;">
        <strong>1. Droit d'information :</strong><br>
        Vous pouvez exiger que le responsable du traitement vous fournisse toute une série d'informations.
      </p>
      <p style="margin-bottom: 10px; text-align: justify;">
        <strong>2. Droit d'accès et de rectification :</strong><br>
        Vous avez le droit d'obtenir du responsable du traitement la confirmation que vos données personnelles soient ou ne soient pas traitées. Vous avez le droit de demander, dans les meilleurs délais, la rectification ou la possibilité de compléter vos données.
      </p>
      <p style="margin-bottom: 15px; text-align: justify;">
        <strong>3. Droit d'opposition :</strong><br>
        Vous disposez d'un droit d'opposition légitime, sans qu'il y ait lieu de préciser les fondements de la demande ni de justifier légitime lorsque la demande vise à ce que vos informations à caractère personnel soient pas utilisées par des partenaires commerciaux de <strong>CycleM</strong>.
      </p>
      <p style="margin-bottom: 15px; text-align: justify;">
        Pour mieux connaître vos droits, vous pouvez également consulter le site de la commission nationale de l'informatique et des libertés, accessible à l'adresse suivante : <a href="http://cnil.fr" style="color: #3498db;">http://cnil.fr</a>
      </p>
      
      <h3 style="color: #34495e; font-size: 18px; margin-top: 25px; margin-bottom: 12px;">d. Réseaux sociaux</h3>
      <p style="margin-bottom: 15px; text-align: justify;">
        Nous sommes présents sur les réseaux sociaux et nous avons notamment des pages dédiées sur FaceBook, Twitter, Instagram.
      </p>
      <p style="margin-bottom: 15px; text-align: justify;">
        Nous vous rappellons que l'accès à ces réseaux sociaux nécessite votre acceptation de leurs conditions contractuelles comportant des dispositions relatives à la réglementation sur les données personnelles pour les traitements effectués par leurs services.
      </p>
      
      <h3 style="color: #34495e; font-size: 18px; margin-top: 25px; margin-bottom: 12px;">e. Mise à jour de la politique de protection des données personnelles</h3>
      <p style="margin-bottom: 15px; text-align: justify;">
        Nous accordons une attention particulière à vos données. Nous pouvons ainsi être amenés à modifier, compléter ou mettre à jour périodiquement la politique de protection des données personnelles. Nous pourrons aussi apporter des modifications nécessaires afin de respecter la législation et les réglementations en vigueur. Cependant, vos données personnelles seront toujours traitées conformément à la politique en vigueur au moment de leur collecte, sauf si une loi venait à en disposer autrement et serait d'application rétroactive.
      </p>
    </div>
  ''';

  String get _staticPrivacyPolicyEnglish => '''
    <div style="padding: 20px; font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
      <h1 style="color: #2c3e50; font-size: 24px; margin-bottom: 20px; border-bottom: 2px solid #3498db; padding-bottom: 10px;">Personal Data Protection Policy</h1>
      
      <h2 style="color: #34495e; font-size: 20px; margin-top: 30px; margin-bottom: 15px;">1. Preamble</h2>
      <p style="margin-bottom: 15px; text-align: justify;">
        By using our website and all applications provided by <strong>CycleM</strong> and by providing us with your personal data, you consent to all such data being processed by us in the manner and for the purposes defined in the privacy rules below and in accordance with applicable laws and regulations on personal data.
      </p>
      
      <h2 style="color: #34495e; font-size: 20px; margin-top: 30px; margin-bottom: 15px;">2. Rules</h2>
      
      <h3 style="color: #34495e; font-size: 18px; margin-top: 25px; margin-bottom: 12px;">a. Respect for Privacy</h3>
      <p style="margin-bottom: 15px; text-align: justify;">
        <strong>CycleM</strong> is committed to respecting and protecting your privacy. Certain essential information is retained throughout your visit to our site; we understand the importance of keeping this data confidential and informing you of what we will do with it.
      </p>
      
      <h3 style="color: #34495e; font-size: 18px; margin-top: 25px; margin-bottom: 12px;">b. Data Security and Confidentiality</h3>
      <p style="margin-bottom: 15px; text-align: justify;">
        The security and confidentiality of your personal data remains our top priority. CycleM ensures that the necessary security measures are implemented to protect your personal data against any unauthorized access, disclosure, modification, damage or destruction.
      </p>
      <p style="margin-bottom: 15px; text-align: justify;">
        The data controller implements appropriate physical, technical, IT, encrypted and organizational measures to ensure the security and confidentiality of the site, services and all data contained therein, particularly personal data.
      </p>
      
      <h3 style="color: #34495e; font-size: 18px; margin-top: 25px; margin-bottom: 12px;">c. Your Rights</h3>
      <p style="margin-bottom: 10px; text-align: justify;">
        <strong>1. Right to Information:</strong><br>
        You may require the data controller to provide you with a range of information.
      </p>
      <p style="margin-bottom: 10px; text-align: justify;">
        <strong>2. Right of Access and Rectification:</strong><br>
        You have the right to obtain from the data controller confirmation as to whether or not your personal data is being processed. You have the right to request, as soon as possible, the rectification or the possibility to complete your data.
      </p>
      <p style="margin-bottom: 15px; text-align: justify;">
        <strong>3. Right to Object:</strong><br>
        You have a legitimate right to object, without having to specify the grounds for the request or justify it when the request aims to prevent your personal information from being used by <strong>CycleM</strong>'s commercial partners.
      </p>
      <p style="margin-bottom: 15px; text-align: justify;">
        To learn more about your rights, you can also consult the website of the National Commission on Informatics and Liberty, accessible at the following address: <a href="http://cnil.fr" style="color: #3498db;">http://cnil.fr</a>
      </p>
      
      <h3 style="color: #34495e; font-size: 18px; margin-top: 25px; margin-bottom: 12px;">d. Social Networks</h3>
      <p style="margin-bottom: 15px; text-align: justify;">
        We are present on social networks and we have dedicated pages on Facebook, Twitter, Instagram.
      </p>
      <p style="margin-bottom: 15px; text-align: justify;">
        We remind you that access to these social networks requires your acceptance of their contractual terms, which include provisions relating to personal data regulations for processing carried out by their services.
      </p>
      
      <h3 style="color: #34495e; font-size: 18px; margin-top: 25px; margin-bottom: 12px;">e. Update of the Personal Data Protection Policy</h3>
      <p style="margin-bottom: 15px; text-align: justify;">
        We pay particular attention to your data. We may therefore be required to modify, supplement or periodically update the personal data protection policy. We may also make necessary modifications to comply with applicable laws and regulations. However, your personal data will always be processed in accordance with the policy in force at the time of collection, unless a law were to provide otherwise and would be retroactive.
      </p>
    </div>
  ''';

  String _getPrivacyPolicyContent() {
    // Use static content if appStore.privacyPolicy is empty, otherwise use API content
    if (appStore.privacyPolicy.isNotEmpty) {
      return appStore.privacyPolicy;
    }
    
    // Get current language code
    String currentLanguage = getStringAsync(SELECTED_LANGUAGE_CODE, defaultValue: DEFAULT_LANGUAGE);
    
    // Return appropriate language version
    if (currentLanguage == 'en') {
      return _staticPrivacyPolicyEnglish;
    } else {
      return _staticPrivacyPolicyFrench;
    }
  }

  @override
  void initState() {
    super.initState();
    logScreenView("Privacy Policy screen");
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
                padding: const EdgeInsets.symmetric(horizontal: 16),
                color: kPrimaryColor,
                child: Column(
                  children: [
                    10.height,
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
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            language.privacyPolicy,
                            style: boldTextStyle(
                              size: textFontSize_18,
                              weight: FontWeight.w500,
                              color: mainColorText,
                            ),
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
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: HtmlWidget(
                      _getPrivacyPolicyContent(),
                      textStyle: TextStyle(
                        fontSize: 14,
                        color: mainColorText,
                        height: 1.6,
                      ),
                    ),
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

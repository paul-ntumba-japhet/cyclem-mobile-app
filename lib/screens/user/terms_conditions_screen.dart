import 'package:era_flutter/extensions/extension_util/context_extensions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import '../../extensions/extensions.dart';
import '../../extensions/new_colors.dart';
import '../../main.dart';
import '../../utils/app_common.dart';

class TermsConditionsScreen extends StatefulWidget {
  const TermsConditionsScreen({super.key});

  @override
  State<TermsConditionsScreen> createState() => _TermsConditionsScreenState();
}

class _TermsConditionsScreenState extends State<TermsConditionsScreen> {
  // Static terms and conditions content extracted from https://cycle-menstruel.com/conditions_d_utilisation
  String get _staticTermsAndConditions => '''
    <div style="padding: 20px; font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
      <h1 style="color: #2c3e50; font-size: 24px; margin-bottom: 20px; border-bottom: 2px solid #3498db; padding-bottom: 10px;">Conditions d'utilisation</h1>
      
      <h2 style="color: #34495e; font-size: 20px; margin-top: 30px; margin-bottom: 15px;">1. Copyrights</h2>
      <p style="margin-bottom: 15px; text-align: justify;">
        © 2023 CycleM. Tous droits réservés. La mise en ligne et la gestion de ce site Web sont assurées par CycleM. 
        Sauf indication contraire, tout le texte et toutes les informations disponibles sur ce site sont la propriété 
        intellectuelle de CycleM.
      </p>
      
      <h2 style="color: #34495e; font-size: 20px; margin-top: 30px; margin-bottom: 15px;">2. Conditions d'utilisation</h2>
      <p style="margin-bottom: 15px; text-align: justify;">
        Sans préjudice de ses autres droits, CycleM se réserve le droit de prendre des mesures appropriées contre vous 
        si vous ne respectez pas d'une façon ou d'une autre les conditions d'utilisation. Elle peut suspendre votre accès 
        au site, vous interdire l'accès au site, empêcher les ordinateurs qui utilisent votre adresse IP d'accéder au site, 
        contacter votre fournisseur d'accès à Internet pour lui demander de bloquer votre accès au site et/ou vous poursuivre 
        en justice.
      </p>
      
      <p style="margin-top: 20px; margin-bottom: 10px; font-weight: bold; color: #e74c3c;">Il n'est pas permis de :</p>
      <ul style="margin-left: 20px; margin-bottom: 20px; line-height: 1.8;">
        <li style="margin-bottom: 10px;">
          Poster des illustrations, des publications électroniques, des marques, de la musique, des photos, des vidéos ou 
          des articles de ce site sur Internet (sur un site de partage de fichiers, un site de partage de vidéos, un réseau 
          social ou tout autre site).
        </li>
        <li style="margin-bottom: 10px;">
          Diffuser des illustrations, des publications électroniques, des marques, de la musique, des photos, du texte ou 
          des vidéos de ce site, en totalité ou en partie, dans un logiciel ou une application (ainsi que de télécharger ces 
          matières vers un serveur pour utilisation sur une application).
        </li>
        <li style="margin-bottom: 10px;">
          Reproduire, dupliquer, copier, diffuser ou exploiter des illustrations, des photos, du texte ou des vidéos à des 
          fins commerciales ou en échange d'un paiement (même si aucun profit n'est réalisé).
        </li>
        <li style="margin-bottom: 10px;">
          Détourner l'usage de ce site ou de ses services, par exemple en perturber le fonctionnement ou y accéder par une 
          méthode autre que celle qui est clairement indiquée.
        </li>
        <li style="margin-bottom: 10px;">
          Utiliser ce site d'une façon qui cause, ou pourrait causer, des dommages au site ou encore dégrader sa disponibilité 
          ou son accessibilité ; utiliser ce site d'une façon illégale, frauduleuse ou nuisible ; utiliser ce site dans une 
          intention illégale, frauduleuse ou nuisible ou en rapport avec une activité de même nature.
        </li>
      </ul>
      
      <h2 style="color: #34495e; font-size: 20px; margin-top: 30px; margin-bottom: 15px;">3. Violation des conditions d'utilisation</h2>
      <p style="margin-bottom: 15px; text-align: justify;">
        Sans préjudice de ses autres droits, CycleM se réserve le droit de prendre des mesures appropriées contre vous 
        si vous ne respectez pas d'une façon ou d'une autre les conditions d'utilisation. Elle peut suspendre votre accès 
        au site, vous interdire l'accès au site, empêcher les ordinateurs qui utilisent votre adresse IP d'accéder au site, 
        contacter votre fournisseur d'accès à Internet pour lui demander de bloquer votre accès au site et/ou vous poursuivre 
        en justice.
      </p>
      
      <div style="margin-top: 30px; padding: 15px; background-color: #ecf0f1; border-left: 4px solid #3498db; border-radius: 5px;">
        <p style="margin: 0; font-style: italic; color: #7f8c8d;">
          Votre date a été envoyée avec succès, vous allez recevoir un SMS avec le calcul de vos dates importantes de votre 
          cycle menstruel.
        </p>
      </div>
    </div>
  ''';

  @override
  void initState() {
    super.initState();
    logScreenView("TnC screen");
  }

  @override
  Widget build(BuildContext context) {
    // Use static content if appStore.termsCondition is empty, otherwise use API content
    String contentToDisplay = appStore.termsCondition.isNotEmpty 
        ? appStore.termsCondition 
        : _staticTermsAndConditions;
    
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
                            language.termsAndConditions,
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
                      contentToDisplay,
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

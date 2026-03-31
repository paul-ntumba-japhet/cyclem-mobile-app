import '../model/common/article_models/article_model.dart';
import '../utils/app_images.dart';
import '../utils/app_constants.dart';
import '../extensions/shared_pref.dart';
import '../languageConfiguration/LanguageDataConstant.dart';
import '../languageConfiguration/LanguageDefaultJson.dart';

/// Static blog posts data
/// These are hardcoded blog posts that will be displayed alongside API-fetched articles
class StaticBlogPosts {
  /// Get all static blog posts based on current language
  static List<Article> getStaticBlogPosts() {
    final languageCode = getStringAsync(SELECTED_LANGUAGE_CODE, defaultValue: defaultLanguageCode);
    return [
      _getPost1(languageCode),
      _getPost2(languageCode),
    ];
  }

  /// Article 1: Understanding the Standard Days Method
  static Article _getPost1(String languageCode) {
    if (languageCode == 'en') {
      return Article(
        id: -1, // Negative ID to distinguish from API posts
        name: 'Understanding the Standard Days Method',
        description: '''
<h2>Introduction to the Standard Days Method</h2>
<p>The Standard Days Method is based on established research in reproductive physiology and statistical analysis. The fertile window (the days of the menstrual cycle during which a person can become pregnant) begins approximately five days before ovulation and lasts until 24 hours after ovulation. Indeed, sperm remain viable in the female reproductive tract for up to five days and the egg can be fertilized for up to 24 hours after ovulation. Therefore, the fertile window lasts approximately 6 days per cycle.</p>

<p>However, during a given cycle, potential fertile days can vary because the exact timing of ovulation can vary from cycle to cycle. Ovulation generally occurs around the middle of the menstrual cycle (+/- 3 days).</p>

<p>Researchers at the Institute for Reproductive Health identified this extended potential fertile window using a computer simulation that took into account the probability of pregnancy, the probability of ovulation occurring on different days of the cycle, and the variability of cycle length from woman to woman and from cycle to cycle. Their analysis revealed that avoiding unprotected intercourse on days 8 to 19 of the cycle offered maximum protection against pregnancy while minimizing the number of days needed to avoid unprotected intercourse.</p>

<p>People with menstrual cycles of 26 to 32 days can use CycleM and the Standard Days Method to prevent pregnancy by avoiding unprotected intercourse during the 12 fertile days identified by the method, days 8 to 19 of the cycle.</p>

<h2>Effectiveness of the Standard Days Method</h2>
<p>In effectiveness studies conducted in several countries, researchers found that the Standard Days Method was more than 95% effective in preventing pregnancy when used correctly and 88% with typical use. This means that when the family planning method is used correctly, fewer than 5 out of 100 people who track their cycles consistently and do not have unprotected intercourse on days 8 to 19 of the cycle will become pregnant during the first year of using the Standard Days Method. In typical use, when the method is sometimes used incorrectly or inconsistently, 12 out of 100 people will become pregnant.</p>

<p>To read the original research article, click here: <a href="https://cycle-menstruel.com/articles">Effectiveness of a New Family Planning Method: The Standard Days Method</a>. Based on this research, CycleM compares favorably to other contraceptive options both in terms of correct use effectiveness and typical use effectiveness.</p>

<h2>Implications for Using This Natural Family Planning Option</h2>
<p>If a person does not want to become pregnant, they should use a backup method of contraception, such as condoms, or not have sexual intercourse on days 8 to 19 of the cycle. On the other hand, if a person wants to become pregnant, these are the days when pregnancy is most likely. The CycleM platform and its Mobile, USSD and SMS applications are based on the Standard Days Method to enable correct and effective use of this method.</p>
''',
        articleImage: article_image_1,
        type: FREE, // Free article
        bookmark: 0,
        goalType: 0, // Cycle tracking goal
        goalTypeName: 'Cycle Tracking',
        createdAt: '2023-04-15',
        updatedAt: '2023-04-15',
        tags: null,
        expertData: null,
        articleReference: null,
      );
    } else {
      // French version (default)
      return Article(
        id: -1, // Negative ID to distinguish from API posts
        name: 'Comprendre la méthode des jours fixes',
        description: '''
<h2>Introduction à la méthode des jours fixes</h2>
<p>La méthode des jours fixes est basée sur des recherches établies en physiologie de la reproduction et sur des analyses statistiques. La fenêtre fertile (les jours du cycle menstruel pendant lesquels une personne peut tomber enceinte) commence environ cinq jours avant l'ovulation et dure jusqu'à 24 heures après l'ovulation. En effet, les spermatozoïdes restent viables dans l'appareil reproducteur féminin jusqu'à cinq jours et l'ovule peut être fécondé jusqu'à 24 heures après l'ovulation. Par conséquent, la fenêtre fertile dure environ 6 jours par cycle.</p>

<p>Cependant, au cours d'un cycle donné, les jours fertiles potentiels peuvent varier en raison du fait que le moment exact de l'ovulation peut varier d'un cycle à l'autre. L'ovulation se produit généralement vers le milieu du cycle menstruel (+/- 3 jours).</p>

<p>Des chercheurs de l'Institute for Reproductive Health ont identifié cette fenêtre fertile potentielle étendue en utilisant une simulation informatique qui a pris en compte la probabilité de grossesse, la probabilité d'ovulation survenant à différents jours du cycle et la variabilité de la durée du cycle d'une femme à l'autre et d'un cycle à l'autre. Leur analyse a révélé qu'éviter les rapports sexuels non protégés les jours 8 à 19 du cycle offrait une protection maximale contre la grossesse tout en minimisant le nombre de jours nécessaires pour éviter les rapports sexuels non protégés.</p>

<p>Les personnes ayant des cycles menstruels de 26 à 32 jours peuvent utiliser CycleM et la méthode des jours fixes pour prévenir une grossesse en évitant les rapports sexuels non protégés pendant les 12 jours fertiles identifiés par la méthode, les jours 8 à 19 du cycle.</p>

<h2>Efficacité de la méthode des jours fixes</h2>
<p>Dans des études d'efficacité menées dans plusieurs pays, les chercheurs ont découvert que la méthode des jours fixes était efficace à plus de 95 % pour prévenir la grossesse lorsqu'elle était utilisée correctement et à 88 % avec une utilisation typique. Cela signifie que lorsque la méthode de planification familiale est utilisée correctement, moins de 5 personnes sur 100 qui suivent leurs cycles de manière cohérente et n'ont pas de rapports sexuels non protégés les jours 8 à 19 du cycle tomberont enceintes au cours de la première année d'utilisation de la méthode des jours fixes. En utilisation typique, lorsque la méthode est parfois utilisée de manière incorrecte ou incohérente, 12 personnes sur 100 tomberont enceintes.</p>

<p>Pour lire l'article de recherche original, cliquez ici : <a href="https://cycle-menstruel.com/articles">Efficacité d'une nouvelle méthode de planification familiale : la méthode des jours fixes</a>. Sur la base de cette recherche, CycleM se compare favorablement à d'autres options contraceptives à la fois en termes d'efficacité d'utilisation correcte et d'efficacité d'utilisation typique.</p>

<h2>Implications pour l'utilisation de cette option de planification familiale naturelle</h2>
<p>Si une personne ne veut pas tomber enceinte, elle doit utiliser une méthode de contraception d'appoint, comme les préservatifs, ou ne pas avoir de relations sexuelles les jours 8 à 19 du cycle. D'un autre côté, si une personne veut tomber enceinte, ce sont les jours où la grossesse est la plus probable. La plateforme CycleM et ses applications Mobile, USSD et SMS sont basées sur la méthode des jours fixes pour permettre une utilisation correcte et efficace de cette méthode.</p>
''',
        articleImage: article_image_1,
        type: FREE, // Free article
        bookmark: 0,
        goalType: 0, // Cycle tracking goal
        goalTypeName: 'Cycle Tracking',
        createdAt: '2023-04-15',
        updatedAt: '2023-04-15',
        tags: null,
        expertData: null,
        articleReference: null,
      );
    }
  }

  /// Article 2: How can I prevent pregnancy using this method
  static Article _getPost2(String languageCode) {
    if (languageCode == 'en') {
      return Article(
        id: -2, // Negative ID to distinguish from API posts
        name: 'How can I prevent pregnancy using this method',
        description: '''
<p>To prevent pregnancy using CycleM, avoid sexual intercourse or use condoms on fertile days (cycle days 8 to 19). Make sure to track the duration of your cycles using CycleM to determine if your cycles fall within the 26 to 32 day range and stay within this range.</p>

<h2>Effectiveness of the Standard Days Method</h2>
<p>CycleM uses the Standard Days Method and is more than 95% effective in preventing pregnancy when used correctly and 88% with typical use. This means that when used correctly, fewer than 5 out of 100 people who track their cycles consistently and do not have unprotected intercourse on days 8 to 19 of the cycle will become pregnant during the first year of use. When sometimes used incorrectly or inconsistently, 12 out of 100 people will become pregnant.</p>

<h2>What about other ways to prevent pregnancy</h2>
<p>There are other fertility awareness-based methods that can be used to avoid pregnancy. These methods typically require tracking fertility symptoms, particularly cervical mucus and basal body temperature. These methods are effective with correct and consistent use, but less effective in typical use. They also require daily action and typically require taking a course with a certified method instructor.</p>

<p>The Standard Days Method and cycle beads were designed to make fertility awareness easier. They eliminate subjective observations and detailed tracking, which can be error-prone. The method was designed to be easy to teach and use so that it can be used immediately without extensive training.</p>
''',
        articleImage: article_image_2,
        type: FREE, // Free article
        bookmark: 0,
        goalType: 0, // Cycle tracking goal
        goalTypeName: 'Cycle Tracking',
        createdAt: '2023-05-20',
        updatedAt: '2023-05-20',
        tags: null,
        expertData: null,
        articleReference: null,
      );
    } else {
      // French version (default)
      return Article(
        id: -2, // Negative ID to distinguish from API posts
        name: 'Comment puis-je prévenir la grossesse en utilisant cette méthode',
        description: '''
<p>Pour prévenir une grossesse en utilisant CycleM, évitez les rapports sexuels ou utilisez des préservatifs les jours fertiles (jours du cycle 8 à 19). Assurez-vous de suivre la durée de vos cycles à l'aide de CycleM pour déterminer si vos cycles se situent dans la plage de 26 à 32 jours et rester dans cette plage.</p>

<h2>Efficacité de la méthode des jours fixes</h2>
<p>CycleM utilise la méthode des jours fixes et est efficace pratiquement à plus de 95 % pour prévenir la grossesse lorsqu'il est utilisé correctement et à 88 % avec une utilisation typique. Cela signifie que lorsqu'il est utilisé correctement, moins de 5 personnes sur 100 qui suivent leurs cycles de manière cohérente et n'ont pas de rapports sexuels non protégés les jours 8 à 19 du cycle tomberont enceintes au cours de la première année d'utilisation. Lorsqu'il est parfois utilisé de manière incorrecte ou incohérente, 12 personnes sur 100 tomberont enceintes.</p>

<h2>Qu'en est-il des autres moyens de prévenir la grossesse</h2>
<p>Il existe d'autres méthodes basées sur la connaissance de la fertilité qui peuvent être utilisées pour éviter une grossesse. Ces méthodes nécessitent généralement le suivi des symptômes de fertilité, en particulier la glaire cervicale et la température basale du corps. Ces méthodes sont efficaces avec une utilisation correcte et cohérente, mais moins efficaces dans une utilisation typique. Ils nécessitent également une action quotidienne et nécessitent généralement de suivre un cours auprès d'un instructeur certifié de la méthode.</p>

<p>La méthode des jours fixes et les colliers du cycle ont été conçus pour faciliter la prise de conscience de la fertilité. Ils éliminent les observations subjectives et le suivi détaillé, qui peuvent être sujets à erreur. La méthode a été conçue pour être facile à enseigner et à utiliser afin qu'elle puisse être utilisée immédiatement sans formation prolongée.</p>
''',
        articleImage: article_image_2,
        type: FREE, // Free article
        bookmark: 0,
        goalType: 0, // Cycle tracking goal
        goalTypeName: 'Cycle Tracking',
        createdAt: '2023-05-20',
        updatedAt: '2023-05-20',
        tags: null,
        expertData: null,
        articleReference: null,
      );
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:intl/intl.dart';
import '../../extensions/extensions.dart';
import '../../extensions/new_colors.dart';
import '../../main.dart';
import '../../data/static_blog_posts.dart';
import '../../data/blog_post_metadata.dart';
import '../../languageConfiguration/LanguageDataConstant.dart';
import '../../languageConfiguration/LanguageDefaultJson.dart';

/// Screen for Static Blog Post 2: Comment puis-je prévenir la grossesse en utilisant cette méthode
class StaticBlogPost2Screen extends StatelessWidget {
  const StaticBlogPost2Screen({super.key});

  @override
  Widget build(BuildContext context) {
    // Use Observer to rebuild when language changes
    return Observer(
      builder: (context) {
        final article = StaticBlogPosts.getStaticBlogPosts()[1];
        final metadata = BlogPostMetadata.getBlogPostMetadata(article.id);
        
        return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: mainColorLight,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: mainColorLight,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: mainColorText),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            language.article,
            style: boldTextStyle(
              color: mainColorText,
              size: 18,
              weight: FontWeight.w500,
            ),
          ),
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero image
              Container(
                width: double.infinity,
                height: 250,
                child: Image.asset(
                  'assets/menstruation-2.avif',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: primaryColor.withOpacity(0.1),
                      child: const Icon(
                        Icons.image_not_supported,
                        size: 48,
                        color: Colors.grey,
                      ),
                    );
                  },
                ),
              ),
              
              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      article.name ?? '',
                      style: boldTextStyle(
                        color: mainColorText,
                        size: 24,
                        weight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Author and Date
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          metadata?.author ?? language.unknownAuthor,
                          style: primaryTextStyle(
                            color: Colors.grey[700],
                            size: 14,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          metadata != null
                              ? _formatDate(metadata.publishDate)
                              : '',
                          style: primaryTextStyle(
                            color: Colors.grey[700],
                            size: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Divider
                    Divider(color: Colors.grey[300]),
                    const SizedBox(height: 24),
                    
                    // HTML Content
                    HtmlWidget(
                      article.description ?? '',
                      textStyle: TextStyle(
                        fontSize: 16,
                        height: 1.6,
                        color: mainColorText,
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
        );
      },
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateFormat('yyyy-MM-dd').parse(dateString);
      final locale = getStringAsync(SELECTED_LANGUAGE_CODE, defaultValue: defaultLanguageCode);
      return DateFormat('d MMMM yyyy', locale).format(date);
    } catch (e) {
      return dateString;
    }
  }
}

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:intl/intl.dart';
import '../../data/static_blog_posts.dart';
import '../../data/blog_post_metadata.dart';
import '../../model/common/article_models/article_model.dart';
import '../../extensions/extensions.dart';
import '../../main.dart';
import '../../languageConfiguration/LanguageDataConstant.dart';
import '../../languageConfiguration/LanguageDefaultJson.dart';
import '../user/static_blog_post_1_screen.dart';
import '../user/static_blog_post_2_screen.dart';
import '../user/blog_detail_screen.dart';

/// Blog carousel widget displaying static blog posts
class BlogCarouselWidget extends StatefulWidget {
  const BlogCarouselWidget({super.key});

  @override
  State<BlogCarouselWidget> createState() => _BlogCarouselWidgetState();
}

class _BlogCarouselWidgetState extends State<BlogCarouselWidget> {
  int _currentSlideIndex = 0;
  final CarouselSliderController _carouselController = CarouselSliderController();


  /// Format date from YYYY-MM-DD to readable format
  String formatDate(String dateString) {
    try {
      final date = DateFormat('yyyy-MM-dd').parse(dateString);
      final locale = getStringAsync(SELECTED_LANGUAGE_CODE, defaultValue: defaultLanguageCode);
      return DateFormat('d MMMM yyyy', locale).format(date);
    } catch (e) {
      return dateString;
    }
  }

  /// Get image path for article based on ID
  String _getImagePath(Article article) {
    switch (article.id) {
      case -1:
        return 'assets/menstruation-1.jpg';
      case -2:
        return 'assets/menstruation-2.avif';
      default:
        return article.articleImage ?? '';
    }
  }

  /// Build a single carousel slide
  Widget _buildSlide(Article article) {
    final metadata = BlogPostMetadata.getBlogPostMetadata(article.id);
    final imagePath = _getImagePath(article);
    
    // Debug: Print image path
    print('🖼️ Loading image for article ${article.id}: $imagePath');
    
    return GestureDetector(
      onTap: () {
        // Navigate to dedicated screen based on article ID
        if (article.id == -1) {
          StaticBlogPost1Screen().launch(context);
        } else if (article.id == -2) {
          StaticBlogPost2Screen().launch(context);
        } else {
          // Fallback to regular blog detail screen for other articles
          BlogDetailScreen(
            article: article,
            onBookmarkUpdated: (updatedArticle) {
              // Handle bookmark update if needed
            },
          ).launch(context);
        }
      },
      child: Container(
        width: double.infinity,
        height: 220,
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 2,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.zero,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background image using article_image_1 or article_image_2
              if (imagePath.isNotEmpty)
                Image.asset(
                  imagePath,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    print('❌ Error loading image: $imagePath');
                    print('   Error: $error');
                    return Container(
                      color: primaryColor.withOpacity(0.1),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.image_not_supported,
                            size: 48,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Image not found: $imagePath',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  },
                )
              else
                Container(
                  color: primaryColor.withOpacity(0.1),
                  child: const Icon(
                    Icons.image_not_supported,
                    size: 48,
                    color: Colors.grey,
                  ),
                ),
              
              // Gradient overlay for better text readability
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
              ),
              
              // Content overlay
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        article.name ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              offset: Offset(0, 1),
                              blurRadius: 3,
                              color: Colors.black54,
                            ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      
                      // Author and Date row
                      Row(
                        children: [
                          // Author icon
                          const Icon(
                            Icons.person_outline,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          // Author name
                          Expanded(
                            child: Text(
                              metadata?.author ?? language.unknownAuthor,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                shadows: [
                                  Shadow(
                                    offset: Offset(0, 1),
                                    blurRadius: 2,
                                    color: Colors.black54,
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Date icon
                          const Icon(
                            Icons.calendar_today,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          // Publish date
                          Text(
                            metadata != null
                                ? formatDate(metadata.publishDate)
                                : '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              shadows: [
                                Shadow(
                                  offset: Offset(0, 1),
                                  blurRadius: 2,
                                  color: Colors.black54,
                                ),
                              ],
                            ),
                          ),
                        ],
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

  /// Build carousel indicators
  Widget _buildIndicators(int itemCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        itemCount,
        (index) => Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _currentSlideIndex == index
                ? primaryColor
                : Colors.white.withOpacity(0.5),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use Observer to rebuild when language changes
    return Observer(
      builder: (context) {
        // Access appStore.selectedLanguage to ensure Observer tracks language changes
        // This ensures the carousel rebuilds when language is switched
        appStore.selectedLanguage; // Observer tracks this observable
        final staticPosts = StaticBlogPosts.getStaticBlogPosts();
        
        if (staticPosts.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              CarouselSlider.builder(
                carouselController: _carouselController,
                itemCount: staticPosts.length,
                options: CarouselOptions(
                  height: 220,
                  viewportFraction: 1.0,
                  autoPlay: true,
                  autoPlayInterval: const Duration(seconds: 5),
                  autoPlayAnimationDuration: const Duration(milliseconds: 800),
                  autoPlayCurve: Curves.fastOutSlowIn,
                  pauseAutoPlayOnTouch: true,
                  pauseAutoPlayOnManualNavigate: true,
                  enlargeCenterPage: false,
                  onPageChanged: (index, reason) {
                    setState(() {
                      _currentSlideIndex = index;
                    });
                  },
                ),
                itemBuilder: (context, index, realIndex) {
                  return _buildSlide(staticPosts[index]);
                },
              ),
              const SizedBox(height: 12),
              _buildIndicators(staticPosts.length),
            ],
          ),
        );
      },
    );
  }
}

/// Blog post metadata helper
/// Provides author and publish date information for static blog posts
class BlogPostMetadata {
  final String author;
  final String publishDate;

  BlogPostMetadata({required this.author, required this.publishDate});

  /// Get blog post metadata by article ID
  static BlogPostMetadata? getBlogPostMetadata(int? articleId) {
    switch (articleId) {
      case -1:
        return BlogPostMetadata(
          author: 'Roger Ntumba',
          publishDate: '2023-04-15',
        );
      case -2:
        return BlogPostMetadata(
          author: 'Sidieu Muyila',
          publishDate: '2023-05-20',
        );
      default:
        return null;
    }
  }
}

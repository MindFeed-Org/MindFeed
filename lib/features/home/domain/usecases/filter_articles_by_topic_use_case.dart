import 'package:mind_feed/core/articles/domain/entities/article_entity.dart';

class FilterArticlesByTopicUseCase {
  const FilterArticlesByTopicUseCase();

  List<ArticleEntity> call(
    List<ArticleEntity> articles,
    String selectedTopic, {
    String? selectedTopicCategoryId,
    String? selectedTopicCategorySlug,
  }) {
    return filterItems<ArticleEntity>(
      items: articles,
      selectedTopic: selectedTopic,
      badgeOf: (a) => a.badge,
      categoryIdOf: (a) => a.categoryId,
      categorySlugOf: (a) => a.categorySlug,
      tagsOf: (a) => a.tags,
      isLiveOf: (a) => a.isLive,
      selectedTopicCategoryId: selectedTopicCategoryId,
      selectedTopicCategorySlug: selectedTopicCategorySlug,
    );
  }

  static List<T> filterItems<T>({
    required List<T> items,
    required String selectedTopic,
    required String Function(T) badgeOf,
    String? Function(T)? categoryIdOf,
    required String? Function(T) categorySlugOf,
    required List<String> Function(T) tagsOf,
    required bool Function(T) isLiveOf,
    String? selectedTopicCategoryId,
    String? selectedTopicCategorySlug,
  }) {
    if (selectedTopic == 'All') {
      return items;
    }
    if (selectedTopic == 'Trending') {
      return items
          .where((s) => isLiveOf(s) || badgeOf(s) == 'LIVE' || badgeOf(s) == 'TECH')
          .toList();
    }

    final targetId = selectedTopicCategoryId?.trim();
    final acceptedTerms = _resolveAcceptedTerms(
      selectedTopic,
      selectedTopicCategorySlug: selectedTopicCategorySlug,
    );
    if ((targetId == null || targetId.isEmpty) && acceptedTerms.isEmpty) {
      return const [];
    }

    return items
        .where(
          (item) => _matchesItem(
            item: item,
            targetCategoryId: targetId,
            acceptedTerms: acceptedTerms,
            badgeOf: badgeOf,
            categoryIdOf: categoryIdOf,
            categorySlugOf: categorySlugOf,
            tagsOf: tagsOf,
          ),
        )
        .toList();
  }

  static String _normalizeRaw(String value) =>
      value.toLowerCase().trim().replaceAll('_', '-');

  static String _toSlug(String normalized) => normalized
      .replaceAll('&', 'and')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');

  static String _toCompactSlug(String normalized) => normalized
      .replaceAll('&', ' ')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');

  static Set<String> _resolveAcceptedTerms(
    String topic, {
    String? selectedTopicCategorySlug,
  }) {
    final terms = <String>{};
    void addForms(String? raw) {
      if (raw == null) {
        return;
      }
      final normalized = _normalizeRaw(raw);
      if (normalized.isEmpty) {
        return;
      }
      terms.add(normalized);
      final slug = _toSlug(normalized);
      if (slug.isNotEmpty) {
        terms.add(slug);
      }
      final compact = _toCompactSlug(normalized);
      if (compact.isNotEmpty) {
        terms.add(compact);
      }
    }

    addForms(topic);
    addForms(selectedTopicCategorySlug);
    return terms;
  }

  static bool _matchesCandidate(String candidate, Set<String> acceptedTerms) {
    final normalized = _normalizeRaw(candidate);
    if (normalized.isEmpty) {
      return false;
    }
    return acceptedTerms.contains(normalized) ||
        acceptedTerms.contains(_toSlug(normalized)) ||
        acceptedTerms.contains(_toCompactSlug(normalized));
  }

  static bool _matchesItem<T>({
    required T item,
    required String? targetCategoryId,
    required Set<String> acceptedTerms,
    required String Function(T) badgeOf,
    required String? Function(T)? categoryIdOf,
    required String? Function(T) categorySlugOf,
    required List<String> Function(T) tagsOf,
  }) {
    final itemCategoryId = categoryIdOf?.call(item)?.trim();
    if (targetCategoryId != null &&
        targetCategoryId.isNotEmpty &&
        itemCategoryId != null &&
        itemCategoryId.isNotEmpty) {
      return itemCategoryId == targetCategoryId;
    }

    final rawSlug = categorySlugOf(item);
    if (rawSlug != null && rawSlug.trim().isNotEmpty) {
      return _matchesCandidate(rawSlug, acceptedTerms);
    }

    final badgeNormalized = _normalizeRaw(badgeOf(item));
    if (_matchesCandidate(badgeNormalized, acceptedTerms)) {
      return true;
    }
    if (badgeNormalized.length >= 4 &&
        acceptedTerms.any((term) => term.startsWith(badgeNormalized))) {
      return true;
    }

    for (final tag in tagsOf(item)) {
      if (_matchesCandidate(tag, acceptedTerms)) {
        return true;
      }
    }
    return false;
  }
}

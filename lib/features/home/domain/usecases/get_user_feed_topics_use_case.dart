import 'package:flutter/foundation.dart';

import 'package:mind_feed/core/errors/failures.dart';
import 'package:mind_feed/features/profile/domain/repos/profile_repo.dart';

class FeedTopicRef {
  final String? id;
  final String? slug;

  const FeedTopicRef({this.id, this.slug});
}

class UserFeedTopicsResult {
  final List<String> topics;
  final List<String> preferredCategoryIds;
  final Map<String, FeedTopicRef> topicRefs;

  const UserFeedTopicsResult({
    required this.topics,
    required this.preferredCategoryIds,
    this.topicRefs = const {},
  });
}

class GetUserFeedTopicsUseCase {
  final ProfileRepository? profileRepository;

  const GetUserFeedTopicsUseCase({this.profileRepository});

  static List<String> buildInitialTopics(List<String>? cachedCategories) {
    if (cachedCategories == null || cachedCategories.isEmpty) {
      return const ['All'];
    }
    final topics = <String>['All'];
    for (final cat in cachedCategories) {
      final trimmed = cat.trim();
      if (trimmed.isNotEmpty && !topics.contains(trimmed)) {
        topics.add(trimmed);
      }
    }
    return topics;
  }

  Future<UserFeedTopicsResult> call({
    String? userId,
    bool shouldQueryRemote = true,
    List<String>? cachedCategories,
  }) async {
    final preferredCategoryIds = <String>[];
    final dynamicTopics = <String>[];
    final topicRefs = <String, FeedTopicRef>{};
    var remoteSucceeded = true;

    if (profileRepository != null && shouldQueryRemote) {
      remoteSucceeded = await _loadRemoteFavorites(
        userId ?? '',
        preferredCategoryIds,
        dynamicTopics,
        topicRefs,
      );
    }

    if (dynamicTopics.isEmpty && cachedCategories != null) {
      _appendCachedTopics(cachedCategories, dynamicTopics);
    }

    final needsMetadata = dynamicTopics.any((topic) {
      final ref = topicRefs[topic.toLowerCase()];
      return ref == null || ref.id == null || ref.slug == null;
    });

    if (remoteSucceeded &&
        dynamicTopics.isNotEmpty &&
        profileRepository != null &&
        (preferredCategoryIds.isEmpty || needsMetadata)) {
      await _resolveCategoryIdsByName(
        dynamicTopics,
        preferredCategoryIds,
        topicRefs,
      );
    }

    return UserFeedTopicsResult(
      topics: <String>['All', ...dynamicTopics],
      preferredCategoryIds: preferredCategoryIds,
      topicRefs: Map<String, FeedTopicRef>.unmodifiable(topicRefs),
    );
  }

  Future<bool> _loadRemoteFavorites(
    String userId,
    List<String> preferredIds,
    List<String> dynamicTopics,
    Map<String, FeedTopicRef> topicRefs,
  ) async {
    try {
      final result = await profileRepository!.getFavoriteCategories(userId);
      final isSuccess = result.when(
        success: (favs) {
          _parseFavoriteMaps(favs, preferredIds, dynamicTopics, topicRefs);
          return true;
        },
        failure: (_) => false,
      );
      return isSuccess;
    } catch (_) {
      const failure = CacheFailure("there's an error, Please try again later");
      debugPrint(failure.message);
      return false;
    }
  }

  void _parseFavoriteMaps(
    List<Map<String, dynamic>> favs,
    List<String> preferredIds,
    List<String> dynamicTopics,
    Map<String, FeedTopicRef> topicRefs,
  ) {
    for (final f in favs) {
      final nested = f['categories'] as Map<String, dynamic>?;
      final catId = (f['category_id'] as String?) ?? (nested?['id'] as String?);
      if (catId != null && catId.isNotEmpty && !preferredIds.contains(catId)) {
        preferredIds.add(catId);
      }
      final slug = (f['slug'] as String?) ??
          (f['category_slug'] as String?) ??
          (nested?['slug'] as String?);
      final name = _extractCategoryName(f);
      if (name != null &&
          name.isNotEmpty &&
          name != 'All' &&
          !dynamicTopics.contains(name)) {
        dynamicTopics.add(name);
        if ((catId != null && catId.isNotEmpty) ||
            (slug != null && slug.trim().isNotEmpty)) {
          topicRefs[name.toLowerCase()] = FeedTopicRef(
            id: catId?.trim(),
            slug: slug?.trim(),
          );
        }
      }
    }
  }

  String? _extractCategoryName(Map<String, dynamic> map) {
    final raw = (map['name'] as String?) ??
        (map['category_name'] as String?) ??
        (map['categories'] as Map<String, dynamic>?)?['name'] as String?;
    return raw?.trim();
  }

  void _appendCachedTopics(
    List<String> cachedCategories,
    List<String> dynamicTopics,
  ) {
    for (final rawName in cachedCategories) {
      final name = rawName.trim();
      if (name.isNotEmpty &&
          name != 'All' &&
          !dynamicTopics.contains(name)) {
        dynamicTopics.add(name);
      }
    }
  }

  Future<void> _resolveCategoryIdsByName(
    List<String> dynamicTopics,
    List<String> preferredIds,
    Map<String, FeedTopicRef> topicRefs,
  ) async {
    try {
      final catResult = await profileRepository!.getCategories();
      catResult.when(
        success: (allCats) => _matchCategoryIds(
          allCats,
          dynamicTopics,
          preferredIds,
          topicRefs,
        ),
        failure: (_) {},
      );
    } catch (_) {
      const failure = CacheFailure("there's an error, Please try again later");
      debugPrint(failure.message);
    }
  }

  void _matchCategoryIds(
    List<Map<String, dynamic>> allCats,
    List<String> dynamicTopics,
    List<String> preferredIds,
    Map<String, FeedTopicRef> topicRefs,
  ) {
    final lowerFavs = dynamicTopics.map((e) => e.toLowerCase()).toSet();
    for (final c in allCats) {
      final name = (c['name'] as String?)?.trim();
      final id = (c['id'] as String?)?.trim();
      final slug = (c['slug'] as String?)?.trim();
      if (name != null && lowerFavs.contains(name.toLowerCase())) {
        if (id != null && id.isNotEmpty && !preferredIds.contains(id)) {
          preferredIds.add(id);
        }
        topicRefs[name.toLowerCase()] = FeedTopicRef(id: id, slug: slug);
      }
    }
  }
}

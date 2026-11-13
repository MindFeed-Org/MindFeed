import 'package:equatable/equatable.dart';

import 'package:mind_feed/core/design/editorial_models.dart';
import 'package:mind_feed/features/home/domain/usecases/filter_articles_by_topic_use_case.dart';
import 'package:mind_feed/features/home/domain/usecases/get_user_feed_topics_use_case.dart';

enum HomeFeedStatus { initial, loading, success, error }

enum SwipeSaveStatus { saved, unauthenticated, failed }

sealed class HomeFeedState extends Equatable {
  final HomeFeedStatus status;
  final List<EditorialNewsItem> allArticles;
  final List<String> topics;
  final String selectedTopic;
  final Map<String, FeedTopicRef> topicRefs;
  final String? errorMessage;

  const HomeFeedState({
    required this.status,
    this.allArticles = const [],
    this.topics = const ['All'],
    this.selectedTopic = 'All',
    this.topicRefs = const {},
    this.errorMessage,
  });

  List<EditorialNewsItem> get filteredArticles {
    final ref = topicRefs[selectedTopic.toLowerCase().trim()];
    return FilterArticlesByTopicUseCase.filterItems<EditorialNewsItem>(
      items: allArticles,
      selectedTopic: selectedTopic,
      badgeOf: (s) => s.badge,
      categoryIdOf: (s) => s.categoryId,
      categorySlugOf: (s) => s.categorySlug,
      tagsOf: (s) => s.tags,
      isLiveOf: (s) => s.isLive,
      selectedTopicCategoryId: ref?.id,
      selectedTopicCategorySlug: ref?.slug,
    );
  }

  HomeFeedState copyWith({
    HomeFeedStatus? status,
    List<EditorialNewsItem>? allArticles,
    List<String>? topics,
    String? selectedTopic,
    Map<String, FeedTopicRef>? topicRefs,
    String? errorMessage,
    bool clearError = false,
  }) {
    final nextStatus = status ?? this.status;
    final nextArticles = allArticles ?? this.allArticles;
    final nextTopics = topics ?? this.topics;
    final nextTopic = selectedTopic ?? this.selectedTopic;
    final nextTopicRefs = topicRefs ?? this.topicRefs;
    final nextError = clearError ? null : (errorMessage ?? this.errorMessage);

    return switch (nextStatus) {
      HomeFeedStatus.initial => HomeFeedInitial(
          allArticles: nextArticles,
          topics: nextTopics,
          selectedTopic: nextTopic,
          topicRefs: nextTopicRefs,
        ),
      HomeFeedStatus.loading => HomeFeedLoading(
          allArticles: nextArticles,
          topics: nextTopics,
          selectedTopic: nextTopic,
          topicRefs: nextTopicRefs,
        ),
      HomeFeedStatus.success => HomeFeedLoaded(
          allArticles: nextArticles,
          topics: nextTopics,
          selectedTopic: nextTopic,
          topicRefs: nextTopicRefs,
        ),
      HomeFeedStatus.error => HomeFeedError(
          errorMessage: nextError ?? 'Failed to load stories.',
          allArticles: nextArticles,
          topics: nextTopics,
          selectedTopic: nextTopic,
          topicRefs: nextTopicRefs,
        ),
    };
  }

  @override
  List<Object?> get props => [
        status,
        allArticles,
        topics,
        selectedTopic,
        topicRefs,
        errorMessage,
      ];
}

final class HomeFeedInitial extends HomeFeedState {
  const HomeFeedInitial({
    super.allArticles,
    super.topics,
    super.selectedTopic,
    super.topicRefs,
  }) : super(status: HomeFeedStatus.initial);
}

final class HomeFeedLoading extends HomeFeedState {
  const HomeFeedLoading({
    super.allArticles,
    super.topics,
    super.selectedTopic,
    super.topicRefs,
  }) : super(status: HomeFeedStatus.loading);
}

final class HomeFeedLoaded extends HomeFeedState {
  const HomeFeedLoaded({
    required super.allArticles,
    super.topics,
    super.selectedTopic,
    super.topicRefs,
  }) : super(status: HomeFeedStatus.success);
}

final class HomeFeedError extends HomeFeedState {
  const HomeFeedError({
    required String errorMessage,
    super.allArticles,
    super.topics,
    super.selectedTopic,
    super.topicRefs,
  }) : super(status: HomeFeedStatus.error, errorMessage: errorMessage);
}

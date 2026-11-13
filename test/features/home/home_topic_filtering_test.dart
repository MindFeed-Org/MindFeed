import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mind_feed/core/articles/domain/entities/article_entity.dart';
import 'package:mind_feed/core/articles/domain/repos/articles_repo.dart';
import 'package:mind_feed/core/articles/domain/usecases/get_saved_articles_use_case.dart';
import 'package:mind_feed/core/articles/domain/usecases/toggle_article_like_use_case.dart';
import 'package:mind_feed/core/articles/domain/usecases/toggle_bookmark_use_case.dart';
import 'package:mind_feed/core/articles/domain/usecases/toggle_star_use_case.dart';
import 'package:mind_feed/core/design/editorial_card.dart';
import 'package:mind_feed/core/networking/api_result.dart';
import 'package:mind_feed/features/home/domain/usecases/filter_articles_by_topic_use_case.dart';
import 'package:mind_feed/features/home/domain/usecases/get_home_feed_use_case.dart';
import 'package:mind_feed/features/home/domain/usecases/get_user_feed_topics_use_case.dart';
import 'package:mind_feed/features/home/presentation/controllers/home_feed/home_feed_cubit.dart';
import 'package:mind_feed/features/home/presentation/widgets/home_feed_empty_view.dart';
import 'package:mind_feed/features/home/presentation/widgets/home_view_body.dart';
import 'package:mind_feed/features/profile/domain/repos/profile_repo.dart';

class _FakeArticlesRepo implements ArticlesRepository, ArticleEngagementRepository {
  List<ArticleEntity> articles = [];

  @override
  Future<ApiResult<List<ArticleEntity>>> getHomeFeed({
    List<String>? preferredCategoryIds,
    int limit = 20,
    int offset = 0,
  }) async {
    return Success(articles);
  }

  @override
  Future<ApiResult<List<ArticleEntity>>> getSavedArticles(String userId) async {
    return const Success([]);
  }

  @override
  Future<ApiResult<void>> saveBookmark(String articleId, String userId) async =>
      const Success(null);

  @override
  Future<ApiResult<void>> removeBookmark(String articleId, String userId) async =>
      const Success(null);

  @override
  Future<ApiResult<void>> starArticle(String articleId, String userId) async =>
      const Success(null);

  @override
  Future<ApiResult<void>> unstarArticle(String articleId, String userId) async =>
      const Success(null);

  @override
  Future<ApiResult<void>> likeArticle(String articleId, String userId) =>
      starArticle(articleId, userId);

  @override
  Future<ApiResult<void>> unlikeArticle(String articleId, String userId) =>
      unstarArticle(articleId, userId);

  @override
  Future<ApiResult<bool>> isArticleLiked(String articleId, String userId) async =>
      const Success(false);

  @override
  Future<ApiResult<AuthorRatingSummary>> rateAuthor({
    required String authorKey,
    required int stars,
    String? authorId,
    String authorName = 'Editorial Staff',
  }) async =>
      const Success(AuthorRatingSummary(
        authorKey: '',
        userStars: 0,
        ratingAvg: 0,
        ratingCount: 0,
      ));

  @override
  Future<ApiResult<AuthorRatingSummary>> getAuthorRatingSummary({
    required String authorKey,
    String? authorId,
    String authorName = 'Editorial Staff',
  }) async =>
      const Success(AuthorRatingSummary(
        authorKey: '',
        userStars: 0,
        ratingAvg: 0,
        ratingCount: 0,
      ));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeProfileRepo implements ProfileRepository {
  List<Map<String, dynamic>> favoriteCategories = [];
  List<Map<String, dynamic>> allCategories = [];

  @override
  Future<ApiResult<List<Map<String, dynamic>>>> getFavoriteCategories(
    String userId,
  ) async {
    return Success(favoriteCategories);
  }

  @override
  Future<ApiResult<List<Map<String, dynamic>>>> getCategories() async {
    return Success(allCategories);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Home topic filtering with dynamic backend categories', () {
    const backendScience = ArticleEntity(
      id: 'art_science',
      title: 'Deep Space Telescope',
      slug: 'deep-space-telescope',
      excerpt: 'Observations from orbit.',
      categoryId: 'cat-science-id',
      categorySlug: 'science',
      badge: 'SPACE',
      tags: ['Future of Tech'],
    );

    const backendDesign = ArticleEntity(
      id: 'art_design',
      title: 'Editorial Print Grids',
      slug: 'editorial-print-grids',
      excerpt: 'Layout systems on paper.',
      categoryId: 'cat-design-id',
      categorySlug: 'art-design',
      badge: 'DESIGN',
      tags: ['UI/UX Design'],
    );

    test(
      'FilterArticlesByTopicUseCase matches by dynamic backend id/slug and returns empty when category has no matches',
      () {
        const useCase = FilterArticlesByTopicUseCase();
        const items = [backendScience, backendDesign];

        // Matches dynamic backend category even when badge differs from topic name.
        final designFiltered = useCase.call(
          items,
          'Art & Design',
          selectedTopicCategoryId: 'cat-design-id',
          selectedTopicCategorySlug: 'art-design',
        );
        expect(designFiltered.map((e) => e.id).toList(), equals(['art_design']));

        // Tag like "Future of Tech" on a Science article does not bleed into Technology.
        final techFiltered = useCase.call(
          items,
          'Technology',
          selectedTopicCategoryId: 'cat-tech-id',
          selectedTopicCategorySlug: 'technology',
        );
        expect(techFiltered, isEmpty);

        // Unpopulated custom category from backend returns empty rather than random articles.
        final emptyFiltered = useCase.call(
          items,
          'Oceanography',
          selectedTopicCategoryId: 'cat-ocean-id',
          selectedTopicCategorySlug: 'oceanography',
        );
        expect(emptyFiltered, isEmpty);
      },
    );

    test(
      'HomeFeedCubit resolves dynamic backend topicRefs and toggles between All, populated category, and empty category',
      () async {
        final articlesRepo = _FakeArticlesRepo()
          ..articles = [backendScience, backendDesign];
        final profileRepo = _FakeProfileRepo()
          ..favoriteCategories = [
            {'name': 'Custom Atelier', 'category_name': 'Custom Atelier'},
            {'name': 'Astronomy Live', 'category_name': 'Astronomy Live'},
            {'name': 'Oceanography', 'category_name': 'Oceanography'},
          ]
          ..allCategories = [
            {
              'id': 'cat-design-id',
              'name': 'Custom Atelier',
              'slug': 'art-design',
            },
            {
              'id': 'cat-science-id',
              'name': 'Astronomy Live',
              'slug': 'science',
            },
            {
              'id': 'cat-ocean-id',
              'name': 'Oceanography',
              'slug': 'oceanography',
            },
          ];

        final cubit = HomeFeedCubit(
          getHomeFeedUseCase: GetHomeFeedUseCase(articlesRepo),
          getUserFeedTopicsUseCase: GetUserFeedTopicsUseCase(
            profileRepository: profileRepo,
          ),
          getSavedArticlesUseCase: GetSavedArticlesUseCase(articlesRepo),
          toggleBookmarkUseCase: ToggleBookmarkUseCase(articlesRepo),
          toggleStarUseCase: ToggleStarUseCase(articlesRepo),
          toggleArticleLikeUseCase: ToggleArticleLikeUseCase(articlesRepo),
          currentUserId: 'user-1',
          randomizeFeed: false,
        );

        await cubit.fetchFeed();

        expect(
          cubit.state.topics,
          equals(['All', 'Custom Atelier', 'Astronomy Live', 'Oceanography']),
        );
        expect(cubit.state.filteredArticles.length, equals(2));

        cubit.selectTopic('Custom Atelier');
        expect(
          cubit.state.filteredArticles.map((e) => e.id).toList(),
          equals(['art_design']),
        );

        cubit.selectTopic('Oceanography');
        expect(cubit.state.filteredArticles, isEmpty);

        cubit.selectTopic('All');
        expect(cubit.state.filteredArticles.length, equals(2));

        await cubit.close();
      },
    );

    testWidgets(
      'HomeViewBody shows empty view for empty favorite category and restores cards when tapping All',
      (tester) async {
        final articlesRepo = _FakeArticlesRepo()
          ..articles = [backendScience, backendDesign];
        final profileRepo = _FakeProfileRepo()
          ..favoriteCategories = [
            {'name': 'Custom Atelier', 'category_name': 'Custom Atelier'},
            {'name': 'Oceanography', 'category_name': 'Oceanography'},
          ]
          ..allCategories = [
            {
              'id': 'cat-design-id',
              'name': 'Custom Atelier',
              'slug': 'art-design',
            },
            {
              'id': 'cat-ocean-id',
              'name': 'Oceanography',
              'slug': 'oceanography',
            },
          ];

        final cubit = HomeFeedCubit(
          getHomeFeedUseCase: GetHomeFeedUseCase(articlesRepo),
          getUserFeedTopicsUseCase: GetUserFeedTopicsUseCase(
            profileRepository: profileRepo,
          ),
          getSavedArticlesUseCase: GetSavedArticlesUseCase(articlesRepo),
          toggleBookmarkUseCase: ToggleBookmarkUseCase(articlesRepo),
          toggleStarUseCase: ToggleStarUseCase(articlesRepo),
          toggleArticleLikeUseCase: ToggleArticleLikeUseCase(articlesRepo),
          currentUserId: 'user-1',
          randomizeFeed: false,
        );

        await cubit.fetchFeed();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: HomeViewBody(cubit: cubit),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(EditorialCard), findsWidgets);
        expect(find.byType(HomeFeedEmptyView), findsNothing);

        // Tap the empty favorite category tab -> must show empty, not random articles.
        await tester.tap(find.text('Oceanography'));
        await tester.pumpAndSettle();

        expect(find.byType(HomeFeedEmptyView), findsOneWidget);
        expect(find.text('No stories available for this topic.'), findsOneWidget);
        expect(find.byType(EditorialCard), findsNothing);

        // Tap populated favorite category -> shows matching article.
        await tester.tap(find.text('Custom Atelier'));
        await tester.pumpAndSettle();

        expect(find.byType(HomeFeedEmptyView), findsNothing);
        expect(find.text('Editorial Print Grids'), findsOneWidget);
        expect(find.text('Deep Space Telescope'), findsNothing);

        // Tap All -> restores both stories.
        await tester.tap(find.text('All'));
        await tester.pumpAndSettle();

        expect(find.byType(EditorialCard), findsWidgets);

        await cubit.close();
      },
    );
  });
}

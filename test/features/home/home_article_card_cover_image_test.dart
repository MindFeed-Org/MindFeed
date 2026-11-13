import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mind_feed/core/articles/data/models/article_model.dart';
import 'package:mind_feed/core/articles/domain/entities/article_entity.dart';
import 'package:mind_feed/core/articles/domain/repos/articles_repo.dart';
import 'package:mind_feed/core/articles/domain/usecases/get_saved_articles_use_case.dart';
import 'package:mind_feed/core/articles/domain/usecases/toggle_article_like_use_case.dart';
import 'package:mind_feed/core/articles/domain/usecases/toggle_bookmark_use_case.dart';
import 'package:mind_feed/core/articles/domain/usecases/toggle_star_use_case.dart';
import 'package:mind_feed/core/design/editorial_card.dart';
import 'package:mind_feed/core/design/editorial_card_stack.dart';
import 'package:mind_feed/core/design/editorial_models.dart';
import 'package:mind_feed/core/networking/api_result.dart';
import 'package:mind_feed/core/services/current_user_session.dart';
import 'package:mind_feed/core/widgets/editorial_cover_image.dart';
import 'package:mind_feed/features/add_article/domain/helpers/article_payload_builder.dart';
import 'package:mind_feed/features/add_article/presentation/controllers/add_article_cubit/add_article_state.dart';
import 'package:mind_feed/features/home/domain/usecases/get_home_feed_use_case.dart';
import 'package:mind_feed/features/home/domain/usecases/get_user_feed_topics_use_case.dart';
import 'package:mind_feed/features/home/presentation/controllers/home_feed/home_feed_cubit.dart';
import 'package:mind_feed/features/home/presentation/widgets/home_lead_story_section.dart';
import 'package:mind_feed/features/home/presentation/widgets/home_view_body.dart';
import 'package:mind_feed/features/profile/domain/repos/profile_repo.dart';

final Uint8List _valid1x1Png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

class _FakeArticlesRepo
    implements ArticlesRepository, ArticleEngagementRepository {
  _FakeArticlesRepo(this.articles);

  final List<ArticleEntity> articles;

  @override
  Future<ApiResult<List<ArticleEntity>>> getHomeFeed({
    List<String>? preferredCategoryIds,
    int limit = 20,
    int offset = 0,
  }) async => Success(articles);

  @override
  Future<ApiResult<List<ArticleEntity>>> getSavedArticles(
    String userId,
  ) async => const Success([]);

  @override
  Future<ApiResult<void>> likeArticle(String articleId, String userId) async =>
      const Success(null);

  @override
  Future<ApiResult<void>> unlikeArticle(
    String articleId,
    String userId,
  ) async => const Success(null);

  @override
  Future<ApiResult<bool>> isArticleLiked(
    String articleId,
    String userId,
  ) async => const Success(false);

  @override
  Future<ApiResult<void>> saveBookmark(String articleId, String userId) async =>
      const Success(null);

  @override
  Future<ApiResult<void>> removeBookmark(
    String articleId,
    String userId,
  ) async => const Success(null);

  @override
  Future<ApiResult<void>> starArticle(String articleId, String userId) async =>
      const Success(null);

  @override
  Future<ApiResult<void>> unstarArticle(
    String articleId,
    String userId,
  ) async => const Success(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeProfileRepo implements ProfileRepository {
  @override
  Future<ApiResult<List<Map<String, dynamic>>>> getFavoriteCategories(
    String userId,
  ) async => const Success([]);

  @override
  Future<ApiResult<List<Map<String, dynamic>>>> getCategories() async =>
      const Success([]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'EditorialCard renders cover image without excerpt when coverImageBytes or coverImageUrl is provided',
    (tester) async {
      final itemWithUrl = EditorialNewsItem(
        id: 'card_url',
        badge: 'TECH',
        badgeColor: Colors.blue,
        title: 'Cover URL Story',
        updated: 'Just now',
        authorName: 'Jane Doe',
        authorRole: 'Editor',
        authorAvatar: '',
        excerpt: 'Excerpt should not appear on EditorialCard.',
        color: Colors.amber,
        coverImageUrl: 'https://example.com/cover.jpg',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditorialCard(item: itemWithUrl),
          ),
        ),
      );

      expect(find.byType(EditorialCoverImage), findsOneWidget);
      expect(
        find.text('Excerpt should not appear on EditorialCard.'),
        findsNothing,
      );
      final networkImageFinder = find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is ResizeImage &&
            (w.image as ResizeImage).imageProvider is NetworkImage &&
            ((w.image as ResizeImage).imageProvider as NetworkImage).url ==
                'https://example.com/cover.jpg',
      );
      expect(networkImageFinder, findsOneWidget);
      expect(
        tester.getSize(find.byType(EditorialCoverImage)).height,
        greaterThanOrEqualTo(220),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EditorialCard(item: itemWithUrl),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(EditorialCoverImage)).height, 220);

      final itemWithBytes = itemWithUrl.copyWith(
        coverImageUrl: '',
        coverImageBytes: _valid1x1Png,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditorialCard(item: itemWithBytes),
          ),
        ),
      );

      expect(find.byType(EditorialCoverImage), findsOneWidget);
      final memoryImageFinder = find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is ResizeImage &&
            (w.image as ResizeImage).imageProvider is MemoryImage,
      );
      expect(memoryImageFinder, findsOneWidget);
    },
  );

  testWidgets(
    'EditorialCard omits EditorialCoverImage when cover image is absent or legacy asset',
    (tester) async {
      final itemNoCover = EditorialNewsItem(
        id: 'card_none',
        badge: 'TECH',
        badgeColor: Colors.blue,
        title: 'No Cover Story',
        updated: 'Just now',
        authorName: 'Jane Doe',
        authorRole: 'Editor',
        authorAvatar: '',
        excerpt: 'Story excerpt text.',
        color: Colors.amber,
        coverImageUrl: 'assets/images/legacy.png',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditorialCard(item: itemNoCover),
          ),
        ),
      );

      expect(find.byType(EditorialCoverImage), findsNothing);
      expect(find.text('Story excerpt text.'), findsNothing);
    },
  );

  testWidgets(
    'EditorialCardStack expands cover image cleanly across available card body without overflow',
    (tester) async {
      final items = [
        EditorialNewsItem(
          id: 'long_1',
          badge: 'SCIENCE',
          badgeColor: Colors.green,
          title:
              'A Deliberately Long Multi-Line Headline That Wraps Across Three Full Lines Inside The Card',
          updated: '2 hours ago',
          authorName: 'Ada Lovelace',
          authorRole: 'Senior Researcher',
          authorAvatar: '',
          excerpt: 'Unused excerpt text.',
          color: Colors.amber,
          coverImageBytes: _valid1x1Png,
          likesCount: 12,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 358,
              child: EditorialCardStack(
                items: items,
                height: 570,
                onOpenArticle: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(EditorialCoverImage), findsOneWidget);
      expect(
        tester.getSize(find.byType(EditorialCoverImage)).height,
        greaterThanOrEqualTo(200),
      );
      expect(find.text('Unused excerpt text.'), findsNothing);
    },
  );

  testWidgets(
    'EditorialCardStack keeps next card cover image from shrinking when promoted to front after swipe',
    (tester) async {
      final items = [
        EditorialNewsItem(
          id: 'swipe_1',
          badge: 'TECH',
          badgeColor: Colors.blue,
          title: 'Front Story',
          updated: 'Just now',
          authorName: 'Author One',
          authorRole: 'Writer',
          authorAvatar: '',
          excerpt: 'Excerpt 1',
          color: Colors.amber,
          coverImageBytes: _valid1x1Png,
        ),
        EditorialNewsItem(
          id: 'swipe_2',
          badge: 'SCIENCE',
          badgeColor: Colors.green,
          title: 'Second Story',
          updated: '1 hour ago',
          authorName: 'Author Two',
          authorRole: 'Writer',
          authorAvatar: '',
          excerpt: 'Excerpt 2',
          color: Colors.cyan,
          coverImageBytes: _valid1x1Png,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 358,
              child: EditorialCardStack(
                items: items,
                height: 570,
                onOpenArticle: (_) {},
              ),
            ),
          ),
        ),
      );

      final secondCardFinder = find.ancestor(
        of: find.text('Second Story'),
        matching: find.byType(EditorialCard),
      );
      final behindCoverHeight = tester
          .getSize(
            find.descendant(
              of: secondCardFinder,
              matching: find.byType(EditorialCoverImage),
            ),
          )
          .height;

      await tester.drag(find.text('Front Story'), const Offset(200, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      final promotedCoverHeight = tester
          .getSize(
            find.descendant(
              of: secondCardFinder,
              matching: find.byType(EditorialCoverImage),
            ),
          )
          .height;

      expect(promotedCoverHeight, greaterThanOrEqualTo(behindCoverHeight));
      expect(
        (promotedCoverHeight - behindCoverHeight).abs(),
        lessThanOrEqualTo(10),
      );
    },
  );

  testWidgets(
    'HomeViewBody displays cover image in EditorialCard and keeps HomeSecondaryStoryTile image-free',
    (tester) async {
      const coverUrl = 'https://cdn.example.com/articles/cover-1.webp';
      final repo = _FakeArticlesRepo([
        const ArticleEntity(
          id: 'home_art_1',
          title: 'Home Cover Article',
          slug: 'home-cover-article',
          excerpt: 'Home feed article excerpt.',
          badge: 'TECH',
          coverImageUrl: coverUrl,
        ),
      ]);
      final cubit = HomeFeedCubit(
        getHomeFeedUseCase: GetHomeFeedUseCase(repo),
        getUserFeedTopicsUseCase: GetUserFeedTopicsUseCase(
          profileRepository: _FakeProfileRepo(),
        ),
        getSavedArticlesUseCase: GetSavedArticlesUseCase(repo),
        toggleBookmarkUseCase: ToggleBookmarkUseCase(repo),
        toggleStarUseCase: ToggleStarUseCase(repo),
        toggleArticleLikeUseCase: ToggleArticleLikeUseCase(repo),
        currentUserId: 'user_1',
      )..fetchFeed();
      addTearDown(cubit.close);

      await tester.pumpWidget(MaterialApp(home: HomeViewBody(cubit: cubit)));
      await tester.pump();
      await tester.pump();

      final cardCover = find.descendant(
        of: find.byType(EditorialCard),
        matching: find.byType(EditorialCoverImage),
      );
      expect(cardCover, findsOneWidget);

      await tester.scrollUntilVisible(
        find.byType(HomeSecondaryStoryTile),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      final tileCover = find.descendant(
        of: find.byType(HomeSecondaryStoryTile),
        matching: find.byType(EditorialCoverImage),
      );
      expect(tileCover, findsNothing);
    },
  );

  test(
    'ArticleModel and ArticlePayloadBuilder use cover_image_url only without hero_image_url',
    () {
      final model = ArticleModel.fromJson({
        'id': 'art_1',
        'title': 'Test',
        'slug': 'test',
        'excerpt': 'Excerpt',
        'cover_image_url': 'https://cdn.example.com/cover.jpg',
      });

      expect(model.coverImageUrl, equals('https://cdn.example.com/cover.jpg'));
      expect(model.toJson().containsKey('hero_image_url'), isFalse);
      expect(
        model.toJson()['cover_image_url'],
        equals('https://cdn.example.com/cover.jpg'),
      );

      final draftPayload = ArticlePayloadBuilder.buildDraftPayload(
        state: const AddArticleState(
          title: 'Draft Title',
          content: 'Draft body',
          coverImageUrl: 'https://cdn.example.com/draft-cover.jpg',
        ),
        user: const CurrentUserSnapshot(id: 'u1', email: 'a@b.com'),
        includeSlug: true,
      );

      expect(draftPayload.containsKey('hero_image_url'), isFalse);
      expect(
        draftPayload['cover_image_url'],
        equals('https://cdn.example.com/draft-cover.jpg'),
      );
    },
  );
}

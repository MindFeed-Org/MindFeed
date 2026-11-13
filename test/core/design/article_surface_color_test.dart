import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_feed/core/articles/domain/entities/article_entity.dart';
import 'package:mind_feed/core/articles/domain/entities/category_entity.dart';
import 'package:mind_feed/core/articles/domain/entities/downloaded_article_entity.dart';
import 'package:mind_feed/core/constants/app_colors.dart';
import 'package:mind_feed/core/constants/category_items.dart';
import 'package:mind_feed/core/design/editorial_card.dart';
import 'package:mind_feed/core/design/editorial_models.dart';
import 'package:mind_feed/core/services/current_user_session.dart';
import 'package:mind_feed/features/add_article/domain/helpers/article_payload_builder.dart';
import 'package:mind_feed/features/add_article/presentation/controllers/add_article_cubit/add_article_state.dart';
import 'package:mind_feed/features/collections/presentation/views/downloaded_article_reader_view.dart';

void main() {
  group('Article 5-color surface palette', () {
    test('defines 5 distinct surface colors separate from category colors', () {
      expect(AppColors.articleSurfaceColors.length, equals(5));
      expect(AppColors.articleSurfaceHexColors.length, equals(5));
      expect(
        AppColors.articleSurfaceColors.map((c) => c.toARGB32()).toSet().length,
        equals(5),
      );
      expect(AppColors.articleSurfaceColors, isNot(contains(AppColors.cream)));

      for (final category in categories) {
        final slug = category.name.toLowerCase().replaceAll(' & ', '-').replaceAll(' ', '-');
        final categoryColor = getCategoryColor(slug).toARGB32();
        for (final surface in AppColors.articleSurfaceColors) {
          expect(surface.toARGB32(), isNot(equals(categoryColor)));
        }
      }
    });

    test('toEditorialNewsItem distributes default #FFF1C6 articles across all 5 colors without matching category color', () {
      final resolvedColors = <int>{};
      for (var i = 0; i < 40; i++) {
        final article = ArticleEntity(
          id: 'article-uuid-$i-seed-${i * 17}',
          title: 'Story $i',
          slug: 'story-$i',
          excerpt: 'Excerpt $i',
          categorySlug: 'technology',
          badge: 'TECH',
          cardColor: '#FFF1C6',
        );
        final item = article.toEditorialNewsItem();
        resolvedColors.add(item.color.toARGB32());
        expect(item.color.toARGB32(), isNot(equals(item.badgeColor.toARGB32())));
        expect(
          AppColors.articleSurfaceColors.map((c) => c.toARGB32()),
          contains(item.color.toARGB32()),
        );
      }

      expect(resolvedColors.length, equals(5));
    });

    test('resolveArticleSurfaceColor replaces cardColor if it collides with avoidColor', () {
      const avoid = Color(0xFFFFE5D0);
      final resolved = ArticleEntityEditorialMapper.resolveArticleSurfaceColor(
        seed: 'collision-seed',
        rawCardColor: '#FFE5D0',
        avoidColor: avoid,
      );
      expect(resolved.toARGB32(), isNot(equals(avoid.toARGB32())));
      expect(
        AppColors.articleSurfaceColors.map((c) => c.toARGB32()),
        contains(resolved.toARGB32()),
      );
    });

    test('ArticlePayloadBuilder picks random card_color from the 5-color palette distinct from badge_color', () {
      const user = CurrentUserSnapshot(
        id: 'user-color-test',
        displayName: 'Color Author',
        email: 'color@example.com',
      );
      const category = CategoryEntity(
        id: 'cat-art',
        name: 'Art & Design',
        slug: 'art-design',
      );
      const state = AddArticleState(
        title: 'Typography Systems',
        content: 'Detailed typography analysis.',
        selectedCategoryId: 'cat-art',
        categories: [category],
        selectedTags: ['design'],
        coverImageUrl: 'https://example.com/cover.jpg',
      );

      final payload = ArticlePayloadBuilder.buildPublishPayload(
        state: state,
        user: user,
        includeSlug: true,
      );
      expect(
        AppColors.articleSurfaceHexColors,
        contains(payload['card_color']),
      );
      expect(payload['card_color'], isNot(equals(payload['badge_color'])));

      final picked = ArticleEntityEditorialMapper.pickRandomArticleSurfaceHex(
        avoidHex: '#FFE5D0',
        random: Random(1),
      );
      expect(picked, isNot(equals('#FFE5D0')));
      expect(AppColors.articleSurfaceHexColors, contains(picked));
    });

    testWidgets('EditorialCard and DownloadedArticleReaderView render varied non-yellow article surface color', (tester) async {
      const article = ArticleEntity(
        id: 'render-color-1',
        title: 'Atmospheric Physics',
        slug: 'atmospheric-physics',
        excerpt: 'Atmospheric summary.',
        content: 'Full article markdown body for reader view.',
        categorySlug: 'science',
        badge: 'SCIENCE',
        cardColor: '#FFF1C6',
      );
      final item = article.toEditorialNewsItem();
      expect(item.color.toARGB32(), isNot(equals(AppColors.cream.toARGB32())));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: EditorialCard(item: item),
            ),
          ),
        ),
      );
      await tester.pump();

      final cardContainer = tester.widget<Container>(
        find.byWidgetPredicate((widget) {
          if (widget is! Container) return false;
          final dec = widget.decoration;
          return dec is BoxDecoration && dec.color == item.color;
        }).first,
      );
      expect((cardContainer.decoration! as BoxDecoration).color, equals(item.color));

      final downloaded = DownloadedArticleEntity(
        id: 'render-color-1',
        title: 'Atmospheric Physics',
        excerpt: 'Atmospheric summary.',
        content: 'Full article markdown body for reader view.',
        categoryId: 'cat-science',
        categorySlug: 'science',
        authorName: 'Author',
        authorRole: 'Writer',
        authorAvatar: '',
        tags: const ['Space'],
        publishedAt: DateTime(2026, 11, 1),
        downloadedAt: DateTime(2026, 11, 2),
        readingTimeMinutes: 3,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DownloadedArticleReaderView(article: downloaded),
        ),
      );
      await tester.pumpAndSettle();

      final readerScaffold = tester.widget<Scaffold>(find.byType(Scaffold).last);
      expect(readerScaffold.backgroundColor, equals(item.color));
      expect(readerScaffold.backgroundColor, isNot(equals(AppColors.cream)));
    });
  });
}

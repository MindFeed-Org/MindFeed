import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:mind_feed/core/constants/app_colors.dart';
import 'package:mind_feed/core/services/current_user_session.dart';
import 'package:mind_feed/features/collections/presentation/views/articles_saved.dart';
import 'package:mind_feed/features/collections/presentation/views/downloaded_articles_view.dart';
import 'package:mind_feed/features/home/presentation/views/home_view.dart';
import 'package:mind_feed/features/main/presentation/widgets/main_navigation_bar.dart';
import 'package:mind_feed/features/profile/presentation/views/profile_view.dart';
import 'package:mind_feed/features/search/presentation/views/search_view.dart';

class MainView extends StatefulWidget {
  const MainView({super.key});
  static const String routeName = 'main';

  @override
  State<MainView> createState() => _MainViewState();
}

class _MainViewState extends State<MainView> {
  int _selectedIndex = 0;
  final Set<int> _visitedTabs = {0};
  final Map<int, Widget> _cachedTabs = {};

  int _homeRefreshSeed = 0;
  int _savedRefreshSeed = 0;
  int _downloadsRefreshSeed = 0;
  List<String> _lastFavoriteCategories = const [];

  @override
  void initState() {
    super.initState();
    _lastFavoriteCategories = _readFavoriteCategories();
    _cachedTabs[0] = HomeView(key: ValueKey<int>(_homeRefreshSeed));
  }

  List<String> _readFavoriteCategories() {
    return List<String>.unmodifiable(
      CurrentUserSession.resolveCachedUserEntity()?.favoriteCategories ??
          const <String>[],
    );
  }

  bool _refreshHomeIfFavoritesChanged() {
    final current = _readFavoriteCategories();
    if (listEquals(current, _lastFavoriteCategories)) {
      return false;
    }
    _lastFavoriteCategories = current;
    _homeRefreshSeed++;
    _cachedTabs[0] = HomeView(key: ValueKey<int>(_homeRefreshSeed));
    return true;
  }

  void _onTabSelected(int index) {
    FocusScope.of(context).unfocus();

    if (_selectedIndex == index) {
      _handleSameTabTapped(index);
      return;
    }

    setState(() {
      _visitedTabs.add(index);
      if (index == 0) {
        _refreshHomeIfFavoritesChanged();
      } else if (index == 2) {
        _refreshSavedTab();
      } else if (index == 3) {
        _refreshDownloadsTab();
      } else {
        _cachedTabs.putIfAbsent(index, () => _buildChildWidget(index));
      }
      _selectedIndex = index;
    });
  }

  void _handleSameTabTapped(int index) {
    if (index == 0) {
      final current = _readFavoriteCategories();
      if (!listEquals(current, _lastFavoriteCategories)) {
        setState(_refreshHomeIfFavoritesChanged);
      }
    } else if (index == 2) {
      setState(() {
        _refreshSavedTab();
      });
    } else if (index == 3) {
      setState(() {
        _refreshDownloadsTab();
      });
    }
  }

  void _refreshSavedTab() {
    _savedRefreshSeed++;
    _cachedTabs[2] = ArticlesSaved(refreshSeed: _savedRefreshSeed);
  }

  void _refreshDownloadsTab() {
    _downloadsRefreshSeed++;
    _cachedTabs[3] =
        DownloadedArticlesView(refreshSeed: _downloadsRefreshSeed);
  }

  Widget _buildChildWidget(int index) {
    return switch (index) {
      0 => HomeView(key: ValueKey<int>(_homeRefreshSeed)),
      1 => const SearchView(),
      2 => ArticlesSaved(refreshSeed: _savedRefreshSeed),
      3 => DownloadedArticlesView(refreshSeed: _downloadsRefreshSeed),
      4 => const ProfileView(),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildTab(int index) {
    if (!_visitedTabs.contains(index)) {
      return const SizedBox.shrink();
    }
    return TickerMode(
      enabled: _selectedIndex == index,
      child: RepaintBoundary(
        child: _cachedTabs[index] ?? const SizedBox.shrink(),
      ),
    );
  }

  void _handlePop() {
    if (_selectedIndex != 0) {
      setState(() {
        _refreshHomeIfFavoritesChanged();
        _selectedIndex = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        _handlePop();
      },
      child: Scaffold(
        extendBody: true,
        backgroundColor: AppColors.ink,
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildTab(0),
            _buildTab(1),
            _buildTab(2),
            _buildTab(3),
            _buildTab(4),
          ],
        ),
        bottomNavigationBar: MainNavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onTabSelected,
        ),
      ),
    );
  }
}

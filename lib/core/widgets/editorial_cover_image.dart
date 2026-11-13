import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:mind_feed/core/constants/app_colors.dart';
import 'package:mind_feed/core/constants/app_icons.dart';
import 'package:mind_feed/core/constants/borders.dart';

/// Shared cover image widget for editorial cards and story tiles.
///
/// Prefers in-memory [coverImageBytes] over [coverImageUrl], configures
/// decoded cache dimensions to avoid raster stalls, and renders a themed
/// placeholder if the image fails to load.
class EditorialCoverImage extends StatelessWidget {
  const EditorialCoverImage({
    super.key,
    this.coverImageUrl,
    this.coverImageBytes,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = AppBorders.xxs,
    this.cacheWidth = 1080,
    this.cacheHeight,
    this.placeholderBackgroundColor = AppColors.blackAlpha12,
    this.placeholderIconColor = AppColors.mutedInk,
    this.placeholderIconSize = 32,
  });

  final String? coverImageUrl;
  final Uint8List? coverImageBytes;
  final double? width;
  final double height;
  final BorderRadiusGeometry borderRadius;
  final int? cacheWidth;
  final int? cacheHeight;
  final Color placeholderBackgroundColor;
  final Color placeholderIconColor;
  final double placeholderIconSize;

  /// Returns whether either [coverImageBytes] or [coverImageUrl] holds a
  /// renderable image source.
  static bool hasValidCover({
    String? coverImageUrl,
    Uint8List? coverImageBytes,
  }) {
    if (coverImageBytes != null && coverImageBytes.isNotEmpty) {
      return true;
    }
    final resolvedUrl = coverImageUrl?.trim();
    return resolvedUrl != null &&
        resolvedUrl.isNotEmpty &&
        !resolvedUrl.startsWith('assets/');
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: _buildImage(),
    );
  }

  Widget _buildImage() {
    if (coverImageBytes != null && coverImageBytes!.isNotEmpty) {
      return Image.memory(
        coverImageBytes!,
        width: width,
        height: height,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildPlaceholder(),
      );
    }

    final resolvedUrl = coverImageUrl?.trim();
    if (resolvedUrl != null &&
        resolvedUrl.isNotEmpty &&
        !resolvedUrl.startsWith('assets/')) {
      return Image.network(
        resolvedUrl,
        width: width,
        height: height,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildPlaceholder(),
      );
    }

    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: placeholderBackgroundColor,
      child: Center(
        child: Icon(
          AppIcons.imageOutlined,
          size: placeholderIconSize,
          color: placeholderIconColor,
        ),
      ),
    );
  }
}

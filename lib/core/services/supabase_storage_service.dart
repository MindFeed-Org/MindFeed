import 'package:flutter/foundation.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mind_feed/core/constants/constants.dart';
import 'package:mind_feed/core/errors/failures.dart';

/// Service responsible for managing asset uploads and URL resolutions
/// within Supabase Storage buckets.
class SupabaseStorageService {
  static const String avatarsBucket = 'avatars';
  static const String articleMediaBucket = 'article-media';
  static const String defaultAvatarFileName = 'defaultAvatar.png';

  final SupabaseClient? _supabaseClient;

  const SupabaseStorageService({SupabaseClient? supabaseClient})
      : _supabaseClient = supabaseClient;

  SupabaseClient? get _client {
    if (_supabaseClient != null) {
      return _supabaseClient;
    }
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  // ===========================================================================
  // Public Upload API
  // ===========================================================================

  /// Deletes the previous avatar from `avatars` (if custom) and uploads new avatar bytes.
  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String fileExtension,
    String? previousAvatarUrl,
  }) {
    return _uploadToBucket(
      bucketName: avatarsBucket,
      userId: userId,
      bytes: bytes,
      fileExtension: fileExtension,
      filePrefix: 'avatar',
      previousUrl: previousAvatarUrl,
      shouldSkipCleanup: (oldPath) =>
          isDefaultAvatar(oldPath) ||
          oldPath == defaultAvatarFileName ||
          oldPath.endsWith('/$defaultAvatarFileName'),
    );
  }

  /// Deletes the previous cover image from `article-media` (if owned by user) and uploads new cover bytes.
  Future<String> uploadArticleCover({
    required String userId,
    required Uint8List bytes,
    required String fileExtension,
    String? previousCoverUrl,
  }) {
    return _uploadToBucket(
      bucketName: articleMediaBucket,
      userId: userId,
      bytes: bytes,
      fileExtension: fileExtension,
      filePrefix: 'cover',
      previousUrl: previousCoverUrl,
      shouldSkipCleanup: (oldPath) => !oldPath.startsWith('$userId/'),
    );
  }

  // ===========================================================================
  // URL & Path Utilities
  // ===========================================================================

  /// Resolves an avatar URL or relative path to a public CDN URL from the `avatars` bucket.
  static String? resolveAvatarUrl(
    String? rawUrlOrPath, {
    SupabaseClient? client,
  }) {
    return resolveBucketUrl(rawUrlOrPath, avatarsBucket, client: client);
  }

  /// Resolves an article image URL or relative path to a public CDN URL from the `article-media` bucket.
  static String? resolveArticleMediaUrl(
    String? rawUrlOrPath, {
    SupabaseClient? client,
  }) {
    return resolveBucketUrl(rawUrlOrPath, articleMediaBucket, client: client);
  }

  /// Generic resolver converting relative storage paths or URLs into fully-qualified public CDN URLs.
  static String? resolveBucketUrl(
    String? rawUrlOrPath,
    String bucketName, {
    SupabaseClient? client,
  }) {
    if (rawUrlOrPath == null) {
      return null;
    }

    final trimmed = rawUrlOrPath.trim();
    if (trimmed.isEmpty || trimmed.startsWith('assets/')) {
      return null;
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    final cleanPath = _normalizeBucketObjectPath(trimmed, bucketName);
    if (cleanPath.isEmpty) {
      return null;
    }

    return _buildPublicUrl(bucketName, cleanPath, client: client);
  }

  /// Returns true if [urlOrPath] is empty or points to the default avatar in Supabase.
  static bool isDefaultAvatar(String? urlOrPath) {
    if (urlOrPath == null) {
      return true;
    }

    final trimmed = urlOrPath.trim();
    if (trimmed.isEmpty) {
      return true;
    }

    final clean = trimmed.split('?').first;
    return clean == defaultAvatarFileName ||
        clean.endsWith('/$defaultAvatarFileName');
  }

  /// Extracts the object path inside [bucketName] from a full URL or relative path.
  static String? extractBucketPath(String? urlOrPath, String bucketName) {
    if (urlOrPath == null) {
      return null;
    }

    final trimmed = urlOrPath.trim();
    if (trimmed.isEmpty || trimmed.startsWith('assets/')) {
      return null;
    }

    final withoutQuery = trimmed.split('?').first;
    final marker = '/storage/v1/object/public/$bucketName/';
    final markerIdx = withoutQuery.indexOf(marker);
    if (markerIdx != -1) {
      final extracted = withoutQuery.substring(markerIdx + marker.length);
      return extracted.isNotEmpty ? Uri.decodeFull(extracted) : null;
    }

    if (withoutQuery.startsWith('http://') ||
        withoutQuery.startsWith('https://')) {
      return null;
    }

    final normalized = _normalizeBucketObjectPath(withoutQuery, bucketName);
    return normalized.isNotEmpty ? normalized : null;
  }

  // ===========================================================================
  // File Format & MIME Helpers
  // ===========================================================================

  /// Normalizes arbitrary file extensions or filenames into canonical image extensions.
  static String normalizeExtension(String fileNameOrExtension) {
    final cleaned = fileNameOrExtension.trim().toLowerCase();
    final rawExt = cleaned.contains('.') ? cleaned.split('.').last : cleaned;
    return switch (rawExt) {
      'jpg' || 'jpeg' => 'jpg',
      'png' => 'png',
      'webp' => 'webp',
      'gif' => 'gif',
      _ => 'jpg',
    };
  }

  /// Maps canonical image extensions to their corresponding MIME types.
  static String contentTypeForExtension(String ext) {
    return switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => 'image/jpeg',
    };
  }

  // ===========================================================================
  // Private Helper Methods
  // ===========================================================================

  /// Core implementation for uploading binary assets to any Supabase Storage bucket.
  Future<String> _uploadToBucket({
    required String bucketName,
    required String userId,
    required Uint8List bytes,
    required String fileExtension,
    required String filePrefix,
    String? previousUrl,
    bool Function(String oldPath)? shouldSkipCleanup,
  }) async {
    final client = _client;
    if (client == null) {
      throw const StorageException('Storage client is not initialized');
    }

    if (previousUrl != null && previousUrl.trim().isNotEmpty) {
      await _cleanupPreviousFile(
        client: client,
        bucketName: bucketName,
        previousUrl: previousUrl,
        shouldSkipCleanup: shouldSkipCleanup,
      );
    }

    final ext = normalizeExtension(fileExtension);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final objectPath = '$userId/${filePrefix}_$timestamp.$ext';

    await client.storage.from(bucketName).uploadBinary(
          objectPath,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: contentTypeForExtension(ext),
          ),
        );

    return client.storage.from(bucketName).getPublicUrl(objectPath);
  }

  /// Deletes a previous file from storage unless filtered out by [shouldSkipCleanup].
  Future<void> _cleanupPreviousFile({
    required SupabaseClient client,
    required String bucketName,
    required String previousUrl,
    bool Function(String oldPath)? shouldSkipCleanup,
  }) async {
    final oldPath = extractBucketPath(previousUrl, bucketName);
    if (oldPath == null || oldPath.isEmpty) {
      return;
    }

    if (shouldSkipCleanup != null && shouldSkipCleanup(oldPath)) {
      return;
    }

    try {
      await client.storage.from(bucketName).remove([oldPath]);
    } catch (_) {
      const failure = CacheFailure("there's an error, Please try again later");
      debugPrint(failure.message);
    }
  }

  static String _normalizeBucketObjectPath(String rawPath, String bucketName) {
    var clean = rawPath.trim();
    while (clean.startsWith('/')) {
      clean = clean.substring(1);
    }
    if (clean.startsWith('$bucketName/')) {
      clean = clean.substring(bucketName.length + 1);
    }
    return clean;
  }

  static String? _buildPublicUrl(
    String bucketName,
    String objectPath, {
    SupabaseClient? client,
  }) {
    try {
      final activeClient = client ?? Supabase.instance.client;
      return activeClient.storage.from(bucketName).getPublicUrl(objectPath);
    } catch (_) {
      final baseUrl = AppConstants.supabaseUrl.trim();
      final normalizedBase = baseUrl.isNotEmpty
          ? (baseUrl.endsWith('/')
              ? baseUrl.substring(0, baseUrl.length - 1)
              : baseUrl)
          : 'https://tsqruoqiajkbrdhprfxa.supabase.co';

      return '$normalizedBase/storage/v1/object/public/$bucketName/$objectPath';
    }
  }
}

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_dio.dart';
import 'server_address.dart';

/// The server's description of an image.
@immutable
class DescriptionResult {
  /// Creates a result.
  const DescriptionResult({required this.description, required this.hasText});

  /// Spoken-ready description in the requested language.
  final String description;

  /// Whether the image shows readable text (the server does not say; false).
  final bool hasText;
}

/// Why a description could not be had.
class DescriptionException implements Exception {
  /// Creates the exception.
  const DescriptionException(this.message);

  /// What went wrong (for logs, not for the user).
  final String message;

  @override
  String toString() => 'DescriptionException: $message';
}

/// Picture descriptions, from the web app (`POST /api/v1/describe`). The app
/// never talks to Gemini and never holds an API key: the server does.
abstract interface class ImageDescriptionRepository {
  /// Describes [jpeg] (already resized) in [language] (`fil` or `en`);
  /// [detail] asks for the longer answer. Nothing identifies the user: the
  /// request is anonymous.
  Future<DescriptionResult> describe({
    required Uint8List jpeg,
    required String language,
    bool detail = false,
  });
}

/// The real thing: `POST {server address}/api/v1/describe` (multipart).
class HttpImageDescriptionRepository implements ImageDescriptionRepository {
  /// Creates the repository for the web app at [baseUrl] over [dio].
  HttpImageDescriptionRepository(this._baseUrl, this._dio);

  final String _baseUrl;
  final Dio _dio;

  @override
  Future<DescriptionResult> describe({
    required Uint8List jpeg,
    required String language,
    bool detail = false,
  }) async {
    try {
      final response = await _dio.post<Object?>(
        '${_baseUrl.replaceAll(RegExp(r'/+$'), '')}/api/v1/describe',
        data: FormData.fromMap({
          'image': MultipartFile.fromBytes(
            jpeg,
            filename: 'photo.jpg',
            contentType: DioMediaType('image', 'jpeg'),
          ),
          'lang': language,
          if (detail) 'detail': 'true',
        }),
      );
      final body = response.data;
      final text = body is Map ? body['description'] : null;
      if (text is! String || text.trim().isEmpty) {
        throw const DescriptionException('empty description');
      }
      return DescriptionResult(description: text.trim(), hasText: false);
    } on DioException catch (e) {
      throw DescriptionException(
        '${e.type.name} ${e.response?.statusCode ?? ''}: ${e.message}',
      );
    }
  }
}

/// The app's description service.
final imageDescriptionRepositoryProvider = Provider<ImageDescriptionRepository>(
  (ref) => HttpImageDescriptionRepository(
    ref.watch(serverAddressProvider),
    apiDio(
      connect: const Duration(seconds: 8),
      send: const Duration(seconds: 8),
      receive: const Duration(seconds: 8),
    ),
  ),
);

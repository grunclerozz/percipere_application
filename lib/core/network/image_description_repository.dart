import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/env.dart';

/// The server's detailed description of an image.
@immutable
class DescriptionResult {
  /// Creates a result.
  const DescriptionResult({required this.description, required this.hasText});

  /// Spoken-ready description in the requested language.
  final String description;

  /// Whether the image shows readable text.
  final bool hasText;
}

/// Why a detailed description could not be had.
class DescriptionException implements Exception {
  /// Creates the exception.
  const DescriptionException(this.message);

  /// What went wrong (for logs, not for the user).
  final String message;

  @override
  String toString() => 'DescriptionException: $message';
}

/// Detailed image descriptions, from the web app. The app never talks to
/// Gemini and never holds an API key: see `docs/api-contract.md`.
abstract interface class ImageDescriptionRepository {
  /// Describes [jpeg] (already resized) in [language] (`fil` or `en`).
  /// [userId] is null for a guest, whose request is sent as anonymous.
  Future<DescriptionResult> describe({
    required Uint8List jpeg,
    required String language,
    String? userId,
  });
}

/// Stand-in until the web app exists: a sample description after a pause.
class MockImageDescriptionRepository implements ImageDescriptionRepository {
  /// Creates the mock; [delay] simulates the network.
  const MockImageDescriptionRepository({
    this.delay = const Duration(milliseconds: 800),
  });

  /// Simulated waiting time.
  final Duration delay;

  @override
  Future<DescriptionResult> describe({
    required Uint8List jpeg,
    required String language,
    String? userId,
  }) async {
    await Future<void>.delayed(delay);
    return DescriptionResult(
      description: language == 'en'
          ? 'It looks like a table with a plate of food, a glass of water '
                'and a spoon, in a brightly lit room.'
          : 'Mukhang isang mesa na may plato ng pagkain, baso ng tubig at '
                'kutsara, sa isang maliwanag na silid.',
      hasText: false,
    );
  }
}

/// The real thing: `POST {API_BASE_URL}/api/describe-image` (multipart).
class HttpImageDescriptionRepository implements ImageDescriptionRepository {
  /// Creates the repository over [dio].
  HttpImageDescriptionRepository(this._dio);

  final Dio _dio;

  @override
  Future<DescriptionResult> describe({
    required Uint8List jpeg,
    required String language,
    String? userId,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '${Env.apiBaseUrl}/api/describe-image',
        data: FormData.fromMap({
          'image': MultipartFile.fromBytes(jpeg, filename: 'image.jpg'),
          'language': language,
          if (userId != null) 'user_id': userId else 'guest': 'true',
        }),
        options: Options(receiveTimeout: const Duration(seconds: 40)),
      );
      final body = response.data;
      final text = body?['description'];
      if (text is! String || text.trim().isEmpty) {
        throw const DescriptionException('empty description');
      }
      return DescriptionResult(
        description: text.trim(),
        hasText: body?['has_text'] == true,
      );
    } on DioException catch (e) {
      throw DescriptionException('${e.type}: ${e.message}');
    }
  }
}

/// The app's description service: the mock while `USE_MOCK_API` is true.
final imageDescriptionRepositoryProvider = Provider<ImageDescriptionRepository>(
  (ref) => Env.useMockApi
      ? const MockImageDescriptionRepository()
      : HttpImageDescriptionRepository(Dio()),
);

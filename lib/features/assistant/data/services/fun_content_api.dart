import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/constants/api_constants.dart';
import '../models/fun_content.dart';

class FunContentException implements Exception {
  final String message;
  const FunContentException(this.message);
  @override
  String toString() => message;
}

/// Pulls quotes, jokes and fun facts from free public APIs.
class FunContentApi {
  FunContentApi._();
  static final FunContentApi instance = FunContentApi._();

  static const Duration _timeout = Duration(seconds: 10);

  Future<FunContent> fetch(FunType type) => switch (type) {
        FunType.quote => quote(),
        FunType.joke => joke(),
        FunType.fact => fact(),
      };

  Future<FunContent> quote() async {
    final data = await _getJson(ApiConstants.quotesUrl);
    // ZenQuotes returns a list: [{ "q": "...", "a": "Author" }]
    if (data is List && data.isNotEmpty) {
      final item = data.first as Map<String, dynamic>;
      return FunContent(
        type: FunType.quote,
        text: (item['q'] as String?)?.trim() ?? '',
        author: (item['a'] as String?)?.trim(),
      );
    }
    throw const FunContentException('Could not load a quote right now.');
  }

  Future<FunContent> joke() async {
    final data = await _getJson(ApiConstants.jokeUrl);
    if (data is Map<String, dynamic>) {
      final text = (data['joke'] as String?) ??
          (data['setup'] as String?) ??
          'I forgot the punchline 😅';
      return FunContent(type: FunType.joke, text: text);
    }
    throw const FunContentException('Could not load a joke right now.');
  }

  Future<FunContent> fact() async {
    final data = await _getJson(ApiConstants.factUrl);
    if (data is Map<String, dynamic>) {
      return FunContent(
        type: FunType.fact,
        text: (data['text'] as String?)?.trim() ?? '',
      );
    }
    throw const FunContentException('Could not load a fact right now.');
  }

  Future<dynamic> _getJson(String url) async {
    try {
      final res = await http.get(Uri.parse(url)).timeout(_timeout);
      if (res.statusCode != 200) {
        throw FunContentException('Service error (${res.statusCode}).');
      }
      return jsonDecode(res.body);
    } on FunContentException {
      rethrow;
    } catch (_) {
      throw const FunContentException('Network hiccup — try again in a moment.');
    }
  }
}

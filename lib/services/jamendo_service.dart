import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/music.dart';
import 'package:flutter/foundation.dart';

class JamendoService {
  static const String baseUrl = 'https://api.jamendo.com/v3.0';
  static const String clientId = 'a0c15f29'; // Jamendo'dan aldığınız Client ID
  static const Duration apiTimeout = Duration(seconds: 10); // API timeout

  Future<List<Music>> getFeaturedTracks({int limit = 20}) async {
    try {
      final uri = Uri.parse(
        'https://api.jamendo.com/v3.0/tracks/?client_id=$clientId&format=jsonpretty&limit=$limit&order=popularity_total&fuzzytags=instrumental',
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['results'] != null) {
          final tracks = data['results'] as List;

          if (tracks.isNotEmpty) {
            final musicList =
                tracks
                    .map((track) => Music.fromJamendoJson(track))
                    .where((music) => music.streamUrl.isNotEmpty)
                    .toList();

            return musicList;
          }
        }

        return [];
      } else {
        throw Exception('API returned status ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Jamendo API Error (Featured): $e');
      return [];
    }
  }

  Future<List<Music>> searchTracks(String query, {int limit = 20}) async {
    try {
      final uri = Uri.parse(
        'https://api.jamendo.com/v3.0/tracks/?client_id=$clientId&format=jsonpretty&limit=$limit&search=$query',
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['results'] != null) {
          final tracks = data['results'] as List;

          final musicList =
              tracks
                  .map((track) => Music.fromJamendoJson(track))
                  .where((music) => music.streamUrl.isNotEmpty)
                  .toList();

          return musicList;
        }

        return [];
      } else {
        throw Exception('Search API returned status ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Jamendo API Error (Search): $e');
      return [];
    }
  }

  Future<List<Music>> getTracksByGenre(String genre, {int limit = 20}) async {
    try {
      final uri = Uri.parse(
        'https://api.jamendo.com/v3.0/tracks/?client_id=$clientId&format=jsonpretty&limit=$limit&tags=$genre',
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['results'] != null) {
          final tracks = data['results'] as List;

          if (tracks.isNotEmpty) {
            final musicList =
                tracks
                    .map(
                      (track) => Music.fromJamendoJsonWithGenre(track, genre),
                    )
                    .where((music) => music.streamUrl.isNotEmpty)
                    .toList();

            return musicList;
          }
        }

        return [];
      } else {
        throw Exception('$genre API returned status ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Jamendo API Error ($genre): $e');
      return [];
    }
  }

  Future<List<Music>> getPopularTracks({int limit = 20}) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/tracks'
        '?client_id=$clientId'
        '&format=json'
        '&limit=$limit'
        '&order=popularity_total'
        '&include=musicinfo+audiodownload',
      );

      final response = await http.get(uri).timeout(apiTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final tracks = data['results'] as List;

        return tracks.map((track) => Music.fromJamendoJson(track)).toList();
      }
    } catch (e) {
      debugPrint('Jamendo API Error (Popular): $e');
    }
    return [];
  }

  // Paralel API çağrıları için yardımcı metod
  Future<List<Music>> getAllGenresParallel({int limitPerGenre = 10}) async {
    try {
      final genres = ['rock', 'pop', 'electronic', 'jazz', 'classical'];

      // Paralel API çağrıları
      final futures = genres.map(
        (genre) => getTracksByGenre(genre, limit: limitPerGenre),
      );

      final results = await Future.wait(futures);

      final allTracks = <Music>[];
      for (int i = 0; i < results.length; i++) {
        final result = results[i];
        allTracks.addAll(result);
      }

      return allTracks;
    } catch (e) {
      debugPrint('❌ Parallel API Error: $e');
      return [];
    }
  }
}

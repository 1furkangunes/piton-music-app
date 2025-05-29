import 'package:flutter/foundation.dart';

class Music {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String imageUrl;
  final String genre;
  final String duration;
  final String streamUrl;
  final String downloadUrl;

  const Music({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.imageUrl,
    required this.genre,
    required this.duration,
    required this.streamUrl,
    required this.downloadUrl,
  });

  factory Music.fromJamendoJson(Map<String, dynamic> json) {
    return Music(
      id: json['id'].toString(),
      title: json['name'] ?? 'Unknown Title',
      artist: json['artist_name'] ?? 'Unknown Artist',
      album: json['album_name'] ?? 'Unknown Album',
      imageUrl: json['album_image'] ?? '',
      genre: _extractGenreFromJson(json),
      duration: _formatDuration(json['duration'] ?? 0),
      streamUrl: json['audio'] ?? '',
      downloadUrl: json['audiodownload'] ?? json['audio'] ?? '',
    );
  }

  factory Music.fromJamendoJsonWithGenre(
    Map<String, dynamic> json,
    String categoryGenre,
  ) {
    return Music(
      id: json['id'].toString(),
      title: json['name'] ?? 'Unknown Title',
      artist: json['artist_name'] ?? 'Unknown Artist',
      album: json['album_name'] ?? 'Unknown Album',
      imageUrl: json['album_image'] ?? '',
      genre: categoryGenre,
      duration: _formatDuration(json['duration'] ?? 0),
      streamUrl: json['audio'] ?? '',
      downloadUrl: json['audiodownload'] ?? json['audio'] ?? '',
    );
  }

  factory Music.fromJson(Map<String, dynamic> json) {
    return Music(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Unknown Title',
      artist: json['artist'] ?? 'Unknown Artist',
      album: json['album'] ?? 'Unknown Album',
      imageUrl: json['imageUrl'] ?? '',
      genre: json['genre'] ?? 'Unknown',
      duration: json['duration'] ?? '0:00',
      streamUrl: json['streamUrl'] ?? '',
      downloadUrl: json['downloadUrl'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'imageUrl': imageUrl,
      'genre': genre,
      'duration': duration,
      'streamUrl': streamUrl,
      'downloadUrl': downloadUrl,
    };
  }

  static String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  static String _extractGenreFromMusicInfo(Map<String, dynamic>? musicinfo) {
    try {
      final tags = musicinfo?['tags'];
      if (tags != null && tags['genres'] != null && tags['genres'].isNotEmpty) {
        return tags['genres'][0];
      }
    } catch (e) {
      // ignore errors
    }
    return 'Unknown';
  }

  static String _extractGenreFromJson(Map<String, dynamic> json) {
    final musicInfoGenre = _extractGenreFromMusicInfo(json['musicinfo']);
    if (musicInfoGenre != 'Unknown') {
      return musicInfoGenre;
    }

    final tagsGenre = _extractGenreFromTagsArray(json['tags']);
    if (tagsGenre != 'Unknown') {
      return tagsGenre;
    }

    return _extractGenreFromOtherFields(json);
  }

  static String _extractGenreFromTagsArray(dynamic tags) {
    try {
      if (tags != null && tags is List && tags.isNotEmpty) {
        return tags[0].toString();
      }
    } catch (e) {
      debugPrint('Error parsing tags array: $e');
    }
    return 'Unknown';
  }

  static String _extractGenreFromOtherFields(Map<String, dynamic> json) {
    try {
      final albumName = json['album_name']?.toString().toLowerCase() ?? '';
      final artistName = json['artist_name']?.toString().toLowerCase() ?? '';

      const genreKeywords = {
        'rock': 'Rock',
        'pop': 'Pop',
        'jazz': 'Jazz',
        'electronic': 'Electronic',
        'classical': 'Classical',
        'hip': 'Hip Hop',
        'rap': 'Hip Hop',
        'folk': 'Folk',
        'blues': 'Blues',
        'country': 'Country',
        'reggae': 'Reggae',
        'metal': 'Metal',
        'punk': 'Punk',
        'funk': 'Funk',
        'soul': 'Soul',
        'r&b': 'R&B',
        'ambient': 'Ambient',
        'techno': 'Techno',
        'house': 'House',
        'trance': 'Trance',
      };

      for (final keyword in genreKeywords.keys) {
        if (albumName.contains(keyword) || artistName.contains(keyword)) {
          return genreKeywords[keyword]!;
        }
      }
    } catch (e) {
      debugPrint('Error extracting genre from other fields: $e');
    }

    return 'Music';
  }
}

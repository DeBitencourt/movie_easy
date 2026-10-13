import '../core/constants/api_constants.dart';

enum MediaTypeEnum {
  movie,
  tv,
  dorama,
}

extension MediaTypeExtension on MediaTypeEnum {
  String get label {
    switch (this) {
      case MediaTypeEnum.movie:
        return 'Filme';
      case MediaTypeEnum.tv:
        return 'Série';
      case MediaTypeEnum.dorama:
        return 'Dorama';
    }
  }
}

class MediaItem {
  final String id;
  final String title;
  final String originalTitle;
  final String? englishTitle;
  final String? posterUrl;
  final String? backdropUrl;
  final String overview;
  final double rating;
  final String? releaseDate;
  final MediaTypeEnum type;
  final List<String> genres;
  final int? seasonCount;
  final int? episodeCount;

  MediaItem({
    required this.id,
    required this.title,
    required this.originalTitle,
    this.englishTitle,
    this.posterUrl,
    this.backdropUrl,
    required this.overview,
    required this.rating,
    this.releaseDate,
    required this.type,
    this.genres = const [],
    this.seasonCount,
    this.episodeCount,
  });

  // Factory para Filmes do TMDB
  factory MediaItem.fromTmdbMovie(Map<String, dynamic> json) {
    final poster = json['poster_path'] != null
        ? '${ApiConstants.tmdbImageW500}${json['poster_path']}'
        : null;
    final backdrop = json['backdrop_path'] != null
        ? '${ApiConstants.tmdbImageOriginal}${json['backdrop_path']}'
        : poster;

    return MediaItem(
      id: json['id'].toString(),
      title: json['title'] ?? json['original_title'] ?? 'Sem título',
      originalTitle: json['original_title'] ?? json['title'] ?? '',
      posterUrl: poster,
      backdropUrl: backdrop,
      overview: json['overview'] ?? 'Sem sinopse disponível.',
      rating: ((json['vote_average'] ?? 0.0) as num).toDouble(),
      releaseDate: json['release_date'],
      type: MediaTypeEnum.movie,
    );
  }

  // Factory para Séries ou Doramas do TMDB
  factory MediaItem.fromTmdbTv(Map<String, dynamic> json, {bool isDorama = false}) {
    final poster = json['poster_path'] != null
        ? '${ApiConstants.tmdbImageW500}${json['poster_path']}'
        : null;
    final backdrop = json['backdrop_path'] != null
        ? '${ApiConstants.tmdbImageOriginal}${json['backdrop_path']}'
        : poster;

    final originCountries = (json['origin_country'] as List?)?.map((c) => c.toString()).toList() ?? [];
    final origLang = (json['original_language'] as String?)?.toLowerCase();
    final isAsianDrama = isDorama ||
        originCountries.contains('KR') ||
        originCountries.contains('JP') ||
        originCountries.contains('CN') ||
        originCountries.contains('TW') ||
        originCountries.contains('TH') ||
        origLang == 'ko' ||
        origLang == 'ja' ||
        origLang == 'zh';

    return MediaItem(
      id: json['id'].toString(),
      title: json['name'] ?? json['original_name'] ?? 'Sem título',
      originalTitle: json['original_name'] ?? json['name'] ?? '',
      englishTitle: json['english_title'] as String?,
      posterUrl: poster,
      backdropUrl: backdrop,
      overview: json['overview'] ?? 'Sem sinopse disponível.',
      rating: ((json['vote_average'] ?? 0.0) as num).toDouble(),
      releaseDate: json['first_air_date'],
      type: isAsianDrama ? MediaTypeEnum.dorama : MediaTypeEnum.tv,
      seasonCount: json['number_of_seasons'],
      episodeCount: json['number_of_episodes'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'originalTitle': originalTitle,
    'englishTitle': englishTitle,
    'posterUrl': posterUrl,
    'backdropUrl': backdropUrl,
    'overview': overview,
    'rating': rating,
    'releaseDate': releaseDate,
    'type': type.name,
    'genres': genres,
    'seasonCount': seasonCount,
    'episodeCount': episodeCount,
  };

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    MediaTypeEnum parsedType = MediaTypeEnum.movie;
    if (json['type'] != null) {
      try {
        parsedType = MediaTypeEnum.values.firstWhere((t) => t.name == json['type']);
      } catch (_) {}
    }

    return MediaItem(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? 'Sem título',
      originalTitle: json['originalTitle'] as String? ?? '',
      englishTitle: json['englishTitle'] as String?,
      posterUrl: json['posterUrl'] as String?,
      backdropUrl: json['backdropUrl'] as String?,
      overview: json['overview'] as String? ?? '',
      rating: ((json['rating'] ?? 0.0) as num).toDouble(),
      releaseDate: json['releaseDate'] as String?,
      type: parsedType,
      genres: (json['genres'] as List?)?.map((g) => g.toString()).toList() ?? const [],
      seasonCount: json['seasonCount'] as int?,
      episodeCount: json['episodeCount'] as int?,
    );
  }
}


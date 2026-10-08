import '../core/constants/api_constants.dart';

enum MediaTypeEnum {
  movie,
  tv,
  dorama,
  anime,
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
      case MediaTypeEnum.anime:
        return 'Anime';
    }
  }
}

class MediaItem {
  final String id;
  final String title;
  final String originalTitle;
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

    return MediaItem(
      id: json['id'].toString(),
      title: json['name'] ?? json['original_name'] ?? 'Sem título',
      originalTitle: json['original_name'] ?? json['name'] ?? '',
      posterUrl: poster,
      backdropUrl: backdrop,
      overview: json['overview'] ?? 'Sem sinopse disponível.',
      rating: ((json['vote_average'] ?? 0.0) as num).toDouble(),
      releaseDate: json['first_air_date'],
      type: isDorama ? MediaTypeEnum.dorama : MediaTypeEnum.tv,
      seasonCount: json['number_of_seasons'],
      episodeCount: json['number_of_episodes'],
    );
  }

  // Factory para Animes do AniList GraphQL
  factory MediaItem.fromAniList(Map<String, dynamic> json) {
    final titleMap = json['title'] as Map<String, dynamic>?;
    final romaji = titleMap?['romaji'] ?? '';
    final english = titleMap?['english'] ?? '';
    final native = titleMap?['native'] ?? '';

    // Prioriza o título em inglês/romaji para visualização clara
    final displayTitle = english.isNotEmpty ? english : (romaji.isNotEmpty ? romaji : native);
    final searchTitle = romaji.isNotEmpty ? romaji : (english.isNotEmpty ? english : displayTitle);

    final coverImage = json['coverImage']?['extraLarge'] ?? json['coverImage']?['large'];
    final bannerImage = json['bannerImage'] ?? coverImage;

    // Remove tags HTML básicas da sinopse do AniList (<br>, <i>, etc.)
    String rawDesc = json['description'] ?? 'Sem sinopse disponível.';
    rawDesc = rawDesc.replaceAll(RegExp(r'<[^>]*>'), '');

    final rawScore = json['averageScore'];
    final double score = rawScore != null ? (rawScore as num).toDouble() / 10.0 : 0.0;

    final genresList = (json['genres'] as List<dynamic>?)
            ?.map((g) => g.toString())
            .toList() ??
        [];

    final startDate = json['startDate'];
    String? formattedDate;
    if (startDate != null && startDate['year'] != null) {
      formattedDate = '${startDate['year']}';
    }

    return MediaItem(
      id: json['id'].toString(),
      title: displayTitle,
      originalTitle: searchTitle,
      posterUrl: coverImage,
      backdropUrl: bannerImage,
      overview: rawDesc,
      rating: score,
      releaseDate: formattedDate,
      type: MediaTypeEnum.anime,
      genres: genresList,
      episodeCount: json['episodes'],
    );
  }
}

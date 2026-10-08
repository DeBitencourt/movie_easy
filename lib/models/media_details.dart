import 'media_item.dart';

class EpisodeItem {
  final int episodeNumber;
  final int seasonNumber;
  final String title;
  final String? overview;
  final String? stillUrl;
  final String? airDate;

  EpisodeItem({
    required this.episodeNumber,
    required this.seasonNumber,
    required this.title,
    this.overview,
    this.stillUrl,
    this.airDate,
  });

  factory EpisodeItem.fromTmdb(Map<String, dynamic> json) {
    final still = json['still_path'] != null
        ? 'https://image.tmdb.org/t/p/w500${json['still_path']}'
        : null;

    return EpisodeItem(
      episodeNumber: json['episode_number'] ?? 1,
      seasonNumber: json['season_number'] ?? 1,
      title: json['name'] ?? 'Episódio ${json['episode_number']}',
      overview: json['overview'],
      stillUrl: still,
      airDate: json['air_date'],
    );
  }
}

class SeasonInfo {
  final int seasonNumber;
  final String name;
  final int episodeCount;
  final String? posterUrl;

  SeasonInfo({
    required this.seasonNumber,
    required this.name,
    required this.episodeCount,
    this.posterUrl,
  });

  factory SeasonInfo.fromTmdb(Map<String, dynamic> json) {
    return SeasonInfo(
      seasonNumber: json['season_number'] ?? 1,
      name: json['name'] ?? 'Temporada ${json['season_number']}',
      episodeCount: json['episode_count'] ?? 0,
      posterUrl: json['poster_path'] != null
          ? 'https://image.tmdb.org/t/p/w500${json['poster_path']}'
          : null,
    );
  }
}

class MediaDetails {
  final MediaItem item;
  final String? tagline;
  final int? runtimeMinutes;
  final String? status;
  final List<String> genres;
  final List<SeasonInfo> seasons;
  final List<String> cast;

  MediaDetails({
    required this.item,
    this.tagline,
    this.runtimeMinutes,
    this.status,
    this.genres = const [],
    this.seasons = const [],
    this.cast = const [],
  });
}

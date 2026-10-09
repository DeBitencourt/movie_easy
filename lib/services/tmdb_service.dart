import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';
import '../models/media_item.dart';
import '../models/media_details.dart';

class TmdbService {
  final String apiKey;

  TmdbService({String? apiKey})
      : apiKey = apiKey ?? ApiConstants.defaultTmdbApiKey;

  Future<List<MediaItem>> _fetchList(
    String endpoint, {
    Map<String, String>? extraParams,
    bool isTv = false,
    bool isDorama = false,
    int page = 1,
  }) async {
    final queryParams = {
      'api_key': apiKey,
      'language': 'pt-BR',
      'page': page.toString(),
      ...?extraParams,
    };

    final uri = Uri.parse('${ApiConstants.tmdbBaseUrl}$endpoint').replace(queryParameters: queryParams);
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List results = data['results'] ?? [];
      return results.map((item) {
        if (isTv || isDorama) {
          return MediaItem.fromTmdbTv(item, isDorama: isDorama);
        } else {
          return MediaItem.fromTmdbMovie(item);
        }
      }).toList();
    } else {
      throw Exception('Erro ao buscar dados do TMDB: ${response.statusCode}');
    }
  }

  // --- FILMES ---
  Future<List<MediaItem>> getTrendingMovies({int page = 1}) => _fetchList('/trending/movie/week', page: page);
  Future<List<MediaItem>> getPopularMovies({int page = 1}) => _fetchList('/movie/popular', page: page);
  Future<List<MediaItem>> getTopRatedMovies({int page = 1}) => _fetchList('/movie/top_rated', page: page);

  // --- SÉRIES ---
  Future<List<MediaItem>> getTrendingTv({int page = 1}) => _fetchList('/trending/tv/week', isTv: true, page: page);
  Future<List<MediaItem>> getPopularTv({int page = 1}) => _fetchList('/tv/popular', isTv: true, page: page);
  Future<List<MediaItem>> getTopRatedTv({int page = 1}) => _fetchList('/tv/top_rated', isTv: true, page: page);

  // --- DORAMAS (K-Dramas com país de origem KR e JP) ---
  Future<List<MediaItem>> getPopularDoramas({int page = 1}) => _fetchList(
        '/discover/tv',
        extraParams: {
          'with_origin_country': 'KR',
          'sort_by': 'popularity.desc',
          'vote_count.gte': '20',
        },
        isDorama: true,
        page: page,
      );

  Future<List<MediaItem>> getTopRatedDoramas({int page = 1}) => _fetchList(
        '/discover/tv',
        extraParams: {
          'with_origin_country': 'KR',
          'sort_by': 'vote_average.desc',
          'vote_count.gte': '100',
        },
        isDorama: true,
        page: page,
      );

  // --- BUSCA GERAL ---
  Future<List<MediaItem>> search(String query) async {
    if (query.trim().isEmpty) return [];

    final uri = Uri.parse('${ApiConstants.tmdbBaseUrl}/search/multi').replace(queryParameters: {
      'api_key': apiKey,
      'language': 'pt-BR',
      'query': query,
      'include_adult': 'false',
    });

    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List results = data['results'] ?? [];
      final List<MediaItem> items = [];

      for (var item in results) {
        final mediaType = item['media_type'];
        if (mediaType == 'movie') {
          items.add(MediaItem.fromTmdbMovie(item));
        } else if (mediaType == 'tv') {
          final originCountries = (item['origin_country'] as List?) ?? [];
          final isDorama = originCountries.contains('KR') || originCountries.contains('JP');
          items.add(MediaItem.fromTmdbTv(item, isDorama: isDorama));
        }
      }
      return items;
    }
    return [];
  }

  // --- DETALHES DE FILME ---
  Future<MediaDetails> getMovieDetails(String id) async {
    final uri = Uri.parse('${ApiConstants.tmdbBaseUrl}/movie/$id').replace(queryParameters: {
      'api_key': apiKey,
      'language': 'pt-BR',
      'append_to_response': 'credits,alternative_titles,translations',
    });

    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final item = MediaItem.fromTmdbMovie(json);

      String? englishTitle;
      final translations = json['translations']?['translations'] as List?;
      if (translations != null) {
        for (final t in translations) {
          if (t['iso_639_1'] == 'en') {
            final title = t['data']?['title']?.toString();
            if (title != null && title.trim().isNotEmpty) {
              englishTitle = title.trim();
              break;
            }
          }
        }
      }
      if (englishTitle == null) {
        final altTitles = json['alternative_titles']?['titles'] as List?;
        if (altTitles != null) {
          for (final alt in altTitles) {
            if (alt['iso_3166_1'] == 'US' || alt['iso_3166_1'] == 'GB') {
              final title = alt['title']?.toString();
              if (title != null && title.trim().isNotEmpty) {
                englishTitle = title.trim();
                break;
              }
            }
          }
        }
      }

      final genres = (json['genres'] as List?)?.map((g) => g['name'].toString()).toList() ?? [];
      final cast = (json['credits']?['cast'] as List?)
              ?.take(6)
              .map((c) => c['name'].toString())
              .toList() ??
          [];

      return MediaDetails(
        item: item,
        tagline: json['tagline'],
        runtimeMinutes: json['runtime'],
        status: json['status'],
        genres: genres,
        cast: cast,
        englishTitle: englishTitle,
      );
    }
    throw Exception('Falha ao obter detalhes do filme: ${response.statusCode}');
  }

  // --- DETALHES DE SÉRIE / DORAMA ---
  Future<MediaDetails> getTvDetails(String id, {bool isDorama = false}) async {
    final uri = Uri.parse('${ApiConstants.tmdbBaseUrl}/tv/$id').replace(queryParameters: {
      'api_key': apiKey,
      'language': 'pt-BR',
      'append_to_response': 'credits,alternative_titles,translations',
    });

    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final item = MediaItem.fromTmdbTv(json, isDorama: isDorama);

      String? englishTitle;
      final translations = json['translations']?['translations'] as List?;
      if (translations != null) {
        for (final t in translations) {
          if (t['iso_639_1'] == 'en') {
            final name = t['data']?['name']?.toString();
            if (name != null && name.trim().isNotEmpty) {
              englishTitle = name.trim();
              break;
            }
          }
        }
      }
      if (englishTitle == null) {
        final altTitles = json['alternative_titles']?['results'] as List?;
        if (altTitles != null) {
          for (final alt in altTitles) {
            if (alt['iso_3166_1'] == 'US' || alt['iso_3166_1'] == 'GB') {
              final title = alt['title']?.toString();
              if (title != null && title.trim().isNotEmpty) {
                englishTitle = title.trim();
                break;
              }
            }
          }
        }
      }

      final genres = (json['genres'] as List?)?.map((g) => g['name'].toString()).toList() ?? [];
      final cast = (json['credits']?['cast'] as List?)
              ?.take(6)
              .map((c) => c['name'].toString())
              .toList() ??
          [];
      final seasons = (json['seasons'] as List?)
              ?.map((s) => SeasonInfo.fromTmdb(s))
              .where((s) => s.seasonNumber > 0) // Ignora especiais temporada 0
              .toList() ??
          [];

      return MediaDetails(
        item: item,
        tagline: json['tagline'],
        status: json['status'],
        genres: genres,
        seasons: seasons,
        cast: cast,
        englishTitle: englishTitle,
      );
    }
    throw Exception('Falha ao obter detalhes da série: ${response.statusCode}');
  }

  // --- EPISÓDIOS DE UMA TEMPORADA ---
  Future<List<EpisodeItem>> getSeasonEpisodes(String tvId, int seasonNumber) async {
    final uri = Uri.parse('${ApiConstants.tmdbBaseUrl}/tv/$tvId/season/$seasonNumber').replace(queryParameters: {
      'api_key': apiKey,
      'language': 'pt-BR',
    });

    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final episodes = (json['episodes'] as List?)
              ?.map((e) => EpisodeItem.fromTmdb(e))
              .toList() ??
          [];
      return episodes;
    }
    return [];
  }
}

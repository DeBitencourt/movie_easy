import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';
import '../models/media_item.dart';
import '../models/media_details.dart';

class TmdbService {
  final String apiKey;

  TmdbService({String? apiKey})
      : apiKey = apiKey ?? ApiConstants.defaultTmdbApiKey;

  Future<List<MediaItem>> _fetchList(String endpoint, {Map<String, String>? extraParams, bool isTv = false, bool isDorama = false}) async {
    final queryParams = {
      'api_key': apiKey,
      'language': 'pt-BR',
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
  Future<List<MediaItem>> getTrendingMovies() => _fetchList('/trending/movie/week');
  Future<List<MediaItem>> getPopularMovies() => _fetchList('/movie/popular');
  Future<List<MediaItem>> getTopRatedMovies() => _fetchList('/movie/top_rated');

  // --- SÉRIES ---
  Future<List<MediaItem>> getTrendingTv() => _fetchList('/trending/tv/week', isTv: true);
  Future<List<MediaItem>> getPopularTv() => _fetchList('/tv/popular', isTv: true);
  Future<List<MediaItem>> getTopRatedTv() => _fetchList('/tv/top_rated', isTv: true);

  // --- DORAMAS (K-Dramas com país de origem KR e JP) ---
  Future<List<MediaItem>> getPopularDoramas() => _fetchList(
        '/discover/tv',
        extraParams: {
          'with_origin_country': 'KR',
          'sort_by': 'popularity.desc',
          'vote_count.gte': '20',
        },
        isDorama: true,
      );

  Future<List<MediaItem>> getTopRatedDoramas() => _fetchList(
        '/discover/tv',
        extraParams: {
          'with_origin_country': 'KR',
          'sort_by': 'vote_average.desc',
          'vote_count.gte': '100',
        },
        isDorama: true,
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
      'append_to_response': 'credits',
    });

    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final item = MediaItem.fromTmdbMovie(json);

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
      );
    }
    throw Exception('Falha ao obter detalhes do filme: ${response.statusCode}');
  }

  // --- DETALHES DE SÉRIE / DORAMA ---
  Future<MediaDetails> getTvDetails(String id, {bool isDorama = false}) async {
    final uri = Uri.parse('${ApiConstants.tmdbBaseUrl}/tv/$id').replace(queryParameters: {
      'api_key': apiKey,
      'language': 'pt-BR',
      'append_to_response': 'credits',
    });

    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final item = MediaItem.fromTmdbTv(json, isDorama: isDorama);

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

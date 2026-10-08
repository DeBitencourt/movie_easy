import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';
import '../models/media_item.dart';
import '../models/media_details.dart';

class AniListService {
  static const String _mediaFragment = '''
    id
    title {
      romaji
      english
      native
    }
    coverImage {
      large
      extraLarge
    }
    bannerImage
    description
    averageScore
    genres
    episodes
    startDate {
      year
    }
  ''';

  Future<List<MediaItem>> _runQuery(String query, {Map<String, dynamic>? variables}) async {
    final response = await http.post(
      Uri.parse(ApiConstants.anilistGraphqlUrl),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'query': query,
        if (variables != null) 'variables': variables,
      }),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final mediaList = json['data']?['Page']?['media'] as List?;
      if (mediaList != null) {
        return mediaList.map((item) => MediaItem.fromAniList(item)).toList();
      }
      return [];
    } else {
      throw Exception('Erro ao consultar AniList API: ${response.statusCode}');
    }
  }

  // --- ANIMES EM ALTA (TRENDING) ---
  Future<List<MediaItem>> getTrendingAnime({int page = 1, int perPage = 20}) {
    const query = '''
      query (\$page: Int, \$perPage: Int) {
        Page(page: \$page, perPage: \$perPage) {
          media(type: ANIME, sort: [TRENDING_DESC], isAdult: false) {
            $_mediaFragment
          }
        }
      }
    ''';
    return _runQuery(query, variables: {'page': page, 'perPage': perPage});
  }

  // --- MAIS POPULARES DE TODOS OS TEMPOS ---
  Future<List<MediaItem>> getPopularAnime({int page = 1, int perPage = 20}) {
    const query = '''
      query (\$page: Int, \$perPage: Int) {
        Page(page: \$page, perPage: \$perPage) {
          media(type: ANIME, sort: [POPULARITY_DESC], isAdult: false) {
            $_mediaFragment
          }
        }
      }
    ''';
    return _runQuery(query, variables: {'page': page, 'perPage': perPage});
  }

  // --- MAIS BEM AVALIADOS (TOP RATED) ---
  Future<List<MediaItem>> getTopRatedAnime({int page = 1, int perPage = 20}) {
    const query = '''
      query (\$page: Int, \$perPage: Int) {
        Page(page: \$page, perPage: \$perPage) {
          media(type: ANIME, sort: [SCORE_DESC], isAdult: false) {
            $_mediaFragment
          }
        }
      }
    ''';
    return _runQuery(query, variables: {'page': page, 'perPage': perPage});
  }

  // --- BUSCA DE ANIME ---
  Future<List<MediaItem>> searchAnime(String search, {int perPage = 20}) {
    if (search.trim().isEmpty) return Future.value([]);
    const query = '''
      query (\$search: String, \$perPage: Int) {
        Page(page: 1, perPage: \$perPage) {
          media(type: ANIME, search: \$search, isAdult: false) {
            $_mediaFragment
          }
        }
      }
    ''';
    return _runQuery(query, variables: {'search': search, 'perPage': perPage});
  }

  // --- DETALHES DE ANIME ---
  Future<MediaDetails> getAnimeDetails(String id) async {
    const query = '''
      query (\$id: Int) {
        Media(id: \$id, type: ANIME) {
          $_mediaFragment
          status
          duration
          characters(perPage: 6, sort: [ROLE, RELEVANCE]) {
            nodes {
              name {
                full
              }
            }
          }
        }
      }
    ''';

    final response = await http.post(
      Uri.parse(ApiConstants.anilistGraphqlUrl),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'query': query,
        'variables': {'id': int.tryParse(id) ?? 0},
      }),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final mediaData = json['data']?['Media'];
      if (mediaData != null) {
        final item = MediaItem.fromAniList(mediaData);
        final genres = (mediaData['genres'] as List?)?.map((g) => g.toString()).toList() ?? [];
        final characterNodes = mediaData['characters']?['nodes'] as List?;
        final cast = characterNodes?.map((c) => c['name']?['full']?.toString() ?? '').where((n) => n.isNotEmpty).toList() ?? [];

        return MediaDetails(
          item: item,
          runtimeMinutes: mediaData['duration'],
          status: mediaData['status'],
          genres: genres,
          cast: cast,
        );
      }
    }
    throw Exception('Falha ao obter detalhes do anime: ${response.statusCode}');
  }
}

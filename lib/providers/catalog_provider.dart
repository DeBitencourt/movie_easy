import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../services/tmdb_service.dart';
import '../services/anilist_service.dart';

class CatalogProvider extends ChangeNotifier {
  final TmdbService _tmdbService = TmdbService();
  final AniListService _aniListService = AniListService();

  bool _isLoading = false;
  String? _errorMessage;

  // Listas da Home
  MediaItem? _heroFeatured;
  List<MediaItem> _trendingMovies = [];
  List<MediaItem> _popularMovies = [];
  List<MediaItem> _trendingTv = [];
  List<MediaItem> _popularTv = [];
  List<MediaItem> _popularDoramas = [];
  List<MediaItem> _trendingAnime = [];
  List<MediaItem> _popularAnime = [];

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  MediaItem? get heroFeatured => _heroFeatured;
  List<MediaItem> get trendingMovies => _trendingMovies;
  List<MediaItem> get popularMovies => _popularMovies;
  List<MediaItem> get trendingTv => _trendingTv;
  List<MediaItem> get popularTv => _popularTv;
  List<MediaItem> get popularDoramas => _popularDoramas;
  List<MediaItem> get trendingAnime => _trendingAnime;
  List<MediaItem> get popularAnime => _popularAnime;

  Future<void> loadHomeCatalog() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _tmdbService.getTrendingMovies(),
        _tmdbService.getPopularMovies(),
        _tmdbService.getTrendingTv(),
        _tmdbService.getPopularTv(),
        _tmdbService.getPopularDoramas(),
        _aniListService.getTrendingAnime(),
        _aniListService.getPopularAnime(),
      ]);

      _trendingMovies = results[0];
      _popularMovies = results[1];
      _trendingTv = results[2];
      _popularTv = results[3];
      _popularDoramas = results[4];
      _trendingAnime = results[5];
      _popularAnime = results[6];

      // Escolhe um item em destaque dinâmico para o banner principal (o #1 em alta com bom backdrop)
      if (_trendingMovies.isNotEmpty) {
        _heroFeatured = _trendingMovies.firstWhere(
          (m) => m.backdropUrl != null && m.backdropUrl!.isNotEmpty,
          orElse: () => _trendingMovies.first,
        );
      }
    } catch (e) {
      _errorMessage = 'Falha ao carregar o catálogo: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Busca unificada (Filmes, Séries, Doramas e Animes)
  Future<List<MediaItem>> searchAll(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final tmdbFuture = _tmdbService.search(query);
      final animeFuture = _aniListService.searchAnime(query);

      final results = await Future.wait([tmdbFuture, animeFuture]);
      final List<MediaItem> combined = [];
      combined.addAll(results[0]);
      combined.addAll(results[1]);
      return combined;
    } catch (e) {
      return [];
    }
  }

  // Carregador específico para cada categoria
  Future<List<MediaItem>> getCategoryItems(MediaTypeEnum type, {String filter = 'popular'}) async {
    switch (type) {
      case MediaTypeEnum.movie:
        if (filter == 'top_rated') return _tmdbService.getTopRatedMovies();
        if (filter == 'trending') return _tmdbService.getTrendingMovies();
        return _tmdbService.getPopularMovies();
      case MediaTypeEnum.tv:
        if (filter == 'top_rated') return _tmdbService.getTopRatedTv();
        if (filter == 'trending') return _tmdbService.getTrendingTv();
        return _tmdbService.getPopularTv();
      case MediaTypeEnum.dorama:
        if (filter == 'top_rated') return _tmdbService.getTopRatedDoramas();
        return _tmdbService.getPopularDoramas();
      case MediaTypeEnum.anime:
        if (filter == 'top_rated') return _aniListService.getTopRatedAnime();
        if (filter == 'trending') return _aniListService.getTrendingAnime();
        return _aniListService.getPopularAnime();
    }
  }
}

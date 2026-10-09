import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../services/tmdb_service.dart';

class CatalogProvider extends ChangeNotifier {
  final TmdbService _tmdbService = TmdbService();

  bool _isLoading = false;
  String? _errorMessage;

  // Listas da Home
  MediaItem? _heroFeatured;
  List<MediaItem> _trendingMovies = [];
  List<MediaItem> _popularMovies = [];
  List<MediaItem> _trendingTv = [];
  List<MediaItem> _popularTv = [];
  List<MediaItem> _popularDoramas = [];

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  MediaItem? get heroFeatured => _heroFeatured;
  List<MediaItem> get trendingMovies => _trendingMovies;
  List<MediaItem> get popularMovies => _popularMovies;
  List<MediaItem> get trendingTv => _trendingTv;
  List<MediaItem> get popularTv => _popularTv;
  List<MediaItem> get popularDoramas => _popularDoramas;

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
      ]);

      _trendingMovies = results[0];
      _popularMovies = results[1];
      _trendingTv = results[2];
      _popularTv = results[3];
      _popularDoramas = results[4];

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

  // Busca unificada (Filmes, Séries e Doramas)
  Future<List<MediaItem>> searchAll(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final results = await _tmdbService.search(query);
      return results;
    } catch (e) {
      return [];
    }
  }

  // Carregador específico para cada categoria com paginação infinita
  Future<List<MediaItem>> getCategoryItems(MediaTypeEnum type, {String filter = 'popular', int page = 1}) async {
    switch (type) {
      case MediaTypeEnum.movie:
        if (filter == 'top_rated') return _tmdbService.getTopRatedMovies(page: page);
        if (filter == 'trending') return _tmdbService.getTrendingMovies(page: page);
        return _tmdbService.getPopularMovies(page: page);
      case MediaTypeEnum.tv:
        if (filter == 'top_rated') return _tmdbService.getTopRatedTv(page: page);
        if (filter == 'trending') return _tmdbService.getTrendingTv(page: page);
        return _tmdbService.getPopularTv(page: page);
      case MediaTypeEnum.dorama:
        if (filter == 'top_rated') return _tmdbService.getTopRatedDoramas(page: page);
        return _tmdbService.getPopularDoramas(page: page);
    }
  }
}

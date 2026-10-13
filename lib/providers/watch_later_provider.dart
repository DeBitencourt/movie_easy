import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/media_item.dart';
import '../models/watch_later_item.dart';

class WatchLaterProvider extends ChangeNotifier {
  static const String _storageKey = 'movie_easy_watch_later_v1';

  final List<WatchLaterItem> _items = [];
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  List<WatchLaterItem> get items => List.unmodifiable(_items);
  List<MediaItem> get mediaList => _items.map((i) => i.media).toList();
  int get count => _items.length;
  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;

  int get moviesCount =>
      _items.where((i) => i.media.type == MediaTypeEnum.movie).length;
  int get seriesCount =>
      _items.where((i) => i.media.type == MediaTypeEnum.tv).length;
  int get doramasCount =>
      _items.where((i) => i.media.type == MediaTypeEnum.dorama).length;

  Future<void> init() async {
    if (_isInitialized) return;
    await _loadFromStorage();
    _isInitialized = true;
    notifyListeners();
  }

  /// Verifica se uma obra já está salva na lista
  bool isSaved(String mediaId) {
    return _items.any((item) => item.media.id == mediaId);
  }

  /// Alterna o estado: se estiver na lista, remove; se não estiver, adiciona.
  /// Retorna `true` se foi adicionado, e `false` se foi removido.
  Future<bool> toggleWatchLater(MediaItem media) async {
    final existingIndex = _items.indexWhere((i) => i.media.id == media.id);
    final bool added;

    if (existingIndex >= 0) {
      _items.removeAt(existingIndex);
      added = false;
    } else {
      _items.insert(0, WatchLaterItem(media: media, addedAt: DateTime.now()));
      added = true;
    }

    notifyListeners();
    await _saveToStorage();
    return added;
  }

  /// Adiciona uma obra à lista de assistir mais tarde (se ainda não estiver presente)
  Future<void> addToWatchLater(MediaItem media) async {
    if (!isSaved(media.id)) {
      _items.insert(0, WatchLaterItem(media: media, addedAt: DateTime.now()));
      notifyListeners();
      await _saveToStorage();
    }
  }

  /// Remove uma obra da lista
  Future<void> removeFromWatchLater(String mediaId) async {
    final index = _items.indexWhere((i) => i.media.id == mediaId);
    if (index >= 0) {
      _items.removeAt(index);
      notifyListeners();
      await _saveToStorage();
    }
  }

  /// Limpa toda a lista de assistir mais tarde
  Future<void> clearAll() async {
    if (_items.isEmpty) return;
    _items.clear();
    notifyListeners();
    await _saveToStorage();
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.trim().isEmpty) return;

      final decoded = jsonDecode(raw) as List<dynamic>;
      _items.clear();
      for (final json in decoded) {
        try {
          _items.add(WatchLaterItem.fromJson(json as Map<String, dynamic>));
        } catch (e) {
          developer.log('Erro ao desserializar WatchLaterItem: $e');
        }
      }
    } catch (e) {
      developer.log('Erro ao carregar lista de Assistir Mais Tarde: $e');
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _items.map((i) => i.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(list));
    } catch (e) {
      developer.log('Erro ao salvar lista de Assistir Mais Tarde: $e');
    }
  }
}

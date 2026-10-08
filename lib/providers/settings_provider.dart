import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/api_constants.dart';

class SettingsProvider extends ChangeNotifier {
  late SharedPreferences _prefs;
  bool _initialized = false;

  String _tmdbApiKey = ApiConstants.defaultTmdbApiKey;
  String _preferredAudio = 'dublado'; // 'dublado', 'legendado'
  String _preferredQuality = '1080p'; // '720p', '1080p', '4k'

  bool get isInitialized => _initialized;
  String get tmdbApiKey => _tmdbApiKey;
  String get preferredAudio => _preferredAudio;
  String get preferredQuality => _preferredQuality;

  SettingsProvider() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    _tmdbApiKey = _prefs.getString('tmdb_api_key') ?? ApiConstants.defaultTmdbApiKey;
    _preferredAudio = _prefs.getString('preferred_audio') ?? 'dublado';
    _preferredQuality = _prefs.getString('preferred_quality') ?? '1080p';
    _initialized = true;
    notifyListeners();
  }

  Future<void> setTmdbApiKey(String key) async {
    _tmdbApiKey = key.trim().isEmpty ? ApiConstants.defaultTmdbApiKey : key.trim();
    await _prefs.setString('tmdb_api_key', _tmdbApiKey);
    notifyListeners();
  }

  Future<void> setPreferredAudio(String audio) async {
    _preferredAudio = audio;
    await _prefs.setString('preferred_audio', audio);
    notifyListeners();
  }

  Future<void> setPreferredQuality(String quality) async {
    _preferredQuality = quality;
    await _prefs.setString('preferred_quality', quality);
    notifyListeners();
  }
}

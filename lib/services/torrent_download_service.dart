import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:libtorrent_flutter/libtorrent_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/download_item.dart';
import '../models/media_item.dart';
import '../models/torrent_item.dart';
import 'comando_torrents_service.dart';
import 'kisskh_service.dart';
import 'subtitle_translation_service.dart';

/// Serviço singleton responsável por inicializar a engine de torrent
/// e coordenar os downloads e streaming sequencial.
class TorrentDownloadService {
  static final TorrentDownloadService _instance = TorrentDownloadService._internal();
  factory TorrentDownloadService() => _instance;
  TorrentDownloadService._internal();

  bool _isInitialized = false;
  String _defaultDownloadDirectory = '';
  static int _kisskhIdCounter = 1;

  final Map<int, DownloadItem> _downloads = {};
  final Map<int, http.Client> _httpClients = {};
  final Map<int, bool> _httpCancelled = {};
  final Map<int, bool> _httpPaused = {};
  final Map<int, IOSink> _activeFileSinks = {};
  final StreamController<List<DownloadItem>> _downloadsController =
      StreamController<List<DownloadItem>>.broadcast();

  Stream<List<DownloadItem>> get downloadsStream => _downloadsController.stream;
  List<DownloadItem> get allDownloads => _downloads.values.toList();
  String get downloadDirectory => _defaultDownloadDirectory;

  /// Inicializa o motor libtorrent e define a pasta padrão de downloads.
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      Directory? baseDir;
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        baseDir = await getDownloadsDirectory();
      }
      baseDir ??= await getApplicationDocumentsDirectory();

      final movieEasyDir = Directory('${baseDir.path}${Platform.pathSeparator}MovieEasy_Downloads');
      if (!await movieEasyDir.exists()) {
        await movieEasyDir.create(recursive: true);
      }
      _defaultDownloadDirectory = movieEasyDir.path;

      await LibtorrentFlutter.init(
        defaultSavePath: _defaultDownloadDirectory,
        fetchTrackers: true,
        pollInterval: const Duration(milliseconds: 600),
      );

      // Ouvir atualizações de progresso do motor nativo
      LibtorrentFlutter.instance.torrentUpdates.listen(_onTorrentUpdates);

      // Carregar histórico persistente de downloads (Biblioteca)
      await _loadDownloadsFromStorage();

      _isInitialized = true;
      developer.log('TorrentDownloadService inicializado com sucesso em: $_defaultDownloadDirectory');
    } catch (e, st) {
      developer.log('Falha ao inicializar LibtorrentFlutter: $e', error: e, stackTrace: st);
    }
  }

  void _onTorrentUpdates(Map<int, TorrentInfo> updates) {
    bool hasChanges = false;
    bool needsSave = false;

    for (final entry in updates.entries) {
      final id = entry.key;
      final info = entry.value;

      final item = _downloads[id];
      if (item != null) {
        final wasFinished = item.isFinished;
        item.progress = info.progress;
        item.downloadRate = info.downloadRate;
        item.uploadRate = info.uploadRate;
        item.totalDone = info.totalDone;
        item.totalWanted = info.totalWanted;
        item.numSeeds = info.numSeeds;
        item.numPeers = info.numPeers;
        item.isPaused = info.isPaused;
        item.isFinished = info.isFinished;
        item.hasMetadata = info.hasMetadata;
        if (!info.hasMetadata && !info.isPaused && !info.isFinished) {
          final peerCount = info.numSeeds + info.numPeers;
          item.stateLabel = peerCount > 0
              ? 'Baixando metadados ($peerCount pares)...'
              : 'Localizando pares na rede DHT...';
        } else {
          item.stateLabel = _mapStateToPortuguese(info.state, isPaused: info.isPaused);
        }
        if (!wasFinished && item.isFinished) {
          needsSave = true;
        }
        hasChanges = true;
      }
    }

    if (hasChanges) {
      _downloadsController.add(allDownloads);
    }
    if (needsSave) {
      _saveDownloadsToStorage();
    }
  }

  /// Adiciona um novo torrent à fila de download.
  Future<DownloadItem> startDownload({
    required TorrentItem torrent,
    required MediaItem media,
    String? customSavePath,
    int? seasonNumber,
    int? episodeNumber,
  }) async {
    if (!_isInitialized) {
      await init();
    }

    // Verificar se já existe um download para este infoHash
    final existing = _downloads.values.firstWhere(
      (d) => d.infoHash.toUpperCase() == torrent.infoHash.toUpperCase(),
      orElse: () => DownloadItem(
        id: -1,
        infoHash: '',
        title: '',
        magnetUrl: '',
        savePath: '',
      ),
    );

    if (existing.id != -1) {
      final isAliveInEngine = LibtorrentFlutter.instance.torrents.containsKey(existing.id);
      if (isAliveInEngine) {
        if (existing.isPaused) {
          resume(existing.id);
        }
        return existing;
      }

      // Se NÃO está ativo no motor (ex: após reiniciar o app), re-adiciona ao motor C++ nativo!
      final targetPath = existing.savePath.isNotEmpty ? existing.savePath : (customSavePath ?? _defaultDownloadDirectory);
      final enhancedMagnet = ComandoTorrentsService.injectFastTrackers(torrent.magnetUrl);
      final newId = LibtorrentFlutter.instance.addMagnet(
        enhancedMagnet,
        targetPath,
        false,
      );

      _downloads.remove(existing.id);
      existing.id = newId;
      existing.isPaused = false;
      existing.isFinished = false;
      existing.stateLabel = 'Conectando aos pares...';
      _downloads[newId] = existing;
      _downloadsController.add(allDownloads);
      _saveDownloadsToStorage();
      return existing;
    }

    final targetPath = customSavePath ?? _defaultDownloadDirectory;

    if (torrent.source.contains('KissKH') || torrent.magnetUrl.startsWith('kisskh://')) {
      return _startKisskhDownload(
        torrent: torrent,
        media: media,
        targetPath: targetPath,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
      );
    }

    final enhancedMagnet = ComandoTorrentsService.injectFastTrackers(torrent.magnetUrl);
    final torrentId = LibtorrentFlutter.instance.addMagnet(
      enhancedMagnet,
      targetPath,
      false, // streamOnly = false para download contínuo
    );

    final isMovie = media.type == MediaTypeEnum.movie;
    final epNum = isMovie ? null : (episodeNumber ?? torrent.episodeNumber);
    final seasonNum = isMovie ? null : seasonNumber;
    String cleanTitle = media.title;
    if (!isMovie && seasonNum != null && epNum != null) {
      cleanTitle = '${media.title} (T$seasonNum:E$epNum)';
    } else if (!isMovie && seasonNum != null) {
      cleanTitle = '${media.title} ($seasonNumª Temporada)';
    }

    final newItem = DownloadItem(
      id: torrentId,
      infoHash: torrent.infoHash,
      title: '$cleanTitle [${torrent.quality}]',
      magnetUrl: enhancedMagnet,
      savePath: targetPath,
      posterUrl: media.posterUrl,
      backdropUrl: media.backdropUrl,
      quality: torrent.quality,
      audio: torrent.audioLabel,
      mediaType: media.type,
      mediaId: media.id,
      mediaTitle: media.title,
      seasonNumber: seasonNum,
      episodeNumber: epNum,
      stateLabel: 'Conectando aos pares...',
    );

    _downloads[torrentId] = newItem;
    _downloadsController.add(allDownloads);
    _saveDownloadsToStorage();
    return newItem;
  }

  /// Inicia múltiplos downloads de torrents ou transmissões em paralelo.
  Future<List<DownloadItem>> startMultipleDownloads({
    required List<TorrentItem> torrents,
    required MediaItem media,
    String? customSavePath,
    int? seasonNumber,
  }) async {
    final List<DownloadItem> started = [];
    for (final torrent in torrents) {
      try {
        final item = await startDownload(
          torrent: torrent,
          media: media,
          customSavePath: customSavePath,
          seasonNumber: seasonNumber ?? torrent.seasonNumber,
          episodeNumber: torrent.episodeNumber,
        );
        started.add(item);
      } catch (e) {
        developer.log('Erro ao iniciar download de ${torrent.title}: $e');
      }
    }
    return started;
  }

  /// Inicia streaming sequencial de um torrent específico para reprodução imediata.
  StreamInfo? startStreaming(int torrentId, {int fileIndex = -1}) {
    if (!_isInitialized) return null;
    try {
      final stream = LibtorrentFlutter.instance.startStream(
        torrentId,
        fileIndex: fileIndex,
      );
      final item = _downloads[torrentId];
      if (item != null) {
        item.streamUrl = stream.url;
        _downloadsController.add(allDownloads);
      }
      return stream;
    } catch (e) {
      developer.log('Erro ao iniciar streaming do torrent $torrentId: $e');
      return null;
    }
  }

  void stopStreaming(int torrentId) {
    if (!_isInitialized) return;
    try {
      LibtorrentFlutter.instance.stopAllStreamsForTorrent(torrentId);
      final item = _downloads[torrentId];
      if (item != null) {
        item.streamUrl = null;
        _downloadsController.add(allDownloads);
      }
    } catch (_) {}
  }

  Future<DownloadItem> _startKisskhDownload({
    required TorrentItem torrent,
    required MediaItem media,
    required String targetPath,
    int? seasonNumber,
    int? episodeNumber,
  }) async {
    // Verificar se já existe um download para este infoHash
    final existing = _downloads.values.firstWhere(
      (d) => d.infoHash.toUpperCase() == torrent.infoHash.toUpperCase(),
      orElse: () => DownloadItem(
        id: -9999999,
        infoHash: '',
        title: '',
        magnetUrl: '',
        savePath: '',
      ),
    );

    if (existing.id != -9999999) {
      if (existing.isPaused) {
        resume(existing.id);
      }
      return existing;
    }

    final downloadId = -(DateTime.now().millisecondsSinceEpoch % 10000000 + (_kisskhIdCounter++));
    final epNum = episodeNumber ?? torrent.episodeNumber;
    final seasonNum = seasonNumber ?? 1;

    String cleanTitle = media.title;
    if (epNum != null) {
      cleanTitle = '${media.title} (T$seasonNum:E$epNum)';
    }

    final newItem = DownloadItem(
      id: downloadId,
      infoHash: torrent.infoHash,
      title: '$cleanTitle [${torrent.quality} • KissKH CDN]',
      magnetUrl: torrent.magnetUrl,
      savePath: targetPath,
      posterUrl: media.posterUrl,
      backdropUrl: media.backdropUrl,
      quality: torrent.quality,
      audio: 'Legendado',
      mediaType: media.type,
      mediaId: media.id,
      mediaTitle: media.title,
      seasonNumber: seasonNum,
      episodeNumber: epNum,
      hasMetadata: true,
      stateLabel: 'Conectando à CDN do KissKH...',
    );

    _downloads[downloadId] = newItem;
    _downloadsController.add(allDownloads);
    _saveDownloadsToStorage();

    _runKisskhDownloadWorker(newItem);
    return newItem;
  }

  Future<void> _runKisskhDownloadWorker(DownloadItem item) async {
    final client = http.Client();
    _httpClients[item.id] = client;
    _httpCancelled[item.id] = false;
    _httpPaused[item.id] = false;
    IOSink? sink;

    try {
      final episodeId = KisskhService.extractEpisodeId(item.magnetUrl, item.infoHash);

      if (episodeId == null) {
        item.stateLabel = 'Erro: Episódio não identificado';
        _downloadsController.add(allDownloads);
        return;
      }

      item.stateLabel = 'Obtendo link da CDN ultra rápida...';
      _downloadsController.add(allDownloads);

      final streamSource = await KisskhService.resolveStream(episodeId);
      if (streamSource == null) {
        item.stateLabel = 'Erro: Fluxo CDN indisponível';
        _downloadsController.add(allDownloads);
        return;
      }

      if (_httpCancelled[item.id] == true) {
        await _deleteCdnFiles(item, item.savePath);
        return;
      }

      item.streamUrl = streamSource.m3u8Url;

      final downloadUrl = streamSource.directTsUrl ?? streamSource.m3u8Url;
      final safeName = item.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final saveDir = Directory(item.savePath);
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }
      final videoFile = File('${item.savePath}${Platform.pathSeparator}$safeName.ts');
      final subFile = File('${item.savePath}${Platform.pathSeparator}$safeName.srt');

      // Baixar legendas e gerar versão em Português se disponível
      if (streamSource.subtitles.isNotEmpty && _httpCancelled[item.id] != true) {
        try {
          final hasPt = streamSource.subtitles.any(
            (s) => s.lang == 'pt' || s.label.toLowerCase().contains('portugu'),
          );
          if (hasPt) {
            final ptSub = streamSource.subtitles.firstWhere(
              (s) => s.lang == 'pt' || s.label.toLowerCase().contains('portugu'),
            );
            final subResp = await http.get(
              Uri.parse(ptSub.src),
              headers: {'User-Agent': 'Mozilla/5.0', 'Referer': 'https://kisskh.co/'},
            );
            if (subResp.statusCode == 200) {
              await subFile.writeAsBytes(subResp.bodyBytes);
              final ptFile = File('${item.savePath}${Platform.pathSeparator}$safeName.pt-BR.srt');
              await ptFile.writeAsBytes(subResp.bodyBytes);
            }
          } else {
            final enSub = streamSource.subtitles.firstWhere(
              (s) => s.lang == 'en' || s.label.toLowerCase().contains('eng'),
              orElse: () => streamSource.subtitles.first,
            );
            final enFile = File('${item.savePath}${Platform.pathSeparator}$safeName.en.srt');
            final subResp = await http.get(
              Uri.parse(enSub.src),
              headers: {'User-Agent': 'Mozilla/5.0', 'Referer': 'https://kisskh.co/'},
            );
            if (subResp.statusCode == 200) {
              await enFile.writeAsBytes(subResp.bodyBytes);
              // Traduzir para Português (Brasil) e salvar como legenda principal
              final rawSrt = utf8.decode(subResp.bodyBytes, allowMalformed: true);
              final translated = await SubtitleTranslationService.translateSrtString(rawSrt);
              await subFile.writeAsString(translated);
              final ptFile = File('${item.savePath}${Platform.pathSeparator}$safeName.pt-BR.srt');
              await ptFile.writeAsString(translated);
            }
          }
        } catch (e) {
          developer.log('Erro ao baixar/traduzir legenda KissKH: $e');
        }
      }

      if (_httpCancelled[item.id] == true) {
        await _deleteCdnFiles(item, item.savePath);
        return;
      }

      int downloadedBytes = 0;
      if (await videoFile.exists()) {
        downloadedBytes = await videoFile.length();
      }

      final request = http.Request('GET', Uri.parse(downloadUrl));
      request.headers['User-Agent'] =
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
      request.headers['Referer'] = 'https://kisskh.co/';
      if (downloadedBytes > 0) {
        request.headers['Range'] = 'bytes=$downloadedBytes-';
      }

      final response = await client.send(request);
      final totalLength = (response.contentLength ?? 0) + downloadedBytes;
      item.totalWanted = totalLength > 0 ? totalLength : 400 * 1024 * 1024;
      item.totalDone = downloadedBytes;

      sink = videoFile.openWrite(mode: downloadedBytes > 0 ? FileMode.append : FileMode.write);
      _activeFileSinks[item.id] = sink;

      int bytesLastSec = 0;
      DateTime lastTime = DateTime.now();

      await for (final chunk in response.stream) {
        if (_httpCancelled[item.id] == true) {
          final s = _activeFileSinks.remove(item.id) ?? sink;
          try { await s.flush(); } catch (_) {}
          try { await s.close(); } catch (_) {}
          await Future.delayed(const Duration(milliseconds: 100));
          await _deleteCdnFiles(item, item.savePath);
          return;
        }
        if (_httpPaused[item.id] == true) {
          final s = _activeFileSinks.remove(item.id) ?? sink;
          try { await s.flush(); } catch (_) {}
          try { await s.close(); } catch (_) {}
          item.isPaused = true;
          item.downloadRate = 0;
          item.stateLabel = 'Pausado';
          _downloadsController.add(allDownloads);
          _saveDownloadsToStorage();
          return;
        }

        sink.add(chunk);
        downloadedBytes += chunk.length;
        bytesLastSec += chunk.length;
        item.totalDone = downloadedBytes;

        final now = DateTime.now();
        final diffMs = now.difference(lastTime).inMilliseconds;
        if (diffMs >= 500) {
          item.downloadRate = ((bytesLastSec * 1000) ~/ diffMs);
          bytesLastSec = 0;
          lastTime = now;
          item.progress = item.totalWanted > 0 ? downloadedBytes / item.totalWanted : 0.0;
          item.stateLabel = 'Baixando CDN (${item.formattedSpeed})';
          _downloadsController.add(allDownloads);
        }
      }

      final s = _activeFileSinks.remove(item.id) ?? sink;
      try { await s.flush(); } catch (_) {}
      try { await s.close(); } catch (_) {}
      item.isFinished = true;
      item.progress = 1.0;
      item.downloadRate = 0;
      item.stateLabel = 'Download Concluído';
      _downloadsController.add(allDownloads);
      _saveDownloadsToStorage();
    } catch (e) {
      if (_httpCancelled[item.id] != true && _httpPaused[item.id] != true) {
        developer.log('Erro no download HTTP KissKH (${item.id}): $e');
        item.stateLabel = 'Falha no download via CDN';
        _downloadsController.add(allDownloads);
      }
    } finally {
      _httpClients.remove(item.id);
      final s = _activeFileSinks.remove(item.id) ?? sink;
      if (s != null) {
        try { await s.flush(); } catch (_) {}
        try { await s.close(); } catch (_) {}
      }
      if (_httpCancelled[item.id] == true) {
        await Future.delayed(const Duration(milliseconds: 100));
        await _deleteCdnFiles(item, item.savePath);
        Future.delayed(const Duration(milliseconds: 400), () {
          _deleteCdnFiles(item, item.savePath);
        });
      }
    }
  }

  /// Localiza o caminho absoluto do arquivo de vídeo no disco para reprodução local direta.
  String? getLocalVideoFilePath(int torrentId) {
    if (torrentId < 0) {
      final item = _downloads[torrentId];
      if (item == null || !item.isFinished) return null;
      final safeName = item.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final videoFile = File('${item.savePath}${Platform.pathSeparator}$safeName.ts');
      if (videoFile.existsSync()) return videoFile.path;
      return null;
    }

    if (!_isInitialized) return null;
    try {
      final item = _downloads[torrentId];
      if (item == null || !item.isFinished) return null;

      // 1. Tentar obter pelo índice de arquivos do libtorrent
      final files = LibtorrentFlutter.instance.getFiles(torrentId);
      if (files.isNotEmpty) {
        final videoFiles = files.where((f) {
          final ext = f.path.split('.').last.toLowerCase();
          return ['mkv', 'mp4', 'avi', 'mov', 'webm', 'ts', 'm4v'].contains(ext);
        }).toList();

        videoFiles.sort((a, b) => b.size.compareTo(a.size));
        if (videoFiles.isNotEmpty) {
          final candidatePath = '${item.savePath}${Platform.pathSeparator}${videoFiles.first.path}';
          if (File(candidatePath).existsSync()) {
            return candidatePath;
          }
        }
      }

      // 2. Fallback: buscar recursivamente na pasta de salvamento
      final saveDir = Directory(item.savePath);
      if (saveDir.existsSync()) {
        final allFiles = saveDir.listSync(recursive: true).whereType<File>();
        final diskVideos = allFiles.where((f) {
          final ext = f.path.split('.').last.toLowerCase();
          return ['mkv', 'mp4', 'avi', 'mov', 'webm', 'ts', 'm4v'].contains(ext);
        }).toList();

        if (diskVideos.isNotEmpty) {
          diskVideos.sort((a, b) => b.lengthSync().compareTo(a.lengthSync()));
          return diskVideos.first.path;
        }
      }
    } catch (e) {
      developer.log('Erro ao buscar caminho local do vídeo ($torrentId): $e');
    }
    return null;
  }

  void pause(int id) {
    if (id < 0) {
      _httpPaused[id] = true;
      final client = _httpClients.remove(id);
      try { client?.close(); } catch (_) {}
      final sink = _activeFileSinks.remove(id);
      if (sink != null) {
        try { sink.flush(); } catch (_) {}
        try { sink.close(); } catch (_) {}
      }
      final item = _downloads[id];
      if (item != null) {
        item.isPaused = true;
        item.downloadRate = 0;
        item.stateLabel = 'Pausado';
        _downloadsController.add(allDownloads);
        _saveDownloadsToStorage();
      }
      return;
    }

    if (!_isInitialized) return;
    try {
      LibtorrentFlutter.instance.pauseTorrent(id);
      final item = _downloads[id];
      if (item != null) {
        item.isPaused = true;
        item.stateLabel = 'Pausado';
        _downloadsController.add(allDownloads);
      }
    } catch (_) {}
  }

  void resume(int id) {
    if (id < 0) {
      final item = _downloads[id];
      if (item != null) {
        item.isPaused = false;
        item.stateLabel = 'Retomando download via CDN...';
        _downloadsController.add(allDownloads);
        _runKisskhDownloadWorker(item);
      }
      return;
    }

    if (!_isInitialized) return;
    try {
      final isAlive = LibtorrentFlutter.instance.torrents.containsKey(id);
      final item = _downloads[id];
      if (item != null) {
        if (!isAlive) {
          final enhancedMagnet = ComandoTorrentsService.injectFastTrackers(item.magnetUrl);
          final newId = LibtorrentFlutter.instance.addMagnet(
            enhancedMagnet,
            item.savePath.isNotEmpty ? item.savePath : _defaultDownloadDirectory,
            false,
          );
          _downloads.remove(id);
          item.id = newId;
          item.isPaused = false;
          item.stateLabel = 'Conectando aos pares...';
          _downloads[newId] = item;
          _downloadsController.add(allDownloads);
          _saveDownloadsToStorage();
          return;
        }
        LibtorrentFlutter.instance.resumeTorrent(id);
        item.isPaused = false;
        item.stateLabel = 'Retomando...';
        _downloadsController.add(allDownloads);
        _saveDownloadsToStorage();
      }
    } catch (_) {}
  }

  Future<void> cancel(int id, {bool deleteFiles = true}) async {
    final item = _downloads[id];
    final targetPath = (item != null && item.savePath.isNotEmpty)
        ? item.savePath
        : _defaultDownloadDirectory;

    if (id < 0) {
      _httpCancelled[id] = true;
      final client = _httpClients.remove(id);
      try { client?.close(); } catch (_) {}

      final sink = _activeFileSinks.remove(id);
      if (sink != null) {
        try { await sink.flush(); } catch (_) {}
        try { await sink.close(); } catch (_) {}
      }

      _downloads.remove(id);
      _downloadsController.add(allDownloads);
      _saveDownloadsToStorage();

      if (item != null && deleteFiles) {
        await Future.delayed(const Duration(milliseconds: 100));
        await _deleteCdnFiles(item, targetPath);
        Future.delayed(const Duration(milliseconds: 300), () => _deleteCdnFiles(item, targetPath));
        Future.delayed(const Duration(milliseconds: 800), () => _deleteCdnFiles(item, targetPath));
      }
      return;
    }

    if (_isInitialized) {
      if (item != null && deleteFiles) {
        await _deleteTorrentFiles(item, targetPath);
        Future.delayed(const Duration(milliseconds: 300), () => _deleteTorrentFiles(item, targetPath));
        Future.delayed(const Duration(milliseconds: 800), () => _deleteTorrentFiles(item, targetPath));
      }
      try {
        LibtorrentFlutter.instance.removeTorrent(id, deleteFiles: false);
      } catch (_) {}
      _downloads.remove(id);
      _downloadsController.add(allDownloads);
      _saveDownloadsToStorage();
    }
  }

  Future<void> _safeDeleteFile(File file, {int maxRetries = 10, int delayMs = 150}) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        if (await file.exists()) {
          if (Platform.isWindows) {
            try {
              await Process.run('attrib', ['-r', file.path]);
            } catch (_) {}
          }
          await file.delete();
        }
        return;
      } catch (e) {
        if (i < maxRetries - 1) {
          await Future.delayed(Duration(milliseconds: delayMs));
        } else {
          if (Platform.isWindows) {
            try {
              await Process.run('cmd.exe', ['/c', 'del', '/f', '/q', file.path]);
              if (!await file.exists()) return;
            } catch (_) {}
          }
          developer.log('Não foi possível excluir arquivo após $maxRetries tentativas: ${file.path} ($e)');
        }
      }
    }
  }

  Future<void> _deleteCdnFiles(DownloadItem item, String savePath) async {
    try {
      final saveDir = Directory(savePath);
      if (!await saveDir.exists()) return;

      final safeName = item.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
      final cleanMedia = item.cleanMediaTitle.toLowerCase().trim();
      final epNum = item.resolvedEpisodeNumber;
      final seasonNum = item.resolvedSeasonNumber;

      for (final ext in ['ts', 'mp4', 'mkv', 'srt', 'pt-BR.srt', 'en.srt', 'txt']) {
        final directFile = File('$savePath${Platform.pathSeparator}$safeName.$ext');
        await _safeDeleteFile(directFile);
      }

      final entities = saveDir.listSync();
      for (final entity in entities) {
        if (entity is File) {
          final fileName = entity.path.split(Platform.pathSeparator).last;
          final lowerName = fileName.toLowerCase();

          final matchSafe = fileName.startsWith(safeName) || fileName.contains(safeName);

          bool matchEpisode = false;
          if (cleanMedia.isNotEmpty && lowerName.contains(cleanMedia)) {
            if (epNum != null) {
              final regex = RegExp(
                r'(?:[te]\d*[_:\s]*)?(?:e|ep|epis[oó]dio)\s*0*' + epNum.toString() + r'(?:[^0-9]|$)',
                caseSensitive: false,
              );
              if (regex.hasMatch(lowerName) || lowerName.contains('e$epNum') || lowerName.contains('e0$epNum')) {
                if (seasonNum != null) {
                  final hasSeasonMatch = lowerName.contains('t$seasonNum') ||
                      lowerName.contains('s$seasonNum') ||
                      !lowerName.contains(RegExp(r'[ts]\d+'));
                  if (hasSeasonMatch) {
                    matchEpisode = true;
                  }
                } else {
                  matchEpisode = true;
                }
              }
            } else {
              matchEpisode = true;
            }
          }

          if (matchSafe || matchEpisode) {
            await _safeDeleteFile(entity);
          }
        }
      }
    } catch (e) {
      developer.log('Erro ao limpar arquivos CDN: $e');
    }
  }

  Future<void> _deleteTorrentFiles(DownloadItem item, String savePath) async {
    try {
      final saveDir = Directory(savePath);
      if (!await saveDir.exists()) return;

      // 1. Arquivos registrados no libtorrent
      try {
        final files = LibtorrentFlutter.instance.getFiles(item.id);
        for (final f in files) {
          final fullPath = '$savePath${Platform.pathSeparator}${f.path}';
          final file = File(fullPath);
          await _safeDeleteFile(file);
          final parts = f.path.split(RegExp(r'[\\/]'));
          if (parts.length > 1) {
            final subDir = Directory('$savePath${Platform.pathSeparator}${parts.first}');
            if (await subDir.exists() && subDir.path.toLowerCase() != saveDir.path.toLowerCase()) {
              try { subDir.deleteSync(recursive: true); } catch (_) {}
            }
          }
        }
      } catch (_) {}

      // 2. Caminho do vídeo detectado localmente
      final localVideo = getLocalVideoFilePathForItem(item);
      if (localVideo != null) {
        final file = File(localVideo);
        if (await file.exists()) {
          final parent = file.parent;
          if (await parent.exists() &&
              parent.path.toLowerCase() != saveDir.path.toLowerCase() &&
              parent.path.toLowerCase() != _defaultDownloadDirectory.toLowerCase()) {
            try { parent.deleteSync(recursive: true); } catch (_) {}
          } else {
            await _safeDeleteFile(file);
          }
        }
      }

      // 3. Busca por diretório ou arquivos na pasta de downloads correspondentes ao nome
      final cleanTitle = item.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ').trim();
      final titleWords = cleanTitle.split(RegExp(r'\s+')).where((w) => w.length >= 3).toList();

      for (final entity in saveDir.listSync()) {
        final name = entity.path.split(Platform.pathSeparator).last;
        bool matches = name.toLowerCase().contains(item.title.toLowerCase()) ||
            item.title.toLowerCase().contains(name.toLowerCase());

        if (!matches && titleWords.length >= 2) {
          final matchedCount = titleWords.where((w) => name.toLowerCase().contains(w.toLowerCase())).length;
          if (matchedCount >= 2 && matchedCount >= (titleWords.length * 0.5)) {
            matches = true;
          }
        }

        if (matches) {
          if (entity is Directory && entity.path.toLowerCase() != saveDir.path.toLowerCase()) {
            try { entity.deleteSync(recursive: true); } catch (_) {}
          } else if (entity is File) {
            await _safeDeleteFile(entity);
          }
        }
      }
    } catch (e) {
      developer.log('Erro ao deletar arquivos torrent: $e');
    }
  }

  Future<void> deleteSeriesFiles(String seriesTitle, String savePath) async {
    try {
      final saveDir = Directory(savePath);
      if (!await saveDir.exists()) return;

      final cleanTitle = seriesTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ').trim().toLowerCase();
      if (cleanTitle.length < 3) return;

      final entities = saveDir.listSync();
      for (final entity in entities) {
        final name = entity.path.split(Platform.pathSeparator).last.toLowerCase();
        if (name.contains(cleanTitle) || cleanTitle.contains(name)) {
          if (entity is Directory && entity.path.toLowerCase() != saveDir.path.toLowerCase()) {
            try {
              entity.deleteSync(recursive: true);
            } catch (e) {
              developer.log('Erro ao deletar pasta da série: $e');
            }
          } else if (entity is File) {
            await _safeDeleteFile(entity);
          }
        }
      }
    } catch (e) {
      developer.log('Erro ao limpar arquivos da série: $e');
    }
  }

  /// Abre a pasta de downloads ou seleciona um arquivo específico no Windows Explorer / Gerenciador de Arquivos.
  Future<void> openDownloadFolder({String? filePath}) async {
    final target = filePath ?? _defaultDownloadDirectory;
    try {
      if (Platform.isWindows) {
        if (filePath != null && File(filePath).existsSync()) {
          await Process.run('explorer.exe', ['/select,', filePath]);
        } else {
          await Process.run('explorer.exe', [target]);
        }
      } else if (Platform.isMacOS) {
        await Process.run('open', [target]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [target]);
      }
    } catch (e) {
      developer.log('Erro ao abrir pasta no explorador: $e');
    }
  }

  /// Localiza o arquivo de vídeo associado a um DownloadItem específico (mesmo após reinicialização do app).
  String? getLocalVideoFilePathForItem(DownloadItem item) {
    try {
      if (!item.isFinished) return null;

      if (item.id < 0) {
        final safeName = item.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
        final videoFile = File('${item.savePath}${Platform.pathSeparator}$safeName.ts');
        if (videoFile.existsSync()) return videoFile.path;
      }

      if (item.id >= 0 && _isInitialized) {
        final path = getLocalVideoFilePath(item.id);
        if (path != null) return path;
      }

      final saveDir = Directory(item.savePath);
      if (saveDir.existsSync()) {
        final allFiles = saveDir.listSync(recursive: true).whereType<File>();
        final diskVideos = allFiles.where((f) {
          final ext = f.path.split('.').last.toLowerCase();
          return ['mkv', 'mp4', 'avi', 'mov', 'webm', 'ts', 'm4v'].contains(ext);
        }).toList();

        if (diskVideos.isNotEmpty) {
          diskVideos.sort((a, b) => b.lengthSync().compareTo(a.lengthSync()));
          return diskVideos.first.path;
        }
      }
    } catch (_) {}
    return null;
  }

  static const String _storageKey = 'movie_easy_persisted_downloads_v1';

  Future<void> _saveDownloadsToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _downloads.values.map((d) => d.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(list));
    } catch (e) {
      developer.log('Erro ao salvar downloads no armazenamento: $e');
    }
  }

  Future<void> _loadDownloadsFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return;

      final decoded = jsonDecode(raw) as List<dynamic>;
      for (final itemJson in decoded) {
        final item = DownloadItem.fromJson(itemJson as Map<String, dynamic>);
        if (item.infoHash.isNotEmpty) {
          final exists = _downloads.values.any((d) => d.infoHash.toUpperCase() == item.infoHash.toUpperCase());
          if (!exists) {
            final localVideo = getLocalVideoFilePathForItem(item);
            if (localVideo != null) {
              item.isFinished = true;
              item.progress = 1.0;
              item.stateLabel = 'Download Concluído';
              _downloads[item.id] = item;
            } else if (!item.isFinished) {
              if (item.magnetUrl.startsWith('kisskh://') || item.infoHash.startsWith('KISSKH')) {
                item.isPaused = true;
                item.stateLabel = 'Pausado';
                _downloads[item.id] = item;
              } else {
                try {
                  final enhancedMagnet = ComandoTorrentsService.injectFastTrackers(item.magnetUrl);
                  final newId = LibtorrentFlutter.instance.addMagnet(
                    enhancedMagnet,
                    item.savePath.isNotEmpty ? item.savePath : _defaultDownloadDirectory,
                    false,
                  );
                  item.id = newId;
                  if (item.isPaused) {
                    LibtorrentFlutter.instance.pauseTorrent(newId);
                  }
                  _downloads[newId] = item;
                } catch (_) {
                  _downloads[item.id] = item;
                }
              }
            } else {
              _downloads[item.id] = item;
            }
          }
        }
      }
      _downloadsController.add(allDownloads);
    } catch (e) {
      developer.log('Erro ao carregar downloads salvos: $e');
    }
  }

  String _mapStateToPortuguese(TorrentState state, {bool isPaused = false}) {
    if (isPaused) return 'Pausado';
    switch (state) {
      case TorrentState.downloadingMetadata:
        return 'Buscando metadados';
      case TorrentState.downloading:
        return 'Baixando';
      case TorrentState.finished:
        return 'Concluído';
      case TorrentState.seeding:
        return 'Semeando';
      case TorrentState.checkingFiles:
      case TorrentState.checkingResume:
        return 'Verificando integridade';
      case TorrentState.allocating:
        return 'Alocando espaço em disco';
      case TorrentState.error:
        return 'Erro';
      default:
        return 'Conectando';
    }
  }

  void dispose() {
    _downloadsController.close();
  }
}

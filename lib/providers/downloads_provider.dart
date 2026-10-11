import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/download_item.dart';
import '../models/library_entry.dart';
import '../models/media_item.dart';
import '../models/torrent_item.dart';
import '../services/kisskh_service.dart';
import '../services/torrent_download_service.dart';

class DownloadsProvider extends ChangeNotifier {
  final TorrentDownloadService _service = TorrentDownloadService();
  StreamSubscription<List<DownloadItem>>? _sub;

  List<DownloadItem> _downloads = [];
  bool _isEngineReady = false;

  List<DownloadItem> get allDownloads => _downloads;
  List<DownloadItem> get activeDownloads => _downloads.where((d) => !d.isFinished).toList();
  List<DownloadItem> get completedDownloads => _downloads.where((d) => d.isFinished).toList();
  
  /// Itens da Biblioteca: títulos com download concluído
  List<DownloadItem> get libraryItems {
    return _downloads.where((d) => d.isFinished).toList();
  }

  /// Títulos agrupados na Biblioteca (filmes e séries consolidadas com seus episódios)
  List<LibraryEntry> get libraryEntries {
    return LibraryEntry.groupFromDownloadItems(libraryItems);
  }

  /// Quantidade de títulos distintos salvos na Biblioteca
  int get libraryTitlesCount => libraryEntries.length;

  /// Espaço total ocupado pelos itens da Biblioteca
  String get totalLibraryDiskUsage {
    int totalBytes = 0;
    for (final d in libraryItems) {
      totalBytes += d.totalDone > 0 ? d.totalDone : d.totalWanted;
    }
    if (totalBytes <= 0) return '0 MB';
    if (totalBytes >= 1024 * 1024 * 1024) {
      return '${(totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    return '${(totalBytes / (1024 * 1024)).toStringAsFixed(0)} MB';
  }

  bool get isEngineReady => _isEngineReady;
  int get activeCount => activeDownloads.length;
  String get downloadDirectory => _service.downloadDirectory;

  /// Soma da velocidade de download de todos os torrents ativos formatada
  String get totalDownloadSpeed {
    int totalBytesPerSec = 0;
    for (final d in activeDownloads) {
      if (!d.isPaused) {
        totalBytesPerSec += d.downloadRate;
      }
    }
    if (totalBytesPerSec <= 0) return '0 KB/s';
    if (totalBytesPerSec >= 1024 * 1024) {
      return '${(totalBytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
    return '${(totalBytesPerSec / 1024).toStringAsFixed(0)} KB/s';
  }

  Future<void> init() async {
    await _service.init();
    _isEngineReady = true;

    _sub = _service.downloadsStream.listen((list) {
      _downloads = List.from(list);
      notifyListeners();
    });

    _downloads = List.from(_service.allDownloads);
    notifyListeners();
  }

  Future<DownloadItem> addDownload({
    required TorrentItem torrent,
    required MediaItem media,
    String? customPath,
    int? seasonNumber,
    int? episodeNumber,
  }) async {
    final item = await _service.startDownload(
      torrent: torrent,
      media: media,
      customSavePath: customPath,
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
    );
    notifyListeners();
    return item;
  }

  /// Inicia o download de múltiplos torrents ou transmissões em lote
  Future<List<DownloadItem>> addMultipleDownloads({
    required List<TorrentItem> torrents,
    required MediaItem media,
    String? customPath,
    int? seasonNumber,
  }) async {
    final items = await _service.startMultipleDownloads(
      torrents: torrents,
      media: media,
      customSavePath: customPath,
      seasonNumber: seasonNumber,
    );
    notifyListeners();
    return items;
  }

  Future<void> openDownloadFolder({String? filePath}) async {
    await _service.openDownloadFolder(filePath: filePath);
  }

  String? getLocalVideoFilePathForItem(DownloadItem item) {
    return _service.getLocalVideoFilePathForItem(item);
  }

  void pauseDownload(int id) {
    _service.pause(id);
    notifyListeners();
  }

  void resumeDownload(int id) {
    _service.resume(id);
    notifyListeners();
  }

  Future<void> cancelDownload(int id, {bool deleteFiles = true}) async {
    await _service.cancel(id, deleteFiles: deleteFiles);
    notifyListeners();
  }

  /// Cancela e remove todos os episódios de uma série/título agrupado
  Future<void> deleteSeries(LibraryEntry entry, {bool deleteFiles = true}) async {
    for (final ep in entry.episodes) {
      await _service.cancel(ep.id, deleteFiles: deleteFiles);
    }
    if (deleteFiles) {
      await _service.deleteSeriesFiles(entry.title, _service.downloadDirectory);
    }
    notifyListeners();
  }

  /// Abre a pasta no explorador onde os episódios da série estão salvos
  Future<void> openSeriesFolder(LibraryEntry entry) async {
    for (final ep in entry.episodes) {
      final path = getLocalVideoFilePathForItem(ep);
      if (path != null) {
        await openDownloadFolder(filePath: path);
        return;
      }
    }
    if (entry.episodes.isNotEmpty) {
      await openDownloadFolder(filePath: entry.episodes.first.savePath);
    } else {
      await openDownloadFolder();
    }
  }

  String? startStreaming(int id, {int fileIndex = -1}) {
    final stream = _service.startStreaming(id, fileIndex: fileIndex);
    notifyListeners();
    return stream?.url;
  }

  void stopStreaming(int id) {
    _service.stopStreaming(id);
    notifyListeners();
  }

  String? getLocalVideoFilePath(int id) {
    return _service.getLocalVideoFilePath(id);
  }

  /// Resolve a melhor fonte para reprodução: arquivo local se concluído no disco, ou URL de streaming HTTP.
  Future<String?> resolvePlaybackSource(DownloadItem item) async {
    // 1. Se o download já está concluído, reproduz o arquivo local diretamente
    if (item.isFinished) {
      final localPath = _service.getLocalVideoFilePathForItem(item);
      if (localPath != null && File(localPath).existsSync()) {
        return localPath;
      }
    }

    // 2. Se já tem streaming ativo, reutilizar
    if (item.streamUrl != null && item.streamUrl!.isNotEmpty) {
      return item.streamUrl;
    }

    // 3. Se for download direto da CDN (KissKH)
    if (item.id < 0 || item.magnetUrl.startsWith('kisskh://')) {
      final epId = KisskhService.extractEpisodeId(item.magnetUrl, item.infoHash);
      if (epId != null) {
        final stream = await KisskhService.resolveStream(epId);
        if (stream != null) {
          item.streamUrl = stream.m3u8Url;
          return stream.m3u8Url;
        }
      }
      return null;
    }

    // 4. Iniciar streaming sequencial sob demanda via libtorrent
    final streamUrl = startStreaming(item.id);
    return streamUrl;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:movie_easy/models/download_item.dart';
import 'package:movie_easy/services/torrent_download_service.dart';

void main() {
  test('getLocalVideoFilePathForItem finds video on disk despite colons and title formatting', () async {
    final tempDir = await Directory.systemTemp.createTemp('movie_easy_test_');
    final releaseDir = Directory('${tempDir.path}/Homem-Aranha Um Novo Dia.2026.1080p.WEB-DL.x264.DUAL.5.1');
    await releaseDir.create(recursive: true);
    final videoFile = File('${releaseDir.path}/Homem-Aranha Um Novo Dia.2026.1080p.WEB-DL.x264.DUAL.5.1.mkv');
    
    // Create a dummy video file > 25MB
    final randomData = List<int>.filled(25 * 1024 * 1024 + 100, 0);
    await videoFile.writeAsBytes(randomData);

    try {
      final service = TorrentDownloadService();
      final item = DownloadItem(
        id: 999,
        infoHash: 'IOXGRGHCXAKOMUTLB4OWX4FO7KMONAKH',
        title: 'Homem-Aranha: Um Novo Dia [1080p]',
        mediaTitle: 'Homem-Aranha: Um Novo Dia',
        magnetUrl: 'magnet:?xt=urn:btih:ioxgrghcxakomutlb4owx4fo7kmonakh&dn=Homem-Aranha%20Um%20Novo%20Dia.2026.1080p.WEB-DL.x264.DUAL.5.1',
        savePath: tempDir.path,
      );

      final path = service.getLocalVideoFilePathForItem(item);
      expect(path, isNotNull);
      expect(File(path!).existsSync(), isTrue);
      expect(path, contains('Homem-Aranha Um Novo Dia'));
      expect(File(path).lengthSync(), greaterThan(20 * 1024 * 1024));
    } finally {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    }
  });

  test('DownloadItem formattedSize returns final formatted bytes when finished', () {
    final item = DownloadItem(
      id: 1,
      infoHash: 'test',
      title: 'Teste',
      magnetUrl: 'magnet:?xt=urn:btih:test',
      savePath: '/tmp',
      isFinished: true,
      hasMetadata: true,
      totalDone: 3784907720,
      totalWanted: 3784907720,
      progress: 1.0,
    );

    expect(item.formattedSize, '3.52 GB');
    expect(item.formattedProgress, '100.0%');
  });
}

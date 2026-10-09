import 'package:flutter_test/flutter_test.dart';
import 'package:movie_easy/models/download_item.dart';
import 'package:movie_easy/models/library_entry.dart';
import 'package:movie_easy/models/media_item.dart';

void main() {
  group('Library Grouping Tests', () {
    test('Groups 12 episodes of A Coroa Perfeita into a single LibraryEntry', () {
      final items = <DownloadItem>[
        // Episódio avulso de outra série
        DownloadItem(
          id: -1,
          infoHash: 'HASH_HONG',
          title: 'Hong, A Infiltrada (T1:E1) [1080p - KissKH CDN]',
          magnetUrl: 'kisskh://hong_1',
          savePath: 'C:\\Downloads',
          mediaType: MediaTypeEnum.dorama,
          mediaId: '9999',
          isFinished: true,
        ),
      ];

      // Adicionar 12 episódios desordenados de A Coroa Perfeita
      for (int i = 12; i >= 1; i--) {
        items.add(
          DownloadItem(
            id: -100 - i,
            infoHash: 'HASH_COROA_$i',
            title: 'A Coroa Perfeita (T1:E$i) [1080p - KissKH CDN]',
            magnetUrl: 'kisskh://coroa_$i',
            savePath: 'C:\\Downloads',
            mediaType: MediaTypeEnum.dorama,
            mediaId: '8888',
            quality: '1080p',
            audio: 'Legendado',
            totalDone: 382 * 1024 * 1024,
            isFinished: true,
          ),
        );
      }

      final entries = LibraryEntry.groupFromDownloadItems(items);

      // Deve ter exatamente 2 títulos na biblioteca: A Coroa Perfeita e Hong, A Infiltrada
      expect(entries.length, 2);

      final coroaEntry = entries.firstWhere((e) => e.title == 'A Coroa Perfeita');
      expect(coroaEntry.isSeries, isTrue);
      expect(coroaEntry.episodeCount, 12);
      expect(coroaEntry.mediaType, MediaTypeEnum.dorama);

      // Episódios devem estar estritamente ordenados de 1 a 12
      for (int i = 0; i < 12; i++) {
        expect(coroaEntry.episodes[i].resolvedEpisodeNumber, i + 1);
        expect(coroaEntry.episodes[i].resolvedSeasonNumber, 1);
      }

      final hongEntry = entries.firstWhere((e) => e.title == 'Hong, A Infiltrada');
      expect(hongEntry.isSeries, isTrue);
      expect(hongEntry.episodeCount, 1);
      expect(hongEntry.episodes.first.resolvedEpisodeNumber, 1);
    });

    test('Single movie is not marked as episodic series', () {
      final items = [
        DownloadItem(
          id: 10,
          infoHash: 'HASH_MOVIE',
          title: 'Interestelar [1080p]',
          magnetUrl: 'magnet:?xt=urn:btih:movie',
          savePath: 'C:\\Downloads',
          mediaType: MediaTypeEnum.movie,
          mediaId: '157336',
          isFinished: true,
        ),
      ];

      final entries = LibraryEntry.groupFromDownloadItems(items);
      expect(entries.length, 1);
      expect(entries.first.title, 'Interestelar');
      expect(entries.first.isSeries, isFalse);
      expect(entries.first.episodeCount, 1);
    });

    test('Extracts clean title and resolves season/episode without explicit mediaTitle', () {
      final rawItem = DownloadItem(
        id: 1,
        infoHash: 'HASH',
        title: 'Breaking Bad (T2:E5) [1080p]',
        magnetUrl: 'magnet:?',
        savePath: 'C:\\',
      );

      expect(rawItem.cleanMediaTitle, 'Breaking Bad');
      expect(rawItem.resolvedSeasonNumber, 2);
      expect(rawItem.resolvedEpisodeNumber, 5);
      expect(rawItem.episodeDisplayLabel, 'T2 : Ep 5');
    });

    test('Movie with (1ª Temporada) in raw title is correctly treated as movie and not series', () {
      final movieItem = DownloadItem(
        id: 2,
        infoHash: 'F11AC2647E9F8555BB6F69015005ED2EEB548FB0',
        title: 'Velozes e Furiosos (1ª Temporada) [1080p]',
        magnetUrl: 'magnet:?xt=urn:btih:movie',
        savePath: 'C:\\Downloads',
        mediaType: MediaTypeEnum.movie,
        mediaId: '9799',
        seasonNumber: 1,
        isFinished: true,
      );

      expect(movieItem.cleanMediaTitle, 'Velozes e Furiosos');
      expect(movieItem.resolvedSeasonNumber, isNull);
      expect(movieItem.resolvedEpisodeNumber, isNull);

      final entries = LibraryEntry.groupFromDownloadItems([movieItem]);
      expect(entries.length, 1);
      final entry = entries.first;
      expect(entry.title, 'Velozes e Furiosos');
      expect(entry.mediaType, MediaTypeEnum.movie);
      expect(entry.isSeries, isFalse);
    });

    test('Clean title stripping preserves movie title correctly', () {
      final movie = DownloadItem(
        id: 3,
        infoHash: 'HASH3',
        title: 'Velozes & Furiosos (2001) 1080p Dublado (www.ThePirateFilmes.com)',
        magnetUrl: 'magnet:?',
        savePath: 'C:\\Downloads',
        mediaType: MediaTypeEnum.movie,
      );

      expect(movie.cleanMediaTitle, contains('Velozes'));
      expect(movie.resolvedEpisodeNumber, isNull);
      final entries = LibraryEntry.groupFromDownloadItems([movie]);
      expect(entries.first.isSeries, isFalse);
    });
  });
}

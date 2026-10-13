import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movie_easy/models/media_item.dart';
import 'package:movie_easy/models/watch_later_item.dart';
import 'package:movie_easy/providers/watch_later_provider.dart';
import 'package:movie_easy/views/watch_later_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Watch Later Model & Provider Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    final testMovie = MediaItem(
      id: '101',
      title: 'Inception',
      originalTitle: 'Inception',
      overview: 'Dom Cobb é um ladrão que rouba segredos.',
      rating: 8.8,
      releaseDate: '2010-07-16',
      type: MediaTypeEnum.movie,
    );

    final testSeries = MediaItem(
      id: '202',
      title: 'Breaking Bad',
      originalTitle: 'Breaking Bad',
      overview: 'Um professor de química do ensino médio.',
      rating: 9.5,
      releaseDate: '2008-01-20',
      type: MediaTypeEnum.tv,
      seasonCount: 5,
      episodeCount: 62,
    );

    final testDorama = MediaItem(
      id: '303',
      title: 'Pousando no Amor',
      originalTitle: 'Crash Landing on You',
      overview: 'Uma herdeira sul-coreana cai na Coreia do Norte.',
      rating: 8.7,
      releaseDate: '2019-12-14',
      type: MediaTypeEnum.dorama,
      seasonCount: 1,
      episodeCount: 16,
    );

    test('MediaItem toJson and fromJson preserves all fields', () {
      final json = testMovie.toJson();
      final restored = MediaItem.fromJson(json);

      expect(restored.id, testMovie.id);
      expect(restored.title, testMovie.title);
      expect(restored.originalTitle, testMovie.originalTitle);
      expect(restored.rating, testMovie.rating);
      expect(restored.type, MediaTypeEnum.movie);
    });

    test('WatchLaterItem toJson, fromJson and formattedAddedTime', () {
      final item = WatchLaterItem(
        media: testDorama,
        addedAt: DateTime.now().subtract(const Duration(minutes: 30)),
      );

      final json = item.toJson();
      final restored = WatchLaterItem.fromJson(json);

      expect(restored.media.id, testDorama.id);
      expect(restored.media.title, testDorama.title);
      expect(restored.media.type, MediaTypeEnum.dorama);
      expect(restored.formattedAddedTime, contains('Salvo'));
    });

    test('WatchLaterProvider adds, toggles, counts and removes items', () async {
      final provider = WatchLaterProvider();
      await provider.init();

      expect(provider.items, isEmpty);
      expect(provider.count, 0);
      expect(provider.isSaved(testMovie.id), isFalse);

      // 1. Adicionar Filme
      final added1 = await provider.toggleWatchLater(testMovie);
      expect(added1, isTrue);
      expect(provider.isSaved(testMovie.id), isTrue);
      expect(provider.count, 1);
      expect(provider.moviesCount, 1);
      expect(provider.seriesCount, 0);
      expect(provider.doramasCount, 0);

      // 2. Adicionar Série e Dorama
      await provider.addToWatchLater(testSeries);
      await provider.addToWatchLater(testDorama);

      expect(provider.count, 3);
      expect(provider.moviesCount, 1);
      expect(provider.seriesCount, 1);
      expect(provider.doramasCount, 1);
      expect(provider.mediaList.map((m) => m.id), containsAll(['101', '202', '303']));

      // 3. Alternar item existente (deve remover)
      final removed = await provider.toggleWatchLater(testMovie);
      expect(removed, isFalse);
      expect(provider.isSaved(testMovie.id), isFalse);
      expect(provider.count, 2);
      expect(provider.moviesCount, 0);

      // 4. Remover dorama
      await provider.removeFromWatchLater(testDorama.id);
      expect(provider.count, 1);
      expect(provider.isSaved(testDorama.id), isFalse);

      // 5. Limpar tudo
      await provider.clearAll();
      expect(provider.isEmpty, isTrue);
      expect(provider.count, 0);
    });

    test('WatchLaterProvider persists items across instance reload', () async {
      final provider1 = WatchLaterProvider();
      await provider1.init();

      await provider1.addToWatchLater(testMovie);
      await provider1.addToWatchLater(testSeries);
      expect(provider1.count, 2);

      // Nova instância recarregando do mesmo mock SharedPreferences
      final provider2 = WatchLaterProvider();
      await provider2.init();

      expect(provider2.count, 2);
      expect(provider2.isSaved(testMovie.id), isTrue);
      expect(provider2.isSaved(testSeries.id), isTrue);
      expect(provider2.items.first.media.title, testSeries.title);
    });
  });

  group('Watch Later Widget Tests', () {
    testWidgets('WatchLaterView renders empty state with explore button', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final provider = WatchLaterProvider();
      await provider.init();

      bool exploreClicked = false;

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            home: WatchLaterView(
              onExploreCatalog: () => exploreClicked = true,
            ),
          ),
        ),
      );

      expect(find.text('Assistir Mais Tarde'), findsOneWidget);
      expect(find.text('Sua lista de "Assistir mais tarde" está vazia'), findsOneWidget);
      expect(find.text('Explorar Catálogo'), findsOneWidget);

      await tester.tap(find.text('Explorar Catálogo'));
      await tester.pump();
      expect(exploreClicked, isTrue);
    });

    testWidgets('WatchLaterView displays saved items and filters', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final provider = WatchLaterProvider();
      await provider.init();

      await provider.addToWatchLater(
        MediaItem(
          id: '1',
          title: 'Interestelar',
          originalTitle: 'Interstellar',
          overview: 'Viagem interestelar no espaço.',
          rating: 8.6,
          releaseDate: '2014-11-07',
          type: MediaTypeEnum.movie,
        ),
      );

      await provider.addToWatchLater(
        MediaItem(
          id: '2',
          title: 'Round 6',
          originalTitle: 'Squid Game',
          overview: 'Jogo de sobrevivência.',
          rating: 8.0,
          releaseDate: '2021-09-17',
          type: MediaTypeEnum.dorama,
        ),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(
            home: WatchLaterView(),
          ),
        ),
      );

      // Deve mostrar 2 títulos salvos
      expect(find.text('2 títulos salvos para assistir a seguir'), findsOneWidget);
      expect(find.text('Interestelar'), findsOneWidget);
      expect(find.text('Round 6'), findsOneWidget);

      // Chips de filtros
      expect(find.text('Filmes (1)'), findsOneWidget);
      expect(find.text('Doramas (1)'), findsOneWidget);
      expect(find.text('Séries (0)'), findsOneWidget);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../models/media_item.dart';
import '../providers/catalog_provider.dart';
import '../providers/watch_later_provider.dart';
import '../widgets/hero_banner.dart';
import '../widgets/media_shelf.dart';
import 'category_view.dart';
import 'details_view.dart';
import 'watch_later_view.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final watchLater = context.watch<WatchLaterProvider>();

    if (catalog.isLoading && catalog.trendingMovies.isEmpty) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppTheme.primary),
              SizedBox(height: 16),
              Text(
                'Carregando catálogo...',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    if (catalog.errorMessage != null && catalog.trendingMovies.isEmpty) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 56, color: AppTheme.textMuted),
                const SizedBox(height: 16),
                Text(
                  catalog.errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => catalog.loadHomeCatalog(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Tentar Novamente'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: RefreshIndicator(
        color: AppTheme.primary,
        backgroundColor: AppTheme.card,
        onRefresh: () => catalog.loadHomeCatalog(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner Principal em Destaque
              HeroBanner(
                item: catalog.heroFeatured,
                onPlay: (item) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => DetailsView(item: item)),
                  );
                },
                onDetails: (item) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => DetailsView(item: item)),
                  );
                },
              ),

              // Carrossel: Assistir Mais Tarde (se houver itens salvos)
              if (watchLater.isNotEmpty) ...[
                MediaShelf(
                  title: 'Assistir Mais Tarde',
                  subtitle: 'Seus filmes, séries e doramas salvos',
                  items: watchLater.mediaList,
                  onSelect: (item) => _openDetails(context, item),
                  onSeeAll: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const WatchLaterView()),
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],

              // Carrossel: Filmes em Alta
              MediaShelf(
                title: 'Filmes em Alta',
                subtitle: 'Os lançamentos mais assistidos no mundo',
                items: catalog.trendingMovies,
                isLoading: catalog.isLoading,
                onSelect: (item) => _openDetails(context, item),
                onSeeAll: () => _openCategory(context, MediaTypeEnum.movie),
              ),

              const SizedBox(height: 12),

              // Carrossel: Séries Populares
              MediaShelf(
                title: 'Séries em Destaque',
                subtitle: 'Temporadas completas e episódios semanais',
                items: catalog.trendingTv,
                isLoading: catalog.isLoading,
                onSelect: (item) => _openDetails(context, item),
                onSeeAll: () => _openCategory(context, MediaTypeEnum.tv),
              ),

              const SizedBox(height: 12),

              // Carrossel: Doramas Mais Amados
              MediaShelf(
                title: 'Doramas & K-Dramas',
                subtitle: 'Dramas asiáticos mais populares (Coreia e Japão)',
                items: catalog.popularDoramas,
                isLoading: catalog.isLoading,
                onSelect: (item) => _openDetails(context, item),
                onSeeAll: () => _openCategory(context, MediaTypeEnum.dorama),
              ),

              const SizedBox(height: 12),

              // Carrossel: Filmes Mais Populares
              MediaShelf(
                title: 'Filmes Mais Populares',
                subtitle: 'Títulos mais buscados no catálogo',
                items: catalog.popularMovies,
                isLoading: catalog.isLoading,
                onSelect: (item) => _openDetails(context, item),
                onSeeAll: () => _openCategory(context, MediaTypeEnum.movie),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  void _openDetails(BuildContext context, MediaItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetailsView(item: item)),
    );
  }

  void _openCategory(BuildContext context, MediaTypeEnum type) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CategoryView(type: type)),
    );
  }
}

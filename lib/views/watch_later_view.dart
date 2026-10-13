import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/app_theme.dart';
import '../models/media_item.dart';
import '../models/watch_later_item.dart';
import '../providers/watch_later_provider.dart';
import 'details_view.dart';

enum WatchLaterSort {
  newest,
  oldest,
  rating,
  alphabetical,
}

/// Aba / Tela "Assistir Mais Tarde" — exibe e gerencia os filmes, séries
/// e doramas salvos pelo usuário para visualização futura.
class WatchLaterView extends StatefulWidget {
  final VoidCallback? onExploreCatalog;

  const WatchLaterView({
    super.key,
    this.onExploreCatalog,
  });

  @override
  State<WatchLaterView> createState() => _WatchLaterViewState();
}

class _WatchLaterViewState extends State<WatchLaterView> {
  String _selectedCategory = 'Todos';
  String _searchQuery = '';
  WatchLaterSort _currentSort = WatchLaterSort.newest;
  late final TextEditingController _searchController;

  final List<String> _categories = [
    'Todos',
    'Filmes',
    'Séries',
    'Doramas',
  ];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  MediaTypeEnum? _getCategoryType(String category) {
    switch (category) {
      case 'Filmes':
        return MediaTypeEnum.movie;
      case 'Séries':
        return MediaTypeEnum.tv;
      case 'Doramas':
        return MediaTypeEnum.dorama;
      default:
        return null;
    }
  }

  int _countForCategory(List<WatchLaterItem> items, String category) {
    if (category == 'Todos') return items.length;
    final type = _getCategoryType(category);
    return items.where((i) => i.media.type == type).length;
  }

  List<WatchLaterItem> _filterAndSortItems(List<WatchLaterItem> items) {
    var filtered = List<WatchLaterItem>.from(items);

    // Filtro por Categoria
    final targetType = _getCategoryType(_selectedCategory);
    if (targetType != null) {
      filtered = filtered.where((i) => i.media.type == targetType).toList();
    }

    // Filtro por Pesquisa de Texto
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      filtered = filtered.where((i) {
        return i.media.title.toLowerCase().contains(q) ||
            i.media.originalTitle.toLowerCase().contains(q);
      }).toList();
    }

    // Ordenação
    switch (_currentSort) {
      case WatchLaterSort.newest:
        filtered.sort((a, b) => b.addedAt.compareTo(a.addedAt));
        break;
      case WatchLaterSort.oldest:
        filtered.sort((a, b) => a.addedAt.compareTo(b.addedAt));
        break;
      case WatchLaterSort.rating:
        filtered.sort((a, b) => b.media.rating.compareTo(a.media.rating));
        break;
      case WatchLaterSort.alphabetical:
        filtered.sort((a, b) => a.media.title.toLowerCase().compareTo(b.media.title.toLowerCase()));
        break;
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final watchLater = context.watch<WatchLaterProvider>();
    final allItems = watchLater.items;
    final filteredItems = _filterAndSortItems(allItems);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Top Bar & Header de Assistir Mais Tarde
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: AppTheme.primary.withOpacity(0.3),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.bookmark_rounded,
                                      color: AppTheme.primary,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Text(
                                      'Assistir Mais Tarde',
                                      style: TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.5,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${allItems.length} título${allItems.length == 1 ? '' : 's'} salvo${allItems.length == 1 ? '' : 's'} para assistir a seguir',
                                style: const TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        // Botão para Limpar Lista Completa
                        if (allItems.isNotEmpty)
                          OutlinedButton.icon(
                            onPressed: () => _confirmClearAll(context, watchLater),
                            icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                            label: const Text('Limpar Lista'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: BorderSide(color: Colors.redAccent.withOpacity(0.4)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Barra de Busca e Ordenação
                    Row(
                      children: [
                        // Barra de busca
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                            onChanged: (val) => setState(() => _searchQuery = val),
                            decoration: InputDecoration(
                              hintText: 'Buscar título na sua lista...',
                              hintStyle: const TextStyle(color: AppTheme.textMuted),
                              prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textMuted, size: 20),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, color: AppTheme.textMuted, size: 18),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                              filled: true,
                              fillColor: AppTheme.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: AppTheme.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: AppTheme.border),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Dropdown de Ordenação
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<WatchLaterSort>(
                              value: _currentSort,
                              dropdownColor: AppTheme.surface,
                              icon: const Icon(Icons.sort_rounded, color: AppTheme.textSecondary, size: 18),
                              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                              onChanged: (sort) {
                                if (sort != null) {
                                  setState(() => _currentSort = sort);
                                }
                              },
                              items: const [
                                DropdownMenuItem(
                                  value: WatchLaterSort.newest,
                                  child: Text('Mais recentes'),
                                ),
                                DropdownMenuItem(
                                  value: WatchLaterSort.oldest,
                                  child: Text('Mais antigos'),
                                ),
                                DropdownMenuItem(
                                  value: WatchLaterSort.rating,
                                  child: Text('Melhor avaliação'),
                                ),
                                DropdownMenuItem(
                                  value: WatchLaterSort.alphabetical,
                                  child: Text('Título (A-Z)'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Chips de Categorias
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _categories.map((cat) {
                          final isSelected = _selectedCategory == cat;
                          final count = _countForCategory(allItems, cat);

                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text('$cat ($count)'),
                              selected: isSelected,
                              onSelected: (_) => setState(() => _selectedCategory = cat),
                              backgroundColor: AppTheme.surface,
                              selectedColor: AppTheme.primary,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : AppTheme.textSecondary,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                fontSize: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: isSelected ? AppTheme.primary : AppTheme.border,
                                ),
                              ),
                              showCheckmark: false,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Conteúdo: Grid de Itens Salvos ou Estado Vazio
            if (filteredItems.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(allItems.isEmpty),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    childAspectRatio: 0.58,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 18,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (ctx, idx) => _buildWatchLaterCard(filteredItems[idx], watchLater),
                    childCount: filteredItems.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWatchLaterCard(WatchLaterItem item, WatchLaterProvider watchLater) {
    final media = item.media;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openDetails(media),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pôster com Badges e Informações
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    media.posterUrl != null && media.posterUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: media.posterUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _buildFallbackPoster(),
                          )
                        : _buildFallbackPoster(),

                    // Gradiente escuro para legibilidade
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.35),
                            Colors.transparent,
                            Colors.black.withOpacity(0.85),
                          ],
                          stops: const [0.0, 0.45, 1.0],
                        ),
                      ),
                    ),

                    // Badge de Categoria no Topo Esquerdo
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _buildCategoryBadge(media.type),
                    ),

                    // Badge de Nota no Topo Direito
                    if (media.rating > 0)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppTheme.starRating.withOpacity(0.4),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 13,
                                color: AppTheme.starRating,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                media.rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Badge de Data em que foi salvo no Rodapé do Pôster
                    Positioned(
                      bottom: 8,
                      left: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              color: AppTheme.primary,
                              size: 11,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                item.formattedAddedTime,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Informações do Título e Botões de Ação
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      media.title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      media.releaseDate != null && media.releaseDate!.isNotEmpty
                          ? '${media.releaseDate!.split('-').first} • ${media.type.label}'
                          : media.type.label,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Botão Principal (Assistir / Torrents)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _openDetails(media),
                        icon: const Icon(Icons.play_arrow_rounded, size: 16),
                        label: const Text('Assistir / Opções', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Linha com Botão Remover
                    Align(
                      alignment: Alignment.centerRight,
                      child: InkWell(
                        onTap: () => _removeItem(media, watchLater),
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.bookmark_remove_rounded, size: 14, color: AppTheme.textMuted),
                              SizedBox(width: 4),
                              Text(
                                'Remover',
                                style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDetails(MediaItem media) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetailsView(item: media)),
    );
  }

  void _removeItem(MediaItem media, WatchLaterProvider watchLater) {
    watchLater.removeFromWatchLater(media.id);

    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${media.title}" removido de Assistir Mais Tarde.'),
        backgroundColor: AppTheme.card,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Desfazer',
          textColor: AppTheme.primary,
          onPressed: () {
            watchLater.addToWatchLater(media);
          },
        ),
      ),
    );
  }

  void _confirmClearAll(BuildContext context, WatchLaterProvider watchLater) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Limpar Lista',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 17),
        ),
        content: const Text(
          'Deseja realmente remover todos os títulos da sua lista de "Assistir Mais Tarde"?',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              watchLater.clearAll();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Limpar Tudo'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBadge(MediaTypeEnum type) {
    String label = 'FILME';
    Color bg = Colors.redAccent;

    switch (type) {
      case MediaTypeEnum.movie:
        label = 'FILME';
        bg = Colors.redAccent;
        break;
      case MediaTypeEnum.tv:
        label = 'SÉRIE';
        bg = Colors.blueAccent;
        break;
      case MediaTypeEnum.dorama:
        label = 'DORAMA';
        bg = Colors.pinkAccent;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.85),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildFallbackPoster() {
    return Container(
      color: AppTheme.surface,
      child: const Center(
        child: Icon(Icons.movie_rounded, color: AppTheme.textMuted, size: 40),
      ),
    );
  }

  Widget _buildEmptyState(bool isTotallyEmpty) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.border),
              ),
              child: const Icon(
                Icons.bookmark_border_rounded,
                color: AppTheme.textMuted,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isTotallyEmpty
                  ? 'Sua lista de "Assistir mais tarde" está vazia'
                  : 'Nenhum resultado encontrado',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isTotallyEmpty
                  ? 'Salve filmes, séries e doramas enquanto navega pelo catálogo para assistir quando quiser.'
                  : 'Nenhum título corresponde ao filtro ou busca selecionada.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            if (isTotallyEmpty && widget.onExploreCatalog != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: widget.onExploreCatalog,
                icon: const Icon(Icons.explore_rounded, size: 18),
                label: const Text('Explorar Catálogo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

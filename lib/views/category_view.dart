import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../models/media_item.dart';
import '../providers/catalog_provider.dart';
import '../widgets/media_card.dart';
import '../widgets/custom_shimmer.dart';
import 'details_view.dart';

class CategoryView extends StatefulWidget {
  final MediaTypeEnum type;

  const CategoryView({super.key, required this.type});

  @override
  State<CategoryView> createState() => _CategoryViewState();
}

class _CategoryViewState extends State<CategoryView> {
  String _selectedFilter = 'popular';
  List<MediaItem> _items = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadItems();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 400) {
      _loadMoreItems();
    }
  }

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
      _currentPage = 1;
      _hasMore = true;
    });
    final catalog = context.read<CatalogProvider>();
    final results = await catalog.getCategoryItems(widget.type, filter: _selectedFilter, page: 1);
    if (mounted) {
      setState(() {
        _items = results;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreItems() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    try {
      final catalog = context.read<CatalogProvider>();
      final nextPage = _currentPage + 1;
      final results = await catalog.getCategoryItems(widget.type, filter: _selectedFilter, page: nextPage);

      if (mounted) {
        if (results.isEmpty) {
          setState(() {
            _hasMore = false;
            _isLoadingMore = false;
          });
        } else {
          final existingIds = _items.map((e) => e.id).toSet();
          final newUniqueItems = results.where((e) => !existingIds.contains(e.id)).toList();

          setState(() {
            _currentPage = nextPage;
            _items.addAll(newUniqueItems);
            _isLoadingMore = false;
            if (results.length < 5) {
              _hasMore = false;
            }
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Cálculo responsivo de colunas: 2 em telas estreitas, até 6 em monitores ultrawide
    final crossAxisCount = (screenWidth / 160).floor().clamp(2, 6);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(widget.type.label),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Filtros por abas / chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _buildFilterChip('Populares', 'popular'),
                const SizedBox(width: 8),
                _buildFilterChip('Em Alta', 'trending'),
                const SizedBox(width: 8),
                _buildFilterChip('Mais Bem Avaliados', 'top_rated'),
              ],
            ),
          ),

          // Grade de Resultados com rolagem infinita
          Expanded(
            child: _isLoading
                ? GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: 0.65,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: crossAxisCount * 3,
                    itemBuilder: (_, __) => const MediaCardSkeleton(),
                  )
                : _items.isEmpty
                    ? const Center(
                        child: Text(
                          'Nenhum título encontrado.',
                          style: TextStyle(color: AppTheme.textMuted),
                        ),
                      )
                    : CustomScrollView(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.all(16),
                            sliver: SliverGrid(
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                childAspectRatio: 0.62,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 16,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final item = _items[index];
                                  return MediaCard(
                                    item: item,
                                    width: double.infinity,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => DetailsView(item: item),
                                        ),
                                      );
                                    },
                                  );
                                },
                                childCount: _items.length,
                              ),
                            ),
                          ),
                          if (_isLoadingMore)
                            const SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: AppTheme.primary,
                                    strokeWidth: 2.5,
                                  ),
                                ),
                              ),
                            ),
                          if (!_hasMore && _items.isNotEmpty)
                            const SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Center(
                                  child: Text(
                                    'Você chegou ao fim desta categoria.',
                                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String filterKey) {
    final isSelected = _selectedFilter == filterKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected && _selectedFilter != filterKey) {
          setState(() => _selectedFilter = filterKey);
          _loadItems();
        }
      },
      selectedColor: AppTheme.primary,
      backgroundColor: AppTheme.card,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppTheme.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      side: BorderSide(color: isSelected ? AppTheme.primary : AppTheme.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}

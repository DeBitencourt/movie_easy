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

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    final catalog = context.read<CatalogProvider>();
    final results = await catalog.getCategoryItems(widget.type, filter: _selectedFilter);
    if (mounted) {
      setState(() {
        _items = results;
        _isLoading = false;
      });
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

          // Grade de Resultados
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
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: 0.62,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
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

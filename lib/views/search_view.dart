import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../models/media_item.dart';
import '../providers/catalog_provider.dart';
import '../widgets/media_card.dart';
import '../widgets/custom_shimmer.dart';
import 'details_view.dart';

class SearchView extends StatefulWidget {
  const SearchView({super.key});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  bool _isSearching = false;
  List<MediaItem> _allResults = [];
  String _selectedCategory = 'all';

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _allResults = [];
        _isSearching = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _isSearching = true);
      final catalog = context.read<CatalogProvider>();
      final results = await catalog.searchAll(query);
      if (mounted) {
        setState(() {
          _allResults = results;
          _isSearching = false;
        });
      }
    });
  }

  List<MediaItem> get _filteredResults {
    if (_selectedCategory == 'all') return _allResults;
    if (_selectedCategory == 'movie') {
      return _allResults.where((i) => i.type == MediaTypeEnum.movie).toList();
    }
    if (_selectedCategory == 'tv') {
      return _allResults.where((i) => i.type == MediaTypeEnum.tv).toList();
    }
    if (_selectedCategory == 'dorama') {
      return _allResults.where((i) => i.type == MediaTypeEnum.dorama).toList();
    }
    if (_selectedCategory == 'anime') {
      return _allResults.where((i) => i.type == MediaTypeEnum.anime).toList();
    }
    return _allResults;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = (screenWidth / 160).floor().clamp(2, 6);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Buscar Títulos'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Campo de Busca
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              autofocus: false,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Digite o nome do filme, série, anime ou dorama...',
                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: AppTheme.textMuted),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Chips de Filtro
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('Todos', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Filmes', 'movie'),
                const SizedBox(width: 8),
                _buildFilterChip('Séries', 'tv'),
                const SizedBox(width: 8),
                _buildFilterChip('Doramas', 'dorama'),
                const SizedBox(width: 8),
                _buildFilterChip('Animes', 'anime'),
              ],
            ),
          ),

          // Grade de Resultados
          Expanded(
            child: _isSearching
                ? GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: 0.65,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: crossAxisCount * 2,
                    itemBuilder: (_, __) => const MediaCardSkeleton(),
                  )
                : _searchController.text.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.search_rounded, size: 64, color: AppTheme.border),
                            SizedBox(height: 12),
                            Text(
                              'Pesquise em todo o catálogo unificado',
                              style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Filmes, Séries, Doramas e Animes com metadados completos',
                              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : _filteredResults.isEmpty
                        ? const Center(
                            child: Text(
                              'Nenhum resultado encontrado para esta busca.',
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
                            itemCount: _filteredResults.length,
                            itemBuilder: (context, index) {
                              final item = _filteredResults[index];
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

  Widget _buildFilterChip(String label, String key) {
    final isSelected = _selectedCategory == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _selectedCategory = key);
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

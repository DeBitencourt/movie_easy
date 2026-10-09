import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../models/media_item.dart';
import '../providers/downloads_provider.dart';
import '../widgets/app_logo.dart';
import '../widgets/custom_title_bar.dart';
import 'home_view.dart';
import 'category_view.dart';
import 'downloads_view.dart';
import 'library_view.dart';
import 'search_view.dart';
import 'settings_view.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const HomeView(), // 0
      const CategoryView(type: MediaTypeEnum.movie), // 1
      const CategoryView(type: MediaTypeEnum.tv), // 2
      const CategoryView(type: MediaTypeEnum.dorama), // 3
      LibraryView(onExploreCatalog: () => setState(() => _currentIndex = 0)), // 4
      const DownloadsView(), // 5
      const SearchView(), // 6
      const SettingsView(), // 7
    ];
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;
    final downloads = context.watch<DownloadsProvider>();

    final mainWidget = isDesktop
        ? Scaffold(
            backgroundColor: AppTheme.background,
            body: Column(
              children: [
                const CustomTitleBar(),
                Expanded(
                  child: Row(
                    children: [
                      // Sidebar Lateral para Desktop
                      _buildDesktopSidebar(downloads),
                      // Divisor sutil
                      Container(width: 1, color: AppTheme.border),
                      // Conteúdo Principal
                      Expanded(
                        child: IndexedStack(
                          index: _currentIndex,
                          children: _pages,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        : Scaffold(
            backgroundColor: AppTheme.background,
            body: IndexedStack(
              index: _currentIndex,
              children: _pages,
            ),
            bottomNavigationBar: Container(
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                border: Border(top: BorderSide(color: AppTheme.border, width: 1)),
              ),
              child: NavigationBar(
                backgroundColor: AppTheme.surface,
                indicatorColor: AppTheme.primary.withOpacity(0.2),
                selectedIndex: _getMobileSelectedIndex(),
                onDestinationSelected: (idx) {
                  final targetPage = _getMobilePageTarget(idx);
                  setState(() => _currentIndex = targetPage);
                },
                destinations: [
                  const NavigationDestination(
                    icon: Icon(Icons.home_outlined, color: AppTheme.textSecondary),
                    selectedIcon: Icon(Icons.home_rounded, color: AppTheme.primary),
                    label: 'Início',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.movie_outlined, color: AppTheme.textSecondary),
                    selectedIcon: Icon(Icons.movie_rounded, color: AppTheme.primary),
                    label: 'Filmes',
                  ),
                  NavigationDestination(
                    icon: Badge(
                      isLabelVisible: downloads.libraryTitlesCount > 0,
                      label: Text('${downloads.libraryTitlesCount}'),
                      backgroundColor: AppTheme.primary,
                      child: const Icon(Icons.video_library_outlined, color: AppTheme.textSecondary),
                    ),
                    selectedIcon: Badge(
                      isLabelVisible: downloads.libraryTitlesCount > 0,
                      label: Text('${downloads.libraryTitlesCount}'),
                      backgroundColor: AppTheme.primary,
                      child: const Icon(Icons.video_library_rounded, color: AppTheme.primary),
                    ),
                    label: 'Biblioteca',
                  ),
                  NavigationDestination(
                    icon: Badge(
                      isLabelVisible: downloads.activeCount > 0,
                      label: Text('${downloads.activeCount}'),
                      backgroundColor: AppTheme.primary,
                      child: const Icon(Icons.download_outlined, color: AppTheme.textSecondary),
                    ),
                    selectedIcon: Badge(
                      isLabelVisible: downloads.activeCount > 0,
                      label: Text('${downloads.activeCount}'),
                      backgroundColor: AppTheme.primary,
                      child: const Icon(Icons.download_rounded, color: AppTheme.primary),
                    ),
                    label: 'Downloads',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.search_outlined, color: AppTheme.textSecondary),
                    selectedIcon: Icon(Icons.search_rounded, color: AppTheme.primary),
                    label: 'Buscar',
                  ),
                ],
              ),
            ),
          );

    return PopScope(
      canPop: false,
      child: mainWidget,
    );
  }

  int _getMobileSelectedIndex() {
    switch (_currentIndex) {
      case 0:
        return 0;
      case 1:
        return 1;
      case 4:
        return 2;
      case 5:
        return 3;
      case 6:
        return 4;
      default:
        return 0;
    }
  }

  int _getMobilePageTarget(int bottomNavIdx) {
    switch (bottomNavIdx) {
      case 0:
        return 0; // Home
      case 1:
        return 1; // Filmes
      case 2:
        return 4; // Biblioteca
      case 3:
        return 5; // Downloads
      case 4:
        return 6; // Busca
      default:
        return 0;
    }
  }

  Widget _buildDesktopSidebar(DownloadsProvider downloads) {
    return Container(
      width: 230,
      color: AppTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo da Aplicação
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: AppLogo(
              size: 34,
              fontSize: 17,
              showText: true,
              subtitle: 'Streaming & Torrents',
            ),
          ),

          const Divider(color: AppTheme.border, height: 1),
          const SizedBox(height: 8),

          // Itens de Navegação scrolláveis caso a altura da janela seja compacta
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildSidebarItem(0, Icons.home_rounded, 'Início'),
                  _buildSidebarItem(1, Icons.movie_rounded, 'Filmes'),
                  _buildSidebarItem(2, Icons.tv_rounded, 'Séries'),
                  _buildSidebarItem(3, Icons.spa_rounded, 'Doramas'),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Divider(color: AppTheme.border, height: 1),
                  ),

                  _buildSidebarItem(
                    4,
                    Icons.video_library_rounded,
                    'Biblioteca',
                    badgeText: downloads.libraryTitlesCount > 0 ? '${downloads.libraryTitlesCount}' : null,
                  ),
                  _buildSidebarItem(
                    5,
                    Icons.download_rounded,
                    'Downloads',
                    badgeText: downloads.activeCount > 0 ? '${downloads.activeCount}' : null,
                  ),
                  _buildSidebarItem(6, Icons.search_rounded, 'Buscar'),
                  _buildSidebarItem(7, Icons.settings_rounded, 'Configurações'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(int index, IconData icon, String title, {String? badgeText}) {
    final isSelected = _currentIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _currentIndex = index),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primary.withOpacity(0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(color: AppTheme.primary.withOpacity(0.4), width: 1)
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
                if (badgeText != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badgeText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

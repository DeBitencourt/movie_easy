import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// Componente de Logo oficial da aplicação MovieEasy.
/// Apresenta o ícone cinematográfico estilizado e tipografia premium.
class AppLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final double? fontSize;
  final String? subtitle;

  const AppLogo({
    super.key,
    this.size = 32,
    this.showText = true,
    this.fontSize,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final titleSize = fontSize ?? (size * 0.55).clamp(13.0, 20.0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Símbolo / Ícone do Logo
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.24),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.35),
                blurRadius: size * 0.35,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.24),
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildFallbackIcon(),
            ),
          ),
        ),

        if (showText) ...[
          SizedBox(width: size * 0.32),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Movie',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: titleSize,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      TextSpan(
                        text: 'Easy',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: titleSize,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: (titleSize * 0.55).clamp(9.0, 11.0),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFallbackIcon() {
    return Container(
      color: AppTheme.primary,
      child: Center(
        child: Icon(
          Icons.play_arrow_rounded,
          color: Colors.white,
          size: size * 0.65,
        ),
      ),
    );
  }
}

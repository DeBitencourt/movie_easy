import 'media_item.dart';

/// Representa um item salvo na lista "Assistir Mais Tarde".
class WatchLaterItem {
  final MediaItem media;
  final DateTime addedAt;

  WatchLaterItem({
    required this.media,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'media': media.toJson(),
        'addedAt': addedAt.toIso8601String(),
      };

  factory WatchLaterItem.fromJson(Map<String, dynamic> json) {
    return WatchLaterItem(
      media: MediaItem.fromJson(json['media'] as Map<String, dynamic>),
      addedAt: json['addedAt'] != null
          ? DateTime.tryParse(json['addedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  /// Retorna uma descrição amigável de quando o item foi salvo
  String get formattedAddedTime {
    final now = DateTime.now();
    final difference = now.difference(addedAt);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes <= 1) {
          return 'Salvo agora há pouco';
        }
        return 'Salvo há ${difference.inMinutes} minutos';
      }
      return 'Salvo hoje';
    } else if (difference.inDays == 1) {
      return 'Salvo ontem';
    } else if (difference.inDays < 7) {
      return 'Salvo há ${difference.inDays} dias';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return 'Salvo há $weeks ${weeks == 1 ? 'semana' : 'semanas'}';
    } else {
      final months = (difference.inDays / 30).floor();
      return 'Salvo há $months ${months == 1 ? 'mês' : 'meses'}';
    }
  }
}

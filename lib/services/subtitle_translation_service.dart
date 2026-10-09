import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class SubtitleCue {
  final int index;
  final String timing;
  final String text;

  const SubtitleCue({
    required this.index,
    required this.timing,
    required this.text,
  });
}

/// Serviço para tradução automática de legendas SRT em lote mantendo sincronia de tempo e formatação.
class SubtitleTranslationService {
  static const String _sep = ' ===SUBSEP=== ';

  /// Analisa o texto de um arquivo SRT e extrai as marcações de tempo e legendas.
  static List<SubtitleCue> parseSrt(String content) {
    final lines = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    final List<SubtitleCue> cues = [];

    int? currentIndex;
    String? currentTiming;
    final List<String> currentTextLines = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) {
        if (currentIndex != null && currentTiming != null && currentTextLines.isNotEmpty) {
          cues.add(SubtitleCue(
            index: currentIndex,
            timing: currentTiming,
            text: currentTextLines.join(' '),
          ));
        }
        currentIndex = null;
        currentTiming = null;
        currentTextLines.clear();
        continue;
      }

      if (currentIndex == null) {
        final parsedIndex = int.tryParse(line);
        if (parsedIndex != null) {
          currentIndex = parsedIndex;
          continue;
        }
      }

      if (currentTiming == null && line.contains('-->')) {
        currentTiming = line;
        continue;
      }

      currentTextLines.add(line);
    }

    if (currentIndex != null && currentTiming != null && currentTextLines.isNotEmpty) {
      cues.add(SubtitleCue(
        index: currentIndex,
        timing: currentTiming,
        text: currentTextLines.join(' '),
      ));
    }

    return cues;
  }

  /// Traduz um lote de textos de uma só vez via API de tradução rápida.
  static Future<List<String>> _translateBatch(
    List<String> texts, {
    String from = 'en',
    String to = 'pt',
  }) async {
    if (texts.isEmpty) return [];

    final joined = texts.join(_sep);
    try {
      final uri = Uri.parse(
        'https://translate.googleapis.com/translate_a/single?client=gtx&sl=$from&tl=$to&dt=t&q=${Uri.encodeComponent(joined)}',
      );

      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded is List && decoded.isNotEmpty && decoded[0] is List) {
          final buffer = StringBuffer();
          for (final item in decoded[0]) {
            if (item is List && item.isNotEmpty) {
              buffer.write(item[0]);
            }
          }
          final translatedJoined = buffer.toString();
          final parts = translatedJoined.split('===SUBSEP===');

          final List<String> result = [];
          for (int i = 0; i < texts.length; i++) {
            if (i < parts.length) {
              result.add(parts[i].trim());
            } else {
              result.add(texts[i]);
            }
          }
          return result;
        }
      }
    } catch (e) {
      developer.log('Erro ao traduzir lote de legendas: $e');
    }

    return texts;
  }

  /// Traduz o conteúdo completo de uma legenda SRT para o português mantendo a sincronia.
  static Future<String> translateSrtString(
    String srtContent, {
    String from = 'en',
    String to = 'pt',
  }) async {
    final cues = parseSrt(srtContent);
    if (cues.isEmpty) return srtContent;

    const chunkSize = 40;
    final List<String> translatedTexts = [];

    for (int i = 0; i < cues.length; i += chunkSize) {
      final end = (i + chunkSize < cues.length) ? i + chunkSize : cues.length;
      final chunk = cues.sublist(i, end).map((c) => c.text).toList();
      final translatedChunk = await _translateBatch(chunk, from: from, to: to);
      translatedTexts.addAll(translatedChunk);
    }

    final buffer = StringBuffer();
    for (int i = 0; i < cues.length; i++) {
      buffer.writeln(cues[i].index);
      buffer.writeln(cues[i].timing);
      buffer.writeln(translatedTexts[i]);
      buffer.writeln('');
    }

    return buffer.toString();
  }

  /// Traduz um arquivo SRT local e salva a versão em Português no disco.
  static Future<File?> translateSrtFile(
    File sourceSrt, {
    File? outputFile,
    String from = 'en',
    String to = 'pt',
  }) async {
    try {
      if (!await sourceSrt.exists()) return null;

      final targetFile = outputFile ??
          File(sourceSrt.path.replaceAll(RegExp(r'\.srt$', caseSensitive: false), '.pt-BR.srt'));

      if (await targetFile.exists() && await targetFile.length() > 500) {
        return targetFile;
      }

      final content = await sourceSrt.readAsString();
      final translated = await translateSrtString(content, from: from, to: to);
      await targetFile.writeAsString(translated);
      return targetFile;
    } catch (e) {
      developer.log('Erro ao traduzir arquivo de legenda: $e');
      return null;
    }
  }

  /// Baixa uma legenda remota de uma URL (ex: KissKH CDN), traduz para Português e salva em cache.
  static Future<File?> getOrTranslateSrtFromUrl(
    String srtUrl, {
    required String cacheKey,
    String from = 'en',
    String to = 'pt',
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final safeKey = cacheKey.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final cachedFile = File('${tempDir.path}${Platform.pathSeparator}${safeKey}_pt-BR.srt');

      if (await cachedFile.exists() && await cachedFile.length() > 500) {
        return cachedFile;
      }

      final resp = await http.get(
        Uri.parse(srtUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0',
          'Referer': 'https://kisskh.co/',
        },
      ).timeout(const Duration(seconds: 8));

      if (resp.statusCode != 200) return null;

      final translated = await translateSrtString(resp.body, from: from, to: to);
      await cachedFile.writeAsString(translated);
      return cachedFile;
    } catch (e) {
      developer.log('Erro getOrTranslateSrtFromUrl: $e');
      return null;
    }
  }
}

// lib/services/direct_google_tts_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import '../models/text_to_mp3_audio_file.dart';
import '../viewmodels/warning_message_vm.dart';
import 'logging_service.dart';
import 'settings_data_service.dart';

/// Thrown when text synthesis genuinely fails for a reason unrelated
/// to connectivity (auth, quota, malformed request, ...). Kept distinct
/// from a plain Exception so the caller can decide how to react without
/// having to parse the message string.
class TtsSynthesisException implements Exception {
  final String message;
  TtsSynthesisException(this.message);

  @override
  String toString() => message;
}

class DirectGoogleTtsService {
  final String _apiKey = 'AIzaSyCcj0KjrlTuj8a6JTdowDMODjZSlTGVGvo';

  // Google Cloud Text-to-Speech hard-limits the input field (text or ssml)
  // to 5000 bytes per request. We stay well under that so that adding the
  // <speak> wrapper and <break time="Xs"/> tags for silence markers never
  // pushes a chunk over the real limit.
  static const int _maxChunkBytes = 4000;

  // Convert { characters to SSML breaks
  String _convertSilenceToSSML(String text, double silenceDurationSeconds) {
    if (!text.contains('{')) {
      return text;
    }

    String ssmlText =
        text.replaceAll('{', '<break time="${silenceDurationSeconds}s"/>');

    // Wrap in SSML speak tags
    ssmlText = '<speak>$ssmlText</speak>';

    logInfo('Text with silence converted to SSML: $ssmlText');
    return ssmlText;
  }

  /// Splits [text] into chunks whose UTF-8 byte length never exceeds
  /// [_maxChunkBytes], trying hard to break at sentence boundaries first,
  /// then at whitespace, and only cutting mid-word as a last resort.
  ///
  /// Splitting happens on the *raw* text (before the { -> SSML break
  /// conversion), because a chunk boundary must never fall inside a
  /// silence marker sequence, and because we need the final, SSML-wrapped
  /// byte length to be verified separately (see [_ensureSsmlChunkFits]).
  List<String> _splitTextIntoChunks(String text) {
    if (utf8.encode(text).length <= _maxChunkBytes) {
      return [text];
    }

    // Split into sentences, keeping the delimiter attached to the
    // preceding sentence. Handles '.', '!', '?', French guillemets and
    // line breaks as natural pause points.
    final sentenceRegExp = RegExp(r'(?<=[.!?…])\s+|\n+');
    final rawSentences = text.split(sentenceRegExp);

    final List<String> chunks = [];
    StringBuffer currentChunk = StringBuffer();

    void flushCurrentChunk() {
      final content = currentChunk.toString().trim();
      if (content.isNotEmpty) {
        chunks.add(content);
      }
      currentChunk = StringBuffer();
    }

    for (final sentence in rawSentences) {
      if (sentence.trim().isEmpty) continue;

      final candidate =
          currentChunk.isEmpty ? sentence : '${currentChunk.toString()} $sentence';

      if (utf8.encode(candidate).length <= _maxChunkBytes) {
        currentChunk = StringBuffer(candidate);
        continue;
      }

      // Adding this sentence would overflow the current chunk: flush
      // what we have and start a new chunk with this sentence.
      flushCurrentChunk();

      if (utf8.encode(sentence).length <= _maxChunkBytes) {
        currentChunk = StringBuffer(sentence);
      } else {
        // A single "sentence" is itself too long (e.g. no punctuation
        // for a long stretch, or a run-on paragraph). Hard-split it on
        // whitespace.
        chunks.addAll(_hardSplitOnWhitespace(sentence));
      }
    }

    flushCurrentChunk();

    logInfo(
      'Text split into ${chunks.length} chunk(s) for TTS synthesis '
      '(original length: ${text.length} chars, ${utf8.encode(text).length} bytes)',
    );

    return chunks;
  }

  /// Last-resort splitter for a single oversized "sentence": cuts on
  /// whitespace so we never break a word in half.
  List<String> _hardSplitOnWhitespace(String text) {
    final words = text.split(RegExp(r'\s+'));
    final List<String> chunks = [];
    StringBuffer current = StringBuffer();

    for (final word in words) {
      final candidate = current.isEmpty ? word : '${current.toString()} $word';
      if (utf8.encode(candidate).length <= _maxChunkBytes) {
        current = StringBuffer(candidate);
      } else {
        if (current.isNotEmpty) {
          chunks.add(current.toString());
        }
        current = StringBuffer(word);
      }
    }

    if (current.isNotEmpty) {
      chunks.add(current.toString());
    }

    return chunks;
  }

  /// Given a raw text chunk, converts it to SSML (if it contains silence
  /// markers) and, on the rare chance that the SSML wrapping itself pushed
  /// the byte length over the API limit, halves the chunk and retries
  /// recursively.
  List<String> _ensureSsmlChunksFit(
    String rawChunk,
    double silenceDurationSeconds,
  ) {
    final ssml = _convertSilenceToSSML(rawChunk, silenceDurationSeconds);

    if (utf8.encode(ssml).length <= 5000) {
      return [ssml];
    }

    // Extremely unlikely given the _maxChunkBytes margin, but split the
    // raw chunk roughly in half (on whitespace) and retry each half.
    final words = rawChunk.split(RegExp(r'\s+'));
    if (words.length <= 1) {
      // Nothing left to split on; return as-is and let the API reject it
      // rather than looping forever.
      return [ssml];
    }

    final mid = words.length ~/ 2;
    final firstHalf = words.sublist(0, mid).join(' ');
    final secondHalf = words.sublist(mid).join(' ');

    return [
      ..._ensureSsmlChunksFit(firstHalf, silenceDurationSeconds),
      ..._ensureSsmlChunksFit(secondHalf, silenceDurationSeconds),
    ];
  }

  // Sanitize filename for Android compatibility
  String _sanitizeFilename(String filename) {
    // Remove or replace problematic characters
    String sanitized = filename
        // Replace quotes with nothing
        .replaceAll('"', '')
        // Replace colon with dash
        .replaceAll(':', ' -')
        // Replace other problematic characters
        .replaceAll('/', '_')
        .replaceAll('\\', '_')
        .replaceAll('<', '_')
        .replaceAll('>', '_')
        .replaceAll('|', '_')
        .replaceAll('*', '_')
        .replaceAll('?', '_')
        // Replace multiple spaces with single space
        .replaceAll(RegExp(r'\s+'), ' ')
        // Trim whitespace
        .trim();

    // Ensure filename isn't too long (Android has ~255 char limit)
    if (sanitized.length > 200) {
      sanitized = sanitized.substring(0, 200);
    }

    // Ensure it's not empty after sanitization
    if (sanitized.isEmpty) {
      sanitized = 'audio_${DateTime.now().millisecondsSinceEpoch}';
    }

    logInfo('Original filename: "$filename"');
    logInfo('Sanitized filename: "$sanitized"');

    return sanitized;
  }

  List<Map<String, String>> _voicesToTryFor({
    required Language appLanguage,
    required bool isVoiceMan,
  }) {
    if (appLanguage == Language.french) {
      return isVoiceMan
          ? [
              {'name': 'fr-FR-Standard-B', 'lang': 'fr-FR'}, // man voice
              {'name': 'fr-FR-Standard-D', 'lang': 'fr-FR'}, // woman voice
            ]
          : [
              {'name': 'fr-FR-Standard-A', 'lang': 'fr-FR'}, // woman voice
              {'name': 'fr-FR-Standard-C', 'lang': 'fr-FR'}, // man voice
            ];
    } else {
      return isVoiceMan
          ? [
              {'name': 'en-US-Standard-A', 'lang': 'en-US'},
              {'name': 'en-US-Standard-B', 'lang': 'en-US'},
            ]
          : [
              {'name': 'en-US-Standard-C', 'lang': 'en-US'},
              {'name': 'en-US-Standard-E', 'lang': 'en-US'},
            ];
    }
  }

  /// Synthesizes a single SSML/plain-text chunk, trying each voice in
  /// [voicesToTry] in order until one succeeds. Returns the audio bytes
  /// and the name of the voice that worked, or throws a
  /// [TtsSynthesisException] if every voice failed for a reason that
  /// isn't worth retrying (auth, quota, ...).
  Future<_ChunkSynthesisResult> _synthesizeChunk({
    required String processedChunk,
    required List<Map<String, String>> voicesToTry,
  }) async {
    for (final voice in voicesToTry) {
      try {
        logInfo('Tentative avec voix: ${voice['name']}');

        final requestBody = {
          'input': processedChunk.startsWith('<speak>')
              ? {'ssml': processedChunk}
              : {'text': processedChunk},
          'voice': {'languageCode': voice['lang'], 'name': voice['name']},
          'audioConfig': {'audioEncoding': 'MP3', 'sampleRateHertz': 24000},
        };

        final response = await http
            .post(
          Uri.parse(
            'https://texttospeech.googleapis.com/v1/text:synthesize?key=$_apiKey',
          ),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestBody),
        )
            .timeout(
          Duration(seconds: 30),
          onTimeout: () {
            throw TimeoutException(
              'API request timed out',
              Duration(seconds: 30),
            );
          },
        );

        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);
          final audioContent = responseData['audioContent'] as String;
          final audioBytes = base64Decode(audioContent);

          logInfo(
            '✅ Succès avec ${voice['name']}: ${audioBytes.length} bytes',
          );

          return _ChunkSynthesisResult(
            audioBytes: audioBytes,
            voiceName: voice['name']!,
          );
        } else {
          _handleHttpError(
            statusCode: response.statusCode,
            responseBody: response.body,
            voiceName: voice['name']!,
          );
          // _handleHttpError throws for the non-recoverable cases
          // (401/403/429). For the others it just logs, so we fall
          // through and try the next voice.
        }
      } on TtsSynthesisException {
        rethrow; // Non-recoverable: no point trying another voice.
      } catch (voiceError) {
        logWarning('Erreur avec ${voice['name']}: $voiceError');
        // Try the next voice.
      }
    }

    throw TtsSynthesisException(
      'Toutes les voix ont échoué pour ce segment de texte.',
    );
  }

  Future<TextToMp3AudioFile?> convertTextToMP3({
    required WarningMessageVM warningMessageVMlistenFalse,
    required Language appLanguage,
    required String text,
    required String customFileName,
    required String mp3FileDirectory,
    required bool isVoiceMan,
    required double silenceDurationSeconds,
  }) async {
    try {
      logInfo('=== CONVERSION MP3 AVEC VOIX SELECTIONNEE ===');
      logInfo('Longueur texte: ${text.length} caractères, '
          '${utf8.encode(text).length} bytes');
      logInfo('Fichier original: "$customFileName"');
      logInfo('Durée silence: ${silenceDurationSeconds}s');

      // 1. Split the raw text into byte-safe chunks (never mid-marker,
      //    prefers sentence boundaries).
      final rawChunks = _splitTextIntoChunks(text);

      // 2. Convert each raw chunk to SSML (if needed) and guarantee it
      //    fits under the API's real 5000-byte limit.
      final List<String> processedChunks = [];
      for (final rawChunk in rawChunks) {
        processedChunks
            .addAll(_ensureSsmlChunksFit(rawChunk, silenceDurationSeconds));
      }

      logInfo('${processedChunks.length} segment(s) à synthétiser');

      final sanitizedFileName = _sanitizeFilename(customFileName);
      final voicesToTry =
          _voicesToTryFor(appLanguage: appLanguage, isVoiceMan: isVoiceMan);

      // 3. Synthesize the first chunk to pick a working voice, then keep
      //    using that same voice for every remaining chunk so the whole
      //    file sounds consistent.
      final BytesBuilder combinedAudio = BytesBuilder();
      String? chosenVoiceName;

      for (int i = 0; i < processedChunks.length; i++) {
        final chunk = processedChunks[i];

        final voiceOrderForThisChunk = chosenVoiceName == null
            ? voicesToTry
            : [
                ...voicesToTry.where((v) => v['name'] == chosenVoiceName),
                ...voicesToTry.where((v) => v['name'] != chosenVoiceName),
              ];

        final result = await _synthesizeChunk(
          processedChunk: chunk,
          voicesToTry: voiceOrderForThisChunk,
        );

        chosenVoiceName ??= result.voiceName;
        combinedAudio.add(result.audioBytes);

        logInfo(
          'Segment ${i + 1}/${processedChunks.length} synthétisé '
          '(${result.audioBytes.length} bytes, voix ${result.voiceName})',
        );
      }

      final audioBytes = combinedAudio.toBytes();

      // 4. Write the combined MP3 bytes to disk (same fallback-to-
      //    Download-folder logic as before).
      final fileName = sanitizedFileName.endsWith('.mp3')
          ? sanitizedFileName
          : '$sanitizedFileName.mp3';
      final filePath = '$mp3FileDirectory${path.separator}$fileName';

      logInfo('Chemin du fichier: $filePath');

      final directory = Directory(mp3FileDirectory);
      if (!directory.existsSync()) {
        logInfo('Création du répertoire: $mp3FileDirectory');
        directory.createSync(recursive: true);
      }

      TextToMp3AudioFile result;
      final file = File(filePath);

      try {
        await file.writeAsBytes(audioBytes);
        logInfo('✅ Fichier sauvegardé: $filePath');

        result = TextToMp3AudioFile(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: text,
          filePath: filePath,
          createdAt: DateTime.now(),
          sizeBytes: audioBytes.length,
        );
      } catch (writeError) {
        logError('Erreur d\'écriture du fichier: $writeError');

        final fallbackDir = Directory('/storage/emulated/0/Download');
        if (fallbackDir.existsSync()) {
          final fallbackPath = '${fallbackDir.path}${path.separator}$fileName';
          logInfo(
              'Tentative d\'écriture dans le répertoire de téléchargement: $fallbackPath');

          final fallbackFile = File(fallbackPath);
          await fallbackFile.writeAsBytes(audioBytes);
          logInfo('✅ Fichier sauvegardé dans Download: $fallbackPath');

          result = TextToMp3AudioFile(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: text,
            filePath: fallbackPath,
            createdAt: DateTime.now(),
            sizeBytes: audioBytes.length,
          );
        } else {
          rethrow;
        }
      }

      logInfo('=== CONVERSION MP3 TERMINÉE ===');

      return result;
    } on TtsSynthesisException catch (e) {
      // Genuine, non-recoverable synthesis failure (auth, quota, ...).
      // Let it propagate with its real message instead of being
      // swallowed into a generic null return.
      logError('Erreur de synthèse TTS', e);
      rethrow;
    } catch (e) {
      logError('Erreur conversion MP3 avec voix', e);
      rethrow;
    }
  }

  // Helper method to handle specific HTTP status codes
  void _handleHttpError({
    required int statusCode,
    required String responseBody,
    required String voiceName,
  }) {
    switch (statusCode) {
      case 400:
        logError(
          'Erreur 400 avec $voiceName: Requête invalide - $responseBody',
        );
        break;
      case 401:
        logError('Erreur 401 avec $voiceName: Clé API invalide ou manquante');
        throw TtsSynthesisException(
          'Clé API Google Cloud invalide. Vérifiez votre configuration.',
        );
      case 403:
        logError(
          'Erreur 403 avec $voiceName: Accès refusé - Quota dépassé ou API désactivée',
        );
        throw TtsSynthesisException(
          'Quota Google Cloud dépassé ou API désactivée. Vérifiez votre compte.',
        );
      case 404:
        logError('Erreur 404 avec $voiceName: Ressource non trouvée');
        break;
      case 429:
        logError('Erreur 429 avec $voiceName: Trop de requêtes');
        throw TtsSynthesisException(
          'Trop de requêtes. Attendez quelques minutes avant de réessayer.',
        );
      case 500:
      case 502:
      case 503:
        logError(
          'Erreur serveur $statusCode avec $voiceName: Problème côté Google',
        );
        break;
      default:
        logWarning('Échec $voiceName: $statusCode - $responseBody');
    }
  }
}

class _ChunkSynthesisResult {
  final List<int> audioBytes;
  final String voiceName;

  _ChunkSynthesisResult({
    required this.audioBytes,
    required this.voiceName,
  });
}
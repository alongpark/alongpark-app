import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import '../api/api_client.dart';

/// Service voix — TTS via OpenAI TTS HD (nova) + STT via Whisper,
/// tous les deux proxifiés par le backend Alongpark.
class VoiceService {
  static final _player = AudioPlayer();
  static final _recorder = AudioRecorder();
  static bool _recording = false;
  static bool _initialized = false;

  static Future<void> _init() async {
    if (_initialized) return;
    try {
      if (Platform.isIOS) {
        await _player.setAudioContext(AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playAndRecord,
            options: {
              AVAudioSessionOptions.duckOthers,
              AVAudioSessionOptions.defaultToSpeaker,
            },
          ),
        ));
        await Future.delayed(const Duration(milliseconds: 500));
      }
      _initialized = true;
    } catch (e) {
      debugPrint('[VoiceService] Init error: $e');
    }
  }

  static String get _ttsUrl => '${ApiClient.baseUrl}/api/voice/tts';
  static String get _sttUrl => '${ApiClient.baseUrl}/api/voice/stt';

  // ── TTS ──────────────────────────────────────────────────────────────────

  /// Retourne null si succès, ou un message d'erreur lisible si échec.
  static Future<String?> speak(String text, {String voice = 'shimmer'}) async {
    await _init();
    await stop();
    try {
      final res = await http.post(
        Uri.parse(_ttsUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text, 'voice': voice}),
      ).timeout(const Duration(seconds: 25));

      if (res.statusCode == 200) {
        final contentType = res.headers['content-type'];
        if (contentType != null && !contentType.contains('audio')) {
          debugPrint('[VoiceService] TTS: réponse non-audio: $contentType - ${res.body}');
          return 'Erreur serveur (non-audio): ${res.body.substring(0, 50)}...';
        }

        if (res.bodyBytes.isEmpty) {
          debugPrint('[VoiceService] TTS: réponse vide');
          return 'Réponse TTS vide';
        }

        // Sur iOS, BytesSource peut être instable. On passe par un fichier temporaire.
        final tempDir = Directory.systemTemp;
        final file = File('${tempDir.path}/tts_output.mp3');
        await file.writeAsBytes(res.bodyBytes);
        
        final size = await file.length();
        debugPrint('[VoiceService] TTS playing file: ${file.path} ($size bytes)');

        await _player.setVolume(1.0);
        await _player.play(DeviceFileSource(file.path));
        
        return null;
      } else {
        debugPrint('[VoiceService] TTS erreur ${res.statusCode}: ${res.body}');
        return 'TTS ${res.statusCode}: ${res.body}';
      }
    } catch (e) {
      debugPrint('[VoiceService] TTS exception: $e');
      return 'Erreur de lecture audio (iOS) : ${e.toString()}';
    }
  }

  static Future<void> stop() async {
    await _player.stop();
  }

  // ── STT ──────────────────────────────────────────────────────────────────

  static Future<bool> startListening() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        debugPrint('[VoiceService] STT: permission microphone refusée');
        return false;
      }
      final path = '${Directory.systemTemp.path}/voice_input.wav';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );
      _recording = true;
      return true;
    } catch (e) {
      debugPrint('[VoiceService] startListening exception: $e');
      return false;
    }
  }

  /// Arrête l'enregistrement et renvoie le texte transcrit (null si erreur).
  static Future<String?> stopListening() async {
    if (!_recording) return null;
    try {
      final path = await _recorder.stop();
      _recording = false;
      if (path == null) return null;

      final file = File(path);
      if (!await file.exists()) return null;

      final req = http.MultipartRequest('POST', Uri.parse(_sttUrl));
      req.files.add(await http.MultipartFile.fromPath('audio', path,
          filename: 'audio.wav'));

      final streamed = await req.send().timeout(const Duration(seconds: 20));
      final res = await http.Response.fromStream(streamed);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return (data['text'] as String?)?.toLowerCase().trim();
      } else {
        debugPrint('[VoiceService] STT erreur ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      debugPrint('[VoiceService] stopListening exception: $e');
      _recording = false;
    }
    return null;
  }
}

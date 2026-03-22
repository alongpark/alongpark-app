import 'dart:convert';
import 'dart:io';
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

  static String get _ttsUrl => '${ApiClient.baseUrl}/api/voice/tts';
  static String get _sttUrl => '${ApiClient.baseUrl}/api/voice/stt';

  // ── TTS ──────────────────────────────────────────────────────────────────

  static Future<void> speak(String text, {String voice = 'nova'}) async {
    await stop();
    try {
      final res = await http.post(
        Uri.parse(_ttsUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text, 'voice': voice}),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        await _player.play(BytesSource(res.bodyBytes));
      }
    } catch (_) {}
  }

  static Future<void> stop() async {
    await _player.stop();
  }

  // ── STT ──────────────────────────────────────────────────────────────────

  static Future<bool> startListening() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) return false;
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
    } catch (_) {
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
      }
    } catch (_) {
      _recording = false;
    }
    return null;
  }
}

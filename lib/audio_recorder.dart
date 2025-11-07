import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';

class AudioRecorder {
  final FlutterSoundRecorder        _recorder   = FlutterSoundRecorder();
  final StreamController<Uint8List> _controller = StreamController<Uint8List>();
  final List<int>                   _pcmBuffer  = [];
  int                               _recStart   = 0;             

  Future<void> init() async {
    bool firstBufferReceived = false;
    _controller.stream.listen((buffer) {
      if (firstBufferReceived == false) {
        firstBufferReceived = true;
        final now = DateTime.now().millisecondsSinceEpoch;
        debugPrint('REAL LATENCY: ${now - _recStart}ms');
      }
      _pcmBuffer.addAll(buffer);
    });

    await Permission.microphone.request();
    await Permission.storage.request();
    await _recorder.openRecorder();
  }

  Future<void> rec() async {
    _recStart = DateTime.now().millisecondsSinceEpoch;
    await _recorder.startRecorder(
      toStream: _controller.sink,
      codec: Codec.pcm16,
      numChannels: 1,
      sampleRate: 48000,
      bufferSize: 64,
      audioSource: AudioSource.microphone
    );
  }

  Future<void> save(String path) async {
    await _recorder.stopRecorder();
    final pcm = Uint8List.fromList(_pcmBuffer);
    final wav = _addWavHeader(pcm, 1, 48000, 16);
    await File("$path.wav").writeAsBytes(wav);
    await FFmpegKit.execute('-y -i "$path.wav" -c:a aac "$path.aac"');
    await File("$path.wav").delete();
    _pcmBuffer.clear();
  }

  Future<void> destroy() async {
    _recorder.closeRecorder();
  }

  Uint8List _addWavHeader(Uint8List pcm, int channels, int sampleRate, int bitsPerSample) {
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;
    final dataSize = pcm.length;
    final header = ByteData(44);

    header.setUint8(0, 'R'.codeUnitAt(0));
    header.setUint8(1, 'I'.codeUnitAt(0));
    header.setUint8(2, 'F'.codeUnitAt(0));
    header.setUint8(3, 'F'.codeUnitAt(0));
    header.setUint32(4, 36 + dataSize, Endian.little);
    header.setUint8(8, 'W'.codeUnitAt(0));
    header.setUint8(9, 'A'.codeUnitAt(0));
    header.setUint8(10, 'V'.codeUnitAt(0));
    header.setUint8(11, 'E'.codeUnitAt(0));
    header.setUint8(12, 'f'.codeUnitAt(0));
    header.setUint8(13, 'm'.codeUnitAt(0));
    header.setUint8(14, 't'.codeUnitAt(0));
    header.setUint8(15, ' '.codeUnitAt(0));
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    header.setUint8(36, 'd'.codeUnitAt(0));
    header.setUint8(37, 'a'.codeUnitAt(0));
    header.setUint8(38, 't'.codeUnitAt(0));
    header.setUint8(39, 'a'.codeUnitAt(0));
    header.setUint32(40, dataSize, Endian.little);

    return Uint8List.fromList(header.buffer.asUint8List() + pcm);
  }
}
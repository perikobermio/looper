import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';

class LoopPlayerTile extends StatefulWidget {
  final String filePath;
  final VoidCallback onDelete;
  const LoopPlayerTile({super.key, required this.filePath, required this.onDelete});

  @override
  State<LoopPlayerTile> createState() => _LoopPlayerTileState();
}

class _LoopPlayerTileState extends State<LoopPlayerTile> {
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _player.openPlayer();
  }

  @override
  void dispose() {
    _player.closePlayer();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.stopPlayer();
      setState(() => _isPlaying = false);
    } else {
      await _startLoop();
      setState(() => _isPlaying = true);
    }
  }

  Future<void> _startLoop() async {
    await _player.startPlayer(
      fromURI: widget.filePath,
      codec: Codec.aacADTS,
      whenFinished: () async {
        if (_isPlaying) {
          // Reinicia inmediatamente al terminar
          await _player.startPlayer(
            fromURI: widget.filePath,
            codec: Codec.aacADTS,
            whenFinished: _startLoop,
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.filePath.split('/').last;
    return ListTile(
      leading: IconButton(
        icon: const Icon(Icons.delete),
        onPressed: () async {
          final file = File(widget.filePath);
          if (await file.exists()) {
            await file.delete();
            widget.onDelete();
          }
        },
      ),
      title: Text(fileName),
      trailing: IconButton(
        icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
        onPressed: _togglePlay,
      ),
    );
  }
}
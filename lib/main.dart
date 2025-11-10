import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'audio_recorder.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final recorder = AudioRecorder();

  bool _isRecording = false;
  int _channel      = 1;

  List<FileSystemEntity> _loops = [];
  late Directory loopsDir;

  @override
  void initState() {
    super.initState();
    recorder.init();
    _getLoopsDirectory().then((_) => _loadLoops());
  }

  Future<void> _getLoopsDirectory() async {
    final dir = await getExternalStorageDirectory();
    loopsDir = Directory('${dir!.path}/loops');
    if (!loopsDir.existsSync()) loopsDir.createSync(recursive: true);
  }

  Future<void> _loadLoops() async {
    final files = loopsDir.listSync().where((f) => f.path.endsWith('.aac')).toList();
    setState(() => _loops = files);
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await recorder.save('${loopsDir.path}/rec_$_channel');
      await _loadLoops();
      setState(() => _isRecording = false);
      return;
    }

    recorder.rec();
    setState(() => _isRecording = true);
  }

  @override
  void dispose() {
    recorder.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Looper App'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: DropdownButton<int>(
              value: _channel,
              items: List.generate(
                4,
                (index) => DropdownMenuItem(
                  value: index + 1,
                  child: Text('Canal ${index + 1}'),
                ),
              ),
              onChanged: (value) {
                setState(() => _channel = value!);
                debugPrint('Canal seleccionado: $_channel');
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _loops.length,
              itemBuilder: (context, index) {
                final file = _loops[index];
                return LoopPlayerTile(filePath: file.path);
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: _toggleRecording,
          child: Text(_isRecording ? 'Stop' : 'REC'),
        ),
      ),
    );
  }
}

class LoopPlayerTile extends StatefulWidget {
  final String filePath;
  const LoopPlayerTile({super.key, required this.filePath});

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
      title: Text(fileName),
      trailing: IconButton(
        icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
        onPressed: _togglePlay,
      ),
    );
  }
}


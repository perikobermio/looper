import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'audio_recorder.dart';
import 'player_tile.dart';

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
  bool _allPlaying  = false;

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

  void _togglePlayAll() {
    setState(() => _allPlaying = !_allPlaying);
    if (_allPlaying) {
      // reproducir todos
    } else {
      // detener todos
    }
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                DropdownButton<int>(
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
                  },
                ),
                ElevatedButton.icon(
                  onPressed: _togglePlayAll,
                  icon: Icon(_allPlaying ? Icons.stop : Icons.play_arrow),
                  label: const Text(''),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _loops.length,
              itemBuilder: (context, index) {
                final file = _loops[index];
                return LoopPlayerTile(filePath: file.path, onDelete: _loadLoops);
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
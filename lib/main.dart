import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';

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
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();

  bool    _isRecording = false;
  String? _filePath;
  final String  _channel = '1';

  @override
  void initState() {
    super.initState();
    _initRecorder();
  }

  Future<void> _initRecorder() async {
    await _recorder.openRecorder();
    final dir = await getExternalStorageDirectory();
    _filePath = '${dir!.path}/loop_$_channel.aac';
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _recorder.stopRecorder();
      setState(() => _isRecording = false);
      debugPrint("Saved $_filePath");

      return;
    }
    
    await _recorder.startRecorder(
      toFile:       _filePath,
      codec:        Codec.aacADTS,
      sampleRate:   44100,
      numChannels:  1,
    );

    setState(() => _isRecording = true);
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Looper App'),
        centerTitle: true,
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: _toggleRecording,
          child: Text(_isRecording ? 'Stop' : 'REC'),
        ),
      ),
    );
  }
}

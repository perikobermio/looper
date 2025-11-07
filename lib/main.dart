import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'dart:async';

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
  final StreamController<Uint8List> _controller = StreamController<Uint8List>();
  final List<int> _pcmBuffer = [];

  bool _isRecording = false;
  int _channel = 1;

  List<FileSystemEntity> _loops = [];
  late Directory loopsDir;

  @override
  void initState() {
    super.initState();
    _controller.stream.listen((buffer) {
      _pcmBuffer.addAll(buffer);
    });
    _initRecorder();
    _getLoopsDirectory().then((_) => _loadLoops());
  }

  Future<void> _initRecorder() async {
    await Permission.microphone.request();
    await Permission.storage.request();
    await _recorder.openRecorder();
  }

  Future<void> _getLoopsDirectory() async {
    final dir = await getExternalStorageDirectory();
    loopsDir = Directory('${dir!.path}/loops');
    if (!loopsDir.existsSync()) loopsDir.createSync(recursive: true);
  }

  Future<void> _loadLoops() async {
    final files = loopsDir
        .listSync()
        .where((f) => f.path.endsWith('.aac'))
        .toList();
    setState(() => _loops = files);
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

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _recorder.stopRecorder();
      setState(() => _isRecording = false);

      final pcm = Uint8List.fromList(_pcmBuffer);
      final wav = _addWavHeader(pcm, 1, 48000, 16);
      final wavPath = '${loopsDir.path}/rec_$_channel.wav';
      await File(wavPath).writeAsBytes(wav);

      await FFmpegKit.execute('-y -i "$wavPath" -c:a aac "${loopsDir.path}/rec_$_channel.aac"');
      await _loadLoops();
      _pcmBuffer.clear();
      return;
    }

    //final start = DateTime.now().millisecondsSinceEpoch;

    await _recorder.startRecorder(
      toStream: _controller.sink,
      codec: Codec.pcm16,
      numChannels: 1,
      sampleRate: 48000,
      bufferSize: 256,
      audioSource: AudioSource.microphone
    );

    //final end = DateTime.now().millisecondsSinceEpoch;
    //debugPrint('LATENCY: ${end - start}ms');

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
      await _player.startPlayer(
        fromURI: widget.filePath,
        codec: Codec.aacADTS,
        whenFinished: () => setState(() => _isPlaying = false),
      );
      setState(() => _isPlaying = true);
    }
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

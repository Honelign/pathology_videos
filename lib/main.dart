import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path/path.dart' as path;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

void main() {
    WidgetsFlutterBinding.ensureInitialized();
  // Make sure to add the required packages to pubspec.yaml:
  // * https://github.com/media-kit/media-kit#installation
  // * https://pub.dev/packages/media_kit#installation
  MediaKit.ensureInitialized(

  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      
  // Make sure to add the required packages to pubspec.yaml:
  // * https://github.com/media-kit/media-kit#installation
  // * https://pub.dev/packages/media_kit#installation

      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _directoryPath;
  List<File> _videoFiles = [];
  Player? _player; // Updated player controller for media_kit
  VideoController? _videoController;
  String? _thumbnailsDir;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _initThumbnailsDir();
    _loadSavedPath();
  }

  Future<void> _initThumbnailsDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    _thumbnailsDir = path.join(appDir.path, 'thumbnails');
    await Directory(_thumbnailsDir!).create(recursive: true);
  }

  Future<void> _loadSavedPath() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _directoryPath = prefs.getString('videoDirectory');
    });
    if (_directoryPath != null) {
      _loadVideos();
    }
  }

  Future<void> _selectDirectory() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      setState(() {
        _directoryPath = selectedDirectory;
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('videoDirectory', selectedDirectory);
      _loadVideos();
    }
  }

  Future<void> _loadVideos() async {
    if (_directoryPath == null) return;

    final directory = Directory(_directoryPath!);
    final List<FileSystemEntity> entities = await directory.list().toList();
    setState(() {
      _videoFiles = entities
          .whereType<File>()
          .where((file) => ['.mp4', '.avi', '.mov', '.mkv'].contains(
              file.path.substring(file.path.lastIndexOf('.')).toLowerCase()))
          .toList();
    });
  }

  Future<String> _getThumbnail(File videoFile) async {
    final thumbnailPath =
        path.join(_thumbnailsDir!, '${path.basename(videoFile.path)}.jpg');
    final thumbnailFile = File(thumbnailPath);

    if (await thumbnailFile.exists()) {
      return thumbnailPath;
    }

    final thumbnail = await VideoThumbnail.thumbnailFile(
      video: videoFile.path,
      thumbnailPath: 'assets/thumb96.png',
      imageFormat: ImageFormat.PNG,
      quality: 75,
    );

    return thumbnail ?? 'assets/thumb96.png';
  }

  Future<void> _playVideo(File file) async {
    if (_player != null) {
      await _player!.dispose();
    }
    _player = Player(); // Create media_kit Player instance
    _videoController = await VideoController(_player!);
    await _player!.open(Media(file.path)); // Load video from file

    setState(() {
      _isPlaying = true;
    });

    await _player!.play();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pathology Videos'),
        centerTitle: true,
        leading: _isPlaying
            ? IconButton(
                onPressed: () {
                  setState(() {
                    _isPlaying = false;
                    _player?.pause();
                  });
                },
                icon: const Icon(Icons.arrow_back),
              )
            : Text(''),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _isPlaying
                  ? const Text('')
                  : TextButton(
                      child: const Text('.'),
                      onPressed: _selectDirectory,
                    ),
            ],
          ),
        ],
      ),
      body: _isPlaying ? _buildVideoPlayer() : _buildVideoList(),
      floatingActionButton: _isPlaying
          ? FloatingActionButton(
              onPressed: () {
                setState(() {
                  if (_player!.state.playing) {
                    _player!.pause();
                  } else {
                    _player!.play();
                  }
                });
              },
              child: Icon(
                _player!.state.playing ? Icons.pause : Icons.play_arrow,
              ),
            )
          : null,
    );
  }

  Widget _buildVideoPlayer() {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.9,
      child: Column(
        children: [
          Expanded(
            child: AspectRatio(
              aspectRatio:MediaQuery.of(context).size.width * 9.0 / 16.0,
              child: Video(
                controller: _videoController!,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoList() {
    if (_directoryPath == null) {
      return const Center(child: Text('Please select a directory'));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 16 / 9,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: _videoFiles.length,
        itemBuilder: (context, index) {
          final file = _videoFiles[index];
          final videoTitle = extractVideoTitle(file.path);
          return GestureDetector(
            onTap: () => _playVideo(file),
            child: FutureBuilder<String>(
              future: _getThumbnail(file),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done &&
                    snapshot.hasData) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/thumb48.png',
                        fit: BoxFit.cover,
                      ),
                      const Center(
                        child: Icon(Icons.play_circle_outline,
                            size: 50, color: Colors.white),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      SizedBox(
                        height: 150,
                        child: Image.asset(
                          'assets/thumb96.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                      Text(videoTitle.toString()),
                    ],
                  );
                }
              },
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  String extractVideoTitle(String filePath) {
    final fileName = filePath.split('\\').last;
    final title = fileName.substring(0, fileName.lastIndexOf('.'));
    return title;
  }
}

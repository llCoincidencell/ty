import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../services/youtube_service.dart';
import '../utils/download_helper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _urlController = TextEditingController();
  final YouTubeService _ytService = YouTubeService();
  final DownloadHelper _downloadHelper = DownloadHelper();

  bool _isLoading = false;
  String _statusMessage = '';
  double _progress = 0.0;
  Video? _videoInfo;
  bool _isAudio = false;

  Future<void> _fetchInfo() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Video bilgisi alınıyor...';
      _videoInfo = null;
    });

    try {
      final video = await _ytService.getVideoInfo(url);
      setState(() {
        _videoInfo = video;
        _isLoading = false;
        _statusMessage = 'Bulundu: ${video.title}';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Hata: $e';
      });
    }
  }

  Future<void> _startDownload() async {
    if (_videoInfo == null) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'İndirme başlıyor...';
      _progress = 0.0;
    });

    try {
      final hasPermission = await _downloadHelper.requestPermission();
      if (!hasPermission) {
        throw Exception('Depolama izni verilmedi');
      }

      final manifest = await _ytService.getManifest(_videoInfo!.id.value);
      StreamInfo streamInfo;
      String ext;
      String folder;

      if (_isAudio) {
        streamInfo = manifest.audioOnly.withHighestBitrate();
        ext = 'mp3';
        folder = 'Music';
      } else {
        streamInfo = manifest.muxed.withHighestBitrate();
        ext = 'mp4';
        folder = 'Movies';
      }

      final fileName = '${_videoInfo!.title}.$ext';
      
      final path = await _downloadHelper.downloadStream(
        streamInfo.url.toString(),
        fileName,
        folder,
        (received, total) {
          if (total != -1) {
            setState(() {
              _progress = received / total;
              _statusMessage = '%${(_progress * 100).toStringAsFixed(1)} İndiriliyor...';
            });
          }
        },
      );

      setState(() {
        _isLoading = false;
        _statusMessage = 'Tamamlandı! Kaydedildi: $path';
        _progress = 1.0;
      });

    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Hata: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('YouTube İndirici'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'YouTube Linki Yapıştır',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _fetchInfo,
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              LinearProgressIndicator(value: _progress > 0 ? _progress : null),
            if (_videoInfo != null) ...[
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        _videoInfo!.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text('Yazar: ${_videoInfo!.author}'),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Video"),
                          Switch(
                            value: _isAudio,
                            onChanged: (val) {
                              setState(() {
                                _isAudio = val;
                              });
                            },
                          ),
                          const Text("Müzik (MP3)"),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _isLoading ? null : _startDownload,
                        icon: const Icon(Icons.download),
                        label: const Text('İndir'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _statusMessage.startsWith('Hata') ? Colors.red : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

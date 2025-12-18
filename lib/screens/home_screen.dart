import 'dart:async';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
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

  StreamSubscription? _intentSub;
  
  bool _isLoading = false;
  String _statusMessage = '';
  double _progress = 0.0;
  
  // Single Video State
  Video? _videoInfo;
  
  // Playlist State
  List<Video>? _playlistVideos;
  Set<String> _selectedVideoIds = {};

  @override
  void initState() {
    super.initState();
    _initSharingListener();
  }

  void _initSharingListener() {
    // For sharing or opening while app is running
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _handleSharedText(value.first.path);
      }
    }, onError: (err) {
      debugPrint("Sharing error: $err");
    });

    // For sharing when app is closed
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _handleSharedText(value.first.path);
      }
    });
  }

  void _handleSharedText(String text) {
    // Shared text often comes as a path or direct text
    // We just take it and put it in the URL box
    _urlController.text = text;
    _fetchInfo();
  }

  @override
  void dispose() {
    _intentSub?.cancel();
    _ytService.dispose();
    super.dispose();
  }

  Future<void> _fetchInfo() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Bilgiler alınıyor...';
      _videoInfo = null;
      _playlistVideos = null;
      _selectedVideoIds.clear();
      _progress = 0.0;
    });

    try {
      // Check if it is a playlist
      if (url.contains('list=')) {
        final videos = await _ytService.getPlaylistVideos(url);
        setState(() {
          _playlistVideos = videos;
          _statusMessage = 'Playlist Bulundu: ${videos.length} Video';
        });
      } else {
        // Single video
        final video = await _ytService.getVideoInfo(url);
        setState(() {
          _videoInfo = video;
          _statusMessage = 'Video Bulundu: ${video.title}';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Hata: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showQualityDialog(Video video) async {
    // Fetch manifest first to see options
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(child: CircularProgressIndicator()),
      );

      final manifest = await _ytService.getManifest(video.id.value);
      Navigator.pop(context); // Close loading

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        builder: (context) {
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Format ve Kalite Seçin", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  const Divider(),
                  const Text("Ses (Müzik)", style: TextStyle(fontWeight: FontWeight.bold)),
                  ...manifest.audioOnly.sortByBitrate().reversed.take(3).map((audio) {
                     return ListTile(
                       leading: const Icon(Icons.music_note),
                       title: Text("MP3 / Audio (${(audio.bitrate.bitsPerSecond / 1000).ceil()} kbps)"),
                       subtitle: Text("${(audio.size.totalBytes / 1024 / 1024).toStringAsFixed(1)} MB"),
                       onTap: () {
                         Navigator.pop(context);
                         _downloadContent(video, audio, 'Music', 'mp3');
                       },
                     );
                  }),
                  const Divider(),
                  const Text("Video", style: TextStyle(fontWeight: FontWeight.bold)),
                  ...manifest.muxed.sortByVideoQuality().reversed.take(3).map((videoStream) {
                    return ListTile(
                      leading: const Icon(Icons.videocam),
                      title: Text("MP4 / ${videoStream.videoQualityLabel}"),
                      subtitle: Text("${(videoStream.size.totalBytes / 1024 / 1024).toStringAsFixed(1)} MB"),
                      onTap: () {
                        Navigator.pop(context);
                        _downloadContent(video, videoStream, 'Movies', 'mp4');
                      },
                    );
                  }),
                ],
              ),
            ),
          );
        },
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Kalite bilgisi alınamadı: $e")));
    }
  }

  Future<void> _downloadContent(Video video, StreamInfo streamInfo, String folder, String ext) async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'İndirme Başlıyor: ${video.title}';
    });

    try {
       final hasPermission = await _downloadHelper.requestPermission();
       if (!hasPermission) throw Exception("İzin verilmedi");

       final stream = _ytService.getStream(streamInfo);
       final fileName = '${video.title}.$ext';

       await _downloadHelper.downloadStream(
         stream,
         streamInfo.size.totalBytes,
         fileName,
         folder,
         (received, total) {
           if (total != -1) {
             setState(() {
                _progress = received / total;
                _statusMessage = '%${(_progress * 100).toStringAsFixed(0)} İndiriliyor...';
             });
           }
         },
       );
       
       setState(() {
         _statusMessage = 'İndirme Tamamlandı!';
         _progress = 1.0;
       });

    } catch (e) {
      setState(() {
        _statusMessage = 'Hata: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Batch download logic for playlist
  Future<void> _downloadSelectedPlaylist() async {
    if (_playlistVideos == null || _selectedVideoIds.isEmpty) return;
    
    // Default to highest quality audio for batch download to keep it simple
    // Or we could ask once. Lets assume Audio (Music) for playlist is the most common use case.
    // Making it explicit: Auto-download as High Quality MP3
    
    int successCount = 0;
    int failCount = 0;
    int current = 0;
    int total = _selectedVideoIds.length;

    for (var video in _playlistVideos!) {
      if (!_selectedVideoIds.contains(video.id.value)) continue;

      current++;
      setState(() {
        _statusMessage = 'Liste İndiriliyor ($current/$total): ${video.title}';
        _progress = 0.0;
      });

      try {
        final manifest = await _ytService.getManifest(video.id.value);
        final audioStream = manifest.audioOnly.withHighestBitrate();
        
        final hasPermission = await _downloadHelper.requestPermission();
        if(!hasPermission) throw Exception("İzin yok");

        final stream = _ytService.getStream(audioStream);
        await _downloadHelper.downloadStream(
           stream, 
           audioStream.size.totalBytes, 
           '${video.title}.mp3', 
           'Music', 
           (r, t) {
             // Individual progress could be shown, but maybe simpler just X/Y
           }
        );
        successCount++;
      } catch (e) {
        failCount++;
        debugPrint("List download error: $e");
      }
    }

    setState(() {
      _isLoading = false;
      _statusMessage = 'Bitti! $successCount başarılı, $failCount hatalı.';
      _progress = 1.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('YT Pro İndirici')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: 'YouTube Linki (Video veya Playlist)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: _isLoading ? null : _fetchInfo,
                )
              ],
            ),
          ),
          if (_isLoading) LinearProgressIndicator(value: _progress > 0 ? _progress : null),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(_statusMessage, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_playlistVideos != null) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.download_for_offline),
              label: Text("Seçilenleri İndir (${_selectedVideoIds.length}) - MP3"),
              onPressed: _isLoading || _selectedVideoIds.isEmpty ? null : _downloadSelectedPlaylist,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _playlistVideos!.length,
              itemBuilder: (context, index) {
                final video = _playlistVideos![index];
                final isSelected = _selectedVideoIds.contains(video.id.value);
                return CheckboxListTile(
                  title: Text(video.title),
                  subtitle: Text(video.author),
                  value: isSelected,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedVideoIds.add(video.id.value);
                      } else {
                        _selectedVideoIds.remove(video.id.value);
                      }
                    });
                  },
                );
              },
            ),
          ),
        ],
      );
    } else if (_videoInfo != null) {
      return Center(
        child: Card(
          margin: const EdgeInsets.all(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_videoInfo!.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 10),
                Text(_videoInfo!.author),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(minimumSize: const Size(200, 50)),
                  icon: const Icon(Icons.download),
                  label: const Text("İndirme Seçenekleri"),
                  onPressed: _isLoading ? null : () => _showQualityDialog(_videoInfo!),
                )
              ],
            ),
          ),
        ),
      );
    } else {
      return const Center(child: Text("Link yapıştırın veya 'Paylaş' diyerek uygulamayı açın."));
    }
  }
}

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class YouTubeService {
  final _yt = YoutubeExplode();

  Future<Video> getVideoInfo(String url) async {
    try {
      return await _yt.videos.get(url);
    } catch (e) {
      throw Exception('Video bulunamadı: $e');
    }
  }

  Future<StreamManifest> getManifest(String videoId) async {
    return await _yt.videos.streamsClient.getManifest(videoId);
  }

  void dispose() {
    _yt.close();
  }
}

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

  Stream<List<int>> getStream(StreamInfo streamInfo) {
    return _yt.videos.streamsClient.get(streamInfo);
  }

  Future<List<Video>> getPlaylistVideos(String url) async {
    try {
      final playlist = await _yt.playlists.get(url);
      // Get all videos (limit to first 50 for performance if needed, but fetch logic handles pagination)
      // await for is needed because getVideos returns a Stream
      final videos = <Video>[];
      await for (final video in _yt.playlists.getVideos(playlist.id)) {
        videos.add(video);
      }
      return videos;
    } catch (e) {
      throw Exception('Playlist bulunamadı: $e');
    }
  }

  void dispose() {
    _yt.close();
  }
}

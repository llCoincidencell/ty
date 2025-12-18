import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class DownloadHelper {
  final Dio _dio = Dio();

  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      // Android 13+ support could be tricky with just storage perms
      // simple implementation for now
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }
      
      // For Android 13+ (Images/Video/Audio specific perms)
      if (await Permission.videos.status.isDenied) {
        await Permission.videos.request();
      }
      if (await Permission.audio.status.isDenied) {
        await Permission.audio.request();
      }

      return status.isGranted || await Permission.manageExternalStorage.isGranted || await Permission.videos.isGranted;
    } else {
      // iOS usually saves to app docs or photos lib
      return true; 
    }
  }

  Future<String> downloadStream(String url, String fileName, String folderType, Function(int, int) onProgress) async {
    try {
      Directory? directory;
      if (Platform.isAndroid) {
         // Direct path to public Downloads or Music folder for easier access
         // Note: Scoped Storage might strict this, but standard Downloads is usually safe
         directory = Directory('/storage/emulated/0/$folderType');
         if (!await directory.exists()) {
           directory = await getExternalStorageDirectory(); // Fallback to app data
         }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) throw Exception("Depolama alanı bulunamadı");

      // Clean filename
      final cleanName = fileName.replaceAll(RegExp(r'[^\w\s\.]+'), '');
      final savePath = '${directory.path}/$cleanName';

      await _dio.download(
        url,
        savePath,
        onReceiveProgress: onProgress,
      );

      return savePath;
    } catch (e) {
      throw Exception('İndirme hatası: $e');
    }
  }
}

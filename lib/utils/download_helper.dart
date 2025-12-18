import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class DownloadHelper {


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

  Future<String> downloadStream(
      Stream<List<int>> stream, 
      int totalBytes, 
      String fileName, 
      String folderType, 
      Function(int, int) onProgress) async {
    try {
      Directory? directory;
      if (Platform.isAndroid) {
         directory = Directory('/storage/emulated/0/$folderType');
         if (!await directory.exists()) {
           directory = await getExternalStorageDirectory(); 
         }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) throw Exception("Depolama alanı bulunamadı");

      // Clean filename
      final cleanName = fileName.replaceAll(RegExp(r'[^\w\s\.]+'), '');
      final savePath = '${directory.path}/$cleanName';
      final file = File(savePath);

      final fileSink = file.openWrite();
      
      int receivedBytes = 0;
      await for (final chunk in stream) {
        fileSink.add(chunk);
        receivedBytes += chunk.length;
        onProgress(receivedBytes, totalBytes);
      }
      
      await fileSink.flush();
      await fileSink.close();

      return savePath;
    } catch (e) {
      throw Exception('İndirme hatası: $e');
    }
  }
}

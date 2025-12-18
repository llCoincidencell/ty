import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class DownloadHelper {


  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      // Android 13+ support could be tricky with just storage perms
      // simple implementation for now
      // Android 11+ (API 30+) requires MANAGE_EXTERNAL_STORAGE for direct access to public folders
      if (await Permission.manageExternalStorage.status.isDenied) {
        await Permission.manageExternalStorage.request();
      }
      
      // Check legacy permission
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }
      
      // Android 13+ media permissions (granular)
      if (await Permission.videos.status.isDenied) await Permission.videos.request();
      if (await Permission.audio.status.isDenied) await Permission.audio.request();

      return await Permission.manageExternalStorage.isGranted || status.isGranted || await Permission.videos.isGranted;
    } else {
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
         // Try public folder first
         directory = Directory('/storage/emulated/0/$folderType');
         // If we can't write there (no permission), fallback to app-specific storage
         try {
           if (!await directory.exists()) {
             await directory.create(recursive: true);
           }
           // Test write access
           final testFile = File('${directory.path}/test_write');
           await testFile.writeAsString('test');
           await testFile.delete();
         } catch (e) {
           // Fallback if public folder is not accessible
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

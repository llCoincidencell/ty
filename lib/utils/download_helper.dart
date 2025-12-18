import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class DownloadHelper {


  Future<bool> requestPermission() async {
    // We will use app-specific storage which doesn't strictly need permission on many Android versions,
    // but asking for it helps for some legacy devices.
    if (Platform.isAndroid) {
      // Just ask basics, don't block logic if denied
      await Permission.storage.request(); 
      await Permission.manageExternalStorage.request();
    }
    return true; // Always return true to attempt download in safe folder
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
         // USE SAFE FOLDER (Android/data/...) to guarantee write access without permission hell
         directory = await getExternalStorageDirectory(); 
         // Optional: Try to create a 'YT_Downloads' subfolder
         if (directory != null) {
            String newPath = directory.path.split('Android')[0] + 'Download'; 
            // Try accessing public Download folder as best effort
            final publicDir = Directory(newPath);
            if (await publicDir.exists()) {
               // Try writing a test file to see if we really can
               try {
                 final t = File('${publicDir.path}/test_permission');
                 await t.writeAsString('k');
                 await t.delete();
                 directory = publicDir; // Success! Use public folder
               } catch (e) {
                 // Ignore, fallback to safe directory
               }
            }
         }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) throw Exception("Depolama alanı bulunamadı");

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

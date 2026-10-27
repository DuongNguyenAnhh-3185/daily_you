// Copyright (C) 2026 Demizo and contributors
// SPDX-License-Identifier: GPL-3.0-only
// Additional terms under GPLv3 section 7 apply; see ADDITIONAL_TERMS.md.

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:daily_you/utils/cancellation_token.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';

class ZipUtils {
  static Future<void> compress(
      String outputFile, List<String> inputFiles, List<String> inputFolders,
      {Map<String, String> filesByArchivePath = const {},
      Function(double percent)? onProgress,
      CancellationToken? cancellationToken}) async {
    if (cancellationToken?.isCancelled ?? false) {
      throw BackupCancelledException();
    }

    var rxPort = ReceivePort();
    var completer = Completer<void>();
    SendPort? cancelPort;

    rxPort.listen((data) {
      if (data is SendPort) {
        cancelPort = data;
        if (cancellationToken?.isCancelled ?? false) cancelPort!.send(true);
      } else if (data is String && data == _encodeArchiveDone) {
        if (!completer.isCompleted) {
          if (cancellationToken?.isCancelled ?? false) {
            completer.completeError(BackupCancelledException());
          } else {
            completer.complete();
          }
        }
      } else if (data == _encodeArchiveCancelled) {
        if (!completer.isCompleted) {
          completer.completeError(BackupCancelledException());
        }
      } else if (data is String) {
        if (!completer.isCompleted) completer.completeError(Exception(data));
      } else {
        onProgress?.call(data);
      }
    });

    final exitPort = ReceivePort();
    final exited = exitPort.first;
    final isolate = await Isolate.spawn(
        encodeArchive,
        {
          "outputFile": outputFile,
          "inputFiles": inputFiles,
          "inputFolders": inputFolders,
          "filesByArchivePath": filesByArchivePath,
          "port": rxPort.sendPort,
        },
        onExit: exitPort.sendPort);

    cancellationToken?.attachNativeCancel(() => cancelPort?.send(true));

    try {
      await completer.future;
    } finally {
      cancellationToken?.detach();
      rxPort.close();
      isolate.kill(priority: Isolate.immediate);
      await exited;
      exitPort.close();
    }
  }

  static Future<void> extract(String inputFile, String outputFolder,
      {Function(double percent)? onProgress}) async {
    var rxPort = ReceivePort();

    rxPort.listen((data) {
      if (onProgress != null) {
        onProgress(data);
      }
    });

    await compute(decodeArchive, {
      "inputFile": inputFile,
      "outputFolder": outputFolder,
      "port": rxPort.sendPort,
    });

    rxPort.close();
  }

  static const _encodeArchiveDone = 'done';
  static const _encodeArchiveCancelled = 'cancelled';

  static Future<void> encodeArchive(Map<String, dynamic> args) async {
    SendPort sendPort = args["port"];
    final cancelPort = ReceivePort();
    var cancelled = false;
    cancelPort.listen((_) => cancelled = true);
    sendPort.send(cancelPort.sendPort);
    void checkCancelled() {
      if (cancelled) throw BackupCancelledException();
    }

    final encoder = ZipFileEncoder();
    var outcome = _encodeArchiveDone;
    try {
      encoder.createWithStream(OutputFileStream(args["outputFile"]));
      for (final String file in args["inputFiles"]) {
        checkCancelled();
        await _addStored(encoder, File(file), basename(file));
      }

      final List<String> folders = args["inputFolders"];
      final Map<String, String> filesByArchivePath = args["filesByArchivePath"];
      final folderFiles = [for (final folder in folders) _filesIn(folder)];
      final folderBytes = [for (final files in folderFiles) _sizeOf(files)];
      final fileBytes = [
        for (final path in filesByArchivePath.values) File(path).lengthSync()
      ];
      final totalBytes =
          [...folderBytes, ...fileBytes].fold(0, (a, b) => a + b);
      var finishedBytes = 0;
      void report(double fraction, int bytes) {
        if (totalBytes > 0) {
          sendPort.send((finishedBytes + fraction * bytes) / totalBytes * 100);
        }
      }

      for (final (index, folder) in folders.indexed) {
        await _addFolder(encoder, folder, folderFiles[index],
            (fraction) => report(fraction, folderBytes[index]), checkCancelled);
        finishedBytes += folderBytes[index];
        report(0, 0);
      }
      for (final (index, entry) in filesByArchivePath.entries.indexed) {
        checkCancelled();
        await _addStored(encoder, File(entry.value), entry.key);
        finishedBytes += fileBytes[index];
        report(0, 0);
      }
      checkCancelled();
    } on BackupCancelledException {
      outcome = _encodeArchiveCancelled;
    } catch (error) {
      outcome = error.toString();
    } finally {
      try {
        await encoder.close();
      } catch (error) {
        outcome = error.toString();
      }
      cancelPort.close();
    }
    sendPort.send(outcome);
  }

  static Future<void> _addFolder(
      ZipFileEncoder encoder,
      String folder,
      List<File> files,
      void Function(double fraction) onProgress,
      void Function() checkCancelled) async {
    for (final (index, file) in files.indexed) {
      checkCancelled();
      final relativeParts = split(relative(file.path, from: folder));
      await _addStored(
          encoder, file, posix.joinAll([basename(folder), ...relativeParts]));
      onProgress((index + 1) / files.length);
    }
  }

  // ZipFileEncoder.addFile deflates into memory even at level 0.
  static Future<void> _addStored(
      ZipFileEncoder encoder, File file, String archivePath) async {
    final stat = await file.stat();
    final stream = InputFileStream(file.path);
    try {
      encoder.addArchiveFile(ArchiveFile.stream(archivePath, stream)
        ..compression = CompressionType.none
        ..lastModTime = stat.modified.millisecondsSinceEpoch ~/ 1000
        ..mode = stat.mode);
    } finally {
      await stream.close();
    }
  }

  static List<File> _filesIn(String folder) =>
      Directory(folder).listSync(recursive: true).whereType<File>().toList();

  static int _sizeOf(List<File> files) =>
      files.fold(0, (bytes, file) => bytes + file.lengthSync());

  static String _pathInside(String outputFolder, String entryName) {
    // Fix for Zip encodings that place / at the start of files paths.
    // All Zip paths should be relative
    final relativeName =
        entryName.startsWith('/') ? entryName.substring(1) : entryName;
    final resolved = join(outputFolder, relativeName);
    if (!isWithin(outputFolder, resolved)) {
      throw FormatException(
          'Archive entry escapes the output folder', entryName);
    }
    return resolved;
  }

  static Future<void> decodeArchive(Map<String, dynamic> args) async {
    SendPort sendPort = args["port"];
    final input = InputFileStream(args["inputFile"]);
    try {
      var decoder = ZipDecoder().decodeStream(input);

      // Track number of files for progress indication
      var totalFileCount = decoder.numberOfFiles();
      var processedFileCount = 0;

      for (final entry in decoder) {
        if (entry.isFile) {
          final file = File(_pathInside(args["outputFolder"], entry.name));
          await file.create(recursive: true);
          final output = OutputFileStream(file.path);
          try {
            entry.writeContent(output);
          } finally {
            await output.close();
          }

          // Updates status
          processedFileCount += 1;
          sendPort.send((processedFileCount / totalFileCount) * 100);
        } else {
          await Directory(_pathInside(args["outputFolder"], entry.name))
              .create(recursive: true);
        }
      }
    } finally {
      await input.close();
    }
  }
}

// Copyright (C) 2026 contributors
// SPDX-License-Identifier: GPL-3.0-only
import 'dart:io';
import 'package:daily_you/widgets/local_image_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

void main() {
  late Directory work;
  setUp(() async =>
      work = await Directory.systemTemp.createTemp('thumbnail_test'));
  tearDown(() => work.delete(recursive: true));

  test('desktop thumbnails decode the bundled WebP welcome image', () async {
    final target = p.join(work.path, 'preview.jpg');
    await resizeDesktopImage('assets/daily_you_First_Steps.webp', target, 100);
    final thumbnail = img.decodeJpg(await File(target).readAsBytes());
    expect(thumbnail, isNotNull);
    expect(thumbnail!.width, 100);
    expect(thumbnail.height, greaterThan(100));
  });

  test('desktop thumbnails decode PNG attachments', () async {
    final source = p.join(work.path, 'photo.png');
    final target = p.join(work.path, 'preview.jpg');
    await File(source)
        .writeAsBytes(img.encodePng(img.Image(width: 80, height: 60)));
    await resizeDesktopImage(source, target, 40);
    final thumbnail = img.decodeJpg(await File(target).readAsBytes());
    expect(thumbnail?.width, 40);
    expect(thumbnail?.height, 30);
  });
}

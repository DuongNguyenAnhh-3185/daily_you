import 'dart:convert';
import 'dart:io';

import 'package:daily_you/config_provider.dart';
import 'package:daily_you/custom_locale_delegates.dart';
import 'package:daily_you/l10n/generated/app_localizations.dart';
import 'package:daily_you/widgets/color_picker_dialog.dart';
import 'package:daily_you/widgets/stats_overview_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../support/config_provider_harness.dart';

void main() {
  useTemporaryConfig();

  test('Vietnamese covers all messages and preserves every argument', () {
    final en =
        jsonDecode(File('lib/l10n/intl_en.arb').readAsStringSync()) as Map;
    final vi =
        jsonDecode(File('lib/l10n/intl_vi.arb').readAsStringSync()) as Map;
    final arguments = RegExp(r'\{(\w+)(?=[,}])');
    for (final key in en.keys.where((k) => !k.startsWith('@'))) {
      expect(vi[key], isA<String>(), reason: key);
      Set<String> names(String s) =>
          arguments.allMatches(s).map((m) => m[1]!).toSet();
      expect(names(vi[key]), names(en[key]), reason: key);
      expect((vi[key] as String).contains('\uFFFD'), isFalse, reason: key);
    }
  });

  test('a fresh installation uses Vietnamese and a 24 hour clock', () async {
    await initializeDateFormatting();
    expect(ConfigProvider.instance.getOverrideLanguage(), const Locale('vi'));
    expect(ConfigProvider.instance.is24HourFormat(), isTrue);
    expect(DateFormat.yMd('vi').format(DateTime(2026, 10, 24)), '24/10/2026');
  });

  test('Vietnamese count messages handle zero and multiple entries', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('vi'));
    expect(l10n.logCount(0), '0 bài nhật ký');
    expect(l10n.logCount(12), '12 bài nhật ký');
    expect(l10n.flashbackWeek(2), '2 tuần trước');
    expect(l10n.deleteTagMessage(0, 'Biết ơn'), 'Xóa "Biết ơn"?');
    expect(l10n.deleteTagMessage(3, 'Biết ơn'), contains('3 bài nhật ký'));
    expect(l10n.creatingBackupStatus('25'), 'Đang tạo bản sao lưu… 25%');
  });

  Widget app(Widget child) => MaterialApp(
        locale: const Locale('vi'),
        localizationsDelegates: [
          AppLocalizations.delegate,
          ...appLocalizationsDelegates
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      );

  testWidgets(
      'Vietnamese color dialog fits a narrow phone and confirms a color',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ColorPickerResult? result;
    await tester.pumpWidget(app(Builder(
        builder: (context) => TextButton(
              onPressed: () async {
                result = await showDialog<ColorPickerResult>(
                    context: context,
                    builder: (_) =>
                        const ColorPickerDialog(initialColor: Colors.blue));
              },
              child: const Text('Mở'),
            ))));
    await tester.tap(find.text('Mở'));
    await tester.pumpAndSettle();
    expect(find.text('Chọn màu'), findsOneWidget);
    expect(find.text('Bảng màu'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final context = tester.element(find.byType(ColorPickerDialog));
    await tester
        .tap(find.text(MaterialLocalizations.of(context).okButtonLabel));
    await tester.pumpAndSettle();
    expect(result?.color, Colors.blue);
  });
  testWidgets('statistics preserve Vietnamese word order around the number',
      (tester) async {
    await tester.pumpWidget(app(const StatsOverviewCard(
      sideItems: [
        StatItem(icon: Icons.history, title: 'Chuỗi dài nhất: 12 ngày')
      ],
      writingItems: [
        StatItem(icon: Icons.description, title: '12 bài nhật ký')
      ],
    )));
    await tester.pumpAndSettle();
    expect(find.text('Chuỗi dài nhất: 12 ngày', findRichText: true),
        findsOneWidget);
    expect(find.text('12 bài nhật ký', findRichText: true), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

import 'package:brownpaw/domain/flow_status.dart';
import 'package:brownpaw/theme/app_theme.dart';
import 'package:brownpaw/theme/flow_status_style.dart';
import 'package:brownpaw/widgets/flow_status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child, {ThemeData? theme}) => MaterialApp(
    theme: theme ?? AppTheme.lightTheme,
    home: Scaffold(body: Center(child: child)),
  );

  for (final status in FlowStatus.values) {
    testWidgets('${status.name} shows its word and icon', (tester) async {
      await tester.pumpWidget(host(FlowStatusChip(status: status)));
      expect(find.text(status.label), findsOneWidget);
      expect(find.byIcon(status.icon), findsOneWidget);
      expect(
        find.bySemanticsLabel('Flow status: ${status.label}'),
        findsOneWidget,
      );
    });
  }

  testWidgets('uses the theme colours in light and dark mode', (tester) async {
    late Color light;
    late Color dark;
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) {
            light = FlowStatus.medium.color(context);
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) {
            dark = FlowStatus.medium.color(context);
            return const SizedBox();
          },
        ),
        theme: AppTheme.darkTheme,
      ),
    );
    // MaterialApp animates between themes; let it finish.
    await tester.pumpAndSettle();
    expect(light, FlowStatusColors.light.medium);
    expect(dark, FlowStatusColors.dark.medium);
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wisplit_client/main.dart';

void main() {
  testWidgets('WiSplit app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: WiSplitApp()));
    expect(find.text('WiSplit'), findsOneWidget);
  });
}

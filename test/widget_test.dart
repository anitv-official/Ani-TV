import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:anitv/main.dart';
import 'package:anitv/providers/app_state_provider.dart';

void main() {
  testWidgets('AniTV renders the application shell', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppStateProvider(),
        child: const MyApp(),
      ),
    );
    expect(find.byType(MyApp), findsOneWidget);
  });
}

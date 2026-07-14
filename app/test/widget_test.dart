import 'package:flutter_test/flutter_test.dart';
import 'package:plant_it_helper/main.dart';

void main() {
  testWidgets('app starts and shows login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const PlantItApp());
    expect(find.text('PlantIt Helper'), findsOneWidget);
    expect(find.text('Sign in to your account'), findsOneWidget);
  });
}

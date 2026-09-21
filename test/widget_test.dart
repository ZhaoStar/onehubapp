import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:onehubapp/main.dart';

void main() {
  testWidgets('shows login page', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    // 登录页启动时会读安全存储里的令牌，这里给出内存实现
    FlutterSecureStorage.setMockInitialValues({});

    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(3));
    expect(find.byType(Checkbox), findsOneWidget);
  });
}

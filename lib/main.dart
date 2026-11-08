import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'presentation/viewmodels/app_viewmodel.dart';
import 'presentation/views/auth/login_view.dart';
import 'presentation/views/main_shell/main_shell_view.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    final settings = settingsAsync.value;
    final themeColor = settings?.themeColor ?? const Color(0xFF3F51B5);

    return MaterialApp(
      title: 'My Life Planner',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(themeColor),
      home: const _AuthGate(),
    );
  }
}

/// 로그인 여부에 따라 화면 분기
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authProvider);

    return authAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const LoginView(),
      data: (account) =>
          account == null ? const LoginView() : const MainShellView(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../viewmodels/app_viewmodel.dart';
import '../../../core/utils/app_timezone.dart';
import '../../widgets/settings/settings_drawer.dart';
import '../calendar/calendar_view.dart';
import '../tasks/tasks_view.dart';
import '../life_goal/life_goal_view.dart';

/// 메인 쉘 — BottomNavigationBar + Drawer
class MainShellView extends ConsumerWidget {
  const MainShellView({super.key});

  static const _pages = [
    TasksView(),
    CalendarScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navIndex = ref.watch(navIndexProvider);
    final settings = ref.watch(settingsProvider).value;
    final isKo = settings?.language != 'en';
    final today = nowInTimezone(settings?.timezone ?? 'Asia/Seoul');

    return Scaffold(
      appBar: AppBar(
        // 햄버거 메뉴 — Drawer.of()를 쓰기 위해 Builder 필요
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: isKo ? '설정' : 'Settings',
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Text(
          isKo ? '${today.month}월 ${today.day}일' : _monthLabel(today),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          // 3-dot 메뉴 → Life Goal 이동
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              if (v == 'lifegoal') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LifeGoalView()),
                );
              } else if (v == 'signout') {
                ref.read(authProvider.notifier).signOut();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'lifegoal',
                child: ListTile(
                  leading: const Icon(Icons.flag_rounded),
                  title: Text(isKo ? 'Life Goal' : 'Life Goal'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'signout',
                child: ListTile(
                  leading: const Icon(Icons.logout),
                  title: Text(isKo ? '로그아웃' : 'Sign Out'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      drawer: const SettingsDrawer(),
      body: IndexedStack(
        index: navIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navIndex,
        onDestinationSelected: (i) =>
            ref.read(navIndexProvider.notifier).setIndex(i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.checklist_outlined),
            selectedIcon: const Icon(Icons.checklist),
            label: isKo ? '할 일' : 'Tasks',
          ),
          NavigationDestination(
            icon: _CalendarIcon(day: today.day, selected: false),
            selectedIcon: _CalendarIcon(day: today.day, selected: true),
            label: isKo ? '캘린더' : 'Calendar',
          ),
        ],
      ),
    );
  }

  String _monthLabel(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }
}

/// 오늘 날짜가 표시되는 캘린더 아이콘
class _CalendarIcon extends StatelessWidget {
  final int day;
  final bool selected;
  const _CalendarIcon({required this.day, required this.selected});

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(
          selected ? Icons.calendar_month : Icons.calendar_month_outlined,
          color: color,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '$day',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

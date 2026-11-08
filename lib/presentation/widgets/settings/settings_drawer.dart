import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/app_settings_model.dart';
import '../../viewmodels/app_viewmodel.dart';

/// 앱 설정 Drawer (햄버거 메뉴 패널)
class SettingsDrawer extends ConsumerWidget {
  const SettingsDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    final settings = settingsAsync.value ?? const AppSettingsModel();
    final notifier = ref.read(settingsProvider.notifier);

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            // ── 헤더 ──
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                '⚙️  설정',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(),

            // ── 1. 테마 색상 (3×3) ──
            const _SectionLabel('테마 색상'),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.5,
              ),
              itemCount: AppThemeColors.palette.length,
              itemBuilder: (ctx, i) {
                final item = AppThemeColors.palette[i];
                final selected = settings.themeColor.toARGB32() == item.color.toARGB32();
                return GestureDetector(
                  onTap: () => notifier.setThemeColor(item.color),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: item.color,
                      borderRadius: BorderRadius.circular(10),
                      border: selected
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                      boxShadow: selected
                          ? [BoxShadow(color: item.color.withAlpha(130), blurRadius: 8, spreadRadius: 2)]
                          : [],
                    ),
                    alignment: Alignment.center,
                    child: selected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : Text(
                            item.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            const Divider(),

            // ── 2. 첫 요일 ──
            const _SectionLabel('주의 첫 번째 날'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(settings.startOnSunday ? '일요일 시작' : '월요일 시작'),
              subtitle: Text(settings.startOnSunday
                  ? '달력이 일요일부터 시작됩니다'
                  : '달력이 월요일부터 시작됩니다'),
              value: settings.startOnSunday,
              activeThumbColor: settings.themeColor,
              onChanged: (v) => notifier.setStartOnSunday(v),
            ),
            const Divider(),

            // ── 3. 타임존 ──
            const _SectionLabel('타임존'),
            DropdownButtonFormField<String>(
              initialValue: settings.timezone,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: _timezones.map((tz) {
                return DropdownMenuItem(value: tz, child: Text(tz, overflow: TextOverflow.ellipsis));
              }).toList(),
              onChanged: (v) {
                if (v != null) notifier.setTimezone(v);
              },
            ),
            const SizedBox(height: 20),
            const Divider(),

            // ── 4. 언어 ──
            const _SectionLabel('언어'),
            Row(
              children: [
                _LangChip(
                  label: '한국어',
                  value: 'ko',
                  selected: settings.language == 'ko',
                  themeColor: settings.themeColor,
                  onTap: () => notifier.setLanguage('ko'),
                ),
                const SizedBox(width: 8),
                _LangChip(
                  label: 'English',
                  value: 'en',
                  selected: settings.language == 'en',
                  themeColor: settings.themeColor,
                  onTap: () => notifier.setLanguage('en'),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _LangChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final Color themeColor;
  final VoidCallback onTap;

  const _LangChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.themeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? themeColor : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? themeColor : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

const List<String> _timezones = [
  'Asia/Seoul',
  'Asia/Tokyo',
  'Asia/Shanghai',
  'Asia/Singapore',
  'Asia/Hong_Kong',
  'Asia/Taipei',
  'Asia/Bangkok',
  'Asia/Jakarta',
  'Asia/Kolkata',
  'Asia/Dubai',
  'Europe/London',
  'Europe/Paris',
  'Europe/Berlin',
  'Europe/Moscow',
  'America/New_York',
  'America/Chicago',
  'America/Denver',
  'America/Los_Angeles',
  'America/Sao_Paulo',
  'Pacific/Auckland',
  'Pacific/Sydney',
  'UTC',
];

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:desperrengue_app/core/models/achievements.dart';
import 'package:desperrengue_app/core/ui/profile_and_achievement_emblems.dart';

void main() {
  testWidgets(
    'Fetch Iconify SVGs for Profile Menus & Achievements and render high-res showcase',
    (WidgetTester tester) async {
      final outDir = Directory('assets/achievement_and_profile_logos');
      if (!outDir.existsSync()) {
        outDir.createSync(recursive: true);
      }

      final manifestEntries = <Map<String, dynamic>>[];

      // 1. Fetch Profile Menu SVGs from Iconify REST API
      await tester.runAsync(() async {
        final client = http.Client();
        try {
          for (final item in ProfileMenuIconKind.values) {
            final parts = item.iconifyId.split(':');
            final prefix = parts.first;
            final name = parts.last;
            final url = Uri.parse('https://api.iconify.design/$prefix/$name.svg');
            String svgContent = '';
            try {
              final resp = await client.get(url).timeout(const Duration(seconds: 8));
              if (resp.statusCode == 200 && resp.body.contains('<svg')) {
                svgContent = resp.body;
              }
            } catch (_) {}

            final fileName = 'profile_${item.id}_$name.svg';
            if (svgContent.isNotEmpty) {
              File('${outDir.path}/$fileName').writeAsStringSync(svgContent);
            }
            manifestEntries.add({
              'type': 'profile_menu',
              'id': item.id,
              'label': item.label,
              'iconifyId': item.iconifyId,
              'primaryHex': '#${item.primaryColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
              'secondaryHex': '#${item.secondaryColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
              'svgFile': fileName,
              'fetchedFromIconify': svgContent.isNotEmpty,
            });
          }

          // 2. Fetch Achievement Track SVGs (Base + Evolved) from Iconify REST API
          for (final spec in kAchievementTrackVisualSpecs) {
            for (final (kind, iconId) in [('base', spec.baseIconifyId), ('evolved', spec.evolvedIconifyId)]) {
              final parts = iconId.split(':');
              final prefix = parts.first;
              final name = parts.last;
              final url = Uri.parse('https://api.iconify.design/$prefix/$name.svg');
              String svgContent = '';
              try {
                final resp = await client.get(url).timeout(const Duration(seconds: 8));
                if (resp.statusCode == 200 && resp.body.contains('<svg')) {
                  svgContent = resp.body;
                }
              } catch (_) {}

              final fileName = 'ach_${spec.code}_${kind}_$name.svg';
              if (svgContent.isNotEmpty) {
                File('${outDir.path}/$fileName').writeAsStringSync(svgContent);
              }
              manifestEntries.add({
                'type': 'achievement_track_$kind',
                'code': spec.code,
                'name': spec.name,
                'isClient': spec.isClient,
                'iconifyId': iconId,
                'primaryHex': '#${spec.primaryColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                'secondaryHex': '#${spec.secondaryColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                'svgFile': fileName,
                'fetchedFromIconify': svgContent.isNotEmpty,
              });
            }
          }
        } finally {
          client.close();
        }
      });

      File('${outDir.path}/manifest.json').writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          'generatedAt': DateTime.now().toIso8601String(),
          'profileIconsCount': ProfileMenuIconKind.values.length,
          'achievementTracksCount': kAchievementTrackVisualSpecs.length,
          'entries': manifestEntries,
        }),
      );

      // 3. Render High-Resolution Showcase Sheet (1200x2200)
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const width = 1200.0;
      const height = 2250.0;

      // Background Dark Quiet Luxury
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, width, height),
        Paint()..color = const Color(0xFF0B111E),
      );

      // Render via widget tree offscreen capture
      tester.view.physicalSize = const Size(width, height);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          home: Scaffold(
            backgroundColor: const Color(0xFF0B111E),
            body: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DESPERRENGUE — FORJA DE MEDALHAS (#CBD5E1 BLOQUEADO vs. EVOLUÇÃO COLORIDA) & ÍCONES DE PERFIL',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '1. ÍCONES DUOTONE DOS MENUS DE PERFIL (CLIENTE & PROFISSIONAL)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF38BDF8)),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 14,
                    runSpacing: 12,
                    children: [
                      for (final kind in ProfileMenuIconKind.values)
                        Container(
                          width: 175,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF151F32),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            children: [
                              ProfileMenuEmblem(kind: kind, size: 42),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  kind.label,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '2. CONQUISTAS (15 TRILHAS): ESTADO BLOQUEADO CINZA CLARO (#CBD5E1) -> EVOLUÇÃO BRONZE AO DIAMANTE COROADO',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFFFBBF24)),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 2.05,
                      ),
                      itemCount: kAchievementTrackVisualSpecs.length,
                      itemBuilder: (context, index) {
                        final spec = kAchievementTrackVisualSpecs[index];
                        return Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF151F32),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: spec.primaryColor.withValues(alpha: 0.35)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${spec.isClient ? "[CLIENTE]" : "[PRO]"} ${spec.name}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  Column(
                                    children: [
                                      AchievementMedalForge(
                                        trackCode: spec.code,
                                        tier: AchievementTier.bronze,
                                        level: 1,
                                        size: 54,
                                        locked: true,
                                      ),
                                      const SizedBox(height: 4),
                                      const Text('Bloqueada', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                                    ],
                                  ),
                                  Column(
                                    children: [
                                      AchievementMedalForge(
                                        trackCode: spec.code,
                                        tier: AchievementTier.bronze,
                                        level: 1,
                                        size: 54,
                                        locked: false,
                                      ),
                                      const SizedBox(height: 4),
                                      const Text('Nível I', style: TextStyle(fontSize: 10, color: Colors.white70)),
                                    ],
                                  ),
                                  Column(
                                    children: [
                                      AchievementMedalForge(
                                        trackCode: spec.code,
                                        tier: AchievementTier.gold,
                                        level: 5,
                                        size: 54,
                                        locked: false,
                                      ),
                                      const SizedBox(height: 4),
                                      const Text('Ouro III', style: TextStyle(fontSize: 10, color: Color(0xFFFBBF24))),
                                    ],
                                  ),
                                  Column(
                                    children: [
                                      AchievementMedalForge(
                                        trackCode: spec.code,
                                        tier: AchievementTier.diamond,
                                        level: 10,
                                        size: 54,
                                        locked: false,
                                      ),
                                      const SizedBox(height: 4),
                                      const Text('Diamante V', style: TextStyle(fontSize: 10, color: Color(0xFF38BDF8))),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    },
  );
}

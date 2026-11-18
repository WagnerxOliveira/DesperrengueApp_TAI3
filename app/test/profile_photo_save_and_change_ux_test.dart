import 'dart:convert';
import 'dart:typed_data';

import 'package:desperrengue_app/core/models/user_profile.dart';
import 'package:desperrengue_app/core/services/app_session.dart';
import 'package:desperrengue_app/core/ui/app_theme.dart';
import 'package:desperrengue_app/core/ui/image_picking.dart';
import 'package:desperrengue_app/features/auth/presentation/verificacao_step6c_termos.dart';
import 'package:desperrengue_app/features/client/presentation/client_orders_tab.dart';
import 'package:desperrengue_app/features/provider/presentation/provider_profile_screens.dart';
import 'package:desperrengue_app/features/provider/presentation/provider_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// PNG 1x1 válido transparente para decodificação limpa pelo codec de imagem em memória.
final Uint8List kValidPngBytesA = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

final Uint8List kValidPngBytesB = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

Widget _testHost(
  Widget child, {
  Brightness brightness = Brightness.dark,
  double textScale = 1.0,
}) {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.forMode(UserMode.client, brightness),
      builder: (context, inner) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: inner!,
      ),
      home: Scaffold(body: child),
    ),
  );
}

void _setViewport(
  WidgetTester tester, {
  required double width,
  required double height,
}) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, height);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  group('Fluxo em 2 etapas de Foto de Perfil (Pré-visualização + Salvar foto + Alterar foto imediato)', () {
    testWidgets(
      'ClientProfileTab: sem foto exibe "Adicionar foto de perfil"; ao escolher foto abre pré-visualização com botão "Salvar foto" (sem upload prematuro); "Cancelar" descarta; "Salvar foto" fecha sozinho e muda botão para "Alterar foto"',
      (tester) async {
        _setViewport(tester, width: 390, height: 844);

        var pickerCalls = 0;
        var uploadCalls = 0;
        Uint8List? lastUploadedBytes;

        const initialProfile = UserProfile(
          id: 'u-client-1',
          fullName: 'Maria Clara Oliveira',
          isClient: true,
          avatarUrl: null,
        );

        await tester.pumpWidget(
          _testHost(
            ClientProfileTab(
              profile: initialProfile,
              customPhotoPicker: (_) async {
                pickerCalls++;
                return PickedImage(
                  pickerCalls.isOdd ? kValidPngBytesA : kValidPngBytesB,
                  'png',
                  'foto_$pickerCalls.png',
                );
              },
              customAvatarUploader: (bytes, ext) async {
                uploadCalls++;
                lastUploadedBytes = bytes;
                return 'https://cdn.desperrengue.test/avatars/u-client-$uploadCalls.$ext';
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Sem foto, o botão explícito no perfil diz "Adicionar foto de perfil"
        final changeBtnFinder = find.byKey(const Key('client-profile-change-photo-btn'));
        expect(changeBtnFinder, findsOneWidget);
        expect(find.text('Adicionar foto de perfil'), findsOneWidget);
        expect(find.text('Alterar foto'), findsNothing);

        // 2. Usuário toca na foto de perfil (EditableAvatar) -> abre visualizador -> toca em "Adicionar foto"
        await tester.tap(find.byKey(const ValueKey('editable-avatar')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('photo-change')), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('photo-change')));
        await tester.pumpAndSettle();

        // 3. A foto foi escolhida na galeria (pickerCalls == 1), mas NENHUM upload foi feito ainda!
        expect(pickerCalls, 1);
        expect(uploadCalls, 0);

        // A tela de Pré-Visualização e Confirmação está aberta com todos os controles explícitos
        expect(find.byKey(const Key('profile-photo-preview-stage')), findsOneWidget);
        expect(find.text('Nova foto selecionada'), findsOneWidget);
        expect(find.text('Gostou da sua nova foto?'), findsOneWidget);
        expect(
          find.text('Confira como ela aparecerá no seu perfil antes de salvar.'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('btn-save-profile-photo')), findsOneWidget);
        expect(find.text('Salvar foto'), findsOneWidget);
        expect(find.byKey(const Key('btn-pick-another-photo')), findsOneWidget);
        expect(find.text('Escolher outra foto'), findsOneWidget);
        expect(find.byKey(const Key('btn-cancel-profile-photo')), findsOneWidget);
        expect(find.text('Cancelar'), findsOneWidget);

        // 4. Clicar em "Cancelar" NÃO faz upload e NÃO altera a foto
        await tester.tap(find.byKey(const Key('btn-cancel-profile-photo')));
        await tester.pumpAndSettle();

        expect(uploadCalls, 0);
        expect(find.byKey(const Key('profile-photo-preview-stage')), findsNothing);
        expect(find.text('Adicionar foto de perfil'), findsOneWidget);

        // 5. Agora o cliente toca diretamente no botão "Adicionar foto de perfil" -> escolhe outra foto -> clica em "Salvar foto"
        await tester.tap(changeBtnFinder);
        await tester.pumpAndSettle();

        expect(pickerCalls, 2);
        expect(uploadCalls, 0);
        expect(find.byKey(const Key('profile-photo-preview-stage')), findsOneWidget);

        // Testa também "Escolher outra foto" antes de salvar
        await tester.tap(find.byKey(const Key('btn-pick-another-photo')));
        await tester.pumpAndSettle();
        expect(pickerCalls, 3);
        expect(uploadCalls, 0); // Ainda sem upload prematuro!

        // Clica no botão principal "Salvar foto"
        await tester.tap(find.byKey(const Key('btn-save-profile-photo')));
        await tester.pumpAndSettle();

        // 6. Upload executado 1 única vez, modal fechou SOZINHO (sem precisar do botão '<' voltar)
        expect(uploadCalls, 1);
        expect(lastUploadedBytes, kValidPngBytesA);
        expect(find.byKey(const Key('profile-photo-preview-stage')), findsNothing);
        expect(find.text('Foto de perfil salva com sucesso!'), findsOneWidget);

        // 7. No exato instante em que volta para o Perfil, o botão já mudou para "Alterar foto"!
        expect(find.byKey(const Key('client-profile-change-photo-btn')), findsOneWidget);
        expect(find.text('Alterar foto'), findsOneWidget);
        expect(find.text('Adicionar foto de perfil'), findsNothing);

        // 8. Tocar logo em seguida em "Alterar foto" permite alterar novamente na hora
        await tester.tap(find.byKey(const Key('client-profile-change-photo-btn')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('profile-photo-preview-stage')), findsOneWidget);
        await tester.tap(find.byKey(const Key('btn-save-profile-photo')));
        await tester.pumpAndSettle();
        expect(uploadCalls, 2);
        expect(lastUploadedBytes, kValidPngBytesB);
        expect(find.text('Alterar foto'), findsOneWidget);
      },
    );

    testWidgets(
      'ClientProfileTab inclui item de menu para consultar Termos de Uso e Mandato Legal (VerificacaoStep6cTermosScreen)',
      (tester) async {
        _setViewport(tester, width: 390, height: 844);
        const profile = UserProfile(
          id: 'u-client-terms',
          fullName: 'Carlos Eduardo',
          isClient: true,
        );

        await tester.pumpWidget(_testHost(const ClientProfileTab(profile: profile)));
        await tester.pumpAndSettle();

        final termsTile = find.text('Termos de Uso e Mandato Legal');
        await tester.scrollUntilVisible(termsTile, 200);
        expect(termsTile, findsOneWidget);

        await tester.tap(termsTile);
        await tester.pumpAndSettle();
        expect(find.byType(VerificacaoStep6cTermosScreen), findsOneWidget);
      },
    );

    testWidgets(
      'ProviderProfileTab: escolhe foto -> pré-visualização -> "Salvar foto" fecha automaticamente, atualiza avatar e exibe botão "Alterar foto"',
      (tester) async {
        _setViewport(tester, width: 390, height: 844);

        var uploadCalls = 0;
        final initialTick = AppSession.instance.profileTick.value;

        const providerProfile = UserProfile(
          id: 'u-prov-1',
          fullName: 'Roberto Eletricista',
          isProvider: true,
          avatarUrl: null,
        );

        await tester.pumpWidget(
          _testHost(
            ProviderProfileTab(
              profile: providerProfile,
              customPhotoPicker: (_) async => PickedImage(
                kValidPngBytesA,
                'jpg',
                'perfil_profissional.jpg',
              ),
              customAvatarUploader: (bytes, ext) async {
                uploadCalls++;
                return 'https://cdn.desperrengue.test/avatars/prov-$uploadCalls.$ext';
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        final btnFinder = find.byKey(const Key('provider-profile-change-photo-btn'));
        expect(btnFinder, findsOneWidget);
        expect(find.text('Adicionar foto de perfil'), findsOneWidget);

        await tester.tap(btnFinder);
        await tester.pumpAndSettle();

        expect(uploadCalls, 0);
        expect(find.byKey(const Key('profile-photo-preview-stage')), findsOneWidget);
        expect(find.byKey(const Key('btn-save-profile-photo')), findsOneWidget);

        await tester.tap(find.byKey(const Key('btn-save-profile-photo')));
        await tester.pumpAndSettle();

        expect(uploadCalls, 1);
        expect(find.byKey(const Key('profile-photo-preview-stage')), findsNothing);
        expect(AppSession.instance.profileTick.value, greaterThan(initialTick));
        expect(find.text('Alterar foto'), findsOneWidget);
        expect(find.text('Adicionar foto de perfil'), findsNothing);
      },
    );

    testWidgets(
      'EditProviderProfileScreen: botão "Adicionar foto" / "Alterar foto" abaixo do avatar de 62px usa pré-visualização e botão explícito "Salvar foto"',
      (tester) async {
        _setViewport(tester, width: 390, height: 844);

        var uploadCalls = 0;

        await tester.pumpWidget(
          _testHost(
            EditProviderProfileScreen(
              initialProfileOverride: const UserProfile(
                id: 'u-prov-edit',
                fullName: 'Marcos Hidráulica',
                isProvider: true,
                avatarUrl: null,
                bio: 'Profissional com mais de 10 anos de experiência em hidráulica.',
              ),
              initialProviderRowOverride: const {
                'headline': 'Encanador Residencial',
                'specialties': ['Encanador'],
                'visit_fee': 40,
                'service_radius_km': 20,
              },
              customPhotoPicker: (_) async => PickedImage(
                kValidPngBytesA,
                'png',
                'avatar_edit.png',
              ),
              customAvatarUploader: (bytes, ext) async {
                uploadCalls++;
                return 'https://cdn.desperrengue.test/avatars/edit-$uploadCalls.$ext';
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        final editBtn = find.byKey(const Key('edit-provider-change-photo-btn'));
        expect(editBtn, findsOneWidget);
        expect(find.text('Adicionar foto'), findsOneWidget);

        await tester.tap(editBtn);
        await tester.pumpAndSettle();

        expect(uploadCalls, 0);
        expect(find.byKey(const Key('profile-photo-preview-stage')), findsOneWidget);
        expect(find.byKey(const Key('btn-save-profile-photo')), findsOneWidget);

        await tester.tap(find.byKey(const Key('btn-save-profile-photo')));
        await tester.pumpAndSettle();

        expect(uploadCalls, 1);
        expect(find.byKey(const Key('profile-photo-preview-stage')), findsNothing);
        expect(find.text('Alterar foto'), findsOneWidget);
      },
    );

    testWidgets(
      'Responsividade estrita (Zero RenderFlex overflow) em 320x640 @ textScale 1.4x, 360x780 e 412x915',
      (tester) async {
        const viewports = <({double w, double h, double scale})>[
          (w: 320, h: 640, scale: 1.4),
          (w: 360, h: 780, scale: 1.0),
          (w: 412, h: 915, scale: 1.0),
        ];

        for (final vp in viewports) {
          _setViewport(tester, width: vp.w, height: vp.h);

          // 1. ClientProfileTab + Modal de Pré-Visualização e Confirmação
          await tester.pumpWidget(
            _testHost(
              ClientProfileTab(
                profile: const UserProfile(
                  id: 'u-resp-client',
                  fullName: 'Fernanda Aparecida Albuquerque de Souza',
                  isClient: true,
                  livenessVerified: true,
                  ocrVerified: true,
                  clientKycStatus: 'VERIFIED',
                ),
                customPhotoPicker: (_) async => PickedImage(
                  kValidPngBytesA,
                  'png',
                  'resp.png',
                ),
                customAvatarUploader: (_, _) async =>
                    'https://cdn.desperrengue.test/avatars/resp.png',
              ),
              textScale: vp.scale,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'ClientProfileTab em ${vp.w}x${vp.h} @ ${vp.scale}x');

          // Abre o estágio de pré-visualização em 320x640 @ 1.4x
          await tester.tap(find.byKey(const Key('client-profile-change-photo-btn')));
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('profile-photo-preview-stage')), findsOneWidget);
          expect(tester.takeException(), isNull, reason: 'PreviewStage em ${vp.w}x${vp.h} @ ${vp.scale}x');

          // Salva e verifica transição para "Alterar foto" sem overflow
          await tester.tap(find.byKey(const Key('btn-save-profile-photo')));
          await tester.pumpAndSettle();
          expect(find.text('Alterar foto'), findsOneWidget);
          expect(tester.takeException(), isNull, reason: 'Pós-salvar em ${vp.w}x${vp.h} @ ${vp.scale}x');

          // 2. ProviderProfileTab
          await tester.pumpWidget(
            _testHost(
              ProviderProfileTab(
                profile: const UserProfile(
                  id: 'u-resp-prov',
                  fullName: 'Sebastião Gonçalves Eletricista Industrial',
                  isProvider: true,
                  avatarUrl: 'https://cdn.desperrengue.test/avatars/resp.png',
                ),
                customPhotoPicker: (_) async => PickedImage(
                  kValidPngBytesA,
                  'png',
                  'resp_prov.png',
                ),
                customAvatarUploader: (_, _) async =>
                    'https://cdn.desperrengue.test/avatars/resp_prov.png',
              ),
              textScale: vp.scale,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'ProviderProfileTab em ${vp.w}x${vp.h} @ ${vp.scale}x');

          // 3. EditProviderProfileScreen
          await tester.pumpWidget(
            _testHost(
              EditProviderProfileScreen(
                initialProfileOverride: const UserProfile(
                  id: 'u-resp-edit',
                  fullName: 'Sebastião Gonçalves',
                  isProvider: true,
                  avatarUrl: null,
                  bio: 'Profissional certificado em instalações elétricas.',
                ),
                initialProviderRowOverride: const {
                  'headline': 'Eletricista',
                  'specialties': ['Elétrica'],
                },
                customPhotoPicker: (_) async => PickedImage(
                  kValidPngBytesA,
                  'png',
                  'resp_edit.png',
                ),
                customAvatarUploader: (_, _) async =>
                    'https://cdn.desperrengue.test/avatars/resp_edit.png',
              ),
              textScale: vp.scale,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'EditProviderProfileScreen em ${vp.w}x${vp.h} @ ${vp.scale}x');
        }
      },
    );
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:desperrengue_app/core/models/marketplace_models.dart';
import 'package:desperrengue_app/core/security/geo_privacy_policy_engine.dart';
import 'package:desperrengue_app/core/services/accurate_geo_routing_service.dart';

GeoPrivacyDecision _provider(
  JobStatus status, {
  DateTime? scheduledFor,
  required DateTime now,
  bool emergency = false,
  bool assigned = true,
}) =>
    GeoPrivacyPolicyEngine.evaluate(
      role: GeoViewerRole.provider,
      status: status,
      scheduledFor: scheduledFor,
      isEmergency: emergency,
      isAssignedProvider: assigned,
      now: now,
    );

void main() {
  // 15/11/2026 12:00 em São Paulo == 15:00Z.
  final noon = DateTime.utc(2026, 11, 15, 15);
  // Dia agendado: 15/11 00h00 SP == 03:00Z.
  final todaySched = DateTime.utc(2026, 11, 15, 3);

  group('cliente (owner)', () {
    test('sempre vê tudo, em qualquer status', () {
      for (final s in JobStatus.values) {
        final d = GeoPrivacyPolicyEngine.evaluate(
          role: GeoViewerRole.owner,
          status: s,
          scheduledFor: DateTime.utc(2030, 1, 1),
          now: noon,
        );
        expect(d.phase, GeoPrivacyPhase.ownerFull, reason: '$s');
        expect(d.exactUnlocked, isTrue);
        expect(d.showStreetAndNumber && d.showComplement && d.showExactMap && d.showRoute, isTrue);
        expect(d.showApproximateArea, isFalse);
        expect(d.lockMessage, isNull);
      }
    });
  });

  group('profissional', () {
    test('open: só área aproximada', () {
      final d = _provider(JobStatus.open, scheduledFor: todaySched, now: noon, assigned: false);
      expect(d.phase, GeoPrivacyPhase.openQuoting);
      expect(d.exactUnlocked, isFalse);
      expect(d.showStreetAndNumber || d.showComplement || d.showExactMap || d.showRoute, isFalse);
      expect(d.showApproximateArea, isTrue);
      expect(d.lockMessage, isNotNull);
    });

    test('não atribuído nunca passa de openQuoting, mesmo no dia', () {
      for (final s in [JobStatus.scheduled, JobStatus.inProgress, JobStatus.awaitingPayment]) {
        final d = _provider(s, scheduledFor: todaySched, now: noon, assigned: false);
        expect(d.phase, GeoPrivacyPhase.openQuoting, reason: '$s');
        expect(d.exactUnlocked, isFalse);
      }
    });

    test('confirmedFuture: amanhã e próxima semana', () {
      for (final days in [1, 7]) {
        final sched = todaySched.add(Duration(days: days));
        for (final s in [JobStatus.awaitingPayment, JobStatus.scheduled]) {
          final d = _provider(s, scheduledFor: sched, now: noon);
          expect(d.phase, GeoPrivacyPhase.confirmedFuture, reason: '$s +$days');
          expect(d.exactUnlocked, isFalse);
          expect(d.showApproximateArea, isTrue);
          expect(d.showRoute, isFalse);
          expect(d.scheduledDay, DateTime.utc(2026, 11, 15 + days));
          expect(d.unlockAt, DateTime.utc(2026, 11, 15 + days, 3));
        }
      }
    });

    test('serviceDay: hoje libera tudo', () {
      final d = _provider(JobStatus.scheduled, scheduledFor: todaySched, now: noon);
      expect(d.phase, GeoPrivacyPhase.serviceDay);
      expect(d.exactUnlocked, isTrue);
      expect(d.showStreetAndNumber && d.showComplement && d.showExactMap && d.showRoute, isTrue);
      expect(d.showApproximateArea, isFalse);
      expect(d.lockMessage, isNull);
    });

    test('fronteira: 23:59:59 SP do dia anterior = travado; 00:00:00 SP = liberado', () {
      final before = DateTime.utc(2026, 11, 15, 2, 59, 59); // 14/11 23:59:59 SP
      final at = DateTime.utc(2026, 11, 15, 3); // 15/11 00:00:00 SP
      final sched = DateTime.utc(2026, 11, 15, 18); // 15/11 15:00 SP
      expect(_provider(JobStatus.scheduled, scheduledFor: sched, now: before).exactUnlocked, isFalse);
      expect(_provider(JobStatus.scheduled, scheduledFor: sched, now: at).exactUnlocked, isTrue);
      expect(
        _provider(JobStatus.scheduled, scheduledFor: sched, now: before).phase,
        GeoPrivacyPhase.confirmedFuture,
      );
    });

    test('awaitingPayment nunca libera, nem no dia', () {
      final d = _provider(JobStatus.awaitingPayment, scheduledFor: todaySched, now: noon);
      expect(d.phase, GeoPrivacyPhase.confirmedFuture);
      expect(d.exactUnlocked, isFalse);
      expect(d.lockMessage, isNot(contains('00h00')));
    });

    test('inProgress e awaitingApproval liberam', () {
      for (final s in [JobStatus.inProgress, JobStatus.awaitingApproval]) {
        final d = _provider(s, scheduledFor: todaySched.add(const Duration(days: 3)), now: noon);
        expect(d.phase, GeoPrivacyPhase.serviceDay, reason: '$s');
        expect(d.exactUnlocked, isTrue);
      }
    });

    test('emergência sem data com orçamento pago libera; sem emergência trava', () {
      expect(_provider(JobStatus.scheduled, now: noon, emergency: true).phase, GeoPrivacyPhase.serviceDay);
      expect(_provider(JobStatus.scheduled, now: noon).phase, GeoPrivacyPhase.confirmedFuture);
      // emergência ainda sem pagamento: trava
      expect(_provider(JobStatus.awaitingPayment, now: noon, emergency: true).exactUnlocked, isFalse);
      // emergência em job aberto (sem orçamento aceito): trava
      expect(
        _provider(JobStatus.open, now: noon, emergency: true, assigned: false).exactUnlocked,
        isFalse,
      );
    });

    test('closed: completed, canceled, disputed re-bloqueiam', () {
      for (final s in [JobStatus.completed, JobStatus.canceled, JobStatus.disputed]) {
        final d = _provider(s, scheduledFor: todaySched, now: noon, emergency: true);
        expect(d.phase, GeoPrivacyPhase.closed, reason: '$s');
        expect(d.exactUnlocked, isFalse);
        expect(d.showStreetAndNumber || d.showComplement || d.showExactMap || d.showRoute, isFalse);
        expect(d.showApproximateArea, isFalse);
        expect(d.lockMessage, isNotNull);
      }
    });
  });

  group('fuso America/Sao_Paulo (UTC−3 fixo)', () {
    test('nowSaoPaulo independe do fuso do aparelho', () {
      final sp = GeoPrivacyPolicyEngine.nowSaoPaulo(DateTime.utc(2026, 11, 15, 2, 30));
      expect((sp.year, sp.month, sp.day, sp.hour, sp.minute), (2026, 11, 14, 23, 30));
    });

    test('agendamento 02:30Z cai no dia anterior em SP', () {
      final sched = DateTime.utc(2026, 11, 15, 2, 30); // 14/11 23:30 SP
      final d = _provider(JobStatus.scheduled, scheduledFor: sched, now: DateTime.utc(2026, 11, 14, 15));
      expect(d.phase, GeoPrivacyPhase.serviceDay);
      expect(d.scheduledDay, DateTime.utc(2026, 11, 14));
      // no dia 13 em SP ainda está travado
      final earlier = _provider(JobStatus.scheduled, scheduledFor: sched, now: DateTime.utc(2026, 11, 13, 20));
      expect(earlier.phase, GeoPrivacyPhase.confirmedFuture);
      expect(earlier.lockMessage, contains('14/11/2026'));
    });

    test('now 02:30Z ainda é o dia anterior em SP', () {
      final sched = DateTime.utc(2026, 11, 15, 12); // 15/11 09:00 SP
      final d = _provider(JobStatus.scheduled, scheduledFor: sched, now: DateTime.utc(2026, 11, 15, 2, 30));
      expect(d.exactUnlocked, isFalse);
    });

    test('DateTime local equivale ao mesmo instante em UTC', () {
      final sched = DateTime.utc(2026, 11, 20, 15);
      final local = sched.toLocal();
      expect(
        _provider(JobStatus.scheduled, scheduledFor: local, now: noon).scheduledDay,
        _provider(JobStatus.scheduled, scheduledFor: sched, now: noon).scheduledDay,
      );
    });
  });

  group('lockMessage', () {
    test('confirmedFuture traz DD/MM/AAAA e texto de segurança', () {
      final d = _provider(
        JobStatus.scheduled,
        scheduledFor: DateTime.utc(2026, 12, 3, 15),
        now: noon,
      );
      expect(
        d.lockMessage,
        '🔒 Endereço Protegido por Segurança: você já está confirmado neste atendimento! '
        'Por segurança residencial, o nome da rua, número da casa/apartamento e o mapa com '
        'a rota exata serão liberados automaticamente às 00h00 do dia agendado (03/12/2026).',
      );
    });

    test('sem data não inventa data', () {
      final d = _provider(JobStatus.scheduled, now: noon);
      expect(d.lockMessage, isNot(matches(RegExp(r'\d{2}/\d{2}/\d{4}'))));
    });
  });

  group('ProviderLocationView.fromRpc', () {
    Map<String, dynamic> locked() => {
          'viewer_role': 'provider',
          'phase': 'confirmed_future',
          'exact_unlocked': false,
          'city': 'Poços de Caldas',
          'uf': 'MG',
          'neighborhood': 'Country Club',
          'lat': -21.79,
          'lng': -46.56,
          'radius_m': 650,
          'scheduled_date': '2026-11-20',
          'unlock_at': '2026-11-20T03:00:00+00:00',
        };

    test('travado: descarta rua/número/etc. mesmo se o servidor enviar por engano', () {
      final v = ProviderLocationView.fromRpc({
        ...locked(),
        'street': 'Avenida Padre Cletus',
        'number': '1661',
        'complement': 'Apto 3',
        'reference': 'Portão azul',
        'cep': '37704-000',
      });
      expect(v.exactUnlocked, isFalse);
      expect(v.street, isNull);
      expect(v.number, isNull);
      expect(v.complement, isNull);
      expect(v.reference, isNull);
      expect(v.cep, isNull);
      expect(v.fullStreetLine, isNull);
      expect(v.areaTitle, 'Country Club • Poços de Caldas - MG');
      expect(v.phase, GeoPrivacyPhase.confirmedFuture);
      expect(v.radiusM, 650);
      expect(v.scheduledDate, DateTime.utc(2026, 11, 20));
      expect(v.unlockAt, DateTime.utc(2026, 11, 20, 3));
      expect(v.canShowApproximateArea, isTrue);
      expect(v.canShowExactMap, isFalse);
      expect(v.lockMessage, contains('20/11/2026'));
    });

    test('flag exact_unlocked ausente ou com fase travada: trava', () {
      final noFlag = ProviderLocationView.fromRpc({'phase': 'service_day', 'street': 'X', 'number': '1'});
      expect(noFlag.exactUnlocked, isFalse);
      expect(noFlag.street, isNull);
      expect(noFlag.phase, GeoPrivacyPhase.openQuoting);

      final lie = ProviderLocationView.fromRpc({...locked(), 'exact_unlocked': true, 'street': 'X'});
      expect(lie.exactUnlocked, isFalse);
      expect(lie.street, isNull);
    });

    test('destravado: expõe endereço completo e raio 100 por padrão', () {
      final v = ProviderLocationView.fromRpc({
        'viewer_role': 'provider',
        'phase': 'service_day',
        'exact_unlocked': true,
        'city': 'Poços de Caldas',
        'uf': 'MG',
        'neighborhood': 'Country Club',
        'street': 'Avenida Padre Cletus',
        'number': '1661',
        'complement': 'Apto 3',
        'reference': 'Portão azul',
        'cep': '37704-000',
        'lat': -21.7968,
        'lng': -46.6012,
      });
      expect(v.exactUnlocked, isTrue);
      expect(v.fullStreetLine, 'Avenida Padre Cletus, 1661 - Apto 3');
      expect(v.radiusM, 100);
      expect(v.canShowExactMap, isTrue);
      expect(v.lockMessage, isNull);
    });

    test('tolerante a null, vazio e tipos estranhos', () {
      final v = ProviderLocationView.fromRpc({});
      expect(v.phase, GeoPrivacyPhase.openQuoting);
      expect(v.exactUnlocked, isFalse);
      expect(v.city, '');
      expect(v.areaTitle, 'Localização protegida');
      expect(v.lat, isNull);
      expect(v.radiusM, 800);

      final w = ProviderLocationView.fromRpc({
        'phase': 'open_quoting',
        'city': null,
        'neighborhood': 'Centro',
        'lat': 'abc',
        'lng': 999,
        'radius_m': '100',
        'scheduled_date': 'lixo',
        'unlock_at': 42,
      });
      expect(w.lat, isNull);
      expect(w.lng, isNull);
      expect(w.radiusM, 800, reason: 'raio travado menor que 500 m é rejeitado');
      expect(w.scheduledDate, isNull);
      expect(w.areaTitle, 'Centro');
    });

    test('closed e denied: sem coordenadas nem área', () {
      final c = ProviderLocationView.fromRpc({...locked(), 'phase': 'closed'});
      expect(c.phase, GeoPrivacyPhase.closed);
      expect(c.lat, isNull);
      expect(c.canShowApproximateArea, isFalse);
      expect(c.lockMessage, isNotNull);

      expect(ProviderLocationView.tryFromRpc({'phase': 'denied', 'viewer_role': 'none'}), isNull);
      expect(ProviderLocationView.tryFromRpc(null), isNull);
      expect(ProviderLocationView.tryFromRpc(<String, dynamic>{}), isNull);
      final d = ProviderLocationView.fromRpc({...locked(), 'phase': 'denied', 'street': 'X'});
      expect(d.exactUnlocked, isFalse);
      expect(d.city, '');
      expect(d.lat, isNull);
    });
  });

  group('Job.fromMap campos públicos', () {
    Map<String, dynamic> base() => {
          'id': '11111111-2222-3333-4444-555555555555',
          'client_id': 'c1',
        };

    test('lê public_lat/public_lng/fuzzy_radius_m e tolera ausência', () {
      final j = Job.fromMap({...base(), 'public_lat': -21.8, 'public_lng': '-46.5', 'fuzzy_radius_m': 650});
      expect(j.publicLat, -21.8);
      expect(j.publicLng, -46.5);
      expect(j.fuzzyRadiusM, 650);
      expect(j.hasPublicCenter, isTrue);
      expect(j.latitude, isNull);

      final k = Job.fromMap(base());
      expect(k.hasPublicCenter, isFalse);
      expect(k.fuzzyRadiusM, isNull);
    });
  });

  group('compat accurate_geo_routing_service', () {
    test('isServiceDayUnlocked delega ao engine (fuso SP)', () {
      final sched = DateTime.utc(2026, 11, 15, 18);
      expect(isServiceDayUnlocked(sched, status: JobStatus.scheduled, now: DateTime.utc(2026, 11, 15, 2, 59, 59)), isFalse);
      expect(isServiceDayUnlocked(sched, status: JobStatus.scheduled, now: DateTime.utc(2026, 11, 15, 3)), isTrue);
      expect(isServiceDayUnlocked(sched, status: JobStatus.completed, now: DateTime.utc(2026, 11, 15, 15)), isFalse);
      expect(isServiceDayUnlocked(null, status: JobStatus.scheduled, isEmergency: true), isTrue);
    });

    test('resolveProviderAddressView trava com data formatada no dia SP', () {
      final view = AccurateGeoRoutingService.resolveProviderAddressView(
        fullAddressLine: 'Rua Padre José Geraldi, 203 - Maria Imaculada, Poços de Caldas - MG',
        scheduledDate: DateTime.utc(2026, 11, 15, 2, 30),
        status: JobStatus.scheduled,
        now: DateTime.utc(2026, 11, 10, 12),
      );
      expect(view.isUnlocked, isFalse);
      expect(view.privacyBadgeText, contains('(14/11/2026)'));
      expect(view.fullAddress, isNull);
    });
  });
}

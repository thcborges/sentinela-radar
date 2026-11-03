import 'package:flutter_test/flutter_test.dart';
import 'package:sentinela/domain/sync/dataset_update_checker.dart';

void main() {
  group('DatasetUpdateChecker', () {
    const checker = DatasetUpdateChecker(
      scheduledWeekday: DateTime.sunday,
      scheduledHourUtc: 3,
      waitMarginHours: 2,
    );

    group('isDatabaseEmpty', () {
      test('retorna true quando totalPoisCount for 0', () {
        expect(checker.isDatabaseEmpty(totalPoisCount: 0), isTrue);
      });

      test('retorna false quando totalPoisCount for maior que 0', () {
        expect(checker.isDatabaseEmpty(totalPoisCount: 1), isFalse);
        expect(checker.isDatabaseEmpty(totalPoisCount: 1997), isFalse);
      });
    });

    group('getLatestScheduledRelease', () {
      test('domingo antes do horário de execução (02:59 UTC) retorna domingo anterior às 05:00 UTC', () {
        final now = DateTime.utc(2026, 11, 8, 2, 59); // Domingo
        final latest = checker.getLatestScheduledRelease(now);
        expect(latest, DateTime.utc(2026, 11, 1, 5, 0));
      });

      test('domingo durante a margem de espera (04:00 UTC) retorna domingo anterior às 05:00 UTC', () {
        final now = DateTime.utc(2026, 11, 8, 4, 0); // Domingo
        final latest = checker.getLatestScheduledRelease(now);
        expect(latest, DateTime.utc(2026, 11, 1, 5, 0));
      });

      test('domingo exatamente no fim da margem de espera (05:00 UTC) retorna este domingo às 05:00 UTC', () {
        final now = DateTime.utc(2026, 11, 8, 5, 0); // Domingo
        final latest = checker.getLatestScheduledRelease(now);
        expect(latest, DateTime.utc(2026, 11, 8, 5, 0));
      });

      test('domingo à tarde (14:30 UTC) retorna este domingo às 05:00 UTC', () {
        final now = DateTime.utc(2026, 11, 8, 14, 30); // Domingo
        final latest = checker.getLatestScheduledRelease(now);
        expect(latest, DateTime.utc(2026, 11, 8, 5, 0));
      });

      test('quarta-feira (12:00 UTC) retorna o domingo anterior às 05:00 UTC', () {
        final now = DateTime.utc(2026, 11, 11, 12, 0); // Quarta-feira
        final latest = checker.getLatestScheduledRelease(now);
        expect(latest, DateTime.utc(2026, 11, 8, 5, 0));
      });

      test('sábado (23:59 UTC) retorna o domingo anterior às 05:00 UTC', () {
        final now = DateTime.utc(2026, 11, 14, 23, 59); // Sábado
        final latest = checker.getLatestScheduledRelease(now);
        expect(latest, DateTime.utc(2026, 11, 8, 5, 0));
      });

      test('suporta margem de 1 hora personalizada', () {
        const checker1h = DatasetUpdateChecker(
          scheduledWeekday: DateTime.sunday,
          scheduledHourUtc: 3,
          waitMarginHours: 1,
        );
        final now = DateTime.utc(2026, 11, 8, 4, 15);
        final latest = checker1h.getLatestScheduledRelease(now);
        expect(latest, DateTime.utc(2026, 11, 8, 4, 0));
      });
    });

    group('isUpdateAvailable', () {
      final now = DateTime.utc(2026, 11, 8, 12, 0); // Domingo após lançamento das 05:00 UTC

      test('retorna false se a base estiver vazia (clean install requer aviso inicial, não atualização)', () {
        expect(
          checker.isUpdateAvailable(
            now: now,
            lastUpdated: null,
            totalPoisCount: 0,
          ),
          isFalse,
        );
      });

      test('retorna true se lastUpdated for nulo mas houver POIs na base', () {
        expect(
          checker.isUpdateAvailable(
            now: now,
            lastUpdated: null,
            totalPoisCount: 50,
          ),
          isTrue,
        );
      });

      test('retorna true se lastUpdated for anterior à data da esteira recente', () {
        final lastUpdated = DateTime.utc(2026, 11, 8, 4, 59); // Antes de 05:00 UTC
        expect(
          checker.isUpdateAvailable(
            now: now,
            lastUpdated: lastUpdated,
            totalPoisCount: 1997,
          ),
          isTrue,
        );
      });

      test('retorna false se lastUpdated for posterior à data da esteira recente (já atualizado)', () {
        final lastUpdated = DateTime.utc(2026, 11, 8, 6, 0); // Depois de 05:00 UTC
        expect(
          checker.isUpdateAvailable(
            now: now,
            lastUpdated: lastUpdated,
            totalPoisCount: 1997,
          ),
          isFalse,
        );
      });

      test('retorna false se lastUpdated for exatamente igual à data da esteira recente', () {
        final lastUpdated = DateTime.utc(2026, 11, 8, 5, 0);
        expect(
          checker.isUpdateAvailable(
            now: now,
            lastUpdated: lastUpdated,
            totalPoisCount: 1997,
          ),
          isFalse,
        );
      });

      test('retorna status correto com base no DateTime.now() caso now seja omitido', () {
        final lastUpdated = DateTime.now().subtract(const Duration(days: 30));
        expect(
          checker.isUpdateAvailable(
            lastUpdated: lastUpdated,
            totalPoisCount: 100,
          ),
          isTrue,
        );
      });
    });
  });
}

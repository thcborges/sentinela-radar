import 'package:flutter_test/flutter_test.dart';
import 'package:sentinela/domain/sync/dataset_update_checker.dart';

void main() {
  group('DatasetUpdateChecker - Margem Exata de 2 Horas após Agendamento', () {
    const checker = DatasetUpdateChecker(
      scheduledWeekday: DateTime.sunday,
      scheduledHourUtc: 3, // 03:00 UTC (00:00 Horário de Brasília)
      waitMarginHours: 2,  // 2 horas exatas de margem de espera
    );

    test('getLatestScheduledRelease deve calcular disponibilidade a partir das 05:00 UTC de domingo', () {
      // Domingo às 04:59 UTC (menos de 2h após a esteira de 03:00 UTC):
      // A release de hoje AINDA NÃO está liberada para consumo. Deve apontar para o domingo anterior.
      final sundayBeforeReady = DateTime.utc(2026, 11, 8, 4, 59, 59);
      final prevRelease = checker.getLatestScheduledRelease(sundayBeforeReady);
      expect(prevRelease, equals(DateTime.utc(2026, 11, 1, 5, 0, 0)));

      // Domingo às 05:00 UTC (exatamente 2 horas após início da esteira):
      // A release de hoje passa a estar disponível!
      final sundayAtReady = DateTime.utc(2026, 11, 8, 5, 0, 0);
      final currentRelease = checker.getLatestScheduledRelease(sundayAtReady);
      expect(currentRelease, equals(DateTime.utc(2026, 11, 8, 5, 0, 0)));
    });

    test('isUpdateAvailable deve respeitar a margem de 2 horas e sumir após atualização', () {
      final lastUpdateOld = DateTime.utc(2026, 11, 1, 6, 0, 0);

      // Domingo às 04:00 UTC (apenas 1h após a esteira): ainda não avisa
      final check1h = DateTime.utc(2026, 11, 8, 4, 0, 0);
      expect(
        checker.isUpdateAvailable(
          now: check1h,
          lastUpdated: lastUpdateOld,
          totalPoisCount: 1500,
        ),
        isFalse,
      );

      // Domingo às 05:01 UTC (2h após a esteira): ALERTA FICA VISÍVEL
      final check2h = DateTime.utc(2026, 11, 8, 5, 1, 0);
      expect(
        checker.isUpdateAvailable(
          now: check2h,
          lastUpdated: lastUpdateOld,
          totalPoisCount: 1500,
        ),
        isTrue,
      );

      // Usuário efetua a atualização: lastUpdated passa a ser agora
      final justUpdated = DateTime.utc(2026, 11, 8, 5, 5, 0);
      expect(
        checker.isUpdateAvailable(
          now: check2h,
          lastUpdated: justUpdated,
          totalPoisCount: 65000,
        ),
        isFalse, // Alerta sumiu com sucesso!
      );
    });
  });
}

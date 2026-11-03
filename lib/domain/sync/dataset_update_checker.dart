/// Mecanismo de verificação e cálculo de disponibilidade de nova versão
/// do conjunto de dados nacional com base na esteira agendada do GitHub Actions.
class DatasetUpdateChecker {
  /// Dia da semana no qual a esteira semanal executa (padrão: domingo / DateTime.sunday).
  final int scheduledWeekday;

  /// Hora UTC na qual a esteira inicia (padrão: 03:00 UTC / 00:00 Horário de Brasília).
  final int scheduledHourUtc;

  /// Margem de segurança de espera para compilação, validação e publicação no GitHub Releases (em horas, ex: 1 a 2 horas).
  final int waitMarginHours;

  const DatasetUpdateChecker({
    this.scheduledWeekday = DateTime.sunday,
    this.scheduledHourUtc = 3,
    this.waitMarginHours = 2,
  });

  /// Verifica se o banco de dados local está vazio (cenário de clean install inicial).
  bool isDatabaseEmpty({required int totalPoisCount}) {
    return totalPoisCount <= 0;
  }

  /// Calcula a data/hora exata do lançamento agendado mais recente já concluído e disponível.
  ///
  /// Considera o horário da esteira somado à margem de tolerância de compilação.
  DateTime getLatestScheduledRelease(DateTime now) {
    final utc = now.toUtc();
    final readyHourUtc = scheduledHourUtc + waitMarginHours;

    int daysDiff = (utc.weekday - scheduledWeekday) % 7;
    if (daysDiff < 0) {
      daysDiff += 7;
    }

    DateTime candidate = DateTime.utc(
      utc.year,
      utc.month,
      utc.day,
      readyHourUtc,
    ).subtract(Duration(days: daysDiff));

    if (utc.isBefore(candidate)) {
      candidate = candidate.subtract(const Duration(days: 7));
    }

    return candidate;
  }

  /// Determina se há uma nova base de dados publicada na esteira pronta para download.
  ///
  /// Retorna false se o banco estiver vazio (pois este requer o aviso de instalação inicial).
  /// Retorna true se houver POIs e a última sincronização tiver ocorrido antes do lançamento mais recente.
  bool isUpdateAvailable({
    DateTime? now,
    DateTime? lastUpdated,
    required int totalPoisCount,
  }) {
    if (isDatabaseEmpty(totalPoisCount: totalPoisCount)) {
      return false;
    }

    if (lastUpdated == null) {
      return true;
    }

    final effectiveNow = now ?? DateTime.now();
    final latestRelease = getLatestScheduledRelease(effectiveNow);

    return lastUpdated.toUtc().isBefore(latestRelease);
  }
}

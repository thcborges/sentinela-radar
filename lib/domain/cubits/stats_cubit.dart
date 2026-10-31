import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentinela/features/stats/models/passage_record.dart';
import 'package:sentinela/infrastructure/repositories/passage_repository.dart';

/// Estado imutável das estatísticas de condução e histórico de passagens.
class StatsState extends Equatable {
  final bool isLoading;
  final StatsSummary summary;
  final List<PassageRecord> recentPassages;

  const StatsState({
    this.isLoading = false,
    this.summary = const StatsSummary(totalPassages: 0, overSpeedPassages: 0),
    this.recentPassages = const [],
  });

  StatsState copyWith({
    bool? isLoading,
    StatsSummary? summary,
    List<PassageRecord>? recentPassages,
  }) {
    return StatsState(
      isLoading: isLoading ?? this.isLoading,
      summary: summary ?? this.summary,
      recentPassages: recentPassages ?? this.recentPassages,
    );
  }

  @override
  List<Object?> get props => [isLoading, summary, recentPassages];
}

/// Cubit responsável por orquestrar a leitura e gravação das estatísticas privadas de passagens.
class StatsCubit extends Cubit<StatsState> {
  final PassageRepository _repository;

  StatsCubit({required PassageRepository repository})
      : _repository = repository,
        super(const StatsState());

  /// Carrega as métricas consolidadas e as últimas passagens registradas.
  Future<void> loadStats() async {
    emit(state.copyWith(isLoading: true));
    final summary = await _repository.getStatsSummary();
    final passages = await _repository.getRecentPassages(limit: 20);
    emit(state.copyWith(
      isLoading: false,
      summary: summary,
      recentPassages: passages,
    ));
  }

  /// Insere uma nova passagem no banco local e atualiza os indicadores.
  Future<void> recordPassage(PassageRecord record) async {
    await _repository.insertPassage(record);
    final summary = await _repository.getStatsSummary();
    final passages = await _repository.getRecentPassages(limit: 20);
    emit(state.copyWith(
      isLoading: false,
      summary: summary,
      recentPassages: passages,
    ));
  }

  /// Limpa 100% dos dados históricos armazenados localmente.
  Future<void> clearHistory() async {
    await _repository.clearHistory();
    emit(const StatsState(
      isLoading: false,
      summary: StatsSummary(totalPassages: 0, overSpeedPassages: 0),
      recentPassages: [],
    ));
  }
}

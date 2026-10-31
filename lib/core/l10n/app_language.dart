/// Idiomas suportados pelo Sentinela.
enum AppLanguage {
  pt,
  en,
  es;

  String get localeCode {
    switch (this) {
      case AppLanguage.pt:
        return 'pt_BR';
      case AppLanguage.en:
        return 'en_US';
      case AppLanguage.es:
        return 'es_ES';
    }
  }

  String get displayName {
    switch (this) {
      case AppLanguage.pt:
        return 'Português';
      case AppLanguage.en:
        return 'English';
      case AppLanguage.es:
        return 'Español';
    }
  }

  static AppLanguage fromCode(String code) {
    final lower = code.toLowerCase();
    if (lower.startsWith('en')) return AppLanguage.en;
    if (lower.startsWith('es')) return AppLanguage.es;
    return AppLanguage.pt;
  }
}

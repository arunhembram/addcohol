enum AppEnvironment {
  dev('dev', 'Development', '.env.dev'),
  staging('staging', 'Staging', '.env.staging'),
  prod('prod', 'Production', '.env.prod');

  const AppEnvironment(this.name, this.displayName, this.defaultEnvFileName);

  final String name;
  final String displayName;
  final String defaultEnvFileName;

  static AppEnvironment fromString(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppEnvironment.dev;
    }
    final normalized = value.trim().toLowerCase();
    for (final env in AppEnvironment.values) {
      if (env.name == normalized || env.displayName.toLowerCase() == normalized) {
        return env;
      }
    }
    return AppEnvironment.dev;
  }

  bool get isDev => this == AppEnvironment.dev;
  bool get isStaging => this == AppEnvironment.staging;
  bool get isProd => this == AppEnvironment.prod;
}

enum AppHealthState {
  healthy('healthy', 'Healthy', 'কার্যকর / সুস্থ'),
  degraded('degraded', 'Degraded', 'আংশিক কার্যকর'),
  unhealthy('unhealthy', 'Unhealthy', 'সমস্যাযুক্ত');

  const AppHealthState(this.value, this.displayName, this.bengaliName);

  final String value;
  final String displayName;
  final String bengaliName;

  bool get isHealthy => this == AppHealthState.healthy;
}

enum ServiceStatus {
  connected('connected', 'Connected', 'সংযুক্ত'),
  disconnected('disconnected', 'Disconnected', 'সংযোগ বিচ্ছিন্ন'),
  unconfigured('unconfigured', 'Not Configured', 'কনফিগার করা হয়নি'),
  checking('checking', 'Checking...', 'যাচাই করা হচ্ছে...');

  const ServiceStatus(this.value, this.label, this.bengaliLabel);

  final String value;
  final String label;
  final String bengaliLabel;

  bool get isConnected => this == ServiceStatus.connected;
}

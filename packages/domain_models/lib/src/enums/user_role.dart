enum UserRole {
  masterAdmin('master_admin', 'Master Admin', 'মাস্টার অ্যাডমিন'),
  admin('admin', 'Admin', 'অ্যাডমিন'),
  employee('employee', 'Employee', 'কর্মী / কর্মচারী'),
  shopkeeper('shopkeeper', 'Shopkeeper', 'দোকানদার'),
  companyUser('company_user', 'Company User / Advertiser', 'বিজ্ঞাপনদাতা কোম্পানি');

  const UserRole(this.value, this.displayName, this.bengaliName);

  final String value;
  final String displayName;
  final String bengaliName;

  static const UserRole company = UserRole.companyUser;

  static UserRole fromString(String? role) {
    if (role == null) return UserRole.shopkeeper;
    final normalized = role.toLowerCase().trim();
    if (normalized == 'company' || normalized == 'company_user') {
      return UserRole.companyUser;
    }
    return UserRole.values.firstWhere(
      (r) => r.value.toLowerCase() == normalized,
      orElse: () => UserRole.shopkeeper,
    );
  }

  bool get isAdministrative => this == UserRole.masterAdmin || this == UserRole.admin;
  bool get isMasterAdmin => this == UserRole.masterAdmin;
  bool get isAdmin => this == UserRole.admin;
  bool get isEmployee => this == UserRole.employee;
  bool get isShopkeeper => this == UserRole.shopkeeper;
  bool get isCompanyUser => this == UserRole.companyUser;
  bool get isCompany => this == UserRole.companyUser;
}

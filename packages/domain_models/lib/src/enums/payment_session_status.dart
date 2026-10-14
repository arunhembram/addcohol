enum PaymentSessionStatus {
  created('created'),
  scanned('scanned'),
  amountSubmitted('amount_submitted'),
  awaitingConfirmation('awaiting_confirmation'),
  confirmed('confirmed'),
  rejected('rejected'),
  expired('expired'),
  cancelled('cancelled');

  final String apiValue;
  const PaymentSessionStatus(this.apiValue);

  static PaymentSessionStatus fromString(String? val) {
    if (val == null) return PaymentSessionStatus.created;
    final normalized = val.toLowerCase().trim();
    switch (normalized) {
      case 'created':
      case 'initiated':
        return PaymentSessionStatus.created;
      case 'scanned':
      case 'qr_scanned':
        return PaymentSessionStatus.scanned;
      case 'amount_submitted':
      case 'amountsubmitted':
        return PaymentSessionStatus.amountSubmitted;
      case 'awaiting_confirmation':
      case 'awaitingconfirmation':
        return PaymentSessionStatus.awaitingConfirmation;
      case 'confirmed':
      case 'completed':
      case 'success':
        return PaymentSessionStatus.confirmed;
      case 'rejected':
        return PaymentSessionStatus.rejected;
      case 'expired':
        return PaymentSessionStatus.expired;
      case 'cancelled':
      case 'canceled':
        return PaymentSessionStatus.cancelled;
      default:
        return PaymentSessionStatus.created;
    }
  }

  String get displayName {
    switch (this) {
      case PaymentSessionStatus.created:
        return 'Created';
      case PaymentSessionStatus.scanned:
        return 'QR Scanned';
      case PaymentSessionStatus.amountSubmitted:
        return 'Amount Submitted';
      case PaymentSessionStatus.awaitingConfirmation:
        return 'Awaiting Confirmation';
      case PaymentSessionStatus.confirmed:
        return 'Confirmed';
      case PaymentSessionStatus.rejected:
        return 'Rejected';
      case PaymentSessionStatus.expired:
        return 'Expired';
      case PaymentSessionStatus.cancelled:
        return 'Cancelled';
    }
  }
}

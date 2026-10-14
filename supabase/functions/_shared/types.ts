export type PaymentSessionStatus =
  | 'created'
  | 'scanned'
  | 'amount_submitted'
  | 'awaiting_confirmation'
  | 'confirmed'
  | 'rejected'
  | 'expired'
  | 'cancelled';

export interface PaymentSession {
  id: string;
  shop_id: string;
  shop_name?: string;
  owner_name?: string;
  shop_code?: string;
  company_id?: string | null;
  initiated_by_user_id?: string;
  created_by_employee_id?: string;
  scanned_by_employee_id?: string | null;
  amount?: number | null;
  currency?: string;
  status: PaymentSessionStatus;
  qr_token?: string;
  qr_token_hash: string;
  transaction_reference?: string | null;
  rejection_reason?: string | null;
  expires_at: string;
  scanned_at?: string | null;
  amount_submitted_at?: string | null;
  confirmed_at?: string | null;
  rejected_at?: string | null;
  created_at: string;
  updated_at: string;
}

export interface PaymentTransaction {
  id: string;
  session_id: string;
  shop_id: string;
  amount: number;
  currency: string;
  status: 'pending' | 'success' | 'confirmed' | 'failed' | 'rejected';
  payment_method: string;
  transaction_reference: string;
  verified_by_user_id: string | null;
  verified_at: string | null;
  verification_notes: string | null;
  created_at: string;
}

export interface CreatePaymentSessionRequest {
  shop_id: string;
  session_id?: string;
  duration_seconds?: number;
}

export interface ScanPaymentQrRequest {
  qr_token: string;
}

export interface SubmitPaymentAmountRequest {
  session_id: string;
  amount: number;
}

export interface ConfirmPaymentRequest {
  session_id: string;
  transaction_reference?: string;
  verification_notes?: string;
}

export interface RejectPaymentRequest {
  session_id: string;
  rejection_reason: string;
}

export interface CancelPaymentSessionRequest {
  session_id: string;
}

export interface ExpireDailyPhotosRequest {
  retention_days?: number;
  batch_size?: number;
}

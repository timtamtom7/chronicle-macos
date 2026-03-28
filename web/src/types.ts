export interface Bill {
  id: string;
  name: string;
  amountCents: number;
  currency: Currency;
  dueDay: number;
  dueDate: string;
  recurrence: Recurrence;
  category: Category;
  notes?: string;
  reminderTimings: ReminderTiming[];
  autoMarkPaid: boolean;
  isTaxDeductible: boolean;
  businessTag?: BusinessTag;
  isReimbursable: boolean;
  invoiceReference?: string;
  attachedInvoiceURL?: string;
  originalAmount?: number;
  originalCurrency?: Currency;
  receiptURL?: string;
  isActive: boolean;
  isPaid: boolean;
  ownerId?: string;
  createdAt: string;
}

export type Currency = 'USD' | 'EUR' | 'GBP' | 'CAD' | 'AUD' | 'JPY' | 'CHF' | 'INR' | 'BRL' | 'MXN';

export type Recurrence = 'None' | 'Weekly' | 'Biweekly' | 'Monthly' | 'Quarterly' | 'Semi-annually' | 'Annually';

export type Category = 'Housing' | 'Utilities' | 'Subscriptions' | 'Insurance' | 'Phone/Internet' | 'Transportation' | 'Health' | 'Other';

export type ReminderTiming = '3 days before' | '1 day before' | 'On due date' | 'None';

export type BusinessTag = 'personal' | 'business' | 'both';

export interface Summary {
  totalDueThisMonth: string;
  totalPaidThisMonth: string;
  upcomingCount: string;
  paidCount: string;
}

export interface Household {
  id: string;
  name: string;
  currency: Currency;
  createdAt: string;
}

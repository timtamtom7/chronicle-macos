import { Bill, Summary, Household } from './types';

const API_BASE = 'http://localhost:8765';

function getPin(): string | null {
  return localStorage.getItem('chronicle_pin');
}

function setPin(pin: string): void {
  localStorage.setItem('chronicle_pin', pin);
}

async function fetchWithAuth(endpoint: string, options: RequestInit = {}): Promise<Response> {
  const pin = getPin();
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    ...(options.headers as Record<string, string> || {}),
  };

  if (pin) {
    headers['Authorization'] = `Bearer ${pin}`;
  }

  const response = await fetch(`${API_BASE}${endpoint}`, {
    ...options,
    headers,
  });

  return response;
}

export function authenticate(pin: string): boolean {
  if (!pin || pin.length !== 4 || !/^\d+$/.test(pin)) {
    return false;
  }
  setPin(pin);
  return true;
}

export function isAuthenticated(): boolean {
  return getPin() !== null;
}

export function logout(): void {
  localStorage.removeItem('chronicle_pin');
}

export async function getBills(): Promise<Bill[]> {
  const response = await fetchWithAuth('/bills');
  if (!response.ok) throw new Error('Failed to fetch bills');
  return response.json();
}

export async function getBill(id: string): Promise<Bill | null> {
  const response = await fetchWithAuth(`/bills/${id}`);
  if (response.status === 404) return null;
  if (!response.ok) throw new Error('Failed to fetch bill');
  return response.json();
}

export async function getSummary(): Promise<Summary> {
  const response = await fetchWithAuth('/summary');
  if (!response.ok) throw new Error('Failed to fetch summary');
  return response.json();
}

export async function getHousehold(): Promise<Household | null> {
  const response = await fetchWithAuth('/household');
  if (response.status === 404) return null;
  if (!response.ok) throw new Error('Failed to fetch household');
  return response.json();
}

export function formatAmount(cents: number, currency: string = 'USD'): string {
  const amount = cents / (currency === 'JPY' ? 1 : 100);
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: currency,
  }).format(amount);
}

export function formatDate(dateString: string): string {
  const date = new Date(dateString);
  return new Intl.DateTimeFormat('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  }).format(date);
}

export function getCategoryIcon(category: string): string {
  const icons: Record<string, string> = {
    'Housing': '🏠',
    'Utilities': '⚡',
    'Subscriptions': '📺',
    'Insurance': '🛡️',
    'Phone/Internet': '📱',
    'Transportation': '🚗',
    'Health': '❤️',
    'Other': '📌',
  };
  return icons[category] || '📌';
}

export function getBillStatus(bill: Bill): 'paid' | 'overdue' | 'due-today' | 'due-soon' | 'upcoming' {
  if (bill.isPaid) return 'paid';

  const now = new Date();
  const dueDate = new Date(bill.dueDate);
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const due = new Date(dueDate.getFullYear(), dueDate.getMonth(), dueDate.getDate());

  if (due < today) return 'overdue';
  if (due.getTime() === today.getTime()) return 'due-today';

  const threeDaysLater = new Date(today);
  threeDaysLater.setDate(threeDaysLater.getDate() + 3);
  if (due <= threeDaysLater) return 'due-soon';

  return 'upcoming';
}

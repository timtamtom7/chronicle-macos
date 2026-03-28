import { useState, useEffect } from 'react';
import {
  authenticate,
  isAuthenticated,
  logout,
  getBills,
  getSummary,
  formatAmount,
  formatDate,
  getCategoryIcon,
  getBillStatus,
} from './api';
import { Bill, Summary } from './types';

type Tab = 'dashboard' | 'bills';

interface BillDetailProps {
  bill: Bill;
  onClose: () => void;
}

function BillDetail({ bill, onClose }: BillDetailProps) {
  const status = getBillStatus(bill);

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <h2>{bill.name}</h2>
          <button className="modal-close" onClick={onClose}>×</button>
        </div>

        <div className="detail-row">
          <span className="detail-label">Amount</span>
          <span className="detail-value amount">
            {formatAmount(bill.amountCents, bill.currency)}
          </span>
        </div>

        <div className="detail-row">
          <span className="detail-label">Due Date</span>
          <span className="detail-value">{formatDate(bill.dueDate)}</span>
        </div>

        <div className="detail-row">
          <span className="detail-label">Category</span>
          <span className="detail-value">
            {getCategoryIcon(bill.category)} {bill.category}
          </span>
        </div>

        <div className="detail-row">
          <span className="detail-label">Status</span>
          <span className={`status-badge status-${status}`}>
            {status.replace('-', ' ')}
          </span>
        </div>

        <div className="detail-row">
          <span className="detail-label">Recurrence</span>
          <span className="detail-value">{bill.recurrence}</span>
        </div>

        {bill.notes && (
          <div className="detail-row">
            <span className="detail-label">Notes</span>
            <span className="detail-value">{bill.notes}</span>
          </div>
        )}
      </div>
    </div>
  );
}

function LoginScreen({ onLogin }: { onLogin: () => void }) {
  const [pin, setPin] = useState('');
  const [error, setError] = useState('');

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (authenticate(pin)) {
      onLogin();
    } else {
      setError('Invalid PIN. Please enter a 4-digit code.');
      setPin('');
    }
  };

  return (
    <div className="login">
      <h1>Chronicle</h1>
      <p>Enter your 4-digit PIN to access your bills</p>

      <form className="login-form" onSubmit={handleSubmit}>
        <input
          type="password"
          className="pin-input"
          value={pin}
          onChange={(e) => setPin(e.target.value.replace(/\D/g, '').slice(0, 4))}
          placeholder="••••"
          maxLength={4}
          autoFocus
        />

        {error && <div className="error">{error}</div>}

        <button type="submit" className="btn btn-primary" disabled={pin.length !== 4}>
          Sign In
        </button>
      </form>
    </div>
  );
}

function Dashboard({ summary, bills }: { summary: Summary; bills: Bill[] }) {
  const [categoryTotals, setCategoryTotals] = useState<Record<string, number>>({});

  useEffect(() => {
    const totals: Record<string, number> = {};
    bills.forEach((bill) => {
      if (!bill.isPaid) {
        totals[bill.category] = (totals[bill.category] || 0) + bill.amountCents;
      }
    });
    setCategoryTotals(totals);
  }, [bills]);

  const maxTotal = Math.max(...Object.values(categoryTotals), 1);
  const sortedCategories = Object.entries(categoryTotals).sort((a, b) => b[1] - a[1]);

  return (
    <div>
      <div className="summary">
        <div className="summary-card highlight">
          <div className="summary-label">Due This Month</div>
          <div className="summary-value" style={{ color: 'var(--accent)' }}>
            {formatAmount(parseInt(summary.totalDueThisMonth) || 0)}
          </div>
        </div>
        <div className="summary-card">
          <div className="summary-label">Paid This Month</div>
          <div className="summary-value" style={{ color: 'var(--success)' }}>
            {formatAmount(parseInt(summary.totalPaidThisMonth) || 0)}
          </div>
        </div>
        <div className="summary-card">
          <div className="summary-label">Upcoming</div>
          <div className="summary-value">{summary.upcomingCount}</div>
        </div>
        <div className="summary-card">
          <div className="summary-label">Paid</div>
          <div className="summary-value">{summary.paidCount}</div>
        </div>
      </div>

      <div className="chart-section">
        <h3>Spending by Category</h3>
        {sortedCategories.length === 0 ? (
          <div className="empty-state">
            <div className="icon">📊</div>
            <p>No unpaid bills to display</p>
          </div>
        ) : (
          sortedCategories.map(([category, total]) => (
            <div key={category} className="category-bar">
              <span className="category-icon">{getCategoryIcon(category)}</span>
              <span className="category-name">{category}</span>
              <div className="bar-track">
                <div
                  className="bar-fill"
                  style={{ width: `${(total / maxTotal) * 100}%` }}
                />
              </div>
              <span className="category-amount">{formatAmount(total)}</span>
            </div>
          ))
        )}
      </div>
    </div>
  );
}

function BillsList({
  bills,
  onSelectBill,
}: {
  bills: Bill[];
  onSelectBill: (bill: Bill) => void;
}) {
  const [search, setSearch] = useState('');
  const [filter, setFilter] = useState<'all' | 'unpaid' | 'paid'>('all');

  const filteredBills = bills.filter((bill) => {
    const matchesSearch = bill.name.toLowerCase().includes(search.toLowerCase());
    if (filter === 'unpaid') return matchesSearch && !bill.isPaid;
    if (filter === 'paid') return matchesSearch && bill.isPaid;
    return matchesSearch;
  });

  return (
    <div>
      <div className="filters">
        <input
          type="text"
          className="search-input"
          placeholder="Search bills..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />

        <div className="filter-row">
          <button
            className={`filter-btn ${filter === 'all' ? 'active' : ''}`}
            onClick={() => setFilter('all')}
          >
            All
          </button>
          <button
            className={`filter-btn ${filter === 'unpaid' ? 'active' : ''}`}
            onClick={() => setFilter('unpaid')}
          >
            Unpaid
          </button>
          <button
            className={`filter-btn ${filter === 'paid' ? 'active' : ''}`}
            onClick={() => setFilter('paid')}
          >
            Paid
          </button>
        </div>
      </div>

      {filteredBills.length === 0 ? (
        <div className="empty-state">
          <div className="icon">📋</div>
          <p>No bills found</p>
        </div>
      ) : (
        <div className="bills-list">
          {filteredBills.map((bill) => {
            const status = getBillStatus(bill);
            return (
              <div
                key={bill.id}
                className={`bill-card ${bill.isPaid ? 'paid' : ''}`}
                onClick={() => onSelectBill(bill)}
              >
                <div className="bill-header">
                  <span className="bill-name">
                    {getCategoryIcon(bill.category)} {bill.name}
                  </span>
                  <span className="bill-amount">
                    {formatAmount(bill.amountCents, bill.currency)}
                  </span>
                </div>
                <div className="bill-meta">
                  <span>Due {formatDate(bill.dueDate)}</span>
                  <span className={`status-badge status-${status}`}>
                    {status.replace('-', ' ')}
                  </span>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}

export default function App() {
  const [activeTab, setActiveTab] = useState<Tab>('dashboard');
  const [summary, setSummary] = useState<Summary | null>(null);
  const [bills, setBills] = useState<Bill[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [selectedBill, setSelectedBill] = useState<Bill | null>(null);
  const [loggedIn, setLoggedIn] = useState(() => isAuthenticated());

  useEffect(() => {
    if (loggedIn) {
      loadData();
    }
  }, [loggedIn]);

  const loadData = async () => {
    setLoading(true);
    setError('');
    try {
      const [summaryData, billsData] = await Promise.all([
        getSummary(),
        getBills(),
      ]);
      setSummary(summaryData);
      setBills(billsData);
    } catch (err) {
      setError('Unable to connect to Chronicle. Make sure the app is running.');
    } finally {
      setLoading(false);
    }
  };

  const handleLogout = () => {
    logout();
    setLoggedIn(false);
  };

  if (!loggedIn) {
    return <LoginScreen onLogin={() => setLoggedIn(true)} />;
  }

  return (
    <div className="app">
      <header className="header">
        <h1>Chronicle</h1>
        <div className="header-actions">
          <button className="icon-btn" onClick={loadData} title="Refresh">
            ↻
          </button>
          <button className="icon-btn" onClick={handleLogout} title="Sign Out">
            ⏻
          </button>
        </div>
      </header>

      {error && <div className="error">{error}</div>}

      <div className="tabs">
        <button
          className={`tab ${activeTab === 'dashboard' ? 'active' : ''}`}
          onClick={() => setActiveTab('dashboard')}
        >
          Dashboard
        </button>
        <button
          className={`tab ${activeTab === 'bills' ? 'active' : ''}`}
          onClick={() => setActiveTab('bills')}
        >
          Bills
        </button>
      </div>

      {loading ? (
        <div className="loading">Loading</div>
      ) : (
        <>
          {activeTab === 'dashboard' && summary && (
            <Dashboard summary={summary} bills={bills} />
          )}
          {activeTab === 'bills' && (
            <BillsList bills={bills} onSelectBill={setSelectedBill} />
          )}
        </>
      )}

      {selectedBill && (
        <BillDetail bill={selectedBill} onClose={() => setSelectedBill(null)} />
      )}
    </div>
  );
}

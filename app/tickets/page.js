'use client';

/* ============================================================
   SmartFix — Support Tickets page
   Wired to GET /api/tickets (paginated, filterable). Row click
   opens the message thread (customer / admin / bot) with a reply
   composer (POST /api/tickets/[id]/messages, senderRole 'admin')
   and status / priority controls (PATCH /api/tickets/[id]).
   Falls back to a local seed so the dashboard always renders.
   ============================================================ */
import React, { useState, useEffect, useMemo } from 'react';
import { fetchWithTimeout } from '@/lib/fetchWithTimeout';
import { SF } from '@/components/sf/data';
import { useT } from '@/components/sf/i18n';
import { Icon } from '@/components/sf/Icon';
import {
  StatCard, SectionHead, DataTable, SearchBox, Select, Modal, Avatar, Loading,
} from '@/components/sf/ui';

const TS = SF.TICKET_STATUS_CONFIG;        // open / pending / resolved / closed
const TP = SF.TICKET_PRIORITY_CONFIG;      // low / medium / high

// Ticket categories are their own taxonomy (separate from service categories).
const TICKET_CATEGORIES = {
  general:         'General',
  payment:         'Payment',
  service_quality: 'Service Quality',
  technician:      'Technician',
  account:         'Account',
  complaint:       'Complaint',
  other:           'Other',
};

// Arabic labels for the ticket categories (resolved at render time via t()).
const TICKET_CATEGORIES_AR = {
  general:         'عام',
  payment:         'الدفع',
  service_quality: 'جودة الخدمة',
  technician:      'الفني',
  account:         'الحساب',
  complaint:       'شكوى',
  other:           'أخرى',
};

// Resolve a ticket category to its localised label using the page's t().
const catLabel = (t, key) =>
  TICKET_CATEGORIES[key]
    ? t(TICKET_CATEGORIES[key], TICKET_CATEGORIES_AR[key] || TICKET_CATEGORIES[key])
    : (key || t('General', 'عام'));

const fmtDate = (s) => s ? new Date(s).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' }) : '—';
const fmtTime = (s) => s ? new Date(s).toLocaleString('en-GB', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' }) : '';

// Local seed so the page renders even with no DB connected.
const SEED_TICKETS = [
  {
    _id: 'seed_1', ticketId: 'TKT-7K2M9X', customerName: 'Mona Adel', customerId: 'c1',
    subject: 'Payment was charged twice', category: 'payment', status: 'open', priority: 'high',
    source: 'manual', createdAt: '2026-06-12T09:10:00Z', updatedAt: '2026-06-13T14:30:00Z',
    messages: [
      { _id: 'm1', senderRole: 'customer', senderName: 'Mona Adel', text: 'I was charged twice for the same plumbing job. Please refund the extra amount.', at: '2026-06-12T09:10:00Z' },
      { _id: 'm2', senderRole: 'admin', senderName: 'Support', text: 'Thank you for reaching out. We are reviewing the transaction and will get back to you shortly.', at: '2026-06-13T14:30:00Z' },
    ],
  },
  {
    _id: 'seed_2', ticketId: 'TKT-3D8F1A', customerName: 'Karim Hassan', customerId: 'c2',
    subject: 'Technician did not show up', category: 'technician', status: 'pending', priority: 'medium',
    source: 'chatbot', createdAt: '2026-06-11T16:45:00Z', updatedAt: '2026-06-11T16:50:00Z',
    messages: [
      { _id: 'm3', senderRole: 'customer', senderName: 'Karim Hassan', text: 'The assigned technician never arrived for my AC repair appointment.', at: '2026-06-11T16:45:00Z' },
      { _id: 'm4', senderRole: 'bot', senderName: 'SmartFix Assistant', text: 'I am sorry for the inconvenience. I have escalated this to our support team.', at: '2026-06-11T16:50:00Z' },
    ],
  },
  {
    _id: 'seed_3', ticketId: 'TKT-9P4Q2C', customerName: 'Sara Mahmoud', customerId: 'c3',
    subject: 'How do I change my saved address?', category: 'account', status: 'resolved', priority: 'low',
    source: 'manual', createdAt: '2026-06-09T11:20:00Z', updatedAt: '2026-06-09T12:05:00Z',
    messages: [
      { _id: 'm5', senderRole: 'customer', senderName: 'Sara Mahmoud', text: 'I moved to a new apartment and need to update my address.', at: '2026-06-09T11:20:00Z' },
      { _id: 'm6', senderRole: 'admin', senderName: 'Support', text: 'You can update it under Profile → Addresses. Let me know if you need help.', at: '2026-06-09T12:05:00Z' },
    ],
  },
];

const ROLE_META = {
  customer: { label: 'Customer', labelAr: 'العميل',   icon: 'User',  color: '#3b82f6' },
  admin:    { label: 'Support',  labelAr: 'الدعم',     icon: 'Headset', color: 'var(--accent)' },
  bot:      { label: 'Assistant', labelAr: 'المساعد', icon: 'Bot',   color: '#10b981' },
};

function Pill({ cfg }) {
  const c = cfg || { label: '—', color: '#64748b' };
  return React.createElement('span', { className: 'badge badge-soft', style: { background: `${c.color}1f`, color: c.color, border: `1px solid ${c.color}40` } },
    React.createElement('span', { className: 'bdot', style: { background: c.color } }), c.label);
}

function ThreadModal({ ticket, onClose, onReply, onPatch }) {
  const t = useT();
  const [text, setText] = useState('');
  const [status, setStatus] = useState(ticket.status || 'open');
  const [priority, setPriority] = useState(ticket.priority || 'medium');
  const [category, setCategory] = useState(ticket.category || 'general');
  const [linkedId, setLinkedId] = useState(ticket.relatedIssueId || '');
  const [issues, setIssues] = useState([]);
  const messages = Array.isArray(ticket.messages) ? ticket.messages : [];

  // Load service requests so the admin can link this ticket to one; linking a
  // request that has an assigned worker fills the ticket's worker column.
  useEffect(() => {
    let alive = true;
    fetchWithTimeout('/api/issues?limit=200', { cache: 'no-store' })
      .then(r => (r.ok ? r.json() : null))
      .then(d => { if (alive && d && Array.isArray(d.issues)) setIssues(d.issues); })
      .catch(() => {});
    return () => { alive = false; };
  }, []);

  const send = () => {
    const t = text.trim();
    if (!t) return;
    onReply(ticket, t);
    setText('');
  };
  const changeStatus = (v) => { setStatus(v); onPatch(ticket, { status: v }); };
  const changePriority = (v) => { setPriority(v); onPatch(ticket, { priority: v }); };
  const changeCategory = (v) => { setCategory(v); onPatch(ticket, { category: v }); };
  const changeLinked = (v) => { setLinkedId(v); onPatch(ticket, { relatedIssueId: v }); };

  const issueNum = ticket.relatedIssueNumber || (ticket.relatedIssue && ticket.relatedIssue.issueNumber) || '';
  const workerName = ticket.technicianName || (ticket.relatedIssue && ticket.relatedIssue.assignedTechnicianName) || '';
  return React.createElement(Modal, {
    title: `${ticket.ticketId || t('Ticket', 'البلاغ')} · ${ticket.subject || ''}`,
    sub: [
      ticket.customerName || t('Customer', 'العميل'),
      catLabel(t, ticket.category),
      issueNum ? `${t('Issue', 'الطلب')} ${issueNum}` : null,
      workerName ? `${t('Worker', 'الفني')}: ${workerName}` : null,
    ].filter(Boolean).join('  ·  '),
    onClose, wide: true,
    footer: React.createElement('div', { style: { display: 'flex', alignItems: 'center', gap: 10, width: '100%' } },
      React.createElement('input', {
        className: 'input', value: text, onChange: (e) => setText(e.target.value),
        onKeyDown: (e) => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); send(); } },
        placeholder: t('Type a reply as Support…', 'اكتب ردًا بصفة الدعم…'), style: { flex: 1 },
      }),
      React.createElement('button', { className: 'btn btn-primary', disabled: !text.trim(), onClick: send },
        React.createElement(Icon, { name: 'Send', size: 16 }), t('Send', 'إرسال'))),
  },
    // Controls: status + priority
    React.createElement('div', { className: 'form-grid', style: { marginBottom: 16 } },
      React.createElement('div', { className: 'field' },
        React.createElement('label', null, t('Status', 'الحالة')),
        React.createElement(Select, { value: status, onChange: changeStatus, icon: 'Activity',
          options: Object.keys(TS).map(k => ({ value: k, label: TS[k].label })) })),
      React.createElement('div', { className: 'field' },
        React.createElement('label', null, t('Priority', 'الأولوية')),
        React.createElement(Select, { value: priority, onChange: changePriority, icon: 'Flag',
          options: Object.keys(TP).map(k => ({ value: k, label: TP[k].label })) })),
      React.createElement('div', { className: 'field' },
        React.createElement('label', null, t('Category', 'الفئة')),
        React.createElement(Select, { value: category, onChange: changeCategory, icon: 'Tag',
          options: Object.keys(TICKET_CATEGORIES).map(k => ({ value: k, label: catLabel(t, k) })) })),
      React.createElement('div', { className: 'field' },
        React.createElement('label', null, t('Related Request (sets worker)', 'الطلب المرتبط (يحدّد الفني)')),
        React.createElement(Select, { value: linkedId, onChange: changeLinked, icon: 'Link',
          options: [
            { value: '', label: t('Not linked', 'غير مرتبط') },
            ...issues.map(i => ({
              value: i._id,
              label: `${i.issueNumber || ('#' + String(i._id).slice(-6))}${i.assignedTechnicianName ? '  ·  ' + i.assignedTechnicianName : '  ·  ' + t('no worker', 'بدون فني')}`,
            })),
          ] }))),

    // Message thread
    React.createElement('div', { style: { display: 'flex', flexDirection: 'column', gap: 12, maxHeight: 360, overflowY: 'auto', paddingRight: 4 } },
      messages.length === 0
        ? React.createElement('div', { style: { color: 'var(--text-3)', fontSize: 13, textAlign: 'center', padding: '24px 0' } }, t('No messages in this ticket yet.', 'لا توجد رسائل في هذا البلاغ بعد.'))
        : messages.map((m, i) => {
            const rm = ROLE_META[m.senderRole] || { label: m.senderRole, labelAr: m.senderRole, icon: 'User', color: '#64748b' };
            const mine = m.senderRole === 'admin';
            return React.createElement('div', { key: m._id || i, style: { display: 'flex', flexDirection: 'column', alignItems: mine ? 'flex-end' : 'flex-start', gap: 4 } },
              React.createElement('div', { style: { display: 'flex', alignItems: 'center', gap: 6, fontSize: 11.5, fontWeight: 700, color: rm.color } },
                React.createElement(Icon, { name: rm.icon, size: 13 }),
                m.senderName || t(rm.label, rm.labelAr || rm.label),
                React.createElement('span', { style: { color: 'var(--text-3)', fontWeight: 400, marginLeft: 4 } }, fmtTime(m.at))),
              React.createElement('div', {
                style: {
                  maxWidth: '78%', padding: '9px 13px', borderRadius: 12, fontSize: 13.5, lineHeight: 1.5,
                  background: mine ? 'var(--accent)' : `${rm.color}14`,
                  color: mine ? '#fff' : 'var(--text-1)',
                  border: mine ? 'none' : `1px solid ${rm.color}26`,
                  borderBottomRightRadius: mine ? 3 : 12, borderBottomLeftRadius: mine ? 12 : 3,
                },
              }, m.text || ''),
              Array.isArray(m.attachments) && m.attachments.length > 0 &&
                React.createElement('div', { style: { display: 'flex', flexWrap: 'wrap', gap: 6, maxWidth: '78%', justifyContent: mine ? 'flex-end' : 'flex-start' } },
                  m.attachments.map((a, ai) => React.createElement('a', {
                    key: ai, href: a, target: '_blank', rel: 'noreferrer',
                    className: 'badge badge-soft',
                    style: { display: 'inline-flex', alignItems: 'center', gap: 5, fontSize: 11.5, textDecoration: 'none', color: rm.color, background: `${rm.color}14`, border: `1px solid ${rm.color}26`, padding: '4px 8px', borderRadius: 8 },
                  },
                    React.createElement(Icon, { name: 'Paperclip', size: 12 }),
                    (typeof a === 'string' ? a.split('/').pop() : '') || t('Attachment', 'مرفق'))))
            );
          })
    ));
}

function NewTicketModal({ onClose, onCreate }) {
  const t = useT();
  const blank = { subject: '', customerName: '', customerId: '', category: 'general', priority: 'medium', relatedIssueId: '', message: '' };
  const [form, setForm] = useState(blank);
  const [saving, setSaving] = useState(false);
  const [err, setErr] = useState('');
  const set = (k, v) => setForm(f => ({ ...f, [k]: v }));
  const valid = (form.subject || '').trim() && (form.customerName || '').trim() && (form.message || '').trim();

  const submit = async () => {
    if (!valid || saving) return;
    setSaving(true); setErr('');
    try {
      await onCreate({
        subject: form.subject.trim(),
        customerName: form.customerName.trim(),
        customerId: (form.customerId || '').trim() || undefined,
        category: form.category,
        priority: form.priority,
        relatedIssueId: (form.relatedIssueId || '').trim() || undefined,
        source: 'manual',
        message: form.message.trim(),
      });
    } catch (e) {
      setErr(e?.message || t('Could not create the ticket. Please try again.', 'تعذّر إنشاء البلاغ. حاول مرة أخرى.'));
      setSaving(false);
    }
  };

  return React.createElement(Modal, {
    title: t('New Ticket', 'بلاغ جديد'),
    sub: t('Open a support ticket on behalf of a customer', 'افتح بلاغ دعم نيابةً عن عميل'),
    onClose, wide: true,
    footer: React.createElement(React.Fragment, null,
      err && React.createElement('span', { style: { color: '#ef4444', fontSize: 12.5, marginRight: 'auto' } }, err),
      React.createElement('button', { className: 'btn btn-ghost', onClick: onClose }, t('Cancel', 'إلغاء')),
      React.createElement('button', { className: 'btn btn-primary', disabled: !valid || saving, onClick: submit },
        React.createElement(Icon, { name: 'Plus', size: 16 }), saving ? t('Creating…', 'جارٍ الإنشاء…') : t('Create Ticket', 'إنشاء البلاغ'))),
  },
    React.createElement('div', { className: 'form-grid' },
      React.createElement('div', { className: 'field', style: { gridColumn: '1 / -1' } },
        React.createElement('label', null, t('Subject ', 'الموضوع '), React.createElement('span', { className: 'req' }, '*')),
        React.createElement('input', { className: 'input', value: form.subject, onChange: (e) => set('subject', e.target.value), placeholder: t('e.g. Payment was charged twice', 'مثال: تم خصم المبلغ مرتين') })),
      React.createElement('div', { className: 'field' },
        React.createElement('label', null, t('Customer Name ', 'اسم العميل '), React.createElement('span', { className: 'req' }, '*')),
        React.createElement('input', { className: 'input', value: form.customerName, onChange: (e) => set('customerName', e.target.value), placeholder: t('e.g. Mona Adel', 'مثال: منى عادل') })),
      React.createElement('div', { className: 'field' },
        React.createElement('label', null, t('Customer ID', 'معرّف العميل')),
        React.createElement('input', { className: 'input', value: form.customerId, onChange: (e) => set('customerId', e.target.value), placeholder: t('Optional', 'اختياري') })),
      React.createElement('div', { className: 'field' },
        React.createElement('label', null, t('Category', 'الفئة')),
        React.createElement(Select, { value: form.category, onChange: (v) => set('category', v), icon: 'Tag',
          options: Object.keys(TICKET_CATEGORIES).map(k => ({ value: k, label: catLabel(t, k) })) })),
      React.createElement('div', { className: 'field' },
        React.createElement('label', null, t('Priority', 'الأولوية')),
        React.createElement(Select, { value: form.priority, onChange: (v) => set('priority', v), icon: 'Flag',
          options: Object.keys(TP).map(k => ({ value: k, label: TP[k].label })) })),
      React.createElement('div', { className: 'field', style: { gridColumn: '1 / -1' } },
        React.createElement('label', null, t('Related Issue ID / Number', 'معرّف/رقم الطلب المرتبط')),
        React.createElement('input', { className: 'input', value: form.relatedIssueId, onChange: (e) => set('relatedIssueId', e.target.value), placeholder: t('Optional — link this ticket to an issue', 'اختياري — اربط البلاغ بطلب') })),
      React.createElement('div', { className: 'field', style: { gridColumn: '1 / -1' } },
        React.createElement('label', null, t('First Message ', 'الرسالة الأولى '), React.createElement('span', { className: 'req' }, '*')),
        React.createElement('textarea', { className: 'input', value: form.message, rows: 4, onChange: (e) => set('message', e.target.value), placeholder: t('Describe the customer\'s issue…', 'صف مشكلة العميل…'), style: { resize: 'vertical', minHeight: 90 } }))
    ));
}

export default function TicketsPage() {
  const t = useT();
  const [tickets, setTickets] = useState([]);
  const [loading, setLoading] = useState(true);
  const [live, setLive] = useState(false);
  const [q, setQ] = useState('');
  const [status, setStatus] = useState('all');
  const [priority, setPriority] = useState('all');
  const [open, setOpen] = useState(null); // ticket object
  const [newOpen, setNewOpen] = useState(false);

  // Load tickets from the live API; fall back to the seed on error / empty.
  useEffect(() => {
    let active = true;
    const load = async () => {
      try {
        const res = await fetchWithTimeout('/api/tickets?limit=200', { cache: 'no-store' });
        if (!res.ok) return;
        const data = await res.json();
        const arr = Array.isArray(data) ? data : (data.tickets || data.items || []);
        if (active) { setTickets(arr); setLive(true); }
      } catch { /* keep the seed fallback */ }
      finally { if (active) setLoading(false); }
    };
    load();
    const t = setInterval(load, 6000);
    return () => { active = false; clearInterval(t); };
  }, []);

  const counts = useMemo(() => {
    const c = { open: 0, pending: 0, resolved: 0, closed: 0 };
    tickets.forEach(t => { if (c[t.status] != null) c[t.status]++; });
    return c;
  }, [tickets]);

  const filtered = useMemo(() => tickets.filter(t =>
    (q === '' ||
      (t.subject || '').toLowerCase().includes(q.toLowerCase()) ||
      (t.ticketId || '').toLowerCase().includes(q.toLowerCase()) ||
      (t.customerName || '').toLowerCase().includes(q.toLowerCase())) &&
    (status === 'all' || t.status === status) &&
    (priority === 'all' || t.priority === priority)
  ), [tickets, q, status, priority]);

  // Optimistic reply; the poll reconciles with Mongo afterwards.
  const reply = (ticket, text) => {
    const id = ticket._id;
    const msg = { _id: 'tmp_' + Date.now(), senderRole: 'admin', senderName: 'Support', text, at: new Date().toISOString() };
    const apply = (tk) => ({ ...tk, messages: [...(tk.messages || []), msg], updatedAt: msg.at });
    setTickets(list => list.map(t => t._id === id ? apply(t) : t));
    setOpen(o => (o && o._id === id) ? apply(o) : o);
    fetch(`/api/tickets/${id}/messages`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ senderRole: 'admin', senderName: 'Support', text }),
    }).catch(() => {});
  };

  const patch = (ticket, fields) => {
    const id = ticket._id;
    const apply = (tk) => ({ ...tk, ...fields, updatedAt: new Date().toISOString() });
    setTickets(list => list.map(t => t._id === id ? apply(t) : t));
    setOpen(o => (o && o._id === id) ? apply(o) : o);
    fetch(`/api/tickets/${id}`, {
      method: 'PATCH', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(fields),
    })
      .then(r => (r.ok ? r.json() : null))
      .then(srv => {
        // The server denormalizes fields like technicianName / relatedIssueNumber
        // (e.g. after linking a request). Merge the canonical doc back in.
        if (!srv || srv.error) return;
        const merge = (tk) => ({ ...tk, ...srv });
        setTickets(list => list.map(t => t._id === id ? merge(t) : t));
        setOpen(o => (o && o._id === id) ? merge(o) : o);
      })
      .catch(() => {});
  };

  // Create a new ticket via the API and prepend the returned document.
  const createTicket = async (payload) => {
    const res = await fetch('/api/tickets', {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload),
    });
    if (!res.ok) {
      let msg = t('Could not create the ticket. Please try again.', 'تعذّر إنشاء البلاغ. حاول مرة أخرى.');
      try { const d = await res.json(); if (d?.error) msg = d.error; } catch { /* ignore parse error */ }
      throw new Error(msg);
    }
    const ticket = await res.json();
    setTickets(list => [ticket, ...list]);
    setLive(true);
    setNewOpen(false);
  };

  const allOpt = (label) => ({ value: 'all', label });
  const columns = [
    { key: 'ticketId', label: t('Ticket', 'البلاغ'), width: 130, render: (r) => React.createElement('div', null,
      React.createElement('div', { className: 'cell-primary', style: { fontFamily: 'var(--mono, monospace)', fontSize: 12.5 } }, r.ticketId || '—'),
      React.createElement('div', { className: 'cell-sub' }, r.source === 'chatbot' ? t('Chatbot', 'روبوت الدردشة') : t('Manual', 'يدوي'))) },
    { key: 'subject', label: t('Subject', 'الموضوع'), width: 250, render: (r) => React.createElement('div', null,
      React.createElement('div', { className: 'cell-primary' }, r.subject || '—'),
      React.createElement('div', { className: 'cell-sub', style: { display: 'flex', alignItems: 'center', gap: 5 } },
        React.createElement(Icon, { name: 'MessageSquare', size: 12, color: 'var(--text-3)' }),
        `${(r.messages || []).length} ${(r.messages || []).length === 1 ? t('message', 'رسالة') : t('messages', 'رسائل')}`)) },
    { key: 'customerName', label: t('Customer', 'العميل'), hideSm: true, render: (r) => React.createElement('div', { style: { display: 'flex', alignItems: 'center', gap: 9 } },
      React.createElement(Avatar, { name: r.customerName || 'Customer' }),
      React.createElement('span', { className: 'cell-muted' }, r.customerName || '—')) },
    { key: 'category', label: t('Category', 'الفئة'), hideSm: true, render: (r) => React.createElement('span', { className: 'cell-muted' }, catLabel(t, r.category)) },
    { key: 'relatedIssue', label: t('Related Issue', 'الطلب المرتبط'), hideSm: true, sortable: false, render: (r) => {
      const num = r.relatedIssueNumber || (r.relatedIssue && r.relatedIssue.issueNumber) || '';
      const id = r.relatedIssueId || '';
      if (!num && !id) return React.createElement('span', { className: 'cell-sub', style: { color: 'var(--text-3)' } }, '—');
      return React.createElement('span', { className: 'badge badge-soft', style: { fontFamily: 'var(--mono, monospace)', fontSize: 11.5 } }, num || `#${id.slice(-6)}`);
    } },
    { key: 'worker', label: t('Worker', 'الفني'), hideSm: true, sortable: false, render: (r) => {
      const w = r.technicianName || (r.relatedIssue && r.relatedIssue.assignedTechnicianName) || '';
      return w
        ? React.createElement('div', { style: { display: 'flex', alignItems: 'center', gap: 8 } },
            React.createElement(Avatar, { name: w }),
            React.createElement('span', { className: 'cell-muted' }, w))
        : React.createElement('span', { className: 'cell-sub', style: { color: 'var(--text-3)' } }, t('Unassigned', 'غير مُعيّن'));
    } },
    { key: 'priority', label: t('Priority', 'الأولوية'), sortAccessor: (r) => ['low', 'medium', 'high'].indexOf(r.priority), render: (r) => React.createElement(Pill, { cfg: TP[r.priority] }) },
    { key: 'status', label: t('Status', 'الحالة'), render: (r) => React.createElement(Pill, { cfg: TS[r.status] }) },
    { key: 'updatedAt', label: t('Updated', 'آخر تحديث'), hideSm: true, render: (r) => React.createElement('span', { className: 'cell-sub', style: { fontSize: 12.5 } }, fmtDate(r.updatedAt || r.createdAt)) },
    { key: 'actions', label: '', sortable: false, align: 'right', render: (r) => React.createElement('button', { className: 'act-btn', title: t('Open thread', 'فتح المحادثة'), onClick: () => setOpen(r) }, React.createElement(Icon, { name: 'MessageSquare', size: 15 })) },
  ];

  if (loading && !live && tickets.length === 0) {
    return React.createElement(Loading, { text: t('Loading support tickets…', 'جارٍ تحميل بلاغات الدعم…') });
  }

  return React.createElement('div', { className: 'page-anim' },
    React.createElement('div', { className: 'stat-grid grid-4' },
      React.createElement(StatCard, { icon: 'Inbox', label: t('Open', 'مفتوح'), value: counts.open, tone: 'primary', delay: 0 }),
      React.createElement(StatCard, { icon: 'Clock', label: t('Pending', 'قيد الانتظار'), value: counts.pending, tone: 'warning', delay: 50 }),
      React.createElement(StatCard, { icon: 'CircleCheck', label: t('Resolved', 'تم الحل'), value: counts.resolved, tone: 'success', delay: 100 }),
      React.createElement(StatCard, { icon: 'LifeBuoy', label: t('Total Tickets', 'إجمالي البلاغات'), value: tickets.length, tone: 'cyan', delay: 150 })
    ),

    React.createElement(SectionHead, { icon: 'LifeBuoy', title: t('Support Tickets', 'بلاغات الدعم'), sub: `· ${filtered.length} ${t('shown', 'معروض')}`,
      right: React.createElement('div', { style: { display: 'inline-flex', alignItems: 'center', gap: 10 } },
        live && React.createElement('span', { title: t('Reading live data from the app backend', 'يقرأ بيانات حيّة من خادم التطبيق'), style: { display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 11.5, fontWeight: 700, letterSpacing: 0.4, color: '#0e9f6e', background: 'rgba(16,185,129,0.12)', padding: '4px 10px', borderRadius: 999 } },
          React.createElement('span', { style: { width: 7, height: 7, borderRadius: 999, background: '#10b981', display: 'inline-block' } }), t('LIVE', 'مباشر')),
        React.createElement('button', { className: 'btn btn-primary', onClick: () => setNewOpen(true) },
          React.createElement(Icon, { name: 'Plus', size: 16 }), t('New Ticket', 'بلاغ جديد'))) }),

    React.createElement('div', { className: 'toolbar' },
      React.createElement(SearchBox, { value: q, onChange: setQ, placeholder: t('Search subject, ticket id or customer…', 'ابحث في الموضوع أو رقم البلاغ أو العميل…') }),
      React.createElement(Select, { value: status, onChange: setStatus, icon: 'Activity', options: [allOpt(t('All Statuses', 'كل الحالات')), ...Object.keys(TS).map(k => ({ value: k, label: TS[k].label }))] }),
      React.createElement(Select, { value: priority, onChange: setPriority, icon: 'Flag', options: [allOpt(t('All Priorities', 'كل الأولويات')), ...Object.keys(TP).map(k => ({ value: k, label: TP[k].label }))] }),
      (q || status !== 'all' || priority !== 'all') && React.createElement('button', { className: 'btn btn-ghost btn-sm', onClick: () => { setQ(''); setStatus('all'); setPriority('all'); } }, React.createElement(Icon, { name: 'X', size: 14 }), t('Clear', 'مسح'))
    ),

    React.createElement(DataTable, { columns, rows: filtered, pageSize: 8, initialSort: { key: 'updatedAt', dir: 'desc' }, emptyTitle: t('No tickets found', 'لا توجد بلاغات'), emptySub: t('Support tickets from customers and the chatbot will appear here.', 'ستظهر هنا بلاغات الدعم من العملاء وروبوت الدردشة.') }),

    open && React.createElement(ThreadModal, { ticket: open, onClose: () => setOpen(null), onReply: reply, onPatch: patch }),

    newOpen && React.createElement(NewTicketModal, { onClose: () => setNewOpen(false), onCreate: createTicket })
  );
}

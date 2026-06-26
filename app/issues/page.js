'use client';

/* ============================================================
   SmartFix — Issues Management page
   ============================================================ */
import React, { useState, useEffect, useMemo } from 'react';
import { fetchWithTimeout } from '@/lib/fetchWithTimeout';
import { SF } from '@/components/sf/data';
import { Icon } from '@/components/sf/Icon';
import {
  StatCard, SectionHead, DataTable, SearchBox, Select, StatusSelect,
  CatChip, UrgencyBadge, Modal,
} from '@/components/sf/ui';
import { useT } from '@/components/sf/i18n';

const fmtDate = (s) => new Date(s).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });

function IssueModal({ issue, onClose, onSave, technicians = [] }) {
  const t = useT();
  const blank = { title: '', description: '', category: 'plumbing', urgency: 'medium', status: 'pending', city: 'Cairo', customerName: '', customerEmail: '', customerPhone: '', address: '', estimatedCost: '', assignedTechnicianId: '', assignedTechnicianName: '' };
  const [form, setForm] = useState(issue || blank);
  const set = (k, v) => setForm(f => ({ ...f, [k]: v }));
  // Selecting a technician keeps id + name in sync; "Unassigned" clears both.
  const setTechnician = (id) => {
    const tech = technicians.find(x => x._id === id);
    setForm(f => ({ ...f, assignedTechnicianId: tech ? tech._id : '', assignedTechnicianName: tech ? tech.name : '' }));
  };
  const valid = form.title.trim() && form.customerName.trim();
  return React.createElement(Modal, {
    title: issue ? t('Edit Issue', 'تعديل البلاغ') : t('Create New Issue', 'إنشاء بلاغ جديد'),
    sub: issue ? `${t('Updating', 'تحديث')} ${issue.title}` : t('Log a new maintenance request', 'تسجيل طلب صيانة جديد'),
    onClose, wide: true,
    footer: React.createElement(React.Fragment, null,
      React.createElement('button', { className: 'btn btn-ghost', onClick: onClose }, t('Cancel', 'إلغاء')),
      React.createElement('button', { className: 'btn btn-primary', disabled: !valid, onClick: () => onSave(form) },
        React.createElement(Icon, { name: 'Check', size: 16 }), issue ? t('Save Changes', 'حفظ التغييرات') : t('Create Issue', 'إنشاء البلاغ'))),
  },
    React.createElement('div', { className: 'form-grid' },
      React.createElement('div', { className: 'field col-2' },
        React.createElement('label', null, t('Issue Title', 'عنوان البلاغ'), ' ', React.createElement('span', { className: 'req' }, '*')),
        React.createElement('input', { className: 'input', value: form.title, onChange: (e) => set('title', e.target.value), placeholder: t('e.g. Leaking kitchen faucet', 'مثال: تسريب في حنفية المطبخ') })),
      React.createElement('div', { className: 'field col-2' },
        React.createElement('label', null, t('Description', 'الوصف')),
        React.createElement('textarea', { className: 'textarea', value: form.description, onChange: (e) => set('description', e.target.value), placeholder: t('Describe the problem…', 'صف المشكلة…') })),
      React.createElement('div', { className: 'field' },
        React.createElement('label', null, t('Category', 'الفئة')),
        React.createElement(Select, { value: form.category, onChange: (v) => set('category', v), options: SF.CATEGORIES.map(c => ({ value: c, label: SF.CATEGORY_CONFIG[c].label })) })),
      React.createElement('div', { className: 'field' },
        React.createElement('label', null, t('Urgency', 'الأولوية')),
        React.createElement(Select, { value: form.urgency, onChange: (v) => set('urgency', v), options: Object.keys(SF.URGENCY_CONFIG).map(u => ({ value: u, label: SF.URGENCY_CONFIG[u].label })) })),
      React.createElement('div', { className: 'field' },
        React.createElement('label', null, t('Status', 'الحالة')),
        React.createElement(Select, { value: form.status, onChange: (v) => set('status', v), options: Object.keys(SF.STATUS_CONFIG).map(s => ({ value: s, label: SF.STATUS_CONFIG[s].label })) })),
      React.createElement('div', { className: 'field' },
        React.createElement('label', null, t('Assigned Technician', 'الفني المُسند')),
        React.createElement(Select, { value: form.assignedTechnicianId || '', onChange: setTechnician, icon: 'UserCheck', options: [{ value: '', label: t('Unassigned', 'غير مُسند') }, ...technicians.map(tech => ({ value: tech._id, label: tech.name }))] })),
      React.createElement('div', { className: 'field' },
        React.createElement('label', null, t('City', 'المدينة')),
        React.createElement(Select, { value: form.city, onChange: (v) => set('city', v), options: SF.CITIES.map(c => ({ value: c, label: c })) })),
      React.createElement('div', { className: 'field' },
        React.createElement('label', null, t('Customer Name', 'اسم العميل'), ' ', React.createElement('span', { className: 'req' }, '*')),
        React.createElement('input', { className: 'input', value: form.customerName, onChange: (e) => set('customerName', e.target.value), placeholder: t('Full name', 'الاسم الكامل') })),
      React.createElement('div', { className: 'field' },
        React.createElement('label', null, t('Estimated Cost (EGP)', 'التكلفة التقديرية (ج.م)')),
        React.createElement('input', { className: 'input', type: 'number', value: form.estimatedCost, onChange: (e) => set('estimatedCost', e.target.value), placeholder: '0' })),
      React.createElement('div', { className: 'field' },
        React.createElement('label', null, t('Customer Email', 'بريد العميل الإلكتروني')),
        React.createElement('input', { className: 'input', value: form.customerEmail, onChange: (e) => set('customerEmail', e.target.value), placeholder: 'name@email.com' })),
      React.createElement('div', { className: 'field' },
        React.createElement('label', null, t('Customer Phone', 'هاتف العميل')),
        React.createElement('input', { className: 'input', value: form.customerPhone, onChange: (e) => set('customerPhone', e.target.value), placeholder: '+20…' })),
      React.createElement('div', { className: 'field col-2' },
        React.createElement('label', null, t('Address', 'العنوان')),
        React.createElement('input', { className: 'input', value: form.address, onChange: (e) => set('address', e.target.value), placeholder: t('Street, district, city', 'الشارع، الحي، المدينة') }))
    ));
}

export default function IssuesPage() {
  const t = useT();
  const [issues, setIssues] = useState([]);
  const [live, setLive] = useState(false);
  const [q, setQ] = useState('');
  const [cat, setCat] = useState('all');
  const [status, setStatus] = useState('all');
  const [urgency, setUrgency] = useState('all');
  const [modal, setModal] = useState(null); // null | 'new' | issueObj
  const [toDelete, setToDelete] = useState(null);
  const [err, setErr] = useState('');
  const [technicians, setTechnicians] = useState([]);
  const [assignTarget, setAssignTarget] = useState(null); // { id } awaiting a technician to enter "assigned"
  const [assignTechId, setAssignTechId] = useState('');

  // ── Live sync ──────────────────────────────────────────────────────
  // Read issues from the same Mongo-backed API the mobile app writes to, and
  // poll so an issue reported on the phone appears here within seconds. Falls
  // back to the seed data if the backend isn't reachable (page is never empty).
  useEffect(() => {
    let active = true;
    const load = async () => {
      try {
        // High limit so the table reflects the full queue instead of the API's
        // default page size of 20.
        const res = await fetchWithTimeout('/api/issues?limit=1000', { cache: 'no-store' });
        if (!res.ok) return;
        const data = await res.json();
        const arr = Array.isArray(data) ? data : (data.issues || []);
        if (active) { setIssues(arr); setLive(true); }
      } catch { /* keep the seed-data fallback */ }
    };
    load();
    const t = setInterval(load, 4000);
    return () => { active = false; clearInterval(t); };
  }, []);

  // Load the technician roster once so the assign Selects can be populated.
  useEffect(() => {
    let active = true;
    fetchWithTimeout('/api/technicians?limit=1000', { cache: 'no-store' })
      .then(res => res.ok ? res.json() : null)
      .then(data => {
        if (!active || !data) return;
        const arr = Array.isArray(data) ? data : (data.technicians || []);
        setTechnicians(arr);
      })
      .catch(() => { /* assign Selects fall back to "Unassigned" only */ });
    return () => { active = false; };
  }, []);

  const counts = useMemo(() => {
    const c = { pending: 0, assigned: 0, inProgress: 0, completed: 0 };
    issues.forEach(i => { if (c[i.status] != null) c[i.status]++; });
    return c;
  }, [issues]);

  const filtered = useMemo(() => issues.filter(i =>
    (q === '' || (i.title || '').toLowerCase().includes(q.toLowerCase()) || (i.customerName || '').toLowerCase().includes(q.toLowerCase())) &&
    (cat === 'all' || i.category === cat) &&
    (status === 'all' || i.status === status) &&
    (urgency === 'all' || i.urgency === urgency)
  ), [issues, q, cat, status, urgency]);

  // Writes go to the same API (optimistic UI; the 4s poll reconciles with Mongo,
  // so dashboard edits are visible to the app on its next fetch — and vice versa).
  // Push a status change (optionally with a technician assignment) to the API,
  // reverting the optimistic update and surfacing the reason on failure.
  const pushStatus = (id, newStatus, tech) => {
    const before = issues.find(i => i._id === id);
    const prevStatus = before?.status;
    const prevTechId = before?.assignedTechnicianId || '';
    const prevTechName = before?.assignedTechnicianName || '';
    const patch = { status: newStatus };
    if (tech) { patch.assignedTechnicianId = tech.id; patch.assignedTechnicianName = tech.name; }
    setIssues(list => list.map(i => i._id === id ? { ...i, ...patch } : i));
    fetch(`/api/issues/${id}`, { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(patch) })
      .then(async (res) => {
        if (!res.ok) {
          const data = await res.json().catch(() => ({}));
          // Server rejected the transition — revert the optimistic change and surface the reason.
          setIssues(list => list.map(i => i._id === id ? { ...i, status: prevStatus, assignedTechnicianId: prevTechId, assignedTechnicianName: prevTechName } : i));
          setErr(data.error || t('Could not update the issue status.', 'تعذّر تحديث حالة البلاغ.'));
        }
      })
      .catch(() => {
        setIssues(list => list.map(i => i._id === id ? { ...i, status: prevStatus, assignedTechnicianId: prevTechId, assignedTechnicianName: prevTechName } : i));
        setErr(t('Could not update the issue status.', 'تعذّر تحديث حالة البلاغ.'));
      });
  };
  const updateStatus = (id, newStatus) => {
    // Moving a row to "assigned" requires a technician. If none is set yet,
    // prompt the admin to pick one before sending the update.
    if (newStatus === 'assigned') {
      const row = issues.find(i => i._id === id);
      if (!row?.assignedTechnicianId) { setAssignTarget({ id }); setAssignTechId(''); return; }
    }
    pushStatus(id, newStatus);
  };
  const confirmAssign = () => {
    if (!assignTarget || !assignTechId) return;
    const tech = technicians.find(x => x._id === assignTechId);
    if (!tech) return;
    pushStatus(assignTarget.id, 'assigned', { id: tech._id, name: tech.name });
    setAssignTarget(null);
    setAssignTechId('');
  };
  const saveIssue = (form) => {
    setModal(null);
    const payload = {
      ...form,
      estimatedCost: Number(form.estimatedCost) || 0,
      // Normalize the assignment: empty (Unassigned) clears both fields.
      assignedTechnicianId: form.assignedTechnicianId || '',
      assignedTechnicianName: form.assignedTechnicianId ? (form.assignedTechnicianName || '') : '',
    };
    if (form._id) {
      setIssues(list => list.map(i => i._id === form._id ? { ...i, ...payload } : i));
      fetch(`/api/issues/${form._id}`, { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) }).catch(() => {});
    } else {
      const tempId = 'tmp_' + Date.now();
      setIssues(list => [{ ...payload, _id: tempId, createdAt: new Date().toISOString() }, ...list]);
      fetch('/api/issues', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) }).catch(() => {});
    }
  };
  const removeIssue = (id) => {
    setIssues(list => list.filter(i => i._id !== id));
    setToDelete(null);
    fetch(`/api/issues/${id}`, { method: 'DELETE' }).catch(() => {});
  };

  const allOpt = (label) => ({ value: 'all', label });
  const columns = [
    { key: 'title', label: t('Issue', 'البلاغ'), width: 230, render: (r) => React.createElement('div', null,
      React.createElement('div', { className: 'cell-primary', style: { display: 'flex', alignItems: 'center', gap: 7 } }, r.title,
        r.urgency === 'emergency' && React.createElement('span', { className: 'badge', style: { background: 'var(--danger)', color: '#fff', padding: '2px 7px', fontSize: 10 } }, 'SOS')),
      React.createElement('div', { className: 'cell-sub' }, `${r.estimatedCost ? 'EGP ' + r.estimatedCost.toLocaleString() : '—'}`)) },
    { key: 'customerName', label: t('Customer', 'العميل'), hideSm: true, render: (r) => React.createElement('div', null,
      React.createElement('div', { className: 'cell-muted' }, r.customerName),
      React.createElement('div', { className: 'cell-sub' }, r.customerPhone)) },
    { key: 'category', label: t('Category', 'الفئة'), render: (r) => React.createElement(CatChip, { cat: r.category, small: true }) },
    { key: 'urgency', label: t('Urgency', 'الأولوية'), sortAccessor: (r) => ['low', 'medium', 'high', 'emergency'].indexOf(r.urgency), render: (r) => React.createElement(UrgencyBadge, { urgency: r.urgency }) },
    { key: 'status', label: t('Status', 'الحالة'), render: (r) => React.createElement(StatusSelect, { value: r.status, onChange: (v) => updateStatus(r._id, v) }) },
    { key: 'assignedTechnicianName', label: t('Assigned To', 'مُسند إلى'), hideSm: true, render: (r) => r.assignedTechnicianName ? React.createElement('span', { className: 'cell-muted' }, r.assignedTechnicianName) : React.createElement('span', { className: 'unassigned' }, t('Unassigned', 'غير مُسند')) },
    { key: 'city', label: t('City', 'المدينة'), hideSm: true, render: (r) => React.createElement('span', { className: 'cell-muted', style: { display: 'flex', alignItems: 'center', gap: 5 } }, React.createElement(Icon, { name: 'MapPin', size: 13, color: 'var(--text-3)' }), r.city) },
    { key: 'createdAt', label: t('Date', 'التاريخ'), hideSm: true, render: (r) => React.createElement('span', { className: 'cell-sub', style: { fontSize: 12.5 } }, fmtDate(r.createdAt)) },
    { key: 'actions', label: '', sortable: false, align: 'right', render: (r) => React.createElement('div', { className: 'row-actions', style: { justifyContent: 'flex-end' } },
      React.createElement('button', { className: 'act-btn', title: t('Edit', 'تعديل'), onClick: () => setModal(r) }, React.createElement(Icon, { name: 'Pencil', size: 15 })),
      React.createElement('button', { className: 'act-btn danger', title: t('Delete', 'حذف'), onClick: () => setToDelete(r) }, React.createElement(Icon, { name: 'Trash2', size: 15 }))) },
  ];

  return React.createElement('div', { className: 'page-anim' },
    err && React.createElement('div', { role: 'alert', 'data-testid': 'issue-error',
      style: { display: 'flex', alignItems: 'center', gap: 10, marginBottom: 12, padding: '11px 14px', borderRadius: 10, background: 'rgba(239,68,68,0.12)', border: '1px solid rgba(239,68,68,0.35)', color: 'var(--danger)', fontSize: 13.5, fontWeight: 600 } },
      React.createElement(Icon, { name: 'TriangleAlert', size: 16 }),
      React.createElement('span', { style: { flex: 1 } }, err),
      React.createElement('button', { className: 'act-btn', title: t('Dismiss', 'إغلاق'), onClick: () => setErr('') }, React.createElement(Icon, { name: 'X', size: 14 }))),
    React.createElement('div', { className: 'stat-grid grid-4', style: { gridTemplateColumns: 'repeat(5,1fr)' } },
      React.createElement(StatCard, { icon: 'Clock', label: t('Pending', 'قيد الانتظار'), value: counts.pending, tone: 'warning', delay: 0 }),
      React.createElement(StatCard, { icon: 'UserCheck', label: t('Assigned', 'مُسند'), value: counts.assigned, tone: 'primary', delay: 50 }),
      React.createElement(StatCard, { icon: 'Loader', label: t('In Progress', 'قيد التنفيذ'), value: counts.inProgress, tone: 'cyan', delay: 100 }),
      React.createElement(StatCard, { icon: 'CircleCheck', label: t('Completed', 'مكتمل'), value: counts.completed, tone: 'success', delay: 150 }),
      React.createElement(StatCard, { icon: 'Layers', label: t('Total Issues', 'إجمالي البلاغات'), value: issues.length, tone: 'primary', delay: 200 })
    ),

    React.createElement(SectionHead, { icon: 'TriangleAlert', title: t('Issue Queue', 'قائمة البلاغات'), sub: `· ${filtered.length} ${t('shown', 'معروض')}`,
      right: React.createElement('div', { style: { display: 'flex', alignItems: 'center', gap: 10 } },
        live && React.createElement('span', { title: t('Reading live data from the app backend', 'قراءة بيانات حية من خادم التطبيق'), style: { display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 11.5, fontWeight: 700, letterSpacing: 0.4, color: '#0e9f6e', background: 'rgba(16,185,129,0.12)', padding: '4px 10px', borderRadius: 999 } },
          React.createElement('span', { style: { width: 7, height: 7, borderRadius: 999, background: '#10b981', display: 'inline-block' } }), t('LIVE', 'مباشر')),
        React.createElement('button', { className: 'btn btn-primary', onClick: () => setModal('new') }, React.createElement(Icon, { name: 'Plus', size: 16 }), t('New Issue', 'بلاغ جديد'))) }),

    React.createElement('div', { className: 'toolbar' },
      React.createElement(SearchBox, { value: q, onChange: setQ, placeholder: t('Search title or customer…', 'ابحث بالعنوان أو العميل…') }),
      React.createElement(Select, { value: cat, onChange: setCat, icon: 'Layers', options: [allOpt(t('All Categories', 'كل الفئات')), ...SF.CATEGORIES.map(c => ({ value: c, label: SF.CATEGORY_CONFIG[c].label }))] }),
      React.createElement(Select, { value: status, onChange: setStatus, icon: 'Activity', options: [allOpt(t('All Statuses', 'كل الحالات')), ...Object.keys(SF.STATUS_CONFIG).map(s => ({ value: s, label: SF.STATUS_CONFIG[s].label }))] }),
      React.createElement(Select, { value: urgency, onChange: setUrgency, icon: 'Flame', options: [allOpt(t('All Urgencies', 'كل الأولويات')), ...Object.keys(SF.URGENCY_CONFIG).map(u => ({ value: u, label: SF.URGENCY_CONFIG[u].label }))] }),
      (q || cat !== 'all' || status !== 'all' || urgency !== 'all') && React.createElement('button', { className: 'btn btn-ghost btn-sm', onClick: () => { setQ(''); setCat('all'); setStatus('all'); setUrgency('all'); } }, React.createElement(Icon, { name: 'X', size: 14 }), t('Clear', 'مسح'))
    ),

    React.createElement(DataTable, { columns, rows: filtered, pageSize: 8, initialSort: { key: 'urgency', dir: 'desc' }, emptyTitle: t('No issues match', 'لا توجد بلاغات مطابقة'), emptySub: t('Try adjusting filters or search terms.', 'حاول تعديل عوامل التصفية أو كلمات البحث.') }),

    modal && React.createElement(IssueModal, { issue: modal === 'new' ? null : modal, onClose: () => setModal(null), onSave: saveIssue, technicians }),
    assignTarget && React.createElement(Modal, { title: t('Assign Technician', 'إسناد فني'), sub: t('Choose a technician to set this issue as assigned.', 'اختر فنياً لتعيين هذا البلاغ كمُسند.'), onClose: () => { setAssignTarget(null); setAssignTechId(''); },
      footer: React.createElement(React.Fragment, null,
        React.createElement('button', { className: 'btn btn-ghost', onClick: () => { setAssignTarget(null); setAssignTechId(''); } }, t('Cancel', 'إلغاء')),
        React.createElement('button', { className: 'btn btn-primary', disabled: !assignTechId, onClick: confirmAssign }, React.createElement(Icon, { name: 'UserCheck', size: 15 }), t('Assign', 'إسناد'))) },
      React.createElement('div', { className: 'field' },
        React.createElement('label', null, t('Technician', 'الفني'), ' ', React.createElement('span', { className: 'req' }, '*')),
        React.createElement(Select, { value: assignTechId, onChange: setAssignTechId, icon: 'UserCheck', options: [{ value: '', label: t('Select a technician…', 'اختر فنياً…') }, ...technicians.map(tech => ({ value: tech._id, label: tech.name }))] }))),
    toDelete && React.createElement(Modal, { title: t('Delete Issue', 'حذف البلاغ'), sub: toDelete.title, onClose: () => setToDelete(null),
      footer: React.createElement(React.Fragment, null,
        React.createElement('button', { className: 'btn btn-ghost', onClick: () => setToDelete(null) }, t('Cancel', 'إلغاء')),
        React.createElement('button', { className: 'btn btn-danger', onClick: () => removeIssue(toDelete._id) }, React.createElement(Icon, { name: 'Trash2', size: 15 }), t('Delete', 'حذف'))) },
      React.createElement('p', { style: { color: 'var(--text-2)', fontSize: 14, lineHeight: 1.6 } }, t('This will permanently remove the issue from the queue. This action cannot be undone.', 'سيؤدي هذا إلى حذف البلاغ نهائياً من القائمة. لا يمكن التراجع عن هذا الإجراء.')))
  );
}

'use client';

/* ============================================================
   SmartFix — Users Management page
   ============================================================ */
import React, { useState, useMemo, useEffect } from 'react';
import { fetchWithTimeout } from '@/lib/fetchWithTimeout';
import { SF } from '@/components/sf/data';
import { Icon } from '@/components/sf/Icon';
import {
  StatCard, SectionHead, DataTable, SearchBox, Select,
  CatChip, VerifiedBadge, Toggle, Modal, Avatar,
} from '@/components/sf/ui';
import { useT } from '@/components/sf/i18n';

function RoleBadge({ role }) {
  const t = useT();
  const cfg = role === 'worker' ? { c: 'var(--accent-2)', i: 'Wrench', l: t('Worker', 'فني') } : { c: 'var(--accent)', i: 'User', l: t('Customer', 'عميل') };
  return React.createElement('span', { className: 'badge badge-soft', style: { background: `${cfg.c}1f`, color: cfg.c, border: `1px solid ${cfg.c}40` } },
    React.createElement(Icon, { name: cfg.i, size: 12 }), cfg.l);
}

function UserModal({ user, onClose, onSave }) {
  const t = useT();
  const blank = { name: '', email: '', phone: '', role: 'customer', city: 'Cairo', skills: [], isVerified: false };
  const [form, setForm] = useState(user || blank);
  const [saving, setSaving] = useState(false);
  const [err, setErr] = useState('');
  const set = (k, v) => { setForm(f => ({ ...f, [k]: v })); setErr(''); };
  const toggleSkill = (s) => set('skills', form.skills.includes(s) ? form.skills.filter(x => x !== s) : [...form.skills, s]);
  const valid = form.name.trim() && form.email.trim();
  const submit = async () => {
    setSaving(true);
    setErr('');
    const errMsg = await onSave(form);
    if (errMsg) { setErr(errMsg); setSaving(false); }
    // on success the parent unmounts this modal
  };
  return React.createElement(Modal, {
    title: user ? t('Edit User', 'تعديل المستخدم') : t('Add User', 'إضافة مستخدم'),
    sub: user ? form.name : t('Create a customer or worker account', 'إنشاء حساب عميل أو فني'),
    onClose, wide: true,
    footer: React.createElement(React.Fragment, null,
      React.createElement('button', { className: 'btn btn-ghost', onClick: onClose }, t('Cancel', 'إلغاء')),
      React.createElement('button', { className: 'btn btn-primary', disabled: !valid || saving, onClick: submit }, React.createElement(Icon, { name: 'Check', size: 16 }), user ? t('Save Changes', 'حفظ التغييرات') : t('Add User', 'إضافة مستخدم'))),
  },
    React.createElement('div', { className: 'form-grid' },
      err && React.createElement('div', { className: 'field col-2', style: { color: 'var(--danger, #ef4444)', background: 'rgba(239,68,68,0.10)', border: '1px solid rgba(239,68,68,0.30)', borderRadius: 10, padding: '10px 12px', fontSize: 13, display: 'flex', alignItems: 'center', gap: 8 } },
        React.createElement(Icon, { name: 'TriangleAlert', size: 15 }), err),
      React.createElement('div', { className: 'field' },
        React.createElement('label', null, t('Full Name', 'الاسم الكامل'), ' ', React.createElement('span', { className: 'req' }, '*')),
        React.createElement('input', { className: 'input', value: form.name, onChange: (e) => set('name', e.target.value), placeholder: t('Full name', 'الاسم الكامل') })),
      React.createElement('div', { className: 'field' },
        React.createElement('label', null, t('Role', 'الدور')),
        React.createElement(Select, { value: form.role, onChange: (v) => set('role', v), options: [{ value: 'customer', label: t('Customer', 'عميل') }, { value: 'worker', label: t('Worker', 'فني') }] })),
      React.createElement('div', { className: 'field' },
        React.createElement('label', null, t('Email', 'البريد الإلكتروني'), ' ', React.createElement('span', { className: 'req' }, '*')),
        React.createElement('input', { className: 'input', value: form.email, onChange: (e) => set('email', e.target.value), placeholder: 'name@email.com' })),
      React.createElement('div', { className: 'field' },
        React.createElement('label', null, t('Phone', 'رقم الهاتف')),
        React.createElement('input', { className: 'input', value: form.phone, onChange: (e) => set('phone', e.target.value), placeholder: '+20…' })),
      React.createElement('div', { className: 'field col-2' },
        React.createElement('label', null, t('City', 'المدينة')),
        React.createElement(Select, { value: form.city, onChange: (v) => set('city', v), options: SF.CITIES.map(c => ({ value: c, label: c })) })),
      form.role === 'worker' && React.createElement('div', { className: 'field col-2' },
        React.createElement('label', null, t('Worker Skills', 'مهارات الفني')),
        React.createElement('div', { className: 'chip-select' },
          SF.CATEGORIES.map(s => React.createElement('button', { key: s, className: `skill-chip ${form.skills.includes(s) ? 'on' : ''}`, onClick: () => toggleSkill(s) },
            React.createElement(Icon, { name: SF.CATEGORY_CONFIG[s].icon, size: 13 }), SF.CATEGORY_CONFIG[s].label)))),
      React.createElement('div', { className: 'field col-2' },
        React.createElement('div', { className: 'field-row' },
          React.createElement('div', null,
            React.createElement('div', { className: 'fr-label' }, t('Verified Account', 'حساب موثّق')),
            React.createElement('div', { className: 'fr-sub' }, t('Identity confirmed via OTP / documents', 'تم تأكيد الهوية عبر رمز التحقق / المستندات'))),
          React.createElement(Toggle, { on: form.isVerified, onChange: (v) => set('isVerified', v) })))
    ));
}

export default function UsersPage() {
  const t = useT();
  const [users, setUsers] = useState([]);
  const [live, setLive] = useState(false);
  const [q, setQ] = useState('');

  // Live sync: read the same Mongo-backed API the mobile app writes to on
  // sign-up/sign-in, so real accounts (incl. the demo users) show here. Falls
  // back to the seed data if the backend isn't reachable.
  useEffect(() => {
    let active = true;
    const load = async () => {
      try {
        const res = await fetchWithTimeout('/api/users?limit=1000', { cache: 'no-store' });
        if (!res.ok) return;
        const data = await res.json();
        const arr = (Array.isArray(data) ? data : (data.users || [])).map(u => ({
          ...u,
          phone: u.phone || '',
          city: u.city || '—',
          skills: Array.isArray(u.skills) ? u.skills : [],
          isVerified: !!u.isVerified,
        }));
        if (active) { setUsers(arr); setLive(true); }
      } catch { /* keep seed-data fallback */ }
    };
    load();
    const t = setInterval(load, 5000);
    return () => { active = false; clearInterval(t); };
  }, []);
  const [role, setRole] = useState('all');
  const [modal, setModal] = useState(null);
  const [toDelete, setToDelete] = useState(null);

  const filtered = useMemo(() => users.filter(u =>
    (q === '' || u.name.toLowerCase().includes(q.toLowerCase()) || u.email.toLowerCase().includes(q.toLowerCase()) || u.phone.includes(q)) &&
    (role === 'all' || u.role === role)
  ), [users, q, role]);

  const stats = useMemo(() => ({
    total: users.length,
    customers: users.filter(u => u.role === 'customer').length,
    workers: users.filter(u => u.role === 'worker').length,
    verified: users.filter(u => u.isVerified).length,
  }), [users]);

  // Returns an error string (to surface in the modal) or null/undefined on success.
  const saveUser = async (form) => {
    if (form._id) {
      const { _id, ...payload } = form;
      const prev = users;
      setUsers(list => list.map(u => u._id === form._id ? form : u));
      // Persist to the same Mongo-backed API so edits (e.g. verification) survive a reload.
      try {
        const res = await fetch(`/api/users/${_id}`, { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) });
        if (!res.ok) {
          const data = await res.json().catch(() => ({}));
          setUsers(prev); // revert optimistic update
          return data.error || t('Could not save changes', 'تعذّر حفظ التغييرات');
        }
      } catch {
        setUsers(prev);
        return t('Could not save changes', 'تعذّر حفظ التغييرات');
      }
      setModal(null);
      return null;
    }

    // Admin Add User: create-or-409 — do NOT fabricate an id, use the real one.
    try {
      const res = await fetch('/api/users', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ ...form, source: 'admin' }) });
      const data = await res.json().catch(() => ({}));
      if (res.status === 409) {
        return t('A user with this email already exists', 'يوجد مستخدم بهذا البريد الإلكتروني بالفعل');
      }
      if (!res.ok) {
        return data.error || t('Could not add user', 'تعذّرت إضافة المستخدم');
      }
      // Insert with the REAL returned document (incl. its _id and createdAt).
      const created = { ...form, ...data, skills: Array.isArray(data.skills) ? data.skills : (form.skills || []) };
      setUsers(list => [created, ...list]);
    } catch {
      return t('Could not add user', 'تعذّرت إضافة المستخدم');
    }
    setModal(null);
    return null;
  };
  const removeUser = (id) => {
    setUsers(list => list.filter(u => u._id !== id));
    setToDelete(null);
    fetch(`/api/users/${id}`, { method: 'DELETE' }).catch(() => {});
  };
  const allOpt = (l) => ({ value: 'all', label: l });

  const columns = [
    { key: 'name', label: t('User', 'المستخدم'), width: 220, render: (r) => React.createElement('div', { className: 'name-cell' },
      React.createElement(Avatar, { name: r.name }),
      React.createElement('div', null,
        React.createElement('div', { className: 'cell-primary' }, r.name),
        React.createElement('div', { className: 'cell-sub' }, r.email))) },
    { key: 'phone', label: t('Phone', 'رقم الهاتف'), hideSm: true, render: (r) => React.createElement('span', { className: 'id-mono' }, r.phone) },
    { key: 'role', label: t('Role', 'الدور'), render: (r) => React.createElement(RoleBadge, { role: r.role }) },
    { key: 'city', label: t('City', 'المدينة'), hideSm: true, render: (r) => React.createElement('span', { className: 'cell-muted' }, r.city) },
    { key: 'skills', label: t('Skills', 'المهارات'), sortable: false, render: (r) => r.role === 'worker' && r.skills.length
      ? React.createElement('div', { style: { display: 'flex', gap: 4, flexWrap: 'wrap' } },
          r.skills.slice(0, 2).map(s => React.createElement(CatChip, { key: s, cat: s, small: true })),
          r.skills.length > 2 && React.createElement('span', { className: 'badge', style: { background: 'var(--surface-2)', color: 'var(--text-2)' } }, `+${r.skills.length - 2}`))
      : React.createElement('span', { className: 'unassigned' }, '—') },
    { key: 'isVerified', label: t('Verified', 'موثّق'), sortAccessor: (r) => r.isVerified ? 1 : 0, render: (r) => React.createElement(VerifiedBadge, { verified: r.isVerified }) },
    { key: 'actions', label: '', sortable: false, align: 'right', render: (r) => React.createElement('div', { className: 'row-actions', style: { justifyContent: 'flex-end' } },
      React.createElement('button', { className: 'act-btn', title: t('Edit', 'تعديل'), onClick: () => setModal(r) }, React.createElement(Icon, { name: 'Pencil', size: 15 })),
      React.createElement('button', { className: 'act-btn danger', title: t('Delete', 'حذف'), onClick: () => setToDelete(r) }, React.createElement(Icon, { name: 'Trash2', size: 15 }))) },
  ];

  return React.createElement('div', { className: 'page-anim' },
    React.createElement('div', { className: 'stat-grid grid-4' },
      React.createElement(StatCard, { icon: 'UsersRound', label: t('Total Users', 'إجمالي المستخدمين'), value: stats.total, tone: 'primary', delay: 0 }),
      React.createElement(StatCard, { icon: 'User', label: t('Customers', 'العملاء'), value: stats.customers, tone: 'cyan', delay: 50 }),
      React.createElement(StatCard, { icon: 'Wrench', label: t('Workers', 'الفنيون'), value: stats.workers, tone: 'warning', delay: 100 }),
      React.createElement(StatCard, { icon: 'BadgeCheck', label: t('Verified', 'الموثّقون'), value: stats.verified, tone: 'success', delay: 150 })
    ),

    React.createElement(SectionHead, { icon: 'UserRound', title: t('User Accounts', 'حسابات المستخدمين'), sub: t(`· ${filtered.length} shown`, `· ${filtered.length} معروض`),
      right: React.createElement('div', { style: { display: 'flex', alignItems: 'center', gap: 10 } },
        live && React.createElement('span', { title: t('Reading live accounts from the app backend', 'قراءة الحسابات المباشرة من خادم التطبيق'), style: { display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 11.5, fontWeight: 700, letterSpacing: 0.4, color: '#0e9f6e', background: 'rgba(16,185,129,0.12)', padding: '4px 10px', borderRadius: 999 } },
          React.createElement('span', { style: { width: 7, height: 7, borderRadius: 999, background: '#10b981', display: 'inline-block' } }), t('LIVE', 'مباشر')),
        React.createElement('button', { className: 'btn btn-primary', onClick: () => setModal('new') }, React.createElement(Icon, { name: 'Plus', size: 16 }), t('Add User', 'إضافة مستخدم'))) }),

    React.createElement('div', { className: 'toolbar' },
      React.createElement(SearchBox, { value: q, onChange: setQ, placeholder: t('Search name, email or phone…', 'ابحث بالاسم أو البريد أو الهاتف…') }),
      React.createElement(Select, { value: role, onChange: setRole, icon: 'UserCog', options: [allOpt(t('All Roles', 'كل الأدوار')), { value: 'customer', label: t('Customers', 'العملاء') }, { value: 'worker', label: t('Workers', 'الفنيون') }] }),
      (q || role !== 'all') && React.createElement('button', { className: 'btn btn-ghost btn-sm', onClick: () => { setQ(''); setRole('all'); } }, React.createElement(Icon, { name: 'X', size: 14 }), t('Clear', 'مسح'))
    ),

    React.createElement(DataTable, { columns, rows: filtered, pageSize: 8, initialSort: { key: 'name', dir: 'asc' }, emptyTitle: t('No users found', 'لا يوجد مستخدمون'), emptySub: t('Adjust your search or add a new user.', 'عدّل بحثك أو أضف مستخدمًا جديدًا.') }),

    modal && React.createElement(UserModal, { user: modal === 'new' ? null : modal, onClose: () => setModal(null), onSave: saveUser }),
    toDelete && React.createElement(Modal, { title: t('Delete User', 'حذف المستخدم'), sub: toDelete.name, onClose: () => setToDelete(null),
      footer: React.createElement(React.Fragment, null,
        React.createElement('button', { className: 'btn btn-ghost', onClick: () => setToDelete(null) }, t('Cancel', 'إلغاء')),
        React.createElement('button', { className: 'btn btn-danger', onClick: () => removeUser(toDelete._id) }, React.createElement(Icon, { name: 'Trash2', size: 15 }), t('Delete', 'حذف'))) },
      React.createElement('p', { style: { color: 'var(--text-2)', fontSize: 14, lineHeight: 1.6 } }, t(`Permanently delete ${toDelete.name}'s account? This cannot be undone.`, `هل تريد حذف حساب ${toDelete.name} نهائيًا؟ لا يمكن التراجع عن هذا الإجراء.`)))
  );
}

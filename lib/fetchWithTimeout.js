// Shared client-side fetch wrapper that aborts after `timeoutMs` instead of
// hanging on the browser default (~50s). This is what keeps the dashboard from
// piling up stuck polling requests when the API/DB is slow or down — a timed-out
// request fails fast so each page keeps its seed/fallback data.
//
// It also broadcasts a coarse reachability signal (`sf:netstatus`) that the
// topbar "System Online" chip listens to, so connectivity failures become
// visible instead of silently showing stale data.
export async function fetchWithTimeout(url, options = {}, timeoutMs = 7000) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(url, { ...options, signal: controller.signal });
    notifyNetStatus(true);
    return res;
  } catch (e) {
    notifyNetStatus(false);
    throw e;
  } finally {
    clearTimeout(timer);
  }
}

function notifyNetStatus(online) {
  if (typeof window === 'undefined') return;
  try {
    window.dispatchEvent(new CustomEvent('sf:netstatus', { detail: { online } }));
  } catch { /* CustomEvent unsupported — ignore */ }
}

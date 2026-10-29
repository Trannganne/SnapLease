/* Layout-only behavior. Search destinations are navigation shortcuts, not API results. */
(() => {
  'use strict';
  const ready = () => {
    const toggle = document.getElementById('sl-sidebar-toggle');
    const backdrop = document.getElementById('sl-app-backdrop');
    const narrow = () => window.matchMedia('(max-width: 991.98px)').matches;
    const updateToggle = () => toggle?.setAttribute('aria-expanded', String(narrow() ? document.body.classList.contains('sl-sidebar-open') : !document.body.classList.contains('sl-sidebar-collapsed')));
    try { if (localStorage.getItem('sl-sidebar-collapsed') === 'true' && !narrow()) document.body.classList.add('sl-sidebar-collapsed'); } catch (_) { /* storage may be blocked */ }
    toggle?.addEventListener('click', () => {
      if (narrow()) document.body.classList.toggle('sl-sidebar-open');
      else {
        document.body.classList.toggle('sl-sidebar-collapsed');
        try { localStorage.setItem('sl-sidebar-collapsed', String(document.body.classList.contains('sl-sidebar-collapsed'))); } catch (_) {}
      }
      updateToggle();
    });
    backdrop?.addEventListener('click', () => { document.body.classList.remove('sl-sidebar-open'); updateToggle(); });
    window.addEventListener('resize', () => { document.body.classList.remove('sl-sidebar-open'); updateToggle(); });
    document.addEventListener('keydown', (event) => {
      if (event.key === 'Escape') { document.body.classList.remove('sl-sidebar-open'); hideSearch(); updateToggle(); }
      if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'k') { event.preventDefault(); document.getElementById('globalSearch')?.focus(); }
    });
    updateToggle();

    const input = document.getElementById('globalSearch');
    const results = document.getElementById('sl-search-results');
    const clear = document.getElementById('sl-search-clear');
    let debounce;
    function hideSearch() { if (results) results.hidden = true; input?.setAttribute('aria-expanded', 'false'); }
    function renderSearch() {
      if (!input || !results) return;
      const query = input.value.trim();
      if (clear) clear.hidden = query.length === 0;
      if (!query) { hideSearch(); return; }
      results.replaceChildren();
      const heading = document.createElement('div'); heading.className = 'sl-search-message'; heading.textContent = 'Lối tắt đến trang quản lý (chưa phải kết quả tìm kiếm API)'; results.append(heading);
      const links = [
        { title: 'Quản lý thiết bị', url: '/ThietBi?search=' + encodeURIComponent(query), detail: 'Mở trang thiết bị để tìm kiếm' },
        { title: 'Quản lý đơn thuê', url: '/DonThue?search=' + encodeURIComponent(query), detail: 'Mở trang đơn thuê để tìm kiếm' },
        { title: 'Quản lý khách hàng', url: '/KhachHang?search=' + encodeURIComponent(query), detail: 'Mở trang khách hàng để tìm kiếm' }
      ];
      links.forEach(item => { const a = document.createElement('a'); a.href = item.url; a.setAttribute('role', 'option'); a.textContent = item.title; const small = document.createElement('small'); small.textContent = item.detail; a.append(small); results.append(a); });
      results.hidden = false; input.setAttribute('aria-expanded', 'true');
    }
    input?.addEventListener('input', () => { clearTimeout(debounce); debounce = setTimeout(renderSearch, 200); });
    input?.addEventListener('focus', renderSearch);
    clear?.addEventListener('click', () => { input.value = ''; clear.hidden = true; hideSearch(); input.focus(); });
    document.addEventListener('click', (event) => { if (!event.target.closest('.sl-header-search')) hideSearch(); });
  };
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', ready); else ready();
})();

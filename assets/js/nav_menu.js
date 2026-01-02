document.addEventListener('DOMContentLoaded', () => {
  const menuToggle = document.getElementById('menu-toggle');
  const mobileMenu = document.getElementById('mobile-menu');
  const menuOverlay = document.getElementById('menu-overlay');
  const searchInput = document.getElementById('menu-search');
  const closeBtn = mobileMenu?.querySelector('[data-close-btn]');
  const body = document.body;
  const focusables = mobileMenu.querySelectorAll('a, button, input, select, textarea');
  const line1 = document.getElementById('line-1');
  const line2 = document.getElementById('line-2');
  const line3 = document.getElementById('line-3');

  if (!menuToggle || !mobileMenu || !menuOverlay) return;

  const isOpen = () => mobileMenu.classList.contains('translate-x-0');

  /* ------------------------
     Event Handlers
  ------------------------ */

  const onEscape = (e) => {
    if (e.key === 'Escape') closeMenu();
  };

  const onOverlayClick = () => closeMenu();

  const onSearchKey = (e) => {
    if (e.key !== 'Enter') return;

    const query = e.target.value.trim();
    if (!query) return;

    window.location.href =
      `{{ '/search-recipes/' | relative_url }}?q=${encodeURIComponent(query)}`;
  };

  /* ------------------------
     Listener Management
  ------------------------ */

  const addMenuListeners = () => {
    document.addEventListener('keydown', onEscape);
    menuOverlay.addEventListener('click', onOverlayClick);
    closeBtn?.addEventListener('click', closeMenu);
    searchInput?.addEventListener('keydown', onSearchKey);
  };

  const removeMenuListeners = () => {
    document.removeEventListener('keydown', onEscape);
    menuOverlay.removeEventListener('click', onOverlayClick);
    closeBtn?.removeEventListener('click', closeMenu);
    searchInput?.removeEventListener('keydown', onSearchKey);
  };

  /* ------------------------
     Open / Close
  ------------------------ */

  const openMenu = () => {
    mobileMenu.classList.add('translate-x-0');
    mobileMenu.classList.remove('translate-x-full');
    addMenuListeners();
    menuOverlay.classList.remove('hidden');
    requestAnimationFrame(() => menuOverlay.classList.add('opacity-100'));
    enableFocus();
    body.classList.add('overflow-hidden');

    // Hamburger → X
    line1?.classList.add('-rotate-45', '-translate-y-[5px]', 'w-[20px]');
    line2?.classList.add('opacity-0');
    line3?.classList.add('rotate-45', 'translate-y-[5px]', 'w-[20px]');

    


    setTimeout(() => searchInput?.focus(), 400);
  };

  const closeMenu = () => {
    mobileMenu.classList.remove('translate-x-0');
    mobileMenu.classList.add('translate-x-full');

    menuOverlay.classList.remove('opacity-100');
    menuOverlay.classList.add('hidden');

    body.classList.remove('overflow-hidden');

    // X → Hamburger
    line1?.classList.remove('-rotate-45', '-translate-y-[5px]', 'w-[20px]');
    line2?.classList.remove('opacity-0');
    line3?.classList.remove('rotate-45', 'translate-y-[5px]', 'w-[20px]');
    disableFocus();
    removeMenuListeners();
  };

  function enableFocus(){
    
    focusables.forEach(el => el.removeAttribute('tabindex'));

    // Optional: move focus into menu
    focusables[0]?.focus();
  }

  function disableFocus(){
  
  focusables.forEach(el => el.setAttribute('tabindex', '-1'));

  menuToggle.focus();
}
  const toggleMenu = () => (isOpen() ? closeMenu() : openMenu());

  /* ------------------------
     Base Binding (always on)
  ------------------------ */
  disableFocus(); // disable focus on init
  menuToggle.addEventListener('click', toggleMenu);
});

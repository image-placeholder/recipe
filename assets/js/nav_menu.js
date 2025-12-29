document.addEventListener('DOMContentLoaded', () => {
  const menuToggle = document.getElementById('menu-toggle');
  const mobileMenu = document.getElementById('mobile-menu');
  const menuOverlay = document.getElementById('menu-overlay');
  const body = document.body;

  // Hamburger lines
  const line1 = document.getElementById('line-1');
  const line2 = document.getElementById('line-2');
  const line3 = document.getElementById('line-3');

  function toggleMenu() {
    const isOpen = mobileMenu.classList.contains('translate-x-0');

    if (isOpen) {
      // Close Menu
      mobileMenu.classList.remove('translate-x-0');
      mobileMenu.classList.add('translate-x-full');
      menuOverlay.classList.add('hidden');
      menuOverlay.classList.remove('opacity-100');
      body.classList.remove('overflow-hidden');
      
      // Animate Hamburger back
      line1.classList.remove('-rotate-45', '-translate-y-[5px]', 'w-[20px]');
      line2.classList.remove('opacity-0');
      line3.classList.remove('rotate-45', 'translate-y-[5px]', 'w-[20px]');
    } else {
      // Open Menu
      mobileMenu.classList.add('translate-x-0');
      mobileMenu.classList.remove('translate-x-full');
      menuOverlay.classList.remove('hidden');
      setTimeout(() => menuOverlay.classList.add('opacity-100'), 10);
      body.classList.add('overflow-hidden');

      // Animate Hamburger to X
      line1.classList.add('-rotate-45', '-translate-y-[5px]', 'w-[20px]');
      line2.classList.add('opacity-0');
      line3.classList.add('rotate-45', 'translate-y-[5px]', 'w-[20px]');
    }
  }

  menuToggle.addEventListener('click', toggleMenu);
  menuOverlay.addEventListener('click', toggleMenu);

  // Close on Escape Key
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && mobileMenu.classList.contains('translate-x-0')) {
      toggleMenu();
    }
  });
});

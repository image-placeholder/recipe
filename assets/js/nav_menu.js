document.addEventListener("DOMContentLoaded", () => {


const overlay = document.getElementById('nav-overlay');
const menu = document.getElementById('mobile-menu');

function handleOverlayClick() {
  overlay.classList.add('hidden');
  menu.classList.remove('translate-x-0');
  menu.classList.add('translate-x-full');
  overlay.removeEventListener('click', handleOverlayClick);
}

document.getElementById('menu-toggle').addEventListener('click', () => {
  if (menu.classList.contains('translate-x-full')) {
    menu.classList.remove('translate-x-full');
    menu.classList.add('translate-x-0');
    overlay.addEventListener('click', handleOverlayClick);
    overlay.classList.remove('hidden');
  } else {
    menu.classList.remove('translate-x-0');
    menu.classList.add('translate-x-full');
    overlay.classList.add('hidden');
    overlay.removeEventListener('click', handleOverlayClick);
  }
});

window.addEventListener('resize', () => {
  const desktopWidth = 1024;
  const isMenuOpen = !overlay.classList.contains('hidden') && menu.classList.contains('translate-x-0');

  if (window.innerWidth >= desktopWidth && isMenuOpen) {
    overlay.classList.add('hidden');
    menu.classList.remove('translate-x-0');
    menu.classList.add('translate-x-full');
    overlay.removeEventListener('click', handleOverlayClick);
  }
});

// Close menu when clicking any link with #
document.querySelectorAll('#mobile-menu a[href^="#"]').forEach(link => {
  link.addEventListener('click', () => {
    document.getElementById('mobile-menu').classList.add('translate-x-full');
  });
});


});  

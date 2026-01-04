(function () {
  const banner = document.getElementById('cookie-banner');
  if (!banner) return;

  const acceptBtn = banner.querySelector('[data-accept-cookies]');
  let clickHandler;

  function hasAcceptedCookies() {
    try {
      return (
        localStorage.getItem('cookiesAccepted') === 'true' ||
        sessionStorage.getItem('cookiesAccepted') === 'true'
      );
    } catch {
      return sessionStorage.getItem('cookiesAccepted') === 'true';
    }
  }

  function cleanup() {
    if (acceptBtn && clickHandler) {
      acceptBtn.removeEventListener('click', clickHandler);
    }
  }

  function acceptCookies() {
    banner.classList.add('opacity-0', 'translate-y-4');

    setTimeout(() => {
      banner.classList.add('hidden');
    }, 500);

    try {
      localStorage.setItem('cookiesAccepted', 'true');
    } catch {
      // localStorage unavailable (private mode, etc.)
    }

    sessionStorage.setItem('cookiesAccepted', 'true');

    cleanup();
  }

  // If already accepted, ensure banner is hidden and do nothing else
  if (hasAcceptedCookies()) {
    banner.classList.add('hidden');
    cleanup();
    return;
  }

  // Otherwise, show banner and bind listener
  banner.classList.remove('hidden');

  if (acceptBtn) {
    clickHandler = acceptCookies;
    acceptBtn.addEventListener('click', clickHandler);
  }
})();

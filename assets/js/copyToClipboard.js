function copyToClipboard() {
  const url = window.location.href;
  const toast = document.getElementById('copy-toast');
  
  navigator.clipboard.writeText(url).then(() => {
    // Show toast
    toast.classList.remove('opacity-0');
    toast.classList.add('opacity-100');
    
    // Hide toast after 2 seconds
    setTimeout(() => {
      toast.classList.remove('opacity-100');
      toast.classList.add('opacity-0');
    }, 2000);
  });
}

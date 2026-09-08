/** Progressive enhancement; all document content and navigation are static HTML. */
const root = document.documentElement;
const themeButtons = document.querySelectorAll('[data-toggle-theme]');
function setTheme(theme) {
  root.dataset.theme = theme;
  for (const button of themeButtons) button.setAttribute('aria-label', `Switch to ${theme === 'dark' ? 'light' : 'dark'} theme`);
  try { localStorage.setItem('pancakes-theme', theme); } catch { /* Storage may be disabled. */ }
}
for (const button of themeButtons) button.addEventListener('click', () => setTheme(root.dataset.theme === 'light' ? 'dark' : 'light'));
for (const button of document.querySelectorAll('.copy-button')) {
  button.addEventListener('click', async () => {
    const source = button.closest('.code-block').querySelector('pre code').textContent;
    const label = button.querySelector('.copy-label');
    try {
      await navigator.clipboard.writeText(source);
      label.textContent = 'Copied!';
      button.setAttribute('aria-label', 'Code copied');
    } catch {
      const range = document.createRange();
      range.selectNodeContents(button.closest('.code-block').querySelector('pre code'));
      const selection = window.getSelection();
      selection.removeAllRanges(); selection.addRange(range);
      label.textContent = 'Select & copy';
    }
    window.setTimeout(() => { label.textContent = 'Copy'; button.setAttribute('aria-label','Copy code'); }, 2000);
  });
}
const drawer = document.querySelector('#mobile-navigation');
const menuButton = document.querySelector('[data-open-menu]');
menuButton?.addEventListener('click', () => { drawer.showModal(); document.body.style.overflow='hidden'; menuButton.setAttribute('aria-expanded','true'); });
drawer?.querySelector('[data-close-menu]').addEventListener('click', () => drawer.close());
drawer?.addEventListener('close', () => { document.body.style.overflow=''; menuButton.setAttribute('aria-expanded','false'); });
drawer?.addEventListener('click', event => { if(event.target === drawer && event.clientX > drawer.getBoundingClientRect().right) drawer.close(); });
const tocLinks = [...document.querySelectorAll('.toc nav a')];
if ('IntersectionObserver' in window) {
  const observer = new IntersectionObserver(entries => {
    const entry=entries.find(entry => entry.isIntersecting);
    if(!entry) return;
    for (const link of tocLinks) {
      const active=link.hash === `#${entry.target.id}`;
      link.classList.toggle('active',active);
      if(active) link.setAttribute('aria-current','location'); else link.removeAttribute('aria-current');
    }
  }, {rootMargin:'-100px 0px -65% 0px',threshold:0});
  for(const section of document.querySelectorAll('.doc-section')) observer.observe(section);
}

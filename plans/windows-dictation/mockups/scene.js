// Draws the Windows taskbar into every .desk on a mockup page.
// <div class="desk" data-tray="idle|rec|hot" data-apps="notepad,edge,explorer"> … </div>
const icons = {
  mic: (c, fill) => `<svg width="16" height="16" viewBox="0 0 16 16" fill="${fill ? c : 'none'}" stroke="${c}" stroke-width="1.4" stroke-linecap="round"><rect x="5.5" y="1.5" width="5" height="8.5" rx="2.5"/><path d="M3 7.5a5 5 0 0 0 10 0M8 12.5v2" fill="none"/></svg>`,
  search: c => `<svg width="14" height="14" viewBox="0 0 16 16" fill="none" stroke="${c}" stroke-width="1.5"><circle cx="7" cy="7" r="5"/><path d="M11 11l4 4"/></svg>`,
  chev: c => `<svg width="12" height="12" viewBox="0 0 16 16" fill="none" stroke="${c}" stroke-width="1.5"><path d="M4 10l4-4 4 4"/></svg>`,
  wifi: c => `<svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="${c}" stroke-width="1.4" stroke-linecap="round"><path d="M1.5 6a9.5 9.5 0 0 1 13 0M4 8.7a6 6 0 0 1 8 0M6.4 11.3a2.5 2.5 0 0 1 3.2 0"/><circle cx="8" cy="13.6" r=".6" fill="${c}"/></svg>`,
  vol: c => `<svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="${c}" stroke-width="1.4" stroke-linejoin="round"><path d="M2 6h3l4-3v10l-4-3H2z"/><path d="M11.5 5.5a3.5 3.5 0 0 1 0 5"/></svg>`,
  notepad: () => `<svg width="22" height="22" viewBox="0 0 24 24"><rect x="4" y="3" width="16" height="18" rx="2" fill="#5AB2E8"/><rect x="7" y="7" width="10" height="1.6" fill="#fff"/><rect x="7" y="11" width="10" height="1.6" fill="#fff"/><rect x="7" y="15" width="6" height="1.6" fill="#fff"/></svg>`,
  edge: () => `<svg width="22" height="22" viewBox="0 0 24 24"><circle cx="12" cy="12" r="9" fill="#1F9CD8"/><path d="M6 13c1-5 10-6 12-1-2-2-7-1-7 3 0 3 5 4 7 2-3 4-11 3-12-4z" fill="#56D364"/></svg>`,
  explorer: () => `<svg width="22" height="22" viewBox="0 0 24 24"><path d="M3 6h7l2 2h9v11H3z" fill="#F2C14E"/><path d="M3 9h18v10H3z" fill="#F7D774"/></svg>`,
  word: () => `<svg width="22" height="22" viewBox="0 0 24 24"><rect x="3" y="3" width="18" height="18" rx="3" fill="#2B5DB8"/><path d="M7 8l1.6 8L10.5 10l1.9 6L14 8" stroke="#fff" stroke-width="1.6" fill="none"/></svg>`,
};
window.loquiIcons = icons;
const dark = matchMedia('(prefers-color-scheme: dark)').matches;
const ink = dark ? '#F5F2EE' : '#1A1A1A';
for (const desk of document.querySelectorAll('.desk')) {
  const apps = (desk.dataset.apps || 'explorer,edge,notepad').split(',');
  const on = desk.dataset.on || '';
  const tray = desk.dataset.tray || 'idle';
  const mic = tray === 'rec' ? icons.mic('#E91E63', true) : icons.mic(ink, false);
  const bar = document.createElement('div');
  bar.className = 'taskbar';
  bar.innerHTML = `
    <div class="tb-app"><span class="tb-start"><i></i><i></i><i></i><i></i></span></div>
    <div class="tb-search">${icons.search(dark ? '#B8B2AC' : '#5F5B57')} Search</div>
    ${apps.map(a => `<div class="tb-app ${a === on ? 'on' : ''}">${icons[a]()}</div>`).join('')}
    <div class="tray">
      <span class="ti">${icons.chev(ink)}</span>
      <span class="ti ${tray === 'hot' ? 'hot' : ''}" title="loqui">${mic}</span>
      <span class="ti">${icons.wifi(ink)}</span><span class="ti">${icons.vol(ink)}</span>
      <span class="clock">9:41 AM<br>11/10/2026</span>
    </div>`;
  desk.appendChild(bar);
}
// Live-looking waveform bars inside any .bars element: a bell envelope like the Mac HUD.
for (const bars of document.querySelectorAll('.bars')) {
  const n = 21, c = (n - 1) / 2;
  bars.innerHTML = Array.from({ length: n }, (_, i) => {
    const d = Math.abs(i - c) / c, env = 0.3 + 0.7 * Math.cos(d * Math.PI / 2);
    const osc = 0.35 + 0.65 * (0.5 + 0.5 * Math.sin(i * 1.7));
    return `<i style="height:${Math.round(3 + 33 * env * 0.8 * osc)}px"></i>`;
  }).join('');
}

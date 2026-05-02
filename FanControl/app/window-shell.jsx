// window-shell.jsx — dark macOS widget chrome for FanControl
// A narrow ~360px column window with traffic lights and a translucent dark backdrop.

const FC_FONT = '-apple-system, BlinkMacSystemFont, "SF Pro Text", "Inter", "Helvetica Neue", sans-serif';
const FC_MONO = '"SF Mono", "JetBrains Mono", ui-monospace, Menlo, monospace';

function FCTrafficLights({ active = true }) {
  const dot = (bg) => (
    <div style={{
      width: 12, height: 12, borderRadius: '50%',
      background: active ? bg : 'rgba(255,255,255,0.18)',
      border: '0.5px solid rgba(0,0,0,0.25)',
      boxShadow: 'inset 0 0.5px 0 rgba(255,255,255,0.18)',
    }} />
  );
  return (
    <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
      {dot('#ff5f57')}{dot('#febc2e')}{dot('#28c840')}
    </div>
  );
}

// A tall narrow window. Exposes header slot + content slot.
function FCWindow({ width = 360, height = 720, accent = '#3b82f6', children, title = 'FanControl', headerRight }) {
  return (
    <div style={{
      width, height,
      borderRadius: 18,
      overflow: 'hidden',
      position: 'relative',
      fontFamily: FC_FONT,
      color: 'rgba(255,255,255,0.92)',
      // layered backdrop: base graphite + soft accent glow + subtle noise
      background: `
        radial-gradient(120% 60% at 50% -10%, ${hexToRgba(accent, 0.18)} 0%, rgba(0,0,0,0) 55%),
        linear-gradient(180deg, #1a1c20 0%, #0f1013 100%)
      `,
      boxShadow: `
        0 0 0 0.5px rgba(255,255,255,0.08),
        0 0 0 1px rgba(0,0,0,0.5),
        0 24px 60px rgba(0,0,0,0.55),
        inset 0 0.5px 0 rgba(255,255,255,0.10)
      `,
      display: 'flex', flexDirection: 'column',
    }}>
      {/* grain */}
      <div style={{
        position: 'absolute', inset: 0, pointerEvents: 'none', opacity: 0.5,
        backgroundImage: 'url("data:image/svg+xml;utf8,<svg xmlns=\'http://www.w3.org/2000/svg\' width=\'160\' height=\'160\'><filter id=\'n\'><feTurbulence type=\'fractalNoise\' baseFrequency=\'0.9\' numOctaves=\'2\'/><feColorMatrix values=\'0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 0.05 0\'/></filter><rect width=\'160\' height=\'160\' filter=\'url(%23n)\'/></svg>")',
        mixBlendMode: 'overlay',
      }} />

      {/* titlebar */}
      <div style={{
        height: 40, display: 'flex', alignItems: 'center',
        padding: '0 14px', gap: 12, flexShrink: 0,
        position: 'relative', zIndex: 1,
      }}>
        <FCTrafficLights />
        <div style={{ flex: 1, textAlign: 'center', fontSize: 12, fontWeight: 600, letterSpacing: 0.2, color: 'rgba(255,255,255,0.55)', marginRight: 50 }}>
          {title}
        </div>
        {headerRight}
      </div>

      <div style={{ flex: 1, minHeight: 0, position: 'relative', zIndex: 1, display: 'flex', flexDirection: 'column' }}>
        {children}
      </div>
    </div>
  );
}

// ─── helpers ──────────────────────────────────────────────────
function hexToRgba(hex, a = 1) {
  const h = hex.replace('#', '');
  const n = parseInt(h.length === 3 ? h.split('').map(c => c + c).join('') : h, 16);
  const r = (n >> 16) & 255, g = (n >> 8) & 255, b = n & 255;
  return `rgba(${r},${g},${b},${a})`;
}

Object.assign(window, { FCWindow, FCTrafficLights, FC_FONT, FC_MONO, hexToRgba });

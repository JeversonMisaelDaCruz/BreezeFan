// window-shell.jsx — Liquid Glass widget chrome (macOS Tahoe inspired)
// Translucent multi-layer glass: backdrop blur + saturation, specular highlights,
// inset white border, subtle inner shadow, accent-tinted ambient glow.

const FC_FONT = '-apple-system, BlinkMacSystemFont, "SF Pro Text", "Inter", "Helvetica Neue", sans-serif';
const FC_MONO = '"SF Mono", "JetBrains Mono", ui-monospace, Menlo, monospace';

function FCTrafficLights() {
  const dot = (bg, glow) => (
    <div style={{
      width: 12, height: 12, borderRadius: '50%',
      background: `radial-gradient(circle at 35% 30%, ${glow} 0%, ${bg} 55%, ${bg} 100%)`,
      boxShadow: 'inset 0 0.5px 0 rgba(255,255,255,0.5), 0 0 0 0.5px rgba(0,0,0,0.25)',
    }} />
  );
  return (
    <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
      {dot('#ff5f57', '#ff8c83')}
      {dot('#febc2e', '#ffd56a')}
      {dot('#28c840', '#5cdf68')}
    </div>
  );
}

// Liquid Glass surface primitive — used both for the window itself and inner cards.
// Composes: base tint + backdrop blur + specular sheen + inset stroke
function GlassSurface({
  children, radius = 22, dark = true, intensity = 1,
  style = {}, sheen = true, padding = 0,
}) {
  // tint depth controlled by `intensity`
  const tint = dark
    ? `rgba(20,22,28, ${0.45 * intensity})`
    : `rgba(255,255,255, ${0.55 * intensity})`;
  const stroke = dark
    ? 'rgba(255,255,255,0.14)'
    : 'rgba(255,255,255,0.7)';
  return (
    <div style={{ position: 'relative', borderRadius: radius, ...style }}>
      {/* 1. backdrop blur layer */}
      <div style={{
        position: 'absolute', inset: 0, borderRadius: radius,
        background: tint,
        backdropFilter: 'blur(40px) saturate(180%)',
        WebkitBackdropFilter: 'blur(40px) saturate(180%)',
        boxShadow: dark
          ? `inset 0 0 0 0.5px ${stroke},
             inset 0 1px 0 rgba(255,255,255,0.18),
             inset 0 -0.5px 0 rgba(0,0,0,0.3)`
          : `inset 0 0 0 0.5px ${stroke},
             inset 0 1px 0 rgba(255,255,255,0.5)`,
      }} />
      {/* 2. specular sheen — diagonal highlight band */}
      {sheen && (
        <div style={{
          position: 'absolute', inset: 0, borderRadius: radius, overflow: 'hidden',
          pointerEvents: 'none',
        }}>
          <div style={{
            position: 'absolute',
            top: '-20%', left: '-10%', width: '70%', height: '60%',
            background: `linear-gradient(140deg, rgba(255,255,255,${dark ? 0.13 : 0.45}) 0%, rgba(255,255,255,0) 60%)`,
            transform: 'rotate(-8deg)',
            filter: 'blur(0.5px)',
          }} />
        </div>
      )}
      {/* 3. content */}
      <div style={{ position: 'relative', zIndex: 1, padding }}>
        {children}
      </div>
    </div>
  );
}

// Wallpaper underneath — gives the glass something colorful to refract
function FCWallpaper({ accent = '#3b82f6' }) {
  return (
    <div style={{
      position: 'absolute', inset: 0, overflow: 'hidden',
      borderRadius: 22,
      // multi-stop gradient mesh; the accent influences the upper-right blob
      background: `
        radial-gradient(60% 50% at 80% 15%, ${hexToRgba(accent, 0.85)} 0%, transparent 60%),
        radial-gradient(50% 40% at 15% 80%, #d946ef 0%, transparent 60%),
        radial-gradient(45% 35% at 85% 90%, #06b6d4 0%, transparent 60%),
        radial-gradient(70% 50% at 30% 20%, #6366f1 0%, transparent 65%),
        linear-gradient(160deg, #1e1b4b 0%, #0c0a1f 100%)
      `,
      filter: 'saturate(115%)',
    }}>
      {/* faint film grain */}
      <div style={{
        position: 'absolute', inset: 0, pointerEvents: 'none', opacity: 0.35,
        backgroundImage: 'url("data:image/svg+xml;utf8,<svg xmlns=\'http://www.w3.org/2000/svg\' width=\'160\' height=\'160\'><filter id=\'n\'><feTurbulence type=\'fractalNoise\' baseFrequency=\'0.9\' numOctaves=\'2\'/><feColorMatrix values=\'0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 0.05 0\'/></filter><rect width=\'160\' height=\'160\' filter=\'url(%23n)\'/></svg>")',
        mixBlendMode: 'overlay',
      }} />
    </div>
  );
}

// Tall narrow window — wallpaper + glass overlay + chrome
function FCWindow({ width = 360, height = 640, accent = '#3b82f6', children, title = 'FanControl' }) {
  return (
    <div style={{
      width, height,
      borderRadius: 22,
      position: 'relative',
      fontFamily: FC_FONT,
      color: 'rgba(255,255,255,0.95)',
      boxShadow: `
        0 0 0 0.5px rgba(0,0,0,0.6),
        0 30px 70px rgba(0,0,0,0.55),
        0 12px 30px rgba(0,0,0,0.35)
      `,
    }}>
      {/* wallpaper layer — visible only in the small "window" rect via overflow */}
      <div style={{ position: 'absolute', inset: 0, borderRadius: 22, overflow: 'hidden' }}>
        <FCWallpaper accent={accent} />

        {/* glass overlay covering everything below the title */}
        <div style={{ position: 'absolute', inset: 0, borderRadius: 22, overflow: 'hidden' }}>
          {/* heavy blur veil */}
          <div style={{
            position: 'absolute', inset: 0,
            background: 'rgba(15,16,20,0.55)',
            backdropFilter: 'blur(60px) saturate(200%)',
            WebkitBackdropFilter: 'blur(60px) saturate(200%)',
          }} />
          {/* top sheen */}
          <div style={{
            position: 'absolute', top: 0, left: 0, right: 0, height: '60%',
            background: 'linear-gradient(180deg, rgba(255,255,255,0.12) 0%, rgba(255,255,255,0) 100%)',
            pointerEvents: 'none',
          }} />
          {/* edge stroke */}
          <div style={{
            position: 'absolute', inset: 0, borderRadius: 22,
            boxShadow: `
              inset 0 0 0 0.5px rgba(255,255,255,0.14),
              inset 0 1px 0 rgba(255,255,255,0.22),
              inset 0 -0.5px 0 rgba(0,0,0,0.4)
            `,
            pointerEvents: 'none',
          }} />
        </div>
      </div>

      {/* content */}
      <div style={{ position: 'relative', display: 'flex', flexDirection: 'column', height: '100%' }}>
        {/* titlebar */}
        <div style={{
          height: 42, display: 'flex', alignItems: 'center',
          padding: '0 14px', gap: 12, flexShrink: 0,
        }}>
          <FCTrafficLights />
          <div style={{
            flex: 1, textAlign: 'center', fontSize: 12, fontWeight: 600,
            letterSpacing: 0.3, color: 'rgba(255,255,255,0.65)',
            marginRight: 50,
            textShadow: '0 1px 0 rgba(0,0,0,0.3)',
          }}>{title}</div>
        </div>

        <div style={{ flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column' }}>
          {children}
        </div>
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

Object.assign(window, { FCWindow, FCTrafficLights, GlassSurface, FCWallpaper, FC_FONT, FC_MONO, hexToRgba });

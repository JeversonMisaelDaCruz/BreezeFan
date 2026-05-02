// atoms.jsx — small shared building blocks for FanControl

// Animated radial RPM/temp ring. Two arcs: track + value.
function FCDial({ value, max = 6500, label, sub, accent = '#3b82f6', size = 96, stroke = 6, format = (v) => v.toLocaleString(), warning = false }) {
  const r = (size - stroke) / 2;
  const c = 2 * Math.PI * r;
  const pct = Math.max(0, Math.min(1, value / max));
  const dash = c * pct;
  const ringColor = warning ? '#f59e0b' : accent;
  return (
    <div style={{ width: size, height: size, position: 'relative', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <svg width={size} height={size} style={{ transform: 'rotate(-90deg)' }}>
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke="rgba(255,255,255,0.07)" strokeWidth={stroke} />
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke={ringColor} strokeWidth={stroke}
                strokeLinecap="round" strokeDasharray={`${dash} ${c}`} style={{ transition: 'stroke-dasharray .8s cubic-bezier(.2,.7,.2,1)' }} />
      </svg>
      <div style={{ position: 'absolute', textAlign: 'center', lineHeight: 1.1 }}>
        <div style={{ fontSize: size > 80 ? 22 : 16, fontWeight: 600, fontVariantNumeric: 'tabular-nums', letterSpacing: -0.4 }}>
          {format(value)}
        </div>
        {sub && <div style={{ fontSize: 9, marginTop: 2, color: 'rgba(255,255,255,0.45)', textTransform: 'uppercase', letterSpacing: 0.6 }}>{sub}</div>}
      </div>
    </div>
  );
}

// A row that shows a label, value and a thin meter
function FCMeter({ label, value, max, unit, accent = '#3b82f6', warn = 75, danger = 90 }) {
  const pct = Math.max(0, Math.min(1, value / max));
  const color = value >= danger ? '#ef4444' : value >= warn ? '#f59e0b' : accent;
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
        <span style={{ fontSize: 11, color: 'rgba(255,255,255,0.55)', letterSpacing: 0.2 }}>{label}</span>
        <span style={{ fontSize: 13, fontWeight: 500, fontVariantNumeric: 'tabular-nums', color: 'rgba(255,255,255,0.92)' }}>
          {value}<span style={{ fontSize: 10, marginLeft: 2, color: 'rgba(255,255,255,0.45)' }}>{unit}</span>
        </span>
      </div>
      <div style={{ height: 3, borderRadius: 2, background: 'rgba(255,255,255,0.08)', overflow: 'hidden', position: 'relative' }}>
        <div style={{
          position: 'absolute', inset: 0, width: `${pct * 100}%`,
          background: color, borderRadius: 2,
          boxShadow: `0 0 8px ${color}88`,
          transition: 'width .8s cubic-bezier(.2,.7,.2,1)',
        }} />
      </div>
    </div>
  );
}

// A single fan card: icon, name, RPM bar, percentage spinner ring
function FCFanRow({ name, rpm, maxRpm = 6500, duty, accent = '#3b82f6' }) {
  const pct = Math.max(0, Math.min(1, rpm / maxRpm));
  // CSS spin speed proportional to duty
  const spinDur = duty > 0 ? `${Math.max(0.4, 3 - duty * 2.5)}s` : '0s';
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '10px 14px', background: 'rgba(255,255,255,0.025)', borderRadius: 12, border: '0.5px solid rgba(255,255,255,0.06)' }}>
      <div style={{
        width: 32, height: 32, borderRadius: '50%',
        background: 'rgba(255,255,255,0.04)',
        border: '0.5px solid rgba(255,255,255,0.08)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        animation: spinDur === '0s' ? 'none' : `fc-spin ${spinDur} linear infinite`,
      }}>
        <FanGlyph color={accent} />
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 4 }}>
          <span style={{ fontSize: 12, fontWeight: 500, color: 'rgba(255,255,255,0.85)' }}>{name}</span>
          <span style={{ fontSize: 12, fontVariantNumeric: 'tabular-nums', fontWeight: 500 }}>
            {rpm.toLocaleString()}<span style={{ fontSize: 9, color: 'rgba(255,255,255,0.45)', marginLeft: 3 }}>RPM</span>
          </span>
        </div>
        <div style={{ height: 3, borderRadius: 2, background: 'rgba(255,255,255,0.06)', overflow: 'hidden' }}>
          <div style={{ height: '100%', width: `${pct * 100}%`, background: accent, borderRadius: 2, boxShadow: `0 0 6px ${accent}66`, transition: 'width .8s ease-out' }} />
        </div>
      </div>
      <div style={{ width: 38, textAlign: 'right', fontSize: 11, fontVariantNumeric: 'tabular-nums', color: 'rgba(255,255,255,0.55)' }}>
        {Math.round(duty * 100)}%
      </div>
    </div>
  );
}

function FanGlyph({ color = '#3b82f6', size = 14 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
      <circle cx="12" cy="12" r="2" fill={color} />
      <path d="M12 10 C 8 6, 4 6, 4 10 C 4 14, 8 14, 12 12" stroke={color} strokeWidth="1.5" strokeLinecap="round" />
      <path d="M14 12 C 18 14, 18 18, 14 18 C 10 18, 10 14, 12 12" stroke={color} strokeWidth="1.5" strokeLinecap="round" />
      <path d="M12 14 C 8 14, 6 16, 6 20 C 10 22, 14 18, 12 14" stroke={color} strokeWidth="0" fill="none" />
      <path d="M12 12 L 16 8 C 20 8, 20 12, 16 14 C 14 14, 12 14, 12 12" stroke={color} strokeWidth="1.5" strokeLinecap="round" />
    </svg>
  );
}

// Preset chip — pill button with optional active state
function FCChip({ label, active, onClick, icon }) {
  return (
    <button onClick={onClick} style={{
      flex: 1, minWidth: 0,
      appearance: 'none', border: 'none', cursor: 'pointer',
      padding: '7px 10px',
      borderRadius: 8,
      background: active ? 'rgba(255,255,255,0.12)' : 'transparent',
      color: active ? '#fff' : 'rgba(255,255,255,0.55)',
      fontSize: 11, fontWeight: 500,
      fontFamily: 'inherit',
      display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 5,
      transition: 'background .15s, color .15s',
      boxShadow: active ? 'inset 0 0.5px 0 rgba(255,255,255,0.15), 0 1px 2px rgba(0,0,0,0.3)' : 'none',
    }}>
      {icon}{label}
    </button>
  );
}

function FCSegment({ options, value, onChange }) {
  return (
    <div style={{
      display: 'flex',
      padding: 3,
      borderRadius: 10,
      background: 'rgba(0,0,0,0.35)',
      border: '0.5px solid rgba(255,255,255,0.06)',
      gap: 2,
    }}>
      {options.map(opt => (
        <FCChip key={opt.value} label={opt.label} icon={opt.icon} active={value === opt.value} onClick={() => onChange(opt.value)} />
      ))}
    </div>
  );
}

function FCDivider() {
  return <div style={{ height: 0.5, background: 'rgba(255,255,255,0.06)', margin: '0 14px' }} />;
}

function FCSection({ title, action, children, padding = 14 }) {
  return (
    <div style={{ padding: `12px ${padding}px 14px` }}>
      {title && (
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
          <div style={{ fontSize: 10, fontWeight: 600, letterSpacing: 1.4, textTransform: 'uppercase', color: 'rgba(255,255,255,0.4)' }}>{title}</div>
          {action}
        </div>
      )}
      {children}
    </div>
  );
}

// inject keyframes once
if (typeof document !== 'undefined' && !document.getElementById('fc-anims')) {
  const s = document.createElement('style');
  s.id = 'fc-anims';
  s.textContent = `
    @keyframes fc-spin { to { transform: rotate(360deg); } }
    @keyframes fc-pulse { 0%,100% { opacity: 0.6 } 50% { opacity: 1 } }
    @keyframes fc-shimmer { 0% { background-position: -200% 0 } 100% { background-position: 200% 0 } }
  `;
  document.head.appendChild(s);
}

Object.assign(window, { FCDial, FCMeter, FCFanRow, FanGlyph, FCChip, FCSegment, FCDivider, FCSection });

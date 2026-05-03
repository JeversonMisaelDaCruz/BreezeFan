// MainMVP.jsx — Liquid Glass MVP main window
// Glass-card hero readout, glass fan rows, glass preset chips.

function MainMVP({ accent = '#3b82f6', tempUnit = 'C', onOpenCurve }) {
  const [activePreset, setActivePreset] = React.useState('balanced');

  const fans = [
    { id: 'f1', name: 'Left Fan', rpm: 4280, max: 6500, duty: 0.66 },
    { id: 'f2', name: 'Right Fan', rpm: 4510, max: 6500, duty: 0.69 },
  ];

  const PRESETS = [
    { id: 'silent', label: 'Silent', icon: 'silent' },
    { id: 'balanced', label: 'Balanced', icon: 'balanced' },
    { id: 'performance', label: 'Performance', icon: 'perf' },
    { id: 'max', label: 'Max', icon: 'max' },
  ];

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', overflow: 'auto', padding: '4px 14px 14px', gap: 12 }}>

      {/* Hero glass card */}
      <GlassSurface radius={18} padding={18} style={{ overflow: 'hidden' }}>
        <div style={{ position: 'relative' }}>
          <div style={{ fontSize: 10, color: 'rgba(255,255,255,0.55)', textTransform: 'uppercase', letterSpacing: 1.6, marginBottom: 6, fontWeight: 600 }}>
            CPU
          </div>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 4 }}>
            <span style={{
              fontSize: 64, fontWeight: 200, letterSpacing: -3, lineHeight: 1,
              fontVariantNumeric: 'tabular-nums', color: '#fff',
              textShadow: '0 2px 20px rgba(0,0,0,0.35)',
            }}>67</span>
            <span style={{ fontSize: 22, color: 'rgba(255,255,255,0.6)', fontWeight: 300 }}>°{tempUnit}</span>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 8 }}>
            <span style={{
              width: 6, height: 6, borderRadius: '50%',
              background: '#22c55e',
              boxShadow: '0 0 8px #22c55e, 0 0 0 2px rgba(34,197,94,0.18)',
            }} />
            <span style={{ fontSize: 11, color: 'rgba(255,255,255,0.7)' }}>Running cool · 2 fans active</span>
          </div>
        </div>
      </GlassSurface>

      {/* Fans glass card */}
      <GlassSurface radius={18} padding="14px 16px" style={{ overflow: 'hidden' }}>
        <div style={{ fontSize: 10, fontWeight: 600, letterSpacing: 1.6, textTransform: 'uppercase', color: 'rgba(255,255,255,0.55)', marginBottom: 10 }}>Fans</div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {fans.map(f => <GlassFanRow key={f.id} fan={f} accent={accent} />)}
        </div>
      </GlassSurface>

      {/* Presets glass card */}
      <GlassSurface radius={18} padding="14px 16px" style={{ overflow: 'hidden' }}>
        <div style={{ fontSize: 10, fontWeight: 600, letterSpacing: 1.6, textTransform: 'uppercase', color: 'rgba(255,255,255,0.55)', marginBottom: 10 }}>Mode</div>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 6 }}>
          {PRESETS.map(p => (
            <PresetGlass key={p.id} label={p.label} icon={p.icon}
                         active={activePreset === p.id} accent={accent}
                         onClick={() => setActivePreset(p.id)} />
          ))}
        </div>
      </GlassSurface>

      <div style={{ flex: 1 }} />

      {/* Edit curve glass button */}
      <button onClick={onOpenCurve} style={{
        appearance: 'none', border: 'none', cursor: 'pointer',
        padding: 0, background: 'transparent',
        fontFamily: 'inherit',
      }}>
        <GlassSurface radius={14} padding="11px 14px" style={{ overflow: 'hidden' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <span style={{ display: 'flex', alignItems: 'center', gap: 9 }}>
              <span style={{
                width: 22, height: 22, borderRadius: 6,
                background: hexToRgba(accent, 0.25),
                boxShadow: `inset 0 0 0 0.5px ${hexToRgba(accent, 0.5)}, 0 0 10px ${hexToRgba(accent, 0.3)}`,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
              }}>
                <svg width="13" height="13" viewBox="0 0 24 24" fill="none" style={{ color: '#fff' }}>
                  <path d="M3 18 C 7 18, 9 6, 13 6 S 17 18, 21 18" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" />
                </svg>
              </span>
              <span style={{ color: 'rgba(255,255,255,0.95)', fontSize: 12.5, fontWeight: 500 }}>Edit fan curve</span>
            </span>
            <svg width="11" height="11" viewBox="0 0 12 12" style={{ color: 'rgba(255,255,255,0.55)' }}>
              <path d="M4 2 L8 6 L4 10" stroke="currentColor" strokeWidth="1.5" fill="none" strokeLinecap="round" />
            </svg>
          </div>
        </GlassSurface>
      </button>
    </div>
  );
}

function GlassFanRow({ fan, accent }) {
  const pct = Math.max(0, Math.min(1, fan.rpm / fan.max));
  const spinDur = `${Math.max(0.5, 3 - fan.duty * 2.5)}s`;
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 11 }}>
      <div style={{
        width: 30, height: 30, borderRadius: '50%',
        background: 'rgba(255,255,255,0.08)',
        boxShadow: 'inset 0 0 0 0.5px rgba(255,255,255,0.18), inset 0 1px 0 rgba(255,255,255,0.25)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        animation: `fc-spin ${spinDur} linear infinite`,
      }}>
        <FanGlyph color="#fff" size={14} />
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 5 }}>
          <span style={{ fontSize: 12, fontWeight: 500, color: 'rgba(255,255,255,0.95)' }}>{fan.name}</span>
          <span style={{ fontSize: 12, fontVariantNumeric: 'tabular-nums', fontWeight: 500, color: '#fff' }}>
            {fan.rpm.toLocaleString()}<span style={{ fontSize: 9, color: 'rgba(255,255,255,0.55)', marginLeft: 3 }}>RPM</span>
          </span>
        </div>
        {/* glass track */}
        <div style={{
          height: 5, borderRadius: 99,
          background: 'rgba(0,0,0,0.3)',
          boxShadow: 'inset 0 0.5px 1px rgba(0,0,0,0.5), inset 0 0 0 0.5px rgba(255,255,255,0.06)',
          overflow: 'hidden',
        }}>
          <div style={{
            height: '100%', width: `${pct * 100}%`,
            background: `linear-gradient(180deg, ${hexToRgba(accent, 1)} 0%, ${hexToRgba(accent, 0.75)} 100%)`,
            boxShadow: `0 0 10px ${hexToRgba(accent, 0.6)}, inset 0 0.5px 0 rgba(255,255,255,0.5)`,
            borderRadius: 99,
            transition: 'width .8s cubic-bezier(.2,.7,.2,1)',
          }} />
        </div>
      </div>
      <div style={{
        width: 38, textAlign: 'right',
        fontSize: 11, fontVariantNumeric: 'tabular-nums',
        color: 'rgba(255,255,255,0.65)',
      }}>
        {Math.round(fan.duty * 100)}%
      </div>
    </div>
  );
}

function PresetGlass({ label, icon, active, accent, onClick }) {
  return (
    <button onClick={onClick} style={{
      appearance: 'none', border: 'none', cursor: 'pointer',
      padding: 0, background: 'transparent',
      fontFamily: 'inherit',
    }}>
      <div style={{
        position: 'relative',
        padding: '10px 8px',
        borderRadius: 12,
        overflow: 'hidden',
        background: active
          ? `linear-gradient(180deg, ${hexToRgba(accent, 0.45)} 0%, ${hexToRgba(accent, 0.25)} 100%)`
          : 'rgba(255,255,255,0.06)',
        boxShadow: active
          ? `inset 0 0 0 0.5px ${hexToRgba(accent, 0.7)},
             inset 0 1px 0 rgba(255,255,255,0.35),
             0 4px 14px ${hexToRgba(accent, 0.35)}`
          : `inset 0 0 0 0.5px rgba(255,255,255,0.12),
             inset 0 1px 0 rgba(255,255,255,0.18)`,
        backdropFilter: 'blur(8px)',
        WebkitBackdropFilter: 'blur(8px)',
        transition: 'all .2s',
      }}>
        {/* sheen */}
        <div style={{
          position: 'absolute', top: 0, left: 0, right: 0, height: '50%',
          background: 'linear-gradient(180deg, rgba(255,255,255,0.18) 0%, rgba(255,255,255,0) 100%)',
          pointerEvents: 'none',
        }} />
        <div style={{ position: 'relative', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 5 }}>
          <PresetIcon kind={icon} color={active ? '#fff' : 'rgba(255,255,255,0.7)'} />
          <span style={{
            fontSize: 11, fontWeight: active ? 600 : 500,
            color: active ? '#fff' : 'rgba(255,255,255,0.8)',
          }}>{label}</span>
        </div>
      </div>
    </button>
  );
}

function PresetIcon({ kind, color }) {
  const props = { width: 16, height: 16, viewBox: '0 0 16 16', fill: 'none', style: { color } };
  switch (kind) {
    case 'silent': return <svg {...props}><path d="M3 6 H5 L9 3 V13 L5 10 H3 Z M11 5 Q13 8, 11 11" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round" /></svg>;
    case 'balanced': return <svg {...props}><circle cx="8" cy="8" r="2" fill="currentColor" /><circle cx="8" cy="8" r="5.5" stroke="currentColor" strokeWidth="1.4" strokeDasharray="2 2" /></svg>;
    case 'perf': return <svg {...props}><path d="M2 12 L6 6 L9 9 L14 3" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" /></svg>;
    case 'max': return <svg {...props}><path d="M5 2 L3 9 H7 L5 14 L13 6 H8 L10 2 Z" fill="currentColor" /></svg>;
    default: return null;
  }
}

Object.assign(window, { MainMVP });

// MainMVP.jsx — V1: MVP simplified main window
// Bare essentials: 1 sensor readout, fan list, 4 presets, edit curve link.
// No hero dial, no history graph, no auto-binding chrome.

function MainMVP({ accent = '#3b82f6', tempUnit = 'C', onOpenCurve }) {
  const [activePreset, setActivePreset] = React.useState('balanced');

  const fans = [
    { id: 'f1', name: 'Left Fan', rpm: 4280, max: 6500, duty: 0.66 },
    { id: 'f2', name: 'Right Fan', rpm: 4510, max: 6500, duty: 0.69 },
  ];

  const PRESETS = [
    { id: 'silent', label: 'Silent' },
    { id: 'balanced', label: 'Balanced' },
    { id: 'performance', label: 'Performance' },
    { id: 'max', label: 'Max' },
  ];

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', overflow: 'auto' }}>

      {/* Big temp readout */}
      <div style={{ padding: '8px 20px 18px' }}>
        <div style={{ fontSize: 10, color: 'rgba(255,255,255,0.4)', textTransform: 'uppercase', letterSpacing: 1.4, marginBottom: 4 }}>
          CPU temperature
        </div>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 4 }}>
          <span style={{ fontSize: 64, fontWeight: 200, letterSpacing: -3, lineHeight: 1, fontVariantNumeric: 'tabular-nums', color: '#fff' }}>67</span>
          <span style={{ fontSize: 22, color: 'rgba(255,255,255,0.5)', fontWeight: 300 }}>°{tempUnit}</span>
        </div>
        <div style={{ fontSize: 11, color: 'rgba(255,255,255,0.45)', marginTop: 6 }}>
          Running cool · 2 fans active
        </div>
      </div>

      <FCDivider />

      {/* Fans */}
      <FCSection title="Fans" padding={20}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
          {fans.map(f => <FCFanRow key={f.id} {...f} maxRpm={f.max} accent={accent} />)}
        </div>
      </FCSection>

      <FCDivider />

      {/* Presets */}
      <FCSection title="Mode" padding={20}>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 6 }}>
          {PRESETS.map(p => (
            <PresetBtn key={p.id} label={p.label} active={activePreset === p.id}
                       accent={accent} onClick={() => setActivePreset(p.id)} />
          ))}
        </div>
      </FCSection>

      <div style={{ flex: 1 }} />

      {/* Edit curve as a quiet footer link */}
      <div style={{ padding: '8px 20px 18px' }}>
        <button onClick={onOpenCurve} style={{
          width: '100%', appearance: 'none', cursor: 'pointer',
          padding: '10px 14px', borderRadius: 10,
          background: 'rgba(255,255,255,0.04)',
          border: '0.5px solid rgba(255,255,255,0.08)',
          color: 'rgba(255,255,255,0.85)', fontFamily: 'inherit', fontSize: 12, fontWeight: 500,
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        }}>
          <span style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" style={{ color: accent }}>
              <path d="M3 18 C 7 18, 9 6, 13 6 S 17 18, 21 18" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
            </svg>
            Edit fan curve
          </span>
          <svg width="11" height="11" viewBox="0 0 12 12" style={{ color: 'rgba(255,255,255,0.4)' }}>
            <path d="M4 2 L8 6 L4 10" stroke="currentColor" strokeWidth="1.5" fill="none" strokeLinecap="round" />
          </svg>
        </button>
      </div>
    </div>
  );
}

function PresetBtn({ label, active, accent, onClick }) {
  return (
    <button onClick={onClick} style={{
      appearance: 'none', cursor: 'pointer',
      padding: '12px 10px', borderRadius: 10,
      background: active ? hexToRgba(accent, 0.15) : 'rgba(255,255,255,0.03)',
      border: active ? `0.5px solid ${hexToRgba(accent, 0.5)}` : '0.5px solid rgba(255,255,255,0.06)',
      color: active ? '#fff' : 'rgba(255,255,255,0.7)',
      fontFamily: 'inherit', fontSize: 12, fontWeight: 500,
      transition: 'all .15s',
      boxShadow: active ? `0 0 14px ${hexToRgba(accent, 0.25)}` : 'none',
    }}>
      {label}
    </button>
  );
}

Object.assign(window, { MainMVP });

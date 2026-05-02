// MainSpectrum.jsx — V2: data-strip layout
// Different aesthetic: thin spectrum bars across the top showing
// 60-second history of CPU temp; fans as horizontal "tape" rows
// with live drift; sensor cards grid; preset stack.

function MainSpectrum({ accent = '#3b82f6', tempUnit = 'C', density = 'regular', onOpenCurve }) {
  const [activePreset, setActivePreset] = React.useState('balanced');

  const fans = [
    { id: 'f1', name: 'Left', rpm: 4280, max: 6500, duty: 0.66 },
    { id: 'f2', name: 'Right', rpm: 4510, max: 6500, duty: 0.69 },
  ];

  // pseudo-random history bars (stable per render)
  const history = React.useMemo(() => Array.from({ length: 48 }, (_, i) => {
    const t = i / 48;
    return 0.35 + 0.18 * Math.sin(t * 6) + 0.15 * Math.sin(t * 11) + 0.1 * Math.cos(t * 3);
  }), []);

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', overflow: 'auto' }}>
      {/* device line */}
      <div style={{ padding: '8px 16px 4px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <span style={{ width: 6, height: 6, borderRadius: '50%', background: '#22c55e', boxShadow: '0 0 6px #22c55e' }} />
          <span style={{ fontSize: 11, fontWeight: 600, letterSpacing: 0.2 }}>MacBook Pro M3 Max</span>
        </div>
        <span style={{ fontSize: 10, color: 'rgba(255,255,255,0.4)', fontFamily: FC_MONO }}>02:14:38</span>
      </div>

      {/* big readout */}
      <div style={{ padding: '14px 16px 0' }}>
        <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', marginBottom: 10 }}>
          <div>
            <div style={{ fontSize: 10, color: 'rgba(255,255,255,0.4)', textTransform: 'uppercase', letterSpacing: 1.4, marginBottom: 2 }}>CPU Package</div>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 4 }}>
              <span style={{ fontSize: 56, fontWeight: 200, letterSpacing: -3, lineHeight: 1, fontVariantNumeric: 'tabular-nums', color: '#fff' }}>67</span>
              <span style={{ fontSize: 18, color: 'rgba(255,255,255,0.5)', fontWeight: 300 }}>°{tempUnit}</span>
            </div>
          </div>
          <div style={{ textAlign: 'right' }}>
            <div style={{ fontSize: 10, color: 'rgba(255,255,255,0.4)', textTransform: 'uppercase', letterSpacing: 1.4, marginBottom: 2 }}>Trend</div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 4, color: '#86efac', fontSize: 12, fontWeight: 500, fontVariantNumeric: 'tabular-nums' }}>
              <svg width="10" height="10" viewBox="0 0 10 10"><path d="M2 7 L5 3 L8 7" stroke="currentColor" strokeWidth="1.5" fill="none" strokeLinecap="round" strokeLinejoin="round" /></svg>
              +2.4°
            </div>
          </div>
        </div>

        {/* spectrum bars */}
        <div style={{ display: 'flex', alignItems: 'flex-end', gap: 2, height: 44, marginBottom: 4 }}>
          {history.map((v, i) => {
            const isLast = i === history.length - 1;
            const h = Math.max(2, v * 100);
            // thermal palette: blue → cyan → yellow → red
            const t = v;
            const color = t > 0.7 ? '#ef4444' : t > 0.55 ? '#f59e0b' : t > 0.4 ? accent : 'rgba(255,255,255,0.25)';
            return (
              <div key={i} style={{
                flex: 1,
                height: `${h}%`,
                background: color,
                borderRadius: 1,
                opacity: isLast ? 1 : 0.6 + (i / history.length) * 0.4,
                boxShadow: isLast ? `0 0 8px ${color}` : 'none',
              }} />
            );
          })}
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 9, color: 'rgba(255,255,255,0.3)', fontFamily: FC_MONO, letterSpacing: 0.5 }}>
          <span>−60s</span><span>−30s</span><span>now</span>
        </div>
      </div>

      <div style={{ padding: '14px 16px 0' }}>
        <FCDivider />
      </div>

      {/* sensor grid 3x */}
      <FCSection title="Sensors">
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 8 }}>
          <SensorCard label="CPU" value="67" unit={`°${tempUnit}`} accent={accent} bar={0.64} />
          <SensorCard label="GPU" value="54" unit={`°${tempUnit}`} accent={accent} bar={0.57} />
          <SensorCard label="Battery" value="32" unit={`°${tempUnit}`} accent="#22c55e" bar={0.53} />
        </div>
      </FCSection>

      <FCDivider />

      {/* fans as tape rows */}
      <FCSection title={`Fans · ${fans.length}`}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {fans.map(f => <TapeFan key={f.id} fan={f} accent={accent} />)}
        </div>
      </FCSection>

      <FCDivider />

      {/* preset list — vertical instead of segmented */}
      <FCSection title="Profile">
        <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
          {[
            { id: 'silent', label: 'Silent', sub: 'Whisper', icon: <PresetGlyph kind="silent" /> },
            { id: 'balanced', label: 'Balanced', sub: 'Default', icon: <PresetGlyph kind="balanced" /> },
            { id: 'performance', label: 'Performance', sub: 'Sustained', icon: <PresetGlyph kind="perf" /> },
            { id: 'max', label: 'Max', sub: 'Burst', icon: <PresetGlyph kind="max" /> },
            { id: 'custom', label: 'Custom curve', sub: 'Your rules', icon: <PresetGlyph kind="curve" />, action: true },
          ].map(p => (
            <PresetRow key={p.id} preset={p} active={activePreset === p.id} accent={accent}
                       onClick={() => p.action ? onOpenCurve() : setActivePreset(p.id)} />
          ))}
        </div>
      </FCSection>

      {/* footer info */}
      <div style={{ padding: '6px 16px 12px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', fontSize: 9, color: 'rgba(255,255,255,0.3)', fontFamily: FC_MONO, letterSpacing: 0.5 }}>
        <span>SMC v2.46</span>
        <span>2 fans · 12 sensors</span>
      </div>
    </div>
  );
}

function SensorCard({ label, value, unit, accent, bar }) {
  return (
    <div style={{
      padding: 10, borderRadius: 10,
      background: 'rgba(255,255,255,0.025)',
      border: '0.5px solid rgba(255,255,255,0.06)',
    }}>
      <div style={{ fontSize: 9, color: 'rgba(255,255,255,0.4)', letterSpacing: 1, textTransform: 'uppercase' }}>{label}</div>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 1, margin: '4px 0 6px' }}>
        <span style={{ fontSize: 20, fontWeight: 500, fontVariantNumeric: 'tabular-nums', letterSpacing: -0.5 }}>{value}</span>
        <span style={{ fontSize: 9, color: 'rgba(255,255,255,0.45)' }}>{unit}</span>
      </div>
      <div style={{ height: 2, background: 'rgba(255,255,255,0.06)', borderRadius: 1, overflow: 'hidden' }}>
        <div style={{ width: `${bar * 100}%`, height: '100%', background: accent, boxShadow: `0 0 4px ${accent}` }} />
      </div>
    </div>
  );
}

function TapeFan({ fan, accent }) {
  const pct = fan.rpm / fan.max;
  const spinDur = `${Math.max(0.5, 3 - fan.duty * 2.5)}s`;
  return (
    <div>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 5 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <div style={{ animation: `fc-spin ${spinDur} linear infinite`, display: 'flex' }}>
            <FanGlyph color={accent} size={11} />
          </div>
          <span style={{ fontSize: 11, fontWeight: 500, color: 'rgba(255,255,255,0.85)' }}>{fan.name}</span>
        </div>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 8 }}>
          <span style={{ fontSize: 10, color: 'rgba(255,255,255,0.4)', fontVariantNumeric: 'tabular-nums', fontFamily: FC_MONO }}>{Math.round(fan.duty * 100)}%</span>
          <span style={{ fontSize: 12, fontWeight: 500, fontVariantNumeric: 'tabular-nums' }}>
            {fan.rpm.toLocaleString()}<span style={{ fontSize: 9, color: 'rgba(255,255,255,0.4)', marginLeft: 2 }}>RPM</span>
          </span>
        </div>
      </div>
      {/* tape: 28 ticks */}
      <div style={{ display: 'flex', gap: 1.5, height: 18, alignItems: 'flex-end' }}>
        {Array.from({ length: 28 }).map((_, i) => {
          const filled = (i / 27) <= pct;
          const isPeak = i === Math.round(pct * 27);
          return (
            <div key={i} style={{
              flex: 1,
              height: filled ? `${60 + (i / 27) * 40}%` : '40%',
              background: filled ? accent : 'rgba(255,255,255,0.07)',
              opacity: filled ? (0.4 + (i / 27) * 0.6) : 1,
              borderRadius: 0.5,
              boxShadow: isPeak ? `0 0 8px ${accent}` : 'none',
            }} />
          );
        })}
      </div>
    </div>
  );
}

function PresetRow({ preset, active, accent, onClick }) {
  return (
    <button onClick={onClick} style={{
      appearance: 'none', border: 'none', cursor: 'pointer',
      width: '100%',
      display: 'flex', alignItems: 'center', gap: 10,
      padding: '8px 10px',
      borderRadius: 8,
      background: active ? hexToRgba(accent, 0.12) : 'transparent',
      border: active ? `0.5px solid ${hexToRgba(accent, 0.35)}` : '0.5px solid transparent',
      color: 'inherit', fontFamily: 'inherit',
      transition: 'background .15s',
    }}>
      <div style={{
        width: 26, height: 26, borderRadius: 7,
        background: active ? hexToRgba(accent, 0.2) : 'rgba(255,255,255,0.04)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        color: active ? accent : 'rgba(255,255,255,0.55)',
      }}>{preset.icon}</div>
      <div style={{ flex: 1, textAlign: 'left' }}>
        <div style={{ fontSize: 12, fontWeight: 500, color: 'rgba(255,255,255,0.92)' }}>{preset.label}</div>
        <div style={{ fontSize: 10, color: 'rgba(255,255,255,0.4)', marginTop: 1 }}>{preset.sub}</div>
      </div>
      {active && <div style={{ width: 5, height: 5, borderRadius: '50%', background: accent, boxShadow: `0 0 6px ${accent}` }} />}
      {preset.action && (
        <svg width="11" height="11" viewBox="0 0 12 12" style={{ color: 'rgba(255,255,255,0.35)' }}>
          <path d="M4 2 L8 6 L4 10" stroke="currentColor" strokeWidth="1.5" fill="none" strokeLinecap="round" />
        </svg>
      )}
    </button>
  );
}

function PresetGlyph({ kind }) {
  switch (kind) {
    case 'silent': return <svg width="13" height="13" viewBox="0 0 16 16"><path d="M3 6 H5 L9 3 V13 L5 10 H3 Z M11 5 Q13 8, 11 11" stroke="currentColor" fill="none" strokeWidth="1.3" strokeLinecap="round" strokeLinejoin="round" /></svg>;
    case 'balanced': return <svg width="13" height="13" viewBox="0 0 16 16"><circle cx="8" cy="8" r="2" fill="currentColor" /><circle cx="8" cy="8" r="5.5" stroke="currentColor" fill="none" strokeWidth="1.3" strokeDasharray="2 2" /></svg>;
    case 'perf': return <svg width="13" height="13" viewBox="0 0 16 16"><path d="M2 12 L6 6 L9 9 L14 3" stroke="currentColor" fill="none" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" /></svg>;
    case 'max': return <svg width="13" height="13" viewBox="0 0 16 16"><path d="M5 2 L3 9 H7 L5 14 L13 6 H8 L10 2 Z" fill="currentColor" /></svg>;
    case 'curve': return <svg width="13" height="13" viewBox="0 0 16 16"><path d="M2 12 C 5 12, 6 4, 9 4 S 13 12, 14 12" stroke="currentColor" fill="none" strokeWidth="1.5" strokeLinecap="round" /></svg>;
    default: return null;
  }
}

Object.assign(window, { MainSpectrum });

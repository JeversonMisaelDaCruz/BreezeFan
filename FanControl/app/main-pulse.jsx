// MainPulse.jsx — V1: Hero dial layout
// Strong focal: a big translucent ring showing the system's loudest fan.
// Below it: fans list with mini-bars, sensor meters, preset row.

function MainPulse({ accent = '#3b82f6', tempUnit = 'C', density = 'regular', onOpenCurve }) {
  const [activePreset, setActivePreset] = React.useState('balanced');
  const [fanFilter, setFanFilter] = React.useState('all');

  const fans = [
    { id: 'f1', name: 'Left Fan', rpm: 4280, max: 6500, duty: 0.66 },
    { id: 'f2', name: 'Right Fan', rpm: 4510, max: 6500, duty: 0.69 },
  ];
  const heroRpm = Math.max(...fans.map(f => f.rpm));
  const heroMax = 6500;
  const sensors = [
    { label: 'CPU', value: 67, max: 105, unit: '°' + tempUnit },
    { label: 'GPU', value: 54, max: 95, unit: '°' + tempUnit },
    { label: 'Battery', value: 32, max: 60, unit: '°' + tempUnit },
  ];

  const PRESETS = [
    { id: 'silent', label: 'Silent' },
    { id: 'balanced', label: 'Balanced' },
    { id: 'performance', label: 'Performance' },
    { id: 'max', label: 'Max' },
  ];

  const padY = density === 'compact' ? 8 : density === 'comfy' ? 16 : 12;

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', overflow: 'auto' }}>
      {/* Hero block */}
      <div style={{ padding: `${padY}px 16px 18px`, display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
        {/* status row */}
        <div style={{
          display: 'inline-flex', alignItems: 'center', gap: 6,
          padding: '4px 10px', borderRadius: 99,
          background: 'rgba(34,197,94,0.10)',
          border: '0.5px solid rgba(34,197,94,0.25)',
          fontSize: 10, fontWeight: 500, color: '#86efac',
          letterSpacing: 0.4,
          marginBottom: 14,
        }}>
          <span style={{ width: 6, height: 6, borderRadius: '50%', background: '#22c55e', boxShadow: '0 0 8px #22c55e', animation: 'fc-pulse 2s infinite' }} />
          AUTO · MacBook Pro 16″
        </div>

        {/* big dial */}
        <HeroRing accent={accent} value={heroRpm} max={heroMax} fanCount={fans.length} />

        {/* legend below ring */}
        <div style={{ marginTop: 14, display: 'flex', gap: 18, fontSize: 10, color: 'rgba(255,255,255,0.45)', textTransform: 'uppercase', letterSpacing: 1 }}>
          <LegendStat label="Avg" value={`${Math.round((fans[0].rpm + fans[1].rpm) / 2).toLocaleString()} rpm`} />
          <LegendStat label="Noise" value="38 dB" />
          <LegendStat label="Power" value="42 W" />
        </div>
      </div>

      <FCDivider />

      {/* Fans */}
      <FCSection title="Fans" padding={14} action={
        <FilterPills value={fanFilter} onChange={setFanFilter} options={[
          { value: 'all', label: 'All' },
          { value: 'f1', label: 'L' },
          { value: 'f2', label: 'R' },
        ]} />
      }>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
          {fans
            .filter(f => fanFilter === 'all' || f.id === fanFilter)
            .map(f => <FCFanRow key={f.id} {...f} maxRpm={f.max} accent={accent} />)
          }
        </div>
      </FCSection>

      <FCDivider />

      {/* Sensors */}
      <FCSection title="Thermals">
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          {sensors.map(s => <FCMeter key={s.label} {...s} accent={accent} />)}
        </div>
      </FCSection>

      <FCDivider />

      {/* Presets */}
      <FCSection title="Profile">
        <FCSegment value={activePreset} onChange={setActivePreset}
          options={PRESETS.map(p => ({ value: p.id, label: p.label }))} />
        <div style={{ marginTop: 10 }}>
          <button onClick={onOpenCurve} style={{
            width: '100%', appearance: 'none', cursor: 'pointer',
            padding: '10px 14px', borderRadius: 10,
            background: `linear-gradient(180deg, ${hexToRgba(accent, 0.95)} 0%, ${hexToRgba(accent, 0.82)} 100%)`,
            border: `0.5px solid ${hexToRgba(accent, 1)}`,
            color: '#fff', fontFamily: 'inherit', fontSize: 12, fontWeight: 600,
            letterSpacing: 0.2,
            display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
            boxShadow: `0 4px 14px ${hexToRgba(accent, 0.35)}, inset 0 0.5px 0 rgba(255,255,255,0.4)`,
          }}>
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none">
              <path d="M3 18 C 7 18, 9 6, 13 6 S 17 18, 21 18" stroke="white" strokeWidth="2" strokeLinecap="round" />
            </svg>
            Edit Custom Curve
          </button>
        </div>
      </FCSection>
    </div>
  );
}

function HeroRing({ accent, value, max, fanCount }) {
  const size = 200, stroke = 10;
  const r = (size - stroke) / 2;
  const c = 2 * Math.PI * r;
  // ring spans 270deg arc (from -135° to +135°)
  const arcSpan = 0.75;
  const pct = Math.max(0, Math.min(1, value / max));
  const dash = c * arcSpan;
  const filled = c * arcSpan * pct;
  return (
    <div style={{ position: 'relative', width: size, height: size }}>
      <svg width={size} height={size} style={{ transform: 'rotate(135deg)' }}>
        <defs>
          <linearGradient id="heroRingGrad" x1="0" y1="0" x2="1" y2="1">
            <stop offset="0%" stopColor={accent} stopOpacity="1" />
            <stop offset="100%" stopColor={accent} stopOpacity="0.5" />
          </linearGradient>
        </defs>
        {/* track */}
        <circle cx={size / 2} cy={size / 2} r={r} fill="none"
                stroke="rgba(255,255,255,0.06)" strokeWidth={stroke}
                strokeDasharray={`${dash} ${c}`} strokeLinecap="round" />
        {/* tick marks */}
        {Array.from({ length: 11 }).map((_, i) => {
          const ang = (i / 10) * arcSpan * 360 - 90;
          const innerR = r - stroke / 2 - 2;
          const outerR = r - stroke / 2 - 8;
          const a = (ang * Math.PI) / 180;
          const x1 = size / 2 + Math.cos(a) * innerR;
          const y1 = size / 2 + Math.sin(a) * innerR;
          const x2 = size / 2 + Math.cos(a) * outerR;
          const y2 = size / 2 + Math.sin(a) * outerR;
          const lit = (i / 10) <= pct;
          return <line key={i} x1={x1} y1={y1} x2={x2} y2={y2}
                       stroke={lit ? accent : 'rgba(255,255,255,0.15)'}
                       strokeWidth="1.5" strokeLinecap="round"
                       style={{ filter: lit ? `drop-shadow(0 0 4px ${accent})` : 'none' }} />;
        })}
        {/* value arc */}
        <circle cx={size / 2} cy={size / 2} r={r} fill="none"
                stroke="url(#heroRingGrad)" strokeWidth={stroke}
                strokeDasharray={`${filled} ${c}`} strokeLinecap="round"
                style={{ transition: 'stroke-dasharray 1.2s cubic-bezier(.2,.7,.2,1)', filter: `drop-shadow(0 0 8px ${accent}66)` }} />
      </svg>

      {/* center content */}
      <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center' }}>
        <div style={{ fontSize: 10, color: 'rgba(255,255,255,0.45)', letterSpacing: 2, textTransform: 'uppercase' }}>RPM</div>
        <div style={{ fontSize: 44, fontWeight: 300, fontVariantNumeric: 'tabular-nums', letterSpacing: -2, marginTop: 2, lineHeight: 1, fontFamily: '-apple-system, BlinkMacSystemFont, sans-serif' }}>
          {value.toLocaleString()}
        </div>
        <div style={{ fontSize: 10, color: 'rgba(255,255,255,0.55)', marginTop: 6, letterSpacing: 0.4 }}>
          {fanCount} fans · peak
        </div>
      </div>
    </div>
  );
}

function LegendStat({ label, value }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 2 }}>
      <span style={{ color: 'rgba(255,255,255,0.35)' }}>{label}</span>
      <span style={{ color: 'rgba(255,255,255,0.85)', fontSize: 11, fontWeight: 500, letterSpacing: 0, textTransform: 'none' }}>{value}</span>
    </div>
  );
}

function FilterPills({ value, onChange, options }) {
  return (
    <div style={{ display: 'flex', gap: 4, padding: 2, background: 'rgba(0,0,0,0.3)', borderRadius: 7, border: '0.5px solid rgba(255,255,255,0.05)' }}>
      {options.map(o => (
        <button key={o.value} onClick={() => onChange(o.value)} style={{
          appearance: 'none', border: 'none', cursor: 'pointer',
          padding: '3px 9px', borderRadius: 5,
          background: value === o.value ? 'rgba(255,255,255,0.12)' : 'transparent',
          color: value === o.value ? '#fff' : 'rgba(255,255,255,0.5)',
          fontSize: 10, fontWeight: 500, fontFamily: 'inherit',
        }}>{o.label}</button>
      ))}
    </div>
  );
}

Object.assign(window, { MainPulse });

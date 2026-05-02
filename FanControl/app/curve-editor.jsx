// CurveEditor.jsx — modal sheet for editing a temperature → fan duty curve
// Step table editor: rows of { temp, duty } with an inline visualization graph.

function CurveEditor({ accent = '#3b82f6', tempUnit = 'C', onClose }) {
  const [name, setName] = React.useState('Render Mode');
  const [appBinding, setAppBinding] = React.useState('com.apple.finalcutpro');
  const [steps, setSteps] = React.useState([
    { temp: 30, duty: 15 },
    { temp: 45, duty: 25 },
    { temp: 55, duty: 40 },
    { temp: 65, duty: 60 },
    { temp: 75, duty: 80 },
    { temp: 85, duty: 100 },
  ]);
  const [hover, setHover] = React.useState(null);

  const updateStep = (i, key, val) => {
    setSteps(prev => prev.map((s, idx) => idx === i ? { ...s, [key]: val } : s));
  };
  const addStep = () => {
    if (steps.length >= 8) return;
    const last = steps[steps.length - 1];
    setSteps([...steps, { temp: Math.min(105, last.temp + 5), duty: Math.min(100, last.duty + 5) }]);
  };
  const removeStep = (i) => {
    if (steps.length <= 2) return;
    setSteps(prev => prev.filter((_, idx) => idx !== i));
  };

  return (
    <div style={{
      position: 'absolute', inset: 0,
      background: 'rgba(8,9,11,0.7)',
      backdropFilter: 'blur(20px) saturate(150%)',
      WebkitBackdropFilter: 'blur(20px) saturate(150%)',
      zIndex: 100,
      display: 'flex', flexDirection: 'column',
      animation: 'fc-sheet-in .26s cubic-bezier(.2,.8,.3,1)',
    }}>
      {/* sheet header */}
      <div style={{
        display: 'flex', alignItems: 'center',
        padding: '12px 14px 10px', gap: 8,
        borderBottom: '0.5px solid rgba(255,255,255,0.06)',
      }}>
        <button onClick={onClose} style={{
          appearance: 'none', border: 'none', cursor: 'pointer',
          padding: '4px 8px', borderRadius: 6,
          background: 'rgba(255,255,255,0.06)',
          color: 'rgba(255,255,255,0.7)', fontFamily: 'inherit',
          display: 'flex', alignItems: 'center', gap: 4, fontSize: 11,
        }}>
          <svg width="9" height="9" viewBox="0 0 12 12"><path d="M8 2 L4 6 L8 10" stroke="currentColor" strokeWidth="1.5" fill="none" strokeLinecap="round" /></svg>
          Back
        </button>
        <div style={{ flex: 1, textAlign: 'center', fontSize: 12, fontWeight: 600, color: 'rgba(255,255,255,0.92)' }}>
          Custom Curve
        </div>
        <button style={{
          appearance: 'none', border: 'none', cursor: 'pointer',
          padding: '4px 10px', borderRadius: 6,
          background: hexToRgba(accent, 0.18),
          color: accent, fontFamily: 'inherit', fontSize: 11, fontWeight: 600,
          border: `0.5px solid ${hexToRgba(accent, 0.35)}`,
        }}>Save</button>
      </div>

      <div style={{ flex: 1, overflow: 'auto' }}>
        {/* name + binding */}
        <FCSection title="Identity">
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            <LabeledInput label="Name" value={name} onChange={setName} />
            <BindingPicker value={appBinding} onChange={setAppBinding} accent={accent} />
          </div>
        </FCSection>

        <FCDivider />

        {/* graph */}
        <FCSection title="Curve" action={
          <span style={{ fontSize: 10, color: 'rgba(255,255,255,0.4)', fontFamily: FC_MONO }}>
            {steps.length} steps
          </span>
        }>
          <CurveGraph steps={steps} accent={accent} hover={hover} setHover={setHover} tempUnit={tempUnit} />
        </FCSection>

        <FCDivider />

        {/* step table */}
        <FCSection title="Steps" action={
          <button onClick={addStep} disabled={steps.length >= 8} style={{
            appearance: 'none', border: 'none', cursor: steps.length >= 8 ? 'default' : 'pointer',
            padding: '3px 8px', borderRadius: 5,
            background: 'rgba(255,255,255,0.06)',
            color: steps.length >= 8 ? 'rgba(255,255,255,0.25)' : 'rgba(255,255,255,0.7)',
            fontFamily: 'inherit', fontSize: 10, fontWeight: 500,
            display: 'flex', alignItems: 'center', gap: 3,
          }}>+ Add step</button>
        }>
          {/* table header */}
          <div style={{
            display: 'grid', gridTemplateColumns: '24px 1fr 1fr 22px',
            gap: 8, alignItems: 'center',
            padding: '0 4px 6px', fontSize: 9,
            color: 'rgba(255,255,255,0.35)', textTransform: 'uppercase', letterSpacing: 1,
          }}>
            <span>#</span>
            <span>Temp °{tempUnit}</span>
            <span>Fan duty %</span>
            <span></span>
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
            {steps.map((s, i) => (
              <StepRow key={i} index={i} step={s} accent={accent}
                       onTemp={(v) => updateStep(i, 'temp', v)}
                       onDuty={(v) => updateStep(i, 'duty', v)}
                       onRemove={() => removeStep(i)}
                       canRemove={steps.length > 2}
                       hovered={hover === i}
                       onHover={(b) => setHover(b ? i : null)} />
            ))}
          </div>
        </FCSection>

        <FCDivider />

        {/* options */}
        <FCSection title="Behavior">
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            <ToggleRow label="Hysteresis (3°)" sub="Prevent oscillation around thresholds" defaultOn accent={accent} />
            <ToggleRow label="Auto-engage on app launch" sub="When Final Cut Pro is active" defaultOn accent={accent} />
            <ToggleRow label="Battery override" sub="Cap at 60% on battery" accent={accent} />
          </div>
        </FCSection>
      </div>
    </div>
  );
}

// ─── graph ────────────────────────────────────────────────────────────
function CurveGraph({ steps, accent, hover, setHover, tempUnit }) {
  const W = 320, H = 140, PAD = { l: 28, r: 8, t: 8, b: 22 };
  const minT = 20, maxT = 105;
  const xFor = (t) => PAD.l + ((t - minT) / (maxT - minT)) * (W - PAD.l - PAD.r);
  const yFor = (d) => PAD.t + (1 - d / 100) * (H - PAD.t - PAD.b);

  // build polyline path with stairstep curve
  const pts = steps.map(s => ({ x: xFor(s.temp), y: yFor(s.duty) }));
  const path = pts.map((p, i) => `${i === 0 ? 'M' : 'L'} ${p.x.toFixed(1)} ${p.y.toFixed(1)}`).join(' ');
  const areaPath = `${path} L ${pts[pts.length - 1].x} ${H - PAD.b} L ${pts[0].x} ${H - PAD.b} Z`;

  return (
    <div style={{ background: 'rgba(0,0,0,0.3)', borderRadius: 10, padding: 8, border: '0.5px solid rgba(255,255,255,0.05)' }}>
      <svg width="100%" viewBox={`0 0 ${W} ${H}`} style={{ display: 'block' }}>
        <defs>
          <linearGradient id="curveArea" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor={accent} stopOpacity="0.35" />
            <stop offset="100%" stopColor={accent} stopOpacity="0" />
          </linearGradient>
        </defs>
        {/* gridlines */}
        {[0, 25, 50, 75, 100].map(d => (
          <g key={d}>
            <line x1={PAD.l} x2={W - PAD.r} y1={yFor(d)} y2={yFor(d)} stroke="rgba(255,255,255,0.05)" strokeDasharray="2 3" />
            <text x={PAD.l - 6} y={yFor(d) + 3} fontSize="8" fill="rgba(255,255,255,0.35)" textAnchor="end" fontFamily="ui-monospace, monospace">{d}</text>
          </g>
        ))}
        {[30, 50, 70, 90].map(t => (
          <text key={t} x={xFor(t)} y={H - 6} fontSize="8" fill="rgba(255,255,255,0.35)" textAnchor="middle" fontFamily="ui-monospace, monospace">{t}°</text>
        ))}

        {/* danger zone */}
        <rect x={xFor(85)} y={PAD.t} width={W - PAD.r - xFor(85)} height={H - PAD.t - PAD.b}
              fill="rgba(239,68,68,0.06)" />

        {/* area + line */}
        <path d={areaPath} fill="url(#curveArea)" />
        <path d={path} fill="none" stroke={accent} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"
              style={{ filter: `drop-shadow(0 0 4px ${accent}88)` }} />

        {/* points */}
        {pts.map((p, i) => (
          <g key={i} onMouseEnter={() => setHover(i)} onMouseLeave={() => setHover(null)} style={{ cursor: 'pointer' }}>
            <circle cx={p.x} cy={p.y} r="9" fill="transparent" />
            <circle cx={p.x} cy={p.y} r={hover === i ? 4 : 3} fill="#0f1013" stroke={accent} strokeWidth="1.5" />
          </g>
        ))}

        {/* hover label */}
        {hover !== null && (
          <g transform={`translate(${pts[hover].x}, ${pts[hover].y - 14})`}>
            <rect x="-22" y="-12" width="44" height="14" rx="3" fill={accent} />
            <text x="0" y="-2" fontSize="8" fill="#fff" textAnchor="middle" fontFamily="ui-monospace, monospace" fontWeight="600">
              {steps[hover].temp}° / {steps[hover].duty}%
            </text>
          </g>
        )}
      </svg>
    </div>
  );
}

// ─── step row ─────────────────────────────────────────────────────────
function StepRow({ index, step, accent, onTemp, onDuty, onRemove, canRemove, hovered, onHover }) {
  return (
    <div
      onMouseEnter={() => onHover(true)}
      onMouseLeave={() => onHover(false)}
      style={{
        display: 'grid', gridTemplateColumns: '24px 1fr 1fr 22px',
        gap: 8, alignItems: 'center',
        padding: '4px 4px',
        borderRadius: 6,
        background: hovered ? 'rgba(255,255,255,0.04)' : 'transparent',
        transition: 'background .15s',
      }}>
      <span style={{ fontSize: 10, color: 'rgba(255,255,255,0.4)', fontFamily: FC_MONO, textAlign: 'center' }}>
        {String(index + 1).padStart(2, '0')}
      </span>
      <NumStepper value={step.temp} onChange={onTemp} min={20} max={105} step={1} suffix="°" accent={accent} />
      <NumStepper value={step.duty} onChange={onDuty} min={0} max={100} step={5} suffix="%" accent={accent} />
      <button onClick={onRemove} disabled={!canRemove} style={{
        appearance: 'none', border: 'none', cursor: canRemove ? 'pointer' : 'default',
        background: 'transparent', borderRadius: 4,
        color: canRemove ? 'rgba(255,255,255,0.4)' : 'rgba(255,255,255,0.15)',
        width: 22, height: 22, display: 'flex', alignItems: 'center', justifyContent: 'center',
      }}>
        <svg width="10" height="10" viewBox="0 0 12 12"><path d="M3 3 L9 9 M9 3 L3 9" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" /></svg>
      </button>
    </div>
  );
}

function NumStepper({ value, onChange, min, max, step = 1, suffix, accent }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'center',
      background: 'rgba(0,0,0,0.3)',
      border: '0.5px solid rgba(255,255,255,0.06)',
      borderRadius: 6,
      height: 26,
      overflow: 'hidden',
    }}>
      <button onClick={() => onChange(Math.max(min, value - step))} style={stepBtn}>−</button>
      <div style={{
        flex: 1, textAlign: 'center', fontSize: 11, fontWeight: 500,
        color: '#fff', fontVariantNumeric: 'tabular-nums', fontFamily: FC_MONO,
      }}>
        {value}<span style={{ color: 'rgba(255,255,255,0.4)', marginLeft: 1 }}>{suffix}</span>
      </div>
      <button onClick={() => onChange(Math.min(max, value + step))} style={stepBtn}>+</button>
    </div>
  );
}
const stepBtn = {
  appearance: 'none', border: 'none', cursor: 'pointer',
  width: 22, height: '100%',
  background: 'transparent', color: 'rgba(255,255,255,0.6)',
  fontSize: 13, fontFamily: 'inherit', fontWeight: 400,
};

function LabeledInput({ label, value, onChange }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
      <span style={{ fontSize: 10, color: 'rgba(255,255,255,0.4)', textTransform: 'uppercase', letterSpacing: 1 }}>{label}</span>
      <input value={value} onChange={(e) => onChange(e.target.value)} style={{
        appearance: 'none',
        height: 28, padding: '0 10px',
        background: 'rgba(0,0,0,0.3)',
        border: '0.5px solid rgba(255,255,255,0.08)',
        borderRadius: 7,
        color: '#fff', fontFamily: 'inherit', fontSize: 12, outline: 'none',
      }} />
    </div>
  );
}

function BindingPicker({ value, onChange, accent }) {
  const apps = [
    { id: 'com.apple.finalcutpro', name: 'Final Cut Pro', icon: '🎬' },
    { id: 'com.apple.logicpro', name: 'Logic Pro', icon: '🎵' },
    { id: 'com.blackmagic.davinci', name: 'DaVinci Resolve', icon: '🎞' },
    { id: 'global', name: 'Always (no binding)', icon: '∞' },
  ];
  const cur = apps.find(a => a.id === value) || apps[0];
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
      <span style={{ fontSize: 10, color: 'rgba(255,255,255,0.4)', textTransform: 'uppercase', letterSpacing: 1 }}>Trigger</span>
      <div style={{
        display: 'flex', alignItems: 'center', gap: 8,
        height: 30, padding: '0 10px',
        background: 'rgba(0,0,0,0.3)',
        border: '0.5px solid rgba(255,255,255,0.08)',
        borderRadius: 7,
      }}>
        <div style={{
          width: 18, height: 18, borderRadius: 4,
          background: hexToRgba(accent, 0.18),
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          fontSize: 11,
        }}>{cur.icon}</div>
        <span style={{ flex: 1, fontSize: 12, color: 'rgba(255,255,255,0.9)' }}>{cur.name}</span>
        <svg width="9" height="9" viewBox="0 0 12 12" style={{ color: 'rgba(255,255,255,0.4)' }}>
          <path d="M3 5 L6 8 L9 5" stroke="currentColor" strokeWidth="1.5" fill="none" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
      </div>
    </div>
  );
}

function ToggleRow({ label, sub, defaultOn, accent }) {
  const [on, setOn] = React.useState(!!defaultOn);
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 12, fontWeight: 500, color: 'rgba(255,255,255,0.92)' }}>{label}</div>
        {sub && <div style={{ fontSize: 10, color: 'rgba(255,255,255,0.4)', marginTop: 2 }}>{sub}</div>}
      </div>
      <button onClick={() => setOn(!on)} style={{
        appearance: 'none', border: 'none', cursor: 'pointer',
        width: 32, height: 18, borderRadius: 99,
        position: 'relative',
        background: on ? accent : 'rgba(255,255,255,0.12)',
        boxShadow: on ? `0 0 10px ${hexToRgba(accent, 0.4)}` : 'none',
        transition: 'background .15s',
      }}>
        <div style={{
          position: 'absolute',
          top: 2, left: on ? 16 : 2,
          width: 14, height: 14, borderRadius: '50%',
          background: '#fff',
          boxShadow: '0 1px 2px rgba(0,0,0,0.3)',
          transition: 'left .15s',
        }} />
      </button>
    </div>
  );
}

// inject sheet animation once
if (typeof document !== 'undefined' && !document.getElementById('fc-sheet-anim')) {
  const s = document.createElement('style');
  s.id = 'fc-sheet-anim';
  s.textContent = `@keyframes fc-sheet-in { from { transform: translateY(20px); opacity: 0 } to { transform: translateY(0); opacity: 1 } }`;
  document.head.appendChild(s);
}

Object.assign(window, { CurveEditor });

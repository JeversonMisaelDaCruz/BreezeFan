// CurveMVP.jsx — Liquid Glass curve editor (modal sheet)

function CurveMVP({ accent = '#3b82f6', tempUnit = 'C', onClose, animate = true }) {
  const [steps, setSteps] = React.useState([
    { temp: 40, duty: 20 },
    { temp: 60, duty: 50 },
    { temp: 75, duty: 80 },
    { temp: 90, duty: 100 },
  ]);
  const [hover, setHover] = React.useState(null);

  const updateStep = (i, key, val) => setSteps(prev => prev.map((s, idx) => idx === i ? { ...s, [key]: val } : s));
  const addStep = () => {
    if (steps.length >= 6) return;
    const last = steps[steps.length - 1];
    setSteps([...steps, { temp: Math.min(105, last.temp + 5), duty: Math.min(100, last.duty + 5) }]);
  };
  const removeStep = (i) => steps.length > 2 && setSteps(prev => prev.filter((_, idx) => idx !== i));

  return (
    <div style={{
      position: 'absolute', inset: 0,
      zIndex: 100,
      display: 'flex', flexDirection: 'column',
      animation: animate ? 'fc-sheet-in .26s cubic-bezier(.2,.8,.3,1) both' : 'none',
    }}>
      {/* heavy frosted veil over the wallpaper */}
      <div style={{
        position: 'absolute', inset: 0,
        background: 'rgba(10,12,18,0.55)',
        backdropFilter: 'blur(50px) saturate(180%)',
        WebkitBackdropFilter: 'blur(50px) saturate(180%)',
      }} />
      {/* top sheen */}
      <div style={{
        position: 'absolute', top: 0, left: 0, right: 0, height: '40%',
        background: 'linear-gradient(180deg, rgba(255,255,255,0.13) 0%, rgba(255,255,255,0) 100%)',
        pointerEvents: 'none',
      }} />

      <div style={{ position: 'relative', display: 'flex', flexDirection: 'column', height: '100%' }}>
        {/* header */}
        <div style={{
          display: 'flex', alignItems: 'center',
          padding: '12px 14px',
          gap: 8,
          borderBottom: '0.5px solid rgba(255,255,255,0.10)',
        }}>
          <button onClick={onClose} style={{
            appearance: 'none', border: 'none', cursor: 'pointer',
            padding: '5px 10px', borderRadius: 7,
            background: 'rgba(255,255,255,0.10)',
            boxShadow: 'inset 0 0 0 0.5px rgba(255,255,255,0.18), inset 0 1px 0 rgba(255,255,255,0.22)',
            backdropFilter: 'blur(10px)',
            WebkitBackdropFilter: 'blur(10px)',
            color: 'rgba(255,255,255,0.85)', fontFamily: 'inherit',
            display: 'flex', alignItems: 'center', gap: 4, fontSize: 11, fontWeight: 500,
          }}>
            <svg width="9" height="9" viewBox="0 0 12 12"><path d="M8 2 L4 6 L8 10" stroke="currentColor" strokeWidth="1.5" fill="none" strokeLinecap="round" /></svg>
            Cancel
          </button>
          <div style={{ flex: 1, textAlign: 'center', fontSize: 12.5, fontWeight: 600, color: '#fff', textShadow: '0 1px 0 rgba(0,0,0,0.3)' }}>Fan Curve</div>
          <button onClick={onClose} style={{
            appearance: 'none', cursor: 'pointer',
            padding: '5px 14px', borderRadius: 7,
            background: `linear-gradient(180deg, ${hexToRgba(accent, 0.6)} 0%, ${hexToRgba(accent, 0.4)} 100%)`,
            boxShadow: `inset 0 0 0 0.5px ${hexToRgba(accent, 0.7)}, inset 0 1px 0 rgba(255,255,255,0.35), 0 4px 14px ${hexToRgba(accent, 0.4)}`,
            color: '#fff', fontFamily: 'inherit', fontSize: 11, fontWeight: 600,
            border: 'none',
          }}>Save</button>
        </div>

        <div style={{ flex: 1, overflow: 'auto', padding: '14px', display: 'flex', flexDirection: 'column', gap: 12 }}>
          {/* graph card */}
          <GlassSurface radius={16} padding="14px" style={{ overflow: 'hidden' }}>
            <div style={{ fontSize: 10, fontWeight: 600, letterSpacing: 1.6, textTransform: 'uppercase', color: 'rgba(255,255,255,0.55)', marginBottom: 10 }}>Preview</div>
            <CurveGraph steps={steps} accent={accent} hover={hover} setHover={setHover} tempUnit={tempUnit} />
          </GlassSurface>

          {/* steps card */}
          <GlassSurface radius={16} padding="14px 14px 12px" style={{ overflow: 'hidden' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10 }}>
              <div style={{ fontSize: 10, fontWeight: 600, letterSpacing: 1.6, textTransform: 'uppercase', color: 'rgba(255,255,255,0.55)' }}>Steps</div>
              <button onClick={addStep} disabled={steps.length >= 6} style={{
                appearance: 'none', border: 'none',
                cursor: steps.length >= 6 ? 'default' : 'pointer',
                padding: '4px 9px', borderRadius: 6,
                background: 'rgba(255,255,255,0.10)',
                boxShadow: 'inset 0 0 0 0.5px rgba(255,255,255,0.18)',
                color: steps.length >= 6 ? 'rgba(255,255,255,0.3)' : 'rgba(255,255,255,0.85)',
                fontFamily: 'inherit', fontSize: 10, fontWeight: 600,
              }}>+ Add</button>
            </div>
            <div style={{
              display: 'grid', gridTemplateColumns: '1fr 1fr 22px',
              gap: 8, padding: '0 4px 6px', fontSize: 9,
              color: 'rgba(255,255,255,0.45)', textTransform: 'uppercase', letterSpacing: 1, fontWeight: 600,
            }}>
              <span>Temperature</span>
              <span>Fan speed</span>
              <span></span>
            </div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
              {steps.map((s, i) => (
                <div key={i}
                  onMouseEnter={() => setHover(i)} onMouseLeave={() => setHover(null)}
                  style={{
                    display: 'grid', gridTemplateColumns: '1fr 1fr 22px',
                    gap: 8, alignItems: 'center', padding: '4px',
                    borderRadius: 8,
                    background: hover === i ? 'rgba(255,255,255,0.07)' : 'transparent',
                    transition: 'background .15s',
                  }}>
                  <GlassStepper value={s.temp} onChange={(v) => updateStep(i, 'temp', v)}
                                min={20} max={105} step={1} suffix={`°${tempUnit}`} />
                  <GlassStepper value={s.duty} onChange={(v) => updateStep(i, 'duty', v)}
                                min={0} max={100} step={5} suffix="%" />
                  <button onClick={() => removeStep(i)} disabled={steps.length <= 2} style={{
                    appearance: 'none', border: 'none',
                    cursor: steps.length <= 2 ? 'default' : 'pointer',
                    background: 'transparent',
                    color: steps.length <= 2 ? 'rgba(255,255,255,0.15)' : 'rgba(255,255,255,0.5)',
                    width: 22, height: 22, display: 'flex', alignItems: 'center', justifyContent: 'center',
                  }}>
                    <svg width="10" height="10" viewBox="0 0 12 12"><path d="M3 3 L9 9 M9 3 L3 9" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" /></svg>
                  </button>
                </div>
              ))}
            </div>
          </GlassSurface>
        </div>
      </div>
    </div>
  );
}

function GlassStepper({ value, onChange, min, max, step = 1, suffix }) {
  const btn = {
    appearance: 'none', border: 'none', cursor: 'pointer',
    width: 24, height: '100%',
    background: 'transparent', color: 'rgba(255,255,255,0.75)',
    fontSize: 14, fontFamily: 'inherit', fontWeight: 400,
  };
  return (
    <div style={{
      display: 'flex', alignItems: 'center',
      background: 'rgba(0,0,0,0.25)',
      boxShadow: 'inset 0 0 0 0.5px rgba(255,255,255,0.12), inset 0 1px 0 rgba(255,255,255,0.06), inset 0 -0.5px 1px rgba(0,0,0,0.35)',
      borderRadius: 8,
      height: 28,
      overflow: 'hidden',
    }}>
      <button onClick={() => onChange(Math.max(min, value - step))} style={btn}>−</button>
      <div style={{
        flex: 1, textAlign: 'center', fontSize: 11.5, fontWeight: 600,
        color: '#fff', fontVariantNumeric: 'tabular-nums', fontFamily: FC_MONO,
      }}>
        {value}<span style={{ color: 'rgba(255,255,255,0.5)', marginLeft: 1, fontWeight: 500 }}>{suffix}</span>
      </div>
      <button onClick={() => onChange(Math.min(max, value + step))} style={btn}>+</button>
    </div>
  );
}

Object.assign(window, { CurveMVP });

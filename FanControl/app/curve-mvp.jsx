// CurveMVP.jsx — simplified curve editor for MVP
// Just: graph + step table + save. No bindings, no toggles.

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
      background: 'rgba(8,9,11,0.85)',
      backdropFilter: 'blur(20px) saturate(150%)',
      WebkitBackdropFilter: 'blur(20px) saturate(150%)',
      zIndex: 100,
      display: 'flex', flexDirection: 'column',
      animation: animate ? 'fc-sheet-in .26s cubic-bezier(.2,.8,.3,1) both' : 'none',
    }}>
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
          Cancel
        </button>
        <div style={{ flex: 1, textAlign: 'center', fontSize: 12, fontWeight: 600 }}>Fan Curve</div>
        <button onClick={onClose} style={{
          appearance: 'none', cursor: 'pointer',
          padding: '4px 12px', borderRadius: 6,
          background: hexToRgba(accent, 0.18),
          color: accent, fontFamily: 'inherit', fontSize: 11, fontWeight: 600,
          border: `0.5px solid ${hexToRgba(accent, 0.35)}`,
        }}>Save</button>
      </div>

      <div style={{ flex: 1, overflow: 'auto' }}>
        <FCSection title="Preview" padding={20}>
          <CurveGraph steps={steps} accent={accent} hover={hover} setHover={setHover} tempUnit={tempUnit} />
        </FCSection>

        <FCDivider />

        <FCSection padding={20} title="Steps" action={
          <button onClick={addStep} disabled={steps.length >= 6} style={{
            appearance: 'none', border: 'none',
            cursor: steps.length >= 6 ? 'default' : 'pointer',
            padding: '3px 8px', borderRadius: 5,
            background: 'rgba(255,255,255,0.06)',
            color: steps.length >= 6 ? 'rgba(255,255,255,0.25)' : 'rgba(255,255,255,0.7)',
            fontFamily: 'inherit', fontSize: 10, fontWeight: 500,
          }}>+ Add</button>
        }>
          <div style={{
            display: 'grid', gridTemplateColumns: '1fr 1fr 22px',
            gap: 8, padding: '0 4px 6px', fontSize: 9,
            color: 'rgba(255,255,255,0.35)', textTransform: 'uppercase', letterSpacing: 1,
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
                  borderRadius: 6,
                  background: hover === i ? 'rgba(255,255,255,0.04)' : 'transparent',
                }}>
                <NumStepper value={s.temp} onChange={(v) => updateStep(i, 'temp', v)}
                            min={20} max={105} step={1} suffix={`°${tempUnit}`} />
                <NumStepper value={s.duty} onChange={(v) => updateStep(i, 'duty', v)}
                            min={0} max={100} step={5} suffix="%" />
                <button onClick={() => removeStep(i)} disabled={steps.length <= 2} style={{
                  appearance: 'none', border: 'none',
                  cursor: steps.length <= 2 ? 'default' : 'pointer',
                  background: 'transparent',
                  color: steps.length <= 2 ? 'rgba(255,255,255,0.15)' : 'rgba(255,255,255,0.4)',
                  width: 22, height: 22, display: 'flex', alignItems: 'center', justifyContent: 'center',
                }}>
                  <svg width="10" height="10" viewBox="0 0 12 12"><path d="M3 3 L9 9 M9 3 L3 9" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" /></svg>
                </button>
              </div>
            ))}
          </div>
        </FCSection>
      </div>
    </div>
  );
}

Object.assign(window, { CurveMVP });

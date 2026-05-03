// site.jsx — Breeze landing page
// Inspired by mac-stats.com: minimal, dark, big hero, single-page.
// i18n PT/EN auto-detected from browser.

// Purchase link (Stripe, Lemon Squeezy, Gumroad — whatever the active gateway is).
const PURCHASE_URL = 'https://buy.stripe.com/your-link-here';
// Latest GitHub Release page (user picks DMG asset to download).
const DOWNLOAD_URL = 'https://github.com/JeversonMisaelDaCruz/Macfancontrol/releases/latest';
const VERSION = 'v1.0.0';

const I18N = {
  en: {
    nav_features: 'Features',
    nav_pricing: 'Pricing',
    nav_download: 'Download',
    hero_eyebrow: 'macOS fan control',
    hero_title: 'Take control of your Mac\u2019s fans.',
    hero_sub: 'A tiny menu‑bar app that monitors temperature and sets fan speed your way. Free to use forever — unlock custom curves once for $3.',
    hero_cta_primary: 'Download for Mac',
    hero_cta_secondary: 'Unlock Pro — $3',
    hero_req: 'Requires macOS 12 or later · Apple Silicon & Intel',
    stat_1_n: '0',
    stat_1_l: 'Background CPU',
    stat_2_n: '<1MB',
    stat_2_l: 'Memory footprint',
    stat_3_n: '$3',
    stat_3_l: 'Pro · pay once',

    feat_title: 'Everything you need. Nothing you don\u2019t.',
    feat_sub: 'Designed for Mac. Built to stay out of the way.',

    f1_t: 'Live temperature',
    f1_d: 'Real‑time CPU and fan readings, right in your menu bar.',
    f2_t: 'Four built‑in modes',
    f2_d: 'Silent, Balanced, Performance, Max — switch with one click.',
    f3_t: 'Custom fan curves',
    f3_d: 'Define exactly how your fans ramp up. Step by step. Pro feature.',
    f4_t: 'Native and lightweight',
    f4_d: 'Built with Swift. Zero background CPU when idle.',
    f5_t: 'Privacy first',
    f5_d: 'No accounts, no tracking, no cloud. Everything stays on your Mac.',
    f6_t: 'Apple Silicon ready',
    f6_d: 'Optimized for M‑series Macs. Works on Intel too.',

    pricing_title: 'One price. One time. Forever.',
    pricing_sub: 'Try the free version, unlock Pro when you\u2019re ready.',
    free_badge: 'Free',
    free_t: 'Free forever',
    free_p: '$0',
    free_p_sub: 'no signup',
    free_1: 'Live temperature & RPM',
    free_2: 'Silent, Balanced, Performance, Max',
    free_3: 'Menu bar widget',
    free_4: 'All future free updates',
    free_cta: 'Download free',

    pro_badge: 'Pro',
    pro_t: 'Custom curves',
    pro_p: '$3',
    pro_p_sub: 'one‑time payment',
    pro_1: 'Everything in Free',
    pro_2: 'Build your own fan curve',
    pro_3: 'Unlimited curve steps',
    pro_4: 'Lifetime access — no subscription',
    pro_cta: 'Unlock Pro',

    foot_made: 'Made with care for macOS',
    foot_priv: 'Privacy',
    foot_terms: 'Terms',
    foot_support: 'Support',
  },
  pt: {
    nav_features: 'Funcionalidades',
    nav_pricing: 'Preço',
    nav_download: 'Baixar',
    hero_eyebrow: 'Controle de Fans para macOS',
    hero_title: 'Controle os Fans do seu Mac.',
    hero_sub: 'Um app discreto na barra de menu que monitora a temperatura e ajusta a velocidade das fans do seu jeito. Grátis pra sempre — desbloqueie curvas personalizadas por $3, pagamento único.',
    hero_cta_primary: 'Baixar para Mac',
    hero_cta_secondary: 'Desbloquear Pro — $3',
    hero_req: 'Requer macOS 12 ou superior · Apple Silicon & Intel',
    stat_1_n: '0',
    stat_1_l: 'CPU em segundo plano',
    stat_2_n: '<1MB',
    stat_2_l: 'Uso de memória',
    stat_3_n: '$3',
    stat_3_l: 'Pro · pague uma vez',

    feat_title: 'Tudo que você precisa. Nada além.',
    feat_sub: 'Feito para o Mac. Pensado pra não atrapalhar.',

    f1_t: 'Temperatura ao vivo',
    f1_d: 'Leituras de CPU e Fans em tempo real, na sua barra de menu.',
    f2_t: 'Quatro modos prontos',
    f2_d: 'Silent, Balanced, Performance e Max — alterne com um clique.',
    f3_t: 'Curvas personalizadas',
    f3_d: 'Defina exatamente como suas fans aceleram. Passo a passo. Recurso Pro.',
    f4_t: 'Nativo e leve',
    f4_d: 'Feito em Swift. Zero CPU em segundo plano quando ocioso.',
    f5_t: 'Privacidade primeiro',
    f5_d: 'Sem contas, sem rastreamento, sem nuvem. Tudo fica no seu Mac.',
    f6_t: 'Pronto para Apple Silicon',
    f6_d: 'Otimizado para Macs com chip M. Funciona em Intel também.',

    pricing_title: 'Um preço. Uma vez. Pra sempre.',
    pricing_sub: 'Experimente a versão grátis, desbloqueie o Pro quando quiser.',
    free_badge: 'Free',
    free_t: 'Grátis pra sempre',
    free_p: '$0',
    free_p_sub: 'sem cadastro',
    free_1: 'Temperatura e RPM ao vivo',
    free_2: 'Silent, Balanced, Performance, Max',
    free_3: 'Widget na barra de menu',
    free_4: 'Atualizações grátis pra sempre',
    free_cta: 'Baixar grátis',

    pro_badge: 'Pro',
    pro_t: 'Curvas personalizadas',
    pro_p: '$3',
    pro_p_sub: 'pagamento único',
    pro_1: 'Tudo do Free',
    pro_2: 'Crie sua própria curva',
    pro_3: 'Quantos passos quiser',
    pro_4: 'Acesso vitalício — sem assinatura',
    pro_cta: 'Desbloquear Pro',

    foot_made: 'Feito com carinho para macOS',
    foot_priv: 'Privacidade',
    foot_terms: 'Termos',
    foot_support: 'Suporte',
  },
};

function detectLang() {
  if (typeof navigator === 'undefined') return 'en';
  const stored = localStorage.getItem('breeze_lang');
  if (stored && I18N[stored]) return stored;
  const nav = (navigator.language || 'en').toLowerCase();
  return nav.startsWith('pt') ? 'pt' : 'en';
}

function Site() {
  const [lang, setLang] = React.useState(detectLang);
  const t = I18N[lang];

  const switchLang = (l) => {
    setLang(l);
    try { localStorage.setItem('breeze_lang', l); } catch (e) {}
  };

  return (
    <div style={{ background: '#08090c', color: '#e8e8ea', minHeight: '100vh' }}>
      <Nav t={t} lang={lang} switchLang={switchLang} />
      <Hero t={t} />
      <Features t={t} />
      <Pricing t={t} />
      <Footer t={t} lang={lang} switchLang={switchLang} />
    </div>
  );
}

// ─── nav ───────────────────────────────────────────
function Nav({ t, lang, switchLang }) {
  return (
    <nav style={{
      position: 'sticky', top: 0, zIndex: 50,
      backdropFilter: 'blur(20px) saturate(160%)',
      WebkitBackdropFilter: 'blur(20px) saturate(160%)',
      background: 'rgba(8,9,12,0.7)',
      borderBottom: '0.5px solid rgba(255,255,255,0.06)',
    }}>
      <div style={{ maxWidth: 1120, margin: '0 auto', padding: '14px 28px', display: 'flex', alignItems: 'center', gap: 28 }}>
        <a href="#" style={{ display: 'flex', alignItems: 'center', gap: 10, textDecoration: 'none', color: '#fff' }}>
          <BreezeLogo size={28} />
          <span style={{ fontSize: 16, fontWeight: 600, letterSpacing: -0.2 }}>BreezeFan</span>
        </a>
        <div style={{ flex: 1 }} />
        <a href="#features" style={navLink}>{t.nav_features}</a>
        <a href="#pricing" style={navLink}>{t.nav_pricing}</a>
        <a href="#download" style={{
          ...navLink, padding: '7px 14px', borderRadius: 8,
          background: 'rgba(255,255,255,0.08)',
          boxShadow: 'inset 0 0 0 0.5px rgba(255,255,255,0.12)',
          color: '#fff',
        }}>{t.nav_download}</a>
        <LangSwitcher lang={lang} switchLang={switchLang} />
      </div>
    </nav>
  );
}
const navLink = {
  textDecoration: 'none', color: 'rgba(255,255,255,0.65)',
  fontSize: 13, fontWeight: 500,
  transition: 'color .15s',
};

function LangSwitcher({ lang, switchLang }) {
  return (
    <div style={{
      display: 'flex', gap: 2,
      padding: 2,
      background: 'rgba(255,255,255,0.04)',
      borderRadius: 7,
      boxShadow: 'inset 0 0 0 0.5px rgba(255,255,255,0.06)',
    }}>
      {['en', 'pt'].map(l => (
        <button key={l} onClick={() => switchLang(l)} style={{
          appearance: 'none', border: 'none', cursor: 'pointer',
          padding: '4px 8px', borderRadius: 5,
          background: lang === l ? 'rgba(255,255,255,0.12)' : 'transparent',
          color: lang === l ? '#fff' : 'rgba(255,255,255,0.5)',
          fontSize: 11, fontWeight: 600, letterSpacing: 0.4,
          textTransform: 'uppercase', fontFamily: 'inherit',
        }}>{l}</button>
      ))}
    </div>
  );
}

function BreezeLogo({ size = 28 }) {
  return (
    <div style={{
      width: size, height: size, borderRadius: size * 0.28,
      background: 'linear-gradient(135deg, #3b82f6 0%, #06b6d4 60%, #6366f1 100%)',
      boxShadow: 'inset 0 0.5px 0 rgba(255,255,255,0.4), 0 4px 14px rgba(59,130,246,0.4)',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      position: 'relative', overflow: 'hidden',
    }}>
      <div style={{ position: 'absolute', top: 0, left: 0, right: 0, height: '50%', background: 'linear-gradient(180deg, rgba(255,255,255,0.25) 0%, rgba(255,255,255,0) 100%)' }} />
      <svg width={size * 0.6} height={size * 0.6} viewBox="0 0 24 24" fill="none" style={{ position: 'relative' }}>
        <path d="M3 9 H 13 Q 17 9, 17 6 T 13 3" stroke="white" strokeWidth="2" strokeLinecap="round" fill="none" />
        <path d="M3 14 H 17 Q 21 14, 21 11 T 17 8" stroke="white" strokeWidth="2" strokeLinecap="round" fill="none" opacity="0.8" />
        <path d="M3 19 H 11 Q 15 19, 15 16" stroke="white" strokeWidth="2" strokeLinecap="round" fill="none" opacity="0.6" />
      </svg>
    </div>
  );
}

// ─── hero ───────────────────────────────────────────
function Hero({ t }) {
  return (
    <section id="download" style={{ position: 'relative', overflow: 'hidden' }}>
      {/* ambient glow */}
      <div style={{
        position: 'absolute', top: -200, left: '50%', transform: 'translateX(-50%)',
        width: 1000, height: 600, pointerEvents: 'none',
        background: 'radial-gradient(closest-side, rgba(59,130,246,0.25) 0%, rgba(99,102,241,0.12) 40%, transparent 75%)',
        filter: 'blur(20px)',
      }} />
      <div style={{ position: 'relative', maxWidth: 1120, margin: '0 auto', padding: '80px 28px 40px', textAlign: 'center' }}>
        <div style={{
          display: 'inline-block',
          fontSize: 11, fontWeight: 600, letterSpacing: 1.6, textTransform: 'uppercase',
          color: 'rgba(255,255,255,0.55)', marginBottom: 20,
          padding: '5px 12px', borderRadius: 99,
          background: 'rgba(255,255,255,0.04)',
          boxShadow: 'inset 0 0 0 0.5px rgba(255,255,255,0.08)',
        }}>{t.hero_eyebrow}</div>
        <h1 style={{
          fontSize: 'clamp(40px, 7vw, 80px)', fontWeight: 600,
          letterSpacing: -2.5, lineHeight: 1.02, margin: '0 0 20px',
          background: 'linear-gradient(180deg, #fff 0%, rgba(255,255,255,0.65) 100%)',
          WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent', backgroundClip: 'text',
        }}>{t.hero_title}</h1>
        <p style={{
          fontSize: 'clamp(15px, 1.6vw, 18px)', lineHeight: 1.55,
          color: 'rgba(255,255,255,0.65)', maxWidth: 620, margin: '0 auto 36px',
          textWrap: 'pretty',
        }}>{t.hero_sub}</p>

        <div style={{ display: 'flex', gap: 12, justifyContent: 'center', flexWrap: 'wrap', marginBottom: 16 }}>
          <a href={DOWNLOAD_URL} style={primaryBtn}>
            <svg width="14" height="17" viewBox="0 0 14 17" fill="currentColor"><path d="M11.6 9c0-2 1.6-2.9 1.7-3-1-1.4-2.4-1.6-3-1.6-1.2-.1-2.5.7-3.1.7-.6 0-1.6-.7-2.7-.7-1.4 0-2.6.8-3.4 2C-.5 8.8.6 12.7 2 14.8c.7 1 1.5 2.2 2.6 2.2 1 0 1.5-.7 2.8-.7 1.3 0 1.7.7 2.8.7 1.2 0 1.9-1 2.7-2 .8-1.1 1.1-2.2 1.2-2.3-.1 0-2.4-1-2.5-3.7zM9.7 3c.5-.7.9-1.6.8-2.6-.8 0-1.7.5-2.3 1.2-.5.6-.9 1.6-.8 2.5.9.1 1.8-.5 2.3-1.1z"/></svg>
            {t.hero_cta_primary}
          </a>
          <a href={PURCHASE_URL} style={secondaryBtn}>
            {t.hero_cta_secondary}
          </a>
        </div>
        <div style={{ fontSize: 12, color: 'rgba(255,255,255,0.4)' }}>{t.hero_req}</div>

        {/* embedded live app */}
        <div style={{ marginTop: 64, display: 'flex', justifyContent: 'center' }}>
          <DesktopFrame />
        </div>

        {/* stats row */}
        <div style={{
          marginTop: 64, display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)',
          gap: 24, maxWidth: 720, margin: '64px auto 0',
        }}>
          {[
            { n: t.stat_1_n, l: t.stat_1_l },
            { n: t.stat_2_n, l: t.stat_2_l },
            { n: t.stat_3_n, l: t.stat_3_l },
          ].map((s, i) => (
            <div key={i} style={{ textAlign: 'center' }}>
              <div style={{ fontSize: 36, fontWeight: 600, letterSpacing: -1, color: '#fff' }}>{s.n}</div>
              <div style={{ fontSize: 12, color: 'rgba(255,255,255,0.5)', marginTop: 4 }}>{s.l}</div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

const primaryBtn = {
  display: 'inline-flex', alignItems: 'center', gap: 9,
  padding: '14px 22px', borderRadius: 11,
  background: 'linear-gradient(180deg, #fff 0%, #d4d4d8 100%)',
  color: '#0a0a0a', fontSize: 14, fontWeight: 600,
  textDecoration: 'none', letterSpacing: -0.1,
  boxShadow: 'inset 0 0.5px 0 rgba(255,255,255,0.6), 0 8px 24px rgba(255,255,255,0.12)',
  transition: 'transform .15s',
};
const secondaryBtn = {
  display: 'inline-flex', alignItems: 'center', gap: 9,
  padding: '14px 22px', borderRadius: 11,
  background: 'rgba(255,255,255,0.06)',
  boxShadow: 'inset 0 0 0 0.5px rgba(255,255,255,0.14), inset 0 1px 0 rgba(255,255,255,0.18)',
  backdropFilter: 'blur(10px)',
  WebkitBackdropFilter: 'blur(10px)',
  color: '#fff', fontSize: 14, fontWeight: 600,
  textDecoration: 'none', letterSpacing: -0.1,
};

// ─── desktop frame embedding the live app ───────────
function DesktopFrame() {
  return (
    <div data-bf-frame style={{
      width: '100%', maxWidth: 980,
      aspectRatio: '16/10',
      borderRadius: 20,
      overflow: 'hidden',
      position: 'relative',
      boxShadow: '0 40px 80px rgba(0,0,0,0.6), 0 0 0 0.5px rgba(255,255,255,0.08)',
      // simulated desktop wallpaper
      background: `
        radial-gradient(60% 50% at 80% 15%, rgba(59,130,246,0.6) 0%, transparent 60%),
        radial-gradient(50% 40% at 15% 80%, rgba(217,70,239,0.5) 0%, transparent 60%),
        radial-gradient(45% 35% at 85% 90%, rgba(6,182,212,0.5) 0%, transparent 60%),
        radial-gradient(70% 50% at 30% 20%, rgba(99,102,241,0.55) 0%, transparent 65%),
        linear-gradient(160deg, #1e1b4b 0%, #0c0a1f 100%)
      `,
    }}>
      {/* macOS menu bar */}
      <div style={{
        position: 'absolute', top: 0, left: 0, right: 0, height: 26,
        background: 'rgba(0,0,0,0.35)',
        backdropFilter: 'blur(20px) saturate(180%)',
        WebkitBackdropFilter: 'blur(20px) saturate(180%)',
        display: 'flex', alignItems: 'center', padding: '0 14px', gap: 16,
        fontSize: 11, color: 'rgba(255,255,255,0.85)',
        zIndex: 2,
      }}>
        <svg width="13" height="13" viewBox="0 0 14 17" fill="currentColor"><path d="M11.6 9c0-2 1.6-2.9 1.7-3-1-1.4-2.4-1.6-3-1.6-1.2-.1-2.5.7-3.1.7-.6 0-1.6-.7-2.7-.7-1.4 0-2.6.8-3.4 2C-.5 8.8.6 12.7 2 14.8c.7 1 1.5 2.2 2.6 2.2 1 0 1.5-.7 2.8-.7 1.3 0 1.7.7 2.8.7 1.2 0 1.9-1 2.7-2 .8-1.1 1.1-2.2 1.2-2.3-.1 0-2.4-1-2.5-3.7zM9.7 3c.5-.7.9-1.6.8-2.6-.8 0-1.7.5-2.3 1.2-.5.6-.9 1.6-.8 2.5.9.1 1.8-.5 2.3-1.1z"/></svg>
        <span style={{ fontWeight: 600 }}>BreezeFan</span>
        <span style={{ marginLeft: 4, opacity: 0.7 }}>File</span>
        <span style={{ opacity: 0.7 }}>Edit</span>
        <span style={{ opacity: 0.7 }}>View</span>
        <span style={{ opacity: 0.7 }}>Window</span>
        <span style={{ opacity: 0.7 }}>Help</span>
        <span style={{ flex: 1 }} />
        <span style={{ fontFamily: 'ui-monospace', fontSize: 10, opacity: 0.85, padding: '2px 8px', borderRadius: 4, background: 'rgba(255,255,255,0.08)' }}>67° · 4.3k RPM</span>
        <span style={{ opacity: 0.85 }}>Tue 14:23</span>
      </div>

      {/* The actual app, auto-scaled to fit comfortably in the desktop area */}
      <div style={{
        position: 'absolute', top: 26, left: 0, right: 0, bottom: 0,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
      }}>
        <div style={{
          transform: 'scale(var(--app-scale, 0.92))',
          transformOrigin: 'center',
        }}>
          <FCWindow accent="#3b82f6" title="BreezeFan" width={360} height={560}>
            <MainMVP accent="#3b82f6" tempUnit="C" onOpenCurve={() => {}} />
          </FCWindow>
        </div>
      </div>

      {/* responsive scale via media-query-ish CSS variable in style tag */}
      <style>{`
        @media (max-width: 760px) {
          [data-bf-frame] { --app-scale: 0.62; }
        }
        @media (max-width: 520px) {
          [data-bf-frame] { --app-scale: 0.5; }
        }
      `}</style>
    </div>
  );
}

// ─── features ───────────────────────────────────────
function Features({ t }) {
  const features = [
    { icon: 'temp',     title: t.f1_t, desc: t.f1_d },
    { icon: 'modes',    title: t.f2_t, desc: t.f2_d },
    { icon: 'curve',    title: t.f3_t, desc: t.f3_d, pro: true },
    { icon: 'native',   title: t.f4_t, desc: t.f4_d },
    { icon: 'privacy',  title: t.f5_t, desc: t.f5_d },
    { icon: 'silicon',  title: t.f6_t, desc: t.f6_d },
  ];
  return (
    <section id="features" style={{ padding: '100px 28px', borderTop: '0.5px solid rgba(255,255,255,0.05)' }}>
      <div style={{ maxWidth: 1120, margin: '0 auto' }}>
        <div style={{ textAlign: 'center', marginBottom: 56 }}>
          <h2 style={sectionTitle}>{t.feat_title}</h2>
          <p style={sectionSub}>{t.feat_sub}</p>
        </div>
        <div style={{
          display: 'grid', gap: 1,
          gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))',
          background: 'rgba(255,255,255,0.06)',
          borderRadius: 16, overflow: 'hidden',
          boxShadow: 'inset 0 0 0 0.5px rgba(255,255,255,0.06)',
        }}>
          {features.map((f, i) => <FeatureCell key={i} {...f} t={t} />)}
        </div>
      </div>
    </section>
  );
}

function FeatureCell({ icon, title, desc, pro, t }) {
  return (
    <div style={{
      padding: '32px 28px',
      background: '#0a0b0e',
      display: 'flex', flexDirection: 'column', gap: 12,
    }}>
      <div style={{
        width: 36, height: 36, borderRadius: 9,
        background: 'rgba(59,130,246,0.12)',
        boxShadow: 'inset 0 0 0 0.5px rgba(59,130,246,0.3), inset 0 1px 0 rgba(255,255,255,0.08)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        color: '#60a5fa',
      }}>
        <FeatureIcon kind={icon} />
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
        <h3 style={{ fontSize: 16, fontWeight: 600, color: '#fff', margin: 0, letterSpacing: -0.2 }}>{title}</h3>
        {pro && (
          <span style={{
            fontSize: 9, fontWeight: 700, letterSpacing: 1, textTransform: 'uppercase',
            padding: '2px 6px', borderRadius: 4,
            background: 'rgba(59,130,246,0.15)',
            color: '#60a5fa',
            boxShadow: 'inset 0 0 0 0.5px rgba(59,130,246,0.4)',
          }}>{t.pro_badge}</span>
        )}
      </div>
      <p style={{ fontSize: 13, lineHeight: 1.55, color: 'rgba(255,255,255,0.55)', margin: 0, textWrap: 'pretty' }}>{desc}</p>
    </div>
  );
}

function FeatureIcon({ kind }) {
  const props = { width: 18, height: 18, viewBox: '0 0 24 24', fill: 'none', stroke: 'currentColor', strokeWidth: 1.8, strokeLinecap: 'round', strokeLinejoin: 'round' };
  switch (kind) {
    case 'temp':    return <svg {...props}><path d="M12 3v11"/><circle cx="12" cy="17" r="4"/><path d="M12 9h3"/><path d="M12 6h3"/></svg>;
    case 'modes':   return <svg {...props}><rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/></svg>;
    case 'curve':   return <svg {...props}><path d="M3 18 C 7 18, 9 6, 13 6 S 17 18, 21 18"/></svg>;
    case 'native':  return <svg {...props}><circle cx="12" cy="12" r="3"/><path d="M12 2v4M12 18v4M22 12h-4M6 12H2M19 5l-3 3M8 16l-3 3M19 19l-3-3M8 8L5 5"/></svg>;
    case 'privacy': return <svg {...props}><path d="M12 3l8 3v6c0 5-4 8-8 9-4-1-8-4-8-9V6l8-3z"/></svg>;
    case 'silicon': return <svg {...props}><rect x="6" y="6" width="12" height="12" rx="1.5"/><path d="M3 9v6M3 12h3M21 9v6M18 12h3M9 3v3M12 3h0v3M15 3v3M9 18v3M12 21v0M15 18v3"/></svg>;
    default: return null;
  }
}

// ─── pricing ───────────────────────────────────────
function Pricing({ t }) {
  return (
    <section id="pricing" style={{ padding: '100px 28px', borderTop: '0.5px solid rgba(255,255,255,0.05)', position: 'relative', overflow: 'hidden' }}>
      <div style={{
        position: 'absolute', top: '50%', left: '50%', transform: 'translate(-50%, -50%)',
        width: 800, height: 400, pointerEvents: 'none',
        background: 'radial-gradient(closest-side, rgba(59,130,246,0.18) 0%, transparent 70%)',
        filter: 'blur(40px)',
      }} />
      <div style={{ position: 'relative', maxWidth: 880, margin: '0 auto' }}>
        <div style={{ textAlign: 'center', marginBottom: 56 }}>
          <h2 style={sectionTitle}>{t.pricing_title}</h2>
          <p style={sectionSub}>{t.pricing_sub}</p>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))', gap: 16 }}>
          <PricingCard
            badge={t.free_badge} title={t.free_t}
            price={t.free_p} priceSub={t.free_p_sub}
            items={[t.free_1, t.free_2, t.free_3, t.free_4]}
            ctaLabel={t.free_cta} ctaHref={DOWNLOAD_URL} />
          <PricingCard featured
            badge={t.pro_badge} title={t.pro_t}
            price={t.pro_p} priceSub={t.pro_p_sub}
            items={[t.pro_1, t.pro_2, t.pro_3, t.pro_4]}
            ctaLabel={t.pro_cta} ctaHref={PURCHASE_URL} />
        </div>
      </div>
    </section>
  );
}

function PricingCard({ featured, badge, title, price, priceSub, items, ctaLabel, ctaHref }) {
  return (
    <div style={{
      position: 'relative',
      padding: 32,
      borderRadius: 18,
      background: featured
        ? 'linear-gradient(180deg, rgba(59,130,246,0.10) 0%, rgba(10,11,14,1) 60%)'
        : '#0a0b0e',
      boxShadow: featured
        ? 'inset 0 0 0 0.5px rgba(59,130,246,0.4), 0 12px 40px rgba(59,130,246,0.18)'
        : 'inset 0 0 0 0.5px rgba(255,255,255,0.06)',
    }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 20 }}>
        <span style={{
          fontSize: 11, fontWeight: 600, letterSpacing: 1.4, textTransform: 'uppercase',
          color: featured ? '#60a5fa' : 'rgba(255,255,255,0.5)',
          padding: '4px 10px', borderRadius: 5,
          background: featured ? 'rgba(59,130,246,0.15)' : 'rgba(255,255,255,0.05)',
          boxShadow: featured ? 'inset 0 0 0 0.5px rgba(59,130,246,0.3)' : 'inset 0 0 0 0.5px rgba(255,255,255,0.08)',
        }}>{badge}</span>
      </div>
      <h3 style={{ fontSize: 20, fontWeight: 600, color: '#fff', margin: '0 0 14px', letterSpacing: -0.4 }}>{title}</h3>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 6, marginBottom: 24 }}>
        <span style={{ fontSize: 48, fontWeight: 600, color: '#fff', letterSpacing: -2, lineHeight: 1 }}>{price}</span>
        <span style={{ fontSize: 13, color: 'rgba(255,255,255,0.5)' }}>{priceSub}</span>
      </div>
      <ul style={{ listStyle: 'none', padding: 0, margin: '0 0 28px', display: 'flex', flexDirection: 'column', gap: 11 }}>
        {items.map((it, i) => (
          <li key={i} style={{ display: 'flex', alignItems: 'flex-start', gap: 10, fontSize: 13.5, color: 'rgba(255,255,255,0.75)' }}>
            <svg width="14" height="14" viewBox="0 0 14 14" style={{ flexShrink: 0, marginTop: 3, color: featured ? '#60a5fa' : 'rgba(255,255,255,0.5)' }}>
              <path d="M2.5 7 L 5.5 10 L 11.5 4" stroke="currentColor" strokeWidth="1.8" fill="none" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
            <span>{it}</span>
          </li>
        ))}
      </ul>
      <a href={ctaHref} style={{
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        padding: '12px 22px', borderRadius: 10,
        background: featured
          ? 'linear-gradient(180deg, #fff 0%, #d4d4d8 100%)'
          : 'rgba(255,255,255,0.06)',
        color: featured ? '#0a0a0a' : '#fff',
        boxShadow: featured
          ? 'inset 0 0.5px 0 rgba(255,255,255,0.6), 0 8px 24px rgba(255,255,255,0.1)'
          : 'inset 0 0 0 0.5px rgba(255,255,255,0.14), inset 0 1px 0 rgba(255,255,255,0.18)',
        textDecoration: 'none', fontSize: 13.5, fontWeight: 600, letterSpacing: -0.1,
      }}>{ctaLabel}</a>
    </div>
  );
}

const sectionTitle = {
  fontSize: 'clamp(28px, 4vw, 42px)', fontWeight: 600,
  letterSpacing: -1.5, lineHeight: 1.1, margin: '0 0 14px',
  background: 'linear-gradient(180deg, #fff 0%, rgba(255,255,255,0.7) 100%)',
  WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent', backgroundClip: 'text',
};
const sectionSub = {
  fontSize: 'clamp(14px, 1.6vw, 17px)', color: 'rgba(255,255,255,0.55)',
  margin: 0, textWrap: 'pretty',
};

// ─── footer ───────────────────────────────────────
function Footer({ t, lang, switchLang }) {
  return (
    <footer style={{ padding: '40px 28px 60px', borderTop: '0.5px solid rgba(255,255,255,0.05)' }}>
      <div style={{ maxWidth: 1120, margin: '0 auto', display: 'flex', alignItems: 'center', gap: 20, flexWrap: 'wrap' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <BreezeLogo size={22} />
          <span style={{ fontSize: 13, color: 'rgba(255,255,255,0.5)' }}>© 2026 BreezeFan · {t.foot_made}</span>
        </div>
        <div style={{ flex: 1 }} />
        <a href="#" style={footLink}>{t.foot_priv}</a>
        <a href="#" style={footLink}>{t.foot_terms}</a>
        <a href="#" style={footLink}>{t.foot_support}</a>
        <span style={{ fontSize: 12, color: 'rgba(255,255,255,0.3)' }}>{VERSION}</span>
      </div>
    </footer>
  );
}
const footLink = { fontSize: 13, color: 'rgba(255,255,255,0.5)', textDecoration: 'none' };

ReactDOM.createRoot(document.getElementById('root')).render(<Site />);

// cards.jsx — OneMET UI shell components
// Exports: Icon, Card, CardHead, Header, TabBar, StatBlock, Chip

function Icon({ name, color = 'currentColor', size = 17, stroke = 1.9 }) {
  const common = { width: size, height: size, viewBox: '0 0 24 24', fill: 'none',
    stroke: color, strokeWidth: stroke, strokeLinecap: 'round', strokeLinejoin: 'round' };
  const fillCommon = { width: size, height: size, viewBox: '0 0 24 24', fill: color };
  switch (name) {
    case 'drop': return <svg {...fillCommon}><path d="M12 2.5C12 2.5 5 10 5 15a7 7 0 0014 0c0-5-7-12.5-7-12.5z"/></svg>;
    case 'heart': return <svg {...fillCommon}><path d="M12 20.5l-1.4-1.27C5.4 14.5 2.5 11.9 2.5 8.6 2.5 6 4.5 4 7 4c1.7 0 3.3.9 4.1 2.3h1.8C13.7 4.9 15.3 4 17 4c2.5 0 4.5 2 4.5 4.6 0 3.3-2.9 5.9-8.1 10.63L12 20.5z"/></svg>;
    case 'flame': return <svg {...fillCommon}><path d="M12 2c.5 4-2.5 5-2.5 8 0 1 .5 2 1.5 2.4C10.3 11 11 9.5 11 9.5s.5 3.5 2.5 4.5c.3-.7.2-1.6.2-1.6s2.3 1.7 2.3 4.1A6 6 0 016 16.5C6 11 11 9 12 2z"/></svg>;
    case 'run': return <svg {...common}><circle cx="14.5" cy="4.5" r="1.8" fill={color} stroke="none"/><path d="M8 21l2.5-5 3-2-1.5-4-3 2-2 2.5M13.5 10l3 1.5 1 4M11 10l3.5-1.5"/></svg>;
    case 'shoe': return <svg {...common}><path d="M4 16v-5l3-1 2 3 3 .5 5 1.5c1 .3 2 1 2 2.5v.5H4v-2z"/></svg>;
    case 'fork': return <svg {...common}><path d="M7 3v7M5 3v4a2 2 0 002 2M9 3v4a2 2 0 01-2 2M7 11v10M17 3c-1.5 0-2.5 2-2.5 5s1 4 2.5 4 2.5-1 2.5-4-1-5-2.5-5zM17 12v9"/></svg>;
    case 'bolt': return <svg {...fillCommon}><path d="M13 2L4 14h6l-1 8 9-12h-6l1-8z"/></svg>;
    case 'activity': return <svg {...common}><path d="M3 12h4l2.5-7 4 16 2.5-9h5"/></svg>;
    case 'chevron': return <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round"><path d="M9 5l7 7-7 7"/></svg>;
    case 'person': return <svg {...common}><circle cx="12" cy="8" r="3.5"/><path d="M5 20c0-3.5 3-6 7-6s7 2.5 7 6"/></svg>;
    case 'house': return <svg {...common}><path d="M4 11l8-7 8 7M6 9.5V20h12V9.5"/></svg>;
    case 'chart': return <svg {...common}><path d="M4 20V4M4 20h16M8 16v-4M12 16V8M16 16v-7"/></svg>;
    case 'calendar': return <svg {...common}><rect x="4" y="5" width="16" height="15" rx="2.5"/><path d="M4 9.5h16M8 3v4M16 3v4"/></svg>;
    default: return null;
  }
}

function Card({ title, icon, iconColor, right, onClick, children, style = {}, pad = 16 }) {
  const T = window.TOKENS;
  return (
    <div onClick={onClick} style={{
      background: T.card, borderRadius: `var(--radius, 20px)`,
      padding: pad, boxShadow: '0 1px 2px rgba(0,0,0,0.04), 0 6px 16px rgba(0,0,0,0.035)',
      cursor: onClick ? 'pointer' : 'default', ...style,
    }}>
      {title && <CardHead title={title} icon={icon} iconColor={iconColor} right={right} clickable={!!onClick} />}
      {children}
    </div>
  );
}

function CardHead({ title, icon, iconColor, right, clickable }) {
  const T = window.TOKENS;
  return (
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 12 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
        {icon && <Icon name={icon} color={iconColor} size={15} />}
        <span style={{ fontSize: 15, fontWeight: 600, color: iconColor || T.ink, letterSpacing: -0.2 }}>{title}</span>
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
        {right && <span style={{ fontSize: 13, color: T.ink2, fontVariantNumeric: 'tabular-nums' }}>{right}</span>}
        {clickable && <Icon name="chevron" color={T.ink3} size={15} />}
      </div>
    </div>
  );
}

function Header({ title, date, accent }) {
  const T = window.TOKENS;
  return (
    <div style={{ padding: '4px 16px 8px', display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between' }}>
      <div>
        <div style={{ fontSize: 13, fontWeight: 600, color: T.ink2, letterSpacing: 0.2, textTransform: 'uppercase' }}>{date}</div>
        <div style={{ fontSize: 32, fontWeight: 700, color: T.ink, letterSpacing: 0.36, lineHeight: 1.1, marginTop: 2 }}>{title}</div>
      </div>
      <div style={{ width: 36, height: 36, borderRadius: 18, background: accent,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        color: '#fff', fontSize: 15, fontWeight: 600, boxShadow: '0 2px 6px rgba(0,0,0,0.12)' }}>AM</div>
    </div>
  );
}

function StatBlock({ label, value, unit, color }) {
  const T = window.TOKENS;
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
      <span style={{ fontSize: 12, fontWeight: 600, color: T.ink2, letterSpacing: 0.2, textTransform: 'uppercase' }}>{label}</span>
      <span style={{ display: 'flex', alignItems: 'baseline', gap: 3 }}>
        <span style={{ fontSize: 22, fontWeight: 700, color: color || T.ink, fontVariantNumeric: 'tabular-nums', letterSpacing: -0.3 }}>{value}</span>
        {unit && <span style={{ fontSize: 12, fontWeight: 600, color: T.ink2 }}>{unit}</span>}
      </span>
    </div>
  );
}

function Chip({ children, color }) {
  const T = window.TOKENS;
  return (
    <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4,
      padding: '3px 9px', borderRadius: 100, background: (color || T.green) + '1f',
      fontSize: 12.5, fontWeight: 600, color: color || T.green, letterSpacing: -0.1 }}>{children}</span>
  );
}

function TabBar({ active, onChange, accent }) {
  const T = window.TOKENS;
  const tabs = [
    { id: 'summary', label: 'Summary', icon: 'house' },
    { id: 'plan', label: 'Plan', icon: 'calendar' },
    { id: 'workouts', label: 'Workouts', icon: 'run' },
    { id: 'profile', label: 'Profile', icon: 'person' },
  ];
  return (
    <div style={{ position: 'absolute', bottom: 0, left: 0, right: 0, zIndex: 40,
      paddingBottom: 22, paddingTop: 9,
      background: 'linear-gradient(to top, rgba(248,248,250,0.96) 60%, rgba(248,248,250,0))',
      backdropFilter: 'blur(18px) saturate(180%)', WebkitBackdropFilter: 'blur(18px) saturate(180%)',
      borderTop: `0.5px solid ${T.sep}`,
      display: 'flex', justifyContent: 'space-around', alignItems: 'flex-start' }}>
      {tabs.map(t => {
        const on = active === t.id;
        return (
          <div key={t.id} onClick={() => onChange(t.id)}
            style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3, cursor: 'pointer', flex: 1, paddingTop: 2 }}>
            <Icon name={t.icon} color={on ? accent : T.ink3} size={24} stroke={on ? 2.2 : 1.9} />
            <span style={{ fontSize: 10.5, fontWeight: on ? 700 : 500, color: on ? accent : T.ink2 }}>{t.label}</span>
          </div>
        );
      })}
    </div>
  );
}

function Select({ label, value, options, onChange, accent, render }) {
  const T = window.TOKENS;
  return (
    <label style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      padding: '11px 0', borderBottom: `0.5px solid ${T.sep}`, cursor: 'pointer' }}>
      <span style={{ fontSize: 15, color: T.ink, fontWeight: 500 }}>{label}</span>
      <span style={{ position: 'relative', display: 'flex', alignItems: 'center', gap: 4 }}>
        <span style={{ fontSize: 15, color: accent, fontWeight: 600 }}>
          {render ? render(value) : (options.find(o => o.value === value)?.label ?? String(value))}
        </span>
        <Icon name="chevron" color={T.ink3} size={13} />
        <select value={value} onChange={e => onChange(e.target.value)}
          style={{ position: 'absolute', inset: 0, opacity: 0, cursor: 'pointer', width: '100%', height: '100%' }}>
          {options.map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
        </select>
      </span>
    </label>
  );
}

// ── Sport picker: swipeable card stack ─────────────────────────
function SportCards({ sports, index, onChange, accent, durationLabel, difficultyLabel }) {
  const T = window.TOKENS;
  const [drag, setDrag] = React.useState(0);
  const startX = React.useRef(null);
  const n = sports.length;

  const onDown = (e) => { startX.current = (e.touches ? e.touches[0].clientX : e.clientX); };
  const onMove = (e) => {
    if (startX.current === null) return;
    const x = (e.touches ? e.touches[0].clientX : e.clientX);
    setDrag(x - startX.current);
  };
  const onUp = () => {
    if (Math.abs(drag) > 60) {
      onChange((index + (drag < 0 ? 1 : -1) + n) % n);
    }
    setDrag(0); startX.current = null;
  };

  const cardAt = (offset) => {
    const s = sports[(index + offset + n) % n];
    const sc = s.color || accent;
    const depth = Math.abs(offset);
    const dragShift = offset === 0 ? drag : 0;
    const tx = offset * 10 + dragShift;
    const ty = depth * 8;
    const scale = 1 - depth * 0.05;
    const rot = offset === 0 ? drag / 40 : offset * 2.5;
    return (
      <div key={offset + '-' + s.id} onPointerDown={offset === 0 ? onDown : undefined}
        onPointerMove={offset === 0 ? onMove : undefined}
        onPointerUp={offset === 0 ? onUp : undefined}
        onPointerLeave={offset === 0 ? onUp : undefined}
        style={{
          position: 'absolute', inset: 0, margin: 'auto', width: '100%', height: '100%',
          transform: `translate(${tx}px, ${ty}px) scale(${scale}) rotate(${rot}deg)`,
          transition: dragShift ? 'none' : 'transform 0.32s cubic-bezier(.2,.8,.2,1)',
          zIndex: 10 - depth, touchAction: 'pan-y', cursor: offset === 0 ? 'grab' : 'default',
          borderRadius: 24, padding: 20, color: '#fff', display: 'flex', flexDirection: 'column',
          background: `linear-gradient(150deg, ${sc} 0%, ${sc} 55%, ${sc} 100%)`,
          boxShadow: offset === 0 ? `0 14px 30px ${sc}45` : 'none',
          opacity: depth > 1 ? 0 : 1, overflow: 'hidden',
        }}>
        {depth > 0 && <div style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.14)' }} />}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
          <div style={{ display: 'flex', gap: 18 }}>
            <div>
              <div style={{ fontSize: 11, fontWeight: 700, opacity: 0.75, textTransform: 'uppercase', letterSpacing: 0.3 }}>Time</div>
              <div style={{ fontSize: 18, fontWeight: 700, marginTop: 2 }}>{durationLabel}</div>
            </div>
            <div>
              <div style={{ fontSize: 11, fontWeight: 700, opacity: 0.75, textTransform: 'uppercase', letterSpacing: 0.3 }}>Difficulty</div>
              <div style={{ fontSize: 18, fontWeight: 700, marginTop: 2 }}>{offset === 0 && difficultyLabel ? difficultyLabel : s.difficulty}</div>
            </div>
          </div>
          <Icon name={s.icon} color="#fff" size={26} stroke={2} />
        </div>
        <div style={{ flex: 1 }} />
        <div style={{ fontSize: 24, fontWeight: 700, letterSpacing: -0.3, lineHeight: 1.15, marginBottom: 8 }}>{s.name}</div>
        <div style={{ fontSize: 14, fontWeight: 500, lineHeight: 1.4, opacity: 0.92, textWrap: 'pretty' }}>{s.desc}</div>
      </div>
    );
  };

  return (
    <div>
      <div style={{ position: 'relative', height: 236, marginBottom: 14 }}>
        {[2, 1, 0].map(cardAt)}
      </div>
      <div style={{ display: 'flex', justifyContent: 'center', gap: 6 }}>
        {sports.map((s, i) => (
          <span key={s.id} onClick={() => onChange(i)} style={{
            width: i === index ? 16 : 6, height: 6, borderRadius: 3, cursor: 'pointer',
            background: i === index ? (s.color || accent) : T.ink3, transition: 'width 0.2s' }} />
        ))}
      </div>
    </div>
  );
}

Object.assign(window, { Icon, Card, CardHead, Header, StatBlock, Chip, TabBar, Select, SportCards });

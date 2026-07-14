// charts.jsx — OneMET chart + list primitives (SVG). Design-source companion to
// data.jsx / cards.jsx / screens.jsx. Exports to window so later scripts can use
// bare names: GlucoseChart, TIRBar, ActivityRings, MetMinTrend, WorkoutChart,
// IOSList, IOSListRow.

function GlucoseChart({ accent, mmol, height = 158, data }) {
  const T = window.TOKENS, D = window.DATA;
  const arr = data || D.glucose;
  const W = 320, H = height, lo = 50, hi = 210;
  const x = i => (i / (arr.length - 1)) * W;
  const y = v => H - ((Math.max(lo, Math.min(hi, v)) - lo) / (hi - lo)) * H;
  const path = arr.map((v, i) => `${i === 0 ? 'M' : 'L'}${x(i).toFixed(1)},${y(v).toFixed(1)}`).join(' ');
  const yHigh = y(D.TARGET_HIGH), yLow = y(D.TARGET_LOW), idx = D.currentIdx;
  return (
    <svg viewBox={`0 0 ${W} ${H}`} width="100%" height={H} preserveAspectRatio="none" style={{ display: 'block' }}>
      <rect x="0" y={yHigh} width={W} height={yLow - yHigh} fill={T.green + '14'} />
      <line x1="0" y1={yHigh} x2={W} y2={yHigh} stroke={T.green + '55'} strokeWidth="1" strokeDasharray="3 3" />
      <line x1="0" y1={yLow} x2={W} y2={yLow} stroke={T.red + '55'} strokeWidth="1" strokeDasharray="3 3" />
      <path d={path} fill="none" stroke={accent} strokeWidth="2" strokeLinejoin="round" strokeLinecap="round" vectorEffect="non-scaling-stroke" />
      <circle cx={x(idx)} cy={y(arr[idx])} r="3.5" fill={accent} stroke="#fff" strokeWidth="1.5" />
    </svg>
  );
}

function TIRBar({ height = 8 }) {
  const T = window.TOKENS, tir = window.DATA.tir;
  const seg = (w, c) => <div style={{ width: w + '%', background: c, height: '100%' }} />;
  return (
    <div style={{ display: 'flex', width: '100%', height, borderRadius: height / 2, overflow: 'hidden', background: T.hair }}>
      {seg(tir.low, T.red)}{seg(tir.inRange, T.green)}{seg(tir.high, T.amber)}
    </div>
  );
}

function ActivityRings({ size = 118, stroke = 12, fractions }) {
  const T = window.TOKENS, r = window.DATA.rings;
  const fr = fractions || [r.move.value / r.move.goal, r.exer.value / r.exer.goal, r.met.value / r.met.goal];
  const colors = [T.ringMove, T.ringExer, T.ringMet];
  const cx = size / 2, cy = size / 2;
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
      {fr.map((f, i) => {
        const rad = size / 2 - stroke / 2 - i * (stroke + 3);
        const c = 2 * Math.PI * rad;
        const frac = Math.max(0, Math.min(1, f));
        return (
          <g key={i} transform={`rotate(-90 ${cx} ${cy})`}>
            <circle cx={cx} cy={cy} r={rad} fill="none" stroke={colors[i] + '26'} strokeWidth={stroke} />
            <circle cx={cx} cy={cy} r={rad} fill="none" stroke={colors[i]} strokeWidth={stroke}
              strokeDasharray={`${(c * frac).toFixed(1)} ${c.toFixed(1)}`} strokeLinecap="round" />
          </g>
        );
      })}
    </svg>
  );
}

function MetMinTrend({ data, accent, height = 150 }) {
  const T = window.TOKENS;
  const arr = (data || window.DATA.metMinTrend).slice(-7);
  const max = Math.max(...arr, 1);
  const peak = Math.max(...arr);
  const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  return (
    <div style={{ display: 'flex', alignItems: 'flex-end', gap: 6, height }}>
      {arr.map((v, i) => {
        const isPeak = v === peak, isToday = i === arr.length - 1;
        const hi = isPeak || isToday;
        const h = Math.max(4, (v / max) * (height - 26));
        return (
          <div key={i} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4, justifyContent: 'flex-end' }}>
            <span style={{ fontSize: 9.5, fontWeight: 700, color: hi ? T.ink : T.ink3, fontVariantNumeric: 'tabular-nums' }}>{v}</span>
            <div style={{ width: '100%', height: h, background: hi ? accent : accent + '55', borderRadius: 5 }} />
            <span style={{ fontSize: 9.5, color: isToday ? accent : T.ink3, fontWeight: isToday ? 700 : 500 }}>{labels[i]}</span>
          </div>
        );
      })}
    </div>
  );
}

function WorkoutChart({ workout, accent, height = 168 }) {
  const T = window.TOKENS, D = window.DATA;
  const arr = workout.curve || [];
  const W = 320, H = height, lo = 50, hi = 200;
  const x = i => (i / Math.max(1, arr.length - 1)) * W;
  const y = v => H - ((Math.max(lo, Math.min(hi, v)) - lo) / (hi - lo)) * H;
  const path = arr.map((v, i) => `${i === 0 ? 'M' : 'L'}${x(i).toFixed(1)},${y(v).toFixed(1)}`).join(' ');
  const aS = x(workout.activityStart), aE = x(workout.activityEnd);
  const yHigh = y(D.TARGET_HIGH), yLow = y(D.TARGET_LOW);
  return (
    <svg viewBox={`0 0 ${W} ${H}`} width="100%" height={H} preserveAspectRatio="none" style={{ display: 'block' }}>
      <rect x="0" y={yHigh} width={W} height={yLow - yHigh} fill={T.green + '12'} />
      <rect x={aS} y="0" width={aE - aS} height={H} fill={accent + '12'} />
      <line x1={aS} y1="0" x2={aS} y2={H} stroke={accent + '55'} strokeWidth="1" strokeDasharray="3 3" />
      <line x1={aE} y1="0" x2={aE} y2={H} stroke={accent + '55'} strokeWidth="1" strokeDasharray="3 3" />
      <path d={path} fill="none" stroke={accent} strokeWidth="2" strokeLinejoin="round" strokeLinecap="round" vectorEffect="non-scaling-stroke" />
    </svg>
  );
}

function IOSList({ header, children }) {
  const T = window.TOKENS;
  return (
    <div>
      <div style={{ fontSize: 12.5, fontWeight: 600, color: T.ink2, textTransform: 'uppercase', letterSpacing: 0.2, padding: '0 4px 6px' }}>{header}</div>
      <div style={{ background: T.card, borderRadius: 'var(--radius, 20px)', overflow: 'hidden' }}>{children}</div>
    </div>
  );
}

function IOSListRow({ title, detail, icon, isLast, onClick }) {
  const T = window.TOKENS;
  return (
    <div onClick={onClick} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '12px 14px',
      borderBottom: isLast ? 'none' : `0.5px solid ${T.sep}`, cursor: onClick ? 'pointer' : 'default' }}>
      <span style={{ width: 10, height: 10, borderRadius: 5, background: icon, flexShrink: 0 }} />
      <span style={{ fontSize: 15, color: T.ink, flex: 1 }}>{title}</span>
      {detail && <span style={{ fontSize: 14, color: T.ink2 }}>{detail}</span>}
      {onClick && <Icon name="chevron" color={T.ink3} size={14} />}
    </div>
  );
}

Object.assign(window, { GlucoseChart, TIRBar, ActivityRings, MetMinTrend, WorkoutChart, IOSList, IOSListRow });

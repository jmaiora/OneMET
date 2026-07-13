// screens.jsx — OneMET screens (Summary, Activity, Trends, Profile, GlucoseDetail)

const SCROLL = {
  height: '100%', overflowY: 'auto', WebkitOverflowScrolling: 'touch',
  display: 'flex', flexDirection: 'column', gap: 14,
  padding: '56px 16px 120px',
};

function Arrow({ dir, color }) {
  // trend arrow: dir = 'up' | 'down' | 'flat'
  const rot = dir === 'up' ? -45 : dir === 'down' ? 45 : 0;
  return (
    <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round" style={{ transform: `rotate(${rot}deg)` }}>
      <path d="M4 12h16M14 6l6 6-6 6" />
    </svg>
  );
}

// ── SUMMARY ───────────────────────────────────────────────────
function SummaryScreen({ accent, mmol, onOpenGlucose, onGoActivity }) {
  const T = window.TOKENS;
  const st = glucoseStatus(DATA.current);
  const val = fmtGlucose(DATA.current, mmol);
  const unit = mmol ? 'mmol/L' : 'mg/dL';
  const r = DATA.rings;

  return (
    <div style={SCROLL}>
      <Header title="Summary" date="Friday, Jun 19" accent={accent} />

      {/* GLUCOSE HERO */}
      <Card icon="drop" iconColor={T.green} title="Glucose" right="Updated 2 min ago" onClick={onOpenGlucose}>
        <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', marginBottom: 6 }}>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 6 }}>
            <span style={{ fontSize: 52, fontWeight: 700, color: T.ink, letterSpacing: -1.5, lineHeight: 1, fontVariantNumeric: 'tabular-nums' }}>{val}</span>
            <span style={{ fontSize: 15, fontWeight: 600, color: T.ink2 }}>{unit}</span>
            <span style={{ marginLeft: 2 }}><Arrow dir="down" color={st.color} /></span>
          </div>
          <Chip color={st.color}><span style={{ width: 6, height: 6, borderRadius: 3, background: st.color, display: 'inline-block' }} />{st.label}</Chip>
        </div>
        <GlucoseChart accent={accent} mmol={mmol} height={158} />
        <div style={{ height: 1, background: T.hair, margin: '12px 0 12px' }} />
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 8 }}>
          <span style={{ fontSize: 12.5, fontWeight: 600, color: T.ink2, textTransform: 'uppercase', letterSpacing: 0.2, whiteSpace: 'nowrap' }}>Time in Range</span>
          <span style={{ fontSize: 13, fontWeight: 700, color: T.green, flexShrink: 0, marginLeft: 8 }}>{DATA.tir.inRange}%</span>
        </div>
        <TIRBar />
        <div style={{ display: 'flex', gap: 14, marginTop: 9 }}>
          {[['Low', DATA.tir.low, T.red], ['In Range', DATA.tir.inRange, T.green], ['High', DATA.tir.high, T.amber]].map(([l, v, c]) => (
            <span key={l} style={{ display: 'flex', alignItems: 'center', gap: 5, fontSize: 11.5, color: T.ink2, fontWeight: 500 }}>
              <span style={{ width: 7, height: 7, borderRadius: 4, background: c }} />{l} {v}%
            </span>
          ))}
        </div>
      </Card>

      {/* INSIGHT */}
      <div style={{ background: accent, borderRadius: 'var(--radius, 20px)', padding: 16, color: '#fff',
        boxShadow: '0 6px 18px ' + accent + '40' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 7, marginBottom: 7 }}>
          <Icon name="bolt" color="#fff" size={15} />
          <span style={{ fontSize: 13, fontWeight: 700, letterSpacing: 0.2, textTransform: 'uppercase', opacity: 0.92 }}>Activity Insight</span>
        </div>
        <div style={{ fontSize: 17, fontWeight: 600, lineHeight: 1.35, letterSpacing: -0.2, textWrap: 'pretty' }}>
          Your 4:08 PM run lowered glucose by <span style={{ fontWeight: 800 }}>38 mg/dL</span> over 32 min — consider 15g carbs before similar sessions.
        </div>
      </div>

      {/* ACTIVITY RINGS */}
      <Card icon="flame" iconColor={T.ringMove} title="Activity" onClick={onGoActivity}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 18 }}>
          <ActivityRings size={118} stroke={12} />
          <div style={{ display: 'flex', flexDirection: 'column', gap: 11, flex: 1 }}>
            <RingStat color={T.ringMove} label="Move" value={r.move.value} goal={r.move.goal} unit="kcal" />
            <RingStat color={T.ringExer} label="Exercise" value={r.exer.value} goal={r.exer.goal} unit="min" />
            <RingStat color={T.ringMet} label="MET" value={r.met.value} goal={r.met.goal} unit="MET·min" />
          </div>
        </div>
      </Card>

      {/* MET + HEART row */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14 }}>
        <Card icon="bolt" iconColor={T.ringMet} title="MET" pad={14}>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 3 }}>
            <span style={{ fontSize: 30, fontWeight: 700, color: T.ink, letterSpacing: -0.8, fontVariantNumeric: 'tabular-nums' }}>486</span>
            <span style={{ fontSize: 12, fontWeight: 600, color: T.ink2 }}>MET·min</span>
          </div>
          <span style={{ fontSize: 11.5, color: T.ink2, fontWeight: 500 }}>Peak 9.1 on your run</span>
          <div style={{ marginTop: 8 }}><MetBars accent={T.ringMet} height={62} /></div>
        </Card>
        <Card icon="heart" iconColor={T.red} title="Heart" pad={14}>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 3 }}>
            <span style={{ fontSize: 30, fontWeight: 700, color: T.ink, letterSpacing: -0.8, fontVariantNumeric: 'tabular-nums' }}>{DATA.heart.current}</span>
            <span style={{ fontSize: 12, fontWeight: 600, color: T.ink2 }}>BPM</span>
          </div>
          <span style={{ fontSize: 11.5, color: T.ink2, fontWeight: 500 }}>Range {DATA.heart.range[0]}–{DATA.heart.range[1]}</span>
          <div style={{ marginTop: 8 }}><HeartChart height={62} /></div>
        </Card>
      </div>

    </div>
  );
}

function RingStat({ color, label, value, goal, unit }) {
  const T = window.TOKENS;
  return (
    <div>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 4 }}>
        <span style={{ fontSize: 13, fontWeight: 600, color }}>{label}</span>
        <span style={{ fontSize: 18, fontWeight: 700, color: T.ink, fontVariantNumeric: 'tabular-nums', letterSpacing: -0.3 }}>{value}</span>
        <span style={{ fontSize: 11.5, color: T.ink2, fontWeight: 500 }}>/ {goal} {unit}</span>
      </div>
      <div style={{ height: 4, borderRadius: 2, background: color + '24', marginTop: 4, overflow: 'hidden' }}>
        <div style={{ width: Math.min(100, (value / goal) * 100) + '%', height: '100%', background: color, borderRadius: 2 }} />
      </div>
    </div>
  );
}

function WorkoutRow({ w, accent, last }) {
  const T = window.TOKENS;
  const dropColor = w.glucoseDelta < 0 ? T.green : T.amber;
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '10px 0',
      borderBottom: last ? 'none' : `0.5px solid ${T.sep}` }}>
      <div style={{ width: 38, height: 38, borderRadius: 10, background: accent + '16',
        display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
        <Icon name="run" color={accent} size={20} />
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 15, fontWeight: 600, color: T.ink }}>{w.name}</div>
        <div style={{ fontSize: 12.5, color: T.ink2 }}>{w.time} · {w.dist} · {w.dur}</div>
      </div>
      <div style={{ textAlign: 'right' }}>
        <Chip color={dropColor}>{w.glucoseDelta > 0 ? '+' : ''}{w.glucoseDelta} mg/dL</Chip>
        <div style={{ fontSize: 11, color: T.ink3, marginTop: 3, fontVariantNumeric: 'tabular-nums' }}>{w.avgMet} MET avg</div>
      </div>
    </div>
  );
}

// ── WORKOUTS (history + detail) ──────────────────────────────
function HistoryRow({ w, accent, last, onClick }) {
  const T = window.TOKENS;
  const dropColor = w.glucoseDelta < 0 ? T.green : T.amber;
  return (
    <div onClick={onClick} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '10px 0',
      borderBottom: last ? 'none' : `0.5px solid ${T.sep}`, cursor: 'pointer' }}>
      <div style={{ width: 38, height: 38, borderRadius: 10, background: accent + '16',
        display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
        <Icon name={w.icon || 'run'} color={accent} size={20} />
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 15, fontWeight: 600, color: T.ink }}>{w.name}</div>
        <div style={{ fontSize: 12.5, color: T.ink2 }}>{w.day} · {w.time} · {w.dur}</div>
      </div>
      <div style={{ textAlign: 'right' }}>
        <Chip color={dropColor}>{w.glucoseDelta > 0 ? '+' : ''}{w.glucoseDelta} mg/dL</Chip>
        <div style={{ fontSize: 11, color: T.ink3, marginTop: 3, fontVariantNumeric: 'tabular-nums' }}>{w.avgMet} MET avg</div>
      </div>
      <Icon name="chevron" color={T.ink3} size={14} />
    </div>
  );
}

function WorkoutsScreen({ accent, onOpenWorkout }) {
  const T = window.TOKENS;
  const [visibleWeeks, setVisibleWeeks] = React.useState(2);
  const weeks = DATA.workoutHistory.slice(0, visibleWeeks);
  const totalCount = DATA.workoutHistory.reduce((n, wk) => n + wk.workouts.length, 0);
  const shownCount = weeks.reduce((n, wk) => n + wk.workouts.length, 0);

  return (
    <div style={SCROLL}>
      <Header title="Workouts" date="History" accent={accent} />

      <Card style={{ padding: 20 }}>
        <div style={{ display: 'flex', justifyContent: 'center', marginBottom: 16 }}>
          <ActivityRings size={140} stroke={14} />
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          <RingStat color={T.ringMove} label="Move" value={DATA.rings.move.value} goal={DATA.rings.move.goal} unit="kcal" />
          <RingStat color={T.ringExer} label="Exercise" value={DATA.rings.exer.value} goal={DATA.rings.exer.goal} unit="min" />
          <RingStat color={T.ringMet} label="MET" value={DATA.rings.met.value} goal={DATA.rings.met.goal} unit="MET·min" />
        </div>
      </Card>

      {weeks.map((wk, wi) => (
        <Card key={wi} icon="run" iconColor={accent} title={wk.label} right={`${wk.workouts.length} workout${wk.workouts.length === 1 ? '' : 's'}`}>
          {wk.workouts.map((w, i) => (
            <HistoryRow key={w.id} w={w} accent={accent} last={i === wk.workouts.length - 1}
              onClick={() => onOpenWorkout(w)} />
          ))}
        </Card>
      ))}

      {shownCount < totalCount && (
        <div onClick={() => setVisibleWeeks(v => v + 2)}
          style={{ textAlign: 'center', padding: '13px 0', fontSize: 15, fontWeight: 600, color: accent, cursor: 'pointer' }}>
          Load Past Weeks
        </div>
      )}
    </div>
  );
}

function WorkoutDetailScreen({ workout, accent, onBack }) {
  const T = window.TOKENS;
  const w = workout;
  const dropColor = w.glucoseDelta < 0 ? T.green : T.amber;
  return (
    <div style={{ ...SCROLL, gap: 14 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6, padding: '4px 0 2px', cursor: 'pointer' }} onClick={onBack}>
        <svg width="12" height="20" viewBox="0 0 12 20" fill="none"><path d="M10 2L2 10l8 8" stroke={accent} strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round"/></svg>
        <span style={{ fontSize: 17, color: accent, fontWeight: 500 }}>Workouts</span>
      </div>
      <div style={{ padding: '0 0 2px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div>
          <div style={{ fontSize: 13, fontWeight: 600, color: T.ink2, textTransform: 'uppercase', letterSpacing: 0.2 }}>{w.day} · {w.time}</div>
          <div style={{ fontSize: 28, fontWeight: 700, color: T.ink, letterSpacing: 0.2, lineHeight: 1.15 }}>{w.name}</div>
        </div>
        <div style={{ width: 44, height: 44, borderRadius: 14, background: accent + '16',
          display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
          <Icon name={w.icon || 'run'} color={accent} size={24} />
        </div>
      </div>

      <Card>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '14px 8px', marginBottom: 14 }}>
          <StatBlock label="Duration" value={w.durMin} unit="min" />
          <StatBlock label="Distance" value={w.dist} />
          <StatBlock label="Calories" value={w.kcal} unit="kcal" />
          <StatBlock label="Avg MET" value={w.avgMet} />
          <StatBlock label="Avg HR" value={w.hr} unit="bpm" color={T.red} />
          <StatBlock label="Glucose Δ" value={`${w.glucoseDelta > 0 ? '+' : ''}${w.glucoseDelta}`} unit="mg/dL" color={dropColor} />
        </div>
        <WorkoutChart workout={w} accent={accent} height={168} />
      </Card>

      {/* Activity Insight — in blue as specified */}
      <div style={{ background: '#2A6FDB', borderRadius: 'var(--radius, 20px)', padding: 16, color: '#fff',
        boxShadow: '0 6px 18px #2A6FDB40' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 7, marginBottom: 7 }}>
          <Icon name="bolt" color="#fff" size={15} />
          <span style={{ fontSize: 13, fontWeight: 700, letterSpacing: 0.2, textTransform: 'uppercase', opacity: 0.92 }}>Activity Insight</span>
        </div>
        <div style={{ fontSize: 16, fontWeight: 600, lineHeight: 1.35, letterSpacing: -0.2, textWrap: 'pretty' }}>
          {w.insight}
        </div>
      </div>
    </div>
  );
}

// ── PLAN ──────────────────────────────────────────────────────
function PlanScreen({ accent }) {
  const T = window.TOKENS;
  const [sportIndex, setSportIndex] = React.useState(0);
  const sportId = SPORTS[sportIndex].id;
  const [duration, setDuration] = React.useState(45);
  const [iob, setIob] = React.useState(1.0);
  const [recentCarbs, setRecentCarbs] = React.useState(30);

  const plan = computeCarbPlan({ sportId, durationMin: Number(duration), iob: Number(iob), recentCarbsG: Number(recentCarbs) });
  const riskColor = plan.risk === 'High' ? T.red : plan.risk === 'Moderate' ? T.amber : T.green;

  const sportOptions = SPORTS.map(s => ({ value: s.id, label: s.name }));
  const durationOptions = [15, 30, 45, 60, 90].map(d => ({ value: d, label: `${d} min` }));
  const iobOptions = [0, 0.5, 1.0, 1.5, 2.0, 3.0].map(v => ({ value: v, label: `${v.toFixed(1)} U` }));
  const carbOptions = [0, 15, 30, 45, 60, 90].map(v => ({ value: v, label: `${v} g` }));

  return (
    <div style={SCROLL}>
      <Header title="Plan" date="Workout Planner" accent={accent} />

      <Card icon="calendar" iconColor={accent} title="Session Details">
        <SportCards sports={SPORTS} index={sportIndex} onChange={setSportIndex} accent={accent}
          durationLabel={`${duration} min`} />
        <div style={{ marginTop: 6 }}>
          <Select label="Planned Duration" value={duration} onChange={v => setDuration(Number(v))} accent={accent}
            options={durationOptions} />
        </div>
      </Card>

      <Card icon="bolt" iconColor={T.amber} title="Current State">
        <Select label="Insulin on Board" value={iob} onChange={v => setIob(Number(v))} accent={accent}
          options={iobOptions} render={v => `${Number(v).toFixed(1)} U`} />
        <Select label="Carbs, Last 2h" value={recentCarbs} onChange={v => setRecentCarbs(Number(v))} accent={accent}
          options={carbOptions} render={v => `${v} g`} />
      </Card>

      <div style={{ background: accent, borderRadius: 'var(--radius, 20px)', padding: 18, color: '#fff',
        boxShadow: '0 6px 18px ' + accent + '40' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 7, marginBottom: 10 }}>
          <Icon name="fork" color="#fff" size={16} />
          <span style={{ fontSize: 13, fontWeight: 700, letterSpacing: 0.2, textTransform: 'uppercase', opacity: 0.92 }}>Carb Recommendation</span>
        </div>
        <div style={{ display: 'flex', gap: 20, marginBottom: 12 }}>
          <div>
            <div style={{ fontSize: 11.5, fontWeight: 600, opacity: 0.8, textTransform: 'uppercase', letterSpacing: 0.2 }}>Before</div>
            <div style={{ fontSize: 30, fontWeight: 700, letterSpacing: -0.8 }}>{plan.pre}<span style={{ fontSize: 15, fontWeight: 600 }}> g</span></div>
          </div>
          {plan.needsDuring && (
            <div>
              <div style={{ fontSize: 11.5, fontWeight: 600, opacity: 0.8, textTransform: 'uppercase', letterSpacing: 0.2 }}>Every 30 min</div>
              <div style={{ fontSize: 30, fontWeight: 700, letterSpacing: -0.8 }}>{plan.duringPer30}<span style={{ fontSize: 15, fontWeight: 600 }}> g</span></div>
            </div>
          )}
        </div>
        <div style={{ fontSize: 15, fontWeight: 500, lineHeight: 1.4, letterSpacing: -0.1, textWrap: 'pretty' }}>
          {plan.pre === 0
            ? `Low hypo risk for this ${plan.sport.name.toLowerCase()} session — no pre-carbs needed given current IOB and recent intake.`
            : `Eat ${plan.pre}g of fast carbs 15–20 min before your ${plan.sport.name.toLowerCase()}${plan.needsDuring ? `, then ${plan.duringPer30}g every 30 min during the session` : ''}. Based on ${plan.sport.met} MET intensity, ${iob.toFixed(1)}U IOB, and ${recentCarbs}g eaten in the last 2h.`}
        </div>
      </div>

      <Card title="Hypo Risk">
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <span style={{ width: 10, height: 10, borderRadius: 5, background: riskColor, flexShrink: 0 }} />
          <span style={{ fontSize: 17, fontWeight: 700, color: riskColor }}>{plan.risk}</span>
          <span style={{ fontSize: 13, color: T.ink2 }}>· {plan.intensity} intensity · {plan.met} MET</span>
        </div>
      </Card>
    </div>
  );
}

// ── PROFILE ───────────────────────────────────────────────────
function ProfileScreen({ accent }) {
  const T = window.TOKENS;
  return (
    <div style={{ ...SCROLL, gap: 18 }}>
      <Header title="Profile" date="Account" accent={accent} />
      <div style={{ display: 'flex', alignItems: 'center', gap: 14, padding: '4px 16px 6px' }}>
        <div style={{ width: 60, height: 60, borderRadius: 30, background: accent, color: '#fff',
          display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 24, fontWeight: 600 }}>AM</div>
        <div>
          <div style={{ fontSize: 21, fontWeight: 700, color: T.ink }}>Alex Moreno</div>
          <div style={{ fontSize: 14, color: T.ink2 }}>Type 1 · since 2014</div>
        </div>
      </div>

      <IOSList header="Connected Devices">
        <IOSListRow title="CGM Sensor" detail="Connected" icon={T.green} />
        <IOSListRow title="Apple Watch" detail="Series 9" icon={T.red} />
        <IOSListRow title="Insulin Pen" detail="Synced 9:41" icon={accent} isLast />
      </IOSList>

      <IOSList header="Targets">
        <IOSListRow title="Glucose Range" detail="70–180 mg/dL" icon={T.green} />
        <IOSListRow title="Daily MET Goal" detail="500 MET·min" icon={T.ringMet} />
        <IOSListRow title="Carb Ratio" detail="1 : 10" icon={T.amber} isLast />
      </IOSList>

      <IOSList header="Data">
        <IOSListRow title="Export Health Report" icon={accent} />
        <IOSListRow title="Share with Clinician" icon={T.teal} />
        <IOSListRow title="Notifications" icon={T.violet} isLast />
      </IOSList>
    </div>
  );
}

// ── GLUCOSE DETAIL (overlay) ──────────────────────────────────
function GlucoseDetail({ accent, mmol, onBack }) {
  const T = window.TOKENS;
  const st = glucoseStatus(DATA.current);
  return (
    <div style={{ ...SCROLL, gap: 14 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6, padding: '4px 0 2px', cursor: 'pointer' }} onClick={onBack}>
        <svg width="12" height="20" viewBox="0 0 12 20" fill="none"><path d="M10 2L2 10l8 8" stroke={accent} strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round"/></svg>
        <span style={{ fontSize: 17, color: accent, fontWeight: 500 }}>Summary</span>
      </div>
      <div style={{ padding: '0 0 2px' }}>
        <div style={{ fontSize: 13, fontWeight: 600, color: T.ink2, textTransform: 'uppercase', letterSpacing: 0.2 }}>Friday, Jun 19</div>
        <div style={{ fontSize: 32, fontWeight: 700, color: T.ink, letterSpacing: 0.36, lineHeight: 1.1 }}>Glucose</div>
      </div>

      <Card>
        <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', marginBottom: 8 }}>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 6 }}>
            <span style={{ fontSize: 52, fontWeight: 700, color: T.ink, letterSpacing: -1.5, lineHeight: 1, fontVariantNumeric: 'tabular-nums' }}>{fmtGlucose(DATA.current, mmol)}</span>
            <span style={{ fontSize: 15, fontWeight: 600, color: T.ink2 }}>{mmol ? 'mmol/L' : 'mg/dL'}</span>
          </div>
          <Chip color={st.color}><span style={{ width: 6, height: 6, borderRadius: 3, background: st.color, display: 'inline-block' }} />{st.label} · falling</Chip>
        </div>
        <GlucoseChart accent={accent} mmol={mmol} height={184} />
      </Card>

      <Card title="Today">
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '18px 14px' }}>
          <StatBlock label="Average" value={fmtGlucose(DATA.avg, mmol)} unit={mmol ? 'mmol/L' : 'mg/dL'} />
          <StatBlock label="Time in Range" value={DATA.tir.inRange} unit="%" color={T.green} />
          <StatBlock label="Lowest" value={fmtGlucose(68, mmol)} color={T.red} />
          <StatBlock label="Highest" value={fmtGlucose(191, mmol)} color={T.amber} />
          <StatBlock label="Std. Dev" value={mmol ? '1.8' : '32'} />
          <StatBlock label="GMI" value="6.4" unit="%" />
        </div>
        <div style={{ height: 1, background: T.hair, margin: '16px 0 14px' }} />
        <div style={{ marginBottom: 8, fontSize: 12.5, fontWeight: 600, color: T.ink2, textTransform: 'uppercase', letterSpacing: 0.2 }}>Range Distribution</div>
        <TIRBar height={16} />
        <div style={{ display: 'flex', gap: 14, marginTop: 9 }}>
          {[['Low', DATA.tir.low, T.red], ['In Range', DATA.tir.inRange, T.green], ['High', DATA.tir.high, T.amber]].map(([l, v, c]) => (
            <span key={l} style={{ display: 'flex', alignItems: 'center', gap: 5, fontSize: 11.5, color: T.ink2, fontWeight: 500 }}>
              <span style={{ width: 7, height: 7, borderRadius: 4, background: c }} />{l} {v}%
            </span>
          ))}
        </div>
      </Card>

      <Card icon="bolt" iconColor={accent} title="Events">
        {[
          { t: '7:30 AM', d: 'Breakfast · 62g carbs', c: T.amber },
          { t: '8:12 AM', d: 'Walk · −9 mg/dL', c: T.green },
          { t: '12:15 PM', d: 'Lunch · 48g carbs', c: T.amber },
          { t: '4:08 PM', d: 'Run · −38 mg/dL', c: T.green },
          { t: '5:55 PM', d: 'Snack · 22g (low treatment)', c: T.red },
        ].map((e, i, a) => (
          <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '9px 0', borderBottom: i === a.length - 1 ? 'none' : `0.5px solid ${T.sep}` }}>
            <span style={{ width: 8, height: 8, borderRadius: 4, background: e.c, flexShrink: 0 }} />
            <span style={{ fontSize: 13, color: T.ink2, width: 64, fontVariantNumeric: 'tabular-nums' }}>{e.t}</span>
            <span style={{ fontSize: 14, color: T.ink, fontWeight: 500 }}>{e.d}</span>
          </div>
        ))}
      </Card>
    </div>
  );
}

Object.assign(window, { SummaryScreen, WorkoutsScreen, WorkoutDetailScreen, PlanScreen, ProfileScreen, GlucoseDetail });

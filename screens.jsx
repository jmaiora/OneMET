// screens.jsx — OneMET screens (Summary, Plan, Workouts, WorkoutDetail, Profile, GlucoseDetail)

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
  const T = window.TOKENS, P = window.PROFILE;
  const st = glucoseStatus(DATA.current);
  const val = fmtGlucose(DATA.current, mmol);
  const unit = mmol ? 'mmol/L' : 'mg/dL';
  const r = DATA.rings;
  const tw = DATA.todayWorkout;

  return (
    <div style={SCROLL}>
      <Header title="Summary" date="Friday, Jun 19" accent={accent} />

      {/* GLUCOSE HERO — swaps to the per-workout curve when a workout is logged today */}
      <Card icon="drop" iconColor={T.green} title="Glucose" right="Now" onClick={onOpenGlucose}>
        <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', marginBottom: 6 }}>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 6 }}>
            <span style={{ fontSize: 52, fontWeight: 700, color: T.ink, letterSpacing: -1.5, lineHeight: 1, fontVariantNumeric: 'tabular-nums' }}>{val}</span>
            <span style={{ fontSize: 15, fontWeight: 600, color: T.ink2 }}>{unit}</span>
            <span style={{ marginLeft: 2 }}><Arrow dir="down" color={st.color} /></span>
          </div>
          <Chip color={st.color}><span style={{ width: 6, height: 6, borderRadius: 3, background: st.color, display: 'inline-block' }} />{st.label}</Chip>
        </div>
        {tw ? <WorkoutChart workout={tw} accent={accent} height={158} /> : <GlucoseChart accent={accent} mmol={mmol} height={158} />}
        <div style={{ height: 1, background: T.hair, margin: '12px 0 12px' }} />
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 8 }}>
          <span style={{ fontSize: 12.5, fontWeight: 600, color: T.ink2, textTransform: 'uppercase', letterSpacing: 0.2 }}>Time in Range</span>
          <span style={{ fontSize: 13, fontWeight: 700, color: T.green }}>{DATA.tir.inRange}%</span>
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
      <div style={{ background: accent, borderRadius: 'var(--radius, 20px)', padding: 16, color: '#fff', boxShadow: '0 6px 18px ' + accent + '40' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 7, marginBottom: 7 }}>
          <Icon name="bolt" color="#fff" size={15} />
          <span style={{ fontSize: 13, fontWeight: 700, letterSpacing: 0.2, textTransform: 'uppercase', opacity: 0.92 }}>Activity Insight</span>
        </div>
        <div style={{ fontSize: 17, fontWeight: 600, lineHeight: 1.35, letterSpacing: -0.2 }}>
          Your 4:08 PM run lowered glucose by <span style={{ fontWeight: 800 }}>38 mg/dL</span> over 32 min — consider 15g carbs before similar sessions.
        </div>
      </div>

      {/* BEFORE WORKOUT (generic; full session guide lives on the Plan tab) */}
      <Card icon="bolt" iconColor={accent} title="Before workout">
        <div style={{ fontSize: 17, fontWeight: 700, color: T.ink, lineHeight: 1.4 }}>{beforeWorkoutSummary(P.isPump)}</div>
        <div style={{ fontSize: 11.5, fontWeight: 500, color: T.ink3, lineHeight: 1.4, marginTop: 10 }}>
          Illustrative guidance, not medical advice. See the Plan tab for a session-specific start decision.
        </div>
      </Card>

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

      {/* MET·MIN TREND (full width) */}
      <Card icon="bolt" iconColor={T.ringMet} title="MET·min" right="Last 7 days">
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 6, marginBottom: 8 }}>
          <span style={{ fontSize: 30, fontWeight: 700, color: T.ink, letterSpacing: -0.8, fontVariantNumeric: 'tabular-nums' }}>{r.met.value}</span>
          <span style={{ fontSize: 12, fontWeight: 600, color: T.ink2 }}>MET·min today</span>
        </div>
        <MetMinTrend accent={T.ringMet} height={150} />
      </Card>
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
  const T = window.TOKENS, P = window.PROFILE;
  const [sportIndex, setSportIndex] = React.useState(0);
  const [duration, setDuration] = React.useState(45);
  const [iob, setIob] = React.useState(1.0);
  const [difficultyId, setDifficultyId] = React.useState(SPORTS[0].difficulty.toLowerCase());
  const difficulty = DIFFICULTIES.find(d => d.id === difficultyId) || DIFFICULTIES[1];

  const guide = buildRunGuide({
    durationMin: Number(duration), iob: Number(iob),
    glucoseMgdl: DATA.current, trend: DATA.currentTrend, difficulty, isPump: P.isPump,
  });
  const g = guide.during;
  const st = glucoseStatus(DATA.current);

  const durationOptions = [15, 30, 45, 60, 75, 90, 120, 150, 180].map(d => ({ value: d, label: `${d} min` }));
  const iobOptions = [0, 0.5, 1.0, 1.5, 2.0, 3.0].map(v => ({ value: v, label: `${v.toFixed(1)} U` }));
  const diffOptions = DIFFICULTIES.map(d => ({ value: d.id, label: d.label }));

  return (
    <div style={SCROLL}>
      <Header title="Plan" date="Run Guide" accent={accent} />

      <Card icon="calendar" iconColor={accent} title="Session Details">
        <SportCards sports={SPORTS} index={sportIndex} onChange={(i) => { setSportIndex(i); setDifficultyId(SPORTS[i].difficulty.toLowerCase()); }} accent={accent} durationLabel={`${duration} min`} difficultyLabel={difficulty.label} />
        <div style={{ marginTop: 6 }}>
          <Select label="Planned Duration" value={duration} onChange={v => setDuration(Number(v))} accent={accent} options={durationOptions} />
          <Select label="Difficulty" value={difficultyId} onChange={setDifficultyId} accent={accent} options={diffOptions} />
        </div>
      </Card>

      <Card icon="bolt" iconColor={T.amber} title="Current State">
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '11px 0', borderBottom: `0.5px solid ${T.sep}` }}>
          <span style={{ fontSize: 15, color: T.ink, fontWeight: 500 }}>Current Glucose</span>
          <span style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
            <span style={{ fontSize: 15, fontWeight: 700, color: st.color, fontVariantNumeric: 'tabular-nums' }}>{DATA.current}</span>
            <span style={{ fontSize: 13, color: T.ink2 }}>mg/dL</span>
            <Arrow dir="down" color={st.color} />
          </span>
        </div>
        <Select label="Insulin on Board" value={iob} onChange={v => setIob(Number(v))} accent={accent} options={iobOptions} render={v => `${Number(v).toFixed(1)} U`} />
      </Card>

      {/* START DECISION */}
      <div style={{ background: guide.statusColor, borderRadius: 'var(--radius, 20px)', padding: 16, color: '#fff', boxShadow: '0 6px 18px ' + guide.statusColor + '47' }}>
        <div style={{ fontSize: 18, fontWeight: 700, marginBottom: 5, letterSpacing: -0.2 }}>{guide.startTitle}</div>
        <div style={{ fontSize: 15, fontWeight: 500, lineHeight: 1.4, opacity: 0.96 }}>{guide.startReason}</div>
      </div>

      {/* DURING (highlighted) */}
      <div style={{ background: T.ringMet, borderRadius: 'var(--radius, 20px)', padding: 16, color: '#fff', boxShadow: '0 6px 18px ' + T.ringMet + '47' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 10 }}>
          <Icon name="fork" color="#fff" size={16} />
          <span style={{ fontSize: 16, fontWeight: 700 }}>During · {g.difficultyLabel}</span>
          <span style={{ flex: 1 }} />
          <span style={{ fontSize: 10.5, fontWeight: 600, opacity: 0.85, textTransform: 'uppercase', letterSpacing: 0.2, textAlign: 'right' }}>{guide.bandDetail}</span>
        </div>
        {g.total > 0 && (
          <div>
            <div style={{ display: 'flex', gap: 22, marginBottom: 6 }}>
              {g.startG > 0 && (
                <div>
                  <div style={{ fontSize: 27, fontWeight: 800, letterSpacing: -0.5 }}>~{g.startG} g</div>
                  <div style={{ fontSize: 10, fontWeight: 600, opacity: 0.8, textTransform: 'uppercase', letterSpacing: 0.3 }}>At Start</div>
                </div>
              )}
              {g.feeds > 0 && (
                <div>
                  <div style={{ fontSize: 27, fontWeight: 800, letterSpacing: -0.5 }}>~{g.perFeed} g</div>
                  <div style={{ fontSize: 10, fontWeight: 600, opacity: 0.8, textTransform: 'uppercase', letterSpacing: 0.3 }}>Every {g.intervalMin} min</div>
                </div>
              )}
            </div>
            <div style={{ fontSize: 12, fontWeight: 600, opacity: 0.85, marginBottom: 8 }}>{g.headline} · ~{g.total} g total</div>
          </div>
        )}
        <div style={{ fontSize: 13.5, fontWeight: 500, lineHeight: 1.45, opacity: 0.96 }}>{g.text}</div>
      </div>

      <Card title="Good to know">
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          <div style={{ display: 'flex', gap: 9, alignItems: 'flex-start' }}>
            <span style={{ color: T.green, fontWeight: 700, fontSize: 15 }}>✓</span>
            <span style={{ fontSize: 13.5, color: T.ink, lineHeight: 1.4 }}>{guide.philosophy}</span>
          </div>
          <div style={{ display: 'flex', gap: 9, alignItems: 'flex-start' }}>
            <span style={{ color: accent, fontWeight: 700, fontSize: 15 }}>↗</span>
            <span style={{ fontSize: 13.5, color: T.ink, lineHeight: 1.4 }}>{guide.learn}</span>
          </div>
        </div>
      </Card>

      <div style={{ background: T.amber + '1a', borderRadius: 14, padding: 14, display: 'flex', gap: 8, alignItems: 'flex-start' }}>
        <span style={{ color: T.amber, fontWeight: 700 }}>⚠</span>
        <span style={{ fontSize: 12.5, fontWeight: 500, color: T.ink2, lineHeight: 1.4 }}>Illustrative guidance, not medical advice. Insulin changes and carbohydrate decisions should be agreed with your clinician.</span>
      </div>
      <div style={{ fontSize: 11.5, color: T.ink3, lineHeight: 1.5, padding: '0 4px' }}>
        Approach: a prevention-first reading of the 2017 Lancet consensus on exercise in type 1 diabetes (Riddell et al.) and EXTOD, oriented to recreational training.
      </div>
    </div>
  );
}

// ── PROFILE ───────────────────────────────────────────────────
function ProfileScreen({ accent }) {
  const T = window.TOKENS, P = window.PROFILE;
  const delivery = P.insulinDelivery === 'pump' ? 'Insulin Pump' : 'Injections (MDI)';
  return (
    <div style={{ ...SCROLL, gap: 18 }}>
      <Header title="Profile" date="Account" accent={accent} />
      <div style={{ display: 'flex', alignItems: 'center', gap: 14, padding: '4px 16px 6px' }}>
        <div style={{ width: 60, height: 60, borderRadius: 30, background: accent, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 24, fontWeight: 600 }}>{P.initials}</div>
        <div>
          <div style={{ fontSize: 21, fontWeight: 700, color: T.ink }}>{P.name}</div>
          <div style={{ fontSize: 14, color: T.ink2 }}>{P.diabetesType} · since {P.diagnosisYear}</div>
        </div>
      </div>

      <IOSList header="Connected Devices">
        <IOSListRow title="CGM Sensor" detail="Connected" icon={T.green} />
        <IOSListRow title="Apple Watch" detail="Series 9" icon={T.red} />
        <IOSListRow title="Insulin Pen" detail="Synced 9:41" icon={accent} isLast />
      </IOSList>

      <IOSList header="Glucose Source">
        <IOSListRow title="Nightscout" detail="On · live" icon={T.green} isLast />
      </IOSList>

      <IOSList header="Personal Targets">
        <IOSListRow title="Glucose Range" detail={`${P.glucoseLow}–${P.glucoseHigh} mg/dL`} icon={T.green} />
        <IOSListRow title="Daily MET Goal" detail={`${P.dailyMetGoal} MET·min`} icon={T.ringMet} />
        <IOSListRow title="Carb Ratio" detail={`1 : ${P.carbRatio}`} icon={T.amber} />
        <IOSListRow title="Insulin Delivery" detail={delivery} icon={accent} isLast />
      </IOSList>

      <IOSList header="Body">
        <IOSListRow title="Weight" detail={`${P.weightKg.toFixed(1)} kg`} icon={T.teal} isLast />
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

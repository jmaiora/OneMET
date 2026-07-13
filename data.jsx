// data.jsx — OneMET design tokens + mock health data
// Exports to window: TOKENS, glucoseStatus, DATA, fmtGlucose

const TOKENS = {
  bg:    '#EFEFF4',
  card:  '#FFFFFF',
  ink:   '#1C1C1E',
  ink2:  'rgba(60,60,67,0.60)',
  ink3:  'rgba(60,60,67,0.32)',
  sep:   'rgba(60,60,67,0.13)',
  hair:  'rgba(60,60,67,0.07)',
  // semantic
  green: '#30B85C',   // in-range
  amber: '#F5A02A',   // high
  red:   '#FF3B30',   // low / heart
  // activity ring hues (shared chroma, varied hue)
  ringMove: '#FF5A4D', // calories
  ringExer: '#5BD15B', // exercise minutes
  ringMet:  '#2A8FE0', // MET
  teal:  '#1FB8C9',
  violet:'#8E72E8',
};

const TARGET_LOW = 70;
const TARGET_HIGH = 180;

function glucoseStatus(mgdl) {
  if (mgdl < TARGET_LOW) return { label: 'Low', color: TOKENS.red };
  if (mgdl > TARGET_HIGH) return { label: 'High', color: TOKENS.amber };
  return { label: 'In Range', color: TOKENS.green };
}

// Build a realistic Type-1 glucose curve across the day (mg/dL).
// 5-min cadence → 288 pts. Key beats: dawn rise, breakfast spike + correction,
// lunch, afternoon run causing a dip toward low, recovery, dinner spike, settle.
function buildGlucose() {
  const pts = [];
  const seg = (from, to, a, b, noise = 4) => {
    const n = to - from;
    for (let i = 0; i < n; i++) {
      const t = i / n;
      // smoothstep
      const s = t * t * (3 - 2 * t);
      const v = a + (b - a) * s + (Math.sin(i * 1.7) + Math.cos(i * 0.9)) * noise * 0.5;
      pts.push(Math.round(v));
    }
  };
  // index = minutes/5 ; 0 = 00:00
  seg(0, 36, 118, 104);     // 0–3h  overnight settle
  seg(36, 72, 104, 96);     // 3–6h  dawn dip
  seg(72, 84, 96, 132);     // 6–7h  dawn rise
  seg(84, 108, 132, 191);   // 7–9h  breakfast spike
  seg(108, 144, 191, 124);  // 9–12h correction
  seg(144, 168, 124, 168);  // 12–14h lunch
  seg(168, 192, 168, 138);  // 14–16h settle
  seg(192, 204, 138, 96);   // 16–17h run begins, drop
  seg(204, 216, 96, 68);    // 17–18h run low
  seg(216, 240, 68, 122);   // 18–20h carb recovery
  seg(240, 264, 122, 174);  // 20–22h dinner spike
  seg(264, 288, 174, 120);  // 22–24h settle
  return pts;
}

const GLUCOSE = buildGlucose();
const CURRENT_IDX = 210; // ~17:30, just after the run dip recovering
const CURRENT = GLUCOSE[CURRENT_IDX];

// time-in-range for today
function computeTIR(arr) {
  let low = 0, inr = 0, high = 0;
  arr.forEach(v => {
    if (v < TARGET_LOW) low++;
    else if (v > TARGET_HIGH) high++;
    else inr++;
  });
  const n = arr.length;
  return {
    low: Math.round((low / n) * 100),
    inRange: Math.round((inr / n) * 100),
    high: Math.round((high / n) * 100),
  };
}

const DATA = {
  TARGET_LOW, TARGET_HIGH,
  glucose: GLUCOSE,
  currentIdx: CURRENT_IDX,
  current: CURRENT,
  currentTrend: -2, // mg/dL per 5 min → falling slowly
  avg: Math.round(GLUCOSE.reduce((a, b) => a + b, 0) / GLUCOSE.length),
  tir: computeTIR(GLUCOSE),
  rings: {
    move:  { value: 540, goal: 620, unit: 'KCAL' },
    exer:  { value: 42,  goal: 45,  unit: 'MIN' },
    met:   { value: 486, goal: 500, unit: 'MET·MIN' },
  },
  steps: 8432,
  stepsGoal: 10000,
  // MET-min accumulated by 2h bucket
  metByHour: [0, 0, 0, 12, 64, 28, 18, 30, 196, 84, 38, 16],
  heart: {
    current: 64,
    resting: 58,
    range: [52, 158],
    // bpm over day sampled (range band low/high per bucket)
    series: [58,57,56,58,72,88,76,70,74,150,96,74],
  },
  workouts: [
    { name: 'Outdoor Run', time: '4:08 PM', dur: '32 min', dist: '5.2 km',
      kcal: 348, avgMet: 9.1, hr: 152, glucoseDelta: -38 },
    { name: 'Walk', time: '8:12 AM', dur: '18 min', dist: '1.4 km',
      kcal: 72, avgMet: 3.2, hr: 104, glucoseDelta: -9 },
  ],
  nutrition: {
    carbs: 168, carbsGoal: 200, insulinUnits: 24,
    meals: [
      { name: 'Breakfast', carbs: 62, time: '7:30 AM' },
      { name: 'Lunch',     carbs: 48, time: '12:15 PM' },
      { name: 'Snack',     carbs: 22, time: '5:55 PM' },
      { name: 'Dinner',    carbs: 36, time: '8:00 PM' },
    ],
  },
  // 14-day time-in-range trend (% in range)
  tirTrend: [71, 68, 74, 80, 77, 82, 79, 73, 85, 88, 81, 84, 90, 86],
  // glucose vs activity correlation scatter (metMin, tirPct)
  corr: [
    [120, 64], [180, 70], [240, 72], [300, 78], [360, 80],
    [420, 83], [486, 86], [540, 88], [200, 68], [330, 76],
  ],
};

function fmtGlucose(mgdl, mmol) {
  return mmol ? (mgdl / 18).toFixed(1) : String(Math.round(mgdl));
}

// ── Sport catalog (MET intensity used across Workouts + Plan) ─
const SPORTS = [
  { id: 'walk',     name: 'Walk',         met: 3.2,  icon: 'shoe',     difficulty: 'Light', color: '#1F8A5B',
    desc: 'An easy walk. Low hypo risk, gentle on glucose across the session.' },
  { id: 'run',      name: 'Outdoor Run',  met: 9.1,  icon: 'run',      difficulty: 'Vigorous', color: '#E0556E',
    desc: 'A steady outdoor run. Expect a fast glucose drop — fuel up beforehand.' },
  { id: 'cycling',  name: 'Cycling',      met: 7.0,  icon: 'bolt',     difficulty: 'Moderate', color: '#E8833A',
    desc: 'Sustained cycling effort. Plan a top-up if you ride past 45 minutes.' },
  { id: 'swim',     name: 'Swimming',     met: 8.0,  icon: 'drop',     difficulty: 'Vigorous', color: '#1FB8C9',
    desc: 'Full-body swim session. Glucose can dip fast — carb up beforehand.' },
  { id: 'strength', name: 'Strength',     met: 5.0,  icon: 'flame',    difficulty: 'Moderate', color: '#8E72E8',
    desc: 'Resistance training. Effects on glucose are slower and can extend post-session.' },
  { id: 'hiit',     name: 'HIIT',         met: 10.0, icon: 'activity', difficulty: 'Vigorous', color: '#D6484B',
    desc: 'High-intensity intervals. Sharp swings possible — monitor closely.' },
];

// Build a plausible pre/during/post glucose curve for a single workout,
// used by the Workouts tab detail overlay. 5-min cadence.
// preMin/postMin default cover 30 min before / 60 min after.
function buildWorkoutCurve(baseline, durMin, delta, preMin = 30, postMin = 60) {
  const pts = [];
  const step = 5;
  const seg = (n, a, b, noise = 3) => {
    for (let i = 0; i < n; i++) {
      const t = i / Math.max(1, n - 1);
      const s = t * t * (3 - 2 * t);
      pts.push(Math.round(a + (b - a) * s + Math.sin(i * 1.3) * noise));
    }
  };
  const preN = Math.round(preMin / step);
  const durN = Math.max(2, Math.round(durMin / step));
  const postN = Math.round(postMin / step);
  const low = baseline + delta;
  seg(preN, baseline - 4, baseline);          // lead-in, roughly flat
  seg(durN, baseline, low);                    // during activity → delta applied
  seg(postN, low, low + Math.abs(delta) * 0.55); // partial recovery after
  return { curve: pts, activityStart: preN, activityEnd: preN + durN };
}

function weekLabel(weeksAgo) {
  if (weeksAgo === 0) return 'This Week';
  if (weeksAgo === 1) return 'Last Week';
  return `${weeksAgo} Weeks Ago`;
}

function buildWorkoutHistory() {
  // deterministic pseudo-random so the list looks varied but stable across renders
  let seed = 42;
  const rnd = () => { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return (seed % 1000) / 1000; };

  const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  const weeks = [];
  let idCounter = 0;

  for (let w = 0; w < 6; w++) {
    const count = w === 0 ? 2 : 2 + Math.floor(rnd() * 2); // this week matches today's 2 logged workouts
    const workouts = [];
    for (let i = 0; i < count; i++) {
      let sport, durMin, delta, baseline, time, dayLabel;
      if (w === 0 && i === 0) {
        sport = SPORTS[0]; durMin = 32; delta = -38; baseline = 138; time = '4:08 PM'; dayLabel = 'Fri, Jun 19';
      } else if (w === 0 && i === 1) {
        sport = SPORTS[1]; durMin = 18; delta = -9; baseline = 105; time = '8:12 AM'; dayLabel = 'Fri, Jun 19';
      } else {
        sport = SPORTS[Math.floor(rnd() * SPORTS.length)];
        durMin = [20, 30, 40, 45, 60][Math.floor(rnd() * 5)];
        const intensity = sport.met >= 8 ? 1 : sport.met >= 5 ? 0.65 : 0.35;
        delta = -Math.round((8 + rnd() * 30) * intensity);
        baseline = 110 + Math.round(rnd() * 60);
        const hr = 6 + Math.floor(rnd() * 13);
        const min = Math.floor(rnd() * 60);
        const ampm = hr >= 12 ? 'PM' : 'AM';
        const h12 = hr % 12 === 0 ? 12 : hr % 12;
        time = `${h12}:${String(min).padStart(2, '0')} ${ampm}`;
        dayLabel = `${days[Math.floor(rnd() * 7)]}, ${['Jun', 'Jul'][w > 3 ? 0 : 0]} ${Math.max(1, 19 - w * 7 - Math.floor(rnd() * 7))}`;
      }
      const { curve, activityStart, activityEnd } = buildWorkoutCurve(baseline, durMin, delta);
      const dist = sport.id === 'run' ? (3 + rnd() * 4).toFixed(1) + ' km'
        : sport.id === 'walk' ? (1 + rnd() * 2).toFixed(1) + ' km'
        : sport.id === 'cycling' ? (8 + rnd() * 12).toFixed(1) + ' km'
        : sport.id === 'swim' ? (0.5 + rnd() * 1.2).toFixed(1) + ' km' : null;
      const kcal = Math.round(sport.met * durMin * 1.1);
      const hrAvg = Math.round(90 + sport.met * 7);
      const insight = delta < -25
        ? `This ${sport.name.toLowerCase()} lowered glucose by ${Math.abs(delta)} mg/dL over ${durMin} min — consider ${Math.round(Math.abs(delta) * 0.4)}g carbs before similar sessions.`
        : delta < -12
        ? `Moderate drop of ${Math.abs(delta)} mg/dL during this session — a small snack beforehand can help keep you in range.`
        : `Glucose stayed steady, dropping only ${Math.abs(delta)} mg/dL — low risk activity at this intensity.`;
      workouts.push({
        id: 'w' + (idCounter++), name: sport.name, sportId: sport.id, icon: sport.icon,
        day: dayLabel, time, dur: `${durMin} min`, durMin, dist: dist || '—',
        kcal, avgMet: sport.met, hr: hrAvg, glucoseDelta: delta,
        curve, activityStart, activityEnd, baseline, insight,
      });
    }
    weeks.push({ label: weekLabel(w), workouts });
  }
  return weeks;
}

// ── Carb planning heuristic (Plan tab) ─────────────────────────
// sportId: SPORTS id | durationMin: number | iob: units on board | recentCarbsG: carbs eaten last 2h
function computeCarbPlan({ sportId, durationMin, iob, recentCarbsG }) {
  const sport = SPORTS.find(s => s.id === sportId) || SPORTS[0];
  const met = sport.met;
  const intensity = met >= 8 ? 'high' : met >= 5 ? 'moderate' : 'low';
  const intensityFactor = intensity === 'high' ? 0.62 : intensity === 'moderate' ? 0.4 : 0.2;

  // baseline grams scale with duration & intensity
  let pre = intensityFactor * durationMin * 0.55;
  // active insulin drives glucose down further during exercise — add buffer
  pre += iob * 7;
  // recent carbs already provide some buffer, offset partially
  pre -= recentCarbsG * 0.18;
  pre = Math.max(0, Math.round(pre / 5) * 5);

  // during-session top-ups only needed for longer / harder sessions
  const needsDuring = durationMin > 45 || (durationMin > 30 && intensity !== 'low');
  const duringPer30 = needsDuring ? Math.max(5, Math.round(pre * 0.35 / 5) * 5) : 0;

  let risk = 'Low';
  if (iob > 1.2 && intensity !== 'low') risk = 'High';
  else if (iob > 0.5 || intensity === 'high') risk = 'Moderate';

  return { pre, duringPer30, needsDuring, risk, intensity, met, sport };
}

// Workout history, grouped by week, most recent first — attached after
// SPORTS/buildWorkoutCurve are defined above.
DATA.workoutHistory = buildWorkoutHistory();

Object.assign(window, {
  TOKENS, glucoseStatus, DATA, fmtGlucose, TARGET_LOW, TARGET_HIGH,
  SPORTS, computeCarbPlan, buildWorkoutCurve,
});

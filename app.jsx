// app.jsx — OneMET prototype root: phone frame, tab state (Plan is 2nd), slide-over overlays.
function App() {
  const accent = '#2A6FDB';
  const [tab, setTab] = React.useState('summary');
  const [showGlucose, setShowGlucose] = React.useState(false);
  const [openWorkout, setOpenWorkout] = React.useState(null);
  const mmol = false;

  let screen;
  if (tab === 'summary') screen = <SummaryScreen accent={accent} mmol={mmol} onOpenGlucose={() => setShowGlucose(true)} onGoActivity={() => setTab('workouts')} />;
  else if (tab === 'plan') screen = <PlanScreen accent={accent} />;
  else if (tab === 'workouts') screen = <WorkoutsScreen accent={accent} onOpenWorkout={setOpenWorkout} />;
  else screen = <ProfileScreen accent={accent} />;

  const changeTab = (t) => { setShowGlucose(false); setOpenWorkout(null); setTab(t); };

  return (
    <div className="screen">
      {screen}
      <TabBar active={tab} onChange={changeTab} accent={accent} />
      {showGlucose && <div className="overlay"><GlucoseDetail accent={accent} mmol={mmol} onBack={() => setShowGlucose(false)} /></div>}
      {openWorkout && <div className="overlay"><WorkoutDetailScreen workout={openWorkout} accent={accent} onBack={() => setOpenWorkout(null)} /></div>}
    </div>
  );
}
ReactDOM.createRoot(document.getElementById('root')).render(<App />);

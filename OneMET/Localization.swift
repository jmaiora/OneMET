import Foundation
import SwiftUI

// Localization.swift — in-app language switching.
//
// Deliberately NOT Apple's .lproj/Localizable.strings mechanism: that follows the system
// language and can't be changed from inside the app without a relaunch (or bundle
// swizzling). OneMET lets you pick the language in Settings and see it apply instantly,
// so strings live in a table keyed by a dotted id and looked up through the observed
// LocalizationStore — changing `language` republishes and the whole tree re-renders.
//
// Adding a language = adding a field to LocalizedText and a value to every row.

enum AppLanguage: String, CaseIterable, Codable, Identifiable, Hashable {
    case en, es

    var id: String { rawValue }

    /// Shown in the language picker — always in that language, never translated.
    var nativeName: String {
        switch self {
        case .en: return "English"
        case .es: return "Español"
        }
    }

    /// Locale used for dates and number formatting while this language is active.
    /// en_US rather than en_GB so English keeps the 12-hour clock and "Fri, Jun 19"
    /// date style the app shipped with; Spanish gets 24-hour and "vie, 19 jun".
    var locale: Locale {
        switch self {
        case .en: return Locale(identifier: "en_US")
        case .es: return Locale(identifier: "es_ES")
        }
    }

    /// Best match for the phone's language, used to preselect the welcome screen.
    static var systemDefault: AppLanguage {
        let code = Locale.preferredLanguages.first?.prefix(2).lowercased() ?? "en"
        return AppLanguage(rawValue: code) ?? .en
    }

    /// Look up a string, filling in any {0}, {1}, … placeholders. Arguments are
    /// pre-formatted strings so the caller keeps control of units and decimals.
    ///
    /// One variadic function rather than a pair of overloads: `t("key")` would be
    /// ambiguous between a no-arg and a variadic version.
    func t(_ key: String, _ args: String...) -> String {
        guard let row = Strings.table[key] else {
            assertionFailure("Missing localization key: \(key)")
            return key
        }
        var out = (self == .es) ? row.es : row.en
        for (i, a) in args.enumerated() {
            out = out.replacingOccurrences(of: "{\(i)}", with: a)
        }
        return out
    }
}

// MARK: - Store

@MainActor
final class LocalizationStore: ObservableObject {
    @Published var language: AppLanguage { didSet { save() } }
    /// False until the welcome screen has been completed once.
    @Published var hasOnboarded: Bool { didSet { save() } }

    private let langKey = "onemet.language.v1"
    private let onboardedKey = "onemet.hasOnboarded.v1"

    init() {
        let saved = UserDefaults.standard.string(forKey: langKey)
        language = saved.flatMap(AppLanguage.init(rawValue:)) ?? .systemDefault
        hasOnboarded = UserDefaults.standard.bool(forKey: onboardedKey)
    }

    private func save() {
        UserDefaults.standard.set(language.rawValue, forKey: langKey)
        UserDefaults.standard.set(hasOnboarded, forKey: onboardedKey)
    }

    /// Shorthand so views can read `loc.t("key")` without reaching for `.language`.
    func t(_ key: String, _ args: String...) -> String {
        var out = language.t(key)
        for (i, a) in args.enumerated() {
            out = out.replacingOccurrences(of: "{\(i)}", with: a)
        }
        return out
    }
}

// MARK: - Table

struct LocalizedText {
    let en: String
    let es: String
}

private func L(_ en: String, _ es: String) -> LocalizedText { LocalizedText(en: en, es: es) }

enum Strings {
    // Placeholders are {0}, {1}, … rather than %@ so the order is explicit and a
    // translation can reorder them freely without changing the call site.
    //
    // Split across several dictionaries and merged: Swift's type-checker gets very slow
    // on a single literal this size, and a chunked build is near-instant.
    static let table: [String: LocalizedText] = {
        var t = chrome
        for d in [charts, workouts, plan, insights, settings] { t.merge(d) { a, _ in a } }
        return t
    }()

    private static let chrome: [String: LocalizedText] = [

        // ── Tabs ──
        "tab.summary":  L("Summary", "Resumen"),
        "tab.workouts": L("Workouts", "Ejercicio"),
        "tab.plan":     L("Plan", "Plan"),
        "tab.settings": L("Settings", "Ajustes"),

        // ── Welcome ──
        "welcome.title":       L("Welcome to OneMET", "Bienvenido a OneMET"),
        // One line, deliberately. The opening screen states what the app is and then gets
        // out of the way; the explanations it used to carry live in Help & FAQ.
        "welcome.subtitle":    L("Glucose and activity, side by side",
                                 "Integrando glucosa y actividad"),
        "welcome.language":    L("Language", "Idioma"),
        "welcome.units":       L("Glucose units", "Unidades de glucosa"),
        "welcome.sources":     L("Glucose source", "Fuente de glucosa"),
        "welcome.sourcesNote": L("Optional. Without one, OneMET reads glucose from Apple Health. You can connect or change this any time in Settings.",
                                 "Opcional. Sin ninguna, OneMET lee la glucosa de Apple Salud. Puedes conectarla o cambiarla cuando quieras en Ajustes."),
        "welcome.connect":     L("Connect", "Conectar"),
        "welcome.connected":   L("Connected", "Conectado"),
        "src.nsSubtitle":      L("Your own server · full history", "Tu propio servidor · historial completo"),
        "src.dexSubtitle":     L("Share / Follow · last 24 h", "Share / Follow · últimas 24 h"),
        "src.libreSubtitle":   L("Follower account · last 12 h", "Cuenta seguidora · últimas 12 h"),
        // ── Welcome: about you ──
        // Prompts only. The notes that used to sit under each control were removed at the
        // user's request; the scope statement they carried is in help.scopeBody, and the
        // Plan tab still refuses to compute for anyone outside it.
        "welcome.namePrompt":  L("What should we call you?", "¿Cómo quieres que te llamemos?"),
        "welcome.namePlace":   L("Your name", "Tu nombre"),
        "welcome.weightPrompt": L("Your weight", "Tu peso"),
        "welcome.typePrompt":  L("Which type of diabetes?", "¿Qué tipo de diabetes?"),
        "welcome.insulinPrompt": L("How do you take insulin?", "¿Cómo te administras la insulina?"),

        // ── Welcome: Apple Health ──
        "welcome.healthTitle": L("Apple Health", "Apple Salud"),
        "welcome.healthLead":  L("OneMET reads your workouts, heart rate and activity from Apple Health, and uses them to line your sessions up against your glucose.",
                                 "OneMET lee tus entrenamientos, tu frecuencia cardiaca y tu actividad de Apple Salud, y los cruza con tu glucosa."),
        "welcome.healthNote":  L("Read-only, apart from workouts OneMET writes back. iOS will ask you which categories to allow — Workouts is the one that matters most.",
                                 "Solo lectura, salvo los entrenamientos que OneMET escribe. iOS te preguntará qué categorías permitir: Entrenamientos es la más importante."),
        "welcome.healthAllow": L("Allow access", "Permitir acceso"),
        "welcome.healthDone":  L("Access requested", "Acceso solicitado"),
        "welcome.healthSkip":  L("Health data isn't available on this device.",
                                 "Los datos de Salud no están disponibles en este dispositivo."),

        // ── Welcome: navigation ──
        "welcome.next":        L("Next", "Siguiente"),
        "welcome.back":        L("Back", "Atrás"),
        "welcome.skip":        L("Skip", "Omitir"),
        "welcome.step":        L("Step {0} of {1}", "Paso {0} de {1}"),
        "welcome.start":       L("Get started", "Empezar"),
        "welcome.disclaimer":  L("OneMET offers illustrative guidance, not medical advice.",
                                 "OneMET ofrece orientación ilustrativa, no consejo médico."),

        // ── Common ──
        "common.cancel":   L("Cancel", "Cancelar"),
        "common.done":     L("Done", "Listo"),
        "common.save":     L("Save", "Guardar"),
        "common.now":      L("Now", "Ahora"),
        "common.updating": L("Updating…", "Actualizando…"),
        "common.notSet":   L("Not set", "Sin configurar"),
        "common.none":     L("—", "—"),
        "common.preview":  L("Preview", "Vista previa"),

        // ── Summary ──
        "summary.title":          L("Summary", "Resumen"),
        "summary.glucose":        L("Glucose", "Glucosa"),
        "summary.timeInRange":    L("TIME IN RANGE", "TIEMPO EN RANGO"),
        "summary.low":            L("Low", "Baja"),
        "summary.inRange":        L("In Range", "En rango"),
        "summary.high":           L("High", "Alta"),
        "summary.activityInsight": L("ACTIVITY INSIGHT", "ANÁLISIS DE ACTIVIDAD"),
        "summary.beforeWorkout":  L("Before workout", "Antes de entrenar"),
        "summary.beforeNote":     L("Illustrative guidance, not medical advice. See the Plan tab for a session-specific start decision.",
                                    "Orientación ilustrativa, no consejo médico. Consulta la pestaña Plan para una decisión de inicio concreta."),
        "summary.activity":       L("Activity", "Actividad"),
        "summary.move":           L("Move", "Movimiento"),
        "summary.exercise":       L("Exercise", "Ejercicio"),
        "summary.met":            L("MET", "MET"),
        "summary.metMin":         L("MET·min", "MET·min"),
        "summary.last7":          L("Last 7 days", "Últimos 7 días"),
        "summary.metToday":       L("MET·min today", "MET·min hoy"),
        "summary.carbsInsulin":   L("Carbs & Insulin", "Carbohidratos e insulina"),
        "summary.carbs":          L("Carbs", "Carbohidratos"),
        "summary.insulin":        L("Insulin", "Insulina"),
        "summary.goal":           L("Goal", "Objetivo"),
        // States the day rather than issuing an instruction: the button underneath is what
        // tells you what to do now.
        "summary.aidBefore":      L("If you use a closed-loop system, set it to manual mode before and during the activity to take advantage of the app's recommendations.",
                                    "Si usas un sistema de asa cerrada, ponlo en modo manual antes y durante la actividad para aprovechar las recomendaciones de la app."),
        "summary.noWorkoutYet":   L("No activity recorded yet today.",
                                    "Aún no hay actividad registrada hoy."),
        // The banner's call to action into the Plan tab: a bold prompt over a quieter line
        // that keeps it honest — tapping opens the plan, it doesn't start a workout.
        // Two wordings for the two states. The empty day gets the invitation; a day with a
        // session already behind it gets a plainer label, because pushing someone towards
        // a second session is not something the app should do on its own. The Spanish keeps
        // the verb but not the exclamation mark: that was where the haranguing tone lived.
        "summary.chooseActivity":    L("Get active", "Actívate"),
        "summary.chooseActivitySub": L("Plan today's session", "Planifica la sesión de hoy"),
        "summary.planAnother":       L("Plan another session", "Planifica otra sesión"),
        "summary.planAnotherSub":    L("Carbs and timing for the next one",
                                       "Carbohidratos y tiempos para la siguiente"),

        // ── Glucose status ──
        "glucose.low":     L("Low", "Baja"),
        "glucose.inRange": L("In Range", "En rango"),
        "glucose.high":    L("High", "Alta"),
        "glucose.falling": L("falling", "bajando"),
        "glucose.rising":  L("rising", "subiendo"),
        "glucose.steady":  L("steady", "estable"),

        // ── Glucose detail ──
        "glucoseDetail.today":       L("Today", "Hoy"),
        "glucoseDetail.average":     L("Average", "Media"),
        "glucoseDetail.timeInRange": L("Time in Range", "Tiempo en rango"),
        "glucoseDetail.lowest":      L("Lowest", "Mínima"),
        "glucoseDetail.highest":     L("Highest", "Máxima"),
        "glucoseDetail.stdDev":      L("Std. Dev", "Desv. típica"),
        "glucoseDetail.gmi":         L("GMI", "GMI"),
        "glucoseDetail.distribution": L("RANGE DISTRIBUTION", "DISTRIBUCIÓN POR RANGO"),
        "glucoseDetail.events":      L("Events", "Eventos"),

    ]

    private static let charts: [String: LocalizedText] = [

        // ── Chart labels ──
        "chart.run":          L("RUN", "SESIÓN"),
        "chart.before":       L("Before", "Antes"),
        "chart.activity":     L("Activity", "Actividad"),
        "chart.after":        L("After", "Después"),
        "chart.goal70":       L("70% goal", "objetivo 70%"),
        "chart.avgWorkoutMet": L("Avg workout MET →", "MET medio de la sesión →"),
        "chart.today":        L("Today", "Hoy"),
        "chart.daysAgo":      L("{0}d", "{0}d"),

        // ── Meals ──
        "meal.breakfast": L("Breakfast", "Desayuno"),
        "meal.lunch":     L("Lunch", "Comida"),
        "meal.snack":     L("Snack", "Tentempié"),
        "meal.dinner":    L("Dinner", "Cena"),
        "meal.carbsLine": L("{0} · {1}g carbs", "{0} · {1} g de carbohidratos"),

    ]

    private static let workouts: [String: LocalizedText] = [

        // ── Workouts ──
        "workouts.title":        L("Workouts", "Ejercicio"),
        "workouts.history":      L("History", "Historial"),
        "workouts.noneShown":    L("No workouts shown", "No se muestran entrenamientos"),
        "workouts.noneYet":      L("No workouts logged yet. Sessions from Apple Health will appear here.",
                                   "Aún no hay entrenamientos. Las sesiones de Apple Salud aparecerán aquí."),
        "workouts.loadPast":     L("Load Past Weeks", "Cargar semanas anteriores"),
        "workouts.one":          L("{0} workout", "{0} entrenamiento"),
        "workouts.many":         L("{0} workouts", "{0} entrenamientos"),
        "workouts.metAvg":       L("{0} MET avg", "{0} MET medio"),
        "workouts.thisWeek":     L("This Week", "Esta semana"),
        "workouts.lastWeek":     L("Last Week", "Semana pasada"),
        "workouts.weeksAgo":     L("{0} Weeks Ago", "Hace {0} semanas"),
        "workouts.duration":     L("Duration", "Duración"),
        "workouts.distance":     L("Distance", "Distancia"),
        "workouts.calories":     L("Calories", "Calorías"),
        "workouts.avgMet":       L("Avg MET", "MET medio"),
        "workouts.avgHr":        L("Avg HR", "FC media"),
        "workouts.glucoseDelta": L("Glucose Δ", "Δ glucosa"),
        "workouts.noCgm":        L("No CGM data around this session.", "Sin datos de MCG en torno a esta sesión."),
        "workouts.min":          L("min", "min"),

        // ── Workout diagnostics ──
        "diag.readFailed":  L("Couldn't read workouts from Health: {0}", "No se pudieron leer los entrenamientos de Salud: {0}"),
        "diag.noneIn6w":    L("No workouts in the last 6 weeks.", "Ningún entrenamiento en las últimas 6 semanas."),
        "diag.noAccess":    L("No workouts visible. iOS updates can switch off Health access for apps — check Settings ▸ Privacy & Security ▸ Health ▸ OneMET and make sure Workouts is on.",
                              "No se ven entrenamientos. Las actualizaciones de iOS pueden desactivar el acceso a Salud — revisa Ajustes ▸ Privacidad y seguridad ▸ Salud ▸ OneMET y comprueba que Entrenamientos esté activado."),
        "diag.unavailable": L("Health data isn't available on this device.", "Los datos de Salud no están disponibles en este dispositivo."),
        "diag.authFailed":  L("HealthKit authorization failed: {0}", "Falló la autorización de HealthKit: {0}"),

        // ── Sport names ──
        "sport.walk":     L("Walk", "Caminar"),
        "sport.run":      L("Outdoor Run", "Carrera al aire libre"),
        "sport.cycling":  L("Cycling", "Ciclismo"),
        "sport.swim":     L("Swimming", "Natación"),
        "sport.strength": L("Strength", "Fuerza"),
        "sport.hiit":     L("HIIT", "HIIT"),
        "sport.hike":     L("Hike", "Senderismo"),
        "sport.yoga":     L("Yoga", "Yoga"),
        "sport.workout":  L("Workout", "Entrenamiento"),

        "sport.walk.desc":     L("An easy walk. Low hypo risk, gentle on glucose across the session.",
                                 "Un paseo tranquilo. Bajo riesgo de hipoglucemia y suave con la glucosa."),
        "sport.run.desc":      L("A steady outdoor run. Expect a fast glucose drop — fuel up beforehand.",
                                 "Carrera continua al aire libre. Espera una bajada rápida de glucosa: come algo antes."),
        "sport.cycling.desc":  L("Sustained cycling effort. Plan a top-up if you ride past 45 minutes.",
                                 "Esfuerzo sostenido en bici. Prevé un aporte extra si superas los 45 minutos."),
        "sport.swim.desc":     L("Full-body swim session. Glucose can dip fast — carb up beforehand.",
                                 "Sesión de natación de cuerpo entero. La glucosa puede caer rápido: toma carbohidratos antes."),
        "sport.strength.desc": L("Resistance training. Effects on glucose are slower and can extend post-session.",
                                 "Entrenamiento de fuerza. El efecto sobre la glucosa es más lento y puede prolongarse tras la sesión."),
        "sport.hiit.desc":     L("High-intensity intervals. Sharp swings possible — monitor closely.",
                                 "Intervalos de alta intensidad. Posibles oscilaciones bruscas: vigila de cerca."),

        // ── Difficulty ──
        "difficulty.light":    L("Light", "Suave"),
        "difficulty.moderate": L("Moderate", "Moderada"),
        "difficulty.vigorous": L("Vigorous", "Intensa"),
        "difficulty.maximal":  L("Maximal", "Máxima"),

    ]

    private static let plan: [String: LocalizedText] = [

        // ── Plan tab ──
        "plan.title":        L("Plan", "Plan"),
        "plan.exerciseGuide": L("Exercise Guide", "Guía de ejercicio"),
        "plan.sessionDetails": L("Session Details", "Detalles de la sesión"),
        "plan.plannedDuration": L("Planned Duration", "Duración prevista"),
        "plan.difficulty":   L("Difficulty", "Dificultad"),
        "plan.currentState": L("Current State", "Estado actual"),
        "plan.currentGlucose": L("Current Glucose", "Glucosa actual"),
        "plan.iob":          L("Insulin on Board", "Insulina activa"),
        "plan.during":       L("During · {0}", "Durante · {0}"),
        "plan.after":        L("After", "Después"),
        "plan.tlStart":      L("Start", "Inicio"),
        "plan.tlRefuel":     L("Refuel", "Toma"),
        "plan.tlFinish":     L("Finish", "Fin"),
        "plan.thresholds":   L("{0} · exercise target {1} · carbs during below {2}",
                               "{0} · objetivo de ejercicio {1} · carbohidratos durante por debajo de {2}"),
        "plan.excess":       L("You start {0} above {1} — about {2} g of glucose, roughly the first {3} min of fuel. The plan starts after that.",
                               "Empiezas {0} por encima de {1}: unos {2} g de glucosa, aproximadamente los primeros {3} min de combustible. El plan empieza después."),
        "plan.ifBelow":      L("if < {0}", "si < {0}"),
        "plan.carry":        L("Carry ~{0} g: {1} g for the plan + {2} g to correct a fast drop.",
                               "Lleva ~{0} g: {1} g del plan + {2} g para corregir una bajada rápida."),
        "plan.carryRescueOnly": L("Carry ~{0} g to correct a drop.", "Lleva ~{0} g para corregir una bajada."),
        "plan.weightDefault": L("Planned for 70 kg — set your weight in Settings ▸ Profile for a personal plan.",
                                "Calculado para 70 kg: indica tu peso en Ajustes ▸ Perfil para un plan personal."),
        "plan.afterLead":    L("For the 90 min after, aim for {0}. If you drop under {1}:",
                               "Durante los 90 min siguientes, intenta estar en {0}. Si bajas de {1}:"),
        "plan.afterNothing": L("nothing", "nada"),
        "plan.afterTreat":   L("treat as a low", "trátala como hipo"),
        "plan.afterNight":   L("Lows can come 6–15 h later. Set your CGM low alert to {0} tonight.",
                               "Las hipos pueden llegar 6–15 h después. Pon la alerta de baja del MCG en {0} esta noche."),
        "plan.afterBedtime": L("Exercised after 4 pm for 30 min or more? Under {0} at bedtime: ~{1} g of slow carbs, without a bolus. Under {2}: add ~15 g of protein.",
                               "¿Ejercicio después de las 16:00 y de 30 min o más? Si al acostarte estás por debajo de {0}: ~{1} g de carbohidratos lentos, sin bolo. Por debajo de {2}: añade ~15 g de proteína."),
        "plan.afterNoCorrection": L("Avoid correction insulin close to bedtime.", "Evita la insulina de corrección cerca de la hora de dormir."),
        "plan.afterSource":  L("EASD/ISPAD 2020 (Table 3) · ISPAD 2022", "EASD/ISPAD 2020 (tabla 3) · ISPAD 2022"),
        "risk.low":          L("Low risk", "Riesgo bajo"),
        "risk.moderate":     L("Moderate risk", "Riesgo moderado"),
        "risk.high":         L("High risk", "Riesgo alto"),
        "risk.auto":         L("Automatic", "Automático"),
        "plan.largeMoved":   L("{0} g moved to start.", "{0} g pasados al inicio."),
        "plan.largeOver":    L("Some intakes are over {0} g.", "Algunas tomas superan los {0} g."),
        "plan.largeIntake":  L("Consider updating intake interval and/or snack size.",
                               "Considera ajustar el intervalo entre tomas y/o el tamaño de cada toma."),
        "plan.adjustCgm":    L("Adjust with CGM values.", "Ajusta según los valores del MCG."),
        "plan.capSlider":    L("Max per intake", "Máximo por toma"),
        "plan.capValue":     L("Up to {0} g", "Hasta {0} g"),
        "plan.interval":     L("Intake interval", "Intervalo entre tomas"),
        "plan.intervalEvery": L("Every {0} min", "Cada {0} min"),
        "plan.perHourTotal": L("~{0} g/h · ~{1} g total", "~{0} g/h · ~{1} g en total"),
        "plan.goodToKnow":   L("Good to know", "Conviene saber"),
        // "Fuel" rather than "calculate carbs": the screen behind this leads with whether
        // to start at all, which on a low reading matters more than the grams — but
        // fuelling is still what most people are coming here for, so it has to be said.
        "plan.calculate":    L("Get my fuel plan", "Ver mi plan de carbohidratos"),
        "plan.carbPlan":     L("Your fuel plan", "Tu plan de carbohidratos"),
        // Restates the session the plan was built for: sport, minutes, MET.
        "plan.forSession":   L("{0} · {1} min · {2} MET", "{0} · {1} min · {2} MET"),
        // Shown in place of the fuel-plan button when the model doesn't apply.
        "plan.scopeTitle":   L("No carbohydrate plan for this profile",
                               "Sin plan de carbohidratos para este perfil"),
        "plan.scopeNoDiabetes": L("OneMET's fuelling plan is built for people using insulin. Without diabetes your body regulates glucose during exercise on its own, so there is no hypoglycaemia to plan around — what to eat becomes a performance question, and general sports-nutrition guidance answers it better than this app can.",
                                  "El plan de carbohidratos de OneMET está pensado para quienes usan insulina. Sin diabetes, tu cuerpo regula la glucosa durante el ejercicio por sí solo, así que no hay hipoglucemia que prevenir: qué comer pasa a ser una cuestión de rendimiento, y la nutrición deportiva general lo responde mejor que esta app."),
        "plan.scopeNoInsulin": L("OneMET's fuelling plan is built for people using insulin. On metformin, a GLP-1 agonist or an SGLT2 inhibitor the risk of exercise hypoglycaemia is low, and eating carbohydrate to prevent it would work against the glycaemic benefit that makes the exercise worth doing.",
                                 "El plan de carbohidratos de OneMET está pensado para quienes usan insulina. Con metformina, un agonista GLP-1 o un inhibidor SGLT2 el riesgo de hipoglucemia por ejercicio es bajo, y comer carbohidratos para prevenirla iría en contra del beneficio glucémico que hace que merezca la pena entrenar."),
        "plan.scopeChange":  L("If that changes, set it in Settings ▸ Profile ▸ Insulin Delivery and the plan will appear.",
                               "Si eso cambia, indícalo en Ajustes ▸ Perfil ▸ Administración de insulina y el plan aparecerá."),
        "plan.scopeRest":    L("Everything else still works: your MET·minutes, rings, glucose and session history are unaffected.",
                               "El resto sigue funcionando: tus MET·minutos, anillos, glucosa e historial de sesiones no cambian."),
        "plan.time":         L("TIME", "TIEMPO"),
        "plan.difficultyShort": L("DIFFICULTY", "DIFICULTAD"),
        "plan.disclaimer":   L("Illustrative guidance, not medical advice. Insulin changes and carbohydrate decisions should be agreed with your clinician.",
                               "Orientación ilustrativa, no consejo médico. Los cambios de insulina y las decisiones sobre carbohidratos deben acordarse con tu equipo médico."),
        "plan.sources":      L("  Sources: EASD/ISPAD 2020 position statement on exercise with CGM (Moser, Riddell et al., Diabetologia 2020;63:2501–20) and ISPAD 2022 exercise guidelines (Adolfsson et al., Pediatr Diabetes 2022;23:1341–72). Both are expert consensus (evidence level D) — a starting point to personalise. Their tables weren't written for hybrid closed-loop pumps, which usually need less carbohydrate.",
                               "  Fuentes: declaración de posición EASD/ISPAD 2020 sobre ejercicio con MCG (Moser, Riddell et al., Diabetologia 2020;63:2501–20) y guías ISPAD 2022 de ejercicio (Adolfsson et al., Pediatr Diabetes 2022;23:1341–72). Ambas son consenso de expertos (nivel de evidencia D): un punto de partida para personalizar. Sus tablas no se escribieron para bombas de asa cerrada híbrida, que suelen necesitar menos carbohidratos."),

        // ── Plan: duration bands ──
        "band.easy":           L("Easy", "Suave"),
        "band.easy.detail":    L("Under 45 min · small top-up", "Menos de 45 min · pequeño aporte"),
        "band.moderate":       L("Moderate", "Moderada"),
        "band.moderate.detail": L("45–90 min · fuel as needed", "45–90 min · toma carbohidratos si hace falta"),
        "band.long":           L("Long", "Larga"),
        "band.anaerobic.detail": L("Intense / resistance · glucose may rise", "Intensa / fuerza · la glucosa puede subir"),
        "band.long.detail":    L("Over 90 min · fuel for performance", "Más de 90 min · come para rendir"),

        // ── Plan: before-workout strategy ──
        "before.pump": L("Ease insulin ahead — a basal cut 60–90 min before, or a smaller bolus if you ate recently.",
                         "Ajusta la insulina antes: reduce la basal 60–90 min antes, o pon un bolo menor si has comido hace poco."),
        "before.mdi":  L("Prevent, don’t treat: your lever is a smaller meal bolus if you ate within ~2–3 h. Start near {0}, carry fast carbs.",
                         "Prevenir, no corregir: tu herramienta es un bolo de comida más pequeño si has comido en las últimas 2–3 h. Empieza cerca de {0} y lleva carbohidratos rápidos."),

        // ── Plan: start decision (EASD/ISPAD 2020 Table 1) ──
        "start.unknown.title":  L("Check your glucose first", "Comprueba tu glucosa primero"),
        "start.unknown.reason": L("No live CGM / Nightscout reading — head out only when you can see your glucose and trend.",
                                  "Sin lectura en directo de MCG o Nightscout: sal solo cuando puedas ver tu glucosa y su tendencia."),
        "start.go.title":       L("Good to start", "Puedes empezar"),
        "start.go.reason":      L("{0} is in your exercise target ({1}) — head out.",
                                  "{0} está en tu objetivo de ejercicio ({1}): adelante."),
        "start.high.reason":    L("{0} is above your exercise target ({1}), so there's nothing to take before you start.",
                                  "{0} está por encima de tu objetivo de ejercicio ({1}): no hace falta tomar nada antes de empezar."),
        "start.highRising.reason": L("{0} and rising. Aerobic work tends to bring it down; intense or resistance work can push it higher — if you correct, be cautious and follow your clinician's plan.",
                                     "{0} y subiendo. El ejercicio aeróbico suele bajarla; el intenso o de fuerza puede subirla más. Si corriges, hazlo con prudencia y según el plan de tu equipo médico."),
        "start.topUp.title":    L("Take ~{0} g, then start", "Toma ~{0} g y empieza"),
        "start.targetFalling.reason": L("{0} is in target but falling — ~{1} g before you start heads off an early drop.",
                                        "{0} está en objetivo pero bajando: ~{1} g antes de empezar evitan una bajada temprana."),
        "start.low.reason":     L("{0} is below your exercise target ({1}). Take ~{2} g and start.",
                                  "{0} está por debajo de tu objetivo de ejercicio ({1}). Toma ~{2} g y empieza."),
        "start.lowRising.reason": L("{0} is below target but rising, and this kind of exercise tends to raise glucose — you can start.",
                                    "{0} está por debajo del objetivo pero subiendo, y este tipo de ejercicio suele subir la glucosa: puedes empezar."),
        "start.wait.title":     L("Take ~{0} g and wait", "Toma ~{0} g y espera"),
        "start.wait.reason":    L("{0} is too low to start safely. Take ~{1} g and wait until {2}.",
                                  "{0} es demasiado bajo para empezar con seguridad. Toma ~{1} g y espera hasta que {2}."),
        "start.until90":        L("you're at least {0} with a steady or rising arrow",
                                  "estés al menos en {0} con la flecha estable o subiendo"),
        "start.untilRising":    L("your arrow is rising quickly", "la flecha suba rápido"),
        "start.treat.title":    L("Treat as a low and wait", "Trátala como una hipo y espera"),
        "start.treat.reason":   L("{0} and falling fast. Treat it as a low — the amount is individual — and wait until {1}.",
                                  "{0} y bajando rápido. Trátala como una hipoglucemia (la cantidad es individual) y espera hasta que {1}."),
        "start.stop.title":     L("Treat first — don't start", "Trata primero: no empieces"),
        "start.stop.reason":    L("You're low ({0}). Treat it, and wait until {1}.",
                                  "Estás en hipoglucemia ({0}). Trátala y espera hasta que {1}."),
        "start.ketones.title":  L("Check ketones first", "Comprueba las cetonas primero"),
        "start.ketones.reason": L("{0} is very high. Check blood ketones: with a reading above 1.5, don't exercise. Below that you can start — any correction should be cautious and agreed with your clinician.",
                                  "{0} es muy alto. Mide cetonas en sangre: con una lectura por encima de 1,5, no hagas ejercicio. Por debajo puedes empezar; cualquier corrección debe ser prudente y acordada con tu equipo médico."),
        "start.ketones.reasonRise": L("{0} is very high. Check blood ketones: with a reading above 1.5, don't exercise. Below that, choose gentle aerobic exercise — intense or resistance work can push glucose higher.",
                                      "{0} es muy alto. Mide cetonas en sangre: con una lectura por encima de 1,5, no hagas ejercicio. Por debajo, elige ejercicio aeróbico suave: el intenso o de fuerza puede subir más la glucosa."),

        // ── Plan: during ──
        "during.none": L("Short enough that nothing is planned. Take carbs only if you drop below {0}.",
                         "Lo bastante corta para no prever tomas. Toma carbohidratos solo si bajas de {0}."),
        "during.resistance": L("Strength work lowers glucose much less than cardio and can even raise it, so nothing is planned. Take carbs only if you drop below {0}.",
                               "El trabajo de fuerza baja la glucosa mucho menos que el cardio e incluso puede subirla, así que no se prevén tomas. Toma carbohidratos solo si bajas de {0}."),
        "during.interval": L("High-intensity intervals lower glucose less than steady cardio and can push it up, so nothing is planned. Take carbs only if you drop below {0}.",
                             "Los intervalos de alta intensidad bajan la glucosa menos que el cardio continuo y pueden subirla, así que no se prevén tomas. Toma carbohidratos solo si bajas de {0}."),

        // ── Plan: philosophy ──
        "philosophy": L("Most PwD feel best around {0} during exercise. Avoiding lows matters more than perfect numbers — chasing {1} usually means repeated gels and rebound highs.",
                        "La mayoría de personas con diabetes prefieren estar en torno a {0} durante el ejercicio. Evitar hipoglucemias importa más que un número perfecto: perseguir {1} suele acabar en geles repetidos y rebotes altos."),
        "learn":      L("Learn your own response: note your start glucose, insulin on board, any carbs, and your end glucose. After 3–5 similar runs you'll usually settle on a repeatable strategy.",
                        "Aprende tu propia respuesta: anota la glucosa de inicio, la insulina activa, los carbohidratos y la glucosa final. Tras 3–5 sesiones parecidas darás con una estrategia repetible."),
        // The one-liners the Plan tab shows; the full versions live in Help & FAQ.
        "philosophy.short": L("Most PwD feel best around {0} before exercise.",
                              "La mayoría de personas con diabetes prefieren estar en torno a {0} antes del ejercicio."),
        "learn.short":      L("Find your own pattern, learn your own response.",
                              "Encuentra tu propio patrón, aprende tu propia respuesta."),

    ]

    private static let insights: [String: LocalizedText] = [

        // ── Workout insights ──
        "insight.dropNoCarbs": L("This {0} lowered glucose by {1} over {2} min, but you never went below {3} — no extra carbs needed for sessions like this.",
                                 "Este {0} bajó la glucosa {1} en {2} min, pero no bajaste de {3}: no necesitas carbohidratos extra en sesiones así."),
        // "adding", not a bare "consider N g": the reading is retrospective, so the person
        // may well have eaten already, possibly the full amount the Plan tab suggested.
        // The figure is an increment on whatever they did, not a total.
        "insight.dropCarbs":   L("This {0} lowered glucose by {1} over {2} min, down to {3} — consider adding {4} g of carbs {5}.",
                                 "Este {0} bajó la glucosa {1} en {2} min, hasta {3}: plantéate añadir {4} g de carbohidratos {5}."),
        // Where the extra carbohydrate belongs — see carbTimingKey. A session that began
        // high can't be pre-fuelled, and a short one has no mid-session feed to add to.
        "timing.before":       L("before similar sessions", "antes de sesiones parecidas"),
        "timing.during":       L("during similar sessions", "durante sesiones parecidas"),
        "timing.both":         L("before and during similar sessions",
                                 "antes y durante sesiones parecidas"),
        "timing.carry":        L("to carry with you and take as soon as it starts to fall",
                                 "para llevar encima y tomar en cuanto empiece a bajar"),
        // Timing-neutral: a moderate drop can be met before or during depending on how the
        // session started, and naming one would sometimes be wrong.
        "insight.dropModerate": L("Moderate drop of {0} during this session — a small additional snack can help keep you in range.",
                                  "Bajada moderada de {0} durante la sesión: un pequeño tentempié puede ayudarte a mantenerte en rango."),
        "insight.riseBig":     L("This {0} raised glucose by {1} over {2} min — common with short, intense or anaerobic efforts.",
                                 "Este {0} subió la glucosa {1} en {2} min: es habitual en esfuerzos cortos, intensos o anaeróbicos."),
        "insight.riseAnaerobic": L("This {0} raised glucose by {1} over {2} min — an expected response to intense or resistance work. If you correct, be conservative, and watch for a delayed low tonight.",
                                   "Esta sesión de {0} subió la glucosa {1} en {2} min, una respuesta esperable al trabajo intenso o de fuerza. Si corriges, hazlo con prudencia, y vigila una posible bajada tardía esta noche."),
        "insight.riseSmall":   L("Glucose rose {0} during this session — typical of higher-intensity work.",
                                 "La glucosa subió {0} durante la sesión: típico de trabajo de mayor intensidad."),
        "insight.steady":      L("Glucose stayed steady ({0}) — low-impact at this intensity.",
                                 "La glucosa se mantuvo estable ({0}): poco impacto a esta intensidad."),
        "insight.dropUnknownNadir": L("a low", "un valor bajo"),

    ]

    private static let settings: [String: LocalizedText] = [

        // ── Settings ──
        "settings.title":        L("Settings", "Ajustes"),
        "settings.account":      L("Account", "Cuenta"),
        "settings.setUpProfile": L("Set up your profile", "Configura tu perfil"),
        "settings.addDetails":   L("Tap to add your details", "Toca para añadir tus datos"),
        "settings.since":        L("since {0}", "desde {0}"),
        "settings.devices":      L("Connected Devices", "Dispositivos conectados"),
        "settings.cgm":          L("CGM Sensor", "Sensor MCG"),
        "settings.appleWatch":   L("Apple Watch", "Apple Watch"),
        "settings.notLinked":    L("Not linked", "No vinculado"),
        "settings.notDetected":  L("Not detected", "No detectado"),
        "settings.appleHealth":  L("Apple Health", "Apple Salud"),
        "settings.glucoseSource": L("Glucose Source", "Fuente de glucosa"),
        "settings.dexcom":       L("Dexcom Share", "Dexcom Share"),
        "settings.libre":        L("LibreLinkUp", "LibreLinkUp"),
        "settings.nightscout":   L("Nightscout", "Nightscout"),
        "settings.profile":      L("Profile", "Perfil"),
        "settings.profileSub":   L("Language, units and targets", "Idioma, unidades y objetivos"),
        "settings.more":         L("More", "Más"),
        "settings.help":         L("Help & FAQ", "Ayuda y preguntas frecuentes"),
        "settings.helpSub":      L("How OneMET reads your data", "Cómo interpreta OneMET tus datos"),
        "settings.onLive":       L("On · live", "Activo · en directo"),
        "settings.configuredOff": L("Configured · off", "Configurado · apagado"),
        "settings.general":      L("General", "General"),
        "settings.language":     L("Language", "Idioma"),
        "settings.targets":      L("Personal Targets", "Objetivos personales"),
        "settings.glucoseUnits": L("Glucose Units", "Unidades de glucosa"),
        "settings.glucoseRange": L("Glucose Range", "Rango de glucosa"),
        "settings.metGoal":      L("Daily MET Goal", "Objetivo MET diario"),
        "settings.riskGroup": L("Exercise Risk Group", "Grupo de riesgo en ejercicio"),
        "settings.carbInterval": L("Carb Intake Interval", "Intervalo entre tomas"),
        "settings.insulinDelivery": L("Insulin Delivery", "Administración de insulina"),
        "settings.body":         L("Body", "Cuerpo"),
        "settings.weight":       L("Weight", "Peso"),
        "settings.data":         L("Data", "Datos"),
        "settings.export":       L("Export Health Report", "Exportar informe de salud"),
        "settings.share":        L("Share with Clinician", "Compartir con tu médico"),

        // ── Insulin delivery ──
        "insulin.pump":      L("Insulin Pump", "Bomba de insulina"),
        "insulin.mdi":       L("Injections (MDI)", "Inyecciones (MDI)"),
        "insulin.noInsulin": L("No insulin", "Sin insulina"),

        // ── Diabetes type ──
        "dtype.type1":       L("Type 1", "Tipo 1"),
        "dtype.type2":       L("Type 2", "Tipo 2"),
        "dtype.lada":        L("LADA", "LADA"),
        "dtype.mody":        L("MODY", "MODY"),
        "dtype.gestational": L("Gestational", "Gestacional"),
        "dtype.nonDiabetic": L("Non-diabetic", "Sin diabetes"),
        "dtype.other":       L("Other", "Otro"),

        // ── Editors ──
        "edit.profile":        L("Edit Profile", "Editar perfil"),
        "edit.identity":       L("Identity", "Identidad"),
        "edit.name":           L("Name", "Nombre"),
        "edit.diabetesType":   L("Diabetes type", "Tipo de diabetes"),
        "edit.setDiagYear":    L("Set diagnosis year", "Indicar año de diagnóstico"),
        "edit.diagYear":       L("Diagnosis year", "Año de diagnóstico"),
        "edit.weightFooter":   L("Used for the MET·min calculation. Leave blank to use your Apple Health weight.",
                                 "Se usa para calcular los MET·min. Déjalo vacío para usar tu peso de Apple Salud."),
        "edit.langTitle":      L("Language", "Idioma"),
        "edit.langFooter":     L("Applies immediately across the whole app. Dates and numbers follow the language you pick.",
                                 "Se aplica de inmediato en toda la app. Las fechas y los números siguen el idioma elegido."),
        "edit.unitsTitle":     L("Glucose Units", "Unidades de glucosa"),
        "edit.unitsFooter":    L("Display only — readings are always stored and compared in mg/dL, so switching units never changes your targets or any advice, just how the numbers are written.",
                                 "Solo visualización: las lecturas siempre se guardan y comparan en mg/dL, así que cambiar de unidad no altera tus objetivos ni ninguna recomendación, solo cómo se escriben los números."),
        "edit.currentRange":   L("Current range", "Rango actual"),
        "edit.rangeTitle":     L("Glucose Range", "Rango de glucosa"),
        "edit.rangeFooter":    L("Your personal time-in-range targets. Standard is {0}.",
                                 "Tus objetivos personales de tiempo en rango. El estándar es {0}."),
        "edit.rangeLow":       L("Low", "Bajo"),
        "edit.rangeHigh":      L("High", "Alto"),
        "edit.metTitle":       L("Daily MET Goal", "Objetivo MET diario"),
        "edit.riskTitle":    L("Exercise Risk Group", "Grupo de riesgo en ejercicio"),
        "edit.riskFooter":   L("Sets the glucose levels the fuel plan uses (EASD/ISPAD 2020): your exercise target, and when to take carbs during and after exercise. Automatic takes the more cautious of your exercise routine and your risk of lows.",
                               "Fija los niveles de glucosa que usa el plan (EASD/ISPAD 2020): tu objetivo de ejercicio y cuándo tomar carbohidratos durante y después. Automático elige el más prudente entre tu rutina de ejercicio y tu riesgo de hipos."),
        "edit.riskUnaware":  L("I often don't notice my lows", "A menudo no noto mis hipos"),
        "edit.riskSevere":   L("Severe low in the last 6 months", "Hipo grave en los últimos 6 meses"),
        "edit.riskSevereNote": L("Severe means you needed someone else's help to recover. Either answer puts you in the high-risk group.",
                                 "Grave significa que necesitaste ayuda de otra persona para recuperarte. Cualquiera de las dos respuestas te sitúa en el grupo de riesgo alto."),
        "edit.riskAuto":     L("Automatic result: {0}. From {1} workouts of 45 min or more per week (last 4 weeks) and {2} of time below {3} (last 14 days).",
                               "Resultado automático: {0}. Según {1} entrenamientos de 45 min o más por semana (últimas 4 semanas) y {2} del tiempo por debajo de {3} (últimos 14 días)."),
        "edit.riskNoData":   L("no data", "sin datos"),
        "edit.riskThresholds": L("Exercise target {0} · carbs during under {1} · after under {2}",
                                 "Objetivo de ejercicio {0} · carbohidratos durante por debajo de {1} · después por debajo de {2}"),
        "edit.intervalTitle":  L("Carb Intake Interval", "Intervalo entre tomas"),
        "edit.intervalFooter": L("Default time between carbohydrate intakes in your fuel plan — 30, 45 or 60 min. You can change it for a single plan on the plan itself. It changes how the total is split, not the total.",
                                 "Tiempo por defecto entre tomas de carbohidratos en tu plan: 30, 45 o 60 min. Puedes cambiarlo para un plan concreto en el propio plan. Cambia cómo se reparte el total, no el total."),
        "edit.metFooter":      L("Target MET·minutes per day. A brisk walk is ~3–4 MET; running ~8–10 MET.",
                                 "MET·minutos objetivo al día. Caminar a buen ritmo son ~3–4 MET; correr ~8–10 MET."),
        "edit.metGoal":        L("Daily goal", "Objetivo diario"),
        "edit.carbTitle":      L("Carb Ratio", "Ratio de carbohidratos"),
        "edit.carbFooter":     L("Insulin-to-carb ratio: 1 unit covers this many grams of carbohydrate.",
                                 "Ratio insulina/carbohidratos: 1 unidad cubre estos gramos de carbohidrato."),
        "edit.carbRatio":      L("Ratio", "Ratio"),
        "edit.insulinTitle":   L("Insulin Delivery", "Administración de insulina"),
        "edit.insulinFooter":  L("How you take insulin. This tailors the Plan tab's before-exercise strategy — basal reductions for a pump, meal-bolus timing on injections — and decides whether the carbohydrate plan is offered at all, since it exists to prevent insulin-driven hypoglycaemia.",
                                 "Cómo te administras la insulina. Adapta la estrategia previa al ejercicio en la pestaña Plan (reducción de basal con bomba, ajuste del bolo de comida con plumas) y determina si se ofrece el plan de carbohidratos, ya que existe para prevenir hipoglucemias causadas por la insulina."),
        "edit.delivery":       L("Delivery", "Administración"),

        // ── Glucose source sheets ──
        "src.nsFooter":     L("Your Nightscout site URL plus an access token (or API secret). Glucose is read directly from Nightscout for lower latency than Apple Health. Read-only.",
                              "La URL de tu sitio Nightscout más un token de acceso (o API secret). La glucosa se lee directamente de Nightscout, con menos retardo que Apple Salud. Solo lectura."),
        "src.token":        L("Access token or API secret", "Token de acceso o API secret"),
        "src.useNs":        L("Use Nightscout for glucose", "Usar Nightscout para la glucosa"),
        "src.test":         L("Test Connection", "Probar conexión"),
        "src.testOk":       L("Connected — recent readings found.", "Conectado: se han encontrado lecturas recientes."),
        "src.testFailNs":   L("Couldn't fetch readings. Check the URL and token.", "No se pudieron obtener lecturas. Revisa la URL y el token."),
        "src.title":        L("Glucose Source", "Fuente de glucosa"),
        "src.dexFooter":    L("Your Dexcom account with Share/Follow enabled (Sharing ON in the Dexcom app, with at least one follower). Read-only; only recent (~24 h) glucose is available.",
                              "Tu cuenta Dexcom con Share/Follow activado (Compartir activado en la app Dexcom y al menos un seguidor). Solo lectura; únicamente hay glucosa reciente (~24 h)."),
        "src.username":     L("Username, email or phone", "Usuario, correo o teléfono"),
        "src.password":     L("Password", "Contraseña"),
        "src.region":       L("Region", "Región"),
        "src.outsideUs":    L("Outside US", "Fuera de EE. UU."),
        "src.us":           L("United States", "Estados Unidos"),
        "src.useDexcom":    L("Use Dexcom for glucose", "Usar Dexcom para la glucosa"),
        "src.testFailDex":  L("Couldn't fetch readings. Check account, password and region.",
                              "No se pudieron obtener lecturas. Revisa la cuenta, la contraseña y la región."),
        "src.libreFooter":  L("Sign in with the LibreLinkUp *follower* account — the one that accepted the invite, not the phone that scans the sensor. Read-only; only the last ~12 h of readings are available, so longer history still comes from Apple Health.",
                              "Inicia sesión con la cuenta *seguidora* de LibreLinkUp: la que aceptó la invitación, no el teléfono que escanea el sensor. Solo lectura; únicamente hay lecturas de las últimas ~12 h, así que el historial largo sigue viniendo de Apple Salud."),
        "src.libreEmail":   L("LibreLinkUp email", "Correo de LibreLinkUp"),
        "src.useLibre":     L("Use LibreLinkUp for glucose", "Usar LibreLinkUp para la glucosa"),
        "src.testFailLibre": L("Couldn't fetch readings. Check the email, password and region, and that someone is sharing with this account.",
                               "No se pudieron obtener lecturas. Revisa el correo, la contraseña y la región, y que alguien esté compartiendo con esta cuenta."),
        "src.libreRegionAuto": L("Detected automatically at sign-in.", "Se detecta automáticamente al iniciar sesión."),

        // ── Help & FAQ ──
        "help.title":        L("Help & FAQ", "Ayuda y preguntas frecuentes"),
        "help.subtitle":     L("Guidance", "Orientación"),
        "help.duringTitle":  L("Glucose during exercise", "La glucosa durante el ejercicio"),
        "help.learnTitle":   L("Finding your own pattern", "Encontrar tu propio patrón"),
        "help.metTitle":     L("What is a MET·minute?", "¿Qué es un MET·minuto?"),
        "help.metBody":      L("A MET is a multiple of your resting metabolic rate: walking briskly is about 3–4 MET, running 8–10. Multiply by the minutes you spent there and you get MET·minutes — one number that captures both how hard and how long you went, which is why OneMET rings on it rather than on calories alone.",
                               "Un MET es un múltiplo de tu metabolismo en reposo: caminar a buen ritmo son unos 3–4 MET, correr 8–10. Multiplícalo por los minutos y obtienes MET·minutos: un solo número que recoge intensidad y duración, y por eso el anillo de OneMET se basa en él y no solo en las calorías."),
        "help.insightTitle": L("How the workout insight is worked out", "Cómo se calcula el análisis del entrenamiento"),
        "help.insightBody":  L("For each session OneMET compares your glucose at the start with the value at the end, and also tracks the lowest reading from the start of the session through the hour afterwards. A fall only prompts a carb suggestion if it took you below the level where the guidelines start carbs during exercise — {0} for low risk, higher for the other groups. Dropping {1} and landing at {2} needs no fuelling, so the app says so instead. The amount is the EASD/ISPAD 2020 one for how fast you fell — about 15, 25 or 35 g for cardio, 10, 15 or 20 g for strength and intervals — and where to take it follows the Plan tab's rules: nothing before a session that began above your target, and nothing during one too short for a planned intake.",
                               "En cada sesión OneMET compara tu glucosa al empezar con la del final, y además sigue el valor más bajo desde el inicio hasta una hora después. Una bajada solo genera una sugerencia de carbohidratos si te llevó por debajo del nivel en el que las guías empiezan a dar carbohidratos durante el ejercicio: {0} con riesgo bajo, más alto en los otros grupos. Caer {1} y quedarte en {2} no necesita comer nada, y la app lo dice así. La cantidad es la de EASD/ISPAD 2020 según lo rápido que bajaste —unos 15, 25 o 35 g en cardio; 10, 15 o 20 g en fuerza e intervalos— y cuándo tomarla sigue las reglas de la pestaña Plan: nada antes de una sesión que empezó por encima de tu objetivo, y nada durante una demasiado corta para una toma prevista."),
        "help.intervalTitle": L("Choosing your carb intake interval", "Elegir el intervalo entre tomas"),
        "help.intervalBody":  L("The fuel plan splits its hourly carbohydrate into intakes — every 45 minutes by default. On the fuel plan you can pick 30, 45 or 60 minutes, and the most you'd take at once: 20, 30 or 45 g. The session total stays the same whatever you choose; a shorter interval just means smaller, more frequent intakes. When an intake would go over your maximum and your glucose at the start isn't high, the extra is taken at the start instead, up to the same maximum — so the Start amount on the timeline can be larger than what the start banner asks for: the banner covers your glucose, the rest is fuel brought forward. If intakes are still larger, the plan suggests changing the interval or snack size. The default interval is in Settings ▸ Profile ▸ Carb Intake Interval.",
                                "El plan de carbohidratos reparte la cantidad por hora en tomas, cada 45 minutos por defecto. En el plan puedes elegir 30, 45 o 60 minutos, y lo máximo que tomarías de una vez: 20, 30 o 45 g. El total de la sesión no cambia elijas lo que elijas; un intervalo más corto solo supone tomas más pequeñas y frecuentes. Si una toma superaría tu máximo y tu glucosa al empezar no está alta, lo que sobra se toma al inicio, hasta ese mismo máximo; por eso la cantidad de Inicio en la línea de tiempo puede ser mayor que la que pide el aviso de inicio: el aviso cubre tu glucosa y el resto es combustible adelantado. Si las tomas siguen siendo mayores, el plan sugiere cambiar el intervalo o el tamaño de las tomas. El intervalo por defecto está en Ajustes ▸ Perfil ▸ Intervalo entre tomas."),
        "after.anaerobic": L("Glucose may rise during or after this session — a normal hormonal response, not a sign you ate too much. If you correct, be conservative and agree the amount with your clinician.",
                             "La glucosa puede subir durante o después de esta sesión: es una respuesta hormonal normal, no una señal de que hayas comido demasiado. Si corriges, hazlo con prudencia y acuerda la cantidad con tu equipo médico."),
        "after.mixedTip":  L("Doing cardio as well? Do the strength or intervals first — it keeps glucose steadier during the cardio.",
                             "¿Vas a hacer cardio también? Haz primero la fuerza o los intervalos: mantiene la glucosa más estable durante el cardio."),
        "help.anaerobicTitle": L("Strength training and HIIT", "Entrenamiento de fuerza y HIIT"),
        "help.anaerobicBody":  L("Steady cardio lowers glucose; strength work and high-intensity intervals lower it much less and can raise it, because intense effort releases adrenaline and other hormones that push glucose up. In a large real-world study (T1DEXI) glucose fell on average by {0} in aerobic sessions, {1} in interval sessions and {2} in resistance sessions. So for strength and HIIT the fuel plan plans no carbs during the session — take some only if you drop below your threshold — and warns that glucose may rise afterwards: correct conservatively, and check before bed, as the risk of a delayed low lasts into the night. If you combine both in one workout, doing the strength or intervals before the cardio keeps glucose steadier. This follows ISPAD 2022's exercise types and the 'increase expected' column of the EASD/ISPAD 2020 tables.",
                                 "El cardio continuo baja la glucosa; la fuerza y los intervalos de alta intensidad la bajan mucho menos e incluso pueden subirla, porque el esfuerzo intenso libera adrenalina y otras hormonas que elevan la glucosa. En un gran estudio en vida real (T1DEXI) la glucosa bajó de media {0} en sesiones aeróbicas, {1} en sesiones de intervalos y {2} en sesiones de fuerza. Por eso, para fuerza y HIIT el plan no prevé tomas durante la sesión (toma carbohidratos solo si bajas de tu umbral) y avisa de que la glucosa puede subir después: corrige con prudencia y compruébala antes de dormir, porque el riesgo de una bajada tardía se prolonga por la noche. Si combinas ambos en un mismo entrenamiento, hacer primero la fuerza o los intervalos y después el cardio mantiene la glucosa más estable. Sigue los tipos de ejercicio de ISPAD 2022 y la columna «se espera subida» de las tablas EASD/ISPAD 2020."),
        "help.scopeTitle":   L("Who the fuelling plan is for", "Para quién es el plan de carbohidratos"),
        "help.scopeBody":    L("The carbohydrate guidance follows the EASD/ISPAD 2020 position statement on exercise with CGM and the ISPAD 2022 exercise guidelines. Both were written for type 1 diabetes on injected or pumped insulin, and the hypoglycaemia they prevent is caused by that insulin rather than by the diagnosis. OneMET therefore offers the plan to people using insulin — including type 2 on insulin — and explains itself instead to everyone else. Both rate their advice as expert consensus (evidence level D), ISPAD 2022 is written for children and adolescents, and neither has been validated as an algorithm: the thresholds are published, the way this app combines them is not.",
                               "La orientación sobre carbohidratos sigue la declaración de posición EASD/ISPAD 2020 sobre ejercicio con MCG y las guías ISPAD 2022 de ejercicio. Ambas se escribieron para diabetes tipo 1 con insulina inyectada o en bomba, y la hipoglucemia que previenen la causa esa insulina, no el diagnóstico. Por eso OneMET ofrece el plan a quienes usan insulina —incluida la diabetes tipo 2 con insulina— y al resto le da una explicación. Ambas califican sus recomendaciones como consenso de expertos (nivel de evidencia D), ISPAD 2022 está escrita para niños y adolescentes, y ninguna está validada como algoritmo: los umbrales están publicados, la forma en que esta app los combina no."),
        "help.planTitle":    L("How the fuel plan is worked out", "Cómo se calcula el plan de carbohidratos"),
        "help.planBody":     L("Before: whether to start, wait or eat first comes from the EASD/ISPAD 2020 adult table — your glucose, its trend arrow, and whether this kind of exercise usually lowers glucose (cardio) or keeps it steady or raises it (strength, intervals). During: intakes are planned at ISPAD 2022's rates — about 0.3–0.5 g per kg per hour when only basal insulin is active, 0.5–1.0 with active bolus insulin — and never more than 60 g an hour, about what the gut can absorb. Insulin on board picks the range and intensity the point inside it. If you start above your exercise target, the glucose above it counts as fuel (assuming it spreads through about 0.2 L of body water per kg), so the first intakes drop out. During the session, adjust the intakes with your CGM values. After: the EASD 90-minute table and ISPAD's bedtime snack. Both guidelines rate their advice as expert consensus (evidence level D), and their tables weren't written for hybrid closed-loop pumps.",
                               "Antes: si empezar, esperar o comer primero sale de la tabla para adultos de EASD/ISPAD 2020: tu glucosa, su flecha de tendencia y si este tipo de ejercicio suele bajarla (cardio) o mantenerla o subirla (fuerza, intervalos). Durante: las tomas se prevén a los ritmos de ISPAD 2022 —unos 0,3–0,5 g por kg y hora cuando solo actúa la insulina basal, 0,5–1,0 con insulina de bolo activa— y nunca más de 60 g por hora, aproximadamente lo que puede absorber el intestino. La insulina activa elige el rango y la intensidad el punto dentro de él. Si empiezas por encima de tu objetivo de ejercicio, la glucosa que sobra cuenta como combustible (suponiendo que se reparte en unos 0,2 L de agua corporal por kg), así que las primeras tomas desaparecen. Durante la sesión, ajusta las tomas según los valores del MCG. Después: la tabla de 90 minutos de EASD y el tentempié antes de dormir de ISPAD. Ambas guías califican sus recomendaciones como consenso de expertos (nivel de evidencia D), y sus tablas no se escribieron para bombas de asa cerrada híbrida."),
        "help.riskTitle":    L("Your exercise risk group", "Tu grupo de riesgo en ejercicio"),
        "help.riskBody":     L("EASD/ISPAD 2020 moves every glucose threshold according to how regularly you exercise and how prone you are to lows. Low risk: carbs during exercise below {0}, exercise target {1}. Moderate: below {2}, target {3}. High: below {4}, target {5}. Automatic counts your workouts of 45 min or more (more than 2 a week is low risk, 1–2 moderate, fewer high), your time below {6} over 14 days (under 4 %, 4–8 %, over 8 %), and two questions — not noticing lows, or a severe low in the last 6 months, mean high risk — and takes the most cautious answer. You can pin a group in Settings ▸ Profile ▸ Exercise Risk Group.",
                               "EASD/ISPAD 2020 desplaza todos los umbrales de glucosa según lo regular que sea tu ejercicio y tu tendencia a las hipos. Riesgo bajo: carbohidratos durante el ejercicio por debajo de {0}, objetivo de ejercicio {1}. Moderado: por debajo de {2}, objetivo {3}. Alto: por debajo de {4}, objetivo {5}. Automático cuenta tus entrenamientos de 45 min o más (más de 2 por semana es riesgo bajo, 1–2 moderado, menos alto), tu tiempo por debajo de {6} en 14 días (menos del 4 %, 4–8 %, más del 8 %) y dos preguntas —no notar las hipos o haber tenido una grave en los últimos 6 meses suponen riesgo alto— y se queda con la respuesta más prudente. Puedes fijar un grupo en Ajustes ▸ Perfil ▸ Grupo de riesgo en ejercicio."),
        "help.sourcesTitle": L("Where the numbers come from", "De dónde salen los datos"),
        "help.sourcesBody":  L("Workouts, heart rate and activity come from Apple Health. Glucose comes from whichever source you switch on in Settings — Dexcom Share, LibreLinkUp or Nightscout — falling back to Apple Health. Follower services only keep a short window (Dexcom ~24 h, LibreLinkUp ~12 h), so the 14-day figures always come from Nightscout or Apple Health.",
                               "Los entrenamientos, la frecuencia cardiaca y la actividad vienen de Apple Salud. La glucosa viene de la fuente que actives en Ajustes — Dexcom Share, LibreLinkUp o Nightscout — y si no, de Apple Salud. Los servicios de seguidor solo guardan una ventana corta (Dexcom ~24 h, LibreLinkUp ~12 h), así que las cifras de 14 días salen siempre de Nightscout o de Apple Salud."),
        "help.disclaimerTitle": L("This is not medical advice", "Esto no es consejo médico"),
        // Closed loop: one sentence on the Help list, the reasons one tap further in.
        "help.aidTitle":     L("Using a closed-loop system?", "¿Usas un sistema de asa cerrada?"),
        "help.aidBody":      L("If you use a closed-loop system, choose manual mode before and during the activity.",
                               "Si usas un sistema de asa cerrada, elige el modo manual antes y durante la actividad."),
        "help.aidMore":      L("Why manual mode?", "¿Por qué el modo manual?"),
        "help.aidDetailTitle": L("Closed-loop systems and exercise", "Sistemas de asa cerrada y ejercicio"),
        "help.aidSportTitle": L("The sport mode doesn't know how hard you go", "El modo deporte no sabe a qué intensidad vas"),
        "help.aidSportBody":  L("Closed-loop (AID) systems — CamAPS FX, Control-IQ, MiniMed 780G, Omnipod 5 and others — have a sport or exercise mode, or a temporary target, that raises the glucose target and makes insulin delivery less aggressive. But it doesn't take into account the intensity of the exercise: an easy walk and a hard interval session get the same setting. And because the system keeps adjusting your insulin by itself during the session, it isn't possible to quantify how much carbohydrate you need — a plan made in advance can't predict what the pump will do.",
                                "Los sistemas de asa cerrada (AID) —CamAPS FX, Control-IQ, MiniMed 780G, Omnipod 5 y otros— tienen un modo deporte o ejercicio, o un objetivo temporal, que sube el objetivo de glucosa y hace menos agresiva la administración de insulina. Pero no tiene en cuenta la intensidad del ejercicio: un paseo tranquilo y una sesión de intervalos dura reciben el mismo ajuste. Y como el sistema sigue ajustando la insulina por su cuenta durante la sesión, no es posible cuantificar cuántos carbohidratos necesitas: un plan hecho de antemano no puede prever lo que hará la bomba."),
        "help.aidLearnTitle": L("The algorithm can't learn from your activity", "El algoritmo no puede aprender de tu actividad"),
        "help.aidLearnBody":  L("The algorithm doesn't know what exercise you did or how intense it was, so it can't learn from the session and do better next time. Each workout looks to it like an unexplained change in your glucose.",
                                "El algoritmo no sabe qué ejercicio hiciste ni a qué intensidad, así que no puede aprender de la sesión ni hacerlo mejor la próxima vez. Para él, cada entrenamiento es un cambio de glucosa sin explicación."),
        "help.aidManualTitle": L("What to do", "Qué hacer"),
        "help.aidManualBody":  L("OneMET's fuel plan is for decisions you make yourself, as with injections or a pump in manual mode. If you use a closed-loop system, switch it to manual mode before and during the activity, and use the plan as you would with an open loop. Agree this with your clinician first.",
                                 "El plan de carbohidratos de OneMET es para decisiones que tomas tú, como con inyecciones o con bomba en modo manual. Si usas un sistema de asa cerrada, ponlo en modo manual antes y durante la actividad, y usa el plan como lo harías en asa abierta. Acuérdalo antes con tu equipo médico."),

        // ── Export ──
        "export.mailSubject": L("OneMET — Health report", "OneMET — Informe de salud"),
        "export.mailBody":    L("Please find attached my OneMET workout health report.",
                                "Adjunto mi informe de salud de entrenamientos de OneMET."),
    ]
}

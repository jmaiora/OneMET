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
        "welcome.subtitle":    L("Glucose and activity, side by side. Two quick choices and you're set — you can change both later in Settings.",
                                 "Glucosa y actividad, lado a lado. Dos ajustes rápidos y listo: puedes cambiar ambos más tarde en Ajustes."),
        "welcome.language":    L("Language", "Idioma"),
        "welcome.units":       L("Glucose units", "Unidades de glucosa"),
        "welcome.unitsNote":   L("Readings are always stored in mg/dL — this only changes how they're written.",
                                 "Las lecturas siempre se guardan en mg/dL: esto solo cambia cómo se muestran."),
        "welcome.start":       L("Get started", "Empezar"),
        "welcome.disclaimer":  L("OneMET offers illustrative guidance, not medical advice.",
                                 "OneMET ofrece orientación ilustrativa, no consejo médico."),

        // ── Common ──
        "common.cancel":   L("Cancel", "Cancelar"),
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
        "summary.noWorkoutYet":   L("Log a workout to see how activity shifts your glucose.",
                                    "Registra un entrenamiento para ver cómo la actividad mueve tu glucosa."),

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
        "plan.runGuide":     L("Run Guide", "Guía de sesión"),
        "plan.sessionDetails": L("Session Details", "Detalles de la sesión"),
        "plan.plannedDuration": L("Planned Duration", "Duración prevista"),
        "plan.difficulty":   L("Difficulty", "Dificultad"),
        "plan.currentState": L("Current State", "Estado actual"),
        "plan.currentGlucose": L("Current Glucose", "Glucosa actual"),
        "plan.iob":          L("Insulin on Board", "Insulina activa"),
        "plan.during":       L("During · {0}", "Durante · {0}"),
        "plan.atStart":      L("AT START", "AL EMPEZAR"),
        "plan.everyMin":     L("EVERY {0} MIN", "CADA {0} MIN"),
        "plan.perHourTotal": L("~{0} g/h · ~{1} g total", "~{0} g/h · ~{1} g en total"),
        "plan.goodToKnow":   L("Good to know", "Conviene saber"),
        "plan.time":         L("TIME", "TIEMPO"),
        "plan.difficultyShort": L("DIFFICULTY", "DIFICULTAD"),
        "plan.disclaimer":   L("Illustrative guidance, not medical advice. Insulin changes and carbohydrate decisions should be agreed with your clinician.",
                               "Orientación ilustrativa, no consejo médico. Los cambios de insulina y las decisiones sobre carbohidratos deben acordarse con tu equipo médico."),
        "plan.sources":      L("  Approach: a prevention-first, real-world interpretation of the 2017 Lancet consensus on exercise in type 1 diabetes (Riddell et al.) and EXTOD.",
                               "  Enfoque: interpretación práctica y centrada en la prevención del consenso de The Lancet (2017) sobre ejercicio en diabetes tipo 1 (Riddell et al.) y EXTOD."),

        // ── Plan: duration bands ──
        "band.easy":           L("Easy", "Suave"),
        "band.easy.detail":    L("Under 45 min · aim to finish without eating", "Menos de 45 min · intenta acabar sin comer"),
        "band.moderate":       L("Moderate", "Moderada"),
        "band.moderate.detail": L("45–90 min · fuel as needed", "45–90 min · toma carbohidratos si hace falta"),
        "band.long":           L("Long", "Larga"),
        "band.long.detail":    L("Over 90 min · fuel for performance", "Más de 90 min · come para rendir"),

        // ── Plan: before-workout strategy ──
        "before.pump": L("Prevent, don’t treat: ease insulin ahead — a basal cut 60–90 min before or a smaller bolus if you ate recently. Start near {0}, carry fast carbs.",
                         "Prevenir, no corregir: ajusta la insulina antes — reduce la basal 60–90 min antes, o pon un bolo menor si has comido hace poco. Empieza cerca de {0} y lleva carbohidratos rápidos."),
        "before.mdi":  L("Prevent, don’t treat: your lever is a smaller meal bolus if you ate within ~2–3 h. Start near {0}, carry fast carbs.",
                         "Prevenir, no corregir: tu herramienta es un bolo de comida más pequeño si has comido en las últimas 2–3 h. Empieza cerca de {0} y lleva carbohidratos rápidos."),

        // ── Plan: start decision ──
        "start.unknown.title":  L("Check your glucose first", "Comprueba tu glucosa primero"),
        "start.unknown.reason": L("No live CGM / Nightscout reading — head out only when you can see your glucose and trend.",
                                  "Sin lectura en directo de MCG o Nightscout: sal solo cuando puedas ver tu glucosa y su tendencia."),
        "start.stop.title":     L("Treat first — don't start", "Trata primero: no empieces"),
        "start.stop.reason":    L("You're low ({0}). Treat, and wait until you've recovered before heading out.",
                                  "Estás en hipoglucemia ({0}). Trátala y espera a recuperarte antes de salir."),
        "start.wait.title":     L("Top up ~{0} g and wait", "Toma ~{0} g y espera"),
        "start.wait.reason":    L("{0} is below the safe start zone — take ~{1} g and re-check before you go.",
                                  "{0} está por debajo de la zona segura de inicio: toma ~{1} g y vuelve a mirar antes de salir."),
        "start.topUpFirst.title": L("Top up ~{0} g first", "Toma ~{0} g antes"),
        "start.lowFalling.reason": L("{0} and falling — take ~{1} g now to head off an early drop.",
                                     "{0} y bajando: toma ~{1} g ahora para evitar una caída temprana."),
        "start.lowThenGo.title":  L("Top up ~{0} g, then go", "Toma ~{0} g y sal"),
        "start.lowThenGo.reason": L("{0} is on the low side — take ~{1} g and start, watching your trend.",
                                    "{0} es algo bajo: toma ~{1} g y empieza, vigilando la tendencia."),
        "start.midFalling.reason": L("{0} but drifting down — ~{1} g steadies the start.",
                                     "{0} pero con tendencia a bajar: ~{1} g estabilizan el arranque."),
        "start.highIob.title":   L("Consider ~{0} g — insulin on board", "Considera ~{0} g: tienes insulina activa"),
        "start.highIob.reason":  L("{0} is fine, but {1} U on board will keep pulling you down — ~{2} g covers it.",
                                   "{0} está bien, pero {1} U activas seguirán tirando hacia abajo: ~{2} g lo compensan."),
        "start.go.title":        L("Good to start", "Puedes empezar"),
        "start.go.reason":       L("{0} is right in the sweet spot — head out.", "{0} está justo en el punto ideal: adelante."),
        "start.goHigh.reason":   L("{0} is a little high; easy exercise usually brings it down. No carbs needed.",
                                   "{0} es algo alto; el ejercicio suave suele bajarlo. No necesitas carbohidratos."),
        "start.ketones.title":   L("Check ketones first", "Comprueba las cetonas primero"),
        "start.ketones.reason":  L("{0} is high — if it's unexpected, check ketones and don't run if they're raised. Otherwise start gently.",
                                   "{0} es alto: si no lo esperabas, mide cetonas y no entrenes si están elevadas. Si no, empieza suave."),

        // ── Plan: during ──
        "during.none": L("Short and easy enough to finish without eating. Carry ~15 g of fast carbs and use them only if you fall toward your target or your CGM arrow shows a rapid drop.",
                         "Corta y suave: puedes acabarla sin comer. Lleva ~15 g de carbohidratos rápidos y úsalos solo si te acercas a tu objetivo o la flecha del MCG marca una bajada rápida."),
        "during.some": L("Planned carb intake to fuel the effort — take it with insulin adjusted rather than skipped. Longer sessions simply add more feeds. Rates per the Riddell/EXTOD consensus.",
                         "Ingesta planificada de carbohidratos para sostener el esfuerzo: tómala con la insulina ajustada, no suprimida. Las sesiones largas solo añaden más tomas. Cantidades según el consenso Riddell/EXTOD."),

        // ── Plan: philosophy ──
        "philosophy": L("Most PwD feel best around {0} during exercise. Avoiding lows matters more than perfect numbers — chasing {1} usually means repeated gels and rebound highs.",
                        "La mayoría de personas con diabetes se prefieren estar en torno a {0} durante el ejercicio. Evitar hipoglucemias importa más que un número perfecto: perseguir {1} suele acabar en geles repetidos y rebotes altos."),
        "learn":      L("Learn your own response: note your start glucose, insulin on board, any carbs, and your end glucose. After 3–5 similar runs you'll usually settle on a repeatable strategy.",
                        "Aprende tu propia respuesta: anota la glucosa de inicio, la insulina activa, los carbohidratos y la glucosa final. Tras 3–5 sesiones parecidas darás con una estrategia repetible."),
        // The one-liners the Plan tab shows; the full versions live in Help & FAQ.
        "philosophy.short": L("Most PwD feel best around {0} before exercise.",
                              "La mayoría de personas con diabetes prefieren estar en torno a {0} antes del ejercicio."),
        "learn.short":      L("Learn your own response.", "Aprende tu propia respuesta."),

    ]

    private static let insights: [String: LocalizedText] = [

        // ── Workout insights ──
        "insight.dropNoCarbs": L("This {0} lowered glucose by {1} over {2} min, but you never went below {3} — no extra carbs needed for sessions like this.",
                                 "Este {0} bajó la glucosa {1} en {2} min, pero no bajaste de {3}: no necesitas carbohidratos extra en sesiones así."),
        "insight.dropCarbs":   L("This {0} lowered glucose by {1} over {2} min, down to {3} — consider adding {4} g carbs before similar sessions.",
                                 "Este {0} bajó la glucosa {1} en {2} min, hasta {3}: plantéate tomar {4} g de carbohidratos antes de sesiones parecidas."),
        "insight.dropModerate": L("Moderate drop of {0} during this session — a small additional snack beforehand can help keep you in range.",
                                  "Bajada moderada de {0} durante la sesión: un pequeño tentempié previo puede ayudarte a mantenerte en rango."),
        "insight.riseBig":     L("This {0} raised glucose by {1} over {2} min — common with short, intense or anaerobic efforts.",
                                 "Este {0} subió la glucosa {1} en {2} min: es habitual en esfuerzos cortos, intensos o anaeróbicos."),
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
        "settings.insulinDelivery": L("Insulin Delivery", "Administración de insulina"),
        "settings.body":         L("Body", "Cuerpo"),
        "settings.weight":       L("Weight", "Peso"),
        "settings.data":         L("Data", "Datos"),
        "settings.export":       L("Export Health Report", "Exportar informe de salud"),
        "settings.share":        L("Share with Clinician", "Compartir con tu médico"),

        // ── Insulin delivery ──
        "insulin.pump": L("Insulin Pump", "Bomba de insulina"),
        "insulin.mdi":  L("Injections (MDI)", "Inyecciones (MDI)"),

        // ── Diabetes type ──
        "dtype.type1":       L("Type 1", "Tipo 1"),
        "dtype.type2":       L("Type 2", "Tipo 2"),
        "dtype.lada":        L("LADA", "LADA"),
        "dtype.mody":        L("MODY", "MODY"),
        "dtype.gestational": L("Gestational", "Gestacional"),
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
        "edit.metFooter":      L("Target MET·minutes per day. A brisk walk is ~3–4 MET; running ~8–10 MET.",
                                 "MET·minutos objetivo al día. Caminar a buen ritmo son ~3–4 MET; correr ~8–10 MET."),
        "edit.metGoal":        L("Daily goal", "Objetivo diario"),
        "edit.carbTitle":      L("Carb Ratio", "Ratio de carbohidratos"),
        "edit.carbFooter":     L("Insulin-to-carb ratio: 1 unit covers this many grams of carbohydrate.",
                                 "Ratio insulina/carbohidratos: 1 unidad cubre estos gramos de carbohidrato."),
        "edit.carbRatio":      L("Ratio", "Ratio"),
        "edit.insulinTitle":   L("Insulin Delivery", "Administración de insulina"),
        "edit.insulinFooter":  L("How you take insulin. This tailors the Plan tab's before-workout strategy — basal reductions for a pump, meal-bolus timing on injections.",
                                 "Cómo te administras la insulina. Adapta la estrategia previa al ejercicio en la pestaña Plan: reducción de basal con bomba, ajuste del bolo de comida con plumas."),
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
        "help.insightBody":  L("For each session OneMET compares your glucose at the start with the value at the end, and also tracks the lowest reading from the start of the session through the hour afterwards. A large fall only prompts a carb suggestion if it actually took you near your low threshold — dropping 60 points and landing at 190 needs no fuelling, so the app says so instead.",
                               "En cada sesión OneMET compara tu glucosa al empezar con la del final, y además sigue el valor más bajo desde el inicio hasta una hora después. Una bajada grande solo genera una sugerencia de carbohidratos si de verdad te acercó a tu umbral bajo: caer 60 puntos y quedarte en 190 no necesita comer nada, y la app lo dice así."),
        "help.sourcesTitle": L("Where the numbers come from", "De dónde salen los datos"),
        "help.sourcesBody":  L("Workouts, heart rate and activity come from Apple Health. Glucose comes from whichever source you switch on in Settings — Dexcom Share, LibreLinkUp or Nightscout — falling back to Apple Health. Follower services only keep a short window (Dexcom ~24 h, LibreLinkUp ~12 h), so the 14-day figures always come from Nightscout or Apple Health.",
                               "Los entrenamientos, la frecuencia cardiaca y la actividad vienen de Apple Salud. La glucosa viene de la fuente que actives en Ajustes — Dexcom Share, LibreLinkUp o Nightscout — y si no, de Apple Salud. Los servicios de seguidor solo guardan una ventana corta (Dexcom ~24 h, LibreLinkUp ~12 h), así que las cifras de 14 días salen siempre de Nightscout o de Apple Salud."),
        "help.disclaimerTitle": L("This is not medical advice", "Esto no es consejo médico"),

        // ── Export ──
        "export.mailSubject": L("OneMET — Health report", "OneMET — Informe de salud"),
        "export.mailBody":    L("Please find attached my OneMET workout health report.",
                                "Adjunto mi informe de salud de entrenamientos de OneMET."),
    ]
}

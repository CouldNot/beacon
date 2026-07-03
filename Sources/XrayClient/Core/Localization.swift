import Foundation
import Observation

/// Supported UI languages. `.system` follows the macOS preferred language.
enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case system
    case en, ru, zh, es, hi, ar, fr, pt, de, ja, id, tr

    var id: String { rawValue }

    /// Native display name shown in the selector.
    var displayName: String {
        switch self {
        case .system: return "System"
        case .en: return "English"
        case .ru: return "Русский"
        case .zh: return "中文"
        case .es: return "Español"
        case .hi: return "हिन्दी"
        case .ar: return "العربية"
        case .fr: return "Français"
        case .pt: return "Português"
        case .de: return "Deutsch"
        case .ja: return "日本語"
        case .id: return "Bahasa Indonesia"
        case .tr: return "Türkçe"
        }
    }

    var isRTL: Bool { self == .ar }
}

/// In-memory localization manager. SPM executables can't easily use .lproj
/// bundles, so translations live in a code table with English fallback.
@MainActor
@Observable
final class Loc {
    var language: AppLanguage = .system {
        didSet { resolved = Loc.resolve(language) }
    }
    private var resolved: String = "en"

    init(language: AppLanguage = .system) {
        self.language = language
        self.resolved = Loc.resolve(language)
    }

    var isRTL: Bool {
        (AppLanguage(rawValue: resolved)?.isRTL ?? false) || resolved == "ar"
    }

    /// Look up a translation by its English key. Falls back to the key itself.
    func callAsFunction(_ key: String) -> String {
        if resolved == "en" { return key }
        return Loc.table[key]?[resolved] ?? key
    }

    /// Map `.system` to the best matching supported language code.
    private static func resolve(_ lang: AppLanguage) -> String {
        if lang != .system { return lang.rawValue }
        for pref in Locale.preferredLanguages {
            let code = String(pref.prefix(2)).lowercased()
            if AppLanguage(rawValue: code) != nil { return code }
        }
        return "en"
    }
}

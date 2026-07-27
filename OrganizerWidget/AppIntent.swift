import WidgetKit
import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "План дня" }
    static var description: IntentDescription { "Выберите личный знак для ближайшей задачи." }

    @Parameter(title: "Личный знак", default: "📌")
    var favoriteEmoji: String
}

import WidgetKit
import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Настройка виджета" }
    static var description: IntentDescription { "Выберите эмодзи, который будет использоваться в виджете." }

    @Parameter(title: "Эмодзи", default: "📌")
    var favoriteEmoji: String
}

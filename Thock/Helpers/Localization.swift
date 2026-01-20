import Foundation

// MARK: - Language Enum

enum AppLanguage: String, CaseIterable {
    case english = "en"
    case spanish = "es"
    case chinese = "zh"
    case japanese = "ja"
    
    var displayName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Español"
        case .chinese: return "中文"
        case .japanese: return "日本語"
        }
    }
    
    static func fromSystem() -> AppLanguage {
        guard let preferred = Locale.preferredLanguages.first else { return .english }
        if preferred.hasPrefix("es") { return .spanish }
        if preferred.hasPrefix("zh") { return .chinese }
        if preferred.hasPrefix("ja") { return .japanese }
        return .english
    }
}

// MARK: - Localization Manager

final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    private let key = "appLanguage"
    private var isInitialized = false
    
    @Published var current: AppLanguage {
        didSet {
            UserDefaults.standard.set(current.rawValue, forKey: key)
            if isInitialized {
                NotificationCenter.default.post(name: .languageDidChange, object: nil)
            }
        }
    }
    
    private init() {
        if let saved = UserDefaults.standard.string(forKey: key),
           let lang = AppLanguage(rawValue: saved) {
            self.current = lang
        } else {
            self.current = AppLanguage.fromSystem()
        }
        isInitialized = true
    }
}

extension Notification.Name {
    static let languageDidChange = Notification.Name("languageDidChange")
}

// MARK: - Localized Strings

struct L10n {
    private static var lang: AppLanguage { LocalizationManager.shared.current }
    
    // MARK: - Settings Tabs
    static var general: String {
        switch lang {
        case .english: return "General"
        case .spanish: return "General"
        case .chinese: return "通用"
        case .japanese: return "一般"
        }
    }
    
    static var sound: String {
        switch lang {
        case .english: return "Sound"
        case .spanish: return "Sonido"
        case .chinese: return "声音"
        case .japanese: return "サウンド"
        }
    }
    
    static var shortcuts: String {
        switch lang {
        case .english: return "Shortcuts"
        case .spanish: return "Atajos"
        case .chinese: return "快捷键"
        case .japanese: return "ショートカット"
        }
    }
    
    // MARK: - System Section
    static var system: String {
        switch lang {
        case .english: return "System"
        case .spanish: return "Sistema"
        case .chinese: return "系统"
        case .japanese: return "システム"
        }
    }
    
    static var launchAtLogin: String {
        switch lang {
        case .english: return "Launch Thock at login"
        case .spanish: return "Iniciar Thock al iniciar sesión"
        case .chinese: return "登录时启动 Thock"
        case .japanese: return "ログイン時にThockを起動"
        }
    }
    
    static var launchAtLoginSubtitle: String {
        switch lang {
        case .english: return "Automatically start Thock when you log in"
        case .spanish: return "Iniciar Thock automáticamente al iniciar sesión"
        case .chinese: return "登录时自动启动 Thock"
        case .japanese: return "ログイン時にThockを自動的に起動"
        }
    }
    
    static var language: String {
        switch lang {
        case .english: return "Language"
        case .spanish: return "Idioma"
        case .chinese: return "语言"
        case .japanese: return "言語"
        }
    }
    
    static var languageSubtitle: String {
        switch lang {
        case .english: return "Choose your preferred language"
        case .spanish: return "Elige tu idioma preferido"
        case .chinese: return "选择您的首选语言"
        case .japanese: return "言語を選択"
        }
    }
    
    // MARK: - More Section
    static var more: String {
        switch lang {
        case .english: return "More"
        case .spanish: return "Más"
        case .chinese: return "更多"
        case .japanese: return "その他"
        }
    }
    
    static var aboutThisVersion: String {
        switch lang {
        case .english: return "About this version"
        case .spanish: return "Acerca de esta versión"
        case .chinese: return "关于此版本"
        case .japanese: return "このバージョンについて"
        }
    }
    
    static var contribute: String {
        switch lang {
        case .english: return "Contribute"
        case .spanish: return "Contribuir"
        case .chinese: return "贡献代码"
        case .japanese: return "貢献する"
        }
    }
    
    static var reportBug: String {
        switch lang {
        case .english: return "Report a bug"
        case .spanish: return "Informar un error"
        case .chinese: return "报告问题"
        case .japanese: return "バグを報告"
        }
    }
    
    // MARK: - Sound Settings
    static var output: String {
        switch lang {
        case .english: return "Output"
        case .spanish: return "Salida"
        case .chinese: return "输出"
        case .japanese: return "出力"
        }
    }
    
    static var volume: String {
        switch lang {
        case .english: return "Volume"
        case .spanish: return "Volumen"
        case .chinese: return "音量"
        case .japanese: return "音量"
        }
    }
    
    static var playThrough: String {
        switch lang {
        case .english: return "Play sound effects through"
        case .spanish: return "Reproducir efectos de sonido a través de"
        case .chinese: return "播放声音效果通过"
        case .japanese: return "サウンドの出力先"
        }
    }
    
    static var systemDefault: String {
        switch lang {
        case .english: return "System Default"
        case .spanish: return "Predeterminado del sistema"
        case .chinese: return "系统默认"
        case .japanese: return "システムデフォルト"
        }
    }
    
    static var filters: String {
        switch lang {
        case .english: return "Filters"
        case .spanish: return "Filtros"
        case .chinese: return "过滤器"
        case .japanese: return "フィルター"
        }
    }
    
    static var disableModifierKeys: String {
        switch lang {
        case .english: return "Disable sound for modifier keys"
        case .spanish: return "Desactivar el sonido para las teclas modificadoras"
        case .chinese: return "禁用修饰键声音"
        case .japanese: return "修飾キーのサウンドを無効化"
        }
    }
    
    static var disableModifierKeysSubtitle: String {
        switch lang {
        case .english: return "Mute sounds when pressing modifier keys (Cmd, Shift, etc.)"
        case .spanish: return "Silenciar sonidos al pulsar las teclas modificadoras (Cmd, Shift, etc.)"
        case .chinese: return "按下修饰键时静音（Cmd、Shift 等）"
        case .japanese: return "修飾キー（Cmd、Shiftなど）を押したときにミュート"
        }
    }
    
    static var ignoreRapidKeys: String {
        switch lang {
        case .english: return "Ignore rapid key events"
        case .spanish: return "Ignorar eventos rápidos de teclas"
        case .chinese: return "忽略快速连续按键"
        case .japanese: return "高速キー入力を無視"
        }
    }
    
    static var ignoreRapidKeysSubtitle: String {
        switch lang {
        case .english: return "Filter out key events that occur too quickly in succession"
        case .spanish: return "Filtrar los eventos de teclas que ocurren demasiado rápido en sucesión"
        case .chinese: return "过滤掉过快的连续按键事件"
        case .japanese: return "連続して発生する高速なキーイベントをフィルタリング"
        }
    }
    
    static var autoMute: String {
        switch lang {
        case .english: return "Auto-mute with Music and Spotify"
        case .spanish: return "Silencio automático con Music y Spotify"
        case .chinese: return "播放音乐时自动静音"
        case .japanese: return "音楽再生時に自動ミュート"
        }
    }
    
    static var autoMuteSubtitle: String {
        switch lang {
        case .english: return "Automatically mute sounds when music is playing"
        case .spanish: return "Silencia automáticamente los sonidos cuando se está reproduciendo música"
        case .chinese: return "播放音乐时自动静音"
        case .japanese: return "音楽再生中は自動的にミュート"
        }
    }
    
    static var soundpacks: String {
        switch lang {
        case .english: return "Soundpacks"
        case .spanish: return "Paquetes de sonido"
        case .chinese: return "音效包"
        case .japanese: return "サウンドパック"
        }
    }
    
    static var customSoundpackDir: String {
        switch lang {
        case .english: return "Custom soundpack directory"
        case .spanish: return "Directorio personalizado de soundpack"
        case .chinese: return "自定义音效包目录"
        case .japanese: return "カスタムサウンドパックディレクトリ"
        }
    }
    
    static var open: String {
        switch lang {
        case .english: return "Open"
        case .spanish: return "Abrir"
        case .chinese: return "打开"
        case .japanese: return "開く"
        }
    }
    
    static var performance: String {
        switch lang {
        case .english: return "Performance"
        case .spanish: return "Rendimiento"
        case .chinese: return "性能"
        case .japanese: return "パフォーマンス"
        }
    }
    
    static var audioLatency: String {
        switch lang {
        case .english: return "Audio latency"
        case .spanish: return "Latencia de audio"
        case .chinese: return "音频延迟"
        case .japanese: return "オーディオ遅延"
        }
    }
    
    static var audioLatencySubtitle: String {
        switch lang {
        case .english: return "- Ultra Low: most responsive, highest CPU usage\n- Low: very responsive, high CPU usage\n- Normal: balanced performance (recommended)\n- High: lower CPU usage, slight delay\n- Very High: lowest CPU usage, noticeable delay"
        case .spanish: return "- Ultra Bajo: Más receptivo, más alto uso de la CPU\n- Bajo: Muy receptivo, alto uso de la CPU\n- Normal: Rendimiento equilibrado (recomendado)\n- Alto: Menor uso de la CPU, leve retardo\n- Muy Alto: Mínimo uso de la CPU, retraso notable"
        case .chinese: return "- 超低：响应最快，CPU 占用最高\n- 低：响应很快，CPU 占用较高\n- 正常：性能均衡（推荐）\n- 高：CPU 占用较低，略有延迟\n- 非常高：CPU 占用最低，延迟明显"
        case .japanese: return "- 超低：最も応答性が高く、CPU使用率が最も高い\n- 低：非常に応答性が高く、CPU使用率が高い\n- 通常：バランスの取れたパフォーマンス（推奨）\n- 高：CPU使用率が低く、わずかな遅延\n- 非常に高い：CPU使用率が最も低く、顕著な遅延"
        }
    }
    
    static var ultraLow: String {
        switch lang {
        case .english: return "Ultra Low"
        case .spanish: return "Ultra Bajo"
        case .chinese: return "超低"
        case .japanese: return "超低"
        }
    }
    
    static var low: String {
        switch lang {
        case .english: return "Low"
        case .spanish: return "Bajo"
        case .chinese: return "低"
        case .japanese: return "低"
        }
    }
    
    static var normal: String {
        switch lang {
        case .english: return "Normal"
        case .spanish: return "Normal"
        case .chinese: return "正常"
        case .japanese: return "通常"
        }
    }
    
    static var high: String {
        switch lang {
        case .english: return "High"
        case .spanish: return "Alto"
        case .chinese: return "高"
        case .japanese: return "高"
        }
    }
    
    static var veryHigh: String {
        switch lang {
        case .english: return "Very High"
        case .spanish: return "Muy Alto"
        case .chinese: return "非常高"
        case .japanese: return "非常に高い"
        }
    }
    
    static var reduceCPU: String {
        switch lang {
        case .english: return "Reduce CPU when idle"
        case .spanish: return "Reducir la CPU cuando esté en reposo"
        case .chinese: return "空闲时降低 CPU 占用"
        case .japanese: return "アイドル時にCPU使用率を削減"
        }
    }
    
    static var reduceCPUSubtitle: String {
        switch lang {
        case .english: return "Stops audio engine after inactivity to reduce CPU usage.\nFirst sound after idle may have a tiny delay.\nSet to 'Never' to keep engine always running."
        case .spanish: return "Detiene el audio tras inactividad para reducir CPU.\nEl primer sonido puede tener un leve retraso.\nUsa 'Nunca' para mantener el motor activo."
        case .chinese: return "闲置后停止音频引擎以降低 CPU 占用。\n空闲后的第一个声音可能会有轻微延迟。\n设置为「从不」以保持引擎始终运行。"
        case .japanese: return "非アクティブ時にオーディオエンジンを停止してCPU使用率を削減。\nアイドル後の最初のサウンドにわずかな遅延が生じる場合があります。\n「なし」に設定するとエンジンを常時稼働させます。"
        }
    }
    
    static var seconds5: String {
        switch lang {
        case .english: return "5 seconds"
        case .spanish: return "5 segundos"
        case .chinese: return "5 秒"
        case .japanese: return "5秒"
        }
    }
    
    static var seconds10: String {
        switch lang {
        case .english: return "10 seconds"
        case .spanish: return "10 segundos"
        case .chinese: return "10 秒"
        case .japanese: return "10秒"
        }
    }
    
    static var seconds30: String {
        switch lang {
        case .english: return "30 seconds"
        case .spanish: return "30 segundos"
        case .chinese: return "30 秒"
        case .japanese: return "30秒"
        }
    }
    
    static var minute1: String {
        switch lang {
        case .english: return "1 minute"
        case .spanish: return "1 minuto"
        case .chinese: return "1 分钟"
        case .japanese: return "1分"
        }
    }
    
    static var minutes5: String {
        switch lang {
        case .english: return "5 minutes"
        case .spanish: return "5 minutos"
        case .chinese: return "5 分钟"
        case .japanese: return "5分"
        }
    }
    
    static var never: String {
        switch lang {
        case .english: return "Never"
        case .spanish: return "Nunca"
        case .chinese: return "从不"
        case .japanese: return "なし"
        }
    }
    
    static var unknownDevice: String {
        switch lang {
        case .english: return "Unknown Device (Disconnected)"
        case .spanish: return "Dispositivo desconocido (Desconectado)"
        case .chinese: return "未知设备（已断开）"
        case .japanese: return "不明なデバイス（切断済み）"
        }
    }
    
    static var mouseClickSound: String {
        switch lang {
        case .english: return "Play sound for mouse clicks"
        case .spanish: return "Reproducir sonido para clics del ratón"
        case .chinese: return "播放鼠标点击声音"
        case .japanese: return "マウスクリックのサウンドを再生"
        }
    }
    
    // MARK: - Shortcuts
    static var global: String {
        switch lang {
        case .english: return "Global"
        case .spanish: return "Global"
        case .chinese: return "全局"
        case .japanese: return "グローバル"
        }
    }
    
    static var toggleThock: String {
        switch lang {
        case .english: return "Toggle Thock"
        case .spanish: return "Alternar Thock"
        case .chinese: return "开关 Thock"
        case .japanese: return "Thockの切り替え"
        }
    }
    
    static var toggleThockSubtitle: String {
        switch lang {
        case .english: return "Quickly enable or disable Thock from anywhere"
        case .spanish: return "Activa o desactiva Thock rápidamente desde cualquier lugar"
        case .chinese: return "从任意位置快速启用或禁用 Thock"
        case .japanese: return "どこからでもThockを素早く有効/無効にする"
        }
    }
    
    // MARK: - Menu Bar
    static var pitch: String {
        switch lang {
        case .english: return "Pitch Variation"
        case .spanish: return "Variación de tono"
        case .chinese: return "音调变化"
        case .japanese: return "ピッチの変化"
        }
    }
    
    static var pitchTooltip: String {
        switch lang {
        case .english: return "Each keystroke detunes itself a little - ± your chosen value. Keeps things human. Or haunted."
        case .spanish: return "Cada pulsación de tecla se desajusta un poco, ± el valor que elijas. Mantiene las cosas humanas. O embrujadas."
        case .chinese: return "每次按键都会产生轻微的音调变化 - ± 您选择的值。让声音更自然，或者更诡异。"
        case .japanese: return "各キー入力が少しずつ音程を変える - ±選択した値。より人間らしく。または不気味に。"
        }
    }
    
    static var quit: String {
        switch lang {
        case .english: return "Quit"
        case .spanish: return "Salir"
        case .chinese: return "退出"
        case .japanese: return "終了"
        }
    }
    
    static var version: String {
        switch lang {
        case .english: return "Version"
        case .spanish: return "Versión"
        case .chinese: return "版本"
        case .japanese: return "バージョン"
        }
    }
    
    static var quickSettings: String {
        switch lang {
        case .english: return "Quick Options..."
        case .spanish: return "Opciones..."
        case .chinese: return "快捷选项..."
        case .japanese: return "クイックオプション..."
        }
    }
    
    static var settings: String {
        switch lang {
        case .english: return "Settings..."
        case .spanish: return "Configuración..."
        case .chinese: return "设置..."
        case .japanese: return "設定..."
        }
    }
    
    static var releaseNotes: String {
        switch lang {
        case .english: return "About this version"
        case .spanish: return "Acerca de esta versión"
        case .chinese: return "关于此版本"
        case .japanese: return "このバージョンについて"
        }
    }
    
    static var updateAvailable: String {
        switch lang {
        case .english: return "New Version Is Available!"
        case .spanish: return "¡Está disponible una nueva versión!"
        case .chinese: return "有新版本可用！"
        case .japanese: return "新しいバージョンが利用可能です！"
        }
    }
    
    static var updateNow: String {
        switch lang {
        case .english: return "↺ Update Now"
        case .spanish: return "↺ Actualizar ahora"
        case .chinese: return "↺ 立即更新"
        case .japanese: return "↺ 今すぐ更新"
        }
    }
    
    static var checkForUpdates: String {
        switch lang {
        case .english: return "Check for updates..."
        case .spanish: return "Buscar actualizaciones..."
        case .chinese: return "检查更新..."
        case .japanese: return "アップデートを確認..."
        }
    }
    
    static var updateAvailableTitle: String {
        switch lang {
        case .english: return "Update Available!"
        case .spanish: return "¡Actualización disponible!"
        case .chinese: return "有更新可用！"
        case .japanese: return "アップデートが利用可能です！"
        }
    }
    
    static var updateAvailableMessage: String {
        switch lang {
        case .english: return "A new version of Thock is available. Check the menu bar for the update option."
        case .spanish: return "Está disponible una nueva versión de Thock. Revisa la barra de menú para ver la opción de actualización."
        case .chinese: return "Thock 有新版本可用。请在菜单栏中查找更新选项。"
        case .japanese: return "Thockの新しいバージョンが利用可能です。メニューバーで更新オプションを確認してください。"
        }
    }
    
    static var noUpdatesTitle: String {
        switch lang {
        case .english: return "No Updates Available"
        case .spanish: return "No hay actualizaciones disponibles"
        case .chinese: return "没有可用的更新"
        case .japanese: return "利用可能なアップデートはありません"
        }
    }
    
    static var noUpdatesMessage: String {
        switch lang {
        case .english: return "You're already running the latest version of Thock."
        case .spanish: return "Ya estás usando la última versión de Thock."
        case .chinese: return "您已经在运行最新版本的 Thock。"
        case .japanese: return "すでに最新バージョンのThockを実行しています。"
        }
    }
    
    static var updateCheckFailed: String {
        switch lang {
        case .english: return "Update Check Failed"
        case .spanish: return "Error al buscar actualizaciones"
        case .chinese: return "检查更新失败"
        case .japanese: return "アップデートの確認に失敗しました"
        }
    }
    
    static var ok: String {
        switch lang {
        case .english: return "OK"
        case .spanish: return "OK"
        case .chinese: return "好"
        case .japanese: return "OK"
        }
    }
    
    // MARK: - Permissions
    static var permissionRequired: String {
        switch lang {
        case .english: return "Accessibility Permissions Required"
        case .spanish: return "Se requieren permisos de accesibilidad"
        case .chinese: return "需要辅助功能权限"
        case .japanese: return "アクセシビリティ権限が必要です"
        }
    }
    
    static var permissionMessage: String {
        switch lang {
        case .english: return "Thock needs accessibility permissions to detect keyboard input and play sounds.\n\nClick 'Open System Settings' below, then enable Thock in the Accessibility list."
        case .spanish: return "Thock necesita permisos de accesibilidad para detectar la entrada del teclado y reproducir sonidos.\n\nHaz clic en 'Abrir Configuración del sistema' más abajo y luego activa Thock en la lista de Accesibilidad."
        case .chinese: return "Thock 需要辅助功能权限来检测键盘输入并播放声音。\n\n请点击下方的「打开系统设置」，然后在辅助功能列表中启用 Thock。"
        case .japanese: return "Thockはキーボード入力を検出してサウンドを再生するためにアクセシビリティ権限が必要です。\n\n下の「システム設定を開く」をクリックし、アクセシビリティリストでThockを有効にしてください。"
        }
    }
    
    static var openSystemSettings: String {
        switch lang {
        case .english: return "Open System Settings"
        case .spanish: return "Abrir Ajustes"
        case .chinese: return "打开系统设置"
        case .japanese: return "システム設定を開く"
        }
    }
    
    static var permissionRefresh: String {
        switch lang {
        case .english: return "Accessibility Permission Refresh"
        case .spanish: return "Actualizar permisos"
        case .chinese: return "辅助功能权限刷新"
        case .japanese: return "アクセシビリティ権限の更新"
        }
    }
    
    static var permissionRefreshMessage: String {
        switch lang {
        case .english: return "Annoying update step ahead!\nWe'd automate this if we could, but it requires the $100 Apple Developer Program.\n\n1. Remove the old Thock entry from Accessibility and quit the app.\n2. Reopen Thock and enable the new entry that appears."
        case .spanish: return "¡Molesto paso de actualización!\nRequiere el Apple Developer Program de $100.\n\n1. Quita Thock de Accesibilidad y cierra la app.\n2. Reabre Thock y activa la nueva entrada."
        case .chinese: return "恼人的更新步骤！\n如果可以的话我们会自动完成这一步，但这需要 $100 的 Apple 开发者计划。\n\n1. 从辅助功能中移除旧的 Thock 条目并退出应用。\n2. 重新打开 Thock 并启用出现的新条目。"
        case .japanese: return "面倒なアップデート手順です！\n自動化したいのですが、$100のApple Developer Programが必要です。\n\n1. アクセシビリティから古いThockエントリを削除してアプリを終了します。\n2. Thockを再度開き、表示される新しいエントリを有効にします。"
        }
    }
    
    static var done: String {
        switch lang {
        case .english: return "Done"
        case .spanish: return "Listo"
        case .chinese: return "完成"
        case .japanese: return "完了"
        }
    }
    
    static var quitThock: String {
        switch lang {
        case .english: return "Quit Thock"
        case .spanish: return "Salir de Thock"
        case .chinese: return "退出 Thock"
        case .japanese: return "Thockを終了"
        }
    }
    
    static var waitingForPermissions: String {
        switch lang {
        case .english: return "Waiting for permissions..."
        case .spanish: return "Esperando permisos..."
        case .chinese: return "等待权限授予..."
        case .japanese: return "権限を待っています..."
        }
    }
}

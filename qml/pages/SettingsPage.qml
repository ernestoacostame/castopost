import castopost
import QtQuick
import QtQuick.Controls.Material
import QtQuick.Layouts

Page {
    id: root
    background: Rectangle { color: theme.bgBase }

    // Referencia a la ventana principal para acceder al tema
    Component.onCompleted: {
        let s = App.loadSettings()
        urlField.text    = s.instanceUrl   || ""
        userField.text   = s.apiUser       || ""
        passField.text   = s.apiPassword   || ""
        handleField.text = s.defaultHandle || ""
        userIdField.text = s.userId > 0 ? s.userId.toString() : "1"
        
    }

    header: ToolBar {
        Material.background: theme.bgHeader
        Label {
            anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
            text: App.configured ? "Ajustes" : "Bienvenido a CastoPOST"
            font.pixelSize: 15; font.bold: true; color: "white"
        }
    }

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        Column {
            width: Math.min(parent.width - 40, 560)
            anchors.horizontalCenter: parent.horizontalCenter
            topPadding: 28; bottomPadding: 28
            spacing: 14

            // ── Apariencia ────────────────────────────────────
            Label { text: "APARIENCIA"; color: theme.textMuted; font.pixelSize: 10; font.letterSpacing: 1.5 }

            Row {
                spacing: 8

                Repeater {
                    model: [
                        { label: "🌙  Oscuro", mode: 0 },
                        { label: "☀  Claro",  mode: 1 }
                    ]
                    Button {
                        required property var modelData
                        text: modelData.label
                        highlighted: theme.mode === modelData.mode
                        flat: theme.mode !== modelData.mode
                        Material.accent: Material.DeepPurple
                        onClicked: theme.mode = modelData.mode
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: theme.border }

            // ── Conexión ──────────────────────────────────────
            Label { text: "INSTANCIA CASTOPOD"; color: theme.textMuted; font.pixelSize: 10; font.letterSpacing: 1.5 }

            Label { text: "URL de la instancia"; color: theme.textSecondary; font.pixelSize: 11 }
            TextField { id: urlField; width: parent.width; placeholderText: "https://podcasts.tudominio.com"; Material.accent: Material.DeepPurple }

            Label { text: "Usuario API"; color: theme.textSecondary; font.pixelSize: 11 }
            TextField { id: userField; width: parent.width; placeholderText: "restapi.basicAuth user"; Material.accent: Material.DeepPurple }

            Label { text: "Contraseña API"; color: theme.textSecondary; font.pixelSize: 11 }
            TextField { id: passField; width: parent.width; echoMode: TextInput.Password; placeholderText: "restapi.basicAuth password"; Material.accent: Material.DeepPurple }

            Rectangle { width: parent.width; height: 1; color: theme.border }
            Label { text: "PODCAST POR DEFECTO"; color: theme.textMuted; font.pixelSize: 10; font.letterSpacing: 1.5 }

            Label { text: "Handle del podcast"; color: theme.textSecondary; font.pixelSize: 11 }
            TextField { id: handleField; width: parent.width; placeholderText: "mi-podcast"; Material.accent: Material.DeepPurple }

            Label { text: "ID de usuario (Castopod)"; color: theme.textSecondary; font.pixelSize: 11 }
            TextField { id: userIdField; width: parent.width; placeholderText: "1"; inputMethodHints: Qt.ImhDigitsOnly; Material.accent: Material.DeepPurple }

            // ── FFmpeg ────────────────────────────────────────
            Rectangle {
                width: parent.width; height: 40; radius: 8
                color: App.ffmpegAvailable() ? "#1b3a20" : theme.warningBg
                border.color: App.ffmpegAvailable() ? "#2e7d32" : "#bf360c"
                Label {
                    anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                    text: App.ffmpegAvailable() ? "✓ FFmpeg disponible" : "✕ FFmpeg no encontrado — sudo apt install ffmpeg"
                    color: App.ffmpegAvailable() ? "#a5d6a7" : theme.warning; font.pixelSize: 11
                }
            }

            // ── Configuración de audio ──────────────────────────────────
            Label { 
                text: "AUDIO"; 
                color: theme.textMuted; 
                font.pixelSize: 10; 
                font.letterSpacing: 1.5 
            }

            Row {
                width: parent.width
                spacing: 12
                
                Column {
                    width: Math.floor(parent.width / 2) - 6
                    
                    Label { 
                        text: "Normalización LUFS predeterminada"; 
                        color: theme.textSecondary; 
                        font.pixelSize: 11 
                    }
                    
                    ComboBox {
                        id: defaultLufsCombo
                        width: parent.width
                        model: [
                            {text: "-14 LUFS (más fuerte)", value: -14},
                            {text: "-16 LUFS (estándar)", value: -16},
                            {text: "-18 LUFS (más suave)", value: -18},
                            {text: "-24 LUFS (EBU)", value: -24}
                        ]
                        textRole: "text"
                        valueRole: "value"
                            
                        Component.onCompleted: {
                            // Load current setting
                            let settings = App.loadSettings()
                            let current = settings.lufsTarget || -16
                            for (let i = 0; i < model.length; i++) {
                                if (model[i].value === current) {
                                    currentIndex = i
                                    break
                                }
                            }
                        }
                            
                        onActivated: {
                            App.setLufsTarget(currentValue)
                        }
                    }
                        
                    Label {
                        text: {
                            switch(defaultLufsCombo.currentValue) {
                                case -14: return "Para contenido más fuerte (música, etc.)"
                                case -16: return "Estándar de podcast (recomendado)"
                                case -18: return "Para contenido más suave"
                                case -24: return "Estándar EBU para broadcast"
                                default: return ""
                            }
                        }
                        color: theme.textMuted
                        font.pixelSize: 10
                        wrapMode: Text.WordWrap
                        width: parent.width
                        topPadding: 4
                    }
                }
                
                // You could add more audio settings here in the future
                Column {
                    width: Math.floor(parent.width / 2) - 6
                    // Placeholder for future audio settings
                }
            }

            Button {
                width: parent.width; height: 48
                text: App.configured ? "Guardar ajustes" : "Guardar y comenzar"
                font.pixelSize: 14; font.bold: true
                enabled: urlField.text.trim().length > 0 && userField.text.trim().length > 0
                Material.background: "#6200ee"; Material.foreground: "white"
                onClicked: App.saveSettings(
                    urlField.text.trim(), userField.text.trim(), passField.text,
                    handleField.text.trim(), parseInt(userIdField.text) || 1)
            }
        }
    }
}

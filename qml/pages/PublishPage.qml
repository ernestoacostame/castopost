import castopost
import QtQuick
import QtQuick.Controls.Material
import QtQuick.Layouts
import Qt.labs.platform as Platform

Page {
    id: root
    background: Rectangle { color: theme.bgBase }

    property string audioFilePath: ""
    property string coverFilePath: ""
    property string draftId:       ""

    // true cuando el audio viene de un borrador guardado (no grabado en esta sesión)
    property bool hasSavedAudio: false
    property string savedAudioName: ""

    function loadDraft(id) {
        draftId = id
        let d = App.getDraft(id)
        if (!d) return
        titleField.text        = d.title        || ""
        descField.text         = d.description  || ""
        slugField.text         = d.slug         || ""
        epNumField.text        = d.episodeNumber > 0 ? d.episodeNumber.toString() : ""
        seasonField.text       = d.seasonNumber  > 0 ? d.seasonNumber.toString()  : ""
        typeCombo.currentIndex = ["full","trailer","bonus"].indexOf(d.type || "full")
        explicitCheck.checked  = d.isExplicit === true || d.isExplicit === "1"

        // Cargar audio guardado si existe y el archivo sigue en disco
        let savedPath = d.audioFilePath || ""
        let savedUrl  = d.audioUrl      || ""
        if (savedPath !== "") {
            root.audioFilePath  = savedPath
            root.hasSavedAudio  = true
            root.savedAudioName = savedPath.split("/").pop()
            // Activar la pestaña correcta según el tipo de audio
            audioTabs.currentIndex = 1   // Subir archivo
        } else if (savedUrl !== "") {
            root.audioFilePath  = ""
            root.hasSavedAudio  = true
            root.savedAudioName = savedUrl
            audioTabs.currentIndex = 2   // URL
            urlField.text = savedUrl
        } else {
            root.hasSavedAudio  = false
            root.savedAudioName = ""
        }
    }

    header: ToolBar {
        Material.background: theme.bgHeader
        RowLayout {
            anchors { fill: parent; leftMargin: 16; rightMargin: 8 }
            Label {
                text: "Publicar episodio"
                font.pixelSize: 15; font.bold: true; color: "white"
                Layout.fillWidth: true
            }
            ToolButton {
                text: "Borrador"; font.pixelSize: 12
                ToolTip.text: "Guardar borrador local"; ToolTip.visible: hovered
                onClicked: saveDraft()
            }
        }
    }

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        Column {
            width: Math.min(parent.width - 40, 700)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12
            topPadding: 16
            bottomPadding: 30

            // ── Cabecera audio ────────────────────────────────
            Label {
                text: "AUDIO *"
                color: theme.accentLight
                font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.5
            }

            // Banner: audio guardado en el borrador
            Rectangle {
                width: parent.width
                height: visible ? 48 : 0
                visible: root.hasSavedAudio && root.audioFilePath !== "" || root.hasSavedAudio && audioTabs.currentIndex === 2
                radius: 8
                color: theme.successBg
                border.color: "#2e7d32"; border.width: 1

                Row {
                    anchors { left: parent.left; right: parent.right; leftMargin: 12; rightMargin: 8; verticalCenter: parent.verticalCenter }
                    spacing: 8

                    Label {
                        text: "✓"
                        color: theme.success; font.pixelSize: 14; font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Label {
                        text: root.savedAudioName
                        color: "#a5d6a7"; font.pixelSize: 11
                        elide: Text.ElideLeft
                        width: parent.width - replaceBtn.implicitWidth - 40
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Button {
                        id: replaceBtn
                        text: "Reemplazar"
                        flat: true; font.pixelSize: 11
                        Material.foreground: "#ef9a9a"
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: {
                            root.hasSavedAudio  = false
                            root.savedAudioName = ""
                            root.audioFilePath  = ""
                            recorderWidget.recordedFilePath = ""
                            audioTabs.currentIndex = 0
                        }
                    }
                }
            }

            TabBar {
                id: audioTabs
                width: parent.width
                currentIndex: 0
                Material.accent: Material.DeepPurple
                TabButton { text: "⏺  Grabar"        }
                TabButton { text: "📁  Subir archivo" }
                TabButton { text: "🔗  URL remota"    }
            }

            // ── Pestaña 0: Grabar ─────────────────────────────
            AudioRecorderWidget {
                id: recorderWidget
                width: parent.width
                visible: audioTabs.currentIndex === 0
                height: visible ? implicitHeight : 0
                onFileReady: (path) => root.audioFilePath = path
            }

            // ── Pestaña 1: Subir archivo ──────────────────────
            Column {
                width: parent.width
                spacing: 8
                visible: audioTabs.currentIndex === 1
                height: visible ? implicitHeight : 0

                Rectangle {
                    width: parent.width
                    height: 80
                    radius: 8
                    color:  dropArea.containsDrag ? "#2d1f5e" : theme.bgInput
                    border.color: dropArea.containsDrag ? theme.accentLight : "#3d3d6b"
                    border.width: dropArea.containsDrag ? 2 : 1
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 4
                        visible: root.audioFilePath === ""
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Arrastra un archivo de audio aquí"
                            color: theme.textMuted; font.pixelSize: 12
                        }
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "MP3, WAV, FLAC, OGG, M4A, OPUS…"
                            color: theme.textMuted; font.pixelSize: 10
                        }
                    }
                    Label {
                        visible: root.audioFilePath !== ""
                        anchors.centerIn: parent
                        text: "✓ " + root.audioFilePath.split("/").pop()
                        color: theme.success; font.pixelSize: 12
                        elide: Text.ElideLeft
                        width: parent.width - 24
                        horizontalAlignment: Text.AlignHCenter
                    }
                    DropArea {
                        id: dropArea
                        anchors.fill: parent
                        keys: ["text/uri-list"]
                        onDropped: (drop) => {
                            root.audioFilePath = drop.urls[0].toString().replace("file://","")
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: audioFileDialog.open()
                    }
                }

                Row {
                    width: parent.width
                    spacing: 8
                    TextField {
                        width: parent.width - examBtn.width - 8
                        placeholderText: "O escribe la ruta manualmente"
                        text: root.audioFilePath
                        onTextChanged: root.audioFilePath = text
                        Material.accent: Material.DeepPurple
                    }
                    Button {
                        id: examBtn
                        text: "Examinar…"
                        onClicked: audioFileDialog.open()
                        Material.background: "#2d2d5e"
                    }
                }
            }

            // ── Pestaña 2: URL ────────────────────────────────
            TextField {
                id: urlField
                width: parent.width
                visible: audioTabs.currentIndex === 2
                height: visible ? implicitHeight : 0
                placeholderText: "https://…/episodio.mp3"
                Material.accent: Material.DeepPurple
            }

            // Aviso FFmpeg
            Rectangle {
                visible: !App.ffmpegAvailable()
                width: parent.width
                height: visible ? 34 : 0
                radius: 6; color: theme.warningBg
                Label {
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    text: "⚠ FFmpeg no encontrado — sudo apt install ffmpeg"
                    color: theme.warning; font.pixelSize: 11
                }
            }

            Rectangle { width: parent.width; height: 1; color: theme.border }

            // ── Título ────────────────────────────────────────
            Label { text: "Título *"; color: theme.textSecondary; font.pixelSize: 11 }
            TextField {
                id: titleField
                width: parent.width
                placeholderText: "Título del episodio"
                Material.accent: Material.DeepPurple
            }

            // ── Números + Tipo ────────────────────────────────
            Row {
                width: parent.width
                spacing: 12
                Column {
                    width: Math.floor((parent.width - 142) / 2)
                    Label { text: "Nº Episodio"; color: theme.textSecondary; font.pixelSize: 11 }
                    TextField {
                        id: epNumField
                        width: parent.width
                        // Se rellena automáticamente con el siguiente número
                        text: App.nextEpisodeNumber.toString()
                        inputMethodHints: Qt.ImhDigitsOnly
                        validator: IntValidator { bottom: 1 }
                        Material.accent: Material.DeepPurple
                    }
                }
                Column {
                    width: Math.floor((parent.width - 142) / 2)
                    Label { text: "Temporada"; color: theme.textSecondary; font.pixelSize: 11 }
                    TextField {
                        id: seasonField
                        width: parent.width
                        placeholderText: "—"
                        inputMethodHints: Qt.ImhDigitsOnly
                        validator: IntValidator { bottom: 1 }
                        Material.accent: Material.DeepPurple
                        onTextChanged: {
                            let s = parseInt(text) || 0
                            epNumField.text = App.nextEpisodeForSeason(s).toString()
                        }
                    }
                }
                Column {
                    width: 130
                    Label { text: "Tipo"; color: theme.textSecondary; font.pixelSize: 11 }
                    ComboBox {
                        id: typeCombo
                        width: parent.width
                        model: ["full", "trailer", "bonus"]
                        Material.accent: Material.DeepPurple
                    }
                }
            }

            // ── Descripción ───────────────────────────────────
            Item {
                width: parent.width
                height: 24
                Label {
                    text: "Descripción (Markdown soportado)"
                    color: theme.textSecondary; font.pixelSize: 11
                    anchors.verticalCenter: parent.verticalCenter
                }
                ToolButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "⊞ Plantilla"; font.pixelSize: 11
                    onClicked: templateDialog.open()
                }
            }
            TextArea {
                id: descField
                width: parent.width
                height: 130
                wrapMode: TextArea.WrapAtWordBoundaryOrAnywhere
                verticalAlignment: TextEdit.AlignTop
                topPadding: 8
                leftPadding: 8
                rightPadding: 8
                Material.accent: Material.DeepPurple
                background: Rectangle {
                    color: theme.bgSurface; radius: 4
                    border.color: descField.activeFocus ? theme.accent : theme.border
                }
            }

            // ── Slug ──────────────────────────────────────────
            Label { text: "Slug (opcional)"; color: theme.textSecondary; font.pixelSize: 11 }
            TextField {
                id: slugField
                width: parent.width
                placeholderText: "se-genera-automaticamente"
                Material.accent: Material.DeepPurple
            }

            // ── Explícito + fecha ─────────────────────────────
            Row {
                width: parent.width
                spacing: 8
                CheckBox {
                    id: explicitCheck
                    text: "Contenido explícito"
                    anchors.verticalCenter: parent.verticalCenter
                    Material.accent: Material.DeepPurple
                }
                Label {
                    text: "Publicar el:"
                    color: theme.textSecondary; font.pixelSize: 11
                    anchors.verticalCenter: parent.verticalCenter
                }
                TextField {
                    id: pubDateField
                    width: parent.width - explicitCheck.width - pubLabel.width - 16
                    placeholderText: "yyyy-MM-ddTHH:mm (vacío = ahora)"
                    Material.accent: Material.DeepPurple
                    Label { id: pubLabel; visible: false; text: "Publicar el:" }
                }
            }

            Rectangle { width: parent.width; height: 1; color: theme.border }

            // ── Portada ───────────────────────────────────────
            Label { text: "PORTADA (opcional)"; color: "#7070b0"; font.pixelSize: 10; font.letterSpacing: 1 }

            Row {
                width: parent.width
                spacing: 8
                TextField {
                    width: parent.width - coverBtn.width - (coverPreview.visible ? 56 : 0) - 16
                    placeholderText: "Ninguna imagen seleccionada"
                    readOnly: true; text: root.coverFilePath
                    Material.accent: Material.DeepPurple
                }
                Button {
                    id: coverBtn
                    text: "Examinar…"
                    onClicked: coverFileDialog.open()
                    Material.background: "#2d2d5e"
                }
                Rectangle {
                    id: coverPreview
                    width: 48; height: 48; radius: 4; color: theme.bgInput
                    visible: root.coverFilePath !== ""
                    Image {
                        anchors.fill: parent
                        source: root.coverFilePath !== "" ? "file://" + root.coverFilePath : ""
                        fillMode: Image.PreserveAspectCrop
                    }
                }
            }

            // ── Publicar ──────────────────────────────────────
            Button {
                width: parent.width
                text: "⬆  Publicar episodio"
                font.pixelSize: 14; font.bold: true
                height: 48
                enabled: !App.busy && titleField.text.trim().length > 0
                Material.background: enabled ? "#6200ee" : "#333355"
                Material.foreground: "white"
                onClicked: publish()
            }
        }
    }

    Platform.FileDialog {
        id: audioFileDialog
        title: "Seleccionar archivo de audio"
        nameFilters: ["Audio (*.mp3 *.wav *.ogg *.flac *.m4a *.opus *.webm *.aac)", "Todos (*)"]
        onAccepted: root.audioFilePath = file.toString().replace("file://", "")
    }
    Platform.FileDialog {
        id: coverFileDialog
        title: "Seleccionar portada"
        nameFilters: ["Imágenes (*.jpg *.jpeg *.png *.webp)", "Todos (*)"]
        onAccepted: root.coverFilePath = file.toString().replace("file://", "")
    }
    TemplatePickerDialog {
        id: templateDialog
        onTemplateSelected: (body) => {
            descField.text = descField.text.trim().length > 0
                             ? descField.text + "\n\n" + body : body
        }
    }

    function publish() {
        let epNum = parseInt(epNumField.text)
        if (isNaN(epNum) || epNum < 1) epNum = App.nextEpisodeNumber
        App.publishEpisode({
            title:         titleField.text.trim(),
            description:   descField.text,
            slug:          slugField.text.trim(),
            episodeNumber: epNum,
            seasonNumber:  parseInt(seasonField.text) || 0,
            type:          typeCombo.currentText,
            isExplicit:    explicitCheck.checked,
            publishedAt:   pubDateField.text.trim(),
            audioUrl:      audioTabs.currentIndex === 2 ? urlField.text.trim() : "",
        },
        audioTabs.currentIndex !== 2 ? root.audioFilePath : "",
        root.coverFilePath)
    }

    function saveDraft() {
        let savedId = App.saveDraft({
            draft_id:      root.draftId,
            title:         titleField.text.trim(),
            description:   descField.text,
            slug:          slugField.text.trim(),
            episodeNumber: parseInt(epNumField.text) || 0,
            seasonNumber:  parseInt(seasonField.text) || 0,
            type:          typeCombo.currentText,
            isExplicit:    explicitCheck.checked,
            // Guardar referencia al audio
            audioFilePath: audioTabs.currentIndex !== 2 ? root.audioFilePath : "",
            audioUrl:      audioTabs.currentIndex === 2 ? urlField.text.trim() : "",
        })
        root.draftId = savedId
    }

    function reset() {
        titleField.text = ""; descField.text = ""
        slugField.text  = ""
        epNumField.text = App.nextEpisodeNumber.toString()
        seasonField.text = ""; pubDateField.text = ""
        explicitCheck.checked = false; typeCombo.currentIndex = 0
        root.audioFilePath = ""; root.coverFilePath = ""
        root.draftId = ""; root.hasSavedAudio = false
        root.savedAudioName = ""
        recorderWidget.recordedFilePath = ""
    }

    // Actualizar el número si cambia mientras la página está abierta
    Connections {
        target: App
        function onEpisodePublishedOk() { root.reset() }
        function onEpisodesChanged() {
            // Solo actualizar si el usuario no ha tocado el campo
            if (root.draftId === "")
                epNumField.text = App.nextEpisodeNumber.toString()
        }
    }
}

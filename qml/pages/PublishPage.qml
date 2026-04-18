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
        
        // Load LUFS setting if saved in draft
        if (d.lufsTarget !== undefined) {
            App.setLufsTarget(d.lufsTarget)
            // Update combo box
            for (let i = 0; i < lufsCombo.model.length; i++) {
                if (lufsCombo.model[i].value === d.lufsTarget) {
                    lufsCombo.currentIndex = i
                    break
                }
            }
            if (lufsCombo.currentIndex === -1) {
                // Custom value
                lufsCombo.currentIndex = 4
                customLufsField.text = d.lufsTarget
            }
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
                visible: root.hasSavedAudio && (root.audioFilePath !== "" || audioTabs.currentIndex === 2)
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
                            urlField.text = ""
                            recorderWidget.recordedFilePath = ""
                            audioTabs.currentIndex = 0
                        }
                    }
                }
                
                // Mover el MouseArea fuera del Row para evitar superposición
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    // Solo activo cuando no hay audio seleccionado (para diálogo de archivo)
                    enabled: !root.hasSavedAudio && root.audioFilePath === ""
                    onClicked: audioFileDialog.open()
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
                        // Se rellena automáticamente con el siguiente número para la temporada seleccionada
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
                        text: "1"
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
            ScrollView {
                width: parent.width
                height: 130
                clip: true
                
                TextArea {
                    id: descField
                    width: parent.width - 20  // Dejar espacio para la barra de scroll
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

            Rectangle { width: parent.width; height: 1; color: theme.border }

            // ── Configuración de normalización ──────────────────────────
            Rectangle {
                width: parent.width
                height: visible ? lufsContainer.height + 20 : 0
                visible: !App.ffmpegAvailable() ? false : (audioTabs.currentIndex !== 2)
                color: "transparent"
                
                Column {
                    id: lufsContainer
                    width: parent.width
                    spacing: 8
                    
                    Label {
                        text: "Normalización LUFS"
                        color: theme.accentLight
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 1.5
                    }
                    
                    Rectangle {
                        width: parent.width
                        implicitHeight: contentColumn.implicitHeight + 24
                        radius: 8
                        color: theme.bgInput
                        border.color: theme.border
                        border.width: 1
                        clip: true

                        Column {
                            id: contentColumn
                            width: parent.width
                            spacing: 6
                            padding: 12

                            // Descripción
                            Label {
                                width: parent.width
                                text: "Selecciona el nivel objetivo de normalización loudness para el audio:"
                                color: theme.textSecondary
                                font.pixelSize: 11
                                wrapMode: Text.WordWrap
                            }
                            
                            // Botones para valores predefinidos
                            Row {
                                width: parent.width
                                spacing: 8
                                
                                // Botón -14
                                Rectangle {
                                    width: 48
                                    height: 32
                                    radius: 4
                                    color: App.lufsTarget === -14 ? "#6200ee" : theme.bgSurface
                                    border.color: App.lufsTarget === -14 ? "#6200ee" : theme.border
                                    border.width: 1
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: "-14"
                                        color: App.lufsTarget === -14 ? "white" : theme.textPrimary
                                        font.pixelSize: 12
                                        font.bold: App.lufsTarget === -14
                                    }
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: App.setLufsTarget(-14)
                                    }
                                }
                                
                                // Botón -16
                                Rectangle {
                                    width: 48
                                    height: 32
                                    radius: 4
                                    color: App.lufsTarget === -16 ? "#6200ee" : theme.bgSurface
                                    border.color: App.lufsTarget === -16 ? "#6200ee" : theme.border
                                    border.width: 1
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: "-16"
                                        color: App.lufsTarget === -16 ? "white" : theme.textPrimary
                                        font.pixelSize: 12
                                        font.bold: App.lufsTarget === -16
                                    }
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: App.setLufsTarget(-16)
                                    }
                                }
                                
                                // Botón -18
                                Rectangle {
                                    width: 48
                                    height: 32
                                    radius: 4
                                    color: App.lufsTarget === -18 ? "#6200ee" : theme.bgSurface
                                    border.color: App.lufsTarget === -18 ? "#6200ee" : theme.border
                                    border.width: 1
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: "-18"
                                        color: App.lufsTarget === -18 ? "white" : theme.textPrimary
                                        font.pixelSize: 12
                                        font.bold: App.lufsTarget === -18
                                    }
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: App.setLufsTarget(-18)
                                    }
                                }
                                
                                // Botón -24
                                Rectangle {
                                    width: 48
                                    height: 32
                                    radius: 4
                                    color: App.lufsTarget === -24 ? "#6200ee" : theme.bgSurface
                                    border.color: App.lufsTarget === -24 ? "#6200ee" : theme.border
                                    border.width: 1
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: "-24"
                                        color: App.lufsTarget === -24 ? "white" : theme.textPrimary
                                        font.pixelSize: 12
                                        font.bold: App.lufsTarget === -24
                                    }
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: App.setLufsTarget(-24)
                                    }
                                }
                                
                                // Campo de texto para valor personalizado
                                TextField {
                                    id: customLufsField
                                    width: Math.min(Math.max(parent.width - 4*48 - 4*8, 120), 200)
                                    height: 32
                                    placeholderText: "otro valor"
                                    inputMethodHints: Qt.ImhDigitsOnly | Qt.ImhSignedNumbers
                                    validator: IntValidator { bottom: -24; top: -14 }
                                    
                                    // Mostrar el valor personalizado actual
                                    Component.onCompleted: {
                                        let target = App.lufsTarget
                                        if (target !== -14 && target !== -16 && target !== -18 && target !== -24) {
                                            text = target.toString()
                                        }
                                    }
                                    
                                    onEditingFinished: {
                                        if (text !== "") {
                                            let value = parseInt(text)
                                            if (!isNaN(value) && value >= -24 && value <= -14) {
                                                App.setLufsTarget(value)
                                            } else {
                                                // Si el valor no es válido, restaurar el actual
                                                text = App.lufsTarget.toString()
                                            }
                                        }
                                    }
                                    
                                    // Actualizar el campo cuando cambia el valor desde otro lugar
                                    Connections {
                                        target: App
                                        function onLufsTargetChanged() {
                                            let target = App.lufsTarget
                                            if (target === -14 || target === -16 || target === -18 || target === -24) {
                                                customLufsField.text = ""
                                            } else {
                                                customLufsField.text = target.toString()
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // Descripción del valor seleccionado
                            Label {
                                width: parent.width
                                text: {
                                    switch(App.lufsTarget) {
                                        case -14: return "• -14 LUFS: Para contenido más fuerte (música, promociones, etc.)"
                                        case -16: return "• -16 LUFS: Estándar recomendado para podcasts (balance óptimo)"
                                        case -18: return "• -18 LUFS: Para contenido más suave (conversación tranquila, ASMR)"
                                        case -24: return "• -24 LUFS: Estándar EBU R128 para broadcast televisivo/radio"
                                        default: return "• " + App.lufsTarget + " LUFS: Valor personalizado"
                                    }
                                }
                                color: theme.textMuted
                                font.pixelSize: 10
                                wrapMode: Text.WordWrap
                                topPadding: 4
                            }
                        }
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
            lufsTarget:    App.lufsTarget, // Save LUFS target
            // Guardar referencia al audio
            audioFilePath: audioTabs.currentIndex !== 2 ? root.audioFilePath : "",
            audioUrl:      audioTabs.currentIndex === 2 ? urlField.text.trim() : "",
        })
        root.draftId = savedId
    }

    function reset() {
        titleField.text = ""; descField.text = ""
        slugField.text  = ""
        seasonField.text = "1"; pubDateField.text = ""
        explicitCheck.checked = false; typeCombo.currentIndex = 0
        root.audioFilePath = ""; root.coverFilePath = ""
        root.draftId = ""; root.hasSavedAudio = false
        root.savedAudioName = ""
        recorderWidget.recordedFilePath = ""
        // Update episode number for default season
        var s = parseInt(seasonField.text) || 0;
        epNumField.text = App.nextEpisodeForSeason(s);
    }

    Component.onCompleted: {
        // Set initial episode number based on default season
        var s = parseInt(seasonField.text) || 0;
        epNumField.text = App.nextEpisodeForSeason(s);
    }

    // Actualizar el número si cambia mientras la página está abierta
    Connections {
        target: App
        function onEpisodePublishedOk() { root.reset() }
        function onEpisodesChanged() {
            // Solo actualizar si el usuario no ha tocado el campo
            if (root.draftId === "") {
                let s = parseInt(seasonField.text) || 0
                epNumField.text = App.nextEpisodeForSeason(s).toString()
            }
        }
    }
}

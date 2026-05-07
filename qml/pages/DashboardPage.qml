import castopost
import QtQuick
import QtQuick.Controls.Material
import QtQuick.Layouts

Page {
    id: root
    background: Rectangle { color: theme.bgBase }

    // Señales
    signal openLocalDraft(string draftId)
    signal openPublish()
    signal openDrafts()

    property var localDraftsList: []
    function reloadLocalDrafts() {
        localDraftsList = App.getDrafts()
    }

    Component.onCompleted: {
        App.refreshEpisodes()
        reloadLocalDrafts()
    }

    Connections {
        target: App
        function onLocalDraftsChanged() {
            reloadLocalDrafts()
        }
    }

    header: ToolBar {
        Material.background: theme.bgHeader
        RowLayout {
            anchors { fill: parent; leftMargin: 20; rightMargin: 12 }
            Label {
                text: "Dashboard"
                font.pixelSize: 16; font.weight: Font.DemiBold; color: theme.textOnDark
                Layout.fillWidth: true
            }
            Row {
                spacing: 6
                Button {
                    text: "＋ Nuevo episodio"
                    Material.background: theme.accent; Material.foreground: "white"
                    font.pixelSize: 12
                    onClicked: root.openPublish()
                }
                Button {
                    text: "Borradores"
                    flat: true; Material.foreground: theme.textMutedOnDark
                    font.pixelSize: 12
                    onClicked: root.openDrafts()
                }
                ToolButton {
                    text: "↻"; font.pixelSize: 16
                    Material.foreground: theme.textMutedOnDark
                    onClicked: App.refreshEpisodes()
                    ToolTip.text: "Actualizar"; ToolTip.visible: hovered
                }
            }
        }
    }

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        Column {
            width: parent.width
            topPadding: 16
            bottomPadding: 20
            spacing: 0

            // ── Podcast info card ──────────────────────────
            Rectangle {
                width: parent.width - 40
                anchors.horizontalCenter: parent.horizontalCenter
                implicitHeight: podInfoRow.implicitHeight + 24
                radius: theme.radiusMd
                color: theme.bgSurface
                border.color: theme.cardBorder; border.width: 1
                visible: App.podcastInfo !== null
                         && App.podcastInfo !== undefined
                         && (App.podcastInfo.title || "") !== ""

                Row {
                    id: podInfoRow
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                    spacing: 12

                    // Cover
                    Rectangle {
                        width: 64; height: 64; radius: 8; color: theme.bgInput
                        visible: (App.podcastInfo.coverUrl || "") !== ""
                        Image {
                            anchors.fill: parent
                            source: App.podcastInfo.coverUrl || ""
                            fillMode: Image.PreserveAspectCrop
                            visible: status === Image.Ready
                        }
                    }

                    Column {
                        width: parent.width - 76 - parent.spacing
                        spacing: 4
                        Label {
                            text: App.podcastInfo.title || App.activePodcast
                            color: theme.textPrimary
                            font.pixelSize: 14; font.bold: true
                            elide: Text.ElideRight; width: parent.width
                        }
                        Label {
                            text: App.podcastInfo.description || ""
                            color: theme.textMuted; font.pixelSize: 11
                            maximumLineCount: 2; elide: Text.ElideRight
                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                            width: parent.width
                            visible: (App.podcastInfo.description || "").length > 0
                        }
                        Label {
                            text: "@" + (App.podcastInfo.handle || App.activePodcast)
                            color: theme.accentLight; font.pixelSize: 10
                        }
                    }
                }
            }

            // ── Stats ─────────────────────────────────────────
            Row {
                width: parent.width
                leftPadding: 20; rightPadding: 20; topPadding: 16; bottomPadding: 12
                spacing: 12

                StatCard { label: "Publicados"; value: App.episodes.length; cardColor: theme.success }
                StatCard { label: "Borradores"; value: App.drafts.length + App.getDrafts().length; cardColor: theme.accent }
                StatCard { label: "Próximo n.°"; value: App.nextEpisodeNumber; cardColor: theme.warning }
            }

            // ── Borradores locales ────────────────────────────
            Loader {
                width: parent.width
                active: localDraftsList.length > 0
                sourceComponent: Column {
                    width: parent.width
                    spacing: 6
                    topPadding: 4

                    Label {
                        text: "Borradores locales"
                        color: theme.textSecondary; font.pixelSize: 12; font.bold: true; font.letterSpacing: 1
                        leftPadding: 20; bottomPadding: 4
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openDrafts()
                        }
                    }

                    Repeater {
                        model: localDraftsList
                        delegate: Rectangle {
                            required property var modelData
                            width: parent.width - 40
                            anchors.horizontalCenter: parent.horizontalCenter
                            height: localRow.implicitHeight + 20
                            radius: 8; color: theme.bgSurface
                            border.color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.25); border.width: 1

                            Column {
                                id: localRow
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                                spacing: 4

                                Row {
                                    width: parent.width
                                    Label {
                                        text: modelData.title || "(sin título)"
                                        color: theme.textPrimary; font.pixelSize: 13; font.bold: true
                                        width: parent.width - continuarBtn.width
                                        elide: Text.ElideRight
                                    }
                                    Button {
                                        id: continuarBtn
                                        text: "Continuar →"
                                        flat: true
                                        font.pixelSize: 11
                                        Material.foreground: theme.accentLight
                                        onClicked: root.openLocalDraft(modelData.draft_id)
                                    }
                                }
                                Label {
                                    visible: (modelData.description || "").length > 0
                                    text: modelData.description || ""
                                    color: theme.textMuted; font.pixelSize: 11
                                    maximumLineCount: 1; elide: Text.ElideRight
                                    width: parent.width
                                }
                                Label {
                                    text: "Guardado: " + (modelData.saved_at || "")
                                    color: theme.textMuted; font.pixelSize: 10
                                }
                            }
                        }
                    }
                }
            }

            // ── Borradores en Castopod ────────────────────────
            Loader {
                width: parent.width
                active: App.drafts.length > 0
                sourceComponent: Column {
                    width: parent.width
                    spacing: 6
                    topPadding: 8

                    Label {
                        text: "Borradores en Castopod"
                        color: theme.textSecondary; font.pixelSize: 12; font.bold: true; font.letterSpacing: 1
                        leftPadding: 20; bottomPadding: 4
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openDrafts()
                        }
                    }

                    Repeater {
                        model: App.drafts
                        EpisodeCard {
                            required property var modelData
                            episode: modelData
                            width: parent.width - 40
                            anchors.horizontalCenter: parent.horizontalCenter
                            onPublishDraftRequested: (id) => App.publishCastopodDraft(id)
                        }
                    }
                }
            }

            // ── Episodios recientes ───────────────────────────
            Label {
                text: "Episodios recientes"
                color: theme.textSecondary; font.pixelSize: 12; font.bold: true; font.letterSpacing: 1
                leftPadding: 20; topPadding: 16; bottomPadding: 4
            }

            Repeater {
                model: App.episodes.slice(0, 10)
                EpisodeCard {
                    required property var modelData
                    episode: modelData
                    width: parent.width - 40
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            // ── Archivos temporales ──────────────────────────
            Loader {
                width: parent.width
                active: tmpFilesList.length > 0
                property var tmpFilesList: App.getTmpFiles()

                sourceComponent: Column {
                    width: parent.width
                    spacing: 6
                    topPadding: 16

                    Row {
                        leftPadding: 20
                        spacing: 12
                        Label {
                            text: "Archivos temporales"
                            color: theme.textSecondary; font.pixelSize: 12
                            font.bold: true; font.letterSpacing: 1
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Button {
                            text: "Limpiar todo"
                            flat: true; font.pixelSize: 11
                            Material.foreground: "#ef9a9a"
                            onClicked: {
                                App.clearAllTmpFiles()
                                parent.parent.parent.tmpFilesList = App.getTmpFiles()
                            }
                        }
                    }

                    Repeater {
                        model: parent.parent.tmpFilesList
                        Rectangle {
                            required property var modelData
                            width: parent.width - 40
                            anchors.horizontalCenter: parent.horizontalCenter
                            height: 40; radius: 6
                            color: theme.bgSurface
                            border.color: theme.cardBorder; border.width: 1

                            Row {
                                anchors { left: parent.left; right: parent.right; margins: 12; verticalCenter: parent.verticalCenter }
                                spacing: 8
                                Label {
                                    text: modelData.name
                                    color: theme.textMuted; font.pixelSize: 11
                                    width: parent.width - 120
                                    elide: Text.ElideMiddle
                                }
                                Label {
                                    text: modelData.size + " MB"
                                    color: theme.textMuted; font.pixelSize: 10
                                }
                                Button {
                                    text: "✕"
                                    flat: true; font.pixelSize: 12
                                    Material.foreground: "#ef9a9a"
                                    onClicked: {
                                        App.deleteTmpFile(modelData.name)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component StatCard: Rectangle {
        property string label:     ""
        property int    value:     0
        property color  cardColor: theme.accent

        width: (parent.width - parent.leftPadding - parent.rightPadding - parent.spacing * 2) / 3
        height: 68; radius: theme.radiusMd
        color: Qt.rgba(cardColor.r, cardColor.g, cardColor.b, 0.08)
        border.color: Qt.rgba(cardColor.r, cardColor.g, cardColor.b, 0.2); border.width: 1

        Column {
            anchors.centerIn: parent
            spacing: 2
            Label {
                text: value.toString()
                font.pixelSize: 26; font.weight: Font.DemiBold
                color: cardColor
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Label {
                text: label
                font.pixelSize: 10; color: theme.textMuted
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}

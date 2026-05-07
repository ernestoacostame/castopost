import castopost
import QtQuick
import QtQuick.Controls.Material
import QtQuick.Layouts

Page {
    id: root
    background: Rectangle { color: theme.bgBase }

    Component.onCompleted: App.refreshEpisodes()

    header: ToolBar {
        Material.background: theme.bgHeader
        RowLayout {
            anchors { fill: parent; leftMargin: 16; rightMargin: 8 }
            Label {
                text: "Episodios · " + App.activePodcast
                font.pixelSize: 15; font.bold: true; color: "white"
                Layout.fillWidth: true
            }
            Label {
                text: App.episodes.length + " publicados"
                color: "#9090c0"; font.pixelSize: 12
            }
            ToolButton {
                text: "↻"; font.pixelSize: 18
                onClicked: App.refreshEpisodes()
                ToolTip.text: "Actualizar"; ToolTip.visible: hovered
            }
        }
    }

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        Column {
            width: parent.width
            padding: 16
            spacing: 8

            Label {
                visible: App.episodes.length === 0 && !App.busy
                text: "No hay episodios publicados."
                color: theme.textMuted; font.pixelSize: 13
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 40
            }

            Repeater {
                model: App.episodes
                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    width: parent.width - 32
                    height: epRow.implicitHeight + 20
                    radius: 8
                    color: epHover.containsMouse ? theme.cardHover : theme.cardBg
                    border.color: theme.cardBorder; border.width: 1

                    HoverHandler { id: epHover }

                    RowLayout {
                        id: epRow
                        anchors {
                            left: parent.left; right: parent.right
                            top: parent.top; margins: 12
                        }
                        spacing: 12

                        // Número
                        Rectangle {
                            width: 36; height: 36; radius: 4
                            color: "#1a3a5c"
                            Label {
                                anchors.centerIn: parent
                                text: modelData.episodeNumber > 0
                                      ? "#" + modelData.episodeNumber : "–"
                                color: "#64b5f6"
                                font.pixelSize: 11; font.bold: true
                            }
                        }

                        // Info
                        Column {
                            Layout.fillWidth: true
                            spacing: 2
                            Label {
                                text: modelData.title || "(sin título)"
                                color: theme.textPrimary
                                font.pixelSize: 13; font.bold: true
                                elide: Text.ElideRight
                                width: parent.width
                            }
                            Row {
                                spacing: 8
                                Label {
                                    text: {
                                        let raw = modelData.publishedAt || ""
                                        if (!raw) return ""
                                        let d = new Date(raw)
                                        return isNaN(d) ? raw : d.toLocaleDateString(Qt.locale(), "d MMM yyyy")
                                    }
                                    color: theme.textMuted; font.pixelSize: 10
                                }
                                Label {
                                    visible: modelData.seasonNumber > 0
                                    text: "T" + modelData.seasonNumber
                                    color: theme.textMuted; font.pixelSize: 10
                                }
                                Label {
                                    visible: modelData.type !== "full" && modelData.type !== ""
                                    text: modelData.type || ""
                                    color: theme.textMuted; font.pixelSize: 10
                                    font.italic: true
                                }
                            }
                        }

                        // Badge publicado
                        Rectangle {
                            radius: 10; width: 72; height: 20
                            color: theme.successBadge
                            Label {
                                anchors.centerIn: parent
                                text: "PUBLICADO"
                                color: "#ffffff"
                                font.pixelSize: 9; font.bold: true
                                font.letterSpacing: 0.8
                            }
                        }
                    }
                }
            }
        }
    }
}

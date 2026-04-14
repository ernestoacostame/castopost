import castopost
import QtQuick
import QtQuick.Controls.Material
import QtQuick.Layouts

Rectangle {
    id: root
    property var episode: ({})
    signal publishDraftRequested(int episodeId)

    height: contentCol.implicitHeight + 24
    radius: 8
    color: hovered ? theme.cardHover : theme.cardBg
    border.color: episode.isDraft ? theme.accent + "44" : theme.cardBorder
    border.width: 1

    property bool hovered: false
    Behavior on color { ColorAnimation { duration: 120 } }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: root.hovered = true
        onExited:  root.hovered = false
    }

    ColumnLayout {
        id: contentCol
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                width: 36; height: 36; radius: 4
                color: episode.isDraft ? "#3d2b6b" : "#1a3a5c"
                Label {
                    anchors.centerIn: parent
                    text: episode.episodeNumber > 0 ? "#" + episode.episodeNumber : "–"
                    color: episode.isDraft ? "#bb86fc" : "#64b5f6"
                    font.pixelSize: 11; font.bold: true
                }
            }

            Column {
                Layout.fillWidth: true
                spacing: 2
                Label {
                    text: episode.title || "(sin título)"
                    color: theme.textPrimary
                    font.pixelSize: 13; font.bold: true
                    elide: Text.ElideRight
                    width: parent.width
                }
                Label {
                    visible: episode.seasonNumber > 0
                    text: "Temporada " + episode.seasonNumber
                    color: theme.textMuted
                    font.pixelSize: 11
                }
            }

            Rectangle {
                radius: 10
                width: badgeLabel.implicitWidth + 16
                height: 20
                color: episode.isDraft ? "#4a2080" : theme.successBadge
                Label {
                    id: badgeLabel
                    anchors.centerIn: parent
                    text:  episode.isDraft ? "BORRADOR" : "PUBLICADO"
                    color: "#ffffff"
                    font.pixelSize: 9; font.bold: true; font.letterSpacing: 0.8
                }
            }
        }

        Label {
            visible: (episode.description || "").length > 0
            text: episode.description || ""
            color: theme.textSecondary
            font.pixelSize: 11
            maximumLineCount: 2
            elide: Text.ElideRight
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Label {
                text: {
                    let raw = episode.publishedAt || episode.createdAt || ""
                    if (!raw) return ""
                    let d = new Date(raw)
                    return isNaN(d) ? raw : d.toLocaleDateString(Qt.locale(), "d MMM yyyy")
                }
                color: theme.textMuted
                font.pixelSize: 10
            }

            Item { Layout.fillWidth: true }

            Button {
                visible: episode.isDraft && episode.id > 0
                text: "Publicar"
                flat: true; font.pixelSize: 11
                Material.foreground: theme.accentLight
                onClicked: root.publishDraftRequested(episode.id)
            }
        }
    }
}

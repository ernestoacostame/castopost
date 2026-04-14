import castopost
import QtQuick
import QtQuick.Controls.Material
import QtQuick.Layouts

Page {
    id: root
    background: Rectangle { color: theme.bgBase }

    header: ToolBar {
        Material.background: theme.bgHeader
        RowLayout {
            anchors { fill: parent; leftMargin: 16 }
            Label { text: "Podcasts gestionados"; font.pixelSize: 15; font.bold: true; color: "white"; Layout.fillWidth: true }
        }
    }

    ColumnLayout {
        anchors { fill: parent; margins: 20 }
        spacing: 16

        // ── Añadir podcast ─────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: addCol.implicitHeight + 24
            radius: 8; color: theme.bgSurface
            border.color: "#3d2b6b"; border.width: 1

            ColumnLayout {
                id: addCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                spacing: 10

                Label { text: "Añadir podcast"; color: theme.textPrimary; font.pixelSize: 13; font.bold: true }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    TextField {
                        id: podName
                        Layout.fillWidth: true
                        placeholderText: "Nombre para mostrar"
                        Material.accent: Material.DeepPurple
                    }
                    TextField {
                        id: podHandle
                        Layout.fillWidth: true
                        placeholderText: "handle (slug en Castopod)"
                        Material.accent: Material.DeepPurple
                    }
                    Button {
                        text: "Añadir"
                        enabled: podName.text.trim().length > 0 && podHandle.text.trim().length > 0 && !App.busy
                        Material.background: "#4a148c"; Material.foreground: "white"
                        onClicked: {
                            App.addPodcast(podName.text.trim(), podHandle.text.trim())
                            podName.text = ""; podHandle.text = ""
                        }
                    }
                }
                Label {
                    text: "El handle debe coincidir exactamente con el slug del podcast en tu instancia de Castopod."
                    color: theme.textMuted; font.pixelSize: 10
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    Layout.fillWidth: true
                }
            }
        }

        Label { text: "PODCASTS CONFIGURADOS"; color: theme.textMuted; font.pixelSize: 10; font.letterSpacing: 1.5 }

        // ── Lista de podcasts ───────────────────────────────
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: App.podcasts
            spacing: 6
            clip: true

            delegate: Rectangle {
                required property var modelData
                width: ListView.view.width
                height: 56
                radius: 8
                // Activo: acento translúcido que funciona en ambos temas
                color: modelData.handle === App.activePodcast
                       ? (theme.dark ? "#252550" : "#ede8ff")
                       : theme.bgSurface
                border.color: modelData.handle === App.activePodcast ? theme.accent : theme.cardBorder
                border.width: 1

                // Nombre + handle
                Column {
                    anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                    spacing: 2
                    Label {
                        text: modelData.name
                        // Texto siempre legible sobre el fondo activo
                        color: modelData.handle === App.activePodcast
                               ? (theme.dark ? "#e0e0ff" : "#3a1a8a")
                               : theme.textPrimary
                        font.pixelSize: 13; font.bold: true
                    }
                    Label {
                        text: modelData.handle
                        color: modelData.handle === App.activePodcast
                               ? (theme.dark ? "#9090c0" : "#6040a0")
                               : theme.textMuted
                        font.pixelSize: 11
                    }
                }

                // Badge ACTIVO
                Rectangle {
                    visible: modelData.handle === App.activePodcast
                    anchors { right: deleteBtn.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    radius: 10; width: 60; height: 20; color: theme.accent
                    Label {
                        anchors.centerIn: parent
                        text: "ACTIVO"; color: "white"
                        font.pixelSize: 9; font.bold: true; font.letterSpacing: 0.8
                    }
                }

                // Botón eliminar — sin MouseArea encima
                Button {
                    id: deleteBtn
                    anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                    text: "✕"
                    flat: true
                    font.pixelSize: 14
                    Material.foreground: "#ef9a9a"
                    onClicked: App.removePodcast(modelData.handle)
                }

                // Clic en la fila (sin solapar el botón)
                MouseArea {
                    anchors { left: parent.left; right: deleteBtn.left; top: parent.top; bottom: parent.bottom }
                    cursorShape: Qt.PointingHandCursor
                    onClicked: App.setActivePodcast(modelData.handle)
                }
            }

            Label {
                visible: App.podcasts.length === 0
                anchors.centerIn: parent
                text: "Aún no has añadido ningún podcast."
                color: theme.textMuted; font.pixelSize: 13
            }
        }
    }
}

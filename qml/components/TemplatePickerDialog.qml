import castopost
import QtQuick
import QtQuick.Controls.Material
import QtQuick.Layouts

Dialog {
    id: root

    signal templateSelected(string body)

    title: "Insertar plantilla"
    modal: true
    standardButtons: Dialog.Cancel
    width: 480
    height: 400

    Material.theme: Material.Dark
    Material.accent: Material.DeepPurple

    property var templates: []

    onOpened: templates = App.getTemplates()

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        Label { text: "Selecciona una plantilla de descripción:"; color: theme.textSecondary; font.pixelSize: 12 }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ListView {
                model: root.templates
                spacing: 6
                delegate: Rectangle {
                    width: ListView.view.width
                    height: itemCol.implicitHeight + 16
                    radius: 6
                    color: hov ? "#2d2d5e" : theme.bgSurface
                    property bool hov: false

                    ColumnLayout {
                        id: itemCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                        spacing: 4
                        Label { text: modelData.name; color: theme.textPrimary; font.pixelSize: 13; font.bold: true }
                        Label {
                            text: modelData.description
                            color: theme.textMuted; font.pixelSize: 11
                            maximumLineCount: 2; elide: Text.ElideRight
                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                            Layout.fillWidth: true
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: parent.hov = true
                        onExited:  parent.hov = false
                        onClicked: {
                            root.templateSelected(modelData.description)
                            root.close()
                        }
                    }
                }
            }
        }
    }
}

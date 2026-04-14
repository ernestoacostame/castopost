import castopost
import QtQuick
import QtQuick.Controls.Material
import QtQuick.Layouts

Page {
    id: root
    background: Rectangle { color: theme.bgBase }

    property var templates: []
    property var editingTemplate: null

    Component.onCompleted: reload()
    function reload() { templates = App.getTemplates() }

    header: ToolBar {
        Material.background: theme.bgHeader
        RowLayout {
            anchors { fill: parent; leftMargin: 16; rightMargin: 8 }
            Label { text: "Plantillas de descripción"; font.pixelSize: 15; font.bold: true; color: "white"; Layout.fillWidth: true }
            ToolButton { text: "+ Nueva"; font.pixelSize: 12; onClicked: { editingTemplate = null; editorDialog.open() } }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ── Lista ─────────────────────────────────────────────
        ScrollView {
            Layout.preferredWidth: 240
            Layout.fillHeight: true
            clip: true

            ListView {
                model: root.templates
                spacing: 4
                topMargin: 12; leftMargin: 12; rightMargin: 12; bottomMargin: 12

                delegate: Rectangle {
                    required property var modelData
                    width: ListView.view.width - 24
                    height: 60; radius: 8
                    color: root.editingTemplate && root.editingTemplate.id === modelData.id
                           ? "#2d2d5e" : theme.bgSurface
                    border.color: "#3d2b6b"; border.width: 1

                    Column {
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                        spacing: 3
                        Label { text: modelData.name; color: theme.textPrimary; font.pixelSize: 12; font.bold: true; elide: Text.ElideRight; width: parent.width }
                        Label { text: modelData.description; color: theme.textMuted; font.pixelSize: 10; elide: Text.ElideRight; maximumLineCount: 1; width: parent.width }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.editingTemplate = modelData
                    }
                }
            }
        }

        Rectangle { width: 1; Layout.fillHeight: true; color: theme.border }

        // ── Editor / detalle ──────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Placeholder cuando nada está seleccionado
            Label {
                visible: root.editingTemplate === null
                anchors.centerIn: parent
                text: "Selecciona una plantilla o crea una nueva"
                color: theme.textMuted; font.pixelSize: 13
            }

            ColumnLayout {
                visible: root.editingTemplate !== null
                anchors { fill: parent; margins: 20 }
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Label { text: "Nombre"; color: theme.textSecondary; font.pixelSize: 11; Layout.preferredWidth: 80 }
                    TextField {
                        id: tplName
                        Layout.fillWidth: true
                        text: root.editingTemplate ? root.editingTemplate.name : ""
                        Material.accent: Material.DeepPurple
                    }
                }

                Label { text: "Contenido"; color: theme.textSecondary; font.pixelSize: 11 }
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    TextArea {
                        id: tplBody
                        text: root.editingTemplate ? root.editingTemplate.description : ""
                        wrapMode: TextArea.WrapAtWordBoundaryOrAnywhere
                        font.family: "monospace"; font.pixelSize: 12
                        Material.accent: Material.DeepPurple
                    }
                }

                RowLayout {
                    spacing: 8
                    Button {
                        text: "Guardar cambios"
                        Material.background: "#4a148c"; Material.foreground: "white"
                        onClicked: {
                            if (root.editingTemplate.id)
                                App.updateTemplate(root.editingTemplate.id, tplName.text, tplBody.text)
                            else
                                App.addTemplate(tplName.text, tplBody.text)
                            root.reload()
                        }
                    }
                    Button {
                        text: "Eliminar"
                        visible: root.editingTemplate && root.editingTemplate.id !== "default"
                        flat: true; Material.foreground: "#ef9a9a"
                        onClicked: {
                            App.deleteTemplate(root.editingTemplate.id)
                            root.editingTemplate = null
                            root.reload()
                        }
                    }
                }
            }
        }
    }

    // ── Diálogo nueva plantilla ───────────────────────────────
    Dialog {
        id: editorDialog
        title: "Nueva plantilla"
        modal: true
        width: 420
        standardButtons: Dialog.Ok | Dialog.Cancel
        Material.theme: Material.Dark
        Material.accent: Material.DeepPurple

        Column {
            width: parent.width
            spacing: 12
            TextField { id: newTplName; width: parent.width; placeholderText: "Nombre"; Material.accent: Material.DeepPurple }
            ScrollView {
                width: parent.width; height: 200
                TextArea { id: newTplBody; placeholderText: "Contenido de la plantilla…"; wrapMode: TextArea.WrapAtWordBoundaryOrAnywhere; Material.accent: Material.DeepPurple }
            }
        }
        onAccepted: {
            if (newTplName.text.trim()) {
                App.addTemplate(newTplName.text.trim(), newTplBody.text)
                root.reload()
            }
            newTplName.text = ""; newTplBody.text = ""
        }
    }
}

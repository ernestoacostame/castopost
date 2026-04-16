import castopost
import QtQuick
import QtQuick.Controls.Material
import QtQuick.Layouts

Page {
    id: root
    background: Rectangle { color: theme.bgBase }

    property int tabIndex: 0   // 0 = locales, 1 = Castopod

    header: ToolBar {
        Material.background: theme.bgHeader
        RowLayout {
            anchors { fill: parent; leftMargin: 16 }
            Label { text: "Borradores"; font.pixelSize: 15; font.bold: true; color: "white"; Layout.fillWidth: true }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        TabBar {
            id: tabs
            Layout.fillWidth: true
            Material.accent: Material.DeepPurple
            Material.background: theme.bgHeader
            TabButton { text: "Borradores locales (%1)".arg(localDrafts.count) }
            TabButton { text: "Borradores en Castopod (%1)".arg(App.drafts.length) }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabs.currentIndex

            // ── Pestaña: locales ─────────────────────────────
            ScrollView {
                contentWidth: availableWidth
                clip: true

                Column {
                    width: parent.width
                    padding: 16
                    spacing: 8

                    Label {
                        visible: localDrafts.count === 0
                        text: "No hay borradores locales guardados."
                        color: theme.textMuted; font.pixelSize: 13
                        anchors.horizontalCenter: parent.horizontalCenter
                        topPadding: 40
                    }

                    Repeater {
                        id: localDrafts
                        model: App.getDrafts()

                        Rectangle {
                            required property var modelData
                            required property int index

                            width: parent.width - 32
                            height: draftCol.implicitHeight + 20
                            radius: 8
                            color: theme.bgSurface
                            border.color: "#3d2b6b"; border.width: 1

                            ColumnLayout {
                                id: draftCol
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                                spacing: 6

                                RowLayout {
                                    Layout.fillWidth: true
                                    Label { text: modelData.title || "(sin título)"; color: theme.textPrimary; font.pixelSize: 13; font.bold: true; Layout.fillWidth: true }
                                    Label { text: modelData.saved_at || ""; color: theme.textMuted; font.pixelSize: 10 }
                                }
                                Label {
                                    visible: (modelData.description || "").length > 0
                                    text: modelData.description || ""
                                    color: theme.textMuted; font.pixelSize: 11
                                    maximumLineCount: 2; elide: Text.ElideRight
                                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                    Layout.fillWidth: true
                                }
                                RowLayout {
                                    spacing: 8
                                    Button {
                                        text: "Editar / Publicar"
                                        flat: true
                                        font.pixelSize: 11
                                        Material.foreground: theme.accentLight
                                        onClicked: {
                                            console.log("Opening draft:", modelData.draft_id)
                                            openLocalDraft(modelData.draft_id)
                                        }
                                    }
                                    Button {
                                        text: "Eliminar"
                                        flat: true; font.pixelSize: 11
                                        Material.foreground: "#ef9a9a"
                                        onClicked: {
                                            App.deleteDraft(modelData.draft_id)
                                            localDrafts.model = App.getDrafts()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── Pestaña: borradores Castopod ─────────────────
            ScrollView {
                contentWidth: availableWidth
                clip: true

                Column {
                    width: parent.width
                    padding: 16
                    spacing: 8

                    Label {
                        visible: App.drafts.length === 0
                        text: "No hay borradores en Castopod."
                        color: theme.textMuted; font.pixelSize: 13
                        anchors.horizontalCenter: parent.horizontalCenter
                        topPadding: 40
                    }

                    Repeater {
                        model: App.drafts
                        EpisodeCard {
                            required property var modelData
                            episode: modelData
                            width: parent.width - 32
                            onPublishDraftRequested: (id) => App.publishCastopodDraft(id)
                        }
                    }
                }
            }
        }
    }

    // Referencia al stack padre para navegar
    property var stack: StackView.view
    property Component publishPageComp: Component { PublishPage {} }

    signal openLocalDraft(string draftId)
}

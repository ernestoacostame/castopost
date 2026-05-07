import castopost
import QtQuick
import QtQuick.Controls.Material
import QtQuick.Layouts

Rectangle {
    id: root
    color: theme.bgSidebar

    signal navigate(string page)
    property string currentPage: "dashboard"

    ColumnLayout {
        anchors { fill: parent; margins: 0 }
        spacing: 0

        // ── Logo ────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            height: 52

            Text {
                text: "CastoPOST"
                color: theme.textOnDark
                font.pixelSize: 15; font.weight: Font.DemiBold
                font.letterSpacing: 0.5
                anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
            }
        }

        // ── Selector de podcast ─────────────────────────
        PodcastSwitcher {
            Layout.fillWidth: true
            Layout.leftMargin: 10; Layout.rightMargin: 10
        }

        Item { height: 12 }

        // ── Navegación ──────────────────────────────────
        NavItem { icon: "⬡"; label: "Dashboard";  page: "dashboard"  }
        NavItem { icon: "＋"; label: "Publicar";   page: "publish"    }
        NavItem { icon: "◉"; label: "Episodios";  page: "episodes"   }
        NavItem { icon: "✎"; label: "Borradores"; page: "drafts"     }
        NavItem { icon: "⊞"; label: "Plantillas"; page: "templates"  }
        NavItem { icon: "♫"; label: "Podcasts";   page: "podcasts"   }

        Item { Layout.fillHeight: true }

        Rectangle {
            Layout.fillWidth: true; height: 1
            Layout.leftMargin: 16; Layout.rightMargin: 16
            color: "#1e2028"
        }
        NavItem { icon: "⚙"; label: "Ajustes"; page: "settings" }
        Item { height: 8 }
    }

    component NavItem: Rectangle {
        property string icon:  ""
        property string label: ""
        property string page:  ""

        readonly property bool active: root.currentPage === page

        Layout.fillWidth: true
        Layout.leftMargin: 8; Layout.rightMargin: 8
        height: 38
        radius: theme.radiusSm
        color: active ? "#1a2030" : (navMouse.containsMouse ? "#14161e" : "transparent")

        Behavior on color { ColorAnimation { duration: 100 } }

        Row {
            anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
            spacing: 10

            Text {
                text: icon
                color: active ? theme.accent : theme.textMutedOnDark
                font.pixelSize: 14
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: label
                color: active ? theme.textOnDark : theme.textMutedOnDark
                font.pixelSize: 13
                font.weight: active ? Font.Medium : Font.Normal
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Indicador lateral activo
        Rectangle {
            visible: active
            width: 3; height: 18; radius: 2
            color: theme.accent
            anchors { left: parent.left; leftMargin: 2; verticalCenter: parent.verticalCenter }
        }

        MouseArea {
            id: navMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { root.currentPage = page; root.navigate(page) }
        }
    }
}

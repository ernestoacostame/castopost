import castopost
import QtQuick
import QtQuick.Controls.Material
import QtQuick.Layouts

Rectangle {
    id: root
    color: theme.bgSidebar  // siempre oscuro

    signal navigate(string page)
    property string currentPage: "dashboard"

    ColumnLayout {
        anchors { fill: parent; margins: 0 }
        spacing: 0

        // ── Logo ──────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 56
            color: Qt.darker(theme.bgSidebar, 1.2)

            Text {
                text: "CastoPOST"
                color: theme.textOnDark
                font.pixelSize: 16; font.bold: true
                anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
            }
        }

        // ── Selector de podcast ───────────────────────────
        PodcastSwitcher {
            Layout.fillWidth: true
            Layout.topMargin: 8
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: "#33334a"; Layout.topMargin: 8 }

        // ── Navegación ────────────────────────────────────
        NavItem { icon: "⬡"; label: "Dashboard";  page: "dashboard"  }
        NavItem { icon: "＋"; label: "Publicar";   page: "publish"    }
        NavItem { icon: "✎"; label: "Borradores"; page: "drafts"     }
        NavItem { icon: "⊞"; label: "Plantillas"; page: "templates"  }
        NavItem { icon: "♫"; label: "Podcasts";   page: "podcasts"   }

        Item { Layout.fillHeight: true }

        Rectangle { Layout.fillWidth: true; height: 1; color: "#33334a" }
        NavItem { icon: "⚙"; label: "Ajustes"; page: "settings" }
        Item { height: 8 }
    }

    component NavItem: Rectangle {
        property string icon:  ""
        property string label: ""
        property string page:  ""

        Layout.fillWidth: true
        height: 44
        color: root.currentPage === page ? "#2d2d5e" : "transparent"
        radius: 6

        Row {
            anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
            spacing: 12
            Text { text: icon;  color: root.currentPage === page ? "#bb86fc" : theme.textMutedOnDark; font.pixelSize: 16 }
            Text { text: label; color: root.currentPage === page ? "#ffffff"  : theme.textMutedOnDark; font.pixelSize: 13 }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: { root.currentPage = page; root.navigate(page) }
        }
    }
}

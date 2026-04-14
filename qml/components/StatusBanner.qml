import castopost
import QtQuick
import QtQuick.Controls.Material

Rectangle {
    id: root

    property string message:  ""
    property bool   isError:  false

    signal dismissed()

    height:  message.length > 0 ? 44 : 0
    visible: message.length > 0
    color:   isError ? theme.errorBg : "#1b5e20"
    clip:    true

    Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }

    Row {
        anchors { left: parent.left; leftMargin: 16; right: closeBtn.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
        spacing: 8
        Text { text: root.isError ? "✕" : "✓"; color: "white"; font.pixelSize: 14; font.bold: true }
        Text { text: root.message; color: "white"; font.pixelSize: 13; elide: Text.ElideRight
               width: parent.width - 24 }
    }

    Text {
        id: closeBtn
        text: "×"
        color: "#ccffffff"
        font.pixelSize: 20
        anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.dismissed() }
    }

    // Auto-dismiss después de 5 s si no es error
    Timer {
        interval: 5000
        running:  root.message.length > 0 && !root.isError
        onTriggered: root.dismissed()
    }
}

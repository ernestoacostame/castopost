import castopost
import QtQuick
import QtQuick.Controls.Material

Column {
    width: parent.width
    padding: 12
    spacing: 4

    Label {
        text: "PODCAST ACTIVO"
        font.pixelSize: 9
        font.letterSpacing: 1.5
        color: theme.textMutedOnDark  // siempre sobre fondo oscuro del sidebar
        leftPadding: 4
    }

    ComboBox {
        id: combo
        width: parent.width - 24
        model: App.podcasts
        textRole: "name"
        valueRole: "handle"

        // El sidebar es siempre oscuro — texto siempre claro
        Material.foreground: "#e0e0ff"
        Material.background: "#2d2d5e"
        font.pixelSize: 12

        onActivated: App.setActivePodcast(currentValue)

        function syncIndex() {
            for (let i = 0; i < App.podcasts.length; i++) {
                if (App.podcasts[i].handle === App.activePodcast) {
                    currentIndex = i
                    return
                }
            }
            if (App.podcasts.length > 0) {
                currentIndex = 0
                App.setActivePodcast(App.podcasts[0].handle)
            } else {
                currentIndex = -1
            }
        }

        Component.onCompleted: syncIndex()

        Connections {
            target: App
            function onPodcastsChanged()      { combo.syncIndex() }
            function onActivePodcastChanged() { combo.syncIndex() }
        }
    }
}

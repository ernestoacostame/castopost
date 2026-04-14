import QtQuick
import QtQuick.Controls.Material
import QtQuick.Layouts
import castopost

ApplicationWindow {
    id: root
    visible: true
    width:  960
    height: 700
    minimumWidth:  800
    minimumHeight: 600
    title: "CastoPOST"

    // Theme instanciado aquí con id: theme
    // Al estar en la raíz, todos los QML hijos lo ven como "Theme"
    Theme {
        id: theme
    }

    Material.theme:  theme.dark ? Material.Dark : Material.Light
    Material.accent: Material.DeepPurple

    background: Rectangle { color: theme.bgBase }

    Component.onCompleted: {
        if (!App.configured)
            stack.replace(settingsPage)
        else
            stack.replace(dashboardPage)
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        SideBar {
            id: sidebar
            visible: App.configured
            Layout.preferredWidth: 200
            Layout.fillHeight: true
            onNavigate: (page) => navigateTo(page)
        }

        StackView {
            id: stack
            Layout.fillWidth: true
            Layout.fillHeight: true
            initialItem: dashboardPage
            clip: true
            pushEnter:    Transition { PropertyAnimation { property: "opacity"; from: 0; to: 1; duration: 150 } }
            pushExit:     Transition { PropertyAnimation { property: "opacity"; from: 1; to: 0; duration: 100 } }
            replaceEnter: Transition { PropertyAnimation { property: "opacity"; from: 0; to: 1; duration: 150 } }
            replaceExit:  Transition { PropertyAnimation { property: "opacity"; from: 1; to: 0; duration: 100 } }
        }
    }

    StatusBanner {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        message: App.statusMessage
        isError: App.statusIsError
        onDismissed: App.clearStatus()
    }

    Rectangle {
        anchors.fill: parent
        color: theme.overlay
        visible: App.busy
        Column {
            anchors.centerIn: parent
            spacing: 16
            BusyIndicator { anchors.horizontalCenter: parent.horizontalCenter; running: true }
            Label {
                text: App.conversionProgress > 0 && App.conversionProgress < 100
                      ? "Convirtiendo audio… %1%".arg(App.conversionProgress)
                      : App.uploadProgress > 0 ? "Subiendo… %1%".arg(App.uploadProgress)
                      : "Procesando…"
                color: "white"; font.pixelSize: 14
                anchors.horizontalCenter: parent.horizontalCenter
            }
            ProgressBar {
                width: 280
                anchors.horizontalCenter: parent.horizontalCenter
                value: App.conversionProgress > 0 && App.conversionProgress < 100
                       ? App.conversionProgress / 100 : App.uploadProgress / 100
                visible: App.conversionProgress > 0 || App.uploadProgress > 0
                Material.accent: Material.LightGreen
            }
        }
    }

    Component {
        id: dashboardPage
        DashboardPage {
            onOpenLocalDraft: (draftId) => {
                stack.replace(publishPage)
                Qt.callLater(() => {
                    if (stack.currentItem && stack.currentItem.loadDraft)
                        stack.currentItem.loadDraft(draftId)
                })
            }
            onOpenPublish: stack.replace(publishPage)
        }
    }
    Component { id: publishPage;   PublishPage   {} }
    Component { id: draftsPage;    DraftsPage    {} }
    Component { id: templatesPage; TemplatesPage {} }
    Component { id: podcastsPage;  PodcastsPage  {} }
    Component { id: settingsPage;  SettingsPage  {} }

    function navigateTo(page) {
        const map = {
            dashboard: dashboardPage, publish: publishPage,
            drafts: draftsPage,       templates: templatesPage,
            podcasts: podcastsPage,   settings: settingsPage
        }
        if (map[page]) stack.replace(map[page])
    }

    Connections {
        target: App
        function onConfiguredChanged() {
            if (App.configured) { stack.replace(dashboardPage); App.refreshEpisodes() }
        }
    }
}

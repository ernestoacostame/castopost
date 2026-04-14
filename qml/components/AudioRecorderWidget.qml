import castopost
import QtQuick
import QtQuick.Controls.Material
import QtMultimedia

Column {
    id: root
    spacing: 10
    width: parent ? parent.width : 0

    property string recordedFilePath: ""
    signal fileReady(string filePath)

    // ── VU-meter (solo mientras graba) ────────────────────
    Rectangle {
        width: parent.width
        height: 10
        radius: 5
        color: theme.bgInput
        visible: App.recorder.recording

        Rectangle {
            width: parent.width * Math.min(App.recorder.level * 3, 1.0)
            height: parent.height
            radius: parent.radius
            color: {
                let l = App.recorder.level * 3
                if (l > 0.8) return "#f44336"
                if (l > 0.5) return "#ffeb3b"
                return theme.success
            }
            Behavior on width { NumberAnimation { duration: 60 } }
        }
    }

    // ── Temporizador ──────────────────────────────────────
    Label {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        visible: App.recorder.recording
        text: {
            let s = App.recorder.elapsed
            let m = Math.floor(s / 60)
            let ss = s % 60
            return "⏺  Grabando  " + m + ":" + (ss < 10 ? "0" : "") + ss
        }
        color: "#f44336"
        font.pixelSize: 13; font.bold: true
    }

    // ── Botón grabar / parar ──────────────────────────────
    Rectangle {
        width: parent.width
        height: 48
        radius: 24
        visible: root.recordedFilePath === ""
        color: App.recorder.recording ? theme.errorBg : "#4a148c"
        Behavior on color { ColorAnimation { duration: 200 } }

        Row {
            anchors.centerIn: parent
            spacing: 8
            Rectangle {
                width: 10; height: 10; radius: 5
                color: "white"
                anchors.verticalCenter: parent.verticalCenter
                visible: App.recorder.recording
                SequentialAnimation on opacity {
                    running: App.recorder.recording
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.2; duration: 500 }
                    NumberAnimation { to: 1.0; duration: 500 }
                }
            }
            Label {
                text: App.recorder.recording ? "⏹  Parar grabación" : "⏺  Grabar"
                color: "white"; font.pixelSize: 14; font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (App.recorder.recording) {
                    App.recorder.stop()
                } else {
                    App.recorder.start()
                    root.recordedFilePath = ""
                }
            }
        }
    }

    // ── Reproductor (aparece tras parar) ──────────────────
    Column {
        width: parent.width
        spacing: 8
        visible: root.recordedFilePath !== ""

        // Objeto de audio (no visual)
        MediaPlayer {
            id: player
            source: root.recordedFilePath !== "" ? "file://" + root.recordedFilePath : ""
            audioOutput: AudioOutput { id: audioOut; volume: volumeSlider.value }
        }

        // Barra de progreso clicable
        Rectangle {
            width: parent.width
            height: 6
            radius: 3
            color: theme.bgSurface

            Rectangle {
                width: player.duration > 0
                       ? parent.width * (player.position / player.duration)
                       : 0
                height: parent.height
                radius: parent.radius
                color: theme.accent
                Behavior on width { NumberAnimation { duration: 100 } }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: (mouse) => {
                    if (player.duration > 0)
                        player.position = (mouse.x / width) * player.duration
                }
            }
        }

        // Tiempo
        Item {
            width: parent.width
            height: 16
            Label {
                text: formatTime(player.position)
                color: theme.textSecondary; font.pixelSize: 10
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            }
            Label {
                text: formatTime(player.duration)
                color: theme.textSecondary; font.pixelSize: 10
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            }
        }

        // Controles
        Row {
            width: parent.width
            spacing: 8

            // Play / Pausa
            Rectangle {
                width: parent.width - discardBtn2.width - volRow.width - 16
                height: 48; radius: 24
                color: player.playbackState === MediaPlayer.PlayingState ? "#1a3a5c" : "#4a148c"
                Behavior on color { ColorAnimation { duration: 150 } }

                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Label {
                        text: player.playbackState === MediaPlayer.PlayingState ? "⏸" : "▶"
                        color: "white"; font.pixelSize: 18
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Label {
                        text: player.playbackState === MediaPlayer.PlayingState
                              ? "Pausar" : "Escuchar grabación"
                        color: "white"; font.pixelSize: 13; font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (player.playbackState === MediaPlayer.PlayingState)
                            player.pause()
                        else
                            player.play()
                    }
                }
            }

            // Volumen
            Row {
                id: volRow
                spacing: 4
                anchors.verticalCenter: parent.verticalCenter
                Label { text: "🔊"; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter; color: theme.textSecondary }
                Slider {
                    id: volumeSlider
                    width: 70
                    from: 0; to: 1; value: 1
                    anchors.verticalCenter: parent.verticalCenter
                    Material.accent: Material.DeepPurple
                }
            }

            // Descartar
            Rectangle {
                id: discardBtn2
                width: 48; height: 48; radius: 24
                color: "#2a0a0a"
                Label { anchors.centerIn: parent; text: "✕"; color: "#ef9a9a"; font.pixelSize: 16 }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        player.stop()
                        App.recorder.discard()
                        root.recordedFilePath = ""
                    }
                }
            }
        }

        // Banner "listo"
        Rectangle {
            width: parent.width
            height: 36; radius: 6
            color: theme.successBg; border.color: "#2e7d32"
            Label {
                anchors.centerIn: parent
                text: "✓  Grabación lista — puedes publicar o descartar"
                color: "#a5d6a7"; font.pixelSize: 11
            }
        }
    }

    // ── Helpers ───────────────────────────────────────────
    function formatTime(ms) {
        if (!ms || ms <= 0) return "0:00"
        let s = Math.floor(ms / 1000)
        let m = Math.floor(s / 60)
        let ss = s % 60
        return m + ":" + (ss < 10 ? "0" : "") + ss
    }

    Connections {
        target: App.recorder
        function onRecordingFinished(filePath) {
            root.recordedFilePath = filePath
            root.fileReady(filePath)
        }
    }
}

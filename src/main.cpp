#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QIcon>
#include <QDir>

#include "app/AppController.h"
#include "audio/AudioRecorder.h"

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    app.setApplicationName("CastoPOST");
    app.setApplicationVersion("0.1.0");
    app.setOrganizationName("castopost");

    // El icono puede estar bajo distintos prefijos según la versión de Qt;
    // probamos los dos y usamos el primero que exista.
    for (const char *path : {
             ":/qt/qml/castopost/resources/icons/castopost.svg",
             ":/castopost/resources/icons/castopost.svg"
         }) {
        if (QFile::exists(path)) {
            app.setWindowIcon(QIcon(path));
            break;
        }
    }

    QQuickStyle::setStyle("Material");

    qmlRegisterUncreatableType<AudioRecorder>("castopost", 1, 0, "AudioRecorder",
                                              "Usa App.recorder");

    AppController controller;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("App", &controller);

    // Qt 6.5+: loadFromModule resuelve la ruta correcta sin importar
    // el prefijo qrc que use la versión instalada de Qt.
    engine.loadFromModule("castopost", "Main");

    if (engine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}

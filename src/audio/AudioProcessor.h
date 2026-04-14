#pragma once
#include <QObject>
#include <QProcess>

/**
 * AudioProcessor
 *
 * Envuelve FFmpeg para realizar la conversión a MP3
 * con normalización EBU R128 a -16 LUFS (2 pasadas).
 *
 * Equivalente C++/Qt de CastopodAPI::ensureMp3() en PHP.
 *
 * Uso:
 *   auto *proc = new AudioProcessor(this);
 *   connect(proc, &AudioProcessor::finished,   this, &MyClass::onAudioReady);
 *   connect(proc, &AudioProcessor::errorOccurred, this, &MyClass::onError);
 *   connect(proc, &AudioProcessor::progressChanged, this, &MyClass::onProgress);
 *   proc->process("/path/to/input.webm");
 */
class AudioProcessor : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int progress READ progress NOTIFY progressChanged)

public:
    explicit AudioProcessor(QObject *parent = nullptr);
    ~AudioProcessor();

    void process(const QString &inputPath);
    void cancel();

    int progress() const { return m_progress; }

    // Devuelve la ruta al MP3 resultante (válida solo después de finished)
    QString outputPath() const { return m_outputPath; }

    // Comprueba si ffmpeg está disponible en PATH
    static bool ffmpegAvailable();
    static QString ffmpegPath();

signals:
    void progressChanged(int percent);
    void logLine(const QString &line);         // stderr de ffmpeg
    void finished(const QString &outputPath);  // ruta al MP3 listo
    void errorOccurred(const QString &message);

private slots:
    void onPass1Finished(int exitCode, QProcess::ExitStatus status);
    void onPass2Finished(int exitCode, QProcess::ExitStatus status);
    void onProcessError(QProcess::ProcessError err);

private:
    void startPass1();
    void startPass2();
    void parseLoudnormStats(const QByteArray &ffmpegOutput);
    void cleanup();

    QString  m_inputPath;
    QString  m_outputPath;
    QProcess *m_process  = nullptr;
    int      m_progress  = 0;

    // Resultados de la medición pass-1
    struct LoudnormStats {
        QString input_i;
        QString input_tp;
        QString input_lra;
        QString input_thresh;
        QString target_offset;
        bool    valid = false;
    } m_stats;
};

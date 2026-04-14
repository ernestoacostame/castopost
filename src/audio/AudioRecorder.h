#pragma once
#include <QObject>
#include <QAudioSource>
#include <QAudioFormat>
#include <QFile>
#include <QTimer>

/**
 * AudioRecorder
 *
 * Graba audio del micrófono a un archivo WAV temporal.
 * Reemplaza la grabadora WebM del navegador.
 *
 * Uso:
 *   auto *rec = new AudioRecorder(this);
 *   connect(rec, &AudioRecorder::levelChanged,  this, &MyClass::updateVuMeter);
 *   connect(rec, &AudioRecorder::recordingFinished, this, &MyClass::onRecorded);
 *   rec->start();
 *   // ... más tarde:
 *   rec->stop(); // → emite recordingFinished(filePath)
 */
class AudioRecorder : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool    recording READ isRecording NOTIFY recordingChanged)
    Q_PROPERTY(float   level     READ level       NOTIFY levelChanged)
    Q_PROPERTY(int     elapsed   READ elapsed     NOTIFY elapsedChanged)

public:
    explicit AudioRecorder(QObject *parent = nullptr);
    ~AudioRecorder() override;

    bool  isRecording() const { return m_recording; }
    float level()       const { return m_level; }
    int   elapsed()     const { return m_elapsed; }

    Q_INVOKABLE void start();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void discard();

signals:
    void recordingChanged(bool recording);
    void levelChanged(float level);
    void elapsedChanged(int seconds);
    void recordingFinished(const QString &wavFilePath);
    void errorOccurred(const QString &message);

private slots:
    void onAudioData();
    void onTick();

private:
    void       writeWavHeader();
    void       finalizeWav();
    QByteArray readChunk();

    QAudioSource *m_source   = nullptr;
    QIODevice    *m_device   = nullptr;   // device de m_source
    QFile         m_wavFile;
    QTimer        m_ticker;

    bool  m_recording = false;
    float m_level     = 0.f;
    int   m_elapsed   = 0;

    // Bytes de datos PCM escritos (para el header WAV al finalizar)
    qint64 m_dataBytes = 0;
    qint32 m_sampleRate = 44100;
    qint16 m_channels   = 1;
    qint16 m_bitsPerSample = 16;
};

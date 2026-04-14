#include "AudioRecorder.h"

#include <QMediaDevices>
#include <QAudioDevice>
#include <QStandardPaths>
#include <QDir>
#include <QDateTime>
#include <QtEndian>
#include <cmath>
#include <cstring>

// ──────────────────────────────────────────────────────────────

AudioRecorder::AudioRecorder(QObject *parent)
    : QObject(parent)
{
    m_ticker.setInterval(1000);
    connect(&m_ticker, &QTimer::timeout, this, &AudioRecorder::onTick);
}

AudioRecorder::~AudioRecorder()
{
    discard();
}

// ──────────────────────────────────────────────────────────────
//  Control
// ──────────────────────────────────────────────────────────────

void AudioRecorder::start()
{
    if (m_recording) return;

    // Formato: PCM 44100 Hz, 16-bit, mono
    QAudioFormat fmt;
    fmt.setSampleRate(m_sampleRate);
    fmt.setChannelCount(m_channels);
    fmt.setSampleFormat(QAudioFormat::Int16);

    QAudioDevice defaultInput = QMediaDevices::defaultAudioInput();
    if (defaultInput.isNull()) {
        emit errorOccurred("No se encontró micrófono disponible.");
        return;
    }

    if (!defaultInput.isFormatSupported(fmt)) {
        emit errorOccurred("El formato de grabación no es compatible con el micrófono.");
        return;
    }

    // Preparar archivo WAV temporal
    QString tmpDir = QStandardPaths::writableLocation(QStandardPaths::TempLocation)
                     + "/castopost";
    QDir().mkpath(tmpDir);
    QString fname = tmpDir + "/rec_" +
                    QString::number(QDateTime::currentMSecsSinceEpoch()) + ".wav";
    m_wavFile.setFileName(fname);
    if (!m_wavFile.open(QIODevice::WriteOnly)) {
        emit errorOccurred("No se pudo crear el archivo temporal de grabación.");
        return;
    }

    writeWavHeader();   // reserva espacio para el header; lo completaremos al parar
    m_dataBytes = 0;

    m_source = new QAudioSource(defaultInput, fmt, this);
    m_device = m_source->start();

    if (!m_device) {
        emit errorOccurred("No se pudo iniciar la grabación de audio.");
        delete m_source; m_source = nullptr;
        m_wavFile.close();
        return;
    }

    connect(m_device, &QIODevice::readyRead, this, &AudioRecorder::onAudioData);

    m_elapsed   = 0;
    m_recording = true;
    m_ticker.start();

    emit recordingChanged(true);
    emit elapsedChanged(0);
}

void AudioRecorder::stop()
{
    if (!m_recording) return;

    m_ticker.stop();

    if (m_source) {
        m_source->stop();
        delete m_source;
        m_source = nullptr;
        m_device = nullptr;
    }

    finalizeWav();
    m_wavFile.close();

    m_recording = false;
    m_level     = 0.f;
    emit recordingChanged(false);
    emit levelChanged(0.f);

    emit recordingFinished(m_wavFile.fileName());
}

void AudioRecorder::discard()
{
    if (m_recording) {
        m_ticker.stop();
        if (m_source) { m_source->stop(); delete m_source; m_source = nullptr; }
        m_recording = false;
        emit recordingChanged(false);
    }
    if (m_wavFile.isOpen()) m_wavFile.close();
    if (!m_wavFile.fileName().isEmpty() && QFile::exists(m_wavFile.fileName()))
        QFile::remove(m_wavFile.fileName());
}

// ──────────────────────────────────────────────────────────────
//  Slots privados
// ──────────────────────────────────────────────────────────────

void AudioRecorder::onAudioData()
{
    if (!m_device || !m_wavFile.isOpen()) return;

    QByteArray chunk = m_device->readAll();
    if (chunk.isEmpty()) return;

    m_wavFile.write(chunk);
    m_dataBytes += chunk.size();

    // Calcular nivel RMS para el VU-meter en QML
    int samples = chunk.size() / 2;
    const qint16 *ptr = reinterpret_cast<const qint16 *>(chunk.constData());
    double sum = 0.0;
    for (int i = 0; i < samples; ++i)
        sum += static_cast<double>(ptr[i]) * ptr[i];
    float rms = (samples > 0) ? static_cast<float>(std::sqrt(sum / samples)) : 0.f;
    m_level = rms / 32768.f;   // normalizar a [0, 1]
    emit levelChanged(m_level);
}

void AudioRecorder::onTick()
{
    ++m_elapsed;
    emit elapsedChanged(m_elapsed);
}

// ──────────────────────────────────────────────────────────────
//  WAV header (RIFF PCM estándar)
// ──────────────────────────────────────────────────────────────

void AudioRecorder::writeWavHeader()
{
    // Escribe 44 bytes de placeholder; se reescribirá en finalizeWav()
    QByteArray header(44, '\0');
    m_wavFile.write(header);
}

static void writeLE32(char *buf, int offset, quint32 val) {
    buf[offset+0] = (val      ) & 0xFF;
    buf[offset+1] = (val >>  8) & 0xFF;
    buf[offset+2] = (val >> 16) & 0xFF;
    buf[offset+3] = (val >> 24) & 0xFF;
}
static void writeLE16(char *buf, int offset, quint16 val) {
    buf[offset+0] = (val     ) & 0xFF;
    buf[offset+1] = (val >> 8) & 0xFF;
}

void AudioRecorder::finalizeWav()
{
    // Vuelve al inicio y escribe el header completo con tamaños reales
    char h[44];
    std::memcpy(h,    "RIFF", 4);
    writeLE32(h,  4, static_cast<quint32>(36 + m_dataBytes));
    std::memcpy(h+8,  "WAVE", 4);
    std::memcpy(h+12, "fmt ", 4);
    writeLE32(h, 16, 16);        // PCM chunk size
    writeLE16(h, 20, 1);         // PCM = 1
    writeLE16(h, 22, static_cast<quint16>(m_channels));
    writeLE32(h, 24, static_cast<quint32>(m_sampleRate));
    writeLE32(h, 28, static_cast<quint32>(m_sampleRate * m_channels * m_bitsPerSample / 8));
    writeLE16(h, 32, static_cast<quint16>(m_channels * m_bitsPerSample / 8));
    writeLE16(h, 34, static_cast<quint16>(m_bitsPerSample));
    std::memcpy(h+36, "data", 4);
    writeLE32(h, 40, static_cast<quint32>(m_dataBytes));

    m_wavFile.seek(0);
    m_wavFile.write(h, 44);
}

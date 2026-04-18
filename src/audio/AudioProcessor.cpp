#include "AudioProcessor.h"

#include <QProcess>
#include <QStandardPaths>
#include <QDir>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QDateTime>

// ──────────────────────────────────────────────────────────────
//  Helpers estáticos
// ──────────────────────────────────────────────────────────────

bool AudioProcessor::ffmpegAvailable()
{
    return !ffmpegPath().isEmpty();
}

QString AudioProcessor::ffmpegPath()
{
    // QStandardPaths::findExecutable busca en PATH
    return QStandardPaths::findExecutable("ffmpeg");
}

// ──────────────────────────────────────────────────────────────
//  Constructor / Destructor
// ──────────────────────────────────────────────────────────────

AudioProcessor::AudioProcessor(QObject *parent)
    : QObject(parent)
    , m_lufsTarget(-16)
{
}

AudioProcessor::~AudioProcessor()
{
    cancel();
    // Limpiar archivo temporal si existe
    if (!m_outputPath.isEmpty() && QFile::exists(m_outputPath))
        QFile::remove(m_outputPath);
}

// ──────────────────────────────────────────────────────────────
//  API pública
// ──────────────────────────────────────────────────────────────

void AudioProcessor::process(const QString &inputPath)
{
    if (!ffmpegAvailable()) {
        emit errorOccurred("FFmpeg no está instalado. Instala con: sudo apt install ffmpeg");
        return;
    }
    if (!QFile::exists(inputPath)) {
        emit errorOccurred(QString("Archivo de audio no encontrado: %1").arg(inputPath));
        return;
    }

    m_inputPath = inputPath;

    // Construir ruta de salida en directorio temporal de la app
    QString tmpDir = QStandardPaths::writableLocation(QStandardPaths::TempLocation)
                     + "/castopost";
    QDir().mkpath(tmpDir);

    QString baseName = QFileInfo(inputPath).completeBaseName();
    m_outputPath = tmpDir + "/" + baseName + "_norm_"
                   + QString::number(QDateTime::currentMSecsSinceEpoch()) + ".mp3";

    m_progress = 0;
    emit progressChanged(m_progress);

    startPass1();
}

void AudioProcessor::cancel()
{
    if (m_process && m_process->state() != QProcess::NotRunning) {
        m_process->kill();
        m_process->waitForFinished(2000);
    }
}

// ──────────────────────────────────────────────────────────────
//  Pasada 1 — medir loudness
// ──────────────────────────────────────────────────────────────

void AudioProcessor::startPass1()
{
    emit logLine(QString("Pass 1/2: midiendo loudness con EBU R128 (target: %1 LUFS)...").arg(m_lufsTarget));

    m_process = new QProcess(this);
    connect(m_process,
            QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, &AudioProcessor::onPass1Finished);
    connect(m_process, &QProcess::errorOccurred,
            this, &AudioProcessor::onProcessError);

    // FFmpeg escribe el JSON de loudnorm en stderr
    m_process->setProcessChannelMode(QProcess::MergedChannels);

    QStringList args = {
        "-y", "-i", m_inputPath,
        "-vn",
        "-af", QString("loudnorm=I=%1:TP=-1.5:LRA=11:print_format=json").arg(m_lufsTarget),
        "-f", "null", "/dev/null"
    };

    m_process->start(ffmpegPath(), args);
}

void AudioProcessor::onPass1Finished(int exitCode, QProcess::ExitStatus /*status*/)
{
    QByteArray output = m_process->readAll();
    m_process->deleteLater();
    m_process = nullptr;

    emit logLine(QString::fromUtf8(output.right(1000)));

    if (exitCode != 0) {
        emit errorOccurred("FFmpeg: error en la medición de loudness (pass 1).");
        return;
    }

    parseLoudnormStats(output);

    m_progress = 50;
    emit progressChanged(m_progress);

    startPass2();
}

// ──────────────────────────────────────────────────────────────
//  Pasada 2 — aplicar normalización y convertir a MP3
// ──────────────────────────────────────────────────────────────

void AudioProcessor::startPass2()
{
    emit logLine(QString("Pass 2/2: convirtiendo a MP3 192k con normalización %1 LUFS...").arg(m_lufsTarget));

    m_process = new QProcess(this);
    connect(m_process,
            QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, &AudioProcessor::onPass2Finished);
    connect(m_process, &QProcess::errorOccurred,
            this, &AudioProcessor::onProcessError);
    m_process->setProcessChannelMode(QProcess::MergedChannels);

    // Filtro loudnorm: dos pasadas si tenemos stats, una si no
    QString afFilter;
    if (m_stats.valid) {
        afFilter = QString(
            "loudnorm=I=%1:TP=-1.5:LRA=11"
            ":measured_I=%2:measured_TP=%3:measured_LRA=%4"
            ":measured_thresh=%5:offset=%6:linear=true"
        ).arg(QString::number(m_lufsTarget),
              m_stats.input_i, m_stats.input_tp, m_stats.input_lra,
              m_stats.input_thresh, m_stats.target_offset);
    } else {
        // Fallback de una sola pasada
        afFilter = QString("loudnorm=I=%1:TP=-1.5:LRA=11").arg(m_lufsTarget);
        emit logLine("Advertencia: usando normalización de una sola pasada (fallback).");
    }

    QStringList args = {
        "-y", "-i", m_inputPath,
        "-vn",
        "-af", afFilter,
        "-acodec", "libmp3lame",
        "-ab", "192k",
        "-ar", "44100",
        m_outputPath
    };

    m_process->start(ffmpegPath(), args);
}

void AudioProcessor::onPass2Finished(int exitCode, QProcess::ExitStatus /*status*/)
{
    QByteArray output = m_process->readAll();
    m_process->deleteLater();
    m_process = nullptr;

    emit logLine(QString::fromUtf8(output.right(500)));

    if (exitCode != 0 || !QFile::exists(m_outputPath)
        || QFileInfo(m_outputPath).size() < 1024)
    {
        emit errorOccurred("FFmpeg: error en la conversión a MP3 (pass 2).");
        return;
    }

    m_progress = 100;
    emit progressChanged(m_progress);

    emit finished(m_outputPath);
}

void AudioProcessor::onProcessError(QProcess::ProcessError err)
{
    Q_UNUSED(err)
    emit errorOccurred(QString("Error al ejecutar FFmpeg: %1")
                           .arg(m_process ? m_process->errorString() : "proceso inválido"));
}

// ──────────────────────────────────────────────────────────────
//  LUFS target configuration
// ──────────────────────────────────────────────────────────────

void AudioProcessor::setLufsTarget(int target)
{
    // Valid range for broadcast LUFS (typically -24 to -14)
    if (target < -24 || target > -14) {
        qWarning() << "LUFS target out of range, using -16";
        m_lufsTarget = -16;
    } else {
        m_lufsTarget = target;
    }
}

// ──────────────────────────────────────────────────────────────
//  Parser del JSON que devuelve loudnorm en pass-1
// ──────────────────────────────────────────────────────────────

void AudioProcessor::parseLoudnormStats(const QByteArray &ffmpegOutput)
{
    // Buscamos el bloque JSON que FFmpeg incluye en stderr
    // Suele aparecer entre llaves { ... } al final de la salida
    QRegularExpression re(R"(\{[^{}]+\})",
                          QRegularExpression::DotMatchesEverythingOption);
    auto it = re.globalMatch(QString::fromUtf8(ffmpegOutput));

    while (it.hasNext()) {
        auto match = it.next();
        QJsonDocument doc = QJsonDocument::fromJson(match.captured(0).toUtf8());
        if (doc.isNull() || !doc.isObject()) continue;
        QJsonObject o = doc.object();
        if (!o.contains("input_i")) continue;

        m_stats.input_i       = o["input_i"].toString();
        m_stats.input_tp      = o["input_tp"].toString();
        m_stats.input_lra     = o["input_lra"].toString();
        m_stats.input_thresh  = o["input_thresh"].toString();
        m_stats.target_offset = o["target_offset"].toString();
        m_stats.valid = !m_stats.input_i.isEmpty();
        return;
    }

    m_stats.valid = false;
    emit logLine("Advertencia: no se pudieron leer las estadísticas de loudnorm.");
}

void AudioProcessor::cleanup()
{
    // El destructor también llama esto; se puede llamar explícitamente
    // para borrar el MP3 temporal una vez subido a Castopod.
    if (!m_outputPath.isEmpty() && QFile::exists(m_outputPath)) {
        QFile::remove(m_outputPath);
        m_outputPath.clear();
    }
}

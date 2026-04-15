#include "AppController.h"
#include "../audio/AudioProcessor.h"

#include <QDir>
#include <QFile>
#include <QDateTime>

AppController::AppController(QObject *parent)
    : QObject(parent)
    , m_api(new CastopodClient(this))
    , m_audioProc(new AudioProcessor(this))
    , m_recorder(new AudioRecorder(this))
    , m_draftStore(new DraftStore(this))
    , m_templateStore(new TemplateStore(this))
    , m_podcastStore(new PodcastStore(this))
    , m_settings("castopost", "castopost")
{
    // ── API signals ─────────────────────────────────────────
    connect(m_api, &CastopodClient::episodesFetched, this,
            [this](int /*podcastId*/, const QList<Episode> &episodes) {
        m_episodes.clear();
        m_drafts.clear();
        int maxNum = 0;
        for (const Episode &e : episodes) {
            if (e.isDraft) m_drafts  << e.toVariantMap();
            else           m_episodes << e.toVariantMap();
            if (e.episodeNumber > maxNum) maxNum = e.episodeNumber;
        }
        m_nextEpisodeNumber = maxNum + 1;
        emit episodesChanged();
        setBusy(false);
    });

    connect(m_api, &CastopodClient::episodePublished, this,
            [this](const Episode &e) {
        setBusy(false);
        setStatus(QString("✓ Episodio '%1' publicado correctamente.").arg(e.title));
        emit episodePublishedOk(e.title);
        refreshEpisodes();
    });

    connect(m_api, &CastopodClient::errorOccurred, this,
            [this](const QString &msg) {
        setBusy(false);
        setStatus(msg, /*isError=*/true);
    });

    connect(m_api, &CastopodClient::uploadProgress, this,
            [this](qint64 sent, qint64 total) {
        if (total > 0) {
            m_uploadProgress = static_cast<int>(sent * 100 / total);
            emit uploadProgressChanged(m_uploadProgress);
        }
    });

    // ── AudioProcessor signals ───────────────────────────────
    connect(m_audioProc, &AudioProcessor::progressChanged, this,
            [this](int p) {
        m_conversionProgress = p;
        emit conversionProgressChanged(p);
    });

    connect(m_audioProc, &AudioProcessor::errorOccurred, this,
            [this](const QString &msg) {
        setBusy(false);
        setStatus(msg, true);
    });

    // finished conectado dinámicamente en publishEpisode (lleva closure con fields)

    // ── Aplicar config guardada ──────────────────────────────
    if (isConfigured()) {
        applyApiConfig();
        m_activePodcast = m_settings.value("defaultHandle").toString();
    }
}

// ──────────────────────────────────────────────────────────────
//  Configuración
// ──────────────────────────────────────────────────────────────

bool AppController::isConfigured() const
{
    return !m_settings.value("instanceUrl").toString().isEmpty()
        && !m_settings.value("apiUser").toString().isEmpty();
}

void AppController::saveSettings(const QString &instanceUrl,
                                  const QString &apiUser,
                                  const QString &apiPassword,
                                  const QString &defaultHandle,
                                  int            userId)
{
    m_settings.setValue("instanceUrl",    instanceUrl);
    m_settings.setValue("apiUser",        apiUser);
    m_settings.setValue("apiPassword",    apiPassword);
    m_settings.setValue("defaultHandle",  defaultHandle);
    m_settings.setValue("userId",         userId);
    applyApiConfig();
    if (m_activePodcast.isEmpty()) setActivePodcast(defaultHandle);
    emit configuredChanged();
    setStatus("Configuración guardada.");
}

QVariantMap AppController::loadSettings() const
{
    return {
        {"instanceUrl",   m_settings.value("instanceUrl").toString()},
        {"apiUser",       m_settings.value("apiUser").toString()},
        {"apiPassword",   m_settings.value("apiPassword").toString()},
        {"defaultHandle", m_settings.value("defaultHandle").toString()},
        {"userId",        m_settings.value("userId", 1).toInt()},
    };
}

void AppController::applyApiConfig()
{
    m_api->configure(
        m_settings.value("instanceUrl").toString(),
        m_settings.value("apiUser").toString(),
        m_settings.value("apiPassword").toString()
    );
}

// ──────────────────────────────────────────────────────────────
//  Podcasts
// ──────────────────────────────────────────────────────────────

QVariantList AppController::podcasts() const
{
    return m_podcastStore->all();
}

void AppController::setActivePodcast(const QString &handle)
{
    if (m_activePodcast == handle) return;
    m_activePodcast = handle;
    emit activePodcastChanged();
    refreshEpisodes();
}

void AppController::addPodcast(const QString &name, const QString &handle)
{
    if (!isConfigured()) { setStatus("Configura la app primero.", true); return; }
    setBusy(true);
    // Verificar que el handle existe en Castopod antes de guardar localmente
    connect(m_api, &CastopodClient::podcastIdResolved, this,
            [this, name, handle](const QString &h, int) {
        if (h == handle) {
            m_podcastStore->add(name, handle);
            emit podcastsChanged();
            setBusy(false);
            setStatus(QString("Podcast '%1' añadido.").arg(name));
        }
    }, Qt::SingleShotConnection);
    connect(m_api, &CastopodClient::errorOccurred, this,
            [this](const QString &msg) {
        setBusy(false); setStatus(msg, true);
    }, Qt::SingleShotConnection);

    m_api->resolvePodcastHandle(handle);
}

void AppController::removePodcast(const QString &handle)
{
    m_podcastStore->remove(handle);
    emit podcastsChanged();
    if (m_activePodcast == handle) {
        auto all = m_podcastStore->all();
        setActivePodcast(all.isEmpty() ? "" : all.first().toMap()["handle"].toString());
    }
}

void AppController::refreshEpisodes()
{
    if (!isConfigured() || m_activePodcast.isEmpty()) return;
    setBusy(true);

    connect(m_api, &CastopodClient::podcastIdResolved, this,
            [this](const QString &handle, int podcastId) {
        if (handle == m_activePodcast)
            m_api->fetchAllEpisodes(podcastId);
    }, Qt::SingleShotConnection);

    m_api->resolvePodcastHandle(m_activePodcast);
}

// ──────────────────────────────────────────────────────────────
//  Publicación
// ──────────────────────────────────────────────────────────────

void AppController::publishEpisode(const QVariantMap &fields,
                                    const QString &audioFilePath,
                                    const QString &coverFilePath)
{
    if (!isConfigured()) { setStatus("Configura la app primero.", true); return; }
    if (fields["title"].toString().isEmpty()) {
        setStatus("El título es obligatorio.", true); return;
    }
    if (audioFilePath.isEmpty() && fields["audioUrl"].toString().isEmpty()) {
        setStatus("Debes seleccionar un archivo de audio o proporcionar una URL.", true);
        return;
    }

    setBusy(true);
    m_uploadProgress    = 0;
    m_conversionProgress = 0;
    emit uploadProgressChanged(0);
    emit conversionProgressChanged(0);

    if (!audioFilePath.isEmpty()) {
        // Convertir primero a MP3 -16 LUFS
        setStatus("Convirtiendo audio a MP3...");

        // Conectar finished una sola vez con el closure que tiene los fields
        connect(m_audioProc, &AudioProcessor::finished, this,
                [this, fields, coverFilePath](const QString &mp3Path) {
            onAudioProcessed(mp3Path, fields, coverFilePath);
        }, Qt::SingleShotConnection);

        m_audioProc->process(audioFilePath);
    } else {
        // Audio URL — no necesita conversión
        onAudioProcessed(QString(), fields, coverFilePath);
    }
}

void AppController::onAudioProcessed(const QString &mp3Path,
                                      const QVariantMap &fields,
                                      const QString &coverPath)
{
    setStatus("Subiendo episodio a Castopod...");

    PublishRequest req;
    req.podcastHandle  = m_activePodcast;
    req.userId         = m_settings.value("userId", 1).toInt();
    req.title          = fields["title"].toString();
    req.description    = fields["description"].toString();
    req.slug           = fields["slug"].toString();
    req.episodeNumber  = fields["episodeNumber"].toInt();
    req.seasonNumber   = fields["seasonNumber"].toInt();
    req.type           = fields["type"].toString().isEmpty() ? "full" : fields["type"].toString();
    req.isExplicit     = fields["isExplicit"].toBool();
    req.publishedAt    = fields["publishedAt"].toString();
    req.audioFilePath  = mp3Path.isEmpty() ? QString() : mp3Path;
    req.audioUrl       = fields["audioUrl"].toString();
    req.coverFilePath  = coverPath;

    m_api->publishEpisode(req);
}

void AppController::publishCastopodDraft(int episodeId)
{
    if (!isConfigured()) { setStatus("Configura la app primero.", true); return; }
    setBusy(true);
    int userId = m_settings.value("userId", 1).toInt();
    m_api->publishDraft(episodeId, userId);
}

// ──────────────────────────────────────────────────────────────
//  Borradores locales
// ──────────────────────────────────────────────────────────────

QString AppController::saveDraft(const QVariantMap &fields)
{
    QString id = m_draftStore->saveDraft(m_activePodcast, fields);
    emit localDraftsChanged();
    return id;
}

QVariantList AppController::getDrafts()
{
    return m_draftStore->getDrafts(m_activePodcast);
}

QVariantMap AppController::getDraft(const QString &draftId)
{
    return m_draftStore->getDraft(m_activePodcast, draftId);
}

void AppController::deleteDraft(const QString &draftId)
{
    m_draftStore->deleteDraft(m_activePodcast, draftId);
    emit localDraftsChanged();
}

// ──────────────────────────────────────────────────────────────
//  Plantillas
// ──────────────────────────────────────────────────────────────

QVariantList AppController::getTemplates() { return m_templateStore->all(); }

QString AppController::addTemplate(const QString &name, const QString &body)
{
    return m_templateStore->add(name, body);
}

void AppController::updateTemplate(const QString &id, const QString &name, const QString &body)
{
    m_templateStore->update(id, name, body);
}

void AppController::deleteTemplate(const QString &id)
{
    m_templateStore->remove(id);
}

// ──────────────────────────────────────────────────────────────
//  Migración desde el proyecto PHP
// ──────────────────────────────────────────────────────────────

bool AppController::importFromPhpProject(const QString &dirPath)
{
    bool ok = true;
    if (QFile::exists(dirPath + "/local_drafts.json"))
        ok &= m_draftStore->importFromFile(dirPath + "/local_drafts.json");
    if (QFile::exists(dirPath + "/templates.json"))
        ok &= m_templateStore->importFromFile(dirPath + "/templates.json");
    if (QFile::exists(dirPath + "/podcasts.json"))
        ok &= m_podcastStore->importFromFile(dirPath + "/podcasts.json");

    emit podcastsChanged();
    setStatus(ok ? "Migración completada." : "Algunos archivos no se pudieron importar.", !ok);
    return ok;
}

// ──────────────────────────────────────────────────────────────
//  Misc
// ──────────────────────────────────────────────────────────────

bool AppController::ffmpegAvailable() const
{
    return AudioProcessor::ffmpegAvailable();
}

void AppController::clearStatus() { m_statusMsg.clear(); emit statusMessageChanged(); }

int AppController::nextEpisodeForSeason(int season) const
{
    int maxNum = 0;
    for (const QVariant &v : m_episodes) {
        QVariantMap ep = v.toMap();
        int epSeason = ep["seasonNumber"].toInt();
        // Si season==0 ignoramos la temporada; si no, filtramos
        if (season == 0 || epSeason == season) {
            int num = ep["episodeNumber"].toInt();
            if (num > maxNum) maxNum = num;
        }
    }
    return maxNum + 1;
}

void AppController::setBusy(bool busy)
{
    if (m_busy == busy) return;
    m_busy = busy;
    emit busyChanged();
}

void AppController::setStatus(const QString &msg, bool isError)
{
    m_statusMsg     = msg;
    m_statusIsError = isError;
    emit statusMessageChanged();
}

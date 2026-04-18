#pragma once
#include <QObject>
#include <QSettings>
#include <QVariantList>
#include <QVariantMap>

#include "../api/CastopodClient.h"
#include "../audio/AudioProcessor.h"
#include "../audio/AudioRecorder.h"
#include "../store/DraftStore.h"
#include "../store/TemplateStore.h"
#include "../store/PodcastStore.h"

/**
 * AppController
 *
 * Orquesta todos los subsistemas y se expone a QML como contexto raíz.
 * QML solo habla con AppController; nunca instancia clases C++ directamente.
 *
 * Registro en main.cpp:
 *   qmlRegisterSingletonInstance("castopost", 1, 0, "App", &controller);
 */
class AppController : public QObject
{
    Q_OBJECT

    // ── Estado general ──────────────────────────────────────
    Q_PROPERTY(bool    configured    READ isConfigured  NOTIFY configuredChanged)
    Q_PROPERTY(bool    busy          READ isBusy        NOTIFY busyChanged)
    Q_PROPERTY(QString statusMessage READ statusMessage NOTIFY statusMessageChanged)
    Q_PROPERTY(bool    statusIsError READ statusIsError NOTIFY statusMessageChanged)
    Q_PROPERTY(int     lufsTarget    READ lufsTarget    WRITE setLufsTarget NOTIFY lufsTargetChanged)

    // ── Podcast activo ───────────────────────────────────────
    Q_PROPERTY(QString activePodcast READ activePodcast WRITE setActivePodcast
               NOTIFY activePodcastChanged)
    Q_PROPERTY(QVariantList podcasts READ podcasts NOTIFY podcastsChanged)

    // ── Episodios ────────────────────────────────────────────
    Q_PROPERTY(QVariantList episodes          READ episodes          NOTIFY episodesChanged)
    Q_PROPERTY(QVariantList drafts            READ drafts            NOTIFY episodesChanged)
    Q_PROPERTY(int          nextEpisodeNumber READ nextEpisodeNumber NOTIFY episodesChanged)

    // ── Progreso de conversión / upload ──────────────────────
    Q_PROPERTY(int  conversionProgress READ conversionProgress
               NOTIFY conversionProgressChanged)
    Q_PROPERTY(int  uploadProgress     READ uploadProgress
               NOTIFY uploadProgressChanged)

    // ── Audio recorder ───────────────────────────────────────
    Q_PROPERTY(AudioRecorder* recorder READ recorder CONSTANT)

public:
    explicit AppController(QObject *parent = nullptr);

    // ── Getters ──────────────────────────────────────────────
    bool    isConfigured()       const;
    bool    isBusy()             const { return m_busy; }
    QString statusMessage()      const { return m_statusMsg; }
    bool    statusIsError()      const { return m_statusIsError; }
    QString activePodcast()      const { return m_activePodcast; }
    QVariantList podcasts()      const;
    QVariantList episodes()      const { return m_episodes; }
    QVariantList drafts()        const { return m_drafts; }
    int  nextEpisodeNumber()     const { return m_nextEpisodeNumber; }
    int  conversionProgress()    const { return m_conversionProgress; }
    int  uploadProgress()        const { return m_uploadProgress; }
    AudioRecorder* recorder()    const { return m_recorder; }

    // Devuelve el siguiente número de episodio para una temporada concreta.
    // Si season=0 devuelve el global (ignorando temporadas).
    Q_INVOKABLE int nextEpisodeForSeason(int season) const;

    // ── Configuración ────────────────────────────────────────
    Q_INVOKABLE void saveSettings(const QString &instanceUrl,
                                  const QString &apiUser,
                                  const QString &apiPassword,
                                  const QString &defaultHandle,
                                  int            userId);
    Q_INVOKABLE QVariantMap loadSettings() const;

    // ── Podcasts ─────────────────────────────────────────────
    Q_INVOKABLE void setActivePodcast(const QString &handle);
    Q_INVOKABLE void addPodcast(const QString &name, const QString &handle);
    Q_INVOKABLE void removePodcast(const QString &handle);
    Q_INVOKABLE void refreshEpisodes();

    // ── Publicación ──────────────────────────────────────────
    Q_INVOKABLE void publishEpisode(const QVariantMap &fields,
                                    const QString &audioFilePath,
                                    const QString &coverFilePath);
    Q_INVOKABLE void publishCastopodDraft(int episodeId);

    // ── Borradores locales ───────────────────────────────────
    Q_INVOKABLE QString      saveDraft(const QVariantMap &fields);
    Q_INVOKABLE QVariantList getDrafts();
    Q_INVOKABLE QVariantMap  getDraft(const QString &draftId);
    Q_INVOKABLE void         deleteDraft(const QString &draftId);

    // ── Plantillas ───────────────────────────────────────────
    Q_INVOKABLE QVariantList getTemplates();
    Q_INVOKABLE QString      addTemplate(const QString &name, const QString &body);
    Q_INVOKABLE void         updateTemplate(const QString &id, const QString &name,
                                             const QString &body);
    Q_INVOKABLE void         deleteTemplate(const QString &id);

    // ── Migración desde proyecto PHP ─────────────────────────
    Q_INVOKABLE bool importFromPhpProject(const QString &dirPath);

    // ── Misc ─────────────────────────────────────────────────
    Q_INVOKABLE void clearStatus();
    Q_INVOKABLE bool ffmpegAvailable() const;

    // LUFS target
    Q_INVOKABLE void setLufsTarget(int target);
    int lufsTarget() const { return m_lufsTarget; }

signals:
    void configuredChanged();
    void busyChanged();
    void statusMessageChanged();
    void activePodcastChanged();
    void podcastsChanged();
    void episodesChanged();
    void localDraftsChanged();
    void conversionProgressChanged(int percent);
    void uploadProgressChanged(int percent);
    void episodePublishedOk(const QString &title);
    void lufsTargetChanged();

private:
    void setBusy(bool busy);
    void setStatus(const QString &msg, bool isError = false);
    void applyApiConfig();

    // Flujo: audio → AudioProcessor → CastopodClient
    void onAudioProcessed(const QString &mp3Path, const QVariantMap &fields,
                          const QString &coverPath);

    CastopodClient *m_api;
    AudioProcessor *m_audioProc;
    AudioRecorder  *m_recorder;
    DraftStore     *m_draftStore;
    TemplateStore  *m_templateStore;
    PodcastStore   *m_podcastStore;
    QSettings       m_settings;

    QString      m_activePodcast;
    QVariantList m_episodes;
    QVariantList m_drafts;
    int          m_nextEpisodeNumber  = 1;
    bool         m_busy            = false;
    QString      m_statusMsg;
    bool         m_statusIsError   = false;
    int          m_conversionProgress = 0;
    int          m_uploadProgress     = 0;
    int          m_lufsTarget      = -16;
};

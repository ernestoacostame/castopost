#pragma once
#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QUrlQuery>
#include "ApiTypes.h"

/**
 * CastopodClient
 *
 * Cliente asíncrono para la REST API de Castopod.
 * Todos los métodos emiten señales con el resultado;
 * nunca bloquean el hilo principal.
 *
 * Equivalente C++/Qt de castopod.php
 */
class CastopodClient : public QObject
{
    Q_OBJECT

public:
    explicit CastopodClient(QObject *parent = nullptr);

    // Configura la conexión. Llama antes de cualquier request.
    void configure(const QString &instanceUrl,
                   const QString &apiUser,
                   const QString &apiPassword);

    bool isConfigured() const { return m_configured; }

    // ── Podcasts ──────────────────────────────────────────
    void fetchPodcasts();
    void fetchPodcastById(int podcastId);
    void resolvePodcastHandle(const QString &handle);   // → emite podcastIdResolved

    // ── Episodes ──────────────────────────────────────────
    void fetchRecentEpisodes(int podcastId, int limit = 20);
    void fetchAllEpisodes(int podcastId);

    // ── Publish ───────────────────────────────────────────
    // Flujo completo: crea episodio (draft) y luego lo publica.
    // La conversión FFmpeg la hace AudioProcessor antes de llamar aquí;
    // audioFilePath ya es un MP3 normalizado cuando llega.
    void publishEpisode(const PublishRequest &req);

    // Publica un borrador de Castopod ya existente por su ID
    void publishDraft(int episodeId, int userId);

signals:
    // ── Éxito ─────────────────────────────────────────────
    void podcastsFetched(const QList<Podcast> &podcasts);
    void podcastFetched(const Podcast &podcast);
    void podcastIdResolved(const QString &handle, int podcastId);
    void episodesFetched(int podcastId, const QList<Episode> &episodes);
    void episodePublished(const Episode &episode);
    void draftPublished(int episodeId);

    // ── Progreso (upload) ─────────────────────────────────
    void uploadProgress(qint64 bytesSent, qint64 bytesTotal);

    // ── Error ─────────────────────────────────────────────
    void errorOccurred(const QString &message);

private:
    // Helpers internos
    QNetworkRequest buildRequest(const QString &endpoint,
                                 const QUrlQuery &query = QUrlQuery()) const;
    void            handleReply(QNetworkReply *reply,
                                std::function<void(const QJsonDocument &)> onSuccess);

    // Paso 2 del flujo publishEpisode: crear draft en Castopod
    void createEpisodeDraft(int podcastId, const PublishRequest &req);
    // Paso 3: publicar el draft recién creado
    void publishCreatedDraft(int episodeId, int userId,
                             const QString &scheduledAt = {});

    QString m_baseUrl;
    QString m_authHeader;   // "Basic base64(user:pass)"
    bool    m_configured = false;

    QNetworkAccessManager *m_nam;
};

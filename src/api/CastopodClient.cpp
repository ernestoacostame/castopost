#include "CastopodClient.h"

#include <QNetworkRequest>
#include <QNetworkReply>
#include <QHttpMultiPart>
#include <QHttpPart>
#include <QUrlQuery>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QFile>
#include <QFileInfo>
#include <QMimeDatabase>
#include <QDateTime>
#include <QRegularExpression>

CastopodClient::CastopodClient(QObject *parent)
    : QObject(parent)
    , m_nam(new QNetworkAccessManager(this))
{
}

void CastopodClient::configure(const QString &instanceUrl,
                                const QString &apiUser,
                                const QString &apiPassword)
{
    m_baseUrl     = instanceUrl.trimmed().remove(QRegularExpression("/$")) + "/api/rest/v1";
    m_authHeader  = "Basic " + QString(apiUser + ":" + apiPassword).toUtf8().toBase64();
    m_configured  = true;
}

// ──────────────────────────────────────────────────────────────
//  Podcasts
// ──────────────────────────────────────────────────────────────

void CastopodClient::fetchPodcasts()
{
    auto req = buildRequest("/podcasts");
    handleReply(m_nam->get(req), [this](const QJsonDocument &doc) {
        QList<Podcast> list;
        for (const QJsonValue &v : doc.array())
            list << Podcast::fromJson(v.toObject());
        emit podcastsFetched(list);
    });
}

void CastopodClient::fetchPodcastById(int podcastId)
{
    auto req = buildRequest(QString("/podcasts/%1").arg(podcastId));
    handleReply(m_nam->get(req), [this](const QJsonDocument &doc) {
        emit podcastFetched(Podcast::fromJson(doc.object()));
    });
}

void CastopodClient::resolvePodcastHandle(const QString &handle)
{
    fetchPodcasts();
    // Conectamos una sola vez para interceptar la respuesta y filtrar por handle
    connect(this, &CastopodClient::podcastsFetched,
            this, [this, handle](const QList<Podcast> &podcasts) {
        for (const Podcast &p : podcasts) {
            if (p.handle == handle) {
                emit podcastIdResolved(handle, p.id);
                return;
            }
        }
        emit errorOccurred(
            QString("No se encontró podcast con handle '%1'").arg(handle));
    }, Qt::SingleShotConnection);
}

// ──────────────────────────────────────────────────────────────
//  Episodes
// ──────────────────────────────────────────────────────────────

void CastopodClient::fetchRecentEpisodes(int podcastId, int limit)
{
    QUrlQuery q;
    q.addQueryItem("podcastIds", QString::number(podcastId));
    q.addQueryItem("limit",      QString::number(limit));
    q.addQueryItem("order",      "newest");

    handleReply(m_nam->get(buildRequest("/episodes/", q)), [this, podcastId](const QJsonDocument &doc) {
        QList<Episode> list;
        QJsonArray arr = doc.isArray() ? doc.array()
                                       : doc.object()["data"].toArray();
        for (const QJsonValue &v : arr)
            list << Episode::fromJson(v.toObject());
        emit episodesFetched(podcastId, list);
    });
}

void CastopodClient::fetchAllEpisodes(int podcastId)
{
    // Paginación completa (replica PHP getAllEpisodes)
    struct State {
        QList<Episode> all;
        int offset   = 0;
        int pageSize = 100;
    };
    auto state = std::make_shared<State>();

    std::function<void()> fetchPage = [=, &fetchPage]() mutable {
        QUrlQuery q;
        q.addQueryItem("podcastIds", QString::number(podcastId));
        q.addQueryItem("limit",      QString::number(state->pageSize));
        q.addQueryItem("offset",     QString::number(state->offset));
        q.addQueryItem("order",      "newest");

        handleReply(m_nam->get(buildRequest("/episodes/", q)),
                    [this, state, podcastId, fetchPage](const QJsonDocument &doc) mutable {
            QJsonArray arr = doc.isArray() ? doc.array()
                                           : doc.object()["data"].toArray();
            if (arr.isEmpty() || state->offset >= 2000) {
                emit episodesFetched(podcastId, state->all);
                return;
            }
            for (const QJsonValue &v : arr)
                state->all << Episode::fromJson(v.toObject());

            if (arr.count() < state->pageSize) {
                emit episodesFetched(podcastId, state->all);
            } else {
                state->offset += state->pageSize;
                fetchPage();
            }
        });
    };
    fetchPage();
}

// ──────────────────────────────────────────────────────────────
//  Publish
// ──────────────────────────────────────────────────────────────

void CastopodClient::publishEpisode(const PublishRequest &req)
{
    // Paso 1: resolver handle → podcast_id, luego crear draft
    resolvePodcastHandle(req.podcastHandle);
    connect(this, &CastopodClient::podcastIdResolved,
            this, [this, req](const QString &handle, int podcastId) {
        if (handle == req.podcastHandle)
            createEpisodeDraft(podcastId, req);
    }, Qt::SingleShotConnection);
}

void CastopodClient::createEpisodeDraft(int podcastId, const PublishRequest &req)
{
    auto *multiPart = new QHttpMultiPart(QHttpMultiPart::FormDataType);

    auto addField = [&](const QString &name, const QString &value) {
        QHttpPart part;
        part.setHeader(QNetworkRequest::ContentDispositionHeader,
                       QString("form-data; name=\"%1\"").arg(name));
        part.setBody(value.toUtf8());
        multiPart->append(part);
    };

    // Campos obligatorios (equivalente a publishEpisode body en PHP)
    QString slug = req.slug.isEmpty()
        ? req.title.toLower()
              .replace(QRegularExpression("[^a-z0-9\\s-]"), "")
              .replace(QRegularExpression("[\\s]+"), "-")
              .left(80) + "-" + QString::number(QDateTime::currentSecsSinceEpoch())
        : req.slug;

    addField("podcast_id",  QString::number(podcastId));
    addField("created_by",  QString::number(req.userId));
    addField("updated_by",  QString::number(req.userId));
    addField("title",       req.title);
    addField("slug",        slug);
    addField("type",        req.type.isEmpty() ? "full" : req.type);

    if (!req.description.isEmpty())
        addField("description", req.description);
    if (req.episodeNumber > 0)
        addField("episode_number", QString::number(req.episodeNumber));
    if (req.seasonNumber > 0)
        addField("season_number", QString::number(req.seasonNumber));
    if (req.isExplicit)
        addField("parental_advisory", "explicit");
    if (!req.audioUrl.isEmpty())
        addField("audio_url", req.audioUrl);

    // Archivo de audio
    if (!req.audioFilePath.isEmpty()) {
        QFile *audioFile = new QFile(req.audioFilePath, multiPart);
        if (audioFile->open(QIODevice::ReadOnly)) {
            QHttpPart audioPart;
            audioPart.setHeader(QNetworkRequest::ContentTypeHeader, "audio/mpeg");
            audioPart.setHeader(QNetworkRequest::ContentDispositionHeader,
                                QString("form-data; name=\"audio_file\"; filename=\"%1\"")
                                    .arg(QFileInfo(req.audioFilePath).fileName()));
            audioPart.setBodyDevice(audioFile);
            multiPart->append(audioPart);
        }
    }

    // Cover opcional
    if (!req.coverFilePath.isEmpty()) {
        QFile *coverFile = new QFile(req.coverFilePath, multiPart);
        if (coverFile->open(QIODevice::ReadOnly)) {
            QMimeDatabase db;
            QString mime = db.mimeTypeForFile(req.coverFilePath).name();
            QHttpPart coverPart;
            coverPart.setHeader(QNetworkRequest::ContentTypeHeader, mime);
            coverPart.setHeader(QNetworkRequest::ContentDispositionHeader,
                                QString("form-data; name=\"cover\"; filename=\"%1\"")
                                    .arg(QFileInfo(req.coverFilePath).fileName()));
            coverPart.setBodyDevice(coverFile);
            multiPart->append(coverPart);
        }
    }

    QNetworkRequest request = buildRequest("/episodes/");
    QNetworkReply *reply = m_nam->post(request, multiPart);
    multiPart->setParent(reply);

    connect(reply, &QNetworkReply::uploadProgress, this, &CastopodClient::uploadProgress);

    handleReply(reply, [this, req](const QJsonDocument &doc) {
        // Castopod puede devolver el ID en varias estructuras:
        // {"id": 7, ...}  o  {"data": {"id": 7}}  o  [{"id": 7}]
        int episodeId = 0;

        if (doc.isObject()) {
            QJsonObject o = doc.object();
            // Caso directo: {"id": 7}
            if (o.contains("id"))
                episodeId = o["id"].toInt();
            // Caso anidado: {"data": {"id": 7}}
            else if (o.contains("data") && o["data"].isObject())
                episodeId = o["data"].toObject()["id"].toInt();
            // Algunos endpoints devuelven {"episode": {"id": 7}}
            else if (o.contains("episode") && o["episode"].isObject())
                episodeId = o["episode"].toObject()["id"].toInt();
        } else if (doc.isArray() && !doc.array().isEmpty()) {
            episodeId = doc.array().first().toObject()["id"].toInt();
        }

        if (!episodeId) {
            // Log completo para diagnóstico
            qWarning() << "[CastopodClient] Respuesta inesperada al crear episodio:"
                       << doc.toJson(QJsonDocument::Compact);
            emit errorOccurred(
                QString("Castopod no devolvió el ID del episodio. Respuesta: %1")
                    .arg(QString::fromUtf8(doc.toJson(QJsonDocument::Compact)).left(200)));
            return;
        }

        QString scheduledAt;
        if (!req.publishedAt.isEmpty()) {
            QDateTime dt = QDateTime::fromString(req.publishedAt, Qt::ISODate);
            if (dt.isValid() && dt > QDateTime::currentDateTime().addSecs(60))
                scheduledAt = dt.toString("yyyy-MM-dd HH:mm");
        }
        publishCreatedDraft(episodeId, req.userId, scheduledAt);
    });
}

void CastopodClient::publishCreatedDraft(int episodeId, int userId,
                                         const QString &scheduledAt)
{
    // Castopod espera application/x-www-form-urlencoded para el endpoint publish
    QUrlQuery body;
    body.addQueryItem("created_by", QString::number(userId));

    if (scheduledAt.isEmpty()) {
        body.addQueryItem("publication_method", "now");
    } else {
        body.addQueryItem("publication_method",       "schedule");
        body.addQueryItem("scheduled_publication_date", scheduledAt);
    }

    QNetworkRequest request = buildRequest(QString("/episodes/%1/publish").arg(episodeId));
    request.setHeader(QNetworkRequest::ContentTypeHeader,
                      "application/x-www-form-urlencoded");

    handleReply(m_nam->post(request, body.toString(QUrl::FullyEncoded).toUtf8()),
                [this, episodeId](const QJsonDocument &doc) {
        emit episodePublished(Episode::fromJson(doc.object()));
    });
}

void CastopodClient::publishDraft(int episodeId, int userId)
{
    publishCreatedDraft(episodeId, userId);
    connect(this, &CastopodClient::episodePublished,
            this, [this, episodeId](const Episode &) {
        emit draftPublished(episodeId);
    }, Qt::SingleShotConnection);
}

// ──────────────────────────────────────────────────────────────
//  Helpers
// ──────────────────────────────────────────────────────────────

QNetworkRequest CastopodClient::buildRequest(const QString &endpoint,
                                              const QUrlQuery &query) const
{
    QUrl url(m_baseUrl + endpoint);
    if (!query.isEmpty())
        url.setQuery(query);

    QNetworkRequest request(url);
    request.setRawHeader("Authorization", m_authHeader.toUtf8());
    request.setRawHeader("Accept",        "application/json");
    request.setTransferTimeout(600'000);  // 10 min para uploads grandes
    return request;
}

void CastopodClient::handleReply(QNetworkReply *reply,
                                  std::function<void(const QJsonDocument &)> onSuccess)
{
    connect(reply, &QNetworkReply::finished, this, [=]() {
        reply->deleteLater();

        if (reply->error() != QNetworkReply::NoError) {
            emit errorOccurred(QString("Error de conexión: %1").arg(reply->errorString()));
            return;
        }

        int httpCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        QByteArray raw = reply->readAll();
        QJsonDocument doc = QJsonDocument::fromJson(raw);

        if (httpCode >= 400) {
            QString msg;
            if (!doc.isNull() && doc.isObject()) {
                auto o = doc.object();
                msg = o["messages"].toObject()["error"].toString(
                      o["message"].toString(
                      o["error"].toString()));
            }
            if (msg.isEmpty())
                msg = QString::fromUtf8(raw.left(400));
            emit errorOccurred(QString("Castopod HTTP %1: %2").arg(httpCode).arg(msg));
            return;
        }

        onSuccess(doc);
    });
}

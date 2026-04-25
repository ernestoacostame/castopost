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
#include <QTimer>

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
    constexpr int kMaxEpisodes = 500;
    constexpr int pageSize = 100;

    struct State {
        QList<Episode> all;
        int offset = 0;
    };
    auto state = std::make_shared<State>();

    // Use shared_ptr to hold the recursive function, but schedule next call via QTimer
    auto fetchPage = std::make_shared<std::function<void()>>();

    *fetchPage = [this, state, podcastId, fetchPage]() mutable {
        if (state->all.size() >= kMaxEpisodes) {
            qWarning() << "fetchAllEpisodes: capped at" << kMaxEpisodes
                       << "episodes for podcast" << podcastId;
            emit episodesFetched(podcastId, state->all);
            return;
        }

        QUrlQuery q;
        q.addQueryItem("podcastIds", QString::number(podcastId));
        q.addQueryItem("limit",      QString::number(pageSize));
        q.addQueryItem("offset",     QString::number(state->offset));
        q.addQueryItem("order",      "newest");

        handleReply(m_nam->get(buildRequest("/episodes/", q)),
                    [this, state, podcastId, fetchPage](const QJsonDocument &doc) mutable {
                        QJsonArray arr = doc.isArray() ? doc.array()
                                                       : doc.object()["data"].toArray();
                        if (arr.isEmpty()) {
                            emit episodesFetched(podcastId, state->all);
                            return;
                        }

                        for (const QJsonValue &v : arr)
                            state->all << Episode::fromJson(v.toObject());

                        state->offset += arr.size();

                        // Check cap
                        if (state->all.size() >= kMaxEpisodes) {
                            qWarning() << "fetchAllEpisodes: capped at" << kMaxEpisodes
                                       << "episodes for podcast" << podcastId;
                            emit episodesFetched(podcastId, state->all);
                            return;
                        }

                        // Schedule next page asynchronously to avoid stack growth
                        if (arr.size() == pageSize && state->offset < 2000)
                            QTimer::singleShot(0, *fetchPage);
                        else
                            emit episodesFetched(podcastId, state->all);
                    });
    };

    // Start first page via QTimer to keep stack shallow
    QTimer::singleShot(0, *fetchPage);
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

    connect(reply, &QNetworkReply::finished, this,
            [this, reply, req]() {
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

        // Try to extract episode ID from JSON response
        int episodeId = 0;
        if (!doc.isNull()) {
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
                // Otro posible campo: "episode_id"
                else if (o.contains("episode_id"))
                    episodeId = o["episode_id"].toInt();
                // Si aún no, intentar con otros campos comunes de ID
                if (episodeId == 0) {
                    static const QStringList idKeys = {"id", "episode_id", "audio_id", "podcast_episode_id"};
                    for (const QString &key : idKeys) {
                        if (o.contains(key)) {
                            QJsonValue val = o.value(key);
                            if (val.isDouble()) {
                                episodeId = val.toInt();
                                break;
                            } else if (val.isString()) {
                                bool ok;
                                int candidate = val.toString().toInt(&ok);
                                if (ok) {
                                    episodeId = candidate;
                                    break;
                                }
                            }
                        }
                    }
                }
                // Si todavía no, buscar cualquier clave que termine con "_id"
                if (episodeId == 0) {
                    for (auto it = o.begin(); it != o.end(); ++it) {
                        QString key = it.key();
                        if (key.endsWith("_id")) {
                            QJsonValue val = it.value();
                            if (val.isDouble()) {
                                episodeId = val.toInt();
                                break;
                            } else if (val.isString()) {
                                bool ok;
                                int candidate = val.toString().toInt(&ok);
                                if (ok) {
                                    episodeId = candidate;
                                    break;
                                }
                            }
                        }
                    }
                }
            } else if (doc.isArray() && !doc.array().isEmpty()) {
                episodeId = doc.array().first().toObject()["id"].toInt();
            }
        }

        // If still not found, try to extract from Location header
        if (episodeId == 0) {
            QUrl location = reply->header(QNetworkRequest::LocationHeader).toUrl();
            if (location.isValid()) {
                QString path = location.path();
                QRegularExpression re1("/episodes/(\\d+)");
                QRegularExpression re2("/episode/(\\d+)");
                auto match = re1.match(path);
                if (!match.hasMatch()) {
                    match = re2.match(path);
                }
                if (match.hasMatch()) {
                    episodeId = match.captured(1).toInt();
                }
            }
        }

        // Fallback regex search in raw response
        if (episodeId == 0 && !raw.isEmpty()) {
            QRegularExpression reAudioId(R"xyz("audio_id"\s*:\s*"([0-9]+)")xyz");
            QRegularExpressionMatch match = reAudioId.match(raw);
            if (match.hasMatch()) {
                episodeId = match.captured(1).toInt();
                qWarning() << "[CastopodClient] Extracted episode ID from audio_id via regex:" << episodeId;
            } else {
                QRegularExpression reId(R"("id"\s*:\s*([0-9]+))");
                match = reId.match(raw);
                if (match.hasMatch()) {
                    episodeId = match.captured(1).toInt();
                    qWarning() << "[CastopodClient] Extracted episode ID from id via regex:" << episodeId;
                }
            }
        }

        if (!episodeId) {
            qWarning() << "[CastopodClient] Respuesta inesperada al crear episodio:"
                       << doc.toJson(QJsonDocument::Compact);
            qWarning() << "[CastopodClient] Raw response:" << raw.left(500);
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

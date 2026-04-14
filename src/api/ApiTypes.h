#pragma once
#include <QString>
#include <QDateTime>
#include <QJsonObject>
#include <QJsonArray>
#include <QList>

// ─────────────────────────────────────────────
//  Podcast
// ─────────────────────────────────────────────
struct Podcast {
    int     id      = 0;
    QString handle;
    QString title;
    QString description;
    QString coverUrl;

    static Podcast fromJson(const QJsonObject &o) {
        Podcast p;
        p.id          = o["id"].toInt();
        p.handle      = o["handle"].toString();
        p.title       = o["title"].toString();
        p.description = o["description"].toString();
        // cover puede venir como objeto {url:...} o string directo
        const QJsonValue cover = o["cover"];
        if (cover.isObject())
            p.coverUrl = cover.toObject()["url"].toString();
        else
            p.coverUrl = cover.toString();
        return p;
    }
};

// ─────────────────────────────────────────────
//  Episode
// ─────────────────────────────────────────────
struct Episode {
    int     id            = 0;
    QString title;
    QString slug;
    QString description;
    int     episodeNumber = 0;
    int     seasonNumber  = 0;
    QString type;          // full | trailer | bonus
    bool    isExplicit    = false;
    QString audioUrl;
    QString coverUrl;
    QString publishedAt;   // ISO string o vacío si es borrador
    QString createdAt;
    bool    isDraft       = false;

    static Episode fromJson(const QJsonObject &o) {
        Episode e;
        e.id            = o["id"].toInt();
        e.title         = o["title"].toString();
        e.slug          = o["slug"].toString();
        e.description   = o["description"].toString();
        e.episodeNumber = o["number"].toInt(o["episode_number"].toInt());
        e.seasonNumber  = o["season_number"].toInt();
        e.type          = o["type"].toString("full");
        e.isExplicit    = o["parental_advisory"].toString() == "explicit";

        // Audio URL
        const QJsonValue audio = o["audio"];
        if (audio.isObject())
            e.audioUrl = audio.toObject()["url"].toString();
        else
            e.audioUrl = audio.toString();

        // Cover
        const QJsonValue cover = o["cover"];
        if (cover.isObject())
            e.coverUrl = cover.toObject()["url"].toString();
        else
            e.coverUrl = cover.toString();

        // Castopod devuelve published_at como objeto {"date":"...", ...} o string
        const QJsonValue pub = o["published_at"];
        if (pub.isObject())
            e.publishedAt = pub.toObject()["date"].toString();
        else
            e.publishedAt = pub.toString();

        const QJsonValue cre = o["created_at"];
        if (cre.isObject())
            e.createdAt = cre.toObject()["date"].toString();
        else
            e.createdAt = cre.toString();

        e.isDraft = e.publishedAt.isEmpty();
        return e;
    }

    // Convierte a QVariantMap para exponer en QML
    QVariantMap toVariantMap() const {
        return {
            {"id",            id},
            {"title",         title},
            {"slug",          slug},
            {"description",   description},
            {"episodeNumber", episodeNumber},
            {"seasonNumber",  seasonNumber},
            {"type",          type},
            {"isExplicit",    isExplicit},
            {"audioUrl",      audioUrl},
            {"coverUrl",      coverUrl},
            {"publishedAt",   publishedAt},
            {"createdAt",     createdAt},
            {"isDraft",       isDraft},
        };
    }
};

// ─────────────────────────────────────────────
//  PublishRequest  (datos del formulario)
// ─────────────────────────────────────────────
struct PublishRequest {
    QString podcastHandle;
    int     userId        = 1;

    // Metadatos del episodio
    QString title;
    QString description;
    QString slug;
    int     episodeNumber = 0;
    int     seasonNumber  = 0;
    QString type          = "full";
    bool    isExplicit    = false;
    QString publishedAt;   // vacío = publicar ahora

    // Audio: exactamente uno de estos tres estará presente
    QString audioFilePath;  // archivo local subido / grabado
    QString audioUrl;       // URL remota

    // Cover opcional
    QString coverFilePath;
};

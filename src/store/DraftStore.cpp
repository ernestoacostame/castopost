#include "DraftStore.h"

#include <QStandardPaths>
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonArray>
#include <QDateTime>
#include <QUuid>

DraftStore::DraftStore(QObject *parent) : QObject(parent) { load(); }

QString DraftStore::filePath() const
{
    QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(dir);
    return dir + "/local_drafts.json";
}

void DraftStore::load()
{
    QFile f(filePath());
    if (!f.open(QIODevice::ReadOnly)) return;
    auto doc = QJsonDocument::fromJson(f.readAll());
    m_data   = doc.isObject() ? doc.object() : QJsonObject{};
}

void DraftStore::save() const
{
    QFile f(filePath());
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) return;
    f.write(QJsonDocument(m_data).toJson(QJsonDocument::Indented));
}

QString DraftStore::saveDraft(const QString &podcastHandle, const QVariantMap &fields)
{
    QString id = fields.value("draft_id").toString();
    if (id.isEmpty())
        id = "draft_" + QUuid::createUuid().toString(QUuid::WithoutBraces).left(12);

    QJsonObject podcast = m_data[podcastHandle].toObject();
    QJsonObject draft   = QJsonObject::fromVariantMap(fields);
    draft["draft_id"] = id;
    draft["podcast"]  = podcastHandle;
    draft["saved_at"] = QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm:ss");
    podcast[id]       = draft;
    m_data[podcastHandle] = podcast;
    save();
    return id;
}

QVariantList DraftStore::getDrafts(const QString &podcastHandle) const
{
    QJsonObject podcast = m_data[podcastHandle].toObject();
    QVariantList list;
    for (const QString &key : podcast.keys())
        list << podcast[key].toObject().toVariantMap();

    // Ordenar por saved_at descendente
    std::sort(list.begin(), list.end(), [](const QVariant &a, const QVariant &b) {
        return a.toMap()["saved_at"].toString() > b.toMap()["saved_at"].toString();
    });
    return list;
}

QVariantMap DraftStore::getDraft(const QString &podcastHandle, const QString &draftId) const
{
    return m_data[podcastHandle].toObject()[draftId].toObject().toVariantMap();
}

void DraftStore::deleteDraft(const QString &podcastHandle, const QString &draftId)
{
    QJsonObject podcast = m_data[podcastHandle].toObject();
    podcast.remove(draftId);
    m_data[podcastHandle] = podcast;
    save();
}

void DraftStore::clearPodcastDrafts(const QString &podcastHandle)
{
    m_data.remove(podcastHandle);
    save();
}

bool DraftStore::importFromFile(const QString &filePath)
{
    QFile f(filePath);
    if (!f.open(QIODevice::ReadOnly)) return false;
    auto doc = QJsonDocument::fromJson(f.readAll());
    if (!doc.isObject()) return false;
    // Merge: no sobreescribe drafts existentes
    QJsonObject imported = doc.object();
    for (const QString &handle : imported.keys()) {
        QJsonObject existing = m_data[handle].toObject();
        QJsonObject newDrafts = imported[handle].toObject();
        for (const QString &id : newDrafts.keys())
            if (!existing.contains(id))
                existing[id] = newDrafts[id];
        m_data[handle] = existing;
    }
    save();
    return true;
}

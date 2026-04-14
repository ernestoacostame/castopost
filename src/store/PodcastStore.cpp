#include "PodcastStore.h"
#include <QStandardPaths>
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>

PodcastStore::PodcastStore(QObject *parent) : QObject(parent) { load(); }

QString PodcastStore::filePath() const {
    QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(dir);
    return dir + "/podcasts.json";
}
void PodcastStore::load() {
    QFile f(filePath());
    if (!f.open(QIODevice::ReadOnly)) return;
    auto doc = QJsonDocument::fromJson(f.readAll());
    m_data = doc.isArray() ? doc.array() : QJsonArray{};
}
void PodcastStore::save() const {
    QFile f(filePath());
    if (!f.open(QIODevice::WriteOnly|QIODevice::Truncate)) return;
    f.write(QJsonDocument(m_data).toJson(QJsonDocument::Indented));
}
QVariantList PodcastStore::all() const {
    QVariantList l; for (auto v : m_data) l << v.toObject().toVariantMap(); return l;
}
void PodcastStore::add(const QString &name, const QString &handle) {
    if (contains(handle)) return;
    QJsonObject o; o["name"]=name; o["handle"]=handle;
    m_data.append(o); save();
}
void PodcastStore::remove(const QString &handle) {
    for (int i=0;i<m_data.count();++i)
        if (m_data[i].toObject()["handle"].toString()==handle) { m_data.removeAt(i); save(); return; }
}
bool PodcastStore::contains(const QString &handle) const {
    for (auto v : m_data) if (v.toObject()["handle"].toString()==handle) return true;
    return false;
}
bool PodcastStore::importFromFile(const QString &filePath) {
    QFile f(filePath);
    if (!f.open(QIODevice::ReadOnly)) return false;
    auto doc = QJsonDocument::fromJson(f.readAll());
    if (!doc.isArray()) return false;
    for (auto v : doc.array()) {
        auto o = v.toObject();
        add(o["name"].toString(), o["handle"].toString());
    }
    return true;
}

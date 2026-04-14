#include "TemplateStore.h"

#include <QStandardPaths>
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QDateTime>
#include <QUuid>

TemplateStore::TemplateStore(QObject *parent) : QObject(parent) { load(); }

QString TemplateStore::filePath() const
{
    QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(dir);
    return dir + "/templates.json";
}

void TemplateStore::load()
{
    QFile f(filePath());
    if (!f.open(QIODevice::ReadOnly)) {
        // Semilla con plantilla por defecto (igual que PHP)
        QJsonObject tpl;
        tpl["id"]          = "default";
        tpl["name"]        = "Plantilla base";
        tpl["description"] = "En este episodio:\n\n- \n- \n- \n\n---\n\nSígueme en:\n- Web: \n- Mastodon: \n- YouTube: ";
        tpl["created_at"]  = QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm:ss");
        m_data.append(tpl);
        save();
        return;
    }
    auto doc = QJsonDocument::fromJson(f.readAll());
    m_data   = doc.isArray() ? doc.array() : QJsonArray{};
}

void TemplateStore::save() const
{
    QFile f(filePath());
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) return;
    f.write(QJsonDocument(m_data).toJson(QJsonDocument::Indented));
}

QVariantList TemplateStore::all() const
{
    QVariantList list;
    for (const auto &v : m_data) list << v.toObject().toVariantMap();
    return list;
}

QVariantMap TemplateStore::get(const QString &id) const
{
    for (const auto &v : m_data)
        if (v.toObject()["id"].toString() == id)
            return v.toObject().toVariantMap();
    return {};
}

QString TemplateStore::add(const QString &name, const QString &description)
{
    QString id = "tpl_" + QUuid::createUuid().toString(QUuid::WithoutBraces).left(12);
    QJsonObject t;
    t["id"]          = id;
    t["name"]        = name;
    t["description"] = description;
    t["created_at"]  = QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm:ss");
    m_data.append(t);
    save();
    return id;
}

void TemplateStore::update(const QString &id, const QString &name, const QString &description)
{
    for (int i = 0; i < m_data.count(); ++i) {
        QJsonObject o = m_data[i].toObject();
        if (o["id"].toString() == id) {
            o["name"]        = name;
            o["description"] = description;
            o["updated_at"]  = QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm:ss");
            m_data[i]        = o;
            save();
            return;
        }
    }
}

void TemplateStore::remove(const QString &id)
{
    if (id == "default") return;
    for (int i = 0; i < m_data.count(); ++i)
        if (m_data[i].toObject()["id"].toString() == id) {
            m_data.removeAt(i);
            save();
            return;
        }
}

bool TemplateStore::importFromFile(const QString &filePath)
{
    QFile f(filePath);
    if (!f.open(QIODevice::ReadOnly)) return false;
    auto doc = QJsonDocument::fromJson(f.readAll());
    if (!doc.isArray()) return false;
    // Solo importa IDs nuevos
    QSet<QString> existing;
    for (const auto &v : m_data) existing.insert(v.toObject()["id"].toString());
    for (const auto &v : doc.array()) {
        QString tid = v.toObject()["id"].toString();
        if (!existing.contains(tid)) m_data.append(v);
    }
    save();
    return true;
}

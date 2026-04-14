#pragma once
#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QJsonArray>

/**
 * PodcastStore
 *
 * Lista de podcasts gestionados localmente (handle + nombre).
 * Equivale a podcasts_store.php + podcasts.json del proyecto PHP.
 */
class PodcastStore : public QObject
{
    Q_OBJECT
public:
    explicit PodcastStore(QObject *parent = nullptr);

    Q_INVOKABLE QVariantList all() const;
    Q_INVOKABLE void add(const QString &name, const QString &handle);
    Q_INVOKABLE void remove(const QString &handle);
    Q_INVOKABLE bool contains(const QString &handle) const;

    bool importFromFile(const QString &filePath);

private:
    void load(); void save() const; QString filePath() const;
    QJsonArray m_data;
};

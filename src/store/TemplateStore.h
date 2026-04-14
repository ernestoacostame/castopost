#pragma once
#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QJsonArray>

class TemplateStore : public QObject
{
    Q_OBJECT
public:
    explicit TemplateStore(QObject *parent = nullptr);

    Q_INVOKABLE QVariantList all() const;
    Q_INVOKABLE QVariantMap  get(const QString &id) const;
    Q_INVOKABLE QString      add(const QString &name, const QString &description);
    Q_INVOKABLE void         update(const QString &id, const QString &name,
                                    const QString &description);
    Q_INVOKABLE void         remove(const QString &id);

    bool importFromFile(const QString &filePath);

private:
    void    load();
    void    save() const;
    QString filePath() const;

    QJsonArray m_data;
};

#pragma once
#include <QObject>
#include <QJsonObject>
#include <QVariantList>
#include <QVariantMap>

/**
 * DraftStore
 *
 * Persiste borradores locales de episodios en un JSON en AppDataLocation.
 * Formato compatible con local_drafts.json del proyecto PHP original.
 *
 * Clave: podcastHandle → { draftId → { campos } }
 */
class DraftStore : public QObject
{
    Q_OBJECT

public:
    explicit DraftStore(QObject *parent = nullptr);

    // Guarda o actualiza un borrador. Si draftId está vacío crea uno nuevo.
    // Devuelve el id resultante.
    Q_INVOKABLE QString saveDraft(const QString &podcastHandle,
                                  const QVariantMap &fields);

    Q_INVOKABLE QVariantList getDrafts(const QString &podcastHandle) const;
    Q_INVOKABLE QVariantMap  getDraft(const QString &podcastHandle,
                                      const QString &draftId) const;
    Q_INVOKABLE void deleteDraft(const QString &podcastHandle,
                                  const QString &draftId);
    Q_INVOKABLE void clearPodcastDrafts(const QString &podcastHandle);

    // Importa un local_drafts.json del proyecto PHP
    bool importFromFile(const QString &filePath);

private:
    void load();
    void save() const;
    QString filePath() const;

    QJsonObject m_data;   // { handle: { draftId: {...} } }
};

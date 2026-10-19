// Kalyna OS native shell: connection to the Python system service (kalyna-system).
#pragma once
#include <QHash>
#include <QJSValue>
#include <QLocalSocket>
#include <QObject>
#include <QTimer>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

class SystemClient : public QObject {
    Q_OBJECT
    QML_NAMED_ELEMENT(System)
    QML_SINGLETON
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
    Q_PROPERTY(QVariantMap info READ info NOTIFY infoChanged)
    Q_PROPERTY(QVariantMap battery READ battery NOTIFY batteryChanged)
    Q_PROPERTY(QVariantMap volume READ volume NOTIFY volumeChanged)
    Q_PROPERTY(QVariantMap brightness READ brightness NOTIFY brightnessChanged)
    Q_PROPERTY(QVariantMap wifi READ wifi NOTIFY wifiChanged)
    Q_PROPERTY(QVariantMap bt READ bt NOTIFY btChanged)
    Q_PROPERTY(QVariantList apps READ apps NOTIFY appsChanged)

public:
    explicit SystemClient(QObject *parent = nullptr);

    bool connected() const { return m_sock.state() == QLocalSocket::ConnectedState; }
    QVariantMap info() const { return m_state.value("info").toMap(); }
    QVariantMap battery() const { return m_state.value("battery").toMap(); }
    QVariantMap volume() const { return m_state.value("volume").toMap(); }
    QVariantMap brightness() const { return m_state.value("brightness").toMap(); }
    QVariantMap wifi() const { return m_state.value("wifi").toMap(); }
    QVariantMap bt() const { return m_state.value("bt").toMap(); }
    QVariantList apps() const { return m_apps; }

    // call a service command; the optional callback gets (ok, data, error)
    Q_INVOKABLE void call(const QString &cmd, const QVariantMap &args = {}, const QJSValue &callback = QJSValue());
    Q_INVOKABLE void refreshApps();

signals:
    void connectedChanged();
    void infoChanged();
    void batteryChanged();
    void volumeChanged();
    void brightnessChanged();
    void wifiChanged();
    void btChanged();
    void appsChanged();
    void event(const QString &name, const QVariant &data);

private:
    void connectNow();
    void onReadyRead();
    void setState(const QString &key, const QVariant &v);

    QLocalSocket m_sock;
    QTimer m_retry;
    QByteArray m_buf;
    int m_nextId = 1;
    QHash<int, QJSValue> m_callbacks;
    QHash<int, QString> m_pendingState;   // request id -> state key it fills
    QVariantMap m_state;
    QVariantList m_apps;
    QString m_path;
};

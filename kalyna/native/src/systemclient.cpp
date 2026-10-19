#include "systemclient.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QJSEngine>
#include <QQmlEngine>

SystemClient::SystemClient(QObject *parent) : QObject(parent)
{
    m_path = qEnvironmentVariable("KALYNA_SYSTEM_SOCK");
    m_retry.setInterval(400);
    m_retry.setSingleShot(true);
    connect(&m_retry, &QTimer::timeout, this, &SystemClient::connectNow);
    connect(&m_sock, &QLocalSocket::connected, this, [this] {
        emit connectedChanged();
        // everything the shell shows from the first frame
        const QStringList initial{"info", "battery", "volume.get", "brightness.get", "wifi.state", "bt.state"};
        const QStringList keys{"info", "battery", "volume", "brightness", "wifi", "bt"};
        for (int i = 0; i < initial.size(); ++i) {
            m_pendingState.insert(m_nextId, keys[i]);
            call(initial[i]);
        }
        refreshApps();
    });
    connect(&m_sock, &QLocalSocket::disconnected, this, [this] {
        emit connectedChanged();
        m_retry.start();
    });
    connect(&m_sock, &QLocalSocket::errorOccurred, this, [this](QLocalSocket::LocalSocketError) {
        if (!m_retry.isActive() && m_sock.state() != QLocalSocket::ConnectedState)
            m_retry.start();
    });
    connect(&m_sock, &QLocalSocket::readyRead, this, &SystemClient::onReadyRead);
    connectNow();
}

void SystemClient::connectNow()
{
    if (m_path.isEmpty() || m_sock.state() != QLocalSocket::UnconnectedState)
        return;
    m_sock.connectToServer(m_path);
}

void SystemClient::call(const QString &cmd, const QVariantMap &args, const QJSValue &callback)
{
    const int id = m_nextId++;
    static const QHash<QString, QString> setters{{"volume.set", "volume"}, {"brightness.set", "brightness"},
        {"wifi.enable", "wifi"}, {"bt.enable", "bt"}, {"wifi.state", "wifi"}, {"battery", "battery"}};
    if (setters.contains(cmd) && !m_pendingState.contains(id))
        m_pendingState.insert(id, setters.value(cmd));
    if (callback.isCallable())
        m_callbacks.insert(id, callback);
    if (!connected()) {
        if (callback.isCallable()) {
            QJSValue cb = m_callbacks.take(id);
            cb.call({false, QJSValue(), QStringLiteral("Kalyna system service is not running")});
        }
        return;
    }
    QJsonObject o{{"id", id}, {"cmd", cmd}, {"args", QJsonObject::fromVariantMap(args)}};
    m_sock.write(QJsonDocument(o).toJson(QJsonDocument::Compact) + '\n');
}

void SystemClient::refreshApps()
{
    call("apps.list", {}, QJSValue());
    m_pendingState.insert(m_nextId - 1, "apps");
}

void SystemClient::setState(const QString &key, const QVariant &v)
{
    if (key == "apps") {
        m_apps = v.toList();
        emit appsChanged();
        return;
    }
    if (m_state.value(key) == v)
        return;
    m_state.insert(key, v);
    if (key == "info") emit infoChanged();
    else if (key == "battery") emit batteryChanged();
    else if (key == "volume") emit volumeChanged();
    else if (key == "brightness") emit brightnessChanged();
    else if (key == "wifi") emit wifiChanged();
    else if (key == "bt") emit btChanged();
}

void SystemClient::onReadyRead()
{
    m_buf += m_sock.readAll();
    int nl;
    while ((nl = m_buf.indexOf('\n')) >= 0) {
        const QByteArray line = m_buf.left(nl);
        m_buf.remove(0, nl + 1);
        const QJsonObject o = QJsonDocument::fromJson(line).object();
        if (o.contains("event")) {
            const QString name = o.value("event").toString();
            const QVariant data = o.value("data").toVariant();
            setState(name, data);
            emit event(name, data);
            continue;
        }
        const int id = o.value("id").toInt();
        const bool ok = o.value("ok").toBool();
        const QVariant data = o.value("data").toVariant();
        if (ok && m_pendingState.contains(id))
            setState(m_pendingState.value(id), data);
        m_pendingState.remove(id);
        // replies to setters also refresh the matching state
        if (m_callbacks.contains(id)) {
            QJSValue cb = m_callbacks.take(id);
            QJSEngine *eng = qjsEngine(this);
            if (eng && cb.isCallable())
                cb.call({ok, eng->toScriptValue(data), o.value("error").toString()});
        }
    }
}

// Kalyna OS native shell: small helpers the QML side needs from C++.
#pragma once
#include <QElapsedTimer>
#include <QHash>
#include <QObject>
#include <QUrl>
#include <QtQml/qqmlregistration.h>

#include <QQuickItem>
#include <QTimer>
#include <array>
#include <SDL.h>

class Shell : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(QString version READ version CONSTANT)
    Q_PROPERTY(bool nested READ nested CONSTANT)
    Q_PROPERTY(QString assets READ assets CONSTANT)
    Q_PROPERTY(QString product READ product CONSTANT)
    Q_PROPERTY(QString defaultRotation READ defaultRotation CONSTANT)
    Q_PROPERTY(QString forcedRotation READ forcedRotation CONSTANT)
    Q_PROPERTY(QString socketName READ socketName CONSTANT)
    Q_PROPERTY(bool touchLast READ touchLast NOTIFY touchLastChanged)
    Q_PROPERTY(QString screenshotPath READ screenshotPath CONSTANT)
    // phone layout (home screen + app drawer) and a fixed UI scale, set by Kalyna on Android
    Q_PROPERTY(bool phone READ phone CONSTANT)
    Q_PROPERTY(qreal uiScale READ uiScale CONSTANT)
    Q_PROPERTY(bool controllerConnected READ controllerConnected NOTIFY controllerChanged)
    Q_PROPERTY(int controllerAxisX READ controllerAxisX NOTIFY controllerChanged)
    Q_PROPERTY(int controllerAxisY READ controllerAxisY NOTIFY controllerChanged)

public:
    explicit Shell(QObject *parent = nullptr);

    QString version() const;
    bool nested() const;
    QString assets() const;
    QString product() const;
    QString defaultRotation() const;
    QString forcedRotation() const;
    QString socketName() const;
    QString screenshotPath() const;
    bool phone() const;
    qreal uiScale() const;
    bool controllerConnected() const { return m_controller != nullptr; }
    int controllerAxisX() const { return m_axisX; }
    int controllerAxisY() const { return m_axisY; }
    bool touchLast() const { return m_touchLast; }

    Q_INVOKABLE QUrl asset(const QString &rel) const;
    Q_INVOKABLE QUrl glyph(const QString &name, const QString &color = QStringLiteral("#ffffff")) const;
    Q_INVOKABLE QUrl fileUrl(const QString &path) const;
    Q_INVOKABLE bool exists(const QString &path) const;
    Q_INVOKABLE void quit();
    // for automated tests and the "screenshot" feature: save the window to a PNG
    Q_INVOKABLE bool grab(QQuickItem *item, const QString &path);
    // tests: a mouse click at (x, y) inside item, delivered like a real one (reaches apps too)
    Q_INVOKABLE void click(QQuickItem *item, qreal x, qreal y);

signals:
    void touchLastChanged();
    void controllerChanged();
    void controllerAction(const QString &action);

protected:
    bool eventFilter(QObject *obj, QEvent *ev) override;

private:
    bool m_touchLast = false;
    SDL_GameController *m_controller = nullptr;
    QTimer m_controllerTimer;
    std::array<bool, 32> m_controllerButtons{};
    int m_axisX = 0;
    int m_axisY = 0;
    void pollController();
    mutable QHash<QString, QByteArray> m_glyphs;
};

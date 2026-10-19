// Kalyna OS native shell: small helpers the QML side needs from C++.
#pragma once
#include <QElapsedTimer>
#include <QHash>
#include <QObject>
#include <QUrl>
#include <QtQml/qqmlregistration.h>

#include <QQuickItem>

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

protected:
    bool eventFilter(QObject *obj, QEvent *ev) override;

private:
    bool m_touchLast = false;
    mutable QHash<QString, QByteArray> m_glyphs;
};

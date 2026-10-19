#include "shell.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QImage>
#include <QQuickItem>
#include <QQuickWindow>
#include <QTouchEvent>
#include <QMouseEvent>

Shell::Shell(QObject *parent) : QObject(parent)
{
    // remember whether the last input came from the touchscreen (shows the on-screen keyboard then)
    qApp->installEventFilter(this);
}

bool Shell::eventFilter(QObject *obj, QEvent *ev)
{
    switch (ev->type()) {
    case QEvent::TouchBegin:
        if (!m_touchLast) { m_touchLast = true; emit touchLastChanged(); }
        break;
    case QEvent::KeyPress:
    case QEvent::MouseButtonPress:
        if (ev->type() == QEvent::MouseButtonPress &&
            static_cast<QMouseEvent *>(ev)->source() != Qt::MouseEventNotSynthesized)
            break;   // synthesized from touch
        if (m_touchLast && ev->type() == QEvent::KeyPress) { m_touchLast = false; emit touchLastChanged(); }
        break;
    default:
        break;
    }
    return QObject::eventFilter(obj, ev);
}

QString Shell::version() const { return QStringLiteral(KALYNA_VERSION); }
bool Shell::nested() const { return qEnvironmentVariableIntValue("KALYNA_NESTED") == 1; }
QString Shell::assets() const { return qEnvironmentVariable("KALYNA_ASSETS"); }
QString Shell::socketName() const { return qEnvironmentVariable("KALYNA_WAYLAND_SOCKET", "wayland-kalyna"); }
QString Shell::screenshotPath() const { return qEnvironmentVariable("KALYNA_SCREENSHOT"); }
QString Shell::forcedRotation() const { return qEnvironmentVariable("KALYNA_ROTATE"); }

QString Shell::product() const
{
    QFile f("/sys/class/dmi/id/product_name");
    return f.open(QIODevice::ReadOnly) ? QString::fromUtf8(f.readAll()).trimmed() : QString();
}

QString Shell::defaultRotation() const
{
    // Steam Deck LCD (Jupiter) and OLED (Galileo) have a portrait panel mounted sideways
    const QString p = product();
    if (!nested() && (p == "Jupiter" || p == "Galileo"))
        return QStringLiteral("cw");
    return QStringLiteral("none");
}

QUrl Shell::asset(const QString &rel) const { return QUrl::fromLocalFile(QDir(assets()).filePath(rel)); }
QUrl Shell::glyph(const QString &name, const QString &color) const
{
    // the glyph SVG with its stroke in the wanted colour, as a data: URL (cached per glyph)
    if (!m_glyphs.contains(name)) {
        QFile f(QDir(assets()).filePath("glyphs/" + name + ".svg"));
        m_glyphs.insert(name, f.open(QIODevice::ReadOnly) ? f.readAll() : QByteArray());
    }
    QByteArray svg = m_glyphs.value(name);
    if (svg.isEmpty())
        return QUrl();
    svg.replace("#ffffff", color.toUtf8());
    return QUrl(QStringLiteral("data:image/svg+xml;base64,") + QString::fromLatin1(svg.toBase64()));
}
QUrl Shell::fileUrl(const QString &path) const { return path.isEmpty() ? QUrl() : QUrl::fromLocalFile(path); }
bool Shell::exists(const QString &path) const { return QFileInfo::exists(path); }
void Shell::quit() { QCoreApplication::quit(); }

bool Shell::grab(QQuickItem *item, const QString &path)
{
    if (!item || !item->window())
        return false;
    const QImage img = item->window()->grabWindow();
    return !img.isNull() && img.save(path);
}

void Shell::click(QQuickItem *item, qreal x, qreal y)
{
    if (!item || !item->window())
        return;
    QQuickWindow *w = item->window();
    const QPointF sp = item->mapToScene(QPointF(x, y));
    const QPointF gp = w->mapToGlobal(sp);
    QMouseEvent move(QEvent::MouseMove, sp, sp, gp, Qt::NoButton, Qt::NoButton, Qt::NoModifier);
    QMouseEvent press(QEvent::MouseButtonPress, sp, sp, gp, Qt::LeftButton, Qt::LeftButton, Qt::NoModifier);
    QMouseEvent release(QEvent::MouseButtonRelease, sp, sp, gp, Qt::LeftButton, Qt::NoButton, Qt::NoModifier);
    QGuiApplication::sendEvent(w, &move);
    QGuiApplication::sendEvent(w, &press);
    QGuiApplication::sendEvent(w, &release);
}

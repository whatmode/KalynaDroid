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
#include <SDL.h>

Shell::Shell(QObject *parent) : QObject(parent)
{
    // remember whether the last input came from the touchscreen (shows the on-screen keyboard then)
    qApp->installEventFilter(this);

    // SDL maps the Deck's built-in controller to a stable game-controller layout.
    if (SDL_InitSubSystem(SDL_INIT_GAMECONTROLLER | SDL_INIT_EVENTS) == 0) {
        SDL_GameControllerEventState(SDL_ENABLE);
        m_controllerTimer.setInterval(16);
        connect(&m_controllerTimer, &QTimer::timeout, this, &Shell::pollController);
        m_controllerTimer.start();
        pollController();
    }
}

void Shell::pollController()
{
    SDL_Event event;
    while (SDL_PollEvent(&event)) {
        if (event.type == SDL_CONTROLLERDEVICEADDED && !m_controller
            && SDL_IsGameController(event.cdevice.which)) {
            m_controller = SDL_GameControllerOpen(event.cdevice.which);
            emit controllerChanged();
        } else if (event.type == SDL_CONTROLLERDEVICEREMOVED && m_controller
                   && event.cdevice.which == SDL_JoystickInstanceID(SDL_GameControllerGetJoystick(m_controller))) {
            SDL_GameControllerClose(m_controller);
            m_controller = nullptr;
            m_controllerButtons.fill(false);
            m_axisX = m_axisY = 0;
            emit controllerChanged();
        }
    }

    if (!m_controller) {
        for (int i = 0; i < SDL_NumJoysticks(); ++i) {
            if (SDL_IsGameController(i)) {
                m_controller = SDL_GameControllerOpen(i);
                if (m_controller) emit controllerChanged();
                break;
            }
        }
    }
    if (!m_controller || !SDL_GameControllerGetAttached(m_controller)) return;

    SDL_GameControllerUpdate();
    const SDL_GameControllerButton buttons[] = {
        SDL_CONTROLLER_BUTTON_DPAD_UP, SDL_CONTROLLER_BUTTON_DPAD_DOWN,
        SDL_CONTROLLER_BUTTON_DPAD_LEFT, SDL_CONTROLLER_BUTTON_DPAD_RIGHT,
        SDL_CONTROLLER_BUTTON_A, SDL_CONTROLLER_BUTTON_B,
        SDL_CONTROLLER_BUTTON_Y, SDL_CONTROLLER_BUTTON_START,
        SDL_CONTROLLER_BUTTON_GUIDE
    };
    const char *actions[] = {"up", "down", "left", "right", "a", "b", "y", "start", "guide"};
    for (size_t i = 0; i < sizeof(buttons) / sizeof(buttons[0]); ++i) {
        const bool pressed = SDL_GameControllerGetButton(m_controller, buttons[i]) != 0;
        const int index = static_cast<int>(buttons[i]);
        if (pressed && !m_controllerButtons[index])
            emit controllerAction(QString::fromLatin1(actions[i]));
        m_controllerButtons[index] = pressed;
    }

    const int x = SDL_GameControllerGetAxis(m_controller, SDL_CONTROLLER_AXIS_LEFTX);
    const int y = SDL_GameControllerGetAxis(m_controller, SDL_CONTROLLER_AXIS_LEFTY);
    if (x != m_axisX || y != m_axisY) {
        m_axisX = x;
        m_axisY = y;
        emit controllerChanged();
    }
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
bool Shell::phone() const { return qEnvironmentVariableIntValue("KALYNA_PHONE") == 1; }
qreal Shell::uiScale() const
{
    bool ok = false;
    const qreal s = qEnvironmentVariable("KALYNA_SCALE").toDouble(&ok);
    return ok && s >= 0.5 && s <= 5 ? s : 0;   // 0: size from the screen
}

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

// Kalyna OS native shell (kalyna-shell)
//
// A Wayland compositor written with Qt Quick: it draws the whole screen (lock screen, home, dock,
// quick settings, settings) and shows Linux and Android apps as real windows inside it.
// System work (Wi-Fi, sound, power, apps...) is done by the Python service kalyna-system,
// which this program starts and talks to over a Unix socket.
//
//   kalyna-shell                 run as the session on a Steam Deck / PC (KMS, from a text console)
//   kalyna-shell --nested        run in a window inside another desktop, for development
//   options: --demo (demo system data), --size WxH (nested window size), --rotate none|cw|ccw|180,
//            --screenshot FILE (save the screen after start-up and quit; used by tests)

#include <QCommandLineParser>
#include <QDir>
#include <QFileInfo>
#include <QFontDatabase>
#include <QGuiApplication>
#include <QProcess>
#include <QQmlApplicationEngine>
#include <QQuickWindow>
#include <QStandardPaths>

static QString findAssets(const QString &appDir)
{
    for (const QString &c : {qEnvironmentVariable("KALYNA_ASSETS"), appDir + "/../share/kalyna/assets",
                             appDir + "/../assets", appDir + "/../../assets", QStringLiteral("/usr/share/kalyna/assets")}) {
        if (!c.isEmpty() && QFileInfo::exists(c + "/glyphs"))
            return QDir(c).canonicalPath();
    }
    return QString();
}

static QString findService(const QString &appDir)
{
    for (const QString &c : {qEnvironmentVariable("KALYNA_SYSTEM"), appDir + "/kalyna-system",
                             appDir + "/../lib/kalyna/kalyna-system.py", appDir + "/../system/kalyna-system.py",
                             appDir + "/../../system/kalyna-system.py", QStringLiteral("/usr/lib/kalyna/kalyna-system.py")}) {
        if (!c.isEmpty() && QFileInfo::exists(c))
            return QFileInfo(c).canonicalFilePath();
    }
    return QString();
}

int main(int argc, char *argv[])
{
    // decide the platform before Qt starts: KMS on the real device, a window when nested
    bool nested = false, demo = false;
    QString size = "1280x800", rotate, shot;
    for (int i = 1; i < argc; ++i) {
        const QByteArray a = argv[i];
        if (a == "--nested") nested = true;
        else if (a == "--demo") demo = true;
        else if (a == "--size" && i + 1 < argc) size = argv[++i];
        else if (a == "--rotate" && i + 1 < argc) rotate = argv[++i];
        else if (a == "--screenshot" && i + 1 < argc) shot = argv[++i];
    }
    if (nested) qputenv("KALYNA_NESTED", "1");
    if (!rotate.isEmpty()) qputenv("KALYNA_ROTATE", rotate.toUtf8());
    if (!shot.isEmpty()) qputenv("KALYNA_SCREENSHOT", shot.toUtf8());
    qputenv("KALYNA_SIZE", size.toUtf8());
    if (!nested && qEnvironmentVariableIsEmpty("QT_QPA_PLATFORM")) {
        qputenv("QT_QPA_PLATFORM", "eglfs");
        qputenv("QT_QPA_EGLFS_INTEGRATION", "eglfs_kms");
        qputenv("QT_QPA_EGLFS_ALWAYSSET", "1");
        qputenv("QT_QPA_EGLFS_HIDECURSOR", "0");
    }
    // the on-screen keyboard (Qt Virtual Keyboard) also types into apps through the Wayland text-input protocol
    if (qEnvironmentVariableIsEmpty("QT_IM_MODULE"))
        qputenv("QT_IM_MODULE", "qtvirtualkeyboard");
    // apps started from Kalyna must not try to open their own windows on the outer desktop
    qputenv("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1");

    QGuiApplication app(argc, argv);
    app.setApplicationName("Kalyna");
    app.setOrganizationName("Kalyna");
    app.setApplicationVersion(KALYNA_VERSION);

    const QString appDir = QCoreApplication::applicationDirPath();
    const QString assets = findAssets(appDir);
    if (assets.isEmpty())
        qWarning("kalyna-shell: assets not found (set KALYNA_ASSETS)");
    qputenv("KALYNA_ASSETS", assets.toUtf8());

    for (const QString &f : QDir(assets + "/fonts").entryList({"*.otf", "*.ttf"}))
        QFontDatabase::addApplicationFont(assets + "/fonts/" + f);
    QFont font("Kalyna Text");
    font.setPixelSize(15);
    QGuiApplication::setFont(font);

    // the Wayland socket our apps connect to; the service starts apps with it
    const QString socket = qEnvironmentVariable("KALYNA_WAYLAND_SOCKET", nested ? "wayland-kalyna-test" : "wayland-kalyna");
    qputenv("KALYNA_WAYLAND_SOCKET", socket.toUtf8());

    QString runtime = qEnvironmentVariable("XDG_RUNTIME_DIR");
    if (runtime.isEmpty()) {
        runtime = QDir::tempPath() + "/kalyna-runtime";
        QDir().mkpath(runtime);
        qputenv("XDG_RUNTIME_DIR", runtime.toUtf8());
    }
    const QString sock = runtime + "/kalyna-system.sock";
    qputenv("KALYNA_SYSTEM_SOCK", sock.toUtf8());

    // start the system service with the environment our apps need
    QProcess service;
    const QString servicePath = findService(appDir);
    if (!servicePath.isEmpty() && qEnvironmentVariableIntValue("KALYNA_NO_SERVICE") != 1) {
        QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
        env.insert("WAYLAND_DISPLAY", socket);
        env.insert("KALYNA_ASSETS", assets);
        env.remove("QT_QPA_PLATFORM");
        env.remove("QT_IM_MODULE");
        env.remove("DISPLAY");
        if (demo) env.insert("KALYNA_DEMO", "1");
        service.setProcessEnvironment(env);
        service.setProcessChannelMode(QProcess::ForwardedChannels);
        if (servicePath.endsWith(".py"))
            service.start("python3", {servicePath, sock});
        else
            service.start(servicePath, {sock});
    } else if (servicePath.isEmpty()) {
        qWarning("kalyna-shell: kalyna-system not found, running without system services");
    }

    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app,
                     [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    engine.loadFromModule("Kalyna", "Main");

    const int rc = app.exec();
    if (service.state() != QProcess::NotRunning) {
        service.terminate();
        if (!service.waitForFinished(1500))
            service.kill();
    }
    return rc;
}

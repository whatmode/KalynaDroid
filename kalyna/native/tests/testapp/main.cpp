// A tiny Wayland app used to test the Kalyna compositor: a window with a text field.
#include <QGuiApplication>
#include <QQmlApplicationEngine>
int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    app.setDesktopFileName("kalyna-testapp");
    QQmlApplicationEngine e;
    e.loadFromModule("TestApp", "Main");
    return app.exec();
}

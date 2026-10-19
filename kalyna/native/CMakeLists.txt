cmake_minimum_required(VERSION 3.21)
file(READ "${CMAKE_CURRENT_SOURCE_DIR}/VERSION" KALYNA_VERSION)
string(STRIP "${KALYNA_VERSION}" KALYNA_VERSION)
project(kalyna-shell VERSION ${KALYNA_VERSION} LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Network Qml Quick WaylandCompositor ShaderTools)
qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(kalyna-shell
    src/main.cpp
    src/shell.cpp src/shell.h
    src/systemclient.cpp src/systemclient.h
)
target_compile_definitions(kalyna-shell PRIVATE KALYNA_VERSION="${KALYNA_VERSION}")
target_include_directories(kalyna-shell PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)

set_source_files_properties(qml/Theme.qml qml/Prefs.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
qt_add_qml_module(kalyna-shell
    URI Kalyna
    VERSION 1.0
    QML_FILES
        qml/Main.qml qml/ShellUI.qml qml/Theme.qml qml/Prefs.qml
        qml/Glyph.qml qml/AppIcon.qml qml/AppTile.qml qml/Glass.qml qml/Wallpaper.qml
        qml/HomeScreen.qml qml/HomeOverlay.qml qml/StatusBar.qml qml/BatteryIcon.qml qml/GestureBar.qml
        qml/QuickSettings.qml qml/QsTile.qml qml/KSlider.qml qml/KSwitch.qml qml/KButton.qml
        qml/WifiList.qml qml/Recents.qml qml/LockScreen.qml qml/Toast.qml qml/SettingsApp.qml
)

qt_add_shaders(kalyna-shell "kalyna_shaders"
    PREFIX "/qt/qml/Kalyna"
    FILES shaders/glass.frag
)

target_link_libraries(kalyna-shell PRIVATE
    Qt6::Core Qt6::Gui Qt6::Network Qt6::Qml Qt6::Quick Qt6::WaylandCompositor)

include(GNUInstallDirs)
install(TARGETS kalyna-shell RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(DIRECTORY assets/ DESTINATION ${CMAKE_INSTALL_DATADIR}/kalyna/assets)
install(PROGRAMS system/kalyna-system.py DESTINATION lib/kalyna)

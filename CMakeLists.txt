cmake_minimum_required(VERSION 3.21)

project(LibraryManagementSystem VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
include(GNUInstallDirs)

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE Debug CACHE STRING "Build type" FORCE)
endif()

# 可执行文件输出到 <build>/bin，FluentUI 的 QML 插件输出到 <build>/qml/FluentUI。
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")
set(FLUENTUI_QML_PLUGIN_DIRECTORY "${CMAKE_BINARY_DIR}/qml/FluentUI" CACHE PATH
    "Directory where the FluentUI QML plugin is generated" FORCE)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Quick Qml Widgets PrintSupport Sql)
qt_standard_project_setup()

if(WIN32)
    enable_language(RC)
endif()

add_subdirectory(FluentUI)
add_subdirectory(src)

install(TARGETS LibraryManagementSystem
    BUNDLE DESTINATION .
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
install(DIRECTORY "${FLUENTUI_QML_PLUGIN_DIRECTORY}/"
    DESTINATION "qml/FluentUI"
    OPTIONAL
)
if(UNIX AND NOT APPLE)
    install(FILES
        "${CMAKE_SOURCE_DIR}/packaging/linux/com.bubaimengj4.LibraryManagementSystem.desktop"
        DESTINATION "${CMAKE_INSTALL_DATADIR}/applications")
    install(FILES
        "${CMAKE_SOURCE_DIR}/packaging/linux/com.bubaimengj4.LibraryManagementSystem.metainfo.xml"
        DESTINATION "${CMAKE_INSTALL_DATADIR}/metainfo")
    install(FILES
        "${CMAKE_SOURCE_DIR}/packaging/linux/library.png"
        DESTINATION "${CMAKE_INSTALL_DATADIR}/icons/hicolor/256x256/apps"
        RENAME "com.bubaimengj4.LibraryManagementSystem.png")
endif()

set(CPACK_PACKAGE_NAME "LibraryManagementSystem")
set(CPACK_PACKAGE_VENDOR "BuBaiMengJ4")
set(CPACK_PACKAGE_VERSION "${PROJECT_VERSION}")
set(CPACK_PACKAGE_CONTACT "github.com/BuBaiMengJ4/Library-management-system")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "FluentUI Qt library management system")
set(CPACK_DEBIAN_PACKAGE_MAINTAINER "BuBaiMengJ4")
set(CPACK_RPM_PACKAGE_LICENSE "MIT")
set(CPACK_GENERATOR "DEB;RPM")
set(CPACK_DEBIAN_PACKAGE_DEPENDS "libqt6core6, libqt6gui6, libqt6quick6, libqt6sql6-sqlite, libssl3")
set(CPACK_RPM_PACKAGE_REQUIRES "qt6-qtbase, qt6-qtdeclarative, qt6-qtbase-sqlite, openssl-libs")
include(CPack)

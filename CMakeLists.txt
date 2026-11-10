cmake_minimum_required(VERSION 3.21)

project(LibraryManagementSystem VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE Debug CACHE STRING "Build type" FORCE)
endif()

# 可执行文件输出到 <build>/bin，FluentUI 的 QML 插件输出到 <build>/qml/FluentUI。
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")
set(FLUENTUI_QML_PLUGIN_DIRECTORY "${CMAKE_BINARY_DIR}/qml/FluentUI" CACHE PATH
    "Directory where the FluentUI QML plugin is generated" FORCE)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Quick Qml Widgets PrintSupport Sql)
qt_standard_project_setup()

if(NOT WIN32)
    message(FATAL_ERROR "加密存储当前使用 Windows DPAPI + BCrypt，仅支持 Windows 构建。")
endif()
if(WIN32)
    enable_language(RC)
endif()

add_subdirectory(FluentUI)
add_subdirectory(src)

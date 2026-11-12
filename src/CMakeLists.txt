set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

set(APP_ICON_PATH "${CMAKE_SOURCE_DIR}/library.ico")
configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/resources/app.rc.in"
    "${CMAKE_CURRENT_BINARY_DIR}/app.rc"
    @ONLY
)

set(PROJECT_SOURCES
    main.cpp
    backend/Encryption.h
    backend/Encryption.cpp
    backend/LibraryImageProvider.h
    backend/LibraryImageProvider.cpp
    backend/LibraryService.h
    backend/LibraryService.cpp
    qml.qrc
)

if(WIN32)
    list(APPEND PROJECT_SOURCES "${CMAKE_CURRENT_BINARY_DIR}/app.rc")
endif()

qt_add_executable(LibraryManagementSystem
    ${PROJECT_SOURCES}
)

target_include_directories(LibraryManagementSystem PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}"
)

target_link_libraries(LibraryManagementSystem PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Quick
    Qt6::Qml
    Qt6::Sql
    fluentuiplugin
)

if(WIN32)
    target_link_libraries(LibraryManagementSystem PRIVATE bcrypt crypt32)
else()
    find_package(OpenSSL REQUIRED)
    target_link_libraries(LibraryManagementSystem PRIVATE OpenSSL::Crypto)
endif()

if(MSVC)
    target_compile_options(LibraryManagementSystem PRIVATE /utf-8)
endif()

if(WIN32)
    set_target_properties(LibraryManagementSystem PROPERTIES
        WIN32_EXECUTABLE TRUE
        OUTPUT_NAME "LibraryManagementSystem"
    )
elseif(APPLE)
    set_target_properties(LibraryManagementSystem PROPERTIES
        MACOSX_BUNDLE TRUE
        MACOSX_BUNDLE_BUNDLE_NAME "LibraryManagementSystem"
        MACOSX_BUNDLE_GUI_IDENTIFIER "com.bubaimengj4.library"
        MACOSX_BUNDLE_BUNDLE_VERSION "${PROJECT_VERSION}"
        MACOSX_BUNDLE_SHORT_VERSION_STRING "${PROJECT_VERSION}"
    )
else()
    set_target_properties(LibraryManagementSystem PROPERTIES
        OUTPUT_NAME "LibraryManagementSystem"
    )
endif()

if(WIN32)
    # 让 Windows 资源管理器、任务栏和窗口标题使用与旧版相同的图标。
    set_target_properties(LibraryManagementSystem PROPERTIES
        OUTPUT_NAME "LibraryManagementSystem"
    )

    # 一键生成可分发目录：cmake --build <build> --target deploy
    if(TARGET Qt6::qmake)
        get_target_property(_qt_qmake Qt6::qmake IMPORTED_LOCATION)
        if(_qt_qmake)
            get_filename_component(_qt_bin_dir "${_qt_qmake}" DIRECTORY)
            find_program(WINDEPLOYQT_EXECUTABLE windeployqt HINTS "${_qt_bin_dir}")
            if(WINDEPLOYQT_EXECUTABLE)
                add_custom_target(deploy
                    COMMAND ${CMAKE_COMMAND} -E remove_directory "${CMAKE_BINARY_DIR}/dist"
                    COMMAND ${CMAKE_COMMAND} -E make_directory "${CMAKE_BINARY_DIR}/dist"
                    COMMAND ${CMAKE_COMMAND} -E copy
                            "$<TARGET_FILE:LibraryManagementSystem>"
                            "${CMAKE_BINARY_DIR}/dist/"
                    COMMAND "${WINDEPLOYQT_EXECUTABLE}"
                            --qmldir "${CMAKE_SOURCE_DIR}/src/qml"
                            --no-translations
                            "${CMAKE_BINARY_DIR}/dist/LibraryManagementSystem.exe"
                    COMMAND ${CMAKE_COMMAND} -E copy_directory
                            "${FLUENTUI_QML_PLUGIN_DIRECTORY}"
                            "${CMAKE_BINARY_DIR}/dist/qml/FluentUI"
                    DEPENDS LibraryManagementSystem
                    COMMENT "Deploying Qt runtime, SQLite driver and FluentUI plugin..."
                )
            endif()
        endif()
    endif()
endif()

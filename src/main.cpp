#ifdef Q_OS_ANDROID
    #include <QGuiApplication>
    #include <QtAndroid>
#else
    #include <QApplication>
#endif

#include <QQmlApplicationEngine>
#include <QtQml>
#include <QDebug>

#include "ZXingQtReader.h"
#include "ContentDatabase.h"
#include "History.h"
#include "LocaleChanger.h"

// Export main() as part of a library interface. Needed on Android.
//   Q_DECL_EXPORT is a Qt MOC macro that exposes main() as part of the interface of a
//   library; see https://stackoverflow.com/q/13911387. Building and executing works
//   without this for desktop software. But on Android, a native application is loaded
//   as a library from some Java bootstrap code, so it's needed there. Otherwise, the
//   build process fails with "Could not find a main() symbol". See
//   https://phabricator.kde.org/D12120
Q_DECL_EXPORT
int main(int argc, char *argv[]) {
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
    QCoreApplication::setAttribute(Qt::AA_UseHighDpiPixmaps);

    // Create the application object.
    //   It gets provided with all command line arguments so it can evaluate the Qt default ones,
    //   see https://doc.qt.io/qt-5/qapplication.html#QApplication for the list.
    #ifdef Q_OS_ANDROID
        QGuiApplication app(argc, argv);
    #else
        // Our QuickControls2 style for desktops requires a QApplication.
        QApplication app(argc, argv);
    #endif

	ZXingQt::registerQmlAndMetaTypes();

    // Create and initialize the Food Rescue SQLite3 database connection.
    ContentDatabase db;
    db.connect();

    // Make the Food Rescue database available for use in QML.
    // TODO: Better than registering the type to be instantiated as a singleton object in QML, provide
    //   the above "db" object as a context property that is accessible in QML. For that, use
    //   engine.rootContext()->setContextProperty
    qmlRegisterType<ContentDatabase>("local", 1, 0, "ContentDatabase");

    QQmlApplicationEngine engine;

    // Set up the language switcher and make it available to QML.
    LocaleChanger localeChanger(&engine, QString("/i18n"), QString("foodrescue_"));
    engine.rootContext()->setContextProperty("localeChanger", &localeChanger);

    // Set up the global history object and make it available to QML.
    //   TODO: Insteaf of "", use a different homepage identifier, so that navigating back there
    //   will indeed bring one back to the start screen. For that, a search term of "home:" could
    //   be used, similar to the "config:" special URL in Firefox.
    History browserHistory("");
    engine.rootContext()->setContextProperty("browserHistory", &browserHistory);

    // Use different main files on desktop vs. mobile platform.
    // TODO: Switch to the "qrc:/something" URLs if possible. So far not working.
    const QUrl desktopQML(QStringLiteral("qrc:///qml/App.qml"));
    const QUrl mobileQML(QStringLiteral("qrc:///qml/AppOnMobile.qml"));
    const bool QQC_MOBILE_SET(qEnvironmentVariableIsSet("QT_QUICK_CONTROLS_MOBILE"));
    const QString QQC_MOBILE(QString::fromLatin1(qgetenv("QT_QUICK_CONTROLS_MOBILE")));
    if (QQC_MOBILE_SET && (QQC_MOBILE == QStringLiteral("1") || QQC_MOBILE == QStringLiteral("true"))) {
        engine.load(mobileQML);
    }
    else {
        engine.load(desktopQML);
    }

    if (engine.rootObjects().isEmpty()) {
        QCoreApplication::exit(-1);
    }

    // i18n management

    // Determine the target language to switch to.
    //   Using .left(2) fetches the language portion from a full locale code, which can be something
    //   like de_DE. Note that Qt does never include the encoding into the locale, unlike Linux.
    //   So starting the application with "env LANGUAGE= LC_ALL=de_AT.utf8 ./foodrescue" will still
    //   result in QLocale().name() == "de_AT".
    //
    //   TODO: Once providing translation files with regional variation (such as de_DE and de_AT),
    //   extend the selection mechanism accordingly to QLocale::system().name().left(5).
    qDebug() << "Detected application locale: " + QLocale().name();
    QString targetLanguage(QLocale().name().left(2));

    // Switch the user interface to use the right language.
    //   Qt determines the locale the application was started with and makes it available in
    //   QLocale::system(). However, it does not automatically create and apply
    //   UI translator in the system locale language. With QQMLApplicationEngine as used above, that
    //   should happen as per https://doc.qt.io/qt-5/qqmlapplicationengine.html#details but it
    //   does not happen, at least not under Linux. This seems to be a bug. Especially because it
    //   does not even work in the official qml-i18n example from
    //   https://doc.qt.io/qt-5/qtqml-qml-i18n-example.html when starting the executable with
    //   "env LANGUAGE= LANG=fr_FR ./qml-i18n". So we'll apply translation files ourselves, and
    //   also integrate that with a feature that lets the user switch the language at runtime. We
    //   do not want translations to be loaded automatically anyway as that would force us to put
    //   them into src/qml/i18n/qml_{lang}.ts
    //
    //   TODO: Reference the bug report above once it's reported.
    localeChanger.changeLocale(targetLanguage);

    return app.exec();
}

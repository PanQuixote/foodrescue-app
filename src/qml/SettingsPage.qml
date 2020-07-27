import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.2
import org.kde.kirigami 2.10 as Kirigami

import QtQuick.Templates 2.4 as T

// Page for "☰ → Settings".
Kirigami.ScrollablePage {
    id: page
    title: qsTr("Settings")
    Layout.fillWidth: true

    // A two-column layout with form elements and their labels.
    //   See file FormLayoutGallery.qml in application Kirigami Gallery for a usage example.
    Kirigami.FormLayout {

        ComboBox {
            id: languageChanger
            Kirigami.FormData.label: qsTr("User interface language:")
            textRole: "label" // Role of the model to show as the combobox list items.

            // Initialize the combobox with "no entry selected".
            //   This will be adapted in Component.onCompleted {} to select the current language.
            //   But choosing "-1" first is necessary, for whatever reason, to avoid a weird
            //   error in the Kirigami GlobalDrawer menu item to open this page: "GlobalDrawerActionItem.qml:132:
            //   TypeError: Cannot call method 'hasOwnProperty' of undefined"
            //
            //   TODO: Figure out the above error and report it as a bug to Kirigami.
            currentIndex: -1

            // Workaround for the Kirgami bug that the currentIndex element is shown white on white
            // in the ComboBox popup. Uses Kirigami's default colors for the same roles in a ListView.
            // About customizing a QQC2 ComboBox, see:
            //   https://doc.qt.io/qt-5/qtquickcontrols2-customize.html#customizing-combobox
            //   https://doc.qt.io/qt-5/qml-palette.html#qtquickcontrols2-palette
            // TODO: Report this bug, get it fixed, and remove this workaround.
            popup.palette.light:    "#7ba9c6" // Background of the popup's current item.
            popup.palette.midlight: "#308cc6" // Background of the popup's item while clicking.

            model: ListModel {
                id: languageModel
                // TODO: Maybe automatically initialize this based on the available .qm translation files.
                ListElement { label: qsTr("English"); language: "en" }
                ListElement { label: qsTr("German");  language: "de" }
            }

            Component.onCompleted: {
                console.log("SettingsPage.qml: Detected current locale: " + Qt.locale().name)
                var currentLanguage = Qt.locale().name.substring(0,2)
                console.log("SettingsPage.qml: Detected current language: " + currentLanguage)

                // Initialize the current item coresponding to the current language.
                //   TODO: When moving to Qt 5.14, replace this with indexOfValue(). See:
                //   https://doc.qt.io/qt-5/qml-qtquick-controls2-combobox.html#indexOfValue-method
                //   That also requires setting valueRole, see:
                //   https://doc.qt.io/qt-5/qml-qtquick-controls2-combobox.html#valueRole-prop
                for (var i = 0; i < languageModel.count; i++) {
                    if (languageModel.get(i).language === currentLanguage) {
                        currentIndex = i
                        break
                    }
                }
            }

            onCurrentIndexChanged: {
                // Change the locale according to the new current entry.
                //   But don't change the locale if it's the same as the current locale. That case
                //   happens when the component is initialized and sets the current index according
                //   to the current locale. Changing the locale *then* would mean changing it while
                //   the KDE Kirigami GlobalDrawer menu where the user clicked "Settings" is still open.
                //   And that leads to a weird error "GlobalDrawerActionItem.qml:132: ReferenceError:
                //   modelData is not defined", with the drawer staying open as a result. So as a rule,
                //   don't change the locale while certain components are doing their stuff.
                var currentLanguage = Qt.locale().name.substring(0,2)
                var nextLanguage = languageModel.get(currentIndex).language
                if (currentLanguage !== nextLanguage) {
                    // localeChanger is a custom context object provided in main.cpp.
                    localeChanger.changeLocale(nextLanguage)

                    // TODO: Also exchange the frontpage logo graphic with the proper i18n'ed version.
                    // That's a bit complicated though as we'd have to send a signal between two
                    // dynamically created QML objects. Better to make the logo graphic adapt itself
                    // according to locale changes, as indicated there as a TODO already.
                }
            }
        }
    }
}

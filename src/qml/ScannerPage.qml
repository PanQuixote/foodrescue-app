/**
 * Barcode scanner component, originally from QZXingNu (https://github.com/swex/QZXingNu)
 *
 * Authors and copyright:
 *   © 2018-2020  Alexey Mednyy      (https://github.com/swex)
 *   © 2020       Matthias Ansorg    (https://github.com/tanius)
 *   © 2020       Axel Waggershauser (https://github.com/axxel)
 *
 * The authors license this file to you under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License. You may obtain a copy of the
 * License at: http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software distributed under the
 * License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
 * express or implied.  See the License for the specific language governing permissions and
 * limitations under the License.
 */

import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.2
import QtMultimedia 5.12
import org.kde.kirigami 2.10 as Kirigami
import ZXing 1.0 as ZXing
import local 1.0 as Local // Our custom QML components, exported in main.cpp.

Kirigami.ScrollablePage {
    id: scannerPage
    title: qsTr("Scan a Barcode")

    property int tagsFound: 0
    property string lastTag: ""
    signal barcodeFound(string code)

    // Activate the camera only while visible.
    //   Else it would consume energy and have its LED on permanently. This page is dynamically
    //   created, so it is not visible before "onCompleted".
    Component.onCompleted: {
        tagsFound = 0
        lastTag = ""
        camera.start()
    }

    // Barcode search algorithm, provided by ZXing-C++. Invisible.
    ZXing.VideoFilter {
        id: zxingFilter

        formats: ZXing.EAN13 | ZXing.EAN8
        tryRotate: true // Also search for barcodes with horizontal bars, in addition to vertical.
        tryHarder: true // Spend more effort on barcode recognition. Not really needed, as this is the default now.

        // onNewResult: console.log(result) // Good for debugging, also showing no-recognition results.

        onFoundBarcode: {
            tagsFound++
            // Stop the camera manually to prevent finding more barcodes.
            //   The camera would also be stopped automatically when the page is destroyed with
            //   pageStack.layers.pop() below. However, it would recognize 1-2 more barcodes during that.
            camera.stop()

            // TODO: Better reference the page instead of just removing the top layer.
            //   So far, we could not find a way to do so. pageStack.layers.pop(scannerPage) does
            //   nothing and pageStack.layers.removePage(scannerPage) results in "TypeError: Property
            //   'removePage' of object QQuickStackView_QML_9(…) is not a function". The documentation
            //   is not clear how to reference a page here, see:
            //   https://api.kde.org/frameworks/kirigami/html/classorg_1_1kde_1_1kirigami_1_1PageRow.html
            //   But the reason is that pageStack.layers is a QtQuick.Controls.StackView, which has
            //   different methods than org.kde.kirigami.PageRow. See the source code referenced from:
            //   https://api.kde.org/frameworks/kirigami/html/classorg_1_1kde_1_1kirigami_1_1PageRow.html#ab0a1367b4574053f31e376ed81e7e9c3
            pageStack.layers.pop()
            lastTag = result.text
            scannerPage.barcodeFound(lastTag)

            console.log(result)
        }
    }

    // Configuration of device camera access. Invisible.
    Camera {
        id: camera

        // Prevent camera (as indicated by its LED) from switching on at application start.
        //   Because OverlaySheet is instantiated when its parent object is instantiated,
        //   and the default state is Camera.ActiveState. Using Camera.UnloadedState here
        //   would be even slightly better in terms of energy consumption, but would not allow
        //   setting imageCapture.resolution below.
        cameraState: Camera.LoadedState

        captureMode: Camera.CaptureViewfinder

        focus {
            // TODO: Only change focusMode if supported, to avoid messages like
            // "Focus mode selection is not supported".
            focusMode: CameraFocus.FocusContinuous
            focusPointMode: CameraFocus.FocusPointAuto
        }

        deviceId: {
            QtMultimedia.availableCameras[camerasComboBox.currentIndex] ?
                QtMultimedia.availableCameras[camerasComboBox.currentIndex].deviceId : ""
        }

        // Workaround for a viewfinder image distortion bug on Asus Nexus 7 and other models.
        //   Basically, still image resolution has to match the preview size resolution.
        //   Background and solution details: https://stackoverflow.com/a/62541306
        //
        //   Setting imageCapture.resolution is a good workaround as it does not break any
        //   code for desktop systems, does not fail even when that resolution is not supported,
        //   and does not require any special-casing for devices or operating systems.
        //
        //   TODO: The current setting matches the default preview size of 1920x1020 on the
        //   Nexus 7. Make this solution generic for all devices with similar issues, according
        //   to the instructions on https://stackoverflow.com/a/62541306 .
        imageCapture {
            resolution: "1920x1080"
        }

        /** Debug helper function that prints resolutions supported by the camera viewfinder.
          *
          * Must be called while the camera is in Camera.LoadedState. Otherwise, the list is empty.
          */
        function printViewfinderResolutions() {
            var resolutions = camera.supportedViewfinderResolutions();

            console.debug("Number of supported viewfinder resolutions: " + resolutions.length)

            for(var i=0; i<resolutions.length; i++) {
                console.debug("resolution #" + i + ":" +
                    resolutions[i].width + "×" + resolutions[i].height
                )
            }

            console.debug("Current resolution: " +
                camera.viewfinder.resolution.width + "×" + camera.viewfinder.resolution.height
            )
        }

        onCameraStateChanged: {
            // TODO: An event parameter "state" should be available but is empty. Maybe a bug?
            // TODO: Encapsulate this into a function, so there's just one line of code here.

            switch (cameraState) {
            case Camera.UnloadedState:
                console.debug("New camera state: Camera.UnloadedState");
                break;
            case Camera.LoadedState:
                console.debug("New camera state: Camera.LoadedState");
                printViewfinderResolutions()
                break;
            case Camera.ActiveState:
                console.debug("New camera state: Camera.ActiveState");
                printViewfinderResolutions()
                break;
            }
        }

        onDeviceIdChanged: {
            focus.focusMode = CameraFocus.FocusContinuous
            focus.focusPointMode = CameraFocus.FocusPointAuto
        }

        onLockStatusChanged: {
            if (tagDiscoveredInSession)
                return
            if (lockStatus === Camera.Locked)
                camera.unlock()
        }

        onError: console.log("camera error:" + errorString)
    }

    ColumnLayout {
        // Limit layout height to enable "Layout.fillHeight: true" for child VideoOutput.
        //   77% window height is the maximum possible for an overlay sheet without content
        //   scrolling in, and with a bottom margin the same size as the side margins.
        //
        //   TODO: Layout.maximumHeight does not work here. Why?
        //   TODO: Improve the calculation. There must be a better way than guessing the height of
        //   the window's header bar.
        height: applicationWindow().height - 80

        // Spacings between video, camera list, status bar.
        spacing: Kirigami.Units.largeSpacing * 5

        VideoOutput {
            id: viewFinder

            source: camera
            filters: [zxingFilter]

            Layout.fillWidth: true  // Takes the width not taken by siblings.
            Layout.fillHeight: true // Takes the height not taken by siblings.
            fillMode: VideoOutput.PreserveAspectFit

            // TODO: Find out if excluding iOS here is still necessary.
            autoOrientation: Qt.platform.os == 'ios' ? false : true
            focus: visible // Captures key events only while visible.
        }

        // Camera chooser widget. Shown only when multiple cameras exist.
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false
            visible: QtMultimedia.availableCameras.length > 1
            Label {
                text: qsTr("Camera: ")
                Layout.fillWidth: false
            }
            ComboBox {
                id: camerasComboBox
                Layout.fillWidth: true
                model: QtMultimedia.availableCameras
                textRole: "displayName"
                currentIndex: 0
            }
        }

        // Status bar.
        //   Useful for debugging, but hidden otherwise to save space.
        Label {
            id: resultOutput

            // TODO: Enable when in debugging mode.
            visible: false
            text: qsTr("Barcodes found:)") + " " + tagsFound + " " +
                (lastTag ? qsTr("Last barcode:") + " " + lastTag : "")
        }
    }
}

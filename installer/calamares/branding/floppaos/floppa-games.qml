/* FloppaOS installer page "Floppa games" (Calamares notesqml module, instance floppagames).
 *
 * Tick boxes for what Floppa Setup does at the first login of the new user: install the Floppa Launcher,
 * pin it to the taskbar, install Wine. Nothing is downloaded during the installation; Floppa Setup does it
 * after the first start, when the PC is online.
 *
 * The choices go into Calamares' GlobalStorage as "floppaos_setup" (a map of three true/false values).
 * The floppasetup step (installer/calamares-modules/floppasetup) writes them into the new system as
 * /etc/floppaos/setup-choices.conf, which setup/floppa-setup.py reads. See installer/README.md.
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import io.calamares.core 1.0

Pane {
    id: page

    function save() {
        Global.insert("floppaos_setup", {
            "launcher": launcher.checked,
            "pin": launcher.checked && pin.checked,
            "wine": wine.checked
        })
    }
    // The page is loaded when the installer starts, so the defaults are stored even before it is shown.
    Component.onCompleted: save()

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        Label {
            Layout.fillWidth: true
            Layout.bottomMargin: 10
            wrapMode: Text.WordWrap
            text: "FloppaOS can set up the Floppa games for you. Floppa Setup does it when you log in for "
                + "the first time, so the PC needs internet then. Nothing is downloaded during the installation."
        }

        CheckBox {
            id: launcher
            checked: true
            text: "Install the Floppa Launcher"
            onToggled: page.save()
        }
        Label {
            Layout.fillWidth: true
            Layout.leftMargin: launcher.indicator.width + launcher.spacing + launcher.leftPadding
            Layout.bottomMargin: 8
            wrapMode: Text.WordWrap
            opacity: 0.75
            text: "It installs, updates and starts the Floppa games. FloppaNet, the overlay that opens "
                + "with F2 in a game, comes with every game."
        }

        CheckBox {
            id: pin
            checked: true
            enabled: launcher.checked
            text: "Pin the Floppa Launcher to the taskbar"
            onToggled: page.save()
        }
        Item { Layout.preferredHeight: 8 }

        CheckBox {
            id: wine
            checked: false
            text: "Install Wine"
            onToggled: page.save()
        }
        Label {
            Layout.fillWidth: true
            Layout.leftMargin: wine.indicator.width + wine.spacing + wine.leftPadding
            wrapMode: Text.WordWrap
            opacity: 0.75
            text: "Runs Windows programs and games. About 1 GB to download; Floppa Setup asks for your "
                + "password when it installs it."
        }

        Item { Layout.fillHeight: true }

        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            opacity: 0.75
            text: "You can change this later: open Floppa Setup from the start menu."
        }
    }
}

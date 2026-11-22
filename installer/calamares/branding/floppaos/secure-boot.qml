/* FloppaOS installer page "Secure Boot" (Calamares notesqml module, instance secureboot).
 *
 * One tick box: start FloppaOS with Secure Boot on (decision 27). Some Windows games with anti-cheat need
 * Secure Boot on in the PC's settings; with this, FloppaOS starts with it on too, so it never has to be
 * switched off and on again. The page makes a one-time code of 8 digits (digits only, because the blue
 * key-confirmation screen uses the firmware's US keyboard) and says what to do at the next start.
 *
 * The choice goes into Calamares' GlobalStorage as "floppaos_secureboot" = {"enabled": bool, "code": "12345678"}.
 * The floppasecureboot step (installer/calamares-modules/floppasecureboot) runs `floppaos-secureboot setup`
 * in the new system with that code. See installer/README.md and secureboot/README.md.
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import io.calamares.core 1.0

Pane {
    id: page

    // 8 random digits, the first one not 0 so the code always looks like 8 digits.
    readonly property string code: {
        var c = String(1 + Math.floor(Math.random() * 9))
        for (var i = 0; i < 7; i++)
            c += String(Math.floor(Math.random() * 10))
        return c
    }

    function save() {
        Global.insert("floppaos_secureboot", { "enabled": secureBoot.checked, "code": page.code })
    }
    // The page is loaded when the installer starts, so the default (off) is stored even before it is shown.
    Component.onCompleted: save()

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        Label {
            Layout.fillWidth: true
            Layout.bottomMargin: 10
            wrapMode: Text.WordWrap
            text: "Some Windows games with anti-cheat need Secure Boot turned on in the PC's settings. "
                + "With this, FloppaOS starts with Secure Boot on too, so you never have to switch it off "
                + "and on again. Windows keeps working as before."
        }

        CheckBox {
            id: secureBoot
            checked: false
            text: "Start FloppaOS with Secure Boot on"
            onToggled: page.save()
        }
        Label {
            Layout.fillWidth: true
            Layout.leftMargin: secureBoot.indicator.width + secureBoot.spacing + secureBoot.leftPadding
            Layout.bottomMargin: 8
            wrapMode: Text.WordWrap
            opacity: 0.75
            text: "Not needed if you don't use Secure Boot. You can also set it up later in Konsole: "
                + "sudo floppaos-secureboot setup"
        }

        ColumnLayout {
            visible: secureBoot.checked
            Layout.fillWidth: true
            Layout.leftMargin: secureBoot.indicator.width + secureBoot.spacing + secureBoot.leftPadding
            spacing: 6

            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: "One step is left after the installation. Write this code down or take a photo:"
            }
            Label {
                text: page.code.substring(0, 4) + " " + page.code.substring(4)
                font.pointSize: 24
                font.bold: true
                font.letterSpacing: 2
            }
            Label {
                Layout.fillWidth: true
                Layout.topMargin: 4
                wrapMode: Text.WordWrap
                textFormat: Text.StyledText
                text: "At the first start of FloppaOS a blue screen appears (\"Perform MOK management\"):<br>"
                    + "1. Press any key within 10 seconds.<br>"
                    + "2. Choose <b>Enroll MOK</b>, then <b>Continue</b>, then <b>Yes</b>.<br>"
                    + "3. At \"Password:\" type the code (only the 8 digits) and press Enter.<br>"
                    + "4. Choose <b>Reboot</b>.<br>"
                    + "Then turn Secure Boot back on in the PC's settings (UEFI). FloppaOS also shows the code "
                    + "again after you log in, until this is done."
            }
        }

        Item { Layout.fillHeight: true }
    }
}

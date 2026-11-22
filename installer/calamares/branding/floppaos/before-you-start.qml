/* FloppaOS installer page "Before you start" (Calamares notesqml module, instance beforeyoustart).
 *
 * Shown right after the welcome page, before anything is chosen or changed: FloppaOS is a hobby project by one
 * person without warranty, so back up your files first. Text only; nothing is stored. Same wording as the
 * website and the README.
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Pane {
    id: page

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pointSize: 14
            font.bold: true
            text: "Back up your files first"
        }
        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: "FloppaOS is a free hobby project made by one person. It comes with no warranty: "
                + "installing it is at your own risk."
        }
        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: "The installer changes your disk, and one wrong choice can delete files. Copy everything you "
                + "want to keep to a USB drive or the cloud before you go on, especially if you install "
                + "FloppaOS next to Windows."
        }
        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            opacity: 0.75
            text: "This is a preview. It has been tested in virtual machines, not yet on many real PCs."
        }
        Item { Layout.fillHeight: true }
    }
}

/***************************************************************************
 *   Copyright (C) 2013-2014 by Eike Hein <hein@kde.org>                   *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program; if not, write to the                         *
 *   Free Software Foundation, Inc.,                                       *
 *   51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA .        *
 ***************************************************************************/

// FloppaOS: the button only opens and closes Plasma's own applet popup (main.qml's fullRepresentation).
// Upstream created its own window and placed it by hand, which no longer shows on Plasma 6.8 (Wayland only).

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

MouseArea {
    id: button

    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool useCustomButtonImage: Plasmoid.configuration.useCustomButtonImage
                                                  && Plasmoid.configuration.customButtonImage.length !== 0

    Layout.minimumWidth: vertical ? 0 : height
    Layout.minimumHeight: vertical ? width : 0
    Layout.preferredWidth: vertical ? -1 : height
    Layout.preferredHeight: vertical ? width : -1

    hoverEnabled: true
    Accessible.name: Plasmoid.title
    Accessible.role: Accessible.Button

    // A click while the menu is open closes it: the press already took the focus away from the popup.
    property bool wasExpanded: false
    onPressed: wasExpanded = kicker.expanded
    onClicked: kicker.expanded = !wasExpanded

    Kirigami.Icon {
        anchors.fill: parent
        source: button.useCustomButtonImage ? Plasmoid.configuration.customButtonImage : Plasmoid.configuration.icon
        active: button.containsMouse || kicker.expanded
        smooth: true
    }

    // Dragging a file onto the button opens the menu (as in KDE's own launcher).
    DropArea {
        anchors.fill: parent
        onEntered: openOnDrag.start()
        onExited: openOnDrag.stop()
    }
    Timer {
        id: openOnDrag
        interval: 250
        onTriggered: kicker.expanded = true
    }
}

/***************************************************************************
 *   Copyright (C) 2014 by Weng Xuetian <wengxt@gmail.com>
 *   Copyright (C) 2013-2017 by Eike Hein <hein@kde.org>                   *
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

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components 3.0 as PC3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.private.kicker 0.1 as Kicker
import org.kde.kquickcontrolsaddons

import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as Plasma5Support

// FloppaOS: this is now the content of Plasma's own applet popup (main.qml's fullRepresentation), so Plasma
// opens it next to the start button. Upstream made its own PlasmaCore.Dialog and moved it to a position it
// worked out itself (popupPosition()); on Plasma 6.8 (Wayland only) that window never showed up.
FocusScope {
    id: root
    objectName: "popupWindow"

    Layout.minimumWidth: rootItem.width
    Layout.maximumWidth: rootItem.width
    Layout.preferredWidth: rootItem.width
    Layout.minimumHeight: rootItem.height
    Layout.maximumHeight: rootItem.height
    Layout.preferredHeight: rootItem.height

    property int iconSize: {
        switch (Plasmoid.configuration.appsIconSize) {
        case 0:
            return Kirigami.Units.iconSizes.smallMedium;
        case 1:
            return Kirigami.Units.iconSizes.medium;
        case 2:
            return Kirigami.Units.iconSizes.large;
        case 3:
            return Kirigami.Units.iconSizes.huge;
        default:
            return 64;
        }
    }

    property int docsIconSize: {
        switch (Plasmoid.configuration.docsIconSize) {
        case 0:
            return Kirigami.Units.iconSizes.smallMedium;
        case 1:
            return Kirigami.Units.iconSizes.medium;
        case 2:
            return Kirigami.Units.iconSizes.large;
        case 3:
            return Kirigami.Units.iconSizes.huge;
        default:
            return Kirigami.Units.iconSizes.medium;
        }
    }

    property int cellSizeHeight: iconSize + Kirigami.Units.gridUnit * 2 + (2 * Math.max(highlightItemSvg.margins.top + highlightItemSvg.margins.bottom, highlightItemSvg.margins.left + highlightItemSvg.margins.right))
    property int cellSizeWidth: cellSizeHeight + Kirigami.Units.gridUnit

    property bool searching: (searchField.text != "")

    onSearchingChanged: {

        if (searching) {

            view.currentIndex = 2;
        } else {

            view.currentIndex = 0;
        }
    }
    Connections {
        target: kicker
        function onExpandedChanged() {
            if (kicker.expanded) {
                root.reset();
            } else {
                view.currentIndex = 0;
            }
        }
    }

    function toggle() {
        kicker.expanded = !kicker.expanded;
    }

    function reset() {
        searchField.text = "";
        searchField.focus = true;
        view.currentIndex = 0;
        globalFavoritesGrid.currentIndex = -1;
        documentsGrid.currentIndex = -1;
        allAppsGrid.currentIndex = -1;
    }

    function colorWithAlpha(color: color, alpha: real): color {
        return Qt.rgba(color.r, color.g, color.b, alpha);
    }

    FocusScope {
        id: rootItem
        property int widthComputed: root.cellSizeWidth * Plasmoid.configuration.numberColumns + Kirigami.Units.gridUnit * 2

        width: Math.max(widthComputed + Kirigami.Units.gridUnit * 2, 300)
        height: view.height + searchField.height + footer.height + Kirigami.Units.gridUnit * 3

        focus: true
        onFocusChanged: searchField.focus = true

        Plasma5Support.DataSource {
            id: executable
            engine: "executable"
            connectedSources: []

            property bool dolphinRunning: false

            onNewData: function (source, data) {
                if (source.includes("pgrep")) {
                    dolphinRunning = data["exit code"] === 0;
                }
                disconnectSource(source);
            }

            function exec(cmd) {
                connectSource(cmd);
            }

            function checkDolphin() {
                connectSource("pgrep dolphin");
            }
        }

        Kirigami.Heading {
            id: dummyHeading
            visible: false
            width: 0
            level: 5
        }

        TextMetrics {
            id: headingMetrics
            font: dummyHeading.font
        }

        PC3.TextField {
            id: searchField
            anchors {
                top: parent.top
                topMargin: Kirigami.Units.gridUnit
                left: parent.left
                leftMargin: Kirigami.Units.gridUnit
                right: parent.right
                rightMargin: Kirigami.Units.gridUnit
            }
            focus: true
            placeholderText: i18n("Type here to search ...")
            topPadding: 10
            bottomPadding: 10
            leftPadding: Kirigami.Units.gridUnit + Kirigami.Units.iconSizes.small
            text: ""
            font.pointSize: Kirigami.Theme.defaultFont.pointSize

            background: Rectangle {
                color: Kirigami.Theme.backgroundColor
                radius: 20
                border.width: 1
                border.color: colorWithAlpha(Kirigami.Theme.textColor, 0.05)
            }

            onTextChanged: runnerModel.query = text
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    event.accepted = true;
                    if (root.searching) {
                        searchField.clear();
                    } else {
                        root.toggle();
                    }
                }
                // Forward Up/Down keys directly to runnerGrid when on search page
                if (view.currentIndex === 2 && (event.key === Qt.Key_Up || event.key === Qt.Key_Down)) {
                    event.accepted = true;

                    // Make sure runnerGrid can receive the key event
                    runnerGrid.focus = true;

                    // Forward the key event to runnerGrid
                    if (event.key === Qt.Key_Down) {
                        console.log("Down key pressed");
                        // Simulate a down key press on the first item if nothing is selected
                        if (!runnerGrid.focus || runnerGrid.currentIndex === -1) {
                            runnerGrid.tryActivate(0, 0);
                        } else {
                            // Forward the down key to the currently focused grid
                            var currentGrid = runnerGrid.subGridAt(0); // or find the currently active grid
                            if (currentGrid) {
                                currentGrid.forceActiveFocus();
                                // Trigger the key navigation
                                currentGrid.keyNavDown();
                            }
                        }
                    } else if (event.key === Qt.Key_Up) {
                        // For up key, go to the last item or handle appropriately
                        console.log("Up key pressed");
                        var lastGridIndex = runnerGrid.count - 1;
                        if (lastGridIndex >= 0) {
                            var lastGrid = runnerGrid.subGridAt(lastGridIndex);
                            if (lastGrid && lastGrid.count > 0) {
                                lastGrid.tryActivate(lastGrid.lastRow(), 0);
                                lastGrid.focus = true;
                            }
                        }
                    }
                    return;
                }

                if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                    event.accepted = true;
                    if (view.currentIndex === 2) {
                        // For search results page
                        runnerGrid.focus = true;
                        runnerGrid.tryActivate(0, 0);
                    } else {
                        // For other pages
                        view.currentItem.forceActiveFocus();
                        view.currentItem.tryActivate(0, 0);
                    }
                }

                
            }
            Keys.onReturnPressed: {
                if (view.currentIndex === 2) {
                    // On search results page, activate the first available item
                    runnerGrid.focus = true;

                    // Find the first grid with items and activate its first item
                    for (var i = 0; i < runnerGrid.count; i++) {
                        var grid = runnerGrid.subGridAt(i);
                        if (grid && grid.count > 0) {
                            grid.currentIndex = 0;
                            grid.focus = true;
                            grid.itemActivated(0, "", null);
                       
                            if ("trigger" in grid.model) {
                                //console.log("Calling grid.model.trigger(0)");
                                grid.model.trigger(0, "", null);
                                root.toggle();
                            }
                            return;
                        }
                    }
                } else {
                    // Original logic for other pages
                    for (var i = 0; i < runnerGrid.count; i++) {
                        var grid = runnerGrid.subGridAt(i)
                        if (grid && grid.count > 0) {
                            grid.currentIndex = 0
                            grid.focus = true
                            grid.itemActivated(0, "", null)
                            return
                        }
                    }
                }
            }
            function backspace() {
                if (!kicker.expanded) {
                    return;
                }
                focus = true;
                text = text.slice(0, -1);
            }

            function appendText(newText) {
                if (!kicker.expanded) {
                    return;
                }
                focus = true;
                text = text + newText;
            }

            Kirigami.Icon {
                source: 'search'
                anchors {
                    left: searchField.left
                    verticalCenter: searchField.verticalCenter
                    leftMargin: Kirigami.Units.smallSpacing * 2
                }
                height: Kirigami.Units.iconSizes.small
                width: height
            }
        }

        SwipeView {
            id: view

            interactive: false
            currentIndex: 0
            clip: true

            anchors {
                top: searchField.bottom
                topMargin: Kirigami.Units.gridUnit
                left: parent.left
                leftMargin: Kirigami.Units.gridUnit
                right: parent.right
                rightMargin: Kirigami.Units.gridUnit
            }
            onCurrentIndexChanged: {
                globalFavoritesGrid.currentIndex = -1;
                documentsGrid.currentIndex = -1;
            }

            width: rootItem.widthComputed / 0.1
            height: (root.cellSizeHeight * Plasmoid.configuration.numberRows) + (topRow.height * 2) + ((docsIconSize + Kirigami.Units.largeSpacing) * 5) + (3 * Kirigami.Units.largeSpacing)

            // PAGE 1
            Column {
            width: view.width // Ensure Column fills SwipeView
                height: view.height
                spacing: Kirigami.Units.largeSpacing
                function tryActivate(row, col) {
                    globalFavoritesGrid.tryActivate(row, col);
                }

                RowLayout {
                    id: topRow
                    width: parent.width
                    height: butttonActionAllApps.implicitHeight
                    Kirigami.Icon {
                        visible: false // FloppaOS: Windows 11 style, title only
                        source: 'bookmarks'
                        implicitHeight: Kirigami.Units.iconSizes.smallMedium
                        implicitWidth: Kirigami.Units.iconSizes.smallMedium
                    }

                    PlasmaExtras.Heading {
                        id: headLabelFavorites
                        color: colorWithAlpha(Kirigami.Theme.textColor, 0.8)
                        level: 5
                        text: i18n("Pinned")
                        font.weight: Font.Bold
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    PC3.ToolButton {
                        id: butttonActionAllApps
                        text: i18n("All apps")
                        // FloppaOS: the text first, then the arrow (as in Windows 11)
                        contentItem: RowLayout {
                            spacing: Kirigami.Units.smallSpacing
                            PC3.Label {
                                text: butttonActionAllApps.text
                            }
                            Kirigami.Icon {
                                source: "go-next"
                                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                            }
                        }
                        onClicked: {
                            view.currentIndex = 1;
                        }
                    }
                }

                ItemGridView {
                    id: globalFavoritesGrid
                    width: parent.width
                    height: {
                        if (Plasmoid.configuration.showRecentDocuments) {
                            return root.cellSizeHeight * Plasmoid.configuration.numberRows;
                        } else {
                            return view.height - topRow.height - Kirigami.Units.largeSpacing - Kirigami.Units.gridUnit;
                        }
                    }
                    itemColumns: 1
                    dragEnabled: true
                    dropEnabled: true
                    cellWidth: parent.width / Plasmoid.configuration.numberColumns
                    cellHeight: root.cellSizeHeight
                    iconSize: root.iconSize
                    onKeyNavUp: {
                        globalFavoritesGrid.focus = false;
                        searchField.focus = true;
                    }
                    onKeyNavDown: {
                        globalFavoritesGrid.focus = false;
                        if (Plasmoid.configuration.showRecentDocuments) {
                            documentsGrid.tryActivate(0, 0);
                        }
                    }
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Tab) {
                            event.accepted = true;
                            searchField.focus = true;
                            globalFavoritesGrid.focus = false;
                        }
                    }
                }

                RowLayout {
                    visible: Plasmoid.configuration.showRecentDocuments
                    width: parent.width
                    height: butttonActionAllApps.implicitHeight

                    Kirigami.Icon {
                        visible: false // FloppaOS: Windows 11 style, title only
                        source: 'tag-recents'
                        implicitHeight: Kirigami.Units.iconSizes.smallMedium
                        implicitWidth: Kirigami.Units.iconSizes.smallMedium
                    }

                    PlasmaExtras.Heading {
                        color: colorWithAlpha(Kirigami.Theme.textColor, 0.8)
                        level: 5
                        text: i18n("Recent documents")
                        Layout.leftMargin: Kirigami.Units.smallSpacing
                        font.weight: Font.Bold
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    PC3.ToolButton {
                        id: butttonActionRecentMore
                        text: i18n("Show more")
                        // FloppaOS: the text first, then the arrow (as in Windows 11)
                        contentItem: RowLayout {
                            spacing: Kirigami.Units.smallSpacing
                            PC3.Label {
                                text: butttonActionRecentMore.text
                            }
                            Kirigami.Icon {
                                source: "go-next"
                                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                            }
                        }
                        onClicked: {
                            executable.checkDolphin();
                            if (executable.dolphinRunning) {
                                console.log("dolphin is running");
                                executable.exec("dolphin 'recentlyused:/files/'");
                            } else {
                                console.log("dolphin is not running");
                                executable.exec("dolphin --new-window 'recentlyused:/files/'");
                            }
                            root.toggle();
                        }
                    }
                }

                ItemGridView {
                    visible: Plasmoid.configuration.showRecentDocuments
                    id: documentsGrid
                    width: parent.width
                    height: cellHeight * 3
                    itemColumns: 2
                    dragEnabled: true
                    dropEnabled: true
                    cellWidth: (width - Kirigami.Units.gridUnit) / 2
                    cellHeight: docsIconSize + Kirigami.Units.largeSpacing * 2
                    iconSize: docsIconSize
                    clip: true
                    handleTriggerManually: true
                    onItemActivated: (index, actionId, argument) => {
                         var url = documentsGrid.currentItem.url.toString();
                         console.log("Opening URL:", url);
                         executable.exec("xdg-open '" + url.replace(/'/g, "'\\''") + "'");
                         root.toggle();
                    }
                    onKeyNavUp: {
                        globalFavoritesGrid.tryActivate(0, 0);
                        documentsGrid.focus = false;
                    }
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Tab) {
                            event.accepted = true;
                            searchField.focus = true;
                            documentsGrid.focus = false;
                        }
                    }

                    // FloppaOS: a hint while the list is still empty, instead of a blank area
                    PC3.Label {
                        anchors.centerIn: parent
                        visible: documentsGrid.count === 0
                        text: i18n("Files you open will show up here")
                        color: colorWithAlpha(Kirigami.Theme.textColor, 0.6)
                    }
                }
            }
            // PAGE 2
            Column {
                width: view.width // Ensure Column fills SwipeView
                height: view.height
                spacing: Kirigami.Units.largeSpacing
                function tryActivate(row, col) {
                    allAppsGrid.tryActivate(row, col);
                }

                RowLayout {
                    id: allAppsTopRow
                    width: parent.width
                    height: butttonActionAllApps.implicitHeight

                    Kirigami.Icon {
                        visible: false // FloppaOS: Windows 11 style, title only
                        source: 'view-grid'
                        implicitHeight: Kirigami.Units.iconSizes.smallMedium
                        implicitWidth: Kirigami.Units.iconSizes.smallMedium
                    }

                    PlasmaExtras.Heading {
                        color: colorWithAlpha(Kirigami.Theme.textColor, 0.8)
                        level: 5
                        text: i18n("All apps")
                        Layout.leftMargin: Kirigami.Units.smallSpacing
                        font.weight: Font.Bold
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    PC3.ToolButton {
                        icon.name: 'go-previous'
                        text: i18n("Pinned")
                        onClicked: {
                            view.currentIndex = 0;
                        }
                    }
                }

                ItemGridView {
                    id: allAppsGrid
                    width: parent.width
                    height: view.height - allAppsTopRow.height - Kirigami.Units.largeSpacing - Kirigami.Units.gridUnit
                    itemColumns: 1
                    forceListDelegate: true
                    showDescriptions: Plasmoid.configuration.showDescriptions
                    dragEnabled: false
                    dropEnabled: false
                    cellWidth: width
                    cellHeight: root.iconSize + Kirigami.Units.largeSpacing
                    iconSize: root.iconSize
                    onKeyNavUp: {
                        searchField.focus = true;
                        allAppsGrid.focus = false;
                    }
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Tab) {
                            event.accepted = true;
                            searchField.focus = true;
                            allAppsGrid.focus = false;
                        }
                    }
                }
            }

            // PAGE 3
            ItemMultiGridView {
                id: runnerGrid
                width: rootItem.widthComputed
                height: view.height
                itemColumns: 3
                cellWidth: rootItem.widthComputed - Kirigami.Units.gridUnit * 2
                cellHeight: root.iconSize + Kirigami.Units.smallSpacing * 4
                model: runnerModel
                grabFocus: true  // Change this to true
                focus: view.currentIndex === 2  // Add this line
                onKeyNavUp: {
                    runnerGrid.focus = false;
                    searchField.focus = true;
                }
            }
        }

        PlasmaExtras.PlasmoidHeading {
            id: footer
            contentWidth: parent.width
            contentHeight: Kirigami.Units.gridUnit * 3
            anchors.bottom: parent.bottom
            position: PC3.ToolBar.Footer

            Footer {
                anchors.fill: parent
                anchors.leftMargin: Kirigami.Units.gridUnit
                anchors.rightMargin: Kirigami.Units.gridUnit
            }
        }

        Keys.onPressed: event => {
            if (event.modifiers & Qt.ControlModifier || event.modifiers & Qt.ShiftModifier) {
                searchField.focus = true;
                return;
            }
            if (event.key === Qt.Key_Escape) {
                event.accepted = true;
                if (root.searching) {
                    reset();
                } else {
                    kicker.expanded = false;
                }
                return;
            }

            if (searchField.focus) {
                return;
            }

            if (event.key === Qt.Key_Backspace) {
                event.accepted = true;
                searchField.backspace();
            } else if (event.text !== "") {
                event.accepted = true;
                searchField.appendText(event.text);
            }
        }
    }

    function setModels() {
        globalFavoritesGrid.model = globalFavorites;
        allAppsGrid.model = rootModel.modelForRow(2);
        documentsGrid.model = rootModel.modelForRow(1);
    }

    Component.onCompleted: {
        rootModel.refreshed.connect(setModels);
        reset();
        rootModel.refresh();
    }
}

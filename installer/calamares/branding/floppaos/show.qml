/*
 *   SPDX-FileCopyrightText: 2015 Teo Mrnjavac <teo@kde.org>
 *   SPDX-FileCopyrightText: 2018 Adriaan de Groot <groot@kde.org>
 *   SPDX-FileCopyrightText: 2026 FloppaOS
 *   SPDX-License-Identifier: GPL-3.0-or-later
 *   Based on the sample slideshow of Calamares 3.4.2 (src/branding/default/show.qml).
 */
/* FloppaOS installer slideshow, shown while FloppaOS is being installed (Calamares slideshow API 2).
 * Black background (OLED), white text, the logo's orange for titles. A new slide every 20 seconds.
 * Text rule: no other platforms or stores are named here.
 */
import QtQuick 2.0;
import calamares.slideshow 1.0;

Presentation
{
    id: presentation
    textColor: "#ffffff"
    titleColor: "#f58220"
    fontFamily: "Noto Sans"

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        z: -1
    }

    function nextSlide() {
        presentation.goToNextSlide();
    }

    Timer {
        id: advanceTimer
        interval: 20000
        running: presentation.activatedInCalamares
        repeat: true
        onTriggered: nextSlide()
    }

    Slide {
        title: "Welcome to FloppaOS"
        content: [
            "A familiar desktop: taskbar at the bottom, start menu on the left",
            "Ready for games, with graphics drivers already installed",
            "Built on Arch Linux, so the software is always new"
        ]
    }

    Slide {
        title: "Feels like home"
        content: [
            "Start menu: the button on the left, or the Windows key",
            "Files: Windows key + E",
            "Settings: Windows key + I",
            "Task Manager: Ctrl + Shift + Esc"
        ]
    }

    Slide {
        title: "Made for games"
        content: [
            "AMD graphics drivers (Vulkan) with 32-bit support for older games",
            "GameMode gives a game more speed while it runs",
            "Floppa Setup installs the Floppa Launcher and checks your Floppa games"
        ]
    }

    Slide {
        title: "Almost done"
        content: [
            "When the installer is finished, restart and remove the USB stick",
            "Log in with the account you just created",
            "Floppa Setup opens after your first login"
        ]
    }

    function onActivate() {
        presentation.currentSlide = 0;
    }

    function onLeave() {
    }
}

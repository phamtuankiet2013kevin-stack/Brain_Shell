import QtQuick
import QtQuick.Controls
import "../"
import "../../"

Item {
    id: root

    Flickable {
        anchors.fill: parent
        contentWidth:  width
        contentHeight: _col.implicitHeight + 16
        clip:           true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle {
                implicitWidth: 3; implicitHeight: 40; radius: 1.5
                color: Qt.rgba(1, 1, 1, 0.22)
            }
            background: Item {}
        }

        Column {
            id: _col
            width:   parent.width - 8
            spacing: 14

            Item {
                width:  parent.width
                height: _headerCol.implicitHeight

                Column {
                    id: _headerCol
                    width: parent.width
                    spacing: 4

                    Text {
                        text: "Themes"
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        color: Theme.text
                    }

                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: "Switch between premade color palettes. Drop matching wallpapers into src/assets/wallpapers/ to enable full wallpaper + matugen theming."
                        font.pixelSize: 11
                        color: Qt.rgba(1, 1, 1, 0.38)
                    }
                }
            }

            Flow {
                width:  parent.width
                spacing: 10

                Repeater {
                    model: ThemeService.themes

                    delegate: Rectangle {
                        id: card
                        required property var modelData

                        readonly property bool isActive: ThemeService.currentThemeId === modelData.id
                        readonly property bool isBusy:   ThemeService.applying && isActive

                        width:  Math.floor((_col.width - 10) / 2)
                        height: 108
                        radius: Theme.cornerRadius
                        color:  Qt.rgba(1, 1, 1, 0.03)
                        border.width: isActive ? 2 : 1
                        border.color: isActive
                            ? Theme.active
                            : (cardHov.hovered ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08))
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        Rectangle {
                            anchors {
                                top:    parent.top
                                left:   parent.left
                                right:  parent.right
                                margins: 8
                            }
                            height: 44
                            radius: 6
                            clip: true

                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop {
                                    position: 0
                                    color: modelData.colors ? modelData.colors.background : "#1a282a"
                                }
                                GradientStop {
                                    position: 1
                                    color: modelData.colors ? modelData.colors.active : "#a6d0f7"
                                }
                            }

                            Image {
                                anchors.fill: parent
                                visible: {
                                    var p = ThemeService.resolveWallpaper(modelData)
                                    return p !== ""
                                }
                                source: {
                                    var p = ThemeService.resolveWallpaper(modelData)
                                    return p !== "" ? "file://" + p : ""
                                }
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                        }

                        Column {
                            anchors {
                                left:   parent.left
                                right:  parent.right
                                bottom: parent.bottom
                                margins: 8
                            }
                            spacing: 2

                            Text {
                                text: modelData.name || modelData.id
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: isActive ? Theme.active : Theme.text
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            Text {
                                text: modelData.description || ""
                                font.pixelSize: 9
                                color: Qt.rgba(1, 1, 1, 0.35)
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }

                        Rectangle {
                            anchors.top:    parent.top
                            anchors.right:  parent.right
                            anchors.margins: 6
                            width: 18; height: 18; radius: 9
                            visible: isActive
                            color: Theme.active
                            Text {
                                anchors.centerIn: parent
                                text: isBusy ? "…" : "✓"
                                font.pixelSize: 10
                                color: Theme.background
                            }
                        }

                        HoverHandler { id: cardHov; cursorShape: Qt.PointingHandCursor }
                        MouseArea {
                            anchors.fill: parent
                            enabled: !ThemeService.applying
                            onClicked: ThemeService.applyTheme(modelData.id)
                        }
                    }
                }
            }

            Text {
                visible: ThemeService.themes.length === 0
                anchors.horizontalCenter: parent.horizontalCenter
                text: "No theme presets found."
                font.pixelSize: 12
                color: Qt.rgba(1, 1, 1, 0.25)
            }
        }
    }
}

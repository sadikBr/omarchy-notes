import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Notes.js" as N

// Bar entry for notes. A checklist glyph and the current task (the first open
// one), or just the open count when showTask is off.
//
//   left click    open the popup
//   right click   mark the current task done
//   middle click  open todo.md in the editor
BarWidget {
  id: root
  moduleName: "bsadik.notes"

  // The service is created by the shell independently of the widget, and a
  // plugin reload recreates it, so keep looking it up until it is there.
  property var service: null
  property bool popupOpen: false

  readonly property bool ready: service !== null && service.loaded === true
  readonly property int openCount: ready ? service.openCount : 0
  readonly property bool showTask: setting("showTask", true) === true
  readonly property int maxChars: Number(setting("maxTaskChars", 28)) || 28

  readonly property color barColor: root.bar ? root.bar.barForeground : Commons.Color.foreground
  readonly property color fg: root.bar ? root.bar.foreground : Commons.Color.foreground
  readonly property color accent: Commons.Color.accent
  readonly property string fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
  readonly property string iconFamily: "JetBrainsMono Nerd Font"

  readonly property string label: !ready || openCount === 0 ? ""
    : showTask && service.current ? N.ellipsize(service.current.text, maxChars)
    : String(openCount)

  readonly property string tooltip: {
    if (!ready) return "Notes"
    var lines = ["Notes · " + service.summary()]
    if (service.current) lines.push("Now: " + service.current.text)
    lines.push("Right-click: done · Middle-click: open in editor")
    return lines.join("\n")
  }

  // Shape contract for shell.summon/hide/toggle routing: the bar looks for
  // open/close/opened on the widget root and picks the copy on the focused
  // monitor.
  readonly property bool opened: popupOpen
  function close() { popupOpen = false }
  function open() { popupOpen = true }

  function findService() {
    if (!root.bar || !root.bar.shell) return
    var s = root.bar.shell.serviceFor(root.moduleName) || null
    if (s !== root.service) root.service = s
  }

  Timer {
    interval: root.service ? 2000 : 400
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.findService()
  }

  implicitWidth: vertical ? barSize : row.implicitWidth + Style.space(14)
  implicitHeight: vertical ? column.implicitHeight + Style.space(10) : barSize

  Row {
    id: row
    visible: !root.vertical
    anchors.centerIn: parent
    spacing: Style.space(5)

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: N.icons.list
      color: root.openCount > 0 ? root.barColor : Util.alpha(root.barColor, 0.45)
      font.family: root.iconFamily
      font.pixelSize: Style.font.body + 1
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      visible: root.label !== ""
      textFormat: Text.PlainText
      text: root.label
      color: root.barColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }
  }

  Column {
    id: column
    visible: root.vertical
    anchors.centerIn: parent
    spacing: Style.space(2)

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: N.icons.list
      color: root.openCount > 0 ? root.barColor : Util.alpha(root.barColor, 0.45)
      font.family: root.iconFamily
      font.pixelSize: Style.font.body + 1
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      visible: root.openCount > 0
      textFormat: Text.PlainText
      text: String(root.openCount)
      color: root.barColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

    onClicked: function(mouse) {
      if (mouse.button === Qt.RightButton) { if (root.ready) root.service.completeCurrent() }
      else if (mouse.button === Qt.MiddleButton) { if (root.service) root.service.openInEditor(root.service.todoPath) }
      else root.popupOpen = !root.popupOpen
    }
    onEntered: if (root.bar) root.bar.showTooltip(root, root.tooltip)
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }

  // KeyboardPanel rather than PopupCard: the popup is mostly typing, and an
  // xdg-popup only gets keys after the pointer has been inside it.
  KeyboardPanel {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    focusTarget: panel.focusTarget
    contentWidth: popup.fittedContentWidth(Style.space(420))
    contentHeight: popup.fittedContentHeight(panel.implicitHeight, Style.space(640))

    NotesPanel {
      id: panel
      anchors.fill: parent
      service: root.service
      opened: root.popupOpen
      foreground: root.fg
      accent: root.accent
      fontFamily: root.fontFamily
      iconFamily: root.iconFamily
      onCloseRequested: root.close()
    }
  }
}

import QtQuick
import QtQuick.Controls as QQC
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Notes.js" as N

// Popup body: a Todo tab (add field, checklist, clear done) and a Scratch
// tab (free text). The add field has focus when the popup opens, so
// SUPER+ALT+N, type, Enter adds a task without touching the mouse.
//
//   Enter      add the task           Tab / Shift+Tab   switch tabs
//   Esc        close the popup
Item {
  id: root

  property var service: null
  property bool opened: false
  property color foreground: Commons.Color.foreground
  property color accent: Commons.Color.accent
  property string fontFamily: Style.font.family
  property string iconFamily: "JetBrainsMono Nerd Font"

  property string tab: "todo"
  readonly property Item focusTarget: tab === "todo" ? addField : scratchArea

  readonly property bool ready: service !== null && service.loaded === true
  readonly property var tasks: ready ? service.tasks : []
  readonly property color muted: Qt.darker(foreground, 1.4)
  readonly property color urgent: Commons.Color.urgent

  signal closeRequested()

  implicitHeight: content.implicitHeight

  function switchTab(name) {
    root.tab = name
    Qt.callLater(function() { root.focusTarget.forceActiveFocus() })
  }

  function handleKey(event) {
    if (event.key === Qt.Key_Escape) {
      root.closeRequested()
      event.accepted = true
    } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
      root.switchTab(root.tab === "todo" ? "scratch" : "todo")
      event.accepted = true
    }
  }

  // Load the scratchpad into the editor on open, and follow edits made
  // elsewhere unless the user is typing in it right now.
  onOpenedChanged: if (opened) { scratchArea.text = service ? service.scratch : ""; addField.text = "" }
  Connections {
    target: root.service
    function onScratchChanged() {
      if (!scratchArea.activeFocus && scratchArea.text !== root.service.scratch) scratchArea.text = root.service.scratch
    }
  }

  Column {
    id: content
    width: parent.width
    spacing: Style.space(10)

    // ---------------------------------------------------------- tabs

    Item {
      width: parent.width
      height: Math.max(tabRow.height, editButton.height)

      Row {
        id: tabRow
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(6)

        Button {
          iconText: N.icons.list
          text: root.ready && root.service.openCount > 0 ? "Todo · " + root.service.openCount : "Todo"
          bordered: true
          selected: root.tab === "todo"
          foreground: root.foreground
          accent: root.accent
          onClicked: root.switchTab("todo")
        }

        Button {
          iconText: N.icons.pencil
          text: "Scratch"
          bordered: true
          selected: root.tab === "scratch"
          foreground: root.foreground
          accent: root.accent
          onClicked: root.switchTab("scratch")
        }
      }

      PanelActionButton {
        id: editButton
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        iconText: N.icons.edit
        tooltipText: "Open " + (root.tab === "todo" ? "todo.md" : "scratch.md") + " in the editor"
        fontFamily: root.iconFamily
        foreground: root.foreground
        onClicked: {
          if (!root.service) return
          root.service.openInEditor(root.tab === "todo" ? root.service.todoPath : root.service.scratchPath)
          root.closeRequested()
        }
      }
    }

    // ---------------------------------------------------------- todo

    Column {
      width: parent.width
      spacing: Style.space(8)
      visible: root.tab === "todo"

      TextField {
        id: addField
        width: parent.width
        placeholderText: "Add a task and press Enter"
        foreground: root.foreground
        accent: root.accent
        font.family: root.fontFamily
        Keys.onPressed: function(event) { root.handleKey(event) }
        onAccepted: {
          if (root.service && root.service.add(text) !== "") text = ""
        }
      }

      Text {
        visible: root.ready && root.tasks.length === 0
        textFormat: Text.PlainText
        text: "Nothing to do. Add a task above."
        color: root.muted
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
      }

      Flickable {
        id: taskScroll
        width: parent.width
        height: Math.min(taskColumn.implicitHeight, Style.space(380))
        contentWidth: width
        contentHeight: taskColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        visible: root.tasks.length > 0

        Column {
          id: taskColumn
          width: taskScroll.width
          spacing: Style.space(2)

          Repeater {
            model: root.tasks

            Item {
              id: taskRow
              required property var modelData
              required property int index
              readonly property bool isCurrent: root.service.current !== null && root.service.current.line === modelData.line
              readonly property bool hot: rowHover.hovered

              width: taskColumn.width
              height: Math.max(taskText.implicitHeight, Style.space(24)) + Style.space(6)

              BorderSurface {
                anchors.fill: parent
                radius: Style.cornerRadius
                color: taskRow.isCurrent ? Util.alpha(root.accent, 0.12)
                  : taskRow.hot ? Util.alpha(root.foreground, 0.06) : "transparent"
              }

              HoverHandler { id: rowHover }

              MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.service.toggle(taskRow.modelData.line)
              }

              Text {
                id: checkGlyph
                anchors.left: parent.left
                anchors.leftMargin: Style.space(6)
                anchors.verticalCenter: parent.verticalCenter
                text: taskRow.modelData.done ? N.icons.checked : (taskRow.isCurrent ? N.icons.target : N.icons.box)
                color: taskRow.modelData.done ? root.muted : (taskRow.isCurrent ? root.accent : root.foreground)
                font.family: root.iconFamily
                font.pixelSize: Style.font.icon
              }

              Text {
                id: taskText
                anchors.left: checkGlyph.right
                anchors.leftMargin: Style.space(8)
                anchors.right: actions.left
                anchors.rightMargin: Style.space(4)
                anchors.verticalCenter: parent.verticalCenter
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
                text: taskRow.modelData.text
                color: taskRow.modelData.done ? root.muted : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.strikeout: taskRow.modelData.done
                font.bold: taskRow.isCurrent
              }

              Row {
                id: actions
                anchors.right: parent.right
                anchors.rightMargin: Style.space(4)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(2)
                opacity: taskRow.hot ? 1 : 0

                PanelActionButton {
                  id: upButton
                  visible: !taskRow.modelData.done && !taskRow.isCurrent
                  iconText: N.icons.up
                  tooltipText: "Make this the current task"
                  fontFamily: root.iconFamily
                  foreground: root.foreground
                  onClicked: root.service.focusTask(taskRow.modelData.line)
                }

                PanelActionButton {
                  id: removeButton
                  iconText: N.icons.remove
                  tooltipText: "Delete"
                  fontFamily: root.iconFamily
                  foreground: root.foreground
                  hoverColor: root.urgent
                  onClicked: root.service.remove(taskRow.modelData.line)
                }
              }
            }
          }
        }
      }

      Item {
        width: parent.width
        height: Math.max(summaryText.implicitHeight, clearButton.height)
        visible: root.tasks.length > 0

        Text {
          id: summaryText
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: root.ready ? root.service.summary() + " · click a task to tick it" : ""
          color: root.muted
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }

        Button {
          id: clearButton
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          visible: root.ready && root.service.doneCount > 0
          iconText: N.icons.broom
          text: "Clear done"
          bordered: true
          foreground: root.foreground
          accent: root.accent
          onClicked: root.service.clearDone()
        }
      }
    }

    // ------------------------------------------------------- scratch

    Column {
      width: parent.width
      spacing: Style.space(6)
      visible: root.tab === "scratch"

      QQC.ScrollView {
        width: parent.width
        height: Style.space(300)

        QQC.TextArea {
          id: scratchArea
          placeholderText: "Anything worth keeping for a bit. Saved as you type."
          placeholderTextColor: Qt.darker(root.foreground, 1.6)
          wrapMode: TextEdit.Wrap
          color: root.foreground
          selectionColor: Style.selectionFillFor(root.foreground, root.accent)
          selectedTextColor: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          padding: Style.spacing.controlPaddingX
          background: BorderSurface {
            color: Style.controlFill(scratchArea.activeFocus, scratchArea.hovered, root.foreground, root.accent)
            borderSpec: Border.controlSpec(scratchArea.activeFocus ? "focus" : "normal", root.foreground, root.accent)
            radius: Style.cornerRadius
          }
          // Tab inside the scratchpad switches back to the todo list
          // rather than inserting a tab character.
          Keys.onPressed: function(event) { root.handleKey(event) }
          onTextChanged: if (activeFocus && root.service) root.service.setScratch(text)
        }
      }

      Text {
        textFormat: Text.PlainText
        text: root.service ? "Saved to ~/Documents/notes/scratch.md" : ""
        color: root.muted
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }
}

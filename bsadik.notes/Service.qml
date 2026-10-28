import Quickshell
import Quickshell.Io
import QtQuick
import "Notes.js" as N

// Notes engine. One instance per shell: it owns the todo list and the
// scratchpad, both plain markdown files that are watched for changes, so
// editing them in an editor shows up in the popup right away. Bar widgets
// (one per monitor) only read from it and call into it.
Item {
  id: root

  property var shell: null
  property var manifest: null
  property string omarchyPath: Quickshell.env("OMARCHY_PATH") || "/usr/share/omarchy"

  readonly property string dir: Quickshell.env("HOME") + "/Documents/notes"
  readonly property string todoPath: dir + "/todo.md"
  readonly property string scratchPath: dir + "/scratch.md"

  // ---------------------------------------------------------------- state

  property var lines: N.parse("").lines
  readonly property var tasks: N.tasksOf(lines)
  readonly property int openCount: N.openCount(tasks)
  readonly property int doneCount: tasks.length - openCount
  readonly property var current: N.current(tasks)
  property string scratch: ""
  property bool loaded: false

  function summary() {
    if (tasks.length === 0) return "No tasks"
    return openCount + " open · " + doneCount + " done"
  }

  // --------------------------------------------------------------- editing

  function taskAt(line) {
    for (var i = 0; i < tasks.length; i++) if (tasks[i].line === line) return tasks[i]
    return null
  }

  function commit(next) {
    root.lines = next
    todoFile.setText(N.serialize(next))
  }

  function add(text) {
    var clean = N.cleanText(text)
    if (clean === "") return ""
    var next = root.lines.slice()
    next.splice(N.insertIndex(next), 0, N.taskLine(clean, false))
    commit(next)
    return clean
  }

  // Either way the task lands right after the last open one: ticked, it
  // heads the finished tasks; unticked, it rejoins the end of the open list.
  function toggle(line) {
    var t = taskAt(line)
    if (!t) return
    var next = root.lines.slice()
    next.splice(line, 1)
    next.splice(N.insertIndex(next), 0, N.taskLine(t.text, !t.done))
    commit(next)
  }

  function edit(line, text) {
    var t = taskAt(line)
    var clean = N.cleanText(text)
    if (!t || clean === "" || clean === t.text) return
    var next = root.lines.slice()
    next[line] = N.taskLine(clean, t.done)
    commit(next)
  }

  function remove(line) {
    if (!taskAt(line)) return
    var next = root.lines.slice()
    next.splice(line, 1)
    commit(next)
  }

  // Moves a task to the top of the list, which makes it the current one.
  function focusTask(line) {
    var t = taskAt(line)
    if (!t || tasks.length === 0 || tasks[0].line === line) return
    var next = root.lines.slice()
    var moved = N.taskLine(t.text, false)
    next.splice(line, 1)
    next.splice(tasks[0].line, 0, moved)
    commit(next)
  }

  function clearDone() {
    var drop = {}
    tasks.forEach(function(t) { if (t.done) drop[t.line] = true })
    commit(root.lines.filter(function(_, i) { return !drop[i] }))
  }

  function completeCurrent() {
    if (!root.current) return ""
    var text = root.current.text
    toggle(root.current.line)
    return text
  }

  function setScratch(text) {
    if (text === root.scratch) return
    root.scratch = text
    scratchSave.restart()
  }

  function openInEditor(path) {
    Quickshell.execDetached([root.omarchyPath + "/bin/omarchy-launch-editor", path])
  }

  // ------------------------------------------------------------- plumbing

  // The files have to exist for the watchers to pick up outside edits.
  Component.onCompleted: Quickshell.execDetached(["bash", "-c", 'mkdir -p "$1" && touch "$1/todo.md" "$1/scratch.md"', "_", root.dir])

  FileView {
    id: todoFile
    path: root.todoPath
    printErrors: false
    watchChanges: true
    atomicWrites: true
    onFileChanged: reload()
    onLoaded: { root.lines = N.parse(text()).lines; root.loaded = true }
    onLoadFailed: root.loaded = true
  }

  FileView {
    id: scratchFile
    path: root.scratchPath
    printErrors: false
    watchChanges: true
    atomicWrites: true
    onFileChanged: reload()
    // A pending save means the popup holds newer text than the disk.
    onLoaded: if (!scratchSave.running) root.scratch = text()
  }

  Timer {
    id: scratchSave
    interval: 400
    onTriggered: scratchFile.setText(root.scratch)
  }

  IpcHandler {
    target: "bsadik.notes"

    function add(text: string): string { return root.add(text) }
    function current(): string { return root.current ? root.current.text : "" }
    function done(): string { return root.completeCurrent() }
    function list(): string {
      return root.tasks.map(function(t) { return (t.done ? "[x] " : "[ ] ") + t.text }).join("\n")
    }
    function status(): string {
      return JSON.stringify({ open: root.openCount, done: root.doneCount, current: root.current ? root.current.text : null, file: root.todoPath })
    }
    function panel(): void { if (root.shell) root.shell.toggle("bsadik.notes", "") }
  }
}

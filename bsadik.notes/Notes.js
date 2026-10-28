.pragma library

// Pure helpers for the notes plugin: icons, and reading and writing the todo
// file as a markdown checklist.
//
// The file is kept as a list of lines. Lines that are checklist items become
// tasks; everything else (headings, blank lines, notes written by hand in an
// editor) is kept in place, so editing the file outside the popup is safe.

function g(cp) { return String.fromCodePoint(cp) }

var icons = {
  note: g(0xF11D7),
  list: g(0xF0756),
  box: g(0xF0131),
  checked: g(0xF0135),
  remove: g(0xF09E7),
  up: g(0xF0737),
  target: g(0xF04FE),
  plus: g(0xF0415),
  edit: g(0xF0DC9),
  broom: g(0xF00E2),
  pencil: g(0xF03EB)
}

var taskPattern = /^(\s*)[-*] \[( |x|X)\] ?(.*)$/

var header = ["# Todo", ""]

// "- [ ] a\n- [x] b" -> { lines: [...], tasks: [{ line, text, done }] }
function parse(text) {
  var lines = String(text || "").replace(/\r\n/g, "\n").split("\n")
  // A trailing newline leaves one empty element behind; drop it so a
  // save/parse round trip doesn't grow the file.
  if (lines.length > 0 && lines[lines.length - 1] === "") lines.pop()
  if (lines.length === 0) lines = header.slice()
  return { lines: lines, tasks: tasksOf(lines) }
}

function tasksOf(lines) {
  var tasks = []
  for (var i = 0; i < lines.length; i++) {
    var m = taskPattern.exec(lines[i])
    if (m) tasks.push({ line: i, text: m[3], done: m[2] !== " " })
  }
  return tasks
}

function serialize(lines) {
  return lines.join("\n") + "\n"
}

function taskLine(text, done) {
  return "- [" + (done ? "x" : " ") + "] " + cleanText(text)
}

// One line, no leading checkbox the user typed by habit.
function cleanText(text) {
  return String(text || "").replace(/[\r\n]+/g, " ").replace(/^\s*[-*]?\s*\[[ xX]?\]\s*/, "").trim()
}

// New tasks go after the last open task, so the list reads top to bottom as
// "do next" and finished items collect below.
function insertIndex(lines) {
  var tasks = tasksOf(lines)
  var lastOpen = -1
  for (var i = 0; i < tasks.length; i++) if (!tasks[i].done) lastOpen = tasks[i].line
  if (lastOpen >= 0) return lastOpen + 1
  if (tasks.length > 0) return tasks[0].line
  return lines.length
}

function openCount(tasks) {
  return tasks.filter(function(t) { return !t.done }).length
}

function current(tasks) {
  for (var i = 0; i < tasks.length; i++) if (!tasks[i].done) return tasks[i]
  return null
}

function ellipsize(text, max) {
  text = String(text || "")
  return text.length > max ? text.slice(0, Math.max(1, max - 1)) + "…" : text
}

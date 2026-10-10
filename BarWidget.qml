import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

// Shows the EC power mode set by the Corsair AI Workstation 300's front
// button (via the ec_su_axb35 driver) alongside live APU package power, so
// the effect of a mode change is visible as the wattage ceiling moves.
// Right-click opens a menu to switch the fans between auto and max.
Panel {
  id: root
  moduleName: "iain.corsair-power"
  ipcTarget: "iain.corsair-power"

  property var status: ({})
  property int cursorLevel: 0
  property bool cursorActive: false
  property string liveMode: ""
  readonly property string mode: liveMode || status.mode || ""
  readonly property int fanFloor: status.fanFloor || 0
  readonly property var modes: ["quiet", "balanced", "performance"]
  readonly property var icons: ({ quiet: "󰾆", balanced: "󰾅", performance: "󰓅" })
  readonly property var names: ({ quiet: "Quiet", balanced: "Balanced", performance: "Performance" })
  readonly property var levels: [
    { level: 5, label: "Max" },
    { level: 0, label: "Auto" }
  ]

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function cycleMode() {
    if (!status.driver || !root.bar) return
    var next = modes[(modes.indexOf(mode) + 1) % modes.length]
    root.bar.run("echo " + next + " > /sys/class/ec_su_axb35/apu/power_mode")
    refreshSoon.restart()
  }

  function setFanLevel(level) {
    if (!status.driver || !root.bar) return
    root.bar.run("corsair-fans floor " + level)
    refreshSoon.restart()
    close()
  }

  function fanLabel() {
    return fanFloor === 0 ? "" : " 󰈐"
  }

  function tooltip() {
    var s = status
    var lines = []
    lines.push("Power mode: " + (s.driver ? (names[mode] || mode || "unknown") : "unknown (ec_su_axb35 driver not loaded)"))
    lines.push("APU package power: " + (s.pptW || 0) + " W")
    lines.push("CPU " + (s.cpuTemp || 0) + "°C · GPU " + (s.gpuTemp || 0) + "°C @ " + (s.sclkMhz || 0) + " MHz")
    if (s.fans && s.fans.length) lines.push("Fans: " + s.fans.join(" / ") + " rpm" + (fanFloor === 0 ? " (auto)" : " (max)"))
    if (s.profile) lines.push("OS power profile: " + s.profile)
    if (s.driver) lines.push("Left-click: cycle mode · Right-click: fans")
    return lines.join("\n")
  }

  onOpenedChanged: {
    if (opened) {
      cursorLevel = fanFloor === 0 ? 0 : 5
      cursorActive = false
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process {
    id: statusProc
    command: ["corsair-power-status"]
    stdout: StdioCollector {
      onStreamFinished: {
        try { root.status = JSON.parse(text) } catch (e) {}
      }
    }
  }

  // The front button only changes EC register 0x31; there's no event for it,
  // so poll the mode file every second. (FileView won't re-read sysfs, whose
  // size and mtime never change, hence the tiny cat.)
  Process {
    id: modeProc
    command: ["cat", "/sys/class/ec_su_axb35/apu/power_mode"]
    stdout: StdioCollector {
      onStreamFinished: { if (text.trim() !== "") root.liveMode = text.trim() }
    }
  }

  Timer {
    interval: 1000
    running: root.status.driver === true
    repeat: true
    onTriggered: if (!modeProc.running) modeProc.running = true
  }

  Timer {
    id: refreshSoon
    interval: 300
    onTriggered: root.refresh()
  }

  Timer {
    interval: 10000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: (root.icons[root.mode] || "󰾅") + " " + Math.round((root.status.pptW || 0) / 5) * 5 + "W" + root.fanLabel()
    dimmed: !root.status.driver
    useActiveColor: false
    // Faint tint over the bar's text colour: blue for quiet, orange for performance.
    foreground: {
      var base = root.bar ? root.bar.barForeground : Color.foreground
      if (root.mode === "quiet") return Qt.tint(base, Qt.rgba(0.4, 0.65, 1.0, 0.4))
      if (root.mode === "performance") return Qt.tint(base, Qt.rgba(1.0, 0.6, 0.25, 0.4))
      return base
    }
    tooltipText: root.opened ? "" : root.tooltip()
    onPressed: function(b) {
      if (b === Qt.LeftButton) root.cycleMode()
      else if (b === Qt.RightButton) { if (root.status.driver) root.toggle() }
      else root.refresh()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(200))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        if (dy !== 0) root.cursorLevel = dy < 0 ? 5 : 0
      }
      onActivateRequested: if (root.cursorActive) root.setFanLevel(root.cursorLevel)
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(6)

        PanelSectionHeader {
          text: "FANS"
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
        }

        Repeater {
          model: root.levels
          Button {
            required property var modelData
            width: column.width
            iconText: "󰈐"
            iconSize: Style.font.body
            text: modelData.label
            leftAlign: true
            fontSize: Style.font.bodySmall
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            active: modelData.level === 0 ? root.fanFloor === 0 : root.fanFloor !== 0
            hasCursor: root.cursorActive && root.cursorLevel === modelData.level
            onClicked: root.setFanLevel(modelData.level)
            onHovered: function(h) {
              if (h) {
                root.cursorActive = true
                root.cursorLevel = modelData.level
              }
            }
          }
        }
      }
    }
  }
}

pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import Quickshell.Io
import qs.Ui as Ui
import qs.Commons
import "Model.js" as Model

Ui.Panel {
  id: root
  moduleName: "ben.omagic"
  ipcTarget: "ben.omagic"
  manageIpc: false

  readonly property string script: decodeURIComponent(String(Qt.resolvedUrl("omagic.py")).replace(/^file:\/\//, ""))
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color muted: Qt.alpha(foreground, 0.65)
  readonly property string family: bar ? bar.fontFamily : Style.font.family
  readonly property var preferences: Object.assign({}, snapshot.settings || {}, optimistic)
  readonly property bool managed: !!(snapshot.plugins && (snapshot.plugins.plus || snapshot.plugins.pulse))
  readonly property bool trackpadPresent: !!(snapshot.trackpad && snapshot.trackpad.present)
  readonly property bool busy: action.running
  readonly property bool saving: busy || Object.keys(pending).length > 0
  property var snapshot: ({})
  property string page: "Devices"
  property string error: ""
  property string activity: ""
  property var optimistic: ({})
  property var pending: ({})
  property var applying: ({})
  property bool settingsAction: false
  property int revision: 0
  property int statusRevision: 0

  function refresh() {
    if (!status.running && !busy && !Object.keys(pending).length) {
      statusRevision = revision
      status.running = true
    }
  }
  function run(args, label) {
    if (busy || Object.keys(pending).length) return
    revision++
    error = ""
    activity = label
    settingsAction = false
    action.command = ["python3", script].concat(args)
    action.running = true
  }
  function setSetting(key, value) {
    revision++
    error = ""
    var next = Object.assign({}, optimistic)
    next[key] = value
    optimistic = next
    var patch = Object.assign({}, pending)
    patch[key] = value
    pending = patch
    saveDelay.restart()
  }
  function saveNext() {
    if (busy || !Object.keys(pending).length) return
    var patch = Object.assign({}, pending)
    var rest = {}
    // Fn mode can require authentication and is independent of trackpad settings.
    if (patch.macFnKeys !== undefined) {
      rest = patch
      patch = {macFnKeys: rest.macFnKeys}
      delete rest.macFnKeys
    }
    applying = patch
    pending = rest
    settingsAction = true
    activity = "Saving…"
    action.command = ["python3", script, "set-settings", JSON.stringify(patch)]
    action.running = true
  }

  implicitWidth: chip.implicitWidth
  implicitHeight: chip.implicitHeight
  Component.onCompleted: refresh()
  onOpenedChanged: if (opened) refresh()

  IpcHandler {
    target: "ben.omagic"
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): void { root.refresh() }
    function showPage(name: string): void {
      if (["Devices", "Trackpad", "Gestures"].indexOf(name) >= 0) { root.page = name; scroll.contentY = 0; root.open() }
    }
    function status(): string { return JSON.stringify(root.snapshot) }
  }
  Timer { id: saveDelay; interval: 120; onTriggered: root.saveNext() }
  Timer {
    interval: root.opened ? 5000 : 30000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }
  Process {
    id: status
    command: ["python3", root.script, "state"]
    stdout: StdioCollector { id: statusOutput; waitForEnd: true }
    onExited: {
      try {
        var result = JSON.parse(statusOutput.text)
        if (result.ok && !root.busy && root.statusRevision === root.revision) root.snapshot = result
        else if (!result.ok) root.error = result.error
      } catch (e) { root.error = "Unable to read devices. Check that Python 3 is installed." }
    }
  }
  Process {
    id: action
    stdout: StdioCollector { id: actionOutput; waitForEnd: true }
    onExited: {
      var result
      try { result = JSON.parse(actionOutput.text) }
      catch (e) { result = {ok: false, error: "The command failed. Run it from a terminal for details."} }
      root.error = result.ok ? "" : result.error
      if (root.settingsAction) {
        if (result.ok && result.settings) {
          var updated = Object.assign({}, root.snapshot)
          updated.settings = result.settings
          root.snapshot = updated
        }
        var next = Object.assign({}, root.optimistic)
        Object.keys(root.applying).forEach(function(key) {
          if (!(key in root.pending)) delete next[key]
        })
        root.optimistic = next
        root.applying = ({})
      }
      root.activity = ""
      if (Object.keys(root.pending).length) saveDelay.restart()
      else Qt.callLater(root.refresh)
    }
  }

  Ui.BarIconButton {
    id: chip
    anchors.fill: parent
    bar: root.bar
    tooltipText: "Omagic · " + Model.heroStatus(root.snapshot)
    iconComponent: Component {
      WandIcon { color: root.foreground; fontFamily: root.family }
    }
    onPressed: root.toggle()
  }

  Ui.KeyboardPanel {
    id: popup
    anchorItem: chip
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: content
    contentWidth: fittedContentWidth(Style.space(360))
    contentHeight: fittedContentHeight(layout.implicitHeight, Style.space(620))

    FocusScope {
      id: content
      anchors.fill: parent
      Keys.onEscapePressed: root.close()

      Flickable {
        id: scroll
        anchors.fill: parent
        contentHeight: layout.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded }

        Column {
          id: layout
          width: parent.width
          spacing: Style.space(16)

          Column {
            width: parent.width
            spacing: Style.space(4)
            Text {
              textFormat: Text.PlainText
              text: "Omagic"
              color: root.foreground
              font.family: root.family
              font.pixelSize: Style.font.body * 1.5
              font.bold: true
            }
            Caption { text: "Your Magic devices, at home on Linux." }
          }

          Row {
            width: parent.width
            spacing: Style.space(6)
            Repeater {
              model: ["Devices", "Trackpad", "Gestures"]
              Ui.Button {
                required property string modelData
                width: (parent.width - Style.space(12)) / 3
                text: modelData
                selected: root.page === modelData
                bordered: true
                focusable: true
                fontFamily: root.family
                fontSize: Style.font.caption
                foreground: root.foreground
                onClicked: { root.page = modelData; scroll.contentY = 0 }
              }
            }
          }

          Caption {
            visible: root.busy || root.error !== ""
            text: root.error || root.activity
            color: root.error ? Color.urgent : root.muted
          }

          Column {
            visible: root.page === "Devices"
            width: parent.width
            spacing: Style.space(14)
            DeviceCard { kind: "keyboard"; title: "Magic Keyboard" }
            DeviceCard { kind: "trackpad"; title: "Magic Trackpad" }
            Ui.PanelSeparator { foreground: root.foreground }
            ToggleRow {
              label: "Media keys first"
              hint: "Hold Fn / Globe for F1–F12. Applies to Apple keyboards."
              checked: root.preferences.macFnKeys !== false
              enabled: !root.busy || root.settingsAction
              onToggled: root.setSetting("macFnKeys", !checked)
            }
            Caption { text: "Touch ID authentication is not supported." }
          }

          Caption {
            visible: root.page !== "Devices" && (root.managed || !root.trackpadPresent)
            text: root.managed ? "Trackpad Plus/Pulse is managing your trackpad. Disable it to use these controls."
                              : "Connect a Magic Trackpad to change these settings."
          }

          Column {
            visible: root.page === "Trackpad"
            width: parent.width
            spacing: Style.space(14)
            enabled: (!root.busy || root.settingsAction) && !root.managed && root.trackpadPresent
            opacity: enabled ? 1 : 0.45
            ToggleRow {
              label: "Tap to click"
              hint: "Tap with one finger for a primary click."
              checked: !!root.preferences.tapToClick
              onToggled: root.setSetting("tapToClick", !checked)
            }
            ToggleRow {
              label: "Two-finger secondary click"
              hint: checked ? "Click with two fingers to right-click." : "Click the bottom-right corner to right-click."
              checked: root.preferences.clickfinger !== false
              onToggled: root.setSetting("clickfinger", !checked)
            }
            ToggleRow {
              label: "Natural scrolling"
              hint: "Content follows your fingers. Also reverses workspace swipes."
              checked: !!root.preferences.naturalScroll
              onToggled: root.setSetting("naturalScroll", !checked)
            }
            SliderRow { label: "Tracking speed"; settingKey: "sensitivity"; minimum: -0.6; maximum: 0.6; fallback: 0 }
            SliderRow { label: "Scroll speed"; settingKey: "scrollFactor"; minimum: 0.15; maximum: 1.2; fallback: 0.4 }
            ToggleRow {
              label: "Ignore while typing"
              checked: root.preferences.disableWhileTyping !== false
              onToggled: root.setSetting("disableWhileTyping", !checked)
            }
          }

          Column {
            visible: root.page === "Gestures"
            width: parent.width
            spacing: Style.space(14)
            enabled: (!root.busy || root.settingsAction) && !root.managed && root.trackpadPresent
            opacity: enabled ? 1 : 0.45
            Repeater {
              model: [
                {key: "workspaceSwipe", label: "Switch workspaces", hint: root.preferences.drag3fg ? "Swipe horizontally with four fingers." : "Swipe horizontally with three fingers."},
                {key: "drag3fg", label: "Three-finger drag", hint: "Moves workspace swipes to four fingers."},
                {key: "pinchZoom", label: "Pinch to zoom", hint: "Two-finger pinch magnifies the desktop."},
                {key: "launchpad", label: "App launcher", hint: "Swipe up with four fingers."},
                {key: "notificationCenter", label: "Notification history", hint: root.preferences.drag3fg && root.preferences.workspaceSwipe ? "Unavailable while four-finger workspace swipes are on." : "Swipe right with four fingers."}
              ]
              ToggleRow {
                required property var modelData
                label: modelData.label
                hint: modelData.hint
                checked: !!root.preferences[modelData.key]
                enabled: modelData.key !== "notificationCenter" || !(root.preferences.drag3fg && root.preferences.workspaceSwipe)
                opacity: enabled ? 1 : 0.45
                onToggled: root.setSetting(modelData.key, !checked)
              }
            }
            Caption { text: "Gestures apply to all touchpads in Hyprland." }
          }

          Column {
            visible: root.page !== "Devices"
            width: parent.width
            spacing: Style.space(8)
            Ui.PanelSeparator { foreground: root.foreground }
            Caption { text: root.snapshot.profile && root.snapshot.profile.applied ? "Custom profile active · changes save automatically" : "System defaults active · saved preferences kept" }
            Row {
              width: parent.width
              spacing: Style.space(8)
              Ui.Button {
                width: (parent.width - parent.spacing) / 2
                text: "Apply saved"
                focusable: true
                bordered: true
                fontFamily: root.family
                fontSize: Style.font.caption
                foreground: root.foreground
                enabled: !root.saving && !root.managed && root.trackpadPresent
                onClicked: root.run(["apply-trackpad"], "Applying saved preferences…")
              }
              Ui.Button {
                width: (parent.width - parent.spacing) / 2
                text: "Use defaults"
                focusable: true
                bordered: true
                fontFamily: root.family
                fontSize: Style.font.caption
                foreground: root.foreground
                enabled: !root.saving && !!(root.snapshot.profile && root.snapshot.profile.applied)
                onClicked: root.run(["revert-trackpad"], "Restoring system defaults…")
              }
            }
          }
        }
      }
    }
  }

  component Caption: Text {
    textFormat: Text.PlainText
    width: parent.width
    color: root.muted
    font.family: root.family
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }

  component DeviceCard: Rectangle {
    id: card
    required property string kind
    required property string title
    readonly property var group: root.snapshot[kind]
    readonly property var device: Model.firstDevice(group)
    readonly property bool connected: !!(group && group.present)
    width: parent.width
    implicitHeight: cardBody.implicitHeight + Style.space(24)
    radius: Style.cornerRadius
    color: Qt.alpha(root.foreground, 0.035)
    border.color: Qt.alpha(root.foreground, 0.14)
    Column {
      id: cardBody
      x: Style.space(12)
      y: Style.space(12)
      width: parent.width - Style.space(24)
      spacing: Style.space(8)
      Text {
        textFormat: Text.PlainText
        text: card.title
        color: root.foreground
        font.family: root.family
        font.pixelSize: Style.font.body
        font.bold: true
      }
      Caption { text: card.connected ? Model.deviceLine(card.device) : "Not connected" }
      Ui.Button {
        width: parent.width
        text: card.connected ? "Connected" : "Connect"
        enabled: !root.saving && !card.connected
        focusable: true
        bordered: true
        fontFamily: root.family
        fontSize: Style.font.caption
        foreground: root.foreground
        onClicked: root.run(["setup-wireless", card.kind], "Searching for " + card.title + "…")
      }
      Caption {
        visible: !card.connected
        text: card.kind === "trackpad" ? "Power on, then tap the trackpad to wake it." : "Power on and make the keyboard discoverable."
      }
    }
  }

  component ToggleRow: FocusScope {
    id: row
    required property string label
    property string hint: ""
    required property bool checked
    signal toggled()
    width: parent.width
    implicitHeight: Math.max(labels.implicitHeight, toggle.implicitHeight) + Style.space(4)
    activeFocusOnTab: true
    Accessible.role: Accessible.CheckBox
    Accessible.name: label
    Accessible.description: hint
    Accessible.checked: checked
    Accessible.onPressAction: if (enabled) toggled()
    Keys.onSpacePressed: if (enabled) toggled()
    Keys.onReturnPressed: if (enabled) toggled()
    Rectangle {
      anchors.fill: parent
      anchors.margins: -Style.space(3)
      radius: Style.cornerRadius
      color: row.activeFocus || mouse.containsMouse ? Qt.alpha(root.foreground, 0.06) : "transparent"
    }
    Column {
      id: labels
      width: parent.width - toggle.width - Style.space(12)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(3)
      Text {
        textFormat: Text.PlainText
        width: parent.width
        text: row.label
        color: root.foreground
        font.family: root.family
        font.pixelSize: Style.font.body
        wrapMode: Text.WordWrap
      }
      Caption { visible: text !== ""; text: row.hint }
    }
    Ui.ToggleSwitch {
      id: toggle
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      checked: row.checked
      interactive: false
      foreground: root.foreground
    }
    MouseArea {
      id: mouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: { row.forceActiveFocus(); row.toggled() }
    }
  }

  component SliderRow: Column {
    id: sliderRow
    required property string label
    required property string settingKey
    required property real minimum
    required property real maximum
    required property real fallback
    width: parent.width
    spacing: Style.space(6)
    Caption { text: sliderRow.label + "  ·  " + slider.liveValue.toFixed(2); color: root.foreground }
    Ui.PanelSlider {
      id: slider
      width: parent.width
      bar: root.bar
      minimum: sliderRow.minimum
      maximum: sliderRow.maximum
      value: root.preferences[sliderRow.settingKey] === undefined ? sliderRow.fallback : root.preferences[sliderRow.settingKey]
      step: 0.05
      activeFocusOnTab: true
      Accessible.role: Accessible.Slider
      Accessible.name: sliderRow.label
      Keys.onLeftPressed: root.setSetting(sliderRow.settingKey, Math.max(minimum, Math.round((value - step) * 100) / 100))
      Keys.onRightPressed: root.setSetting(sliderRow.settingKey, Math.min(maximum, Math.round((value + step) * 100) / 100))
      onReleased: v => root.setSetting(sliderRow.settingKey, Math.round(v * 100) / 100)
    }
  }
}

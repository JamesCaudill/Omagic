"""Exercise real QML controls with a fake backend; requires Omarchy and Wayland."""
from pathlib import Path
import json, shutil
import os, subprocess, sys, tempfile
project = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(project))
import omagic_lib as om
temporary = tempfile.TemporaryDirectory(prefix="omagic-ui-smoke-")
root=Path(temporary.name)
for folder in ['Ui','Commons','Services','Components']:
 source=Path('/usr/share/omarchy/shell')/folder
 if source.exists() and not (root/folder).exists(): (root/folder).symlink_to(source)
for file in ['Panel.qml','WandIcon.qml','Model.js']: shutil.copy2(project/file, root/file)
p=root/'Panel.qml';s=p.read_text();pos=s.index('  implicitWidth:')
s=s[:pos]+'''  function testFind(label, toggle) {
    function walk(item) {
      if (toggle ? item.label === label && typeof item.toggled === "function"
                 : item.text === label && typeof item.clicked === "function") return item
      var children = item.children || []
      for (var i = 0; i < children.length; i++) {
        var found = walk(children[i])
        if (found) return found
      }
      return null
    }
    var found = walk(layout)
    if (!found) throw new Error("Missing control: " + label)
    if (!found.enabled) throw new Error("Disabled control: " + label)
    return found
  }
  function testClick(label) { testFind(label, false).clicked() }
  function testToggle(label) {
    var control = testFind(label, true)
    var before = control.checked
    control.toggled()
    if (control.checked === before) throw new Error("Toggle did not react instantly: " + label)
  }
  function testSlider(key, value) {
    function walk(item) {
      if (item.settingKey === key) {
        item.children[1].released(value)
        return true
      }
      var children = item.children || []
      for (var i = 0; i < children.length; i++) if (walk(children[i])) return true
      return false
    }
    if (!walk(layout)) throw new Error("Slider missing: " + key)
  }
''' +s[pos:];p.write_text(s)
fixture={'ok':True,'settings':om.DEFAULT_SETTINGS,'keyboard':{'present':False,'devices':[]},'trackpad':{'present':False,'devices':[]},'plugins':{},'profile':{'applied':False}}
(root/'fixture.json').write_text(json.dumps(fixture))
(root/'omagic.py').write_text('''import json, sys, time
from pathlib import Path
path=Path(__file__).with_name("fixture.json")
s=json.loads(path.read_text())
a=sys.argv[1:]
if a[0]=="state": print(json.dumps(s));sys.exit()
time.sleep(0.15)
if a[0]=="set-settings":
 patch=json.loads(a[1])
 if patch.get("sensitivity")==0.55:
  print(json.dumps({"ok":False,"error":"Simulated save failure"}));sys.exit(1)
 s["settings"].update(patch);s["profile"]["applied"]=True
elif a[0]=="setup-wireless":
 s[a[1]]={"present":True,"devices":[{"link":"Wireless","battery":85,"name":"Magic"}]}
elif a[0]=="apply-trackpad": s["profile"]["applied"]=True
elif a[0]=="revert-trackpad": s["profile"]["applied"]=False
path.write_text(json.dumps(s));print(json.dumps(s))
''')

(root/"shell.qml").write_text(r'''
import QtQuick
import Quickshell

ShellRoot {
  QtObject {
    id: theme
    property color foreground: "#eeeeee"
    property color barForeground: foreground
    property color background: "#111111"
    property color urgent: "#ff6666"
    property string fontFamily: "monospace"
    property bool vertical: false
    property bool foregroundAnimationEnabled: false
    property int barSize: 30
    property string position: "top"
    function hideTooltip(owner) {}
  }
  Panel { id: panel; bar: theme }
  Timer {
    property int phase: 0
    property int ticks: 0
    interval: 50
    running: true
    repeat: true
    onTriggered: {
      if (++ticks > 300) { console.error("UI_SMOKE_FAILED timeout at " + phase); Qt.quit(); return }
      if (panel.busy || Object.keys(panel.pending).length || !panel.snapshot.settings) return
      try {
        switch (phase) {
        case 0: panel.testClick("Connect"); break
        case 1:
          if (!panel.snapshot.keyboard.present) return
          panel.testClick("Connect"); break
        case 2:
          if (!panel.snapshot.trackpad.present) return
          panel.testToggle("Media keys first"); break
        case 3:
          if (panel.preferences.macFnKeys !== false) throw Error("Fn setting not saved")
          panel.testClick("Trackpad")
          panel.testToggle("Tap to click")
          panel.testToggle("Two-finger secondary click")
          panel.testToggle("Natural scrolling")
          panel.testToggle("Ignore while typing")
          panel.testSlider("sensitivity", 0.2)
          panel.testSlider("scrollFactor", 0.6)
          break
        case 4:
          if (!panel.preferences.tapToClick || panel.preferences.clickfinger || !panel.preferences.naturalScroll
              || panel.preferences.disableWhileTyping || panel.preferences.sensitivity !== 0.2
              || panel.preferences.scrollFactor !== 0.6) throw Error("Trackpad settings not saved")
          // Queue a second click while a process is already saving.
          panel.testToggle("Tap to click")
          panel.saveNext()
          panel.testToggle("Tap to click")
          panel.testToggle("Natural scrolling")
          break
        case 5:
          if (!panel.preferences.tapToClick || panel.preferences.naturalScroll) throw Error("Rapid clicks lost")
          panel.testClick("Gestures")
          panel.testToggle("Switch workspaces")
          panel.testToggle("Three-finger drag")
          panel.testToggle("Pinch to zoom")
          panel.testToggle("App launcher")
          panel.testToggle("Notification history")
          break
        case 6:
          if (panel.preferences.workspaceSwipe || !panel.preferences.drag3fg || !panel.preferences.pinchZoom
              || !panel.preferences.launchpad || !panel.preferences.notificationCenter) throw Error("Gesture settings not saved")
          panel.testClick("Use defaults"); break
        case 7:
          if (panel.snapshot.profile.applied) return
          panel.testClick("Apply saved"); break
        case 8:
          if (!panel.snapshot.profile.applied) return
          panel.testClick("Trackpad")
          panel.testSlider("sensitivity", 0.55)
          if (panel.preferences.sensitivity !== 0.55) throw Error("Slider not optimistic")
          break
        case 9:
          if (panel.preferences.sensitivity !== 0.2 || panel.error !== "Simulated save failure") throw Error("Failure did not revert")
          panel.testClick("Devices")
          console.log("UI_SMOKE_PASSED all buttons, toggles, sliders, rapid saves, and error rollback")
          Qt.quit(); return
        }
        phase++
      } catch (e) { console.error("UI_SMOKE_FAILED phase " + phase + ": " + e); Qt.quit() }
    }
  }
}
''')

result = subprocess.run(["quickshell", "-p", str(root)], capture_output=True, text=True, timeout=25)
output = result.stdout + result.stderr
print(output)
temporary.cleanup()
raise SystemExit(0 if "UI_SMOKE_PASSED" in output and "UI_SMOKE_FAILED" not in output else 1)

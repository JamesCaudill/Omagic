function firstDevice(group) {
  return group && group.devices && group.devices.length ? group.devices[0] : null
}

function deviceLine(device) {
  if (!device) return "Not connected"
  var battery = device.battery
  return (device.link || "Connected") + (battery === null || battery === undefined ? "" : " · " + battery + "%")
}

function heroStatus(snapshot) {
  var keyboard = snapshot.keyboard && snapshot.keyboard.present
  var trackpad = snapshot.trackpad && snapshot.trackpad.present
  return keyboard && trackpad ? "Keyboard + Trackpad" : keyboard ? "Keyboard" : trackpad ? "Trackpad" : "No devices"
}

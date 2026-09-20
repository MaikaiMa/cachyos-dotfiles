--!nonstrict

local state = {
  brightness = nil,
  outputVolume = nil,
  outputMuted = false,
  inputVolume = nil,
  inputMuted = false,
  batteryPercent = nil,
  batteryStatus = "",
  batterySeconds = nil,
  powerProfile = "",
  wifi = nil,
  bluetooth = nil,
  caffeine = nil,
  dnd = nil,
  wallpaper = nil,
  media = nil,
  system = nil,
}

local histories = {
  cpu = {},
  memory = {},
  gpu = {},
  network = {},
}
local previousSystem = nil

local stateRefreshInFlight = false
local sliderEditing = {
  brightness = false,
  output = false,
  input = false,
}

local function trim(value)
  return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function splitTabs(line)
  local fields = {}
  for field in (line .. "\t"):gmatch("(.-)\t") do
    table.insert(fields, field)
  end
  return fields
end

local function numberInRange(value, minimum, maximum)
  local parsed = tonumber(value)
  if parsed == nil then
    return nil
  end
  return math.max(minimum, math.min(maximum, parsed))
end

local function booleanStatus(value)
  if value == "on" then
    return true
  end
  if value == "off" then
    return false
  end
  return nil
end

local function percentage(value)
  if value == nil then
    return "—"
  end
  return string.format("%.0f%%", value)
end

local function pushSample(series, value)
  table.insert(series, math.max(0, math.min(1, value)))
  if #series > 30 then
    table.remove(series, 1)
  end
end

local function formatDuration(seconds)
  local value = math.max(0, math.floor(seconds or 0))
  return string.format("%d:%02d", math.floor(value / 60), value % 60)
end

local function formatRate(bytes)
  if bytes >= 1048576 then
    return string.format("%.1f MB/s", bytes / 1048576)
  end
  if bytes >= 1024 then
    return string.format("%.0f kB/s", bytes / 1024)
  end
  return string.format("%.0f B/s", bytes)
end

local function recordSystemSample(sample)
  if sample == nil then
    return
  end

  if previousSystem ~= nil and sample.timestamp <= previousSystem.timestamp then
    sample.cpu = previousSystem.cpu
    sample.network = previousSystem.network
    return
  end

  local cpu = 0
  local network = 0
  if previousSystem ~= nil and sample.timestamp > previousSystem.timestamp then
    local totalDelta = sample.cpuTotal - previousSystem.cpuTotal
    local idleDelta = sample.cpuIdle - previousSystem.cpuIdle
    if totalDelta > 0 then
      cpu = (totalDelta - idleDelta) / totalDelta
    end

    local seconds = sample.timestamp - previousSystem.timestamp
    network = math.max(0, (sample.rxBytes - previousSystem.rxBytes + sample.txBytes - previousSystem.txBytes) / seconds)
  end

  sample.cpu = cpu * 100
  sample.network = network
  pushSample(histories.cpu, cpu)
  pushSample(histories.memory, sample.memory / 100)
  pushSample(histories.gpu, math.max(0, sample.gpu) / 100)

  local networkPeak = math.max(network, 1024)
  for _, value in ipairs(histories.network) do
    networkPeak = math.max(networkPeak, value)
  end
  table.insert(histories.network, network)
  if #histories.network > 30 then
    table.remove(histories.network, 1)
  end
  sample.networkPeak = networkPeak
  previousSystem = sample
end

local function batteryStatusLabel(status)
  if status == "Charging" then
    return "Opladen"
  end
  if status == "Full" then
    return "Vol"
  end
  if status == "Not charging" then
    return "Netstroom"
  end
  if status == "Discharging" then
    return "Op batterij"
  end
  return status
end

local function remainingTime(seconds)
  if seconds == nil or seconds <= 0 then
    return ""
  end

  local hours = math.floor(seconds / 3600)
  local minutes = math.floor((seconds % 3600) / 60)
  if hours > 0 then
    return string.format("%d u %02d min resterend", hours, minutes)
  end
  return string.format("%d min resterend", minutes)
end

local function runNoctalia(arguments, action, callback)
  local command = { "noctalia", "msg" }
  for _, argument in ipairs(arguments) do
    table.insert(command, argument)
  end

  noctalia.runAsync(command, function(result)
    if result.exitCode ~= 0 then
      noctalia.notifyError("Dashboard", action .. " is mislukt.")
    end
    if callback ~= nil then
      callback(result.exitCode == 0)
    end
  end)
end

local function openNoctalia(arguments, action)
  panel.close()
  runNoctalia(arguments, action, nil)
end

local function parseState(raw)
  local nextState = {
    brightness = nil,
    outputVolume = nil,
    outputMuted = false,
    inputVolume = nil,
    inputMuted = false,
    batteryPercent = nil,
    batteryStatus = "",
    batterySeconds = nil,
    powerProfile = "",
    wifi = nil,
    bluetooth = nil,
    caffeine = nil,
    dnd = nil,
    wallpaper = nil,
    media = nil,
    system = nil,
  }

  for line in raw:gmatch("[^\r\n]+") do
    local fields = splitTabs(line)
    local kind = fields[1]
    if kind == "brightness" then
      nextState.brightness = numberInRange(fields[2], 0, 100)
    elseif kind == "output" then
      nextState.outputVolume = numberInRange(fields[2], 0, 150)
      nextState.outputMuted = fields[3] == "true"
    elseif kind == "input" then
      nextState.inputVolume = numberInRange(fields[2], 0, 150)
      nextState.inputMuted = fields[3] == "true"
    elseif kind == "battery" then
      nextState.batteryPercent = numberInRange(fields[2], 0, 100)
      nextState.batteryStatus = fields[3] or ""
      nextState.batterySeconds = tonumber(fields[4])
    elseif kind == "power" then
      nextState.powerProfile = fields[2] or ""
    elseif kind == "wifi" then
      nextState.wifi = booleanStatus(fields[2])
    elseif kind == "bluetooth" then
      nextState.bluetooth = booleanStatus(fields[2])
    elseif kind == "caffeine" then
      nextState.caffeine = booleanStatus(fields[2])
    elseif kind == "dnd" then
      nextState.dnd = booleanStatus(fields[2])
    elseif kind == "wallpaper" then
      nextState.wallpaper = fields[2]
    elseif kind == "media" and fields[3] ~= nil and fields[3] ~= "" then
      nextState.media = {
        status = fields[2],
        title = fields[3],
        artist = fields[4] or "",
        player = fields[5] or "",
        position = tonumber(fields[6]) or 0,
        length = tonumber(fields[7]) or 0,
      }
    elseif kind == "system" then
      nextState.system = {
        cpuTotal = tonumber(fields[2]) or 0,
        cpuIdle = tonumber(fields[3]) or 0,
        memory = tonumber(fields[4]) or 0,
        gpu = tonumber(fields[5]) or -1,
        rxBytes = tonumber(fields[6]) or 0,
        txBytes = tonumber(fields[7]) or 0,
        timestamp = tonumber(fields[8]) or 0,
      }
    end
  end

  if sliderEditing.brightness then
    nextState.brightness = state.brightness
  end
  if sliderEditing.output then
    nextState.outputVolume = state.outputVolume
  end
  if sliderEditing.input then
    nextState.inputVolume = state.inputVolume
  end
  recordSystemSample(nextState.system)
  state = nextState
end

local function refreshState()
  if stateRefreshInFlight then
    return
  end

  stateRefreshInFlight = true
  noctalia.runAsync({ "noctalia-dashboard-state" }, function(result)
    stateRefreshInFlight = false
    if result.exitCode == 0 then
      parseState(result.stdout)
      render()
    else
      noctalia.log("dashboard state refresh failed: " .. trim(result.stderr))
    end
  end)
end

local function iconButton(glyph, tooltip, callback, enabled)
  return ui.button({
    glyph = glyph,
    tooltip = tooltip,
    controlSize = "sm",
    width = 38,
    enabled = enabled ~= false,
    onClick = callback,
  })
end

local function sliderControl(title, glyph, value, muted, changeCallback, dragEndCallback, muteCallback)
  local displayValue = percentage(value)
  if muted then
    displayValue = "Gedempt"
  end

  local headerChildren = {
    ui.glyph({ name = glyph, size = 18, color = "primary" }),
    ui.label({ text = title, fontWeight = "bold", flexGrow = 1 }),
    ui.label({ text = displayValue, color = muted and "error" or "on_surface_variant" }),
  }
  if muteCallback ~= nil then
    table.insert(headerChildren, iconButton(muted and "volume-off" or glyph, title .. " dempen", muteCallback))
  end

  return ui.column({
    gap = 7,
    flexGrow = 1,
  }, {
    ui.row({ gap = 8, align = "center" }, headerChildren),
    ui.slider({
      min = 0,
      max = 100,
      step = 1,
      value = math.min(value or 0, 100),
      enabled = value ~= nil,
      onChange = changeCallback,
      onDragEnd = dragEndCallback,
    }),
  })
end

local function quickTile(glyph, label, active, callback)
  return ui.column({
    gap = 2,
    width = 0,
    flexGrow = 1,
    height = 64,
    align = "center",
    justify = "center",
    fill = active and "primary" or "surface_variant/0.46",
    radius = 12,
    border = active and "primary" or "outline/0.42",
    borderWidth = 1,
    onClick = callback,
  }, {
    ui.glyph({ name = glyph, size = 18, color = active and "on_primary" or "on_surface" }),
    ui.label({ text = label, fontSize = 11, color = active and "on_primary" or "on_surface_variant" }),
  })
end

local function quickControls()
  local controls = {}
  local wallpaper = state.wallpaper
  if wallpaper ~= nil and wallpaper ~= "" and wallpaper:sub(1, 6) ~= "color:" then
    table.insert(controls, ui.image({
      path = wallpaper,
      width = 0,
      flexGrow = 1,
      height = 64,
      radius = 12,
      fit = "cover",
      border = "outline/0.50",
      borderWidth = 1,
      onClick = "onWallpaperClicked",
    }))
  else
    table.insert(controls, quickTile("photo", "Achtergrond", false, "onWallpaperClicked"))
  end

  if state.wifi ~= nil then
    table.insert(controls, quickTile("wifi", "Wifi", state.wifi, "onWifiClicked"))
  end
  if state.bluetooth ~= nil then
    table.insert(controls, quickTile("bluetooth", "Bluetooth", state.bluetooth, "onBluetoothClicked"))
  end
  if state.caffeine ~= nil then
    table.insert(controls, quickTile("coffee", "Caffeine", state.caffeine, "onCaffeineClicked"))
  end
  if state.dnd ~= nil then
    table.insert(controls, quickTile("bell-off", "Niet storen", state.dnd, "onDndClicked"))
  end

  return ui.row({ gap = 10, align = "stretch" }, controls)
end

local function mediaCard()
  local available = state.media ~= nil
  local media = state.media or {
    status = "Stopped",
    title = "Geen media actief",
    artist = "Start muziek om de bediening te gebruiken",
    position = 0,
    length = 0,
  }
  local progress = 0
  if media.length > 0 then
    progress = math.max(0, math.min(1, media.position / media.length))
  end

  return ui.column({
    gap = 8,
    padding = 11,
    fill = "surface_variant/0.52",
    radius = 16,
    border = "outline/0.45",
    borderWidth = 1,
  }, {
    ui.row({ gap = 12, align = "center" }, {
      ui.column({
        width = 66,
        height = 66,
        align = "center",
        justify = "center",
        fill = "primary/0.14",
        radius = 11,
      }, {
        ui.glyph({ name = "music", size = 27, color = "primary" }),
      }),
      ui.column({ gap = 3, flexGrow = 1 }, {
        ui.label({ text = media.title, fontWeight = "bold", fontSize = 16, maxLines = 1 }),
        ui.label({
          text = media.artist ~= "" and media.artist or "Onbekende artiest",
          color = "on_surface_variant",
          maxLines = 1,
        }),
      }),
      iconButton("player-skip-back", "Vorige", "onMediaPrevious", available),
      iconButton(media.status == "Playing" and "player-pause" or "player-play", "Afspelen of pauzeren", "onMediaToggle", available),
      iconButton("player-skip-forward", "Volgende", "onMediaNext", available),
    }),
    ui.row({ gap = 7, align = "center" }, {
      ui.label({ text = formatDuration(media.position), fontSize = 10, color = "on_surface_variant" }),
      ui.progress({ progress = progress, height = 5, fill = "primary", track = "outline/0.30", flexGrow = 1 }),
      ui.label({ text = formatDuration(media.length), fontSize = 10, color = "on_surface_variant" }),
    }),
  })
end

local function profileButton(text, glyph, profile)
  local active = state.powerProfile == profile
  return ui.button({
    text = text,
    glyph = glyph,
    variant = active and "primary" or "default",
    selected = active,
    controlSize = "md",
    flexGrow = 1,
    onClick = function() onPowerProfile(profile) end,
  })
end

local function controlsCard()
  return ui.column({
    gap = 8,
    padding = 12,
    fill = "surface_variant/0.42",
    radius = 14,
    border = "outline/0.42",
    borderWidth = 1,
  }, {
    ui.label({ text = "Display & audio", fontWeight = "bold", fontSize = 15 }),
    sliderControl(
      "Brightness",
      "sun",
      state.brightness,
      false,
      "onBrightnessChanged",
      "onBrightnessCommitted",
      nil
    ),
    ui.separator({ spacing = 0, color = "outline/0.28" }),
    ui.row({ gap = 18, align = "stretch" }, {
      sliderControl(
        "Output",
        "volume",
        state.outputVolume,
        state.outputMuted,
        "onOutputChanged",
        "onOutputCommitted",
        "onOutputMute"
      ),
      sliderControl(
        "Input",
        "microphone",
        state.inputVolume,
        state.inputMuted,
        "onInputChanged",
        "onInputCommitted",
        "onInputMute"
      ),
    }),
  })
end

local function powerCard()
  if state.batteryPercent == nil and state.powerProfile == "" then
    return nil
  end

  local children = {
    ui.label({ text = "Power", fontWeight = "bold", fontSize = 15 }),
  }
  if state.batteryPercent ~= nil then
    table.insert(children, ui.row({ gap = 9, align = "center" }, {
      ui.glyph({ name = "battery", size = 19, color = "primary" }),
      ui.label({ text = percentage(state.batteryPercent), fontWeight = "bold" }),
      ui.label({ text = batteryStatusLabel(state.batteryStatus), color = "on_surface_variant" }),
      ui.label({ text = remainingTime(state.batterySeconds), color = "on_surface_variant", flexGrow = 1, textAlign = "end" }),
    }))
    table.insert(children, ui.progress({
      progress = state.batteryPercent / 100,
      height = 7,
      fill = state.batteryPercent <= 15 and "error" or "primary",
      track = "outline/0.30",
    }))
  end
  if state.powerProfile ~= "" then
    table.insert(children, ui.row({ gap = 8, align = "center" }, {
      profileButton("Power Saver", "leaf", "power-saver"),
      profileButton("Balanced", "scale", "balanced"),
      profileButton("Performance", "gauge", "performance"),
    }))
  end

  return ui.column({
    gap = 7,
    padding = 12,
    fill = "surface_variant/0.42",
    radius = 14,
    border = "outline/0.42",
    borderWidth = 1,
  }, children)
end

local function normalizedNetworkHistory()
  local normalized = {}
  local peak = 1024
  for _, value in ipairs(histories.network) do
    peak = math.max(peak, value)
  end
  for _, value in ipairs(histories.network) do
    table.insert(normalized, value / peak)
  end
  return normalized
end

local function systemCard(title, value, values, color)
  return ui.column({
    gap = 3,
    padding = 9,
    fill = "surface_variant/0.38",
    radius = 12,
    border = "outline/0.38",
    borderWidth = 1,
    flexGrow = 1,
  }, {
    ui.row({ gap = 6, align = "center" }, {
      ui.label({ text = title, fontWeight = "bold", flexGrow = 1 }),
      ui.label({ text = value, fontSize = 11, color = "on_surface_variant" }),
    }),
    ui.graph({ values = values, color = color, lineWidth = 2, fillOpacity = 0.10, height = 29, flexGrow = 1 }),
  })
end

local function systemCards()
  local system = state.system
  if system == nil then
    return nil
  end
  local gpuValue = system.gpu >= 0 and percentage(system.gpu) or "—"
  return ui.row({ gap = 8, align = "stretch" }, {
    systemCard("CPU", percentage(system.cpu), histories.cpu, "primary"),
    systemCard("Memory", percentage(system.memory), histories.memory, "tertiary"),
    systemCard("GPU", gpuValue, histories.gpu, "secondary"),
    systemCard("Network", formatRate(system.network or 0), normalizedNetworkHistory(), "primary"),
  })
end

function render()
  local header = ui.row({ align = "center", gap = 8 }, {
    ui.label({
      text = "Dashboard",
      fontSize = 20,
      fontWeight = "bold",
      color = "on_surface",
      flexGrow = 1,
    }),
    iconButton("home", "Originele Home", "onOpenHome"),
    iconButton("bell", "Notificaties", "onOpenNotifications"),
    iconButton("settings", "Noctalia-instellingen", "onOpenSettings"),
    iconButton("x", "Sluiten", "onCloseClicked"),
  })
  local content = {}

  table.insert(content, quickControls())
  table.insert(content, mediaCard())
  table.insert(content, controlsCard())

  local power = powerCard()
  if power ~= nil then
    table.insert(content, power)
  end

  local systems = systemCards()
  if systems ~= nil then
    table.insert(content, systems)
  end

  panel.render(ui.column({ flexGrow = 1, gap = 12 }, {
    header,
    ui.scroll({ flexGrow = 1, gap = 8 }, content),
  }))
end

function onOpen(_context)
  panel.setWantsSecondTicks(true)
  render()
  refreshState()
end

function update()
  refreshState()
end

function onOpenHome()
  openNoctalia({ "panel-open", "control-center", "home" }, "Het Control Center")
end

function onOpenNotifications()
  openNoctalia({ "panel-open", "control-center", "notifications" }, "Notificaties")
end

function onOpenSettings()
  openNoctalia({ "settings-open" }, "De instellingen")
end

function onWallpaperClicked()
  openNoctalia({ "panel-open", "wallpaper" }, "De achtergrondkiezer")
end

function onCloseClicked()
  panel.close()
end

function onBrightnessChanged(value)
  local parsed = numberInRange(value, 0, 100)
  if parsed == nil then
    return
  end
  state.brightness = parsed
  sliderEditing.brightness = true
  render()
end

function onBrightnessCommitted()
  sliderEditing.brightness = false
  runNoctalia(
    { "brightness-set", "current", tostring(math.floor((state.brightness or 0) + 0.5)) },
    "Brightness aanpassen",
    refreshState
  )
end

function onOutputChanged(value)
  local parsed = numberInRange(value, 0, 100)
  if parsed == nil then
    return
  end
  state.outputVolume = parsed
  sliderEditing.output = true
  render()
end

function onOutputCommitted()
  sliderEditing.output = false
  runNoctalia(
    { "volume-set", tostring(math.floor((state.outputVolume or 0) + 0.5)) },
    "Outputvolume aanpassen",
    refreshState
  )
end

function onInputChanged(value)
  local parsed = numberInRange(value, 0, 100)
  if parsed == nil then
    return
  end
  state.inputVolume = parsed
  sliderEditing.input = true
  render()
end

function onInputCommitted()
  sliderEditing.input = false
  runNoctalia(
    { "mic-volume-set", tostring(math.floor((state.inputVolume or 0) + 0.5)) },
    "Inputvolume aanpassen",
    refreshState
  )
end

function onOutputMute()
  state.outputMuted = not state.outputMuted
  render()
  runNoctalia({ "volume-mute" }, "Output dempen", refreshState)
end

function onInputMute()
  state.inputMuted = not state.inputMuted
  render()
  runNoctalia({ "mic-mute" }, "Input dempen", refreshState)
end

local function setToggle(field, enabled, onCommand, offCommand, action)
  state[field] = enabled
  render()
  runNoctalia({ enabled and onCommand or offCommand }, action, refreshState)
end

function onBluetoothClicked()
  setToggle("bluetooth", not state.bluetooth, "bluetooth-enable", "bluetooth-disable", "Bluetooth aanpassen")
end

function onWifiClicked()
  setToggle("wifi", not state.wifi, "wifi-enable", "wifi-disable", "Wifi aanpassen")
end

function onCaffeineClicked()
  setToggle("caffeine", not state.caffeine, "caffeine-enable", "caffeine-disable", "Caffeine aanpassen")
end

function onDndClicked()
  local enabled = not state.dnd
  state.dnd = enabled
  render()
  runNoctalia({ "notification-dnd-set", enabled and "on" or "off" }, "Niet storen aanpassen", refreshState)
end

function onPowerProfile(profile)
  state.powerProfile = profile
  render()
  runNoctalia({ "power-set", profile }, "Energieprofiel aanpassen", refreshState)
end

local function runPlayerctl(action)
  if state.media == nil or state.media.player == "" then
    return
  end
  noctalia.runAsync({ "playerctl", "--player", state.media.player, action }, function(result)
    if result.exitCode ~= 0 then
      noctalia.notifyError("Dashboard", "Mediabediening is mislukt.")
    end
    refreshState()
  end)
end

function onMediaPrevious()
  runPlayerctl("previous")
end

function onMediaToggle()
  runPlayerctl("play-pause")
end

function onMediaNext()
  runPlayerctl("next")
end

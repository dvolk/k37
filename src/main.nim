import strformat
import sugar
import sequtils
import tables
import random
import times

import nico
import nico/vec

{.this:self.}

type
  MapObj = ref object of RootObj
    name: string
    # m, m/s, kg
    pos: Vec2f
    vel: Vec2f
    mass: float

  Widget = ref object of RootObj
    x: int
    y: int
    w: int
    h: int

  Gui = ref object of RootObj
    widgets: seq[Widget]
    sub_gui: Gui

  Button = ref object of Widget
    label: string
    hovered: bool
    active: bool
    press_cb: Button -> void

  PanelLabelKind = enum
    kind_string
    kind_float

  PanelLabel = ref object of Widget
    kind: PanelLabelKind
    label: string
    tbl_ref: string
    unit: string

  TimeCtrl = ref object of Widget

  Map = ref object of Widget
    view: Vec2f
    scale: int
    objs: seq[MapObj]
    stars: seq[Vec2i]

var
  frame_t: int
  game_t: int # game seconds
  accel: int
  map: Map
  sel: MapObj
  tgt: MapObj
  main_gui: Gui
  current_gui: Gui
  sub_guis: Table[string, Gui]
  gui_floats: Table[string, float]
  gui_strings: Table[string, string]
  top_buttons: seq[Button]

# --- widget ---

method draw(self: Widget) {.base.} = discard
method update(self: Widget) {.base.} = discard
method onMouseUp(self: Widget) {.base.} = discard
method onMouseDown(self: Widget) {.base.} = discard
method onKeydown(self: Widget) {.base.} = discard
method onHoverOver(self: Widget) {.base.} = discard

# --- gui ---

proc newGui(): Gui =
  result = new(Gui)
  result.widgets = newSeq[Widget]()

method draw(self: Gui) {.base.} =
  for w in widgets:
    w.draw()

method update(self: Gui) {.base.} =
  for w in widgets:
    w.update()

method mouseDownEvent(self: Gui) =
  let (mx, my) = mouse()
  for w in widgets:
    if w.x <= mx and w.y <= my and w.x + w.w >= mx and w.y + w.h >= my:
      w.onMouseDown()
      break

proc findHoveredWidget(self: Gui): Widget =
  let (mx, my) = mouse()
  for w in widgets:
    if w.x <= mx and w.y <= my and w.x + w.w >= mx and w.y + w.h >= my:
      return w
  return nil

# --- button ---

proc newButton(x, y, w, h: int, label: string, cb: Button -> void): Button =
  result = new(Button)
  result.x = x
  result.y = y
  result.w = w
  result.h = h
  result.label = label
  result.press_cb = cb

method onMouseDown(self: Button) =
  press_cb(self)
  echo &"clicked on {label}"

method onHoverOver(self: Button) =
  hovered = true

method draw(self: Button) =
  if active:
    setColor(19)
  else:
    setColor(1)
  boxfill(x, y, w, h)
  setColor(11)
  printc(label, x + w div 2, y + 2)
  if hovered:
    setColor(3)
    box(x, y, w, h)

  hovered = false

# --- panel label ---

proc newPanelLabel(x, y, w, h: int, label: string,
                   tbl_ref: string, unit: string, kind: PanelLabelKind): PanelLabel =
  result = new(PanelLabel)
  result.x = x
  result.y = y
  result.w = w
  result.h = h
  result.label = label
  result.tbl_ref = tbl_ref
  result.unit = unit
  result.kind = kind

method draw(self: PanelLabel) =
  setColor(6)
  print(label, x + 2, y + 2)
  setColor(5)
  boxfill(x + 15, y, w, h)
  setColor(10)
  if kind == kind_float:
    print(&"{int(gui_floats[tbl_ref])}{unit}", x + 17, y + 2)
  if kind == kind_string:
    print(gui_strings[tbl_ref], x + 17, y + 2)

# --- time control widget ---

proc offsetAccel(cur, offset: int): int =
  const accels = @[0, 1, 2, 5, 10, 100, 1000]
  for i, acc in accels:
    if cur == acc and i == 0 and offset < 0:
      return 0
    if cur == acc and i == (accels.len - 1) and offset > 0:
      return cur
    if cur == acc:
      return accels[i + offset]

proc newTimeCtrl(x, y, w, h: int): TimeCtrl =
  result = new(TimeCtrl)
  result.x = x
  result.y = y
  result.w = w
  result.h = h

method draw(self: TimeCtrl) =
  # show controls
  setColor(5)
  boxfill(x, y, w, h)
  setColor(6)
  print(&"{accel}x", x + 2, y + 2)
  print("<< >>", x + 26, y + 2)
  # show current time
  boxfill(x, y - 10, w, h)
  setColor(5)
  let t = fromUnix(1603192756 + 2003192756 + (game_t div 60))
  print(format(t, "YYYY-MM-dd hh:mm:ss"), x + 2, y - 8)

method onMouseDown(self: TimeCtrl) =
  let (mx, my) = mouse()
  if mx > x and my > y and mx < x + 20 and my < y + 10:
    accel = 0
    echo "accel = 0"
  if mx - x > 26 and my - y > 0 and mx - x < 36 and my - y < 10:
    accel = offsetAccel(accel, -1)
    echo "less accel"
  if mx - x > 36 and my - y > 0 and mx - x < 48 and my - y < 10:
    accel = offsetAccel(accel,  1)
    echo "more accel"

  echo &"clicked on time control at {mx-x}, {my-y}"

# --- mapobj ---

proc newMapObj(x, y, vx, vy: int, name: string): MapObj =
  result = new(MapObj)
  result.pos = vec2f(float(x), float(y))
  result.vel = vec2f(float(vx), float(vy))
  result.mass = 1000
  result.name = name

proc draw(self: MapObj) =
  let
    x = (pos.x - map.view.x) div map.scale
    y = (pos.y - map.view.y) div map.scale
    norm_vel = 10 * vel.normalized()
  if accel > 0 and (game_t div 10) mod 9 == 0:
    setColor(5)
    line(x, y, x + norm_vel.x, y + norm_vel.y)
    circ(x, y, 5)
    return
  if self == sel:
    setColor(11) # player
    line(x, y, x + norm_vel.x, y + norm_vel.y)
    circ(x, y, 5)
  elif self == tgt:
    setColor(8) # target
    line(x, y, x + norm_vel.x, y + norm_vel.y)
    circ(x, y, 5)
    let dist = ((sel.pos - pos).length() / 1000).int
    let rvel = gui_floats["tgt_rel_spd"]
    print(&"{dist}km", x + 8, y + 1)
    print(&"{int(rvel)}m/s", x + 8, y - 5)
  else:
    setColor(6) # other
    line(x, y, x + norm_vel.x, y + norm_vel.y)
    circ(x, y, 5)

# --- map ---

proc newMap(): Map =
  result = new(Map)
  result.x = 0
  result.y = 10
  result.h = 100
  result.w = 128
  result.scale = 1000
  result.objs = @[]
  result.view = vec2f(-64000, -64000)
  for i in 0..32:
    result.stars.add(vec2i(rand(128), rand(128)))

method draw(self: Map) =
  setColor(1) # grid
  for x in 0..8:
    line(16 * x, 0, 16 * x, 128)
  for y in 1..7:
    line(0, 16 * y, 128, 16 * y)
  for star in stars:
    pset(star.x, star.y, 22)
  for obj in objs:
    obj.draw()

method onMouseDown(self: Map) =
  echo "clicked on map"
  let (mx, my) = mouse()
  for obj in objs:
    if obj == sel:
      continue
    let
      x = (obj.pos.x - map.view.x) div map.scale
      y = (obj.pos.y - map.view.y) div map.scale
    if (vec2i(x, y) - vec2i(mx, my)).length() < 5:
      tgt = obj
      echo &"clicked on {tgt.name}"
      break

method onHoverOver(self: Map) =
  if btn(pcLeft):
    view.x -= (3 * scale).float
  if btn(pcRight):
    view.x += (3 * scale).float
  if btn(pcUp):
    view.y -= (3 * scale).float
  if btn(pcDown):
    view.y += (3 * scale).float
  if btnp(pcA):
    view += 32 * scale.float
    scale = scale div 2
    echo &"scale = {scale} view = {view}"
  if btnp(pcB):
    view -= 64 * scale.float
    scale *= 2
    echo &"scale = {scale} view = {view}"

# --- setup ---

proc switch_gui_btn_cb(btn: Button) =
  main_gui.sub_gui = sub_guis[btn.label]
  for btn in top_buttons:
    btn.active = false
  btn.active = true

proc gameInit =
  # game
  frame_t = 0
  game_t = 0
  accel = 0 # time acceleration
  map = newMap()
  for i in 0..10:
    let
      name = &"X-{1000+rand(8999)}"
      vel_x = -100 + rand(200)
      vel_y = -100 + rand(200)
    map.objs.add(newMapObj(64000 - rand(128000), 64000 - rand(128000),
                           vel_x, vel_y, name))

  sel = map.objs[0]
  tgt = map.objs[1]
  sel.vel = vec2f(-100, 0)

  # gui
  main_gui = newGui()
  # add common elements
  top_buttons = @[newButton(0, 0, 16, 10, "NAV", switch_gui_btn_cb),
                  newButton(20, 0, 16, 10, "TGT", switch_gui_btn_cb),
                  newButton(60, 0, 16, 10, "CRW", switch_gui_btn_cb),
                  newButton(40, 0, 16, 10, "COM", switch_gui_btn_cb),
                  newButton(80, 0, 16, 10, "ENG", switch_gui_btn_cb),
                  newButton(100, 0, 16, 10, "CBT", switch_gui_btn_cb)]
  for btn in top_buttons:
    main_gui.widgets.add(btn)
  top_buttons[0].active = true
  main_gui.widgets.add(newTimeCtrl(49, 118, 79, 10))

  var
    nav_sub_gui = newGui()
    tgt_sub_gui = newGui()
    crw_sub_gui = newGui()
    com_sub_gui = newGui()
    eng_sub_gui = newGui()
    cbt_sub_gui = newGui()

  nav_sub_gui.widgets.add(map)
  tgt_sub_gui.widgets.add(newPanelLabel(0, 12, 30, 10, "NAM", "tgt_name", "", kind_string))
  tgt_sub_gui.widgets.add(newPanelLabel(0, 24, 30, 10, "VEL", "tgt_rel_spd", "m/s", kind_float))
  tgt_sub_gui.widgets.add(newPanelLabel(0, 36, 30, 10, "DST", "tgt_dst_km", "km", kind_float))

  sub_guis = { "NAV": nav_sub_gui,
               "TGT": tgt_sub_gui,
               "CRW": crw_sub_gui,
               "COM": com_sub_gui,
               "ENG": eng_sub_gui,
               "CBT": cbt_sub_gui }.toTable

  current_gui = main_gui
  current_gui.sub_gui = sub_guis["NAV"]

# --- simulation ---

proc simulate(dt: float32) =
  let factor = float(accel) * dt

  for mapobj in map.objs:
    mapobj.pos += mapobj.vel * factor

  var
    tgt_spd_ms = (tgt.vel - sel.vel).length()
    tgt_dst_ms = (sel.pos - tgt.pos).length()
    tgt_dst_ms2 = ((sel.pos + sel.vel.normalized()) - (tgt.pos + tgt.vel.normalized())).length()

  if tgt_dst_ms - tgt_dst_ms2 < 0:
    tgt_spd_ms = -tgt_spd_ms

  gui_floats["tgt_rel_spd"] = tgt_spd_ms
  gui_floats["tgt_dst_km"] = tgt_dst_ms / 1000
  gui_strings["tgt_name"] = tgt.name

  if frame_t mod 120 == 0:
    echo &"game_t={game_t} sel.pos={sel.pos} sel.vel={sel.vel} tgt.pos={tgt.pos} tgt.vel={tgt.vel} {tgt_dst_ms - tgt_dst_ms2}"


# --- nico callbacks ---

proc gameUpdate(dt: float32) =
  let (x, y) = mouse()
  if mousebtnp(0):
    current_gui.mouseDownEvent()
    current_gui.sub_gui.mouseDownEvent()
  let w = current_gui.findHoveredWidget()
  if w != nil:
    w.onHoverOver()
  else:
    let w = current_gui.sub_gui.findHoveredWidget()
    if w != nil:
      w.onHoverOver()
  current_gui.update()
  current_gui.sub_gui.update()
  frame_t = frame_t + 1
  game_t = game_t + accel
  simulate(dt)

proc gameDraw =
  cls()
  current_gui.sub_gui.draw()
  current_gui.draw()

# --- main ---

when isMainModule:
  nico.init("com.oxfordfun", "kelvin27")
  fixedSize(true)
  integerScale(false)
  setPalette(loadPalettePico8Extra())
  nico.createWindow("myApp", 128, 128, 4, false)
  nico.run(gameInit, gameUpdate, gameDraw)

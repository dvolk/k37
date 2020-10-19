import strformat
import sugar
import sequtils
import tables

import nico
import nico/vec

{.this:self.}

type
  Widget = ref object of RootObj
    x: int
    y: int
    w: int
    h: int

  Gui = ref object of RootObj
    widgets: seq[Widget]

  Button = ref object of Widget
    label: string

  PanelLabel = ref object of Widget
    label: string
    val: ref float
    unit: string

  TimeCtrl = ref object of Widget

  MapObj = ref object of RootObj
    # m, m/s, kg
    pos: Vec2f
    vel: Vec2f
    mass: float

  Ship = ref object of MapObj

  Map = object
    objs: seq[MapObj]

var
  frame_t: int
  game_t: int # game seconds
  accel: int
  map: Map
  sel: int
  tgt: int
  main_gui: Gui
  current_gui: Gui

# --- GameData ---

proc initGameData =
  frame_t = 0
  game_t = 0
  accel = 0 # time acceleration

# --- widget ---
    
method draw(self: Widget) {.base.} = discard
method update(self: Widget) {.base.} = discard
method onMouseUp(self: Widget) {.base.} = discard
method onMouseDown(self: Widget) {.base.} = discard
method onKeydown(self: Widget) {.base.} = discard
method hoverOver(self: Widget) {.base.} = discard

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

# --- button ---
      
proc newButton(x, y, w, h: int, label: string): Button =
  result = new(Button)
  result.x = x
  result.y = y
  result.w = w
  result.h = h
  result.label = label

method onMouseDown(self: Button) =
  echo &"clicked on {label}"

method draw(self: Button) =
  setColor(1)
  boxfill(x, y, w, h)
  setColor(11)
  printc(label, x + w div 2, y + 2)

# --- panel label ---

proc newPanelLabel(x, y, w, h: int, label: string, val: ref float, unit: string): PanelLabel =
  result = new(PanelLabel)
  result.x = x
  result.y = y
  result.w = w
  result.h = h
  result.label = label
  result.val = val
  result.unit = unit

method draw(self: PanelLabel) =
  setColor(6)
  print(label, x + 2, y + 2)
  setColor(5)
  boxfill(x + 15, y, w, h)
  setColor(10)
  print(&"{int(val[])}{unit}", x + 17, y + 2)
  
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
  print(&"{game_t div 60}", x + 2, y - 8)

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

proc newMapObj(x, y, vx, vy: int): MapObj =
  result = new(MapObj)
  result.pos = vec2f(float(x), float(y))
  result.vel = vec2f(float(vx), float(vy))
  result.mass = 1000

proc draw(self: MapObj) =
  let
    dx = pos.x div map.scale - map.view.x + (64 * map.scale)
    dy = pos.y div map.scale - map.view.y + (64 * map.scale)
    norm_vel = 10 * vel.normalized()
  if accel > 0 and (game_t div 10) mod 9 == 0:
    setColor(5)
    circ(dx, dy, 5)
    return
  if self == sel:
    setColor(11) # player
    line(dx, dy, dx + norm_vel.x, dy + norm_vel.y)
    circ(dx, dy, 5)
  elif self == tgt:
    setColor(8) # target
    line(dx, dy, dx + norm_vel.x, dy + norm_vel.y)
    circ(dx, dy, 5)
    let dist = ((sel.pos - pos).length() / 1000).int
    let rvel = (sel.vel - vel).length().int()
    print(&"{dist}km", dx + 8, dy + 1)
    print(&"{rvel}m/s", dx + 8, dy - 5)
  else:
    setColor(7) # other
    line(dx, dy, dx + norm_vel.x, dy + norm_vel.y)
    circ(dx, dy, 5)

# --- map ---

proc newMap(): Map =
  result = new(Map)
  result.x = 0
  result.y = 10
  result.h = 100
  result.w = 128
  result.scale = 1000
  result.objs = @[]

method draw(self: Map) =
  for obj in objs:
    obj.draw()

method onHoverOver(self: Map) =
  if btn(pcLeft):
    view.x -= 3
  if btn(pcRight):
    view.x += 3
  if btn(pcUp):
    view.y -= 3
  if btn(pcDown):
    view.y += 3
  if btnp(pcA):
    scale = scale div 2
    echo &"scale = {scale}"
  if btnp(pcB):
    scale *= 2
    echo &"scale = {scale}"


# --- setup ---

proc switch_gui_btn_cb(btn: Button) =
  main_gui.sub_gui = sub_guis[btn.label]

proc gameInit =
  # game
  frame_t = 0
  game_t = 0
  accel = 0 # time acceleration
  map = newMap()
  for i in 0..10:
    map.objs.add(newMapObj(rand(128000), rand(128000), -1000 + rand(2000), - 1000 + rand(2000)))

  sel = map.objs[0]
  tgt = map.objs[1]

  # gui
  main_gui = newGui()
  # add common elements
  main_gui.widgets.add(newButton(0, 0, 16, 10, "NAV", switch_gui_btn_cb))
  main_gui.widgets.add(newButton(20, 0, 16, 10, "TGT", switch_gui_btn_cb))
  main_gui.widgets.add(newButton(60, 0, 16, 10, "CRW", switch_gui_btn_cb))
  main_gui.widgets.add(newButton(40, 0, 16, 10, "COM", switch_gui_btn_cb))
  main_gui.widgets.add(newButton(80, 0, 16, 10, "ENG", switch_gui_btn_cb))
  main_gui.widgets.add(newButton(100, 0, 16, 10, "CBT", switch_gui_btn_cb))
  main_gui.widgets.add(newTimeCtrl(80, 118, 48, 10))

  var
    nav_sub_gui = newGui()
    tgt_sub_gui = newGui()
    crw_sub_gui = newGui()
    com_sub_gui = newGui()
    eng_sub_gui = newGui()
    cbt_sub_gui = newGui()

  nav_sub_gui.widgets.add(map)
  nav_sub_gui.widgets.add(newPanelLabel(0, 118, 30, 10, "TRS", "tgt_rel_spd", "m/s"))

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
  if frame_t mod 60 == 0:
    echo &"game_t={game_t} tgt.pos={tgt.pos} tgt.vel={tgt.vel} {tgt.vel.normalized()}"
  let tgt_spd = (sel.vel - tgt.vel).length()
  gui_floats["tgt_rel_spd"] = tgt_spd

# --- nico callbacks ---

proc gameUpdate(dt: float32) =
  let (x, y) = mouse()
  if mousebtnp(0):
    current_gui.mouseDownEvent()
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

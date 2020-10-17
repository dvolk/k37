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
  
proc newMapObj(x, y: int): MapObj =
  result = new(MapObj)
  result.pos = vec2f(float(x), float(y))
  result.vel = vec2f(0.0, 0.0)
  result.mass = 1000
             

proc draw(self: MapObj) =
  if (frame_t div 10) mod 9 == 0:
    return
  setColor(11)
  circ(int(pos.x), int(pos.y), 5)

# --- map ---
      
method draw(self: Map) =
  for obj in objs:
    obj.draw()

# --- setup ---
    
proc gameInit =
  # game
  sel = newMapObj(30, 30)
  tgt = newMapObj(50, 60)
  map.objs.add(sel)
  map.objs.add(tgt)
  # gui
  main_gui = newGui()
  main_gui.widgets.add(newButton(0, 0, 16, 10, "NAV"))
  main_gui.widgets.add(newButton(20, 0, 16, 10, "TGT"))
  main_gui.widgets.add(newButton(60, 0, 16, 10, "CRW"))
  main_gui.widgets.add(newButton(40, 0, 16, 10, "COM"))
  main_gui.widgets.add(newButton(80, 0, 16, 10, "ENG"))
  main_gui.widgets.add(newButton(100, 0, 16, 10, "CBT"))
  main_gui.widgets.add(newTimeCtrl(80, 118, 48, 10))
  main_gui.widgets.add(newPanelLabel(20, 70, 30, 10, "spd", sel.vel.x, "m/s"))
  current_gui = main_gui

# --- nico callbacks ---
  
proc gameUpdate(dt: float32) =
  let (x, y) = mouse()
  if mousebtnp(0):
    current_gui.mouseDownEvent()
  current_gui.update()
  frame_t = frame_t + 1
  game_t = game_t + accel

proc gameDraw =
  cls()
  map.draw()
  current_gui.draw()

# --- main ---

when isMainModule:
  nico.init("com.oxfordfun", "kelvin27")
  fixedSize(true)
  integerScale(false)
  setPalette(loadPalettePico8Extra())
  nico.createWindow("myApp", 128, 128, 4, false)
  nico.run(gameInit, gameUpdate, gameDraw)

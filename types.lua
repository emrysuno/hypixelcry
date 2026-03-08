---@meta

---@param callback fun()
---@return boolean
function registerUnloadCallback(callback) end

---@param callback fun()
---@return boolean
function registerSpawnParticle(callback) end

---@param callback fun()
---@return boolean
function unregisterSpawnParticle(callback) end

---@param callback fun()
---@return boolean
function registerInventoryItemChange(callback) end

---@param callback fun()
---@return boolean
function unregisterInventoryItemChange(callback) end

---@param commandName string
---@param callback fun(commandName:string, args:table, senderName:string)
---@return boolean
function registerCommand(commandName, callback) end

---@param commandName string
---@return boolean
function unregisterCommand(commandName) end

---@param commandName string
---@param callback fun(args:string):table
---@return boolean
function registerCommandSuggestions(commandName, callback) end

---@param callback fun()
---@return boolean
function registerClientTick(callback) end
function registerClientTickPost(callback) end
function registerClientTickPre(callback) end

---@param callback fun()
---@return boolean
function unregisterClientTick(callback) end
function unregisterClientTickPost(callback) end
function unregisterClientTickPre(callback) end

---@param callback fun(blockTable:table): boolean?
---@return boolean
function registerBlockUpdate(callback) end
function unregisterBlockUpdate(callback) end

---@param callback fun(blockTable:table): boolean?
---@return boolean
function registerUseBlock(callback) end
function unregisterUseBlock(callback) end

---@param callback fun(worldRenderer:WorldRendererObject)
---@return boolean
function registerWorldRenderer(callback) end
function unregisterWorldRenderer(callback) end

---@param callback fun(twoRender:TwoRenderObject)
---@return boolean
function register2DRenderer(callback) end
function unregister2DRenderer(callback) end

---@param callback fun(key:number, type:string)
---@return boolean
function registerKeyEvent(callback) end
function unregisterKeyEvent(callback) end

---@param callback fun(message:string, overlay:boolean): boolean?
---@return boolean
function registerMessageEvent(callback) end
function unregisterMessageEvent(callback) end

---@param callback fun(text:string): boolean?
---@return boolean
function registerSendMessageEvent(callback) end
function unregisterSendMessageEvent(callback) end

---@param callback fun(text:string): boolean?
---@return boolean
function registerSendCommandEvent(callback) end
function unregisterSendCommandEvent(callback) end

---@param callback fun(locationString:string)
---@return boolean
function registerLocationChangeEvent(callback) end
function unregisterLocationChangeEvent(callback) end

---@param callback fun()
---@return boolean
function registerImGuiRenderEvent(callback) end
function unregisterImGuiRenderEvent(callback) end

---@param callback fun(yaw:number, pitch:number): boolean?
---@return boolean
function registerServerSideRotationEvent(callback) end
function unregisterServerSideRotationEvent(callback) end

---@param callback fun(x:number, y:number, z:number): boolean?
---@return boolean
function registerServerSideTeleportEvent(callback) end
function unregisterServerSideTeleportEvent(callback) end

---@class ImGuiTexture
---@field loadImage fun(path:string): integer
ImGuiTexture = ImGuiTexture or {}

---@class imgui
imgui = imgui or {}

function imgui.begin(name, flags) end
function imgui.endBegin() end
function imgui.newFrame() end
function imgui.render() end

function imgui.text(s) end
function imgui.textColored(r,g,b,a,s) end
function imgui.textDisabled(s) end
function imgui.bulletText(s) end

---@return ImGuiTexture
function imgui.createImageObject() end
---@param image ImGuiTexture|userdata
---@param w number
---@param h number
function imgui.image(image, w, h) end

function imgui.button(label, width, height) end
function imgui.smallButton(label) end
function imgui.arrowButton(strId, dir) end
function imgui.checkbox(label, value) end

function imgui.inputText(label, text, flags) end
function imgui.inputTextMultiline(label, text, width, height, flags) end
function imgui.inputInt(label, value, step, stepFast, flags) end
function imgui.inputFloat(label, value, step, stepFast, format, flags) end
function imgui.inputDouble(label, value, step, stepFast, format, flags) end

function imgui.sameLine() end
function imgui.newLine() end
function imgui.spacing() end
function imgui.separator() end

function imgui.beginGroup() end
function imgui.endGroup() end
function imgui.indent() end
function imgui.unindent() end
function imgui.setCursorPos(x, y) end
function imgui.getCursorPos() end
function imgui.getCursorScreenPos() end

function imgui.treeNode(label) end
function imgui.treeNodeEx(label, flags) end
function imgui.treePop() end
function imgui.collapsingHeader(label, flags) end

function imgui.selectable(label, selected, flags, width, height) end
function imgui.listBox(label, currentItem, items, heightInItems) end

function imgui.setTooltip(text) end
function imgui.beginTooltip() end
function imgui.endTooltip() end

function imgui.beginPopup(strId, flags) end
function imgui.beginPopupModal(name, flags) end
function imgui.endPopup() end
function imgui.openPopup(strId, flags) end
function imgui.closeCurrentPopup() end

function imgui.beginMenuBar() end
function imgui.endMenuBar() end
function imgui.beginMainMenuBar() end
function imgui.endMainMenuBar() end
function imgui.beginMenu(label, enabled) end
function imgui.endMenu() end
function imgui.menuItem(label, shortcut, selected, enabled) end

function imgui.beginTabBar(strId, flags) end
function imgui.endTabBar() end
function imgui.beginTabItem(label, flags) end
function imgui.endTabItem() end

function imgui.beginChild(strId, width, height, border, flags) end
function imgui.endChild() end

function imgui.pushStyleColor(idx, r, g, b, a) end
function imgui.popStyleColor(count) end
function imgui.pushStyleVar(idx, x, y) end
function imgui.popStyleVar(count) end
function imgui.popFont() end
function imgui.pushID(strId) end
function imgui.popID() end

function imgui.setNextItemWidth(width) end
function imgui.isItemHovered(flags) end
function imgui.isItemClicked(mouseButton) end
function imgui.isItemActive() end
function imgui.isWindowAppearing() end
function imgui.isWindowCollapsed() end
function imgui.isWindowFocused(flags) end
function imgui.isWindowHovered(flags) end

function imgui.setNextWindowSize(width, height, cond) end
function imgui.setNextWindowPos(x, y, cond, pivotX, pivotY) end
function imgui.setNextWindowCollapsed(collapsed, cond) end
function imgui.setNextWindowFocus() end

function imgui.getWindowSize() end
function imgui.getWindowPos() end
function imgui.getWindowWidth() end
function imgui.getWindowHeight() end

function imgui.beginTable(name, column, flags) end
function imgui.tableSetupColumn(name) end
function imgui.tableHeadersRow() end
function imgui.tableNextRow() end
function imgui.tableSetColumnIndex(index) end
function imgui.endTable() end

function imgui.sliderFloat(label, value, min, max, format, flags) end
function imgui.sliderInt(label, value, min, max, format, flags) end
function imgui.vSliderFloat(label, sizeX, sizeY, value, min, max, format, flags) end
function imgui.vSliderInt(label, sizeX, sizeY, value, min, max, format, flags) end

function imgui.pathClear() end
function imgui.pathLineTo(x,y) end
function imgui.pathStroke(color, flags, thickness) end

imgui.constants = imgui.constants or {}

---@class json
local json = json or {}
---@param jsonString string
---@return table|nil
function json.parse(jsonString) end
---@param value any
---@param indent? number|boolean
---@return string
function json.stringify(value, indent) end

---@class AsyncResult
---@field await fun(timeout?:number, default?:any): any
---@field then fun(callback:fun(result:any, err:any))
AsyncResult = AsyncResult or {}

---@class http
http = http or {}

---Synchronous GET
---@param url string
---@param timeout? number
---@return table
function http.get(url, timeout) end
---@param url string
---@param headers table
---@return table
function http.get_with_headers(url, headers) end

---Asynchronous GET returning a promise
---@param url string
---@param timeout? number
---@return AsyncResult
function http.get_async(url, timeout) end
---@param url string
---@param headers table
---@return AsyncResult
function http.get_async_with_headers(url, headers) end

---Asynchronous GET with callback
---@param url string
---@param callback fun(response:table, err:any)
---@return boolean
function http.get_async_callback(url, callback) end
---@param url string
---@param headers table
---@param callback fun(response:table, err:any)
---@return boolean
function http.get_async_with_headers_callback(url, headers, callback) end

---Synchronous POST
---@param url string
---@param headers table
---@param body string
---@return table
function http.post(url, headers, body) end
---@param url string
---@param body string
---@return table
function http.post_with_headers(url, body) end

---Asynchronous POST returning a promise
---@param url string
---@param headers table
---@param body string
---@return AsyncResult
function http.post_async(url, headers, body) end
---@param url string
---@param body string
---@return AsyncResult
function http.post_async_with_headers(url, body) end

---Asynchronous POST with callback
---@param url string
---@param headers table
---@param callback fun(response:table, err:any)
---@return boolean
function http.post_async_callback(url, headers, callback) end
---@param url string
---@param headers table
---@param body string
---@param callback fun(response:table, err:any)
---@return boolean
function http.post_async_with_headers_callback(url, headers, body, callback) end

---@class catboost
catboost = catboost or {}
---@param modelPath string
---@return CatBoostModel
function catboost.loadModel(modelPath) end

---@class CatBoostModel
---@param features table
---@return number
function CatBoostModel:predict(features) end

---@class creator
creator = creator or {}
---@param x1 number
---@param y1 number
---@param z1 number
---@param x2 number
---@param y2 number
---@param z2 number
---@return Box
function creator.createAABB(x1, y1, z1, x2, y2, z2) end
function creator.createBox(x1, y1, z1, x2, y2, z2) end

---@param direction string
---@return Direction
function creator.createDirection(direction) end

---@param id string
---@return LuaItemStack
function creator.createItemStackFromId(id) end

---@class encoding
encoding = encoding or {}
---@param text string
---@param encoding? string
---@return table, string|nil
function encoding.stringToBytes(text, encoding) end
---@param bytesTable table
---@param encoding? string
---@param startIndex? number
---@param length? number
---@return string, string|nil
function encoding.bytesToString(bytesTable, encoding, startIndex, length) end
function encoding.getSupportedEncodings() end
function encoding.isValidEncoding(encoding) end
function encoding.detectEncoding(text) end
function encoding.convertEncoding(text, fromEncoding, toEncoding) end
function encoding.hexEncode(text) end
function encoding.hexDecode(hexString) end
function encoding.base64Encode(text) end
function encoding.base64Decode(base64String) end

---@class threads
threads = threads or {}
---@param fn fun()
---@return integer
function threads.startThread(fn) end
---@param threadId integer
function threads.joinThread(threadId) end
---@param threadId integer
---@return boolean
function threads.isAlive(threadId) end
---@param threadId integer
---@return boolean
function threads.interruptThread(threadId) end
---@param threadId integer
---@return boolean
function threads.stopThread(threadId) end
---@param ms number
function threads.sleep(ms) end
function threads.getThreadCount() end

---@class tcp
tcp = tcp or {}
---@param host string
---@param port integer
---@param timeout? number
---@return integer|string, string|nil
function tcp.connect(host, port, timeout) end
---@param connectionId integer
---@return boolean
function tcp.disconnect(connectionId) end
---@param connectionId integer
---@param message string
---@param newline? boolean
---@return boolean, string|nil
function tcp.send(connectionId, message, newline) end
---@param connectionId integer
---@param bytesTable table
---@return boolean, string|nil
function tcp.sendBytes(connectionId, bytesTable) end
---@param connectionId integer
---@param timeout? number
---@return string|nil, string|nil
function tcp.receive(connectionId, timeout) end
---@param connectionId integer
---@param timeout? number
---@param maxBytes? number
---@return table|nil, string|nil
function tcp.receiveBytes(connectionId, timeout, maxBytes) end
---@param connectionId integer
---@return boolean
function tcp.isConnected(connectionId) end
---@param connectionId integer
---@return table|nil
function tcp.getLocalAddress(connectionId) end
---@param connectionId integer
---@return table|nil
function tcp.getRemoteAddress(connectionId) end
---@param connectionId integer
---@param blocking boolean
---@return boolean, string|nil
function tcp.setBlocking(connectionId, blocking) end
---@param connectionId integer
---@param timeout integer
---@return boolean, string|nil
function tcp.setTimeout(connectionId, timeout) end
function tcp.getSocketCount() end

---@class ComponentBuilder
---@field new fun(text?:string): ComponentBuilder
---@field empty fun(): ComponentBuilder
ComponentBuilder = ComponentBuilder or {}
function ComponentBuilder.new(text) end
function ComponentBuilder.empty() end

---ComponentBuilder instance methods
function component:text(text) end
function component:color(color) end
function component:bold(bold) end
function component:italic(italic) end
function component:underlined(underlined) end
function component:strikethrough(strikethrough) end
function component:obfuscated(obfuscated) end
function component:insertion(insertion) end
function component:clickRunCommand(command) end
function component:clickSuggestCommand(command) end
function component:clickOpenUrl(url) end
function component:clickCopyToClipboard(text) end
function component:clickChangePage(page) end
function component:hoverText(text) end
function component:append(component) end
function component:build() end

---@class LuaItemStack
---@field count number
---@field max_count number
---@field name string
---@field display_name string
---@field is_empty boolean
---@field head_texture string
---@field skyblock_id string
---@field neu_id string
---@field reforge_modifier string
---@field is_stackable boolean
---@field is_recombobulated boolean
---@field is_museum_donated boolean
---@field is_enchanted boolean
---@field uuid string
---@field map table
---@field lore table
---@field lores table
---@field enchantments table
---@field ench table
LuaItemStack = LuaItemStack or {}
function LuaItemStack:getItemStack() end

---@class BlockState
---@field id number
---@field name string
---@field type string
---@field hardness number
---@field blast_resistance number
---@field is_solid boolean
---@field is_liquid boolean
---@field is_air boolean
---@field age number
---@field delay number
---@field power number
---@field facing Direction
---@field extended boolean
---@field layers number
---@field is_still boolean
BlockState = BlockState or {}

---@class Entity
---@field id number
---@field uuid string
---@field name string
---@field display_name string
---@field type string
---@field x number
---@field y number
---@field z number
---@field pos table
---@field box Box
---@field velocity_x number
---@field velocity_y number
---@field velocity_z number
---@field velocity table
---@field width number
---@field height number
---@field yaw number
---@field pitch number
---@field is_on_ground boolean
---@field is_touching_water boolean
---@field is_in_lava boolean
---@field is_sneaking boolean
---@field is_sprinting boolean
---@field passengers table
---@field age number
---@field distance_to_player number
---@field item LuaItemStack
---@field health number
---@field max_health number
---@field is_alive boolean
---@field is_child boolean
---@field is_baby boolean
---@field main_hand LuaItemStack
---@field off_hand LuaItemStack
---@field head LuaItemStack
---@field chest LuaItemStack
---@field legs LuaItemStack
---@field feet LuaItemStack
---@field active_effects table
Entity = Entity or {}

---@class Box
---@field min_x number
---@field min_y number
---@field min_z number
---@field max_x number
---@field max_y number
---@field max_z number
Box = Box or {}

---@class Direction
Direction = Direction or {}

---@class MapData
MapData = MapData or {}

---@class input
input = input or {}
function input.leftClick() end
function input.rightClick() end
function input.attackBlock() end
function input.attackEntity() end
function input.interactBlock() end
function input.interactEntity() end
function input.useItem() end
function input.silentUse(slot) end
function input.syncSelectedSlot() end
function input.setSelectedSlot(slot) end
function input.getSelectedSlot() end

function input.setPressedSprinting(pressed) end
function input.setPressedJump(pressed) end
function input.setPressedSneak(pressed) end
function input.setPressedForward(pressed) end
function input.setPressedBack(pressed) end
function input.setPressedLeft(pressed) end
function input.setPressedRight(pressed) end
function input.setPressedAttack(pressed) end
function input.setPressedUse(pressed) end

function input.isPressedSprinting() end
function input.isPressedJump() end
function input.isPressedSneak() end
function input.isPressedForward() end
function input.isPressedBack() end
function input.isPressedLeft() end
function input.isPressedRight() end
function input.isPressedAttack() end
function input.isPressedUse() end

---@class inventory
inventory = inventory or {}
function inventory.isSignOpened() end
function inventory.isAnyScreenOpened() end
function inventory.getContainerSlots() end
function inventory.getChestTitle() end
function inventory.getStack(slot) end
function inventory.getStackFromContainer(slot) end
function inventory.getStackFromId(id) end
function inventory.getSignText(index) end
function inventory.setSignText(index, text) end
function inventory.leftClick(slot) end
function inventory.rightClick(slot) end
function inventory.dropAll(slot) end
function inventory.closeScreen() end
function inventory.openInventory() end

---@class network
network = network or {}
function network.getPlayersList() end
function network.sendStartDestroyBlockPacket(x,y,z,face) end
function network.sendStopDestroyBlockPacket(x,y,z,face) end
function network.sendAbortDestroyBlockPacket(x,y,z,face) end

---@class player
---@field input input
---@field inventory inventory
---@field network network
---@field entity Entity
player = player or {}
player.input = player.input or input
player.inventory = player.inventory or inventory
player.network = player.network or network
player.entity = player.entity or Entity

function player.fishHook() end
function player.addMessage(msg) end
function player.sendMessage(msg) end
function player.sendCommand(cmd) end
function player.getPos() end
function player.getPosition() end
function player.getRotation() end
function player.setRotation(yaw,pitch) end
function player.getName() end
function player.getArea() end
function player.getRawLocation() end
function player.getLocation() end
function player.getProfile() end
function player.getProfileId() end
function player.getBits() end
function player.getPurse() end
function player.getHealth() end
function player.getMaxHealth() end
function player.getMana() end
function player.getMaxMana() end
function player.getDefence() end
function player.getSpeed() end
function player.getCold() end
function player.getAir() end
function player.getMaxAir() end
function player.getPet() end
function player.getRank() end
function player.isSneaking() end
function player.isSprinting() end
function player.isOnGround() end
function player.isOnSkyBlock() end
function player.isHasLineOfSight(target) end
function player.swingHand(offhand) end
function player.getEyePosition() end
function player.getLookEndPos(a,b) end
function player.getDirectionFromYawPitch(yaw, pitch) end
function player.getScoreBoardLines() end
function player.getTab() end
function player.addToast(title, body, typeNum) end
function player.raycast(distance) end

---@class TwoRenderObject
TwoRenderObject = TwoRenderObject or {}
function TwoRenderObject.getWindowScale() end
function TwoRenderObject.getTextWidth(text) end
function TwoRenderObject.renderText(opts) end
function TwoRenderObject.renderImage(opts) end
function TwoRenderObject.renderRect(opts) end
function TwoRenderObject.renderLine(opts) end
function TwoRenderObject.renderPolygon(opts) end
function TwoRenderObject.renderItemStack(opts) end

---@class WorldRendererObject
WorldRendererObject = WorldRendererObject or {}
function WorldRendererObject.renderFilled(opts) end
function WorldRendererObject.renderOutline(opts) end
function WorldRendererObject.renderFilledCircle(opts) end
function WorldRendererObject.renderOutlineCircle(opts) end
function WorldRendererObject.renderCylinder(opts) end
function WorldRendererObject.renderSphere(opts) end
function WorldRendererObject.renderText(opts) end
function WorldRendererObject.renderLinesFromPoints(opts) end
function WorldRendererObject.renderLineFromCursor(opts) end
function WorldRendererObject.renderImage(opts) end
function WorldRendererObject.renderBeaconBeam(opts) end
function WorldRendererObject.renderQuad(opts) end
function WorldRendererObject.renderHologramBlock(opts) end
function WorldRendererObject.renderBlock(opts) end
function WorldRendererObject.renderItem(opts) end
function WorldRendererObject.getCollisionBoxes(x, y, z, blockState) end
function WorldRendererObject.getOutlineBoxes(x, y, z, blockState) end

---@class world
world = world or {}
function world.getRotation(a,b,c) end
function world.getBlock(a,b,c) end
function world.getBlockState(a,b,c) end
function world.setBlock(a,b,c,id) end
function world.isBlockLoaded(a,b,c) end
function world.getEntities() end
function world.getEntitiesInBox(entity, box) end
function world.getLivingEntities() end
function world.getEntityById(id) end
function world.getCollisionBoxes(x, y, z, arg4) end
function world.getOutlineBoxes(x, y, z, arg4) end
function world.raycast(opts) end
function world.raycastToBlocks(opts) end

---@class modules
modules = modules or {}
function modules.getLoadedScripts() end
modules.pathFinder = modules.pathFinder or {}
function modules.pathFinder.isHasPath(id) end
function modules.pathFinder.removePath(id) end
function modules.pathFinder.addOrUpdatePath(pathTable) end
function modules.pathFinder.getPathBlocks(id) end

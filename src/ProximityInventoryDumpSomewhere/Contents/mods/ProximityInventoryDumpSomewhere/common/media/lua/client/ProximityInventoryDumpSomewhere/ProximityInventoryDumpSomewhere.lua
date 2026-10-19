
---@type function
local log = require('ProximityInventoryDumpSomewhere/log.lua');

ProximityInventoryDumpSomewhere = ProximityInventoryDumpSomewhere or {};

ProximityInventoryDumpSomewhere.Orig = ProximityInventoryDumpSomewhere.Orig or {};
local Orig = ProximityInventoryDumpSomewhere.Orig;

-- Checks whether item can be dropped into at least one of given containers that is not virtual and not floor
---@param containers any
---@param item any
---@return boolean
---@return ItemContainer|nil
function ProximityInventoryDumpSomewhere:canDropSomewhere(containers, item)
  for i = 1, #containers do
    local inv = containers[i].inventory
    if ProximityInventoryDumpSomewhere:isInventoryAllowed(inv) and inv:canItemFit(item, nil) then
      return true, inv;
    end
  end

  return false, nil;
end

function ProximityInventoryDumpSomewhere:isInventoryAllowed(inv)
  local invType = inv:getType()
  return invType ~= "proxInv" and invType ~= "local" and invType ~= "floor"
end


Orig.DraggedItems_update = Orig.DraggedItems_update or ISInventoryPaneDraggedItems.update;

--- Overrides method called while dragging, which recolors items
--- depending on whether they can be dropped or not
---@return nil
function ISInventoryPaneDraggedItems:update()

  self.playerNum = self.inventoryPane.player

  local container, what = self:getDropContainer();
  local playerLoot = getPlayerLoot(self.playerNum)
  if playerLoot == nil or container == nil or container:getType() ~= "proxInv" then
    return Orig.DraggedItems_update(self);
  end

  -- сaching like original update
  if self.mouseOverContainer and (self.mouseOverItemCount ~= self.mouseOverContainer:getItems():size()) then
    self.mouseOverContainer = nil
  end
  if (container == self.mouseOverContainer) and (what == self.mouseOverWhat) then
    return
  end
  self.mouseOverContainer = container
  self.mouseOverWhat = what
  self.mouseOverItemCount = container:getItems():size()
  table.wipe(self.itemNotOK)

  if self.items == nil then
    self.items = ISInventoryPane.getActualItems(ISMouseDrag.dragging)
    self.inventoryPane:sortItemsByTypeAndWeight(self.items)
  end
  if #self.items == 0 then
    return
  end

  for _,item in ipairs(self.items) do
    self.itemNotOK[item] = not ProximityInventoryDumpSomewhere:canDropSomewhere(playerLoot.backpacks, item);
  end

end

function ProximityInventoryDumpSomewhere:dropSomewhere(inventoryPane, invs, items)
  local playerNum = inventoryPane.player;
  local playerObj = getSpecificPlayer(playerNum)

  local availableInvs = {}
  for _, child in pairs(invs) do
    if ProximityInventoryDumpSomewhere:isInventoryAllowed(child.inventory) then
      table.insert(availableInvs, child.inventory);
    end
  end

  local transfered = false;
  for _, item in ipairs(items) do
    if hasRoomFor then
      break
    end
    
    if not item:isFavorite() then
      for invInd, inv in ipairs(availableInvs) do
        local action = ISInventoryTransferUtil.newInventoryTransferAction(playerObj, item, item:getContainer(), inv);
        transfered = action:isValid();
        if transfered then

          action:setOnComplete(function ()
            table.remove(items, 1)
            ProximityInventoryDumpSomewhere:dropSomewhere(inventoryPane, invs, items);
          end);

          ISTimedActionQueue.add(action);

          break;
        end
      end
    end
  end

end

Orig.ISInventoryPage_dropItemsInContainer = Orig.ISInventoryPage_dropItemsInContainer or ISInventoryPage.dropItemsInContainer;

---@param button any
---@return boolean
function ISInventoryPage:dropItemsInContainer(button)

  if button.inventory:getType() ~= "proxInv" then
    return Orig.ISInventoryPage_dropItemsInContainer(self, button);
  end

	if self.player ~= 0 then return false end
	if ISMouseDrag.dragging == nil then return false end
	local playerObj = getSpecificPlayer(self.player)

  self.inventoryPane.draggedItems:reset()
	self.inventoryPane.draggedItems:update()

  ProximityInventoryDumpSomewhere:dropSomewhere(
    self.inventoryPane,
    self.backpacks,
    ISInventoryPane.getActualItems(ISMouseDrag.dragging)
  )

	if ISMouseDrag.draggingFocus then
		ISMouseDrag.draggingFocus:onMouseUp(0,0);
		ISMouseDrag.draggingFocus = nil;
		ISMouseDrag.dragging = nil;
	end
	self:refreshWeight();
  self:updateItemCount();
	return true
end


Orig.ISInventoryPane_onMouseUp = Orig.ISInventoryPane_onMouseUp or ISInventoryPane.onMouseUp;

function ISInventoryPane:onMouseUp(x, y)
  local focusCheck = ISMouseDrag.dragging ~= nil and ISMouseDrag.draggingFocus ~= self and ISMouseDrag.draggingFocus ~= nil;
  if self.inventory:getType() ~= "proxInv" or not focusCheck then
    return Orig.ISInventoryPane_onMouseUp(self, x, y);
  end

  if self.player ~= 0 then return end

  if focusCheck then
    ProximityInventoryDumpSomewhere:dropSomewhere(
      self,
      self.parent.backpacks,
      ISInventoryPane.getActualItems(ISMouseDrag.dragging)
    )
    self.selected = {};
    getPlayerLoot(self.player).inventoryPane.selected = {};
    getPlayerInventory(self.player).inventoryPane.selected = {};
  end

  if ISMouseDrag.draggingFocus then
    ISMouseDrag.draggingFocus:onMouseUp(0,0);
  end
  ISMouseDrag.draggingFocus = nil;
  ISMouseDrag.dragging = nil;
  self.dragging = nil;
  self.draggedItems:reset();
  self.draggingMarquis = false;

  if x >= 0 and y >= 0 and x < self.column3 then
    y = y - self.headerHgt;
    y = y / self.itemHgt;
    y = math.floor(y + 1);
    self.mouseOverOption = y;
  end

	return true;
end



return ProximityInventoryDumpSomewhere;
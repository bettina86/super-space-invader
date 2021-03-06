UI = class("UI", Entity)

function UI:initialize()
  Entity.initialize(self)
  self.layer = 1
  self.alpha = 0
  self.items = {}
  self.selected = nil
  self.selectTime = 0.6
  self.selectTimer = 0
  self.outsidePadding = love.graphics.width / 16
  self.insidePadding = 10
  self.height = love.graphics.height / 3
  self.showInstructions = true
  self.title = Text:new{y = self.height - 45, width = love.graphics.width, align = "center", font = assets.fonts.main[24]}
  
  self.instructions = Text:new{
    "Left/A/LMB to go left\nRight/D/RMB to go right\nHold both to select menu item\nPress Q to quit",
    y = love.graphics.height - 110,
    width = love.graphics.width,
    align = "center",
    font = assets.fonts.main[12]
  }
  
  self.smallInstructions = Text:new{
    "or just press enter to select, if you prefer",
    y = love.graphics.height - 30,
    width = love.graphics.width,
    align = "center",
    font = assets.fonts.main[8]
  }
  
  self.displayTxt = Text:new{width = love.graphics.width, align = "center", font = assets.fonts.main[24]}
  self.displayTxt.y = love.graphics.width / 2 - self.displayTxt.fontHeight / 2
  
  self.countdown = 0
  self.countdownScale = 1
  self.selectingSnd = playSound("selecting")
  self.selectingSnd:stop()
end

function UI:update(dt)
  if input.pressed("select") then self:select() end
  
  if input.down("left") and input.down("right") then
    if self.selectTimer >= self.selectTime then
      self:select()
      self.selectingSnd:stop()
    else
      self.selectTimer = self.selectTimer + dt
      self.selectingSnd:play()
    end
  else
    self.selectTimer = 0
    self.selectingSnd:stop()
    
    if input.pressed("left") and self.selected > 1 and self:checkSelect(self.selected - 1) then
      self.selected = self.selected - 1
      playRandom{"select1", "select2"}
    end
    
    if input.pressed("right") and self.selected < #self.items and self:checkSelect(self.selected + 1) then
      self.selected = self.selected + 1
      playRandom{"select1", "select2"}
    end
  end
end

function UI:draw()
  if self.countdown > 0 then
    love.graphics.setFont(assets.fonts.main[70])
    love.graphics.print(
      self.countdown,
      love.graphics.width / 2,
      love.graphics.height / 2,
      0,
      self.countdownScale,
      self.countdownScale,
      assets.fonts.main[70]:getWidth(self.countdown) / 2,
      assets.fonts.main[70]:getHeight() / 2
    )
  elseif self.displayTxt.text ~= "" then
    --self.displayTxt.color[4] = 255 * self.alpha
    self.displayTxt:draw()
  elseif self.alpha > 0 then
    love.graphics.setColor(0, 0, 0, 100 * self.alpha)
    love.graphics.rectangle("fill", 0, 0, love.graphics.width, love.graphics.height)
    local width = (love.graphics.width - self.outsidePadding * 2 - self.insidePadding * (#self.items - 1)) / #self.items

    for i, item in ipairs(self.items) do
      local x = self.outsidePadding + (width + self.insidePadding) * (i - 1)
      local y = love.graphics.height / 2 - self.height / 2
      local alpha = 100
      local offsetX = 0
      local offsetY = 0
      
      if i == self.selected then
        alpha = self.selectTimer > 0 and 240 or 200
        offsetX = 5 * (self.selectTimer / self.selectTime) * (1 - 2 * math.random(0, 1))
        offsetY = 5 * (self.selectTimer / self.selectTime) * (1 - 2 * math.random(0, 1))
      end
      
      love.graphics.setColor(148, 228, 255, alpha * self.alpha)
      love.graphics.rectangle("fill", x, y, width, self.height)
      
      if Object.isInstanceOf(item, Text) then
        item.width = width
        item.color[4] = 255 * self.alpha
        item:draw(x + offsetX, y + self.height / 2 + item.y + offsetY)
      else
        for _, i in ipairs(item) do
          i.width = width
          i.color[4] = 255 * self.alpha
          i:draw(x + offsetX, y + self.height / 2 + i.y + offsetY)
        end
      end
    end
    
    if self.title.text ~= "" then
      self.title.color[4] = 255 * self.alpha
      self.title:draw()
    end
    
    if self.showInstructions then
      self.instructions.color[4] = 255 * self.alpha
      self.instructions:draw()
      self.smallInstructions.color[4] = 255 * self.alpha
      self.smallInstructions:draw()
    end
  end
end

function UI:select()
  local item = self.items[self.selected]
  if not Object.isInstanceOf(item, Text) then item = item[1] end
  local result = item.select()
  if result ~= true then self:deactivate() end
  self.selectTimer = 0
  playSound("make-selection")
end

function UI:activate()
  if self.tween then self.tween:stop() end
  self.tween = self:animate(0.25, { alpha = 1 })
  self.active = true
end

function UI:deactivate()
  if self.tween then self.tween:stop() end
  self.tween = self:animate(0.25, { alpha = 0 })
  self.active = false
end

function UI:checkSelect(index)
  local item = self.items[index]
  if not item then return false end
  if not Object.isInstanceOf(item, Text) then item = item[1] end
  return item.select ~= nil
end

function UI:addItem(text, func)
  if Object.isInstanceOf(text, Text) then
    text.select = func
  elseif func then
    text[1].select = func
  end
  
  self.items[#self.items + 1] = text
end

function UI:welcome()
  self.items = {}
  self.selected = 1
  self.state = "welcome"
  self.title.text = "Super Space Invader"
  
  if data.wave > 0 then
    local waveTxt = data.wave < 13 and "wave " .. data.wave or "infinite wave"
    
    local texts = {
      Text:new{"Continue", font = assets.fonts.main[24], align = "center", y = -14},
      Text:new{"from " .. waveTxt, font = assets.fonts.main[12], align = "center", y = 14}
    }
    
    self:addItem(texts, function()
      self.world.player:applyLevels(data.attack, data.defence)
      self.world.score = data.score
      self:deactivate()
      self.state = nil
      delay(0.25, self.world.startWave, self.world, data.wave)
    end)
  end
  
  local newText = data.wave > 0 and "New\nGame" or "New Game"
  local newOffset = data.wave > 0 and -24 or -14
  
  self:addItem(Text:new{newText, font = assets.fonts.main[24], align = "center", y = newOffset}, function() 
    self.world.player:applyLevels(0, 0)
    self.world.score = 0
    self:deactivate()
    self.state = nil
    delay(0.25, self.world.startWave, self.world, 1)
  end)
  
  local texts = {
    Text:new{"Sandbox", font = assets.fonts.main[24], align = "center" , y = -14},
    Text:new{"Infinite wave with all upgrades", font = assets.fonts.main[12], align = "center", y = 14}
  }
  
  self:addItem(texts, function()
    self.world.player:applyLevels(6, 7)
    self.world.score = 0
    self:deactivate()
    delay(0.25, self.world.startSandbox, self.world)
  end)
  
  self:activate()
end

function UI:upgrades()
  self.items = {}
  self.state = "upgrades"
  self.title.text = "Pick an upgrade"
  
  local attack = Player.attackUpgrades[self.world.player.attackLvl + 1]
  local defence = Player.defenceUpgrades[self.world.player.defenceLvl + 1]
  
  if attack then
    self.selected = 1
  else
    self.selected = 2
  end
  
  if attack then
    local texts = {
      Text:new{attack[1], font = assets.fonts.main[18], align = "center", y = -24},
      Text:new{attack[2], font = assets.fonts.main[12], align = "center", y = 5}
    }
    
    self:addItem(texts, function()
      self.world:completeUpgrade(self.world.player.attackLvl + 1)
      self:deactivate()
      delay(0.25, self.world.nextWave, self.world)
    end)
  else
    self:addItem({
      Text:new{"N/A", font = assets.fonts.main[18], align = "center", y = -24},
      Text:new{"You've completed every attack upgrade", font = assets.fonts.main[12], align = "center", y = 5}
    })
  end
  
  if defence then
    local texts = {
      Text:new{defence[1], font = assets.fonts.main[18], align = "center", y = -24},
      Text:new{defence[2], font = assets.fonts.main[12], align = "center", y = 5}
    }
    
    self:addItem(texts, function()
      self.world:completeUpgrade(nil, self.world.player.defenceLvl + 1)
      self:deactivate()
      delay(0.25, self.world.nextWave, self.world)
    end)
  else
    self:addItem({
      Text:new{"N/A", font = assets.fonts.main[18], align = "center", y = -24},
      Text:new{"You've completed every defence upgrade", font = assets.fonts.main[12], align = "center", y = 5}
    })
  end
  
  if self.world.player.shieldAllowed then
    self.smallInstructions.text = "Don't forgot you can toggle your shield by pressing left and right together!"
  end
  
  self:activate()
end

function UI:death()
  self.items = {}
  self.selected = 1
  self.state = "death"
  self.title.text = "Game over"
  
  local waveFunc = function()
    self:deactivate()
    self.world.score = data.score
    delay(0.25, self.world.startWave, self.world, self.world.waveNum)
  end
  
  self:addItem(Text:new{"Restart\nWave", font = assets.fonts.main[18], align = "center", y = -20 }, waveFunc)
  
  local texts = {
    Text:new{"Restart\nGame", font = assets.fonts.main[18], align = "center", y = -20 },
    Text:new{"Overwrites saved data", font = assets.fonts.main[12], align = "center", y = 26 }
  }
  
  self:addItem(texts, function()
    self.world.player:applyLevels(0, 0)
    self.world.score = 0
    self:deactivate()
    delay(0.25, self.world.startWave, self.world, 1)
  end)
  
  
  texts = {
    Text:new{"Sandbox", font = assets.fonts.main[18], align = "center" , y = -20},
    Text:new{"Infinite wave with all upgrades", font = assets.fonts.main[12], align = "center", y = 13}
  }
  
  local sandboxFunc = function()
    self.world.player:applyLevels(6, 7)
    self.world.score = 0
    self:deactivate()
    delay(0.25, self.world.startSandbox, self.world)
  end
  
  self:addItem(texts, (self.world.waveNum == 13 and not self.world.sandbox) and waveFunc or sandboxFunc)
  
  if self.world.player.shieldAllowed then
    self.smallInstructions.text = "Don't forget you can toggle your shield by pressing left and right together!"
  end
  
  self:activate()
end

function UI:display(time, text, func)
  --self:activate()
  self.state = "display"
  self.displayTxt.text = text
  
  delay(time, function() 
    self:deactivate()
    self.displayTxt.text = ""
    func()
  end)
end

function UI:startCountdown(callback)
  self.countdown = 3
  self.countdownScale = 1
  self.state = "countdown"
  playSound("voice-3")
  
  self:animate(1, { countdownScale = 0.3 }, ease.quadIn, function()
    self.countdown = 2
    self.countdownScale = 1
    playSound("voice-2")
    
    self:animate(1, { countdownScale = 0.3 }, ease.quadIn, function()
      self.countdown = 1
      self.countdownScale = 1
      playSound("voice-1")
      
      self:animate(1, { countdownScale = 0.3 }, ease.quadIn, function()
        self.countdown = 0
        callback()
      end)
    end)
  end)
end

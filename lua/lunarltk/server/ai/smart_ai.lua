-- SPDX-License-Identifier: GPL-3.0-or-later

---@class SmartAI: TrustAI, AIUtil
---@field private _memory table<string, any> @ AI底层的空间换时间机制
---@field public friends ServerPlayer[] @ 队友
---@field public enemies ServerPlayer[] @ 敌人
local SmartAI = TrustAI:subclass("SmartAI")

local AIUtil = require 'lunarltk.server.ai.util'
SmartAI:include(AIUtil)

local AIGameLogic, AIGameEvent = require "lunarltk.server.ai.logic"
local AI = require "lunarltk.server.ai.strategies"

function SmartAI:initialize(player)
  TrustAI.initialize(self, player)
end

function SmartAI:makeReply()
  self._memory = setmetatable({}, { __mode = "k" })
  return TrustAI.makeReply(self)
end

function SmartAI:__index(k)
  if self._memory[k] then
    return self._memory[k]
  end
  local ret
  if k == "enemies" then
    ret = table.filter(self.room.alive_players, function(p)
      return self:isEnemy(p)
    end)
  elseif k == "friends" then
    ret = table.filter(self.room.alive_players, function(p)
      return self:isFriend(p)
    end)
  end
  self._memory[k] = ret
  return ret
end

---@generic T: AIStrategy
---@param tp T
---@param skill_name string
---@return T?
function SmartAI:findStrategyOfSkill(tp, skill_name)
  local skel = Fk.skills[skill_name]:getSkeleton()
  local list = skel.ai_strategies[tp] or Util.DummyTable
  for _, v in ipairs(list) do
    if v:matchContext(self) then
      return v
    end
  end
  return nil
end

---@type table<string, SkillAI>
fk.ai_skills = {}

---@param key string
---@param spec? SkillAISpec
---@param inherit? string
function SmartAI.static:setSkillAI(key, spec, inherit)
  do return end
end

SmartAI:setSkillAI("__card_skill", {
  choose_targets = function(self, ai)
    -- local targets = ai:getEnabledTargets()
    local logic = AIGameLogic:new(ai)
    local estimate_val = self:getEstimatedBenefit(ai)
    local val_func = function(targets)
      logic.benefit = 0
      logic:useCard({
        from = ai.player,
        tos = targets,
        card = ai:getSelectedCard(),
      })
      verbose(1, "目前状况下，对[%s]的预测收益为%g", table.concat(table.map(targets, function(p)return tostring(p)end), "+"), logic.benefit)
      return logic.benefit
    end
    local best_targets, best_val = nil, -100000
    for targets in self:searchTargetSelections(ai) do
      local val = val_func(targets)
      if (not best_targets) or (best_val < val) then
        best_targets, best_val = targets, val
      end
      -- if best_val > estimate_val then break end
    end
    return best_targets or {}, best_val
  end,

  think = function(self, ai)
  end,
})

function SmartAI.static:setCardSkillAI(key, spec, key2)
  do return end
end

SmartAI:setCardSkillAI("default_card_skill", {
  on_use = function(self, logic, effect)
    self.skill:onUse(logic, effect)
  end,
  on_effect = function(self, logic, effect)
    self.skill:onEffect(logic, effect)
  end,
})

---@type table<string, TriggerSkillAI>
fk.ai_trigger_skills = {}

function SmartAI.static:setTriggerSkillAI(key, spec)
  do return end
end

function SmartAI:handleAskForUseActiveSkill()
  local name = self.handler.skill_name

  local ai
  if self:currentSkill() then
    ai = self:findStrategyOfSkill(AI.ActiveStrategy, self:currentSkill().name)
  end
  if not ai then
    ai = self:findStrategyOfSkill(AI.ActiveStrategy, name)
  end
  if not ai then return "" end
  local _dbg_skill = ai.skill and ai.skill.name or "unknown"
  verbose(1, "正在询问技能：%s", _dbg_skill)
  local ret, real_val = ai:makeReply(self)
  verbose(1, "%s: 思考结果是%s, 收益是%s", _dbg_skill, json.encode(ret), json.encode(real_val))
  return ret, real_val
end

function SmartAI:handlePlayCard()
  local active_strategy_list = {} ---@type AI.ActiveStrategy[]
  do
    local skills = self:getEnabledSkills()
    local card_ids = self:getEnabledCards()
    local tmp = {}
    for _, id in ipairs(card_ids) do
      local cd = Fk:getCardById(id)
      tmp[cd.skill.name] = true
    end

    for sname in pairs(tmp) do
      local ai = self:findStrategyOfSkill(AI.CardSkillStrategy, sname)
      if ai then
        table.insert(active_strategy_list, ai)
      end
    end

    for _, sname in ipairs(skills) do
      local ai = self:findStrategyOfSkill(AI.ActiveStrategy, sname)
      if ai then
        table.insert(active_strategy_list, ai)
      end
    end
  end

  verbose(1, "======== %s: 开始计算出牌阶段 ========", tostring(self))

  local cancel_val = math.min(90 * (self.player:getMaxCards() - self.player:getHandcardNum()), -1)

  local best_ret, best_val = "", cancel_val
  verbose(1, "目前的决策：直接取消(收益%g)", best_val)
  for _, ai in fk.sorted_pairs(active_strategy_list, function(a) return a.use_priority end) do
    self:selectSkill(ai.skill_name, true)

    -- 干脆直接走handleActive的流程

    local ret, real_val = ai:makeReply(self) -- "", -10000 -- ai:think(self)
    verbose(1, "%s: 思考结果是%s, 收益是%s", ai.skill_name, json.encode(ret), json.encode(real_val))
    real_val = real_val or -100000

    -- if ret and ret ~= "" then return ret end
    if best_val < real_val then
      verbose(1, "将决策%s换成更好的%s (收益%g => %g)", json.encode(best_ret), json.encode(ret), best_val, real_val)
      best_ret, best_val = ret, real_val
    end
    self:unSelectAll()

    -- FIXME: 为了实现按优先级出牌，干脆只要收益为正就出
    if best_val > 0 and best_val > cancel_val then
      verbose(1, "懒得推测了，得出决策%s", json.encode(best_ret))
      return best_ret
    end
  end
  verbose(1, "推测出最佳决策是%s", json.encode(best_ret))
  if best_ret and best_ret ~= "" then return best_ret end
  return ""
end

---------------------------------------------------------------------

-- 其他交互：不涉及面板而是基于弹窗式的交互
-- SkillAI里面每个command给个方法
-- ========================================

function SmartAI:handleAskForCardChosen(data)
  local target_id, flag, reason, prompt = table.unpack(data)
  local target = self.room:getPlayerById(target_id)
  local ai = self:findStrategyOfSkill(AI.CardChosenStrategy, reason)
  if ai then
    verbose(1, "正在询问技能：%s, %s", ai.skill_name, prompt)
    local ret, real_val = ai:makeReply(self)
    verbose(1, "%s: 思考结果是%s, 收益是%s", ai.skill_name, json.encode(ret), real_val)
    return ret
  end
end

function SmartAI:handleAskForSkillInvoke(data)
  local skillName, prompt = data[1], data[2]
  local ai = self:findStrategyOfSkill(AI.InvokeStrategy, skillName)
  if ai then
    verbose(1, "正在询问技能：%s, %s", skillName, prompt)
    local ret = ai:makeReply(self)
    verbose(1, "%s: 思考结果是%s", skillName, json.encode(ret))
    return ret and "1" or ""
  else
    return ""
  end
end

function SmartAI:handleAskForChoice(data)
  local choices, allChoices, skillName, prompt = table.unpack(data)
  local ai = self:findStrategyOfSkill(AI.ChoiceStrategy, skillName)
  if ai then
    verbose(1, "正在询问技能：%s, 可选选项列表：%s", ai.skill_name, table.concat(choices, "+"))
    local ret, real_val = ai:makeReply(self)
    verbose(1, "%s: 思考结果是%s, 收益是%s", ai.skill_name, json.encode(ret), real_val)
    return ret or choices[1]
  else
    return choices[1]
  end
end
--[==[
function SmartAI:handleAskForUseCard(data)
  local card_ids = self:getEnabledCards()
  local pattern = data[2]
  local prompt = data[3]
  if pattern == "jink" then
    for _, cd in ipairs(card_ids) do
      self:selectCard(cd, true) -- 默认按下卡牌后直接可确定 懒得管了
      return self:doOKButton()
    end
  elseif pattern == "nullification" then
    if data[5] and data[5].effectFrom and self:isFriend(self.room:getPlayerById(data[5].effectFrom)) then
      return ""
    end
    local to = prompt:startsWith("#AskForNullificationWithoutTo") and prompt:split(":")[2] or prompt:split(":")[3]
    if to then
      to = self.room:getPlayerById(tonumber(to))
      if prompt:startsWith("#AskForNullificationWithoutTo") and self:isEnemy(to) or self:isFriend(to) then
        for _, cd in ipairs(card_ids) do
          self:selectCard(cd, true)
          return self:doOKButton()
        end
      end
    end
    return ""
  elseif pattern == "peach" or pattern == "peach,analeptic" then
    local to = prompt:startsWith("#AskForPeachesSelf") and self.player.id or prompt:split(":")[2]
    if to then
      to = self.room:getPlayerById(tonumber(to))
      if self:isFriend(to) then
        for _, cd in ipairs(card_ids) do
          self:selectCard(cd, true)
          return self:doOKButton()
        end
      end
    end
    return ""
  end

  local skill_ai_list = {}
  for _, id in ipairs(card_ids) do
    local cd = Fk:getCardById(id)
    local ai = fk.ai_skills[cd.skill.name]
    if ai then
      table.insertIfNeed(skill_ai_list, ai)
    end
  end
  for _, sname in ipairs(self:getEnabledSkills()) do
    local ai = fk.ai_skills[sname]
    if ai then
      table.insertIfNeed(skill_ai_list, ai)
    end
  end
  verbose(1, "======== %s: 开始计算出牌阶段 ========", tostring(self))
  verbose(1, "待选技能：[%s]", table.concat(table.map(skill_ai_list, function(ai) return ai.skill.name end), ", "))

  local value_func = function(ai)
    if not ai then return -500 end
    local val = ai:getEstimatedBenefit(self)
    return val or 0
  end

  local best_ret, best_val = "", -100000
  for _, ai, val in fk.sorted_pairs(skill_ai_list, value_func) do
    verbose(1, "[*] 考虑 %s (预估收益%g)", ai.skill.name, val)
    self:selectSkill(ai.skill.name, true)
    local ret, real_val = ai:think(self)
    verbose(1, "%s: 思考结果是%s, 收益是%s", ai.skill.name, json.encode(ret), json.encode(real_val))
    real_val = real_val or -100000
    -- if ret and ret ~= "" then return ret end
    if best_val < real_val then
      verbose(1, "将决策%s换成更好的%s (收益%g => %g)", json.encode(best_ret), json.encode(ret), best_val, real_val)
      best_ret, best_val = ret, real_val
    end
    self:unSelectAll()
  end
  verbose(1, "推测出最佳决策是%s", json.encode(best_ret))
  if best_ret and best_ret ~= "" then return best_ret end
  return ""
end
--]==]

-- 敌友判断相关。
-- 目前才开始，做个明身份打牌的就行了。
--========================================

---@param target ServerPlayer
function SmartAI:isFriend(target)
  return self.player:isFriend(target)
end

---@param target ServerPlayer
function SmartAI:isEnemy(target)
  return not self.player:isFriend(target)
end

-- 排序相关函数。
-- 众所周知AI要排序，再选出尽可能最佳的选项。
-- 这里提供了常见的完整排序和效率更高的不完整排序。
--=================================================

-- sorted_pairs 见 core/util.lua

---@param tab ServerPlayer[]
---@param key "hp"|"handcard"|"handcard_defense"|"value"|"taunt"|"defense"|"threat"
---@param reverse boolean?
function SmartAI:sortPlayers(tab, key, reverse)
end

---@param card integer|Card
---@return number
function SmartAI:getKeepValue(card)
  if type(card) == "number" then
    card = Fk:getCardById(card)
  end
  ---@cast card -integer

  local strategy = self:findStrategyOfSkill(AI.CardSkillStrategy, card.skill.name)
  local ret = 0
  if strategy then
    -- TODO: 可能可以是function
    ret = strategy.keep_value
  end

  -- TODO: 可能可以类似状态技一样给Room挂点状态技性质策略
  -- TODO: 这样那些策略会影响某些卡的keep value

  return ret
end

---@param tab integer[]
---@param key "keep_value"|"use_value"|"use_priority"
---@param reverse boolean?
function SmartAI:sortCards(tab, key, reverse)
  local value_tab = {}
  for _, id in ipairs(tab) do
    if key == "keep_value" then
      value_tab[id] = self:getKeepValue(id)
    end
  end

  table.sort(tab, function(a, b)
    local va, vb = value_tab[a], value_tab[b]
    if reverse then
      return a > b
    else
      return a < b
    end
  end)
end

-- 基于事件的收益推理；内置事件
--=================================================

--- 传一个函数，函数里面模拟操作，返回一系列模拟操作后的收益
---@param fn fun(logic: AIGameLogic) 此函数放置想要的事件
function SmartAI:getBenefitOfEvents(fn)
  local logic = AIGameLogic:new(self)
  fn(logic)
  return logic.benefit
end

---------------------------------------------------------------------

-- 封装一些简单策略
-- ========================================

---@class AIAskToChooseCardsParams
---@field cards integer[] @ 被选择的牌
---@field skill_name string @ 请求发动的技能名
---@field data table @ 用moveCardTo的参数表示这些牌即将被用来做什么操作

--- 选牌
---@param params AIAskToChooseCardsParams @ 各种变量
---@return integer[], integer @ 返回本次选牌收益最大的一种情况，选择的卡牌和收益
function SmartAI:askToChooseCards(params)
  local skill_name, data = params.skill_name, params.data
  local ret, benefit = { -1 }, -100000
  for _, id in ipairs(params.cards) do
    local v = self:getBenefitOfEvents(function(logic)
      logic:moveCardTo(id, data.to_place, data.target, data.reason, skill_name, nil, false, data.proposer)
    end)
    if v > benefit then
      ret, benefit = { id }, v
    end
  end
  return ret, benefit
end

return SmartAI

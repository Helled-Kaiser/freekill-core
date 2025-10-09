-- 主动技策略的分支，专用于使用卡牌相关的主动技

local ActiveStrategy = require "lunarltk.server.ai.strategies.active"

---@class AI.CardSkillStrategy : AI.ActiveStrategy
local CardSkillStrategy = ActiveStrategy[1]:subclass("AI.CardSkillStrategy")

---@return [integer, ServerPlayer[]?, any]?, number?
function CardSkillStrategy:think(ai)
  local skill_name = self.skill_name
  local estimate_val = 0 --self:getEstimatedBenefit(ai)
  local cards = table.filter(ai:getEnabledCards(), function(id)
    return Fk:getCardById(id).skill.name == skill_name
  end)
  cards = table.random(cards, math.min(#cards, 5)) --[[@as integer[] ]]
  -- local cid = table.random(cards)

  local best_ret, best_val = nil, -100000
  for _, cid in ipairs(cards) do
    ai:selectCard(cid, true)
    local ret, val = self:chooseTargets(ai)
    verbose(1, "就目前选择的这张牌，考虑[%s]，收益为%g", table.concat(table.map(ret, function(p)return tostring(p)end), "+"), val)
    val = val or -100000
    if best_val < val then
      best_ret, best_val = ret, val
    end
    if best_val >= estimate_val then break end
    ai:unSelectAll()
  end

  if best_ret then
    -- if best_val < 0 then
    --   return nil, best_val
    -- end

    best_ret = { ai:getSelectedCard().id, best_ret }
  end

  return best_ret, best_val
end

---@param val [integer, ServerPlayer[]?, any]?
function CardSkillStrategy:convertThinkResult(val)
  if not val then return end
  return {
    card = val[1],
    targets = table.map(val[2] or Util.DummyTable, Util.IdMapper),
    interaction = val[3],
  }
end

function CardSkillStrategy:chooseTargets(ai)
  local AIGameLogic, AIGameEvent = require "lunarltk.server.ai.logic"
  -- local targets = ai:getEnabledTargets()
  local logic = AIGameLogic:new(ai)
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
end

---@param logic AIGameLogic
---@param use UseCardData
function CardSkillStrategy:onUse(logic, use)
end

---@param logic AIGameLogic
---@param effect CardEffectData
function CardSkillStrategy:onEffect(logic, effect)
end

---@param spec {
---  on_use?: fun(self: AI.CardSkillStrategy, logic: AIGameLogic, use: UseCardData),
---  on_effect?: fun(self: AI.CardSkillStrategy, logic: AIGameLogic, effect: CardEffectData),
---}
---@return AI.CardSkillStrategy
local function newCardSkillStrategy(spec)
  local ret = CardSkillStrategy:new()

  if spec.on_use then ret.onUse = spec.on_use end
  if spec.on_effect then ret.onEffect = spec.on_effect end

  return ret
end

return {
  CardSkillStrategy,
  newCardSkillStrategy,
}

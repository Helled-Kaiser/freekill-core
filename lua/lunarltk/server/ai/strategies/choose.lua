local AIStrategy = require "lunarltk.server.ai.strategy"

---@class AI.ChooseStrategy : AIStrategy
local ChooseStrategy = AIStrategy:subclass("AI.ChooseStrategy")

---@param ai SmartAI
---@return integer[]?, number?
function ChooseStrategy:chooseCards(ai)
end

---@param ai SmartAI
---@return integer[]?, number?
function ChooseStrategy:choosePlayers(ai)
end

---@param spec {
---  choose_cards?: (fun(self: AI.ActiveStrategy, ai: SmartAI): integer[]?, number?),
---  choose_players?: (fun(self: AI.ActiveStrategy, ai: SmartAI): integer[]?, number?),
---}
---@return AI.ChooseStrategy
local function newChooseStrategy(spec)
  local ret = ChooseStrategy:new()
  if spec.choose_cards then
    ret.chooseCards = spec.choose_cards
  end

  if spec.choose_players then
    ret.choosePlayers = spec.choose_players
  end

  return ret
end

return {
  ChooseStrategy,
  newChooseStrategy,
}


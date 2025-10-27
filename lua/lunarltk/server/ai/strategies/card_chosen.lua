local AIStrategy = require "lunarltk.server.ai.strategy"

---@class AI.CardChosenStrategy : AIStrategy
local CardChosenStrategy = AIStrategy:subclass("AI.CardChosenStrategy")

---@return [integer, any]?, number?
function CardChosenStrategy:think(ai)
end

---@param val [integer?, any]? 
function CardChosenStrategy:convertThinkResult(val)
  if not val then return end
  return {
    card = val[1],
    interaction = val[2],
  }
end


---@param spec {
--- think?: fun(self: AI.CardChosenStrategy, ai: SmartAI)
--- }
---@return AI.CardChosenStrategy
local function newCardChosenStrategy(spec)
  local ret = CardChosenStrategy:new()

  if spec.think then ret.think = spec.think end

  return ret
end

return {
  CardChosenStrategy,
  newCardChosenStrategy,
}

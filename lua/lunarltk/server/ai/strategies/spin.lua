local AIStrategy = require "lunarltk.server.ai.strategy"

---@class AI.SpinStrategy : AIStrategy
local SpinStrategy = AIStrategy:subclass("AI.SpinStrategy")

---@param ai SmartAI
---@return integer?, number?
function SpinStrategy:chooseInteraction(ai)
end

---@param spec {
---  choose_interaction?: (fun(self: AI.SpinStrategy, ai: SmartAI): integer?, number?),
---}
---@return AI.SpinStrategy
local function newSpinStrategy(spec)
  local ret = SpinStrategy:new()
  if spec.choose_interaction then
    ret.chooseInteraction = spec.choose_interaction
  end

  return ret
end

return {
  SpinStrategy,
  newSpinStrategy,
}


---@class AIStrategy : Object
local AIStrategy = class("AIStrategy")

--- 判断这个strategy是否是需要的 一般直接返true
---@param ai SmartAI
function AIStrategy:matchContext(ai)
  return true
end

return AIStrategy

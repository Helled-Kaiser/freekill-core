local active = require 'lunarltk.server.ai.strategies.active'
local card_skill = require 'lunarltk.server.ai.strategies.card_skill'
local invoke = require 'lunarltk.server.ai.strategies.invoke'

return {
  ActiveStrategy = active[1],
  newActiveStrategy = active[2],

  CardSkillStrategy = card_skill[1],
  newCardSkillStrategy = card_skill[2],

  InvokeStrategy = invoke[1],
  newInvokeStrategy = invoke[2],
}

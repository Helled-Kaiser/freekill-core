local active = require 'lunarltk.server.ai.strategies.active'
local card_skill = require 'lunarltk.server.ai.strategies.card_skill'
local invoke = require 'lunarltk.server.ai.strategies.invoke'
local choice = require 'lunarltk.server.ai.strategies.choice'
local card_chosen = require 'lunarltk.server.ai.strategies.card_chosen'
local discard = require 'lunarltk.server.ai.strategies.discard'
local choose = require 'lunarltk.server.ai.strategies.choose'
local spin = require 'lunarltk.server.ai.strategies.spin'
local move_board = require 'lunarltk.server.ai.strategies.move_board'

return {
  ActiveStrategy = active[1],
  newActiveStrategy = active[2],

  CardSkillStrategy = card_skill[1],
  newCardSkillStrategy = card_skill[2],

  InvokeStrategy = invoke[1],
  newInvokeStrategy = invoke[2],

  ChoiceStrategy = choice[1],
  newChoiceStrategy = choice[2],

  CardChosenStrategy = card_chosen[1],
  newCardChosenStrategy = card_chosen[2],

  DiscardStrategy = discard[1],
  newDiscardStrategy = discard[2],

  ChooseStrategy = choose[1],
  newChooseStrategy = choose[2],

  SpinStrategy = spin[1],
  newSpinStrategy = spin[2],

  MoveBoardStrategy = move_board[1],
  newMoveBoardStrategy = move_board[2],
}

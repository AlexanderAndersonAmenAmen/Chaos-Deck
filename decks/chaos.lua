CHAOSDECK = CHAOSDECK or {}

local CHAOS_SUIT = {
    smiles = 'chaos_smiles',
    bananas = 'chaos_bananas',
    dices = 'chaos_dices',
    rubies = 'chaos_rubies',
    flowers = 'chaos_flowers',
    petals = 'chaos_petals',
    free_parking_spots = 'chaos_free_parking_spots',
    wraiths = 'chaos_wraiths',
    beans = 'chaos_beans',
}

CHAOSDECK.CHAOS_SUITS = CHAOS_SUIT

local function chaos_suit_pool_enabled(args)
    if args and args.initial_deck then return false end
    if not (G and G.STAGES and G.STAGE == G.STAGES.RUN and G.GAME) then return false end
    if CHAOSDECK.config and CHAOSDECK.config.enableChaosSuits == true then return true end
    return G.GAME.modifiers ~= nil and G.GAME.modifiers.chaos_chaos_deck == true or false
end

CHAOSDECK.chaos_suit_pool_enabled = chaos_suit_pool_enabled
CHAOSDECK.is_chaos_run_active = chaos_suit_pool_enabled

local suit_defs = {
    { key = 'smiles', card_key = 'M', y = 0, ui_x = 0, colour = 'c9a500', tooltip = 'chaos_suit_smiles' },
    { key = 'bananas', card_key = 'B', y = 1, ui_x = 1, colour = '9bb031', tooltip = 'chaos_suit_bananas' },
    { key = 'dices', card_key = 'I', y = 2, ui_x = 2, colour = '479d7a', tooltip = 'chaos_suit_dices' },
    { key = 'rubies', card_key = 'R', y = 3, ui_x = 3, colour = 'ff5d9b', tooltip = 'chaos_suit_rubies' },
    { key = 'flowers', card_key = 'F', y = 4, ui_x = 4, colour = '6CA2A6', tooltip = 'chaos_suit_flowers' },
    { key = 'petals', card_key = 'P', y = 5, ui_x = 5, colour = '7a73bb', tooltip = 'chaos_suit_petals' },
    { key = 'free_parking_spots', card_key = 'G', y = 6, ui_x = 6, colour = '4189e9', tooltip = 'chaos_suit_free_parking_spots' },
    { key = 'wraiths', card_key = 'W', y = 7, ui_x = 7, colour = '4f6367', tooltip = 'chaos_suit_wraiths' },
    { key = 'beans', card_key = 'E', y = 8, ui_x = 8, colour = '6e8965', tooltip = 'chaos_suit_beans' },
}

for _, def in ipairs(suit_defs) do
    local suit_key = def.key
    local card_key = def.card_key
    local row = def.y
    local colour = def.colour
    local ui_x = def.ui_x or row
    local tooltip = def.tooltip
    local full_key = 'chaos_' .. suit_key
    if SMODS and SMODS.Suit and SMODS.Suits and not SMODS.Suits[full_key] then
        SMODS.Suit {
            key = suit_key,
            card_key = card_key,
            pos = { y = row },
            ui_pos = { x = ui_x, y = 0 },
            lc_atlas = 'SUITS',
            hc_atlas = 'SUITS',
            lc_ui_atlas = 'SUITS_UI',
            hc_ui_atlas = 'SUITS_UI',
            lc_colour = colour,
            hc_colour = colour,
            in_pool = function(self, args) return chaos_suit_pool_enabled(args) end,
            loc_vars = function(self, info_queue, card)
                if info_queue then
                    local vars = nil
                    if suit_key == 'free_parking_spots' or suit_key == 'bananas' then
                        local denominator = suit_key == 'bananas' and 6 or 2
                        local probability_key = suit_key == 'bananas'
                            and 'chaos_chaos_bananas'
                            or 'chaos_chaos_free_parking'
                        local numerator = 1
                        if SMODS and type(SMODS.get_probability_vars) == 'function' then
                            numerator, denominator = SMODS.get_probability_vars(
                                card or self, 1, denominator, probability_key
                            )
                        elseif G and G.GAME and G.GAME.probabilities then
                            numerator = G.GAME.probabilities.normal or numerator
                        end
                        vars = { numerator, denominator }
                    end
                    info_queue[#info_queue + 1] = { set = 'Other', key = tooltip, vars = vars }
                end
            end,
        }
    end
end

local chaos_suit_colours = {}
for _, def in ipairs(suit_defs) do
    chaos_suit_colours['chaos_' .. def.key] = HEX(def.colour)
end

local function apply_chaos_suit_colours()
    if not G or not G.C then return end
    G.C.SO_1 = G.C.SO_1 or {}
    G.C.SO_2 = G.C.SO_2 or {}
    G.C.SUITS = G.C.SUITS or {}
    for key, colour in pairs(chaos_suit_colours) do
        local suit = SMODS and SMODS.Suits and SMODS.Suits[key]
        if suit then
            suit.lc_colour = colour
            suit.hc_colour = colour
        end
        G.C.SO_1[key] = colour
        G.C.SO_2[key] = colour
        G.C.SUITS[key] = colour
        if G.ARGS and G.ARGS.LOC_COLOURS then
            G.ARGS.LOC_COLOURS[key] = colour
        end
    end
end

apply_chaos_suit_colours()
CHAOSDECK.apply_chaos_suit_colours = apply_chaos_suit_colours

if loc_colour and not CHAOSDECK._chaos_loc_colour_hook then
    local chaos_loc_colour_ref = loc_colour
    function loc_colour(_c, _default)
        local colour = chaos_suit_colours[_c]
        if colour then return colour end
        return chaos_loc_colour_ref(_c, _default)
    end
    CHAOSDECK._chaos_loc_colour_hook = true
end

local function chaos_ability_source(card)
    if card and CHAOSDECK.is_faceless and CHAOSDECK.is_faceless(card) and CHAOSDECK.faceless_copy_target then
        return CHAOSDECK.faceless_copy_target(card) or card
    end
    return card
end

local function base_suit(card, suit_key)
    local source = chaos_ability_source(card)
    return source and source.base and source.base.suit == suit_key
end

local function active_suit(card, suit_key)
    return base_suit(card, suit_key) and not card.debuff
end

local chaos_suit_bridge_runtime = nil

local function chaos_has_no_suit(card)
    if CHAOSDECK.safe_has_no_suit then return CHAOSDECK.safe_has_no_suit(card) end
    if SMODS and type(SMODS.has_no_suit) == 'function' then
        local ok, result = pcall(SMODS.has_no_suit, card)
        if ok then return result == true end
    end
    return false
end

local function chaos_bridge_trigger(card, suit_key)
    return active_suit(card, suit_key) and not chaos_has_no_suit(card)
end

local function chaos_bridge_state(played)
    local state = {
        rubies = false,
        petals = false,
        cards = setmetatable({}, { __mode = 'k' }),
    }
    for _, card in ipairs(played or {}) do
        state.cards[card] = true
        if chaos_bridge_trigger(card, CHAOS_SUIT.rubies) then state.rubies = true end
        if chaos_bridge_trigger(card, CHAOS_SUIT.petals) then state.petals = true end
    end
    if not state.rubies and not state.petals then return nil end
    return state
end

local function chaos_bridge_matches(card, suit, first, second, trigger_suit)
    local source = chaos_ability_source(card)
    local printed = source and source.base and source.base.suit
    return (printed == first or printed == second or printed == trigger_suit)
        and (suit == first or suit == second)
end

local function chaos_current_bridge_state()
    if G and G.play and type(G.play.cards) == 'table' and #G.play.cards > 0 then
        return chaos_bridge_state(G.play.cards)
    end
    if G and G.hand and type(G.hand.highlighted) == 'table' and #G.hand.highlighted > 0 then
        return chaos_bridge_state(G.hand.highlighted)
    end
end

local chaos_is_suit_ref = Card.is_suit
if chaos_is_suit_ref and not CHAOSDECK._chaos_is_suit_hook then
    function Card:is_suit(suit, bypass_debuff, flush_calc, ...)
        local state = chaos_suit_bridge_runtime or chaos_current_bridge_state()
        if state and state.cards[self] and not chaos_has_no_suit(self)
            and (not self.debuff or bypass_debuff or flush_calc)
        then
            if state.rubies and chaos_bridge_matches(self, suit, 'Hearts', 'Diamonds', CHAOS_SUIT.rubies) then return true end
            if state.petals and chaos_bridge_matches(self, suit, 'Spades', 'Clubs', CHAOS_SUIT.petals) then return true end
        end
        return chaos_is_suit_ref(self, suit, bypass_debuff, flush_calc, ...)
    end
    CHAOSDECK._chaos_is_suit_hook = true
end

if type(evaluate_poker_hand) == 'function' and not CHAOSDECK._chaos_evaluate_poker_hand_hook then
    CHAOSDECK._chaos_evaluate_poker_hand_hook = true
    local chaos_evaluate_poker_hand_ref = evaluate_poker_hand
    function evaluate_poker_hand(hand, ...)
        local previous = chaos_suit_bridge_runtime
        chaos_suit_bridge_runtime = chaos_bridge_state(hand)
        local results = CHAOSDECK.pack(chaos_evaluate_poker_hand_ref(hand, ...))
        chaos_suit_bridge_runtime = previous
        return unpack(results, 1, results.n)
    end
end

if G and G.FUNCS and type(G.FUNCS.get_poker_hand_info) == 'function'
    and not CHAOSDECK._chaos_suit_bridge_hand_info_hook
then
    CHAOSDECK._chaos_suit_bridge_hand_info_hook = true
    local chaos_get_poker_hand_info_ref = G.FUNCS.get_poker_hand_info
    function G.FUNCS.get_poker_hand_info(...)
        local previous = chaos_suit_bridge_runtime
        local selected = select(1, ...)
        if type(selected) == 'table' then
            chaos_suit_bridge_runtime = chaos_bridge_state(selected)
        end
        local results = CHAOSDECK.pack(chaos_get_poker_hand_info_ref(...))
        chaos_suit_bridge_runtime = previous
        return unpack(results, 1, results.n)
    end
end

if G and G.FUNCS and type(G.FUNCS.evaluate_play) == 'function'
    and not CHAOSDECK._chaos_suit_bridge_evaluate_play_hook
then
    CHAOSDECK._chaos_suit_bridge_evaluate_play_hook = true
    local chaos_evaluate_play_ref = G.FUNCS.evaluate_play
    function G.FUNCS.evaluate_play(...)
        local previous = chaos_suit_bridge_runtime
        local played = G and G.play and G.play.cards or {}
        chaos_suit_bridge_runtime = chaos_bridge_state(played)
        local results = CHAOSDECK.pack(chaos_evaluate_play_ref(...))
        chaos_suit_bridge_runtime = previous
        return unpack(results, 1, results.n)
    end
end

local function played_cards(context)
    if context and type(context.full_hand) == 'table' and #context.full_hand > 0 then
        return context.full_hand
    end
    return G and G.play and G.play.cards or {}
end

local function probability_dice_cards(context)
    if context and type(context.full_hand) == 'table' and #context.full_hand > 0 then
        return context.full_hand
    end
    if context and not context.from_roll and G and G.hand and type(G.hand.highlighted) == 'table'
        and #G.hand.highlighted > 0
    then
        return G.hand.highlighted
    end
    return G and G.play and G.play.cards or {}
end

local function scoring_cards(context)
    if context and type(context.scoring_hand) == 'table' then return context.scoring_hand end
    return {}
end

local function unique_printed_suits(cards)
    local seen = {}
    for _, card in ipairs(cards or {}) do
        local source = chaos_ability_source(card)
        if source and source.base and source.base.suit and not (SMODS and SMODS.has_no_suit and SMODS.has_no_suit(card)) then
            seen[source.base.suit] = true
        end
    end
    local count = 0
    for _ in pairs(seen) do count = count + 1 end
    return count
end

local function count_active_dices(cards)
    local count = 0
    for _, card in ipairs(cards or {}) do
        if active_suit(card, CHAOS_SUIT.dices) then count = count + 1 end
    end
    return count
end

function CHAOSDECK.calculate_chaos_suits(context)
    if type(context) ~= 'table' then return nil end

    if context.mod_probability then
        local count = count_active_dices(probability_dice_cards(context))
        if count > 0 then
            return { numerator = (tonumber(context.numerator) or 0) + count }
        end
    end

    if context.repetition and context.cardarea == G.play and context.other_card
        and active_suit(context.other_card, CHAOS_SUIT.wraiths)
    then
        return { repetitions = 1 }
    end

    if context.individual and context.cardarea == G.play and context.other_card and not context.repetition then
        local card = context.other_card

        if active_suit(card, CHAOS_SUIT.bananas) then
            return { mult = 3 }
        end

        if active_suit(card, CHAOS_SUIT.smiles) then
            local faces = 0
            for _, played_card in ipairs(played_cards(context)) do
                if played_card and not played_card.debuff and played_card.is_face and played_card:is_face() then
                    faces = faces + 1
                end
            end
            if faces > 0 then return { mult = faces } end
        end

        if active_suit(card, CHAOS_SUIT.flowers) then
            local gain = unique_printed_suits(played_cards(context)) * 3
            if gain > 0 then
                card.ability = card.ability or {}
                card.ability.perma_bonus = (tonumber(card.ability.perma_bonus) or 0) + gain
                return {
                    chips = gain,
                    remove_default_message = true,
                    message = localize('k_upgrade_ex'),
                    colour = G.C.CHIPS,
                }
            end
        end
    end

    if context.destroy_card and active_suit(context.destroy_card, CHAOS_SUIT.bananas)
        and type(context.scoring_hand) == 'table'
        and not context.repetition
    then
        local scored = false
        for _, scoring_card in ipairs(context.scoring_hand) do
            if scoring_card == context.destroy_card then
                scored = true
                break
            end
        end
        if scored
            and SMODS and type(SMODS.pseudorandom_probability) == 'function'
            and SMODS.pseudorandom_probability(context.destroy_card, 'chaos_chaos_bananas', 1, 6)
        then
            return { remove = true }
        end
    end

    if context.individual and context.cardarea == G.hand and context.other_card and not context.repetition
        and not context.end_of_round
        and type(context.full_hand) == 'table' and #context.full_hand > 0
        and active_suit(context.other_card, CHAOS_SUIT.free_parking_spots)
        and SMODS and type(SMODS.pseudorandom_probability) == 'function'
        and SMODS.pseudorandom_probability(context.other_card, 'chaos_chaos_free_parking', 1, 2)
    then
        SMODS.calculate_effect({ dollars = 1 }, context.other_card)
        return
    end
end

local chaos_wraith_state = setmetatable({}, { __mode = 'k' })
local chaos_wraith_refresh_pending = setmetatable({}, { __mode = 'k' })

local function chaos_runtime_area(area)
    return area ~= nil and G ~= nil and ((G.hand ~= nil and area == G.hand) or (G.play ~= nil and area == G.play))
end

local function chaos_recalc_debuff(card)
    if not (card and SMODS and type(SMODS.recalc_debuff) == 'function') then return end
    if not (G and G.GAME and G.GAME.blind) then return end
    SMODS.recalc_debuff(card)
end

local function chaos_card_id(card, fallback)
    return tostring(card and (card.playing_card or card.sort_id or card.ID) or fallback)
end

local function chaos_area_signature(area)
    if not (area and type(area.cards) == 'table') then return '' end
    local parts = {}
    for i, card in ipairs(area.cards) do
        parts[i] = chaos_card_id(card, i)
    end
    return table.concat(parts, '|')
end

local function chaos_build_wraith_state(area)
    local state = chaos_wraith_state[area] or {}
    local adjacent = setmetatable({}, { __mode = 'k' })
    local cards = area and area.cards or {}
    local has_wraith = false
    for i, card in ipairs(cards) do
        if base_suit(card, CHAOS_SUIT.wraiths) then has_wraith = true end
        local beside_wraith = base_suit(cards[i - 1], CHAOS_SUIT.wraiths)
            or base_suit(cards[i + 1], CHAOS_SUIT.wraiths)
        if beside_wraith and not base_suit(card, CHAOS_SUIT.wraiths) then
            adjacent[card] = true
        end
    end
    state.adjacent = adjacent
    state.has_wraith = has_wraith
    state.signature = has_wraith and chaos_area_signature(area) or ''
    chaos_wraith_state[area] = state
    return state
end

local function chaos_needs_order_tracking(area)
    local state = chaos_wraith_state[area]
    if state and state.has_wraith then return true end
    for _, card in ipairs(area and area.cards or {}) do
        if base_suit(card, CHAOS_SUIT.wraiths) then return true end
    end
    return false
end

function CHAOSDECK.chaos_wraith_adjacent(card)
    local area = card and card.area
    if not chaos_runtime_area(area) then return false end
    local state = chaos_wraith_state[area] or chaos_build_wraith_state(area)
    return state.adjacent[card] == true
end

function CHAOSDECK.chaos_deck_preview_is_suit(card, suit)
    if not (card and card.is_suit) then return false end
    if CHAOSDECK.chaos_wraith_adjacent(card) then
        return card:is_suit(suit, true)
    end
    return card:is_suit(suit)
end

local chaos_set_debuff_ref = SMODS.current_mod.set_debuff
SMODS.current_mod.set_debuff = function(card)
    if chaos_set_debuff_ref then
        local result = chaos_set_debuff_ref(card)
        if result == true or result == 'prevent_debuff' then return result end
    end
    if CHAOSDECK.chaos_wraith_adjacent(card) then return true end
end

local function strip_legacy_bean_limit(card)
    if not (card and card.ability and card.ability.chaos_bean_card_limit) then return end
    local value = (tonumber(card.ability.card_limit) or 0) - 1
    card.ability.card_limit = value ~= 0 and value or nil
    card.ability.chaos_bean_card_limit = nil
end

local function set_bean_hand_bonus(card, enabled)
    if not (card and G and G.hand and G.hand.config) then return end
    card.ability = card.ability or {}
    strip_legacy_bean_limit(card)
    local applied = card.ability.chaos_bean_hand_bonus == true
    enabled = enabled == true
    if enabled == applied then return end
    G.hand.config.card_limit = math.max(0, (tonumber(G.hand.config.card_limit) or 0) + (enabled and 1 or -1))
    card.ability.chaos_bean_hand_bonus = enabled or nil
end

local function sync_bean_hand_bonus(card)
    set_bean_hand_bonus(card, card and card.area == (G and G.hand) and base_suit(card, CHAOS_SUIT.beans))
end

function CHAOSDECK.refresh_chaos_area(area)
    if not chaos_runtime_area(area) then return end
    local previous = chaos_wraith_state[area]
    local previous_adjacent = previous and previous.adjacent or {}
    local state = chaos_build_wraith_state(area)
    if area == G.hand then
        for _, card in ipairs(area.cards or {}) do sync_bean_hand_bonus(card) end
    end
    for _, card in ipairs(area.cards or {}) do
        if (previous_adjacent[card] == true) ~= (state.adjacent[card] == true) then
            chaos_recalc_debuff(card)
        end
    end
end

local function schedule_chaos_area_refresh(area)
    if area == nil or not chaos_runtime_area(area) or chaos_wraith_refresh_pending[area] then return end
    chaos_wraith_refresh_pending[area] = true
    local function refresh()
        chaos_wraith_refresh_pending[area] = nil
        CHAOSDECK.refresh_chaos_area(area)
        return true
    end
    if G and G.E_MANAGER and Event then
        G.E_MANAGER:add_event(Event({ trigger = 'immediate', blockable = false, func = refresh }))
    else
        refresh()
    end
end

if CardArea and type(CardArea.emplace) == 'function' and not CHAOSDECK._chaos_area_emplace_hook then
    CHAOSDECK._chaos_area_emplace_hook = true
    local chaos_emplace_ref = CardArea.emplace
    function CardArea:emplace(card, ...)
        local bean_bonus = self == (G and G.hand) and base_suit(card, CHAOS_SUIT.beans)
        if bean_bonus then set_bean_hand_bonus(card, true) end
        local results = CHAOSDECK.pack(chaos_emplace_ref(self, card, ...))
        if bean_bonus and card.area ~= self then set_bean_hand_bonus(card, false) end
        if chaos_runtime_area(self) then schedule_chaos_area_refresh(self) end
        return ((table and table.unpack) or unpack)(results, 1, results.n)
    end
end

if CardArea and type(CardArea.remove_card) == 'function' and not CHAOSDECK._chaos_area_remove_hook then
    CHAOSDECK._chaos_area_remove_hook = true
    local chaos_remove_ref = CardArea.remove_card
    function CardArea:remove_card(card, ...)
        local was_runtime = chaos_runtime_area(self)
        local was_hand = self == (G and G.hand) and card and card.ability and card.ability.chaos_bean_hand_bonus
        local results = CHAOSDECK.pack(chaos_remove_ref(self, card, ...))
        if was_hand then set_bean_hand_bonus(card, false) end
        if was_runtime then
            schedule_chaos_area_refresh(self)
            chaos_recalc_debuff(card)
        end
        return ((table and table.unpack) or unpack)(results, 1, results.n)
    end
end

if CardArea and type(CardArea.align_cards) == 'function' and not CHAOSDECK._chaos_area_align_hook then
    CHAOSDECK._chaos_area_align_hook = true
    local chaos_align_ref = CardArea.align_cards
    function CardArea:align_cards(...)
        local results = CHAOSDECK.pack(chaos_align_ref(self, ...))
        if self == (G and G.hand) and chaos_needs_order_tracking(self) then
            local state = chaos_wraith_state[self]
            local signature = chaos_area_signature(self)
            if not state or state.signature ~= signature then schedule_chaos_area_refresh(self) end
        end
        return ((table and table.unpack) or unpack)(results, 1, results.n)
    end
end

if Card and type(Card.set_base) == 'function' and not CHAOSDECK._chaos_set_base_hook then
    CHAOSDECK._chaos_set_base_hook = true
    local chaos_set_base_ref = Card.set_base
    function Card:set_base(base_card, ...)
        local results = CHAOSDECK.pack(chaos_set_base_ref(self, base_card, ...))
        if self.area == (G and G.hand) then sync_bean_hand_bonus(self) end
        if chaos_runtime_area(self.area) then schedule_chaos_area_refresh(self.area) end
        return ((table and table.unpack) or unpack)(results, 1, results.n)
    end
end

if Card and type(Card.load) == 'function' and not CHAOSDECK._chaos_card_load_hook then
    CHAOSDECK._chaos_card_load_hook = true
    local chaos_card_load_ref = Card.load
    function Card:load(...)
        local results = CHAOSDECK.pack(chaos_card_load_ref(self, ...))
        strip_legacy_bean_limit(self)
        if self.area == (G and G.hand) then sync_bean_hand_bonus(self) end
        if chaos_runtime_area(self.area) then schedule_chaos_area_refresh(self.area) end
        return ((table and table.unpack) or unpack)(results, 1, results.n)
    end
end

local chaos_cards = {
    { suit = CHAOS_SUIT.smiles, ranks = { '10', '9', '8', '7' } },
    { suit = CHAOS_SUIT.bananas, ranks = { '6', '5', '4', '3' } },
    { suit = CHAOS_SUIT.dices, ranks = { '2', '10', '9', '8' } },
    { suit = CHAOS_SUIT.rubies, ranks = { '7', '6', '5', '4' } },
    { suit = CHAOS_SUIT.flowers, ranks = { '3', '2', '10', '9' } },
    { suit = CHAOS_SUIT.petals, ranks = { '8', '7', '6', '5' } },
    { suit = CHAOS_SUIT.free_parking_spots, ranks = { '4', '3', '2', '10' } },
    { suit = CHAOS_SUIT.wraiths, ranks = { '9', '8', '7', '6' } },
    { suit = CHAOS_SUIT.beans, ranks = { '5', '4', '3', '2' } },
}

local function chaos_starting_specs()
    local specs = {}
    for _, group in ipairs(chaos_cards) do
        for _, rank in ipairs(group.ranks) do
            specs[#specs + 1] = { suit = group.suit, rank = rank }
        end
    end
    return specs
end

local function add_chaos_starting_cards()
    if not (G and G.GAME and G.deck and G.playing_cards and SMODS and type(SMODS.change_base) == 'function') then
        return false
    end
    if G.GAME.chaos_chaos_cards_added then return true end

    local numbered = {}
    for _, card in ipairs(G.playing_cards) do
        local id = card and card.base and tonumber(card.base.id)
        if id and id >= 2 and id <= 10 then numbered[#numbered + 1] = card end
    end

    local specs = chaos_starting_specs()
    if #numbered ~= #specs then return false end
    for i, card in ipairs(numbered) do
        SMODS.change_base(card, specs[i].suit, specs[i].rank)
    end

    if G.deck.set_ranks then G.deck:set_ranks() end
    if G.deck.align_cards then G.deck:align_cards() end
    if G.deck.hard_set_cards then G.deck:hard_set_cards() end
    if type(check_for_unlock) == 'function' then check_for_unlock({ type = 'modify_deck', deck = G.deck }) end
    G.GAME.chaos_chaos_cards_added = true
    return true
end

local CHAOS_SUIT_SET = {}
for _, suit_key in pairs(CHAOS_SUIT) do CHAOS_SUIT_SET[suit_key] = true end

if type(create_UIBox_customize_deck) == 'function' and not CHAOSDECK._chaos_customize_deck_options_hook then
    CHAOSDECK._chaos_customize_deck_options_hook = true
    local create_UIBox_customize_deck_ref = create_UIBox_customize_deck
    function create_UIBox_customize_deck(...)
        local suit_class = SMODS and SMODS.Suit
        local obj_list_ref = suit_class and suit_class.obj_list
        local scoped_obj_list

        if type(obj_list_ref) == 'function' then
            scoped_obj_list = function(self, ...)
                local results = CHAOSDECK.pack(obj_list_ref(self, ...))
                local list = results[1]
                if type(list) == 'table' then
                    local filtered = {}
                    for _, suit in ipairs(list) do
                        local suit_key = suit and suit.key
                        if not (suit_key and CHAOS_SUIT_SET[suit_key]) then
                            filtered[#filtered + 1] = suit
                        end
                    end
                    results[1] = filtered
                end
                return ((table and table.unpack) or unpack)(results, 1, results.n)
            end
            suit_class.obj_list = scoped_obj_list
        end

        local results = CHAOSDECK.pack(pcall(create_UIBox_customize_deck_ref, ...))

        if suit_class and scoped_obj_list and suit_class.obj_list == scoped_obj_list then
            suit_class.obj_list = obj_list_ref
        end

        if not results[1] then error(results[2], 0) end
        return ((table and table.unpack) or unpack)(results, 2, results.n)
    end
end

local CHAOS_TAROTS = {
    c_sun = {
        vanilla = 'Hearts',
        suits = { 'Hearts', CHAOS_SUIT.rubies, CHAOS_SUIT.flowers },
        pos = { x = 4, y = 2 },
        seed = 'chaos_tarot_sun',
    },
    c_star = {
        vanilla = 'Diamonds',
        suits = { 'Diamonds', CHAOS_SUIT.rubies, CHAOS_SUIT.bananas, CHAOS_SUIT.smiles },
        pos = { x = 0, y = 3 },
        seed = 'chaos_tarot_star',
    },
    c_moon = {
        vanilla = 'Clubs',
        suits = { 'Clubs', CHAOS_SUIT.petals, CHAOS_SUIT.free_parking_spots },
        pos = { x = 3, y = 2 },
        seed = 'chaos_tarot_moon',
    },
    c_world = {
        vanilla = 'Spades',
        suits = { 'Spades', CHAOS_SUIT.petals, CHAOS_SUIT.beans, CHAOS_SUIT.wraiths },
        pos = { x = 2, y = 2 },
        seed = 'chaos_tarot_world',
    },
}

CHAOSDECK.CHAOS_TAROTS = CHAOS_TAROTS

local function chaos_tarots_enabled()
    return chaos_suit_pool_enabled({ source = 'chaos_tarot' })
end

CHAOSDECK.chaos_tarots_enabled = chaos_tarots_enabled

local function chaos_tarot_definition(card_or_center)
    local center = card_or_center
    if card_or_center and card_or_center.config and card_or_center.config.center then
        center = card_or_center.config.center
    end
    local key = center and center.key
    return key and CHAOS_TAROTS[key] or nil, key
end

local function chaos_tarot_valid_target(def, target)
    if not (def and target) then return false end
    for _, suit in ipairs(def.suits) do
        if suit == target then return true end
    end
    return false
end

local function chaos_tarot_roll_target(def)
    if not def then return nil end
    if type(pseudorandom_element) == 'function' and type(pseudoseed) == 'function' then
        return pseudorandom_element(def.suits, pseudoseed(def.seed))
    end
    return def.suits[math.random(#def.suits)]
end

local function chaos_tarot_detach_consumeable(card, center, target)
    if not (card and card.ability and center and center.config) then return end
    local config = {}
    for k, v in pairs(center.config) do config[k] = v end
    config.suit_conv = target
    card.ability.consumeable = config
end

local function chaos_tarot_refresh_ability(card, reroll)
    local def = chaos_tarot_definition(card)
    if not def or not card.ability then return end
    if chaos_tarots_enabled() then
        local target = card.ability.chaos_tarot_suit or card.chaos_tarot_suit
        if reroll or not chaos_tarot_valid_target(def, target) then
            target = chaos_tarot_roll_target(def)
        end
        card.chaos_tarot_suit = target
        card.ability.chaos_tarot_suit = target
        chaos_tarot_detach_consumeable(card, card.config and card.config.center, target)
    else
        card.chaos_tarot_suit = nil
        card.ability.chaos_tarot_suit = nil
        chaos_tarot_detach_consumeable(card, card.config and card.config.center, def.vanilla)
    end
end

local function chaos_tarot_sprite_pos_available(atlas, pos)
    if not (atlas and pos) then return false end
    local image = atlas.image
    if image and type(image.getDimensions) == 'function' then
        local width, height = image:getDimensions()
        if width and height and width > 0 and height > 0 then
            local scale = width >= 700 and 2 or 1
            local columns = math.floor(width / (71 * scale))
            local rows = math.floor(height / (95 * scale))
            return pos.x >= 0 and pos.x < columns and pos.y >= 0 and pos.y < rows
        end
    end
    return pos.x >= 0 and pos.x < 5 and pos.y >= 0 and pos.y < 4
end

local function chaos_tarot_apply_sprite(card)
    local def = chaos_tarot_definition(card)
    if not (def and card and card.children and card.children.center) then return end
    if not chaos_tarots_enabled() then return end
    local atlas = G and G.ASSET_ATLAS and (G.ASSET_ATLAS.chaos_Consumables or G.ASSET_ATLAS.Consumables)
    if not chaos_tarot_sprite_pos_available(atlas, def.pos) then return end
    card.children.center.atlas = atlas
    if card.children.center.set_sprite_pos then
        card.children.center:set_sprite_pos(def.pos)
    end
end

local function chaos_tarot_loc_vars(center, card)
    local def = chaos_tarot_definition(center)
    if not def then return {} end
    local target = def.vanilla
    if chaos_tarots_enabled() and card and card.ability then
        target = card.ability.chaos_tarot_suit or target
    end
    local max_highlighted = center.config and center.config.max_highlighted or 3
    local suit_name = localize(target, 'suits_plural')
    local colour = G and G.C and G.C.SUITS and G.C.SUITS[target] or nil
    colour = colour or (G and G.C and (G.C.FILTER or G.C.ATTENTION or G.C.WHITE)) or { 1, 1, 1, 1 }
    return { vars = { max_highlighted, suit_name, colours = { colour } } }
end

if Card and type(Card.change_suit) == 'function' and not CHAOSDECK._chaos_change_suit_hook then
    CHAOSDECK._chaos_change_suit_hook = true
    local chaos_change_suit_ref = Card.change_suit
    function Card:change_suit(new_suit, ...)
        if CHAOS_SUIT_SET[new_suit] and SMODS and type(SMODS.change_base) == 'function' then
            SMODS.change_base(self, new_suit, nil)
            if G and G.GAME and G.GAME.blind and G.GAME.blind.debuff_card then
                G.GAME.blind:debuff_card(self)
            end
            return
        end
        return chaos_change_suit_ref(self, new_suit, ...)
    end
end

if SMODS and SMODS.Consumable and type(SMODS.Consumable.take_ownership) == 'function'
    and not CHAOSDECK._chaos_tarot_ownership
then
    CHAOSDECK._chaos_tarot_ownership = true
    for _, short_key in ipairs({ 'sun', 'star', 'moon', 'world' }) do
        SMODS.Consumable:take_ownership(short_key, {
            set_ability = function(self, card, initial, delay_sprites)
                local def = chaos_tarot_definition(self)
                local reroll = chaos_tarots_enabled() and not chaos_tarot_valid_target(def, card.chaos_tarot_suit)
                chaos_tarot_refresh_ability(card, reroll)
            end,
            loc_vars = function(self, info_queue, card)
                return chaos_tarot_loc_vars(self, card)
            end,
            set_sprites = function(self, card, front)
                chaos_tarot_apply_sprite(card)
                card.chaos_tarot_visual = chaos_tarots_enabled()
            end,
            load = function(self, card, card_table, other_card)
                chaos_tarot_refresh_ability(card, false)
                chaos_tarot_apply_sprite(card)
                card.chaos_tarot_visual = chaos_tarots_enabled()
            end,
            update = function(self, card, dt)
                local active = chaos_tarots_enabled()
                if card.chaos_tarot_visual ~= active then
                    chaos_tarot_refresh_ability(card, active)
                    card.chaos_tarot_visual = active
                    if card.set_sprites and card.config and card.config.center then
                        card:set_sprites(card.config.center)
                    end
                    card.ability_UIBox_table = nil
                    if card.config then
                        card.config.h_popup = nil
                        card.config.h_popup_config = nil
                    end
                elseif active and card.ability then
                    local def = chaos_tarot_definition(self)
                    if not chaos_tarot_valid_target(def, card.ability.chaos_tarot_suit) then
                        chaos_tarot_refresh_ability(card, true)
                        card.ability_UIBox_table = nil
                        if card.config then
                            card.config.h_popup = nil
                            card.config.h_popup_config = nil
                        end
                    end
                end
            end,
        }, true)
    end
end

function CHAOSDECK.has_chaos_suit_in_list(list)
    if type(list) ~= 'table' then return false end
    for _, suit in ipairs(list) do
        if CHAOS_SUIT_SET[suit] then return true end
    end
    return false
end

function CHAOSDECK.get_pollable_suit_keys(source, excluded)
    local out = {}
    local buffer = SMODS and SMODS.Suit and SMODS.Suit.obj_buffer or {}
    local chaos_enabled = chaos_suit_pool_enabled({ source = source })
    for _, key in ipairs(buffer) do
        if key ~= excluded then
            local suit = SMODS and SMODS.Suits and SMODS.Suits[key]
            local allowed = suit ~= nil and (not CHAOS_SUIT_SET[key] or chaos_enabled)
            if allowed and SMODS and type(SMODS.add_to_pool) == 'function' then
                local ok, result = pcall(SMODS.add_to_pool, suit, { rank = '', source = source })
                allowed = ok and result == true
            elseif allowed and type(suit.in_pool) == 'function' then
                local ok, result = pcall(suit.in_pool, suit, { rank = '', source = source })
                allowed = ok and result ~= false
            end
            if allowed then out[#out + 1] = key end
        end
    end
    return out
end

function CHAOSDECK.poll_suit(source, excluded, seed_key)
    local suits = CHAOSDECK.get_pollable_suit_keys(source, excluded)
    if #suits == 0 then
        for _, suit in ipairs({ 'Spades', 'Hearts', 'Diamonds', 'Clubs' }) do
            if suit ~= excluded then suits[#suits + 1] = suit end
        end
    end
    if #suits == 0 then return nil end
    return pseudorandom_element(suits, pseudoseed(seed_key or source or 'chaos_suit'))
end

function CHAOSDECK.get_front_for_suit_rank(suit_key, rank_card_key)
    if not (G and G.P_CARDS and suit_key and rank_card_key) then return nil end
    local direct = G.P_CARDS[tostring(suit_key) .. '_' .. tostring(rank_card_key)]
    if direct then return direct end
    local suit = SMODS and SMODS.Suits and SMODS.Suits[suit_key]
    if suit and suit.card_key then
        return G.P_CARDS[tostring(suit.card_key) .. '_' .. tostring(rank_card_key)]
    end
end

local function chaos_apply_generated_suit(card, source, seed_key)
    if not (card and card.base and SMODS and type(SMODS.change_base) == 'function') then return card end
    local active = chaos_suit_pool_enabled({ source = source })
    if not active and not CHAOS_SUIT_SET[card.base.suit] then return card end
    local suit = CHAOSDECK.poll_suit(source, nil, seed_key)
    if suit and suit ~= card.base.suit then
        SMODS.change_base(card, suit, nil)
    end
    return card
end

if type(create_card) == 'function' and not CHAOSDECK._chaos_create_card_suit_hook then
    local chaos_create_card_ref = create_card
    function create_card(_type, area, legendary, rarity, skip_materialize, soulable, forced_key, key_append, ...)
        local front_was_forced = SMODS and SMODS.set_create_card_front ~= nil
        local card = chaos_create_card_ref(_type, area, legendary, rarity, skip_materialize, soulable, forced_key, key_append, ...)
        if not front_was_forced and (_type == 'Base' or _type == 'Enhanced') then
            chaos_apply_generated_suit(card, 'chaos_create_card_' .. tostring(key_append or _type), 'chaos_front_' .. tostring(key_append or _type))
        end
        return card
    end
    CHAOSDECK._chaos_create_card_suit_hook = true
end

if SMODS and type(SMODS.create_card) == 'function' and not CHAOSDECK._chaos_smods_create_card_suit_hook then
    local chaos_smods_create_card_ref = SMODS.create_card
    function SMODS.create_card(args)
        local card = chaos_smods_create_card_ref(args)
        local set = type(args) == 'table' and args.set or nil
        local playing_card_request = set == 'Playing Card' or set == 'Base' or set == 'Enhanced'
        if playing_card_request and type(args) == 'table' and args.front == nil and args.suit == nil then
            chaos_apply_generated_suit(card, 'chaos_smods_create_' .. tostring(args.key_append or set), 'chaos_smods_front_' .. tostring(args.key_append or set))
        end
        return card
    end
    CHAOSDECK._chaos_smods_create_card_suit_hook = true
end

if type(create_playing_card) == 'function' and not CHAOSDECK._chaos_create_playing_card_suit_hook then
    local chaos_create_playing_card_ref = create_playing_card
    function create_playing_card(card_init, area, skip_materialize, silent, colours, ...)
        local card = chaos_create_playing_card_ref(card_init, area, skip_materialize, silent, colours, ...)
        if type(card_init) == 'table' and card_init.front == nil then
            chaos_apply_generated_suit(card, 'chaos_create_playing_card', 'chaos_create_playing_card')
        end
        return card
    end
    CHAOSDECK._chaos_create_playing_card_suit_hook = true
end

if type(reset_ancient_card) == 'function' and not CHAOSDECK._chaos_ancient_suit_hook then
    local chaos_reset_ancient_card_ref = reset_ancient_card
    function reset_ancient_card(...)
        if not chaos_suit_pool_enabled({ source = 'chaos_ancient' }) then
            return chaos_reset_ancient_card_ref(...)
        end
        if not (G and G.GAME and G.GAME.current_round and G.GAME.current_round.ancient_card) then
            return chaos_reset_ancient_card_ref(...)
        end
        local current = G.GAME.current_round.ancient_card.suit
        local suit = CHAOSDECK.poll_suit('chaos_ancient', current, 'anc' .. tostring(G.GAME.round_resets and G.GAME.round_resets.ante or 0))
        if suit then
            G.GAME.current_round.ancient_card.suit = suit
            return
        end
        return chaos_reset_ancient_card_ref(...)
    end
    CHAOSDECK._chaos_ancient_suit_hook = true
end

local function selected_chaos_back()
    if not (G and G.GAME) then return false end
    if G.GAME.modifiers and G.GAME.modifiers.chaos_chaos_deck then return true end
    local selected = G.GAME.selected_back
    if selected then
        local center = selected.effect and selected.effect.center or selected.config and selected.config.center
        if center and center.key == 'b_chaos_chaos' then return true end
        if selected.key == 'b_chaos_chaos' then return true end
    end
    local viewed = G.GAME.viewed_back
    if viewed then
        local center = viewed.effect and viewed.effect.center or viewed.config and viewed.config.center
        if center and center.key == 'b_chaos_chaos' then return true end
        if viewed.key == 'b_chaos_chaos' then return true end
    end
    return false
end

local function chaos_cards_present()
    if not (G and type(G.playing_cards) == 'table') then return false end
    for _, card in ipairs(G.playing_cards) do
        if card and card.base and CHAOS_SUIT_SET[card.base.suit] then return true end
    end
    return false
end

function CHAOSDECK.is_chaos_deck()
    return selected_chaos_back()
end

function CHAOSDECK.is_chaos_preview_active()
    return selected_chaos_back() or chaos_cards_present()
end

function CHAOSDECK.is_chaos_config_view_active(list)
    if selected_chaos_back() then return false end
    if not (CHAOSDECK.config and CHAOSDECK.config.enableChaosSuits == true) then return false end
    if type(list) == 'table' and CHAOSDECK.has_chaos_suit_in_list(list) then return true end
    return chaos_cards_present()
end

function CHAOSDECK.is_chaos_suit_key(suit_key)
    return CHAOS_SUIT_SET[suit_key] == true
end

function CHAOSDECK.chaos_view_should_render_initial_suit(suit_key, index, num_suits, suits_per_page, visible_suit)
    if selected_chaos_back() then return false end
    if CHAOSDECK.is_chaos_config_view_active(visible_suit) then
        return not CHAOS_SUIT_SET[suit_key]
    end
    suits_per_page = suits_per_page or 4
    return (index >= 1 and index <= suits_per_page) or num_suits <= suits_per_page
end

function CHAOSDECK.chaos_view_page_count(visible_suit, suits_per_page)
    if selected_chaos_back() then return 1 end
    if CHAOSDECK.is_chaos_config_view_active(visible_suit) then return 2 end
    suits_per_page = suits_per_page or 4
    return math.max(1, math.ceil(#(visible_suit or {}) / suits_per_page))
end

function CHAOSDECK.chaos_view_show_page_cycle(visible_suit, suits_per_page)
    if selected_chaos_back() then return false end
    if CHAOSDECK.is_chaos_config_view_active(visible_suit) then return true end
    suits_per_page = suits_per_page or 4
    return type(visible_suit) == 'table' and #visible_suit > suits_per_page
end

function CHAOSDECK.chaos_config_page_two(visible_suit, current_option)
    return current_option == 2 and CHAOSDECK.is_chaos_config_view_active(visible_suit)
end

local function chaos_deck_owns_suit(suit_key)
    if not (G and type(G.playing_cards) == 'table') then return false end
    for _, card in ipairs(G.playing_cards) do
        if card and card.base and card.base.suit == suit_key then return true end
    end
    return false
end

function CHAOSDECK.hide_unused_chaos_preview_suits(hidden_suits, suit_tallies)
    if selected_chaos_back() or type(hidden_suits) ~= 'table' then return end
    for suit_key in pairs(CHAOS_SUIT_SET) do
        if not chaos_deck_owns_suit(suit_key) then
            hidden_suits[suit_key] = true
        end
    end
end

local function poll_chaos_first_shop_standard_pack()
    if not (G and G.P_CENTER_POOLS and G.P_CENTER_POOLS.Booster) then return nil end
    local choices = {}
    local total_weight = 0
    for _, center in ipairs(G.P_CENTER_POOLS.Booster) do
        if center and center.kind == 'Standard'
            and not (G.GAME and G.GAME.banned_keys and G.GAME.banned_keys[center.key])
        then
            local weight = tonumber(center.weight) or 0
            if weight > 0 then
                choices[#choices + 1] = { center = center, weight = weight }
                total_weight = total_weight + weight
            end
        end
    end
    if total_weight <= 0 then return nil end

    local roll = pseudorandom('chaos_chaos_first_shop_standard') * total_weight
    local cumulative = 0
    for _, entry in ipairs(choices) do
        cumulative = cumulative + entry.weight
        if roll < cumulative then return entry.center end
    end
    return choices[#choices] and choices[#choices].center or nil
end

function CHAOSDECK.chaos_force_first_shop_standard()
    if not (G and G.GAME and G.GAME.modifiers and G.GAME.modifiers.chaos_chaos_deck) then return end
    if G.GAME.chaos_chaos_first_shop_standard_done then return end
    if not (G.GAME.round_resets and G.GAME.round_resets.ante == 1) then return end
    if not (G.E_MANAGER and Event) then return end

    local attempts = 0
    G.E_MANAGER:add_event(Event({
        trigger = 'after',
        delay = 0,
        blockable = false,
        func = function()
            attempts = attempts + 1
            if G.GAME.chaos_chaos_first_shop_standard_done then return true end
            if not (G.shop_booster and type(G.shop_booster.cards) == 'table' and #G.shop_booster.cards >= 2) then
                return attempts >= 120
            end

            local buffoon = nil
            for _, booster in ipairs(G.shop_booster.cards) do
                if booster and booster.config and booster.config.center
                    and booster.config.center.kind == 'Buffoon'
                then
                    buffoon = booster
                    break
                end
            end

            local target = nil
            for _, booster in ipairs(G.shop_booster.cards) do
                if booster ~= buffoon then
                    target = booster
                    break
                end
            end
            target = target or G.shop_booster.cards[#G.shop_booster.cards]
            if not target then return true end

            if target.config and target.config.center and target.config.center.kind ~= 'Standard' then
                local center = poll_chaos_first_shop_standard_pack()
                if center then
                    local booster_pos = target.ability and target.ability.booster_pos
                    local couponed = target.ability and target.ability.couponed
                    target:set_ability(center, nil, false)
                    target.ability = target.ability or {}
                    target.ability.booster_pos = booster_pos
                    if couponed then target.ability.couponed = true end
                    if target.set_cost then target:set_cost() end
                    if booster_pos and G.GAME.current_round and type(G.GAME.current_round.used_packs) == 'table' then
                        G.GAME.current_round.used_packs[booster_pos] = center.key
                    end
                end
            end

            G.GAME.chaos_chaos_first_shop_standard_done = true
            return true
        end,
    }))
end

local chaos_vanilla_suit_order = { 'Hearts', 'Clubs', 'Spades', 'Diamonds' }
local chaos_custom_suit_order = {
    CHAOS_SUIT.smiles, CHAOS_SUIT.bananas, CHAOS_SUIT.dices,
    CHAOS_SUIT.rubies, CHAOS_SUIT.flowers, CHAOS_SUIT.petals,
    CHAOS_SUIT.free_parking_spots, CHAOS_SUIT.wraiths, CHAOS_SUIT.beans,
}

local function reorder_chaos_suits(list)
    if type(list) ~= 'table' then return end
    local original = {}
    local present = {}
    for _, suit in ipairs(list) do
        original[#original + 1] = suit
        present[suit] = true
    end
    for i = #list, 1, -1 do list[i] = nil end
    local added = {}
    local function add(suit)
        if present[suit] and not added[suit] then
            list[#list + 1] = suit
            added[suit] = true
        end
    end
    for _, suit in ipairs(chaos_vanilla_suit_order) do add(suit) end
    for _, suit in ipairs(original) do
        if not CHAOS_SUIT_SET[suit] then add(suit) end
    end
    for _, suit in ipairs(chaos_custom_suit_order) do add(suit) end
    for _, suit in ipairs(original) do add(suit) end
end

function CHAOSDECK.prepare_chaos_full_preview_suit_map(suit_map)
    if not CHAOSDECK.is_chaos_preview_active() and not CHAOSDECK.has_chaos_suit_in_list(suit_map) then return end
    reorder_chaos_suits(suit_map)
end

function CHAOSDECK.prepare_chaos_view_suit_order(visible_suit)
    if not CHAOSDECK.is_chaos_preview_active() and not CHAOSDECK.has_chaos_suit_in_list(visible_suit) then return end
    reorder_chaos_suits(visible_suit)
end

if G and G.UIDEF and type(G.UIDEF.deck_preview) == 'function' and not CHAOSDECK._deck_preview_popup_definition_hook then
    local chaos_deck_preview_ref = G.UIDEF.deck_preview
    function G.UIDEF.deck_preview(...)
        local definition = chaos_deck_preview_ref(...)
        if type(definition) == 'table' then
            definition.chaos_deck_preview_popup = true
        end
        return definition
    end
    CHAOSDECK._deck_preview_popup_definition_hook = true
end

if UIBox and type(UIBox.init) == 'function' and not CHAOSDECK._deck_preview_popup_uibox_hook then
    local chaos_uibox_init_ref = UIBox.init
    function UIBox:init(args)
        if args and type(args.definition) == 'table' and args.definition.chaos_deck_preview_popup then
            args.config = args.config or {}
            args.config.instance_type = 'POPUP'
        end
        return chaos_uibox_init_ref(self, args)
    end
    CHAOSDECK._deck_preview_popup_uibox_hook = true
end

if type(create_option_cycle) == 'function' and not CHAOSDECK._chaos_view_deck_page_cycle_hook then
    local chaos_create_option_cycle_ref = create_option_cycle
    function create_option_cycle(args)
        if args and args.opt_callback == 'your_suits_page' and selected_chaos_back() then
            return { n = G.UIT.R, config = { align = 'cm', minh = 0, minw = 0, padding = 0 }, nodes = {} }
        end
        return chaos_create_option_cycle_ref(args)
    end
    CHAOSDECK._chaos_view_deck_page_cycle_hook = true
end

local preview_groups = {
    { 'Hearts', 'Clubs', 'Spades', 'Diamonds' },
    { CHAOS_SUIT.smiles, CHAOS_SUIT.bananas, CHAOS_SUIT.dices },
    { CHAOS_SUIT.rubies, CHAOS_SUIT.flowers, CHAOS_SUIT.petals },
    { CHAOS_SUIT.free_parking_spots, CHAOS_SUIT.wraiths, CHAOS_SUIT.beans },
}

local chaos_config_preview_groups = {
    { CHAOS_SUIT.smiles, CHAOS_SUIT.bananas, CHAOS_SUIT.dices },
    { CHAOS_SUIT.rubies, CHAOS_SUIT.flowers, CHAOS_SUIT.petals },
    { CHAOS_SUIT.free_parking_spots, CHAOS_SUIT.wraiths, CHAOS_SUIT.beans },
}

local function append_chaos_card_rows(deck_tables, suit_cards, unplayed_only, groups)
    if type(deck_tables) ~= 'table' or type(suit_cards) ~= 'table' then return false end
    local before = #deck_tables
    for _, group in ipairs(groups) do
        local cards = {}
        for _, suit_key in ipairs(group) do
            local source = suit_cards[suit_key]
            if type(source) == 'table' then
                for _, card in ipairs(source) do cards[#cards + 1] = card end
            end
        end
        if #cards > 0 then
            local view_deck = CardArea(
                G.ROOM.T.x + 0.2 * G.ROOM.T.w / 2, G.ROOM.T.h,
                6.5 * G.CARD_W,
                0.6 * G.CARD_H,
                {
                    card_limit = #cards,
                    type = 'title',
                    view_deck = true,
                    highlight_limit = 0,
                    card_w = G.CARD_W * 0.7,
                    draw_layers = { 'card' },
                    negative_info = 'playing_card'
                }
            )
            deck_tables[#deck_tables + 1] = { n = G.UIT.R, config = { align = 'cm', padding = 0 }, nodes = {
                { n = G.UIT.O, config = { object = view_deck } }
            } }
            for _, original in ipairs(cards) do
                local greyed = nil
                if unplayed_only and not ((original.area and original.area == G.deck) or original.ability.wheel_flipped) then greyed = true end
                local copy = copy_card(original, nil, 0.7)
                copy.greyed = greyed
                if CHAOSDECK.chaos_wraith_adjacent(original) then copy.debuff = false end
                copy.T.x = view_deck.T.x + view_deck.T.w / 2
                copy.T.y = view_deck.T.y
                copy:hard_set_T()
                view_deck:emplace(copy)
            end
        end
    end
    return #deck_tables > before
end

function CHAOSDECK.append_chaos_view_deck_rows(deck_tables, suit_cards, unplayed_only)
    if not selected_chaos_back() then return false end
    return append_chaos_card_rows(deck_tables, suit_cards, unplayed_only, preview_groups)
end

function CHAOSDECK.append_chaos_config_view_deck_rows(deck_tables, suit_cards, unplayed_only, visible_suit, current_option)
    if not CHAOSDECK.chaos_config_page_two(visible_suit, current_option) then return false end
    return append_chaos_card_rows(deck_tables, suit_cards, unplayed_only, chaos_config_preview_groups)
end

function CHAOSDECK.append_chaos_config_tally_rows(tally_ui, suit_tallies, mod_suit_tallies, flip_col, visible_suit, current_option)
    if not CHAOSDECK.chaos_config_page_two(visible_suit, current_option) then return false end
    if type(tally_ui) ~= 'table' or type(suit_tallies) ~= 'table' or type(mod_suit_tallies) ~= 'table' then return false end
    if type(tally_sprite) ~= 'function' then return false end
    local added = false
    for _, group in ipairs(chaos_config_preview_groups) do
        local nodes = {}
        for _, suit_key in ipairs(group) do
            if (suit_tallies[suit_key] or 0) > 0 and SMODS and SMODS.Suits and SMODS.Suits[suit_key] then
                nodes[#nodes + 1] = tally_sprite(
                    SMODS.Suits[suit_key].ui_pos,
                    {
                        { string = '' .. (suit_tallies[suit_key] or 0), colour = flip_col },
                        { string = '' .. (mod_suit_tallies[suit_key] or 0), colour = G.C.BLUE }
                    },
                    { localize(suit_key, 'suits_plural') },
                    suit_key
                )
            end
        end
        if #nodes > 0 then
            tally_ui[#tally_ui + 1] = { n = G.UIT.R, config = { align = 'cm', minh = 0.05, padding = 0.05 }, nodes = nodes }
            added = true
        end
    end
    return added
end

SMODS.Back {
    key = 'chaos',
    atlas = 'Extras',
    pos = { x = 0, y = 3 },
    unlocked = true,
    discovered = true,
    apply = function(self, back)
        G.GAME.modifiers.chaos_chaos_deck = true
        G.GAME.chaos_chaos_cards_added = false
        G.GAME.chaos_chaos_first_shop_standard_done = false
        G.E_MANAGER:add_event(Event({
            trigger = 'immediate',
            delay = 0,
            blockable = false,
            func = add_chaos_starting_cards,
        }))
    end,
}

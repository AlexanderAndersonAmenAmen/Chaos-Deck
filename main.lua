CHAOSDECK = CHAOSDECK or {}

function CHAOSDECK.pack(...)
    return { n = select('#', ...), ... }
end

local chaos_query_guard = setmetatable({}, { __mode = 'k' })
function CHAOSDECK.safe_has_no_suit(card)
    if not card then return false end
    if chaos_query_guard[card] then return false end
    if not (SMODS and type(SMODS.has_no_suit) == 'function') then return false end
    chaos_query_guard[card] = true
    local ok, result = pcall(SMODS.has_no_suit, card)
    chaos_query_guard[card] = nil
    return ok and result == true
end

SMODS.Gradient({
    key = "abilities",
    colours = {
        HEX('c9a500'),
        HEX('9bb031'),
        HEX('479d7a'),
        HEX('ff5d9b'),
        HEX('6CA2A6'),
        HEX('7a73bb'),
        HEX('4189e9'),
        HEX('4f6367'),
        HEX('6e8965'),
    },
    cycle = 2 * math.pi / 1.5,
})

if G and G.C then G.C.CHAOS_ABILITIES = SMODS.Gradients.chaos_abilities end

SMODS.Atlas({ key = "SUITS", path = "SUITS.png", px = 71, py = 95 })
SMODS.Atlas({ key = "SUITS_UI", path = "SUITS_UI.png", px = 18, py = 18 })
SMODS.Atlas({ key = "Extras", path = "EHD.png", px = 71, py = 95 })

assert(SMODS.load_file("decks/chaos.lua"))()

SMODS.current_mod.calculate = function(self, context)
    if type(context) ~= 'table' then return end
    if context.starting_shop and CHAOSDECK.chaos_force_first_shop_standard then
        CHAOSDECK.chaos_force_first_shop_standard()
    end
    if CHAOSDECK.calculate_chaos_suits then
        return CHAOSDECK.calculate_chaos_suits(context)
    end
end

local h = require "fzf-lua-frecency.helpers"

local T = MiniTest.new_set()

T["#default"] = MiniTest.new_set()
T["#default"]["returns default when value is nil"] = function()
  MiniTest.expect.equality(h.default(nil, "fallback"), "fallback")
end

T["#default"]["returns original value when not nil"] = function()
  MiniTest.expect.equality(h.default("value", "fallback"), "value")
  MiniTest.expect.equality(h.default(false, "fallback"), false)
end

T["#pad_str"] = MiniTest.new_set()
T["#pad_str"]["returns original string when longer than or equal to len"] = function()
  MiniTest.expect.equality(h.pad_str("abc", 2), "abc")
  MiniTest.expect.equality(h.pad_str("abc", 3), "abc")
end

T["#pad_str"]["pads string with spaces when shorter than len"] = function()
  MiniTest.expect.equality(h.pad_str("abc", 5), "  abc")
end

T["#truncate_num"] = MiniTest.new_set()
T["#truncate_num"]["truncates number to given decimals"] = function()
  MiniTest.expect.equality(h.truncate_num(3.14159, 2), 3.14)
  MiniTest.expect.equality(h.truncate_num(3.19999, 1), 3.1)
end

T["#truncate_num"]["returns same number if no decimals"] = function()
  MiniTest.expect.equality(h.truncate_num(42, 0), 42)
end

return T

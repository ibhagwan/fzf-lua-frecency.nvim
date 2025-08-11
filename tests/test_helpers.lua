local h = require "fzf-lua-frecency.helpers"

local T = MiniTest.new_set()

T["#default"] = MiniTest.new_set()
T["#default"]["returns default when value is nil"] = function()
  MiniTest.expect.equality(h.default(nil, "fallback"), "fallback")
  MiniTest.expect.equality(h.default(nil, false), false)
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

T["#max_decimals"] = MiniTest.new_set()
T["#max_decimals"]["truncates to max decimals without rounding"] = function()
  MiniTest.expect.equality(h.max_decimals(3.456, 2), 3.45)
  MiniTest.expect.equality(h.max_decimals(9.999, 1), 9.9)
  MiniTest.expect.equality(h.max_decimals(5, 3), 5.0)
end

T["#min_decimals"] = MiniTest.new_set()
T["#min_decimals"]["formats number with minimum decimals"] = function()
  MiniTest.expect.equality(h.min_decimals(3.4, 2), "3.40")
  MiniTest.expect.equality(h.min_decimals(5, 3), "5.000")
  MiniTest.expect.equality(h.min_decimals(2.71828, 1), "2.7")
end

T["#exact_decimals"] = MiniTest.new_set()
T["#exact_decimals"]["truncates then formats to exact decimals"] = function()
  MiniTest.expect.equality(h.exact_decimals(3.456, 2), "3.45")
  MiniTest.expect.equality(h.exact_decimals(9.999, 1), "9.9")
  MiniTest.expect.equality(h.exact_decimals(5, 3), "5.000")
end

T["#fit_decimals"] = MiniTest.new_set()
T["#fit_decimals"]["returns two decimals when it fits within max_len"] = function()
  MiniTest.expect.equality(h.fit_decimals(1.23, 5), "1.23")
  MiniTest.expect.equality(h.fit_decimals(12.34, 5), "12.34")
end
T["#fit_decimals"]["returns one decimal when two decimals are too long but one decimal fits"] = function()
  MiniTest.expect.equality(h.fit_decimals(123.45, 5), "123.4")
end
T["#fit_decimals"]["returns no decimals when two decimals are too long"] = function()
  MiniTest.expect.equality(h.fit_decimals(1234.56, 5), "1234")
  MiniTest.expect.equality(h.fit_decimals(12345.67, 5), "12345")
end

T["#strip_score"] = MiniTest.new_set()
T["#strip_score"]["removes leading numbers and spaces"] = function()
  MiniTest.expect.equality(h.strip_score "1.23 some/file/path", "some/file/path")
  MiniTest.expect.equality(h.strip_score "2.00    another/file", "another/file")
  MiniTest.expect.equality(h.strip_score "no/score prefix", "no/score prefix")
  MiniTest.expect.equality(h.strip_score "", "")
  MiniTest.expect.equality(h.strip_score "1    ", "")
end

return T

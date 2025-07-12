local T = MiniTest.new_set()

T["works"] = function()
  MiniTest.expect.equality(true, true)
end

return T

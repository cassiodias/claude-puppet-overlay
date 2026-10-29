-- A tiny assertion helper: check(name, condition) records a failure; check.done(suite) reports and exits.

local failures = {}

local check = setmetatable({}, {
  __call = function(_, name, condition)
    if not condition then failures[#failures + 1] = name end
  end,
})

function check.done(suite)
  if #failures == 0 then
    print(suite .. ": ok")
    return
  end
  for _, name in ipairs(failures) do print(suite .. ": FAILED " .. name) end
  os.exit(1)
end

return check

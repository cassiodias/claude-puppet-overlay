-- The session model with a fake harness: proves the core asks the harness what tools mean and depends on
-- no real agent.

local root = arg[0]:match("^(.*)/tests/") or "."
package.path = root .. "/ClaudePuppet.spoon/lib/?.lua;" .. root .. "/ClaudePuppet.spoon/lib/?/init.lua;" .. package.path
local check = dofile(root .. "/tests/support/check.lua")
local Sessions = require("puppet.model.sessions")
local Mapping = require("puppet.model.mapping")

local fake = {
  id = "fake", name = "Fakebot",
  toolKind = function(tool) return ({ look = "reading", ask_human = "question", run_skill = "skill" })[tool] end,
}
local mapping = Mapping.new({ coder = { "build" }, pingpong = { "review" }, conversation = "off" })

local function event(name, fields)
  local e = { at = 100, name = name, session = "s1", agentId = "", tool = "", agentType = "", text = "",
    folder = "repo", app = "", flag = "", tty = "", harness = "fake" }
  for k, v in pairs(fields or {}) do e[k] = v end
  return e
end

local sessions = Sessions.new(100)
local function apply(name, fields) return sessions:apply(event(name, fields), { mapping = mapping, harness = fake, frame = 1, now = 100 }) end

apply("UserPromptSubmit", { text = "hello" })
check("an unlisted turn with the conversation off does not play", sessions.all.s1.isListed == false)
apply("PreToolUse", { tool = "run_skill", text = "build" })
check("the harness's skill tool starts a listed command mid-turn", sessions.all.s1.isListed and sessions.all.s1.command == "build")
check("that command codes", Sessions.sceneFor(sessions.all.s1, mapping) == "code")
apply("PreToolUse", { tool = "look" })
check("the harness's reading tool shows the lens", sessions.all.s1.readingUntil == 21)
local intents = apply("PreToolUse", { tool = "ask_human" })
check("the harness's question tool raises a hand", sessions.all.s1.mood == "asking")
check("and says so", intents[1] and intents[1].text == "I have a question for you")
intents = apply("Notification", {})
check("a notification without text names the harness", #intents == 0)
apply("PostToolUse", { tool = "ask_human" })
intents = apply("Notification", {})
check("a notification without text names the harness", intents[1] and intents[1].text == "Fakebot needs you")
intents = apply("Stop", { text = "Built it." })
check("done says the reply", intents[1] and intents[1].text == "Built it. ✓")
check("the puppet stays on stage", sessions:stageKeys(100)[1] == "s1")
check("and leaves after hours of silence", sessions:stageKeys(100 + 3 * 60 * 60)[1] == "home")

check.done("sessions")

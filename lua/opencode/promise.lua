---https://github.com/Billiam/promise.lua
---TODO: Consider coroutines (deep refactor).

local queue = {}

local State = {
  PENDING = "pending",
  FULFILLED = "fulfilled",
  REJECTED = "rejected",
}

local passthrough = function(x)
  return x
end
local errorthrough = function(x)
  error(x, 0)
end

local function callable_table(callback)
  local mt = getmetatable(callback)
  return type(mt) == "table" and type(mt.__call) == "function"
end

local function is_callable(value)
  local t = type(value)
  return t == "function" or (t == "table" and callable_table(value))
end

local transition, resolve, run

local Promise = {
  is_promise = true,
  state = State.PENDING,
}
Promise.mt = { __index = Promise }

local do_async = function(callback)
  if Promise.async then
    Promise.async(callback)
  else
    table.insert(queue, callback)
  end
end

local reject = function(promise, reason)
  transition(promise, State.REJECTED, reason)
end

local fulfill = function(promise, value)
  transition(promise, State.FULFILLED, value)
end

transition = function(promise, state, value)
  if
    promise.state == state
    or promise.state ~= State.PENDING
    or (state ~= State.FULFILLED and state ~= State.REJECTED)
    or value == nil
  then
    return
  end

  promise.state = state
  promise.value = value
  run(promise)
end

function Promise:next(on_fulfilled, on_rejected)
  local promise = Promise.new()

  table.insert(self.queue, {
    fulfill = is_callable(on_fulfilled) and on_fulfilled or nil,
    reject = is_callable(on_rejected) and on_rejected or nil,
    promise = promise,
  })

  run(self)

  return promise
end

resolve = function(promise, x)
  if promise == x then
    reject(promise, "TypeError: cannot resolve a promise with itself")
    return
  end

  local x_type = type(x)

  if x_type ~= "table" then
    fulfill(promise, x)
    return
  end

  -- x is a promise in the current implementation
  if x.is_promise then
    -- 2.3.2.1 if x is pending, resolve or reject this promise after completion
    if x.state == State.PENDING then
      x:next(function(value)
        resolve(promise, value)
      end, function(reason)
        reject(promise, reason)
      end)
      return
    end
    -- if x is not pending, transition promise to x's state and value
    transition(promise, x.state, x.value)
    return
  end

  local called = false
  -- 2.3.3.1. Catches errors thrown by __index metatable
  local success, reason = pcall(function()
    local next = x.next
    if is_callable(next) then
      next(x, function(y)
        if not called then
          resolve(promise, y)
          called = true
        end
      end, function(r)
        if not called then
          reject(promise, r)
          called = true
        end
      end)
    else
      fulfill(promise, x)
    end
  end)

  if not success then
    if not called then
      reject(promise, reason)
    end
  end
end

run = function(promise)
  if promise.state == State.PENDING then
    return
  end

  do_async(function()
    -- drain promise.queue while allowing pushes from within callbacks
    local q = promise.queue
    local i = 0
    while i < #q do
      i = i + 1
      local obj = q[i]
      local success, result = pcall(function()
        local success = obj.fulfill or passthrough
        local failure = obj.reject or errorthrough
        local callback = promise.state == State.FULFILLED and success or failure
        return callback(promise.value)
      end)

      if not success then
        reject(obj.promise, result)
      else
        resolve(obj.promise, result)
      end
    end
    for j = 1, i do
      q[j] = nil
    end
  end)
end

function Promise.new(callback)
  local instance = {
    queue = {},
  }
  setmetatable(instance, Promise.mt)

  if callback then
    callback(function(value)
      resolve(instance, value)
    end, function(reason)
      reject(instance, reason)
    end)
  end

  return instance
end

function Promise:catch(callback)
  return self:next(nil, callback)
end

function Promise:resolve(value)
  fulfill(self, value)
end

function Promise:reject(reason)
  reject(self, reason)
end

function Promise.update()
  while true do
    local async = table.remove(queue, 1)

    if not async then
      break
    end

    async()
  end
end

-- resolve when all promises complete
function Promise.all(...)
  local promises = { ... }
  local results = {}
  local state = State.FULFILLED
  local remaining = #promises

  local promise = Promise.new()

  local check_finished = function()
    if remaining > 0 then
      return
    end
    transition(promise, state, results)
  end

  for i, p in ipairs(promises) do
    p:next(function(value)
      results[i] = value
      remaining = remaining - 1
      check_finished()
    end, function(value)
      results[i] = value
      remaining = remaining - 1
      state = State.REJECTED
      check_finished()
    end)
  end

  check_finished()

  return promise
end

-- resolve with first promise to complete
function Promise.race(...)
  local promises = { ... }
  local promise = Promise.new()

  Promise.all(...):next(nil, function(value)
    reject(promise, value)
  end)

  local success = function(value)
    fulfill(promise, value)
  end

  for _, p in ipairs(promises) do
    p:next(success)
  end

  return promise
end

Promise.async = function(callback)
  vim.schedule(callback)
end

return Promise

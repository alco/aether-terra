env = { names = {} }

function env:check_name(name)
    local val
    val = self.names[name]
    if val and val.type == "let" then
        print("Error: name already taken")
        return false
    else
        return true
    end
end

function env:setvar(name, value)
    if self:check_name(name) then
        self.names[name] = { type = "var", val = value }
    end
end

function env:setlet(name, value)
    if self:check_name(name) then
        self.names[name] = { type = "let", val = value }
    end
end

function env:get(name)
    local val
    val = self.names[name]
    if val then
        return val
    else
        print("Unbound variable "..name)
    end
end

function env:getval(name)
    local val
    val = self:get(name)
    if val then
        return val.val
    end
end

--return env

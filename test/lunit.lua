function assertEq(given, expected)
    if given ~= expected then
        error("Assertion failed. Expected `"..tostring(given).."` to be equal to `"..tostring(expected).."`")
    end
end

function assertNil(given)
    if given ~= nil then
        error("Assertion failed. Expected `"..tostring(given).."` to be nil")
    end
end

function assertEqList(given, expected)
    local cnt = 1
    for i = 1, #given do
        assertEq(given[i], expected[i])
        cnt = cnt + 1
    end
    if #expected ~= #given then
        error("Not all values were checked. Stop at '"..tostring(expected[cnt]).."'")
    end
end

function assertError(errstr, fn, ...)
    local status, err = pcall(fn, ...)
    assertEq(status, false)
    assertEq(err, errstr)
end

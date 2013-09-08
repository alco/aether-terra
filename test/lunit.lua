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
    for i = 1, #given do
        assertEq(given[i], expected[i])
    end
    if #expected ~= #given then
        error("Not all values were checked")
    end
end

function assertError(errstr, fn, ...)
    local status, err = pcall(fn, ...)
    assertEq(status, false)
    assertEq(err, errstr)
end

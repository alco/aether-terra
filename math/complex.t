-- type complexf = float[re, im]
-- type complexd = double[re, im]

-- core
function map2(op, s1, s2)
    return quote
        var size = 2 --min(len(s1), len(s2))
        var result: float[2]
        for i = 0, size do
            result[i] = [op(`s1[i], `s2[i])]
        end
        return result
    end
end

-- math
function plus(a, b)
    return `a + b
end

function sub(a, b)
    return `a - b
end

local C = terralib.includec("math.h")

sqrt = C.sqrtf

-- complex
terra conjf(c: float[2])
    var result: float[2]
    result[0] = c[0]
    result[1] = -c[1]
    return result
end

terra mulconjf(c: float[2])
    var v = @[&vector(float,2)]([&float](c))
    v = v*v
    return v[0] + v[1]
end

terra absf(c: float[2])
    return sqrt(mulconjf(c))
end

terra cprodf(c1: float[2], c2: float[2])
    var result: float[2]
    result[0] = c1[0]*c2[0] - c1[1]*c2[1]
    result[1] = c1[0]*c2[1] + c1[1]*c2[0]
    return result
end

terra addf(c1: float[2], c2: float[2])
    [map2(plus, c1, c2)]
end

terra subf(c1: float[2], c2: float[2])
    [map2(sub, c1, c2)]
end

terra recipf(c: float[2])
    var denom: float = c[0]*c[0] + c[1]*c[1]
    var result: float[2]
    result[0] = c[0] / denom
    result[1] = -c[1] / denom
    return result
end

terra divf(c1: float[2], c2: float[2])
    var denom: float = c2[0]*c2[0] + c2[1]*c2[1]
    var result: float[2]
    result[0] = (c1[0]*c2[0] + c1[1]*c2[1]) / denom
    result[1] = (c1[1]*c2[0] - c1[0]*c2[1]) / denom
    return result
end

terra ctest()
    var c1 = arrayof(float, 1, 2)
    var c2 = arrayof(float, 3, 4)
    var c = addf(c1, c2)
    return c[0], c[1]
end

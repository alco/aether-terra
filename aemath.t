local Cmath = terralib.includec("math.h")
local aemath = {}

-- ** Trigonometric functions **

-- fn cos(x) :: τ -> τ
aemath.cos = {
    Cmath.cosf,
    Cmath.cos
}
-- fn sin(x) :: τ -> τ
aemath.sin = {
    Cmath.sinf,
    Cmath.sin
}
-- fn tan(x) :: τ -> τ
aemath.tan = {
    Cmath.tanf,
    Cmath.tan
}
-- fn acos(x) :: τ -> τ
aemath.acos = {
    Cmath.acosf,
    Cmath.acos
}
-- fn asin(x) :: τ -> τ
aemath.asin = {
    Cmath.asinf,
    Cmath.asin
}
-- fn atan(x) :: τ -> τ
aemath.atan = {
    Cmath.atanf,
    Cmath.atan
}
-- fn atan2(x) :: τ -> τ
aemath.atan2 = {
    Cmath.atan2f,
    Cmath.atan2
}

return aemath

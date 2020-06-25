Numeric Instructions
--------------------

In this file we implement the numeric rules specified in section `4.3 Numerics` of the offical WebAssembly specification.

In the notations of some operators, `sx` is the signedness of the operator and could be either `s` (signed) or `u` (unsigned), which indicates whether the operands should be interpreted as signed integer or unsigned integer.

```k
require "data.md"

module WASM-NUMERIC
    imports WASM-DATA

```

### Unary Operators

`*UnOp` takes one oprand and returns a `Val`.

```k
    syntax Val ::= IValType "." IUnOp Int   [klabel(intUnOp)  , function]
                 | FValType "." FUnOp Float [klabel(floatUnOp), function]
 // ---------------------------------------------------------------------
```

#### Unary Operators for Integers

There three unary operators for integers: `clz`, `ctz` and `popcnt`.

- `clz` counts the number of leading zero-bits, with 0 having all leading zero-bits.
- `ctz` counts the number of trailing zero-bits, with 0 having all trailing zero-bits.
- `popcnt` counts the number of non-zero bits.

Note: The actual `ctz` operator considers the integer 0 to have *all* zero-bits, whereas the `#ctz` helper function considers it to have *no* zero-bits, in order for it to be width-agnostic.

```k
    syntax IUnOp ::= "clz" | "ctz" | "popcnt"
 // -----------------------------------------
    rule ITYPE . clz    I1 => < ITYPE > #width(ITYPE) -Int #minWidth(I1)
    rule ITYPE . ctz    I1 => < ITYPE > #if I1 ==Int 0 #then #width(ITYPE) #else #ctz(I1) #fi
    rule ITYPE . popcnt I1 => < ITYPE > #popcnt(I1)

    syntax Int ::= #minWidth ( Int ) [function]
                 | #ctz      ( Int ) [function]
                 | #popcnt   ( Int ) [function]
 // -------------------------------------------
    rule #minWidth(0) => 0
    rule #minWidth(N) => 1 +Int #minWidth(N >>Int 1)                                 requires N =/=Int 0

    rule #ctz(0) => 0
    rule #ctz(N) => #if N modInt 2 ==Int 1 #then 0 #else 1 +Int #ctz(N >>Int 1) #fi  requires N =/=Int 0

    rule #popcnt(0) => 0
    rule #popcnt(N) => #bool(N modInt 2 ==Int 1) +Int #popcnt(N >>Int 1)             requires N =/=Int 0
```

Before we implement the rule for float point numbers, we first need to define 2 helper functions.

- `#isInfinityOrNaN` judges whether a `float` is infinity or NaN.
- `truncFloat` truncates a `float` by keeping its integer part and discards its fractional part.

```k
    syntax Bool ::= #isInfinityOrNaN ( Float ) [function]
 // -----------------------------------------------------
    rule #isInfinityOrNaN ( F ) => (isNaN(F) orBool isInfinite(F))

    syntax Float ::= truncFloat ( Float ) [function]
 // ------------------------------------------------
    rule truncFloat ( F ) => floorFloat (F) requires notBool signFloat(F)
    rule truncFloat ( F ) => ceilFloat  (F) requires         signFloat(F)
```

#### Unary Operators for Floats

There are 7 unary operators for floats: `abs`, `neg`, `sqrt`, `floor`, `ceil`, `trunc` and `nearest`.

- `abs` returns the absolute value of the given float point number.
- `neg` returns the additive inverse value of the given float point number.
- `sqrt` returns the square root of the given float point number.
- `floor` returns the greatest integer less than or equal to the given float point number.
- `ceil` returns the least integer greater than or equal to the given float point number.
- `trunc` returns the integral value by discarding the fractional part of the given float.
- `nearest` returns the integral value that is nearest to the given float number; if two values are equally near, returns the even one.

```k
    syntax FUnOp ::= "abs" | "neg" | "sqrt" | "floor" | "ceil" | "trunc" | "nearest"
 // --------------------------------------------------------------------------------
    rule FTYPE . abs     F => < FTYPE >   absFloat (F)
    rule FTYPE . neg     F => < FTYPE >    --Float  F
    rule FTYPE . sqrt    F => < FTYPE >  sqrtFloat (F)
    rule FTYPE . floor   F => < FTYPE > floorFloat (F)
    rule FTYPE . ceil    F => < FTYPE >  ceilFloat (F)
    rule FTYPE . trunc   F => < FTYPE > truncFloat (F)
    rule FTYPE . nearest F => < FTYPE >  F                requires          #isInfinityOrNaN (F)
    rule FTYPE . nearest F => #round(FTYPE, Float2Int(F)) requires (notBool #isInfinityOrNaN (F)) andBool notBool (Float2Int(F) ==Int 0 andBool signFloat(F))
    rule FTYPE . nearest F => < FTYPE > -0.0              requires (notBool #isInfinityOrNaN (F)) andBool          Float2Int(F) ==Int 0 andBool signFloat(F)
```

### Binary Operators

`*BinOp` takes two oprands and returns a `Val`.
A `*BinOp` operator always produces a result of the same type as its operands.

```k
    syntax Val ::= IValType "." IBinOp Int   Int   [klabel(intBinOp)  , function]
                 | FValType "." FBinOp Float Float [klabel(floatBinOp), function]
 // -----------------------------------------------------------------------------
```

#### Binary Operators for Integers

There are 12 binary operators for integers: `add`, `sub`, `mul`, `div_sx`, `rem_sx`, `and`, `or`, `xor`, `shl`, `shr_sx`, `rotl`, `rotr`.


- `add` returns the result of adding up the 2 given integers modulo 2^N.
- `sub` returns the result of substracting the second oprand from the first oprand modulo 2^N.
- `mul` returns the result of multiplying the 2 given integers modulo 2^N.

`add`, `sub`, and `mul` are given semantics by lifting the correct K operators through the `#chop` function.

```k
    syntax IBinOp ::= "add" | "sub" | "mul"
 // ---------------------------------------
    rule ITYPE:IValType . add I1 I2 => #chop(< ITYPE > I1 +Int I2)
    rule ITYPE:IValType . sub I1 I2 => #chop(< ITYPE > I1 -Int I2)
    rule ITYPE:IValType . mul I1 I2 => #chop(< ITYPE > I1 *Int I2)
```

- `div_sx` returns the result of dividing the first operand by the second oprand, truncated toward zero.
- `rem_sx` returns the remainder of dividing the first operand by the second oprand.

`div_sx` and `rem_sx` have extra side-conditions about when they are defined or not.

```k
    syntax IBinOp ::= "div_u" | "rem_u"
 // -----------------------------------
    rule ITYPE . div_u I1 I2 => < ITYPE > I1 /Int I2 requires I2 =/=Int 0
    rule _ITYPE . div_u _I1 I2 => undefined            requires I2  ==Int 0

    rule ITYPE . rem_u I1 I2 => < ITYPE > I1 %Int I2 requires I2 =/=Int 0
    rule _ITYPE . rem_u _I1 I2 => undefined            requires I2  ==Int 0

    syntax IBinOp ::= "div_s" | "rem_s"
 // -----------------------------------
    rule ITYPE . div_s I1 I2 => < ITYPE > #unsigned(ITYPE, #signed(ITYPE, I1) /Int #signed(ITYPE, I2))
      requires I2 =/=Int 0
       andBool #signed(ITYPE, I1) /Int #signed(ITYPE, I2) =/=Int #pow1(ITYPE)

    rule _ITYPE . div_s _I1 I2 => undefined
      requires I2 ==Int 0

    rule ITYPE . div_s I1 I2 => undefined
      requires I2 =/=Int 0
       andBool #signed(ITYPE, I1) /Int #signed(ITYPE, I2) ==Int #pow1(ITYPE)

    rule ITYPE . rem_s I1 I2 => < ITYPE > #unsigned(ITYPE, #signed(ITYPE, I1) %Int #signed(ITYPE, I2))
      requires I2 =/=Int 0

    rule _ITYPE . rem_s _I1 I2 => undefined
      requires I2 ==Int 0
```

- `and` returns the bitwise conjunction of the 2 given floats.
- `or` returns the bitwise disjunction of the 2 given floats.
- `xor` returns the bitwise exclusive disjunction of the 2 given floats.

Of the bitwise operators, `and` will not overflow, but `or` and `xor` could.
These simply are the lifted K operators.

```k
    syntax IBinOp ::= "and" | "or" | "xor"
 // --------------------------------------
    rule ITYPE . and I1 I2 =>       < ITYPE > I1 &Int   I2
    rule ITYPE . or  I1 I2 => #chop(< ITYPE > I1 |Int   I2)
    rule ITYPE . xor I1 I2 => #chop(< ITYPE > I1 xorInt I2)
```

- `shl` returns the result of shifting the first operand left by k bits modulo 2^N, in which k is the second operand modulo N.
- `shr_u` returns the result of shifting the first operand right by k bits, and extended with 0 bits.
- `shr_s` returns the result of shifting the first operand right by k bits, and  extended with the most significant bit of the original value

Similarly, K bitwise shift operators are lifted for `shl` and `shr_u`.
Careful attention is made for the signed version `shr_s`.

```k
    syntax IBinOp ::= "shl" | "shr_u" | "shr_s"
 // -------------------------------------------
    rule ITYPE . shl   I1 I2 => #chop(< ITYPE > I1 <<Int (I2 %Int #width(ITYPE)))
    rule ITYPE . shr_u I1 I2 =>       < ITYPE > I1 >>Int (I2 %Int #width(ITYPE))

    rule ITYPE . shr_s I1 I2 => < ITYPE > #unsigned(ITYPE, #signed(ITYPE, I1) >>Int (I2 %Int #width(ITYPE)))
```

- `rotl` returns the result of rotating the first operand left by k bits, in which k is the second operand modulo N.
- `rotr` returns the result of rotating the first operand right by k bits, in which k is the second operand modulo N.

The rotation operators `rotl` and `rotr` do not have appropriate K builtins, and so are built with a series of shifts.

```k
    syntax IBinOp ::= "rotl" | "rotr"
 // ---------------------------------
    rule ITYPE . rotl I1 I2 => #chop(< ITYPE > (I1 <<Int (I2 %Int #width(ITYPE))) +Int (I1 >>Int (#width(ITYPE) -Int (I2 %Int #width(ITYPE)))))
    rule ITYPE . rotr I1 I2 => #chop(< ITYPE > (I1 >>Int (I2 %Int #width(ITYPE))) +Int (I1 <<Int (#width(ITYPE) -Int (I2 %Int #width(ITYPE)))))
```

#### Binary Operators for Floats

There are 7 binary operators for integers: `add`, `sub`, `mul`, `div`, `min`, `max`, `copysign`.

- `add` returns the result of adding the 2 given floats and rounded to the nearest representable value.
- `sub` returns the result of substracting the second oprand from the first oprand and rounded to the nearest representable value.
- `mul` returns the result of multiplying the 2 given floats and rounded to the nearest representable value.
- `div` returns the result of dividing the first oprand by the second oprand and rounded to the nearest representable value.
- `min` returns the smaller value of the 2 given floats.
- `max` returns the bigger value of the 2 given floats.
- `copysign` returns the first oprand if the 2 given floats have the same sign, otherwise returns the first oprand with negated sign.

Note: For operators that defined under both sorts `IXXOp` and `FXXOp`, we need to give it a `klabel` and define it as a `symbol` to prevent parsing issue.

```k
    syntax FBinOp ::= "add" [klabel(floatAdd), symbol]
                    | "sub" [klabel(floatSub), symbol]
                    | "mul" [klabel(floatMul), symbol]
                    | "div"
                    | "min"
                    | "max"
                    | "copysign"
 // ----------------------------
    rule FTYPE:FValType . add      F1 F2 => < FTYPE > F1 +Float F2
    rule FTYPE:FValType . sub      F1 F2 => < FTYPE > F1 -Float F2
    rule FTYPE:FValType . mul      F1 F2 => < FTYPE > F1 *Float F2
    rule FTYPE          . div      F1 F2 => < FTYPE > F1 /Float F2
    rule FTYPE          . min      F1 F2 => < FTYPE > minFloat (F1, F2)
    rule FTYPE          . max      F1 F2 => < FTYPE > maxFloat (F1, F2)
    rule FTYPE          . copysign F1 F2 => < FTYPE > F1                requires signFloat (F1) ==Bool  signFloat (F2)
    rule FTYPE          . copysign F1 F2 => < FTYPE > --Float  F1       requires signFloat (F1) =/=Bool signFloat (F2)
```

### Test Operators

Test operations consume one operand and produce a bool, which is an `i32` value.
There is no test operation for float numbers.

```k
    syntax Val ::= IValType "." TestOp Int [klabel(intTestOp), function]
 // --------------------------------------------------------------------
```

#### Test Operators for Integers

- `eqz` checks wether its operand is 0.

```k
    syntax TestOp ::= "eqz"
 // -----------------------
    rule _ . eqz I => < i32 > #bool(I ==Int 0)
```

### Relationship Operators

Relationship Operators consume two operands and produce a bool, which is an `i32` value.

```k
    syntax Val ::= IValType "." IRelOp Int   Int   [klabel(intRelOp)  , function]
                 | FValType "." FRelOp Float Float [klabel(floatRelOp), function]
 // -----------------------------------------------------------------------------
```

### Relationship Operators for Integers

There are 6 relationship operators for integers: `eq`, `ne`, `lt_sx`, `gt_sx`, `le_sx` and `ge_sx`.

- `eq` returns 1 if the 2 given integers are equal, 0 otherwise.
- `eq` returns 1 if the 2 given integers are not equal, 0 otherwise.

```k
    syntax IRelOp ::= "eq" | "ne"
 // -----------------------------
    rule _:IValType . eq I1 I2 => < i32 > #bool(I1 ==Int  I2)
    rule _:IValType . ne I1 I2 => < i32 > #bool(I1 =/=Int I2)
```

- `lt_sx` returns 1 if the first oprand is less than the second opeand, 0 otherwise.
- `gt_sx` returns 1 if the first oprand is greater than the second opeand, 0 otherwise.

```k
    syntax IRelOp ::= "lt_u" | "gt_u" | "lt_s" | "gt_s"
 // ---------------------------------------------------
    rule _     . lt_u I1 I2 => < i32 > #bool(I1 <Int I2)
    rule _     . gt_u I1 I2 => < i32 > #bool(I1 >Int I2)

    rule ITYPE . lt_s I1 I2 => < i32 > #bool(#signed(ITYPE, I1) <Int #signed(ITYPE, I2))
    rule ITYPE . gt_s I1 I2 => < i32 > #bool(#signed(ITYPE, I1) >Int #signed(ITYPE, I2))
```

- `le_sx` returns 1 if the first oprand is less than or equal to the second opeand, 0 otherwise.
- `ge_sx` returns 1 if the first oprand is greater than or equal to the second opeand, 0 otherwise.

```k
    syntax IRelOp ::= "le_u" | "ge_u" | "le_s" | "ge_s"
 // ---------------------------------------------------
    rule _     . le_u I1 I2 => < i32 > #bool(I1 <=Int I2)
    rule _     . ge_u I1 I2 => < i32 > #bool(I1 >=Int I2)

    rule ITYPE . le_s I1 I2 => < i32 > #bool(#signed(ITYPE, I1) <=Int #signed(ITYPE, I2))
    rule ITYPE . ge_s I1 I2 => < i32 > #bool(#signed(ITYPE, I1) >=Int #signed(ITYPE, I2))
```

### Relationship Operators for Floats

There are 6 relationship operators for floats: `eq`, `ne`, `lt`, `gt`, `le` and `ge`.

- `eq` returns 1 if the 2 given floats are equal, 0 otherwise.
- `ne` returns 1 if the 2 given floats are not equal, 0 otherwise.
- `lt` returns 1 if the first oprand is less than the second opeand, 0 otherwise.
- `gt` returns 1 if the first oprand is greater than the second opeand, 0 otherwise.
- `le` returns 1 if the first oprand is less than or equal to the second opeand, 0 otherwise.
- `ge` returns 1 if the first oprand is greater than or equal to the second opeand, 0 otherwise.

```k
    syntax FRelOp ::= "lt"
                    | "gt"
                    | "le"
                    | "ge"
                    | "eq" [klabel(floatEq), symbol]
                    | "ne" [klabel(floatNe), symbol]
 // ------------------------------------------------
    rule _          . lt F1 F2 => < i32 > #bool(F1 <Float   F2)
    rule _          . gt F1 F2 => < i32 > #bool(F1 >Float   F2)
    rule _          . le F1 F2 => < i32 > #bool(F1 <=Float  F2)
    rule _          . ge F1 F2 => < i32 > #bool(F1 >=Float  F2)
    rule _:FValType . eq F1 F2 => < i32 > #bool(F1 ==Float  F2)
    rule _:FValType . ne F1 F2 => < i32 > #bool(F1 =/=Float F2)
```

### Conversion Operators

Conversion operators always take a single argument as input and cast it to another type.
The operators are further broken down into subsorts for their input type, for simpler type-checking.

```k
    syntax Val ::= ValType "." CvtOp Number [klabel(numberCvtOp), function]
 // -----------------------------------------------------------------------

    syntax CvtOp ::= Cvti32Op | Cvti64Op | Cvtf32Op | Cvtf64Op
 // ----------------------------------------------------------
```

There are 7 conversion operators: `wrap`, `extend`, `trunc`, `convert`, `demote` ,`promote` and `reinterpret`.

- `wrap` takes an `i64` value, cuts of the 32 most significant bits and returns an `i32` value.

```k
    syntax Cvti64Op ::= "wrap_i64"
 // ------------------------------
    rule i32 . wrap_i64 I => #chop(< i32 > I)
```

- `extend` takes an `i32` type value, converts its type into the `i64` and returns the result.

```k
    syntax Cvti32Op ::= "extend_i32_u" | "extend_i32_s"
 // ---------------------------------------------------
    rule i64 . extend_i32_u I:Int => < i64 > I
    rule i64 . extend_i32_s I:Int => < i64 > #unsigned(i64, #signed(i32, I))
```

- `convert` takes an `int` type value and convert it to the nearest `float` type value.

```k
    syntax Cvti32Op ::= "convert_i32_s" | "convert_i32_u"
 // -----------------------------------------------------
    rule FTYPE . convert_i32_s I:Int => #round( FTYPE , #signed(i32, I) )
    rule FTYPE . convert_i32_u I:Int => #round( FTYPE , I )

    syntax Cvti64Op ::= "convert_i64_s" | "convert_i64_u"
 // -----------------------------------------------------
    rule FTYPE . convert_i64_s I:Int => #round( FTYPE , #signed(i64, I) )
    rule FTYPE . convert_i64_u I:Int => #round( FTYPE , I )
```

- `demote` turns an `f64` type value to the nearest `f32` type value.
- `promote` turns an `f32` type value to the nearest `f64` type value:

```k
    syntax Cvtf32Op ::= "promote_f32"
 // ---------------------------------
    rule f64 . promote_f32 F => #round( f64 , F )

    syntax Cvtf64Op ::= "demote_f64"
 // --------------------------------
    rule f32 . demote_f64  F => #round( f32 , F )
```

- `trunc` first truncates a float value, then convert the result to the nearest ineger value.

```k
    syntax Cvtf32Op ::= "trunc_f32_s" | "trunc_f32_u"
 // -------------------------------------------------
    rule ITYPE . trunc_f32_s F => undefined
      requires #isInfinityOrNaN (F) orBool (Float2Int(truncFloat(F)) >=Int #pow1(ITYPE)) orBool (0 -Int Float2Int(truncFloat(F)) >Int #pow1 (ITYPE))
    rule ITYPE . trunc_f32_u F => undefined
      requires #isInfinityOrNaN (F) orBool (Float2Int(truncFloat(F)) >=Int #pow (ITYPE)) orBool (Float2Int(truncFloat(F)) <Int 0)

    rule ITYPE . trunc_f32_s F => <ITYPE> #unsigned(ITYPE, Float2Int(truncFloat(F)))
      requires notBool (#isInfinityOrNaN (F) orBool (Float2Int(truncFloat(F)) >=Int #pow1(ITYPE)) orBool (0 -Int Float2Int(truncFloat(F)) >Int #pow1 (ITYPE)))
    rule ITYPE . trunc_f32_u F => <ITYPE> Float2Int(truncFloat(F))
      requires notBool (#isInfinityOrNaN (F) orBool (Float2Int(truncFloat(F)) >=Int #pow (ITYPE)) orBool (Float2Int(truncFloat(F)) <Int 0))

    syntax Cvtf64Op ::= "trunc_f64_s" | "trunc_f64_u"
 // -------------------------------------------------
    rule ITYPE . trunc_f64_s F => undefined
      requires #isInfinityOrNaN (F) orBool (Float2Int(truncFloat(F)) >=Int #pow1(ITYPE)) orBool (0 -Int Float2Int(truncFloat(F)) >Int #pow1 (ITYPE))
    rule ITYPE . trunc_f64_u F => undefined
      requires #isInfinityOrNaN (F) orBool (Float2Int(truncFloat(F)) >=Int #pow (ITYPE)) orBool (Float2Int(truncFloat(F)) <Int 0)

    rule ITYPE . trunc_f64_s F => <ITYPE> #unsigned(ITYPE, Float2Int(truncFloat(F)))
      requires notBool (#isInfinityOrNaN (F) orBool (Float2Int(truncFloat(F)) >=Int #pow1(ITYPE)) orBool (0 -Int Float2Int(truncFloat(F)) >Int #pow1 (ITYPE)))
    rule ITYPE . trunc_f64_u F => <ITYPE> Float2Int(truncFloat(F))
      requires notBool (#isInfinityOrNaN (F) orBool (Float2Int(truncFloat(F)) >=Int #pow (ITYPE)) orBool (Float2Int(truncFloat(F)) <Int 0))
```

**TODO**: Unimplemented: `inn.reinterpret_fnn`,  `fnn.reinterpret_inn`.

```k
endmodule
```

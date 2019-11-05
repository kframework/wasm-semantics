KWASM Lemmas
============

These lemmas aid in verifying WebAssembly programs behavior.
They are part of the *trusted* base, and so should be scrutinized carefully.

```k
module KWASM-LEMMAS
    imports WASM-TEXT
    imports WRC20
```

Basic logic
-----------

```k
    rule #bool(P) ==Int 0 => notBool P
```

Basic arithmetic
----------------

```k
    rule X modInt N => X
      requires 0 <=Int X
       andBool X  <Int N
      [simplification]
```

When reasoning about `#chop`, it's often the case that the precondition to the proof contains the information needed to indicate no overflow.
In this case, it's simpler (and safe) to simply discard the `#chop`, instead of evaluating it.

```k
    rule X modInt #pow(ITYPE) => #unsigned(ITYPE, X)
      requires #inSignedRange (ITYPE, X)
      [simplification]

    syntax Bool ::= #inUnsignedRange (IValType, Int) [function]
    syntax Bool ::= #inSignedRange   (IValType, Int) [function]
 // -----------------------------------------------------------
    rule #inUnsignedRange (ITYPE, I) => 0                 <=Int I andBool I <Int #pow (ITYPE)
    rule #inSignedRange   (ITYPE, I) => #minSigned(ITYPE) <=Int I andBool I <Int #pow1(ITYPE)

    syntax Int ::= #minSigned  ( IValType ) [function]
 // --------------------------------------------------
    rule #minSigned(ITYPE) => 0 -Int #pow1(ITYPE)
```

Memory
------

Memory is represented by a byte map, where each key is an index and each entry either empty (0) or a byte (1 to 255).
This invariant must be maintained by the semantics, and any failure to maintain it is a breach of the Wasm specification.
We want to make the variant explicit, so we introduce the following helper, which simply signifies that we assume a well-formed byte map:

```k
    syntax Bool ::= #isByteMap ( ByteMap ) [function, functional, smtlib(isByteMap)]
    syntax Bool ::= #isByte    ( KItem   ) [function, functional, smtlib(isByte)]
 // -----------------------------------------------------------------------------
    rule #isByteMap(ByteMap <| .Map         |>) => true
    rule #isByteMap(ByteMap <| (_ |-> V) M  |>) => #isByte(V) andBool #isByteMap(ByteMap <| M |>)
    rule #isByteMap(ByteMap <| M [ _ <- V ] |>) => #isByte(V) andBool #isByteMap(ByteMap <| M |>)

    rule #isByte(I:Int) => true
      requires 0 <=Int I
       andBool I <=Int 255
    rule #isByte(I:Int) => false
      requires notBool (0 <=Int I
                        andBool I <=Int 255)
    rule #isByte(I:KItem) => false
      requires notBool isInt(I)
```

With this invariant encoded, we can introduce the following lemma.

```k
    rule #isByteMap(BMAP) impliesBool (0 <=Int #get(BMAP, IDX) andBool #get(BMAP, IDX) <Int 256) => true [smt-lemma]
```

From the semantics, it should be clear that setting the index in a bytemap to the value already contained there will leave the map unchanged.
Conversely, setting an index in a map to a value `VAL` and then retrieving the value at that index will yield `VAL`.

```k
    rule #set(BMAP, IDX, #get(BMAP, IDX)) => BMAP [smt-lemma]
```

TODO: We should inspect the two functions `#getRange` and `#setRange` closer.
They are non-trivial in their implementation, but the following should obviously hold from the intended semantics.

```k
    rule #setRange(BM, EA, #getRange(BM, EA, WIDTH), WIDTH) => BM
```

```k
endmodule
```

Specialized Lemmas
==================

The following are lemmas that should not be included in every proof, but are necessary for certain proofs.

Concrete Memory
---------------

```k
module MEMORY-CONCRETE-TYPE-LEMMAS
    imports KWASM-LEMMAS

    rule #getRange(BM, START, WIDTH) => 0
      requires notBool (WIDTH >Int 0)
    rule #getRange(BM, START, WIDTH) => #get(BM, START) +Int (#getRange(BM, START +Int 1, WIDTH -Int 1) *Int 256)
      requires          WIDTH >Int 0

    rule #wrap(WIDTH, N) => N modInt (1 <<Int WIDTH)

endmodule
```

```k
module WRC20
    imports WASM-TEXT
```

A module of shorthand commands for the WRC20 module.

```k
    syntax Stmts ::= "#wrc20"
    syntax Defns ::= "#wrc20Body"
    syntax Defns ::= "#wrc20Imports"
    syntax Defns ::= "#wrc20Functions"
 // ----------------------------------
    rule #wrc20 => ( module #wrc20Body ) .EmptyStmts [macro]

    rule #wrc20Body => #wrc20Imports ++Defns #wrc20Functions [macro]

    rule #wrc20Imports =>
      (func String2Identifier("$revert")          ( import #unparseWasmString("\"ethereum\"") #unparseWasmString("\"revert\"") )          param i32 i32 .ValTypes .TypeDecls )
      (func String2Identifier("$finish")          ( import #unparseWasmString("\"ethereum\"") #unparseWasmString("\"finish\"") )          param i32 i32 .ValTypes .TypeDecls )
      (func String2Identifier("$getCallDataSize") ( import #unparseWasmString("\"ethereum\"") #unparseWasmString("\"getCallDataSize\"") ) result i32 .ValTypes .TypeDecls )
      (func String2Identifier("$callDataCopy")    ( import #unparseWasmString("\"ethereum\"") #unparseWasmString("\"callDataCopy\"") )    param i32 i32 i32 .ValTypes .TypeDecls )
      (func String2Identifier("$storageLoad")     ( import #unparseWasmString("\"ethereum\"") #unparseWasmString("\"storageLoad\"") )     param i32 i32 .ValTypes .TypeDecls )
      (func String2Identifier("$storageStore")    ( import #unparseWasmString("\"ethereum\"") #unparseWasmString("\"storageStore\"") )    param i32 i32 .ValTypes .TypeDecls )
      (func String2Identifier("$getCaller")       ( import #unparseWasmString("\"ethereum\"") #unparseWasmString("\"getCaller\"") )       param i32 .ValTypes .TypeDecls )
      ( memory ( export #unparseWasmString("\"memory\"") ) 1 )
      .Defns
      [macro]

    rule #wrc20Functions =>
      (func ( export #unparseWasmString("\"main\"") ) .TypeDecls .LocalDecls
        block .TypeDecls
          block .TypeDecls
            call String2Identifier("$getCallDataSize")
            i32.const 4
            i32.ge_u
            br_if 0
            i32.const 0
            i32.const 0
            call String2Identifier("$revert")
            br 1
            .EmptyStmts
          end
          i32.const 0
          i32.const 0
          i32.const 4
          call String2Identifier("$callDataCopy")
          block .TypeDecls
            i32.const 0
            i32.load
            i32.const 436376473:Int
            i32.eq
            i32.eqz
            br_if 0
            call String2Identifier("$do_balance")
            br 1
            .EmptyStmts
          end
          block .TypeDecls
            i32.const 0 i32.load
            i32.const 3181327709:Int
            i32.eq
            i32.eqz
            br_if 0
            call String2Identifier("$do_transfer")
            br 1
            .EmptyStmts
          end
          i32.const 0
          i32.const 0
          call String2Identifier("$revert")
          .EmptyStmts
        end
        .EmptyStmts
      )

      (func String2Identifier("$do_balance") .TypeDecls .LocalDecls
        block .TypeDecls
          block .TypeDecls
            call String2Identifier("$getCallDataSize")
            i32.const 24
            i32.eq
            br_if 0
            i32.const 0
            i32.const 0
            call String2Identifier("$revert")
            br 1
            .EmptyStmts
          end
          i32.const 0
          i32.const 4
          i32.const 20
          call String2Identifier("$callDataCopy")
          i32.const 0
          i32.const 32
          call String2Identifier("$storageLoad")
          i32.const 32
          i32.const 32
          i64.load
          call String2Identifier("$i64.reverse_bytes")
          i64.store
          i32.const 32
          i32.const 8
          call String2Identifier("$finish")
          .EmptyStmts
        end
        .EmptyStmts )

      (func String2Identifier("$do_transfer") .TypeDecls local i64 i64 i64 .ValTypes .LocalDecls
        block .TypeDecls
          block .TypeDecls
            call String2Identifier("$getCallDataSize")
            i32.const 32
            i32.eq
            br_if 0
            i32.const 0
            i32.const 0
            call String2Identifier("$revert")
            br 1
            .EmptyStmts
          end
          i32.const 0
          call String2Identifier("$getCaller")
          i32.const 32
          i32.const 4
          i32.const 20
          call String2Identifier("$callDataCopy")
          i32.const 64
          i32.const 24
          i32.const 8
          call String2Identifier("$callDataCopy")
          i32.const 64
          i64.load
          call String2Identifier("$i64.reverse_bytes")
          local.set 0
          i32.const 0
          i32.const 64
          call String2Identifier("$storageLoad")
          i32.const 64
          i64.load
          local.set 1
          i32.const 32
          i32.const 64
          call String2Identifier("$storageLoad")
          i32.const 64
          i64.load
          local.set 2
          block .TypeDecls
            local.get 0
            local.get 1
            i64.le_u
            br_if 0
            i32.const 0
            i32.const 0
            call String2Identifier("$revert")
            br 1
            .EmptyStmts
          end
          local.get 1
          local.get 0
          i64.sub
          local.set 1
          local.get 2
          local.get 0
          i64.add
          local.set 2
          i32.const 64
          local.get 1
          i64.store
          i32.const 0
          i32.const 64
          call String2Identifier("$storageStore")
          i32.const 64
          local.get 2
          i64.store
          i32.const 32
          i32.const 64
          call String2Identifier("$storageStore")
          .EmptyStmts
        end
        .EmptyStmts
      )

      (func String2Identifier("$i64.reverse_bytes") param i64 .ValTypes result i64 .ValTypes .TypeDecls local i64 i64 .ValTypes .LocalDecls
        block .TypeDecls
          loop .TypeDecls
            local.get 1
            i64.const 8
            i64.ge_u
            br_if 1
            local.get 0
            i64.const 56
            local.get 1
            i64.const 8
            i64.mul
            i64.sub
            i64.shl
            i64.const 56
            i64.shr_u
            i64.const 56
            i64.const 8
            local.get 1
            i64.mul
            i64.sub
            i64.shl
            local.get 2
            i64.add
            local.set 2
            local.get 1
            i64.const 1
            i64.add
            local.set 1
            br 0
            .EmptyStmts
          end
          .EmptyStmts
        end
        local.get 2
        .EmptyStmts
        )
      .Defns
      [macro]

    syntax Defns ::= Defns "++Defns" Defns [function, functional]
 // -------------------------------------------------------------
    rule .Defns ++Defns DS' => DS'
    rule (D DS) ++Defns DS' => D (DS ++Defns DS')
```

```k
endmodule
```

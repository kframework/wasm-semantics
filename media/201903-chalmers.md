---
title: 'Semantics of WebAssembly in the K framework'
subtitle: 'What is KWasm?'
author:
-   Rikard Hjort
-   Everett Hildenbrandt
date: '\today'
institute:
-   Chalmers University of Technology
-   Runtime Verification, Inc.
theme: metropolis
fontsize: 8pt
header-includes:
-   \newcommand{\instr}{instr}
-   \newcommand{\LOOP}{\texttt{loop}}
-   \newcommand{\LABEL}{\texttt{label}}
-   \newcommand{\END}{\texttt{end}}
-   \newcommand{\stepto}{\hookrightarrow}
---

Overview
--------

1.  Background
2.  Introduction to WebAssembly (Wasm)
3.  Introduction to K
4.  Demo: implement a Wasm subset
5.  Proving things
6.  Results: What did I do

Why WebAssembly in K?
==============================

Smart contracts and formal methods
------------

![](media/img/ethereum.png){ width=65%}

- Blockchain technology, **smart contracts** in particular, caught my interest.
- Public, immutable code handling lots of money? Great area of application for formal methods!

Existing projects
-------

![](media/img/maker.png){ width=20% align=center style="margin-bottom:40px"}

- Contacted friends at MakerDAO.
- They have verified the core contracts of their "stablecoin", Dai.

. . .

![](media/img/dapphub.png){ width=40% align=center style="margin-bottom:40px"}

- The verification was largely done by a related organization, DappHub ...

. . .

![](media/img/k.png){ height=15% hspace=30px } &nbsp;&nbsp;&nbsp;
<!-- ![](media/img/rv.png){ height=15%} -->

- ... using the K framework.

Verifying Ethereum contracts
---------

1. Contracts are compiled to EVM bytecode.
2. Some properties or invariant is specified in K.
3. K tries to construct proves that every possible execution path fulfills the
   stated properties
4. The tool KLab (by DappHub) offers an interactive view of execution paths,
   great for seeing what paths where the prover failed.



<!---


* Explain semantics of imp, that Id's always refer to unique identifiers.
* Replace `loop` example with own example (smth you wrote)







(Brief) Introduction to K/KEVM
==============================

K Vision
--------

![K Overview](media/k-overview.png)

K Tooling/Languages
-------------------

### Tools

-   Parser
-   Interpreter
-   Debugger
-   Reachability Logic Prover [@stefanescu-park-yuwen-li-rosu-reachability-prover]

. . .

### Languages

-   Java 1.4 - 2015 [@bogdanas-rosu-k-java]
-   C11 - 2015 [@hathhorn-ellison-rosu-k-c]
-   KJS - 2015 [@park-stefanescu-rosu-k-js]
-   KEVM - 2018 [@hildenbrandt-saxena-zhu-rosu-k-evm]
-   P4K - 2018 [@kheradmand-rosu-k-p4]
-   KIELE - 2018 [@kasampalis-guth-moore-rosu-johnson-k-iele]
-   KLLVM <https://github.com/kframework/llvm-semantics>
-   KX86-64 <https://github.com/kframework/X86-64-semantics>

The Vision: Language Independence
---------------------------------

![K Tooling Overview](media/k-overview.png)

K Specifications: Syntax
------------------------

Concrete syntax built using EBNF style:

```k
    syntax Exp ::= Int | Id | "(" Exp ")" [bracket]
                 | Exp "*" Exp
                 > Exp "+" Exp // looser binding

    syntax Stmt ::= Id ":=" Exp
                  | Stmt ";" Stmt
                  | "return" Exp
```

. . .

This would allow correctly parsing programs like:

```imp
    a := 3 * 2;
    b := 2 * a + 5;
    return b
```

K Specifications: Configuration
-------------------------------

Tell K about the structure of your execution state.
For example, a simple imperative language might have:

```k
    configuration <k>     $PGM:Program </k>
                  <env>   .Map         </env>
                  <store> .Map         </store>
```

. . .

> -   `<k>` will contain the initial parsed program
> -   `<env>` contains bindings of variable names to store locations
> -   `<store>` conaints bindings of store locations to integers

K Specifications: Transition Rules
----------------------------------

Using the above grammar and configuration:

. . .

### Variable lookup

```k
    rule <k> X:Id => V ... </k>
         <env>   ...  X |-> SX ... </env>
         <store> ... SX |-> V  ... </store>
```

. . .

### Variable assignment

```k
    rule <k> X := I:Int => . ... </k>
         <env>   ...  X |-> SX       ... </env>
         <store> ... SX |-> (V => I) ... </store>
```

Example Execution
-----------------

### Program

```imp
    a := 3 * 2;
    b := 2 * a + 5;
    return b
```

### Initial Configuration

```k
    <k>     a := 3 * 2 ; b := 2 * a + 5 ; return b </k>
    <env>   a |-> 0    b |-> 1 </env>
    <store> 0 |-> 0    1 |-> 0 </store>
```

Example Execution (cont.)
-------------------------

### Variable assignment

```k
    rule <k> X := I:Int => . ... </k>
         <env>   ...  X |-> SX       ... </env>
         <store> ... SX |-> (V => I) ... </store>
```

### Next Configuration

```k
    <k>     a := 6 ~> b := 2 * a + 5 ; return b </k>
    <env>   a |-> 0    b |-> 1 </env>
    <store> 0 |-> 0    1 |-> 0 </store>
```

Example Execution (cont.)
-------------------------

### Variable assignment

```k
    rule <k> X := I:Int => . ... </k>
         <env>   ...  X |-> SX       ... </env>
         <store> ... SX |-> (V => I) ... </store>
```

### Next Configuration

```k
    <k>               b := 2 * a + 5 ; return b </k>
    <env>   a |-> 0    b |-> 1 </env>
    <store> 0 |-> 6    1 |-> 0 </store>
```

Example Execution (cont.)
-------------------------

### Variable lookup

```k
    rule <k> X:Id => V ... </k>
         <env>   ...  X |-> SX ... </env>
         <store> ... SX |-> V  ... </store>
```

### Next Configuration

```k
    <k>     a ~> b := 2 * [] + 5 ; return b </k>
    <env>   a |-> 0    b |-> 1 </env>
    <store> 0 |-> 6    1 |-> 0 </store>
```

Example Execution (cont.)
-------------------------

### Variable lookup

```k
    rule <k> X:Id => V ... </k>
         <env>   ...  X |-> SX ... </env>
         <store> ... SX |-> V  ... </store>
```

### Next Configuration

```k
    <k>     6 ~> b := 2 * [] + 5 ; return b </k>
    <env>   a |-> 0    b |-> 1 </env>
    <store> 0 |-> 6    1 |-> 0 </store>
```

Example Execution (cont.)
-------------------------

### Variable lookup

```k
    rule <k> X:Id => V ... </k>
         <env>   ...  X |-> SX ... </env>
         <store> ... SX |-> V  ... </store>
```

### Next Configuration

```k
    <k>          b := 2 * 6 + 5 ; return b </k>
    <env>   a |-> 0    b |-> 1 </env>
    <store> 0 |-> 6    1 |-> 0 </store>
```

Example Execution (cont.)
-------------------------

### Variable assignment

```k
    rule <k> X := I:Int => . ... </k>
         <env>   ...  X |-> SX       ... </env>
         <store> ... SX |-> (V => I) ... </store>
```

### Next Configuration

```k
    <k>     b := 17 ~> return b </k>
    <env>   a |-> 0    b |-> 1 </env>
    <store> 0 |-> 6    1 |-> 0 </store>
```

Example Execution (cont.)
-------------------------

### Variable assignment

```k
    rule <k> X := I:Int => . ... </k>
         <env>   ...  X |-> SX       ... </env>
         <store> ... SX |-> (V => I) ... </store>
```

### Next Configuration

```k
    <k>                return b </k>
    <env>   a |-> 0    b |-> 1  </env>
    <store> 0 |-> 6    1 |-> 17 </store>
```

KWasm Design
============

Wasm Specification
------------------

Available at <https://github.com/WebAssembly/spec>.

-   Fairly unambiguous[^betterThanEVM].
-   Well written with procedural description of execution accompanied by small-step semantic rules.

\vfill{}

. . .

Example rule:

1. Let $L$ be the label whose arity is 0 and whose continuation is the start of the loop.
2. `Enter` the block $\instr^\ast$ with label $L$.

\vfill{}

. . .

$$
    \LOOP~[t^?]~\instr^\ast~\END
    \quad \stepto \quad
    \LABEL_0\{\LOOP~[t^?]~\instr^\ast~\END\}~\instr^\ast~\END
$$

[^betterThanEVM]: Better than the [YellowPaper](https://github.com/ethereum/yellowpaper).

Translation to K
----------------

### Wasm Spec

\vspace{-1em}
$$
    \LOOP~[t^?]~\instr^\ast~\END
    \quad \stepto \quad
    \LABEL_0\{\LOOP~[t^?]~\instr^\ast~\END\}~\instr^\ast~\END
$$

. . .

### In K

```k
    syntax Instr ::= "loop" Type Instrs "end"
 // -----------------------------------------
    rule <k> loop TYPE IS end
          => IS
          ~> label [ .ValTypes ] {
                loop TYPE IS end
             } STACK
          ...
         </k>
         <stack> STACK </stack>
```

Design Difference: 1 or 2 Stacks?
---------------------------------

. . .

### Wasm Specification

One stack mixing values and instructions.

-   Confusing control-flow semantics (with `label`s).
-   Use meta-level context operator to describe semantics of `br`.
-   Section 4.4.5 of the Wasm spec.

\vfill{}

. . .

### KWasm

Uses two stacks, values in `<stack>` cell and instructions in `<k>` cell.

-   Can access both cells simultaneously, without backtracking/remembering one stack.
-   Cleaner semantics, no meta-level context operator needed.

Design Choice: Incremental Semantics
------------------------------------

-   KWasm semantics are given incrementally.
-   Makes it possible to execute program fragments.
-   Allows users to quickly experiment with Wasm using KWasm.

\vfill{}

. . .

For example, KWasm will happily execute the following fragment (without an enclosing `module`):

```wast
    (i32.const 4)
    (i32.const 5)
    (i32.add)
```

Using KWasm (Psuedo-Demo)
=========================

Getting/Building
----------------

Clone the repository:

```sh
git clone 'https://github.com/kframework/wasm-semantics'
cd wasm-semantics
```

Build the dependencies, then the KWasm semantics:

```sh
make deps
make build
```

`kwasm` Script
--------------

The file `./kwasm` is the main runner for KWasm.

### Running `./kwasm help`

```sh
usage: ./kwasm (run|test) [--backend (ocaml|java|haskell)] <pgm>  <K args>*
       ./kwasm prove      [--backend (java|haskell)]       <spec> <K args>*
       ./kwasm klab-(run|prove)                            <spec> <K args>*

    ./kwasm run   : Run a single WebAssembly program
    ./kwasm test  : Run a single WebAssembly program like it's a test
    ./kwasm prove : Run a WebAssembly K proof

    Note: <pgm> is a path to a file containing a WebAssembly program.
          <spec> is a K specification to be proved.
          <K args> are any arguments you want to pass to K when executing/proving.
```

Running a Program
-----------------

### Wasm Program `pgm1.wast`

```wasm
(i32.const 4)
(i32.const 5)
(i32.add)
```

### Result of `./kwasm run pgm1.wast`

```k
<generatedTop>
  <k>
    .
  </k>
  <stack>
    < i32 > 9 : .Stack
  </stack>
</generatedTop>
```

Demo Time!
----------

-   KLab debugging demo!!

Future Directions
=================

Finish KWasm
------------

The semantics are fairly early-stage.

### In progress

-   Memories.

### To be done

-   Everything floating point.
-   Tables.
-   Modules.

KeWasm
------

-   eWasm adds gas metering to Wasm, but otherwise leaves the semantics alone.

\vfill{}

. . .

-   KEVM currently has many verified smart contracts at <https://github.com/runtimeverification/verified-smart-contracts>.
-   We similarly would like to build a repository of verified code using KeWasm.

Conclusion/Questions?
=====================

References
----------

-   Thanks for listening!

\tiny


-->

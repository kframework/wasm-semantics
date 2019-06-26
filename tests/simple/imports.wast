(module
   (global (export "g") i32 (i32.const 42))
   (func (export "f"))
   )

(register "m")

(module
 (export "x" (global $x))
 (func (import "m" "f"))
 (global $x (import "m" "g") i32)
 (global (mut i32) (global.get $x))
 (func (export "foo") (result i32) (global.get 1))
 (func (export "mod") (global.set 1 (i32.const 10)))
 )

;; The globals in one module are independent from the globals in another.

(assert_return (invoke "foo") (i32.const 42))
(invoke "mod")
(assert_return (invoke "foo") (i32.const 10))
(assert_return (get "x") (i32.const 42))

#clearConfig
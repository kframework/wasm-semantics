;; There are some problems with this case case for now.
;; (module
;;   (memory 1)
;;   (data (i32.const 0) "\u{10ABEE}\u{1}\u{BCD}\u{EEAA}\u{EAEA}\u{E11}b")
;;   (func (export "32u_good1") (param $i i32) (result i64)
;;     (i64.load32_u offset=0 (local.get $i))
;;   )
;;   (func (export "32u_good2") (param $i i32) (result i64)
;;     (i64.load32_u offset=4 (local.get $i))
;;   )
;;   (func (export "32u_good3") (param $i i32) (result i64)
;;     (i64.load32_u offset=1 (local.get $i))
;;   )
;;   (func (export "32u_good4") (param $i i32) (result i64)
;;     (i64.load32_u offset=2 (local.get $i))
;;   )
;;   (func (export "32u_good5") (param $i i32) (result i64)
;;     (i64.load32_u offset=12 (local.get $i))
;;   )
;; )

;; (assert_return (invoke "32u_good1" (i32.const 0)) (i64.const 2930739956))
;; (assert_return (invoke "32u_good2" (i32.const 0)) (i64.const 2377113601))
;; (assert_return (invoke "32u_good3" (i32.const 0)) (i64.const 28225418))
;; (assert_return (invoke "32u_good4" (i32.const 0)) (i64.const 3758206639))
;; (assert_return (invoke "32u_good5" (i32.const 0)) (i64.const 3101731499))

;; #clearConfig

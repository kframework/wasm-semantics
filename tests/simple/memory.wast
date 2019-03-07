( memory )
#assertMemory 0 .MemBound "memory initial 1"

( memory 34)
#assertMemory 34 .MemBound "memory initial 2"

( memory 4 10 )
#assertMemory 4 10 "memory initial 3"

( memory 0 10 )
(memory.size)
#assertTopStack <i32> 0 "memory.size 1"
#assertMemory 0 10 "memory ungrown"

( memory 0 10 )
(memory.grow (i32.const 10))
(memory.size)
#assertStack <i32> 10 : < i32 > 0 : .Stack "memory grow"
(memory.grow (i32.const 1))
#assertTopStack <i32> -1 "memory grow"
#assertMemory 10 10 "memory grown"

( memory #maxMemorySize())
(memory.grow (i32.const 1))
#assertTopStack <i32> -1 "memory grow max too large"
#assertMemory #maxMemorySize() .MemBound "memory grow max too large"

( memory )
(memory.grow (i32.const #maxMemorySize()))
(memory.size)
#assertStack <i32> #maxMemorySize() : < i32 > 0 : .Stack "memory grow unbounded"
(memory.grow (i32.const 1))
(memory.size)
#assertStack <i32> #maxMemorySize() : < i32 > -1 : .Stack "memory grow unbounded"
#assertMemory #maxMemorySize() .MemBound "memory grown unbounded"


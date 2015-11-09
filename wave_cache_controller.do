onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_cache_controller/clk
add wave -noupdate /tb_cache_controller/reset
add wave -noupdate /tb_cache_controller/enable
add wave -noupdate -divider {Cache Memory}
add wave -noupdate -radix hexadecimal /tb_cache_controller/uut_cache/addr
add wave -noupdate /tb_cache_controller/uut_cache/op
add wave -noupdate -radix hexadecimal /tb_cache_controller/uut_cache/data
add wave -noupdate /tb_cache_controller/uut_cache/hit
add wave -noupdate -radix hexadecimal /tb_cache_controller/uut_cache/q
add wave -noupdate -radix hexadecimal /tb_cache_controller/uut_cache/mem
add wave -noupdate -radix hexadecimal /tb_cache_controller/uut_cache/tag_table
add wave -noupdate -divider {Cache Controller}
add wave -noupdate /tb_cache_controller/uut_controller/CoreValidIn
add wave -noupdate /tb_cache_controller/uut_controller/CoreLoadStore
add wave -noupdate -radix hexadecimal /tb_cache_controller/uut_controller/CoreAddrIn
add wave -noupdate -radix hexadecimal /tb_cache_controller/uut_controller/CoreDataIn
add wave -noupdate /tb_cache_controller/uut_controller/CoreValidOut
add wave -noupdate /tb_cache_controller/uut_controller/CoreAck
add wave -noupdate -radix hexadecimal /tb_cache_controller/uut_controller/CoreDataOut
add wave -noupdate -radix hexadecimal /tb_cache_controller/uut_controller/CacheDataIn
add wave -noupdate /tb_cache_controller/uut_controller/CacheHit
add wave -noupdate /tb_cache_controller/uut_controller/CacheOp
add wave -noupdate -radix hexadecimal /tb_cache_controller/uut_controller/CacheAddr
add wave -noupdate -radix hexadecimal /tb_cache_controller/uut_controller/CacheDataOut
add wave -noupdate /tb_cache_controller/uut_controller/current_s
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
quietly wave cursor active 0
configure wave -namecolwidth 318
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ps} {662 ps}

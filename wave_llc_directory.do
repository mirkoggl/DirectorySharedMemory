onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_directory/clk
add wave -noupdate /tb_directory/reset
add wave -noupdate /tb_directory/enable
add wave -noupdate -divider LLC
add wave -noupdate /tb_directory/uut_llc/raddr
add wave -noupdate /tb_directory/uut_llc/waddr
add wave -noupdate -radix hexadecimal /tb_directory/uut_llc/data
add wave -noupdate /tb_directory/uut_llc/we
add wave -noupdate -radix hexadecimal /tb_directory/uut_llc/q
add wave -noupdate -radix hexadecimal /tb_directory/uut_llc/ram
add wave -noupdate -divider Directory
add wave -noupdate /tb_directory/uut_directory/CCValidIn
add wave -noupdate /tb_directory/uut_directory/CCGetPutIn
add wave -noupdate -radix hexadecimal /tb_directory/uut_directory/CCAddrIn
add wave -noupdate -radix hexadecimal /tb_directory/uut_directory/CCDataIn
add wave -noupdate /tb_directory/uut_directory/CCValidOut
add wave -noupdate /tb_directory/uut_directory/CCAckOut
add wave -noupdate -radix hexadecimal /tb_directory/uut_directory/CCAddrOut
add wave -noupdate -radix hexadecimal /tb_directory/uut_directory/CCDataOut
add wave -noupdate /tb_directory/uut_directory/RouterValidIn
add wave -noupdate -radix hexadecimal /tb_directory/uut_directory/RouterDataIn
add wave -noupdate /tb_directory/uut_directory/RouterValidOut
add wave -noupdate -radix hexadecimal /tb_directory/uut_directory/RouterDataOut
add wave -noupdate -radix hexadecimal /tb_directory/uut_directory/MemDataIn
add wave -noupdate -radix hexadecimal /tb_directory/uut_directory/MemReadAddr
add wave -noupdate /tb_directory/uut_directory/MemWriteEn
add wave -noupdate -radix hexadecimal /tb_directory/uut_directory/MemWriteAddr
add wave -noupdate -radix hexadecimal /tb_directory/uut_directory/MemDataOut
add wave -noupdate -radix hexadecimal /tb_directory/uut_directory/directory
add wave -noupdate /tb_directory/uut_directory/current_s
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {285000 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 276
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
WaveRestoreZoom {0 ps} {1050 ns}

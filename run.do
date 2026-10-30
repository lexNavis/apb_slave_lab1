# --- Чистая компиляция ---
if {[file exists work]} { vdel -all -lib work }
vlib work
vlog -sv +cover=bcesft apb_slave.sv tb_apb_slave.sv

# --- Симуляция с покрытием ---
vsim -coverage -voptargs="+acc +cover=bcesft" TB

# Открыть окно Wave
view wave

# Добавить сигналы
add wave -divider "Clocks & Reset"
add wave -position end sim:/TB/pclk
add wave -position end sim:/TB/presetn

add wave -divider "APB Control"
add wave -position end sim:/TB/psel
add wave -position end sim:/TB/penable
add wave -position end sim:/TB/pwrite
add wave -position end sim:/TB/pready
add wave -position end sim:/TB/pslverr

add wave -divider "APB Data"
add wave -position hex sim:/TB/paddr
add wave -position hex sim:/TB/pwdata
add wave -position hex sim:/TB/prdata

add wave -divider "DUT Registers"
add wave -position hex sim:/TB/DUT/pi_hi
add wave -position hex sim:/TB/DUT/pi_lo
add wave -position hex sim:/TB/DUT/e_hi
add wave -position hex sim:/TB/DUT/e_lo
add wave -position hex sim:/TB/DUT/ctrl_reg

# Запустить симуляцию
run -all

# --- Отчёты ---
coverage report -summary
coverage report -details -output coverage_detail.rpt
coverage report -instance=/TB/DUT -details -output coverage_dut.rpt
coverage report -instance=/TB/DUT -html    -output coverage_dut_html
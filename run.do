# --- Чистая компиляция ---
if {[file exists work]} { vdel -all -lib work }
vlib work
vlog -sv +cover=bcesft apb_slave.sv tb_apb_slave.sv

# --- Симуляция с покрытием ---
vsim -coverage -voptargs="+acc +cover=bcesft" TB
run -all

# --- Отчёты ---
coverage report -summary
coverage report -details -output coverage_detail.rpt
coverage report -instance=/TB/DUT -details -output coverage_dut.rpt
coverage report -instance=/TB/DUT -html    -output coverage_dut_html
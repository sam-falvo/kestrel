help:
	@echo "make xrs.waves         Run register file testbench and plot waveforms"
	@echo
	@echo "make clean             remove output files"
	@echo

xrs.waves:
	iverilog -s xrs_tb ../../common/*.v bench/verilog/*.v rtl/verilog/*.v -I../../common && vvp -n a.out && gtkwave xrs.vcd

clean:
	rm -f *.blif *.asc *.bin *.vcd a.out

.PHONY: clean xrs.waves


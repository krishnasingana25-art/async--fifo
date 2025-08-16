# async--fifo
Verilog implementation of a dual-clock asynchronous FIFO (Gray code + 2FlipFlop CDC)

# Dual-Clock Asynchronous FIFO 

### Features
- Verilog RTL, synthesizable in Xilinx Vivado
- Dual clock domains (independent write and read clocks)
- FIFO pointers synchronized via **Gray coding**
- **2-flip-flop synchronizers** for safe CDC
- Randomized testbench for verification

### Files
- `rtl/async_fifo.v` 
- `sim/tb_async_fifo.v` 
- `README.md` 

### Simulation (example with Icarus Verilog)
```bash
iverilog -g2012 -o simv rtl/async_fifo.v sim/tb_async_fifo.v
vvp simv


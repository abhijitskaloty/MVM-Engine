# MVM Engine (SystemVerilog)

Matrix–vector multiplication accelerator for FPGA.

- **Throughput:** produces **27 outputs in parallel**
- **Fmax (tested):** **283 MHz**
- **Target board:** PYNQ-Z1 (Zynq-7000)
- **Toolchain:** Vivado + SystemVerilog

---

## What it does

Computes: `y = A · x`

- `x` is loaded into **vector memory**
- `A` is loaded into **matrix memory**
- the engine streams vector/matrix words into a pipelined dot-product datapath
- accumulators build each output element
- results appear on `o_result[0:NUM_OLANES-1]` with `o_valid`

---

## Design notes (high level)

- **Pipelined dot product**: 8-way dot product (`dot8`) using a reduction tree  
  - maps multiplications efficiently to **DSP48E1** slices
- **Accumulator**: signed accumulate with `first/last` framing
- **Control FSM**: generates read addresses and aligns `valid/first/last` through the pipeline
- **Memory**: dual-port style interface (write port + read port) used for vector + matrix storage

---

## Files

`src/`
- `mvm.sv`   – top-level engine (vector memory + N output lanes)
- `ctrl.sv`  – address generation + compute sequencing FSM
- `dot8.sv`  – 8-lane pipelined dot product
- `accum.sv` – accumulator with `first/last` control
- `mem.sv`   – memory block used by vector and matrix storage

`tb/`
- `tb_mvm.sv`   – end-to-end randomized test with golden reference
- `tb_ctrl.sv`  – controller sequencing checks
- `tb_dot8.sv`  – dot-product unit checks
- `tb_accum.sv` – accumulator checks

---

## Data layout

### Vector memory
- One memory word packs **8 signed elements** (`MEM_DATAW = 8 * IWIDTH`)
- Packing matches the slicing in `dot8.sv` (MSB chunk is element 0).

### Matrix memory
- Each output lane reads its own matrix stream.
- Rows are stored as consecutive words:
  - a row contains `i_vec_num_words` words
  - lane processes `i_mat_num_rows_per_olane` rows

---

## Simulate

In Vivado:
1. Create a project, add all `src/*.sv`
2. Add a testbench from `tb/` and set it as simulation top
3. Run behavioral simulation

Recommended order:
1. `dot8_tb.sv`
2. `accum_tb.sv`
3. `ctrl_tb.sv`
4. `mvm_tb.sv`

---

## FPGA build

1. Add `src/*.sv` to a Vivado project targeting PYNQ-Z1
2. Add constraints (clock + any required I/O constraints)
3. Synthesize → Implement → Generate bitstream
4. Program the board and integrate with your top-level wrapper (if applicable)

---

## Status

- Implemented modules: **dot product**, **accumulator**, **memory**, **control FSM**, **top-level MVM**
- Deployed on **PYNQ-Z1**
- Achieved **27 parallel outputs @ 283 MHz** (timing closed on target build)

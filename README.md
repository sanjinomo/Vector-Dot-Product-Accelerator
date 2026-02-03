# Pipelined Vector Dot Product Accelerator (FPGA)

A fully pipelined hardware accelerator for computing the dot product of two vectors on the **Terasic DE1-SoC FPGA**, designed using **SystemVerilog** and **Avalon-MM interfaces**. The accelerator offloads computation from the **ARM Cortex-A9 processor** and achieves significant speedup over a software-only implementation.


## Key Highlights
- Fully pipelined **64-bit MAC unit** (1 operation per cycle after fill)
- **DMA-based SDRAM access** via Avalon-MM Master
- **Dual FIFO buffering** to hide memory latency
- Hardware/software co-design with C-based ARM control program


## Architecture
- Avalon-MM **Slave**: CPU control, configuration, and result readback  
- Avalon-MM **Master**: Autonomous SDRAM reads (DMA)  
- Dual 64-entry FIFOs for vectors A and B  
- 3-state FSM: IDLE → RUN → DONE  

Once started, the accelerator streams data from SDRAM and computes the dot product without CPU intervention.


## Performance (Cycle Count)

| Vector Size | Software | Hardware | Speedup |
|------------|----------|----------|---------|
| 100 | 8,108 | 1,376 | **5.89×** |
| 200 | 9,948 | 1,416 | **7.03×** |
| 1,000 | 63,293 | 22,442 | **2.82×** |
| 10,000 | 632,031 | 221,996 | **2.85×** |

Best performance is achieved for moderate vector sizes; speedup saturates for large vectors due to SDRAM bandwidth limits.


## How to Run
1. Compile and program the design using **Quartus Prime Lite**
2. Build `main.c` using SoC EDS or ARM cross-compiler in our case we used Intel FPGA Monitor Program
3. Run on ARM HPS, enter vector size, and observe speedup



## Authors
**Sanjoy Dev**, **Shaba Altaf Shaon**  
*CPE 523 – Hardware/Software Co-design, UAH*


## Future Work
- Double buffering to reduce SDRAM latency  
- Wider memory interface for higher throughput  
- Extension to matrix–vector acceleration

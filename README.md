# Pipelined Vector Dot Product Accelerator (FPGA)

## Project Overview
[cite_start]This project presents the design, implementation, and performance evaluation of a fully pipelined hardware accelerator for computing the dot product of two vectors[cite: 702]. [cite_start]Developed on the **Terasic DE1-SoC FPGA** platform, the accelerator offloads compute-intensive vector operations from the **ARM Cortex-A9 CPU** to custom hardware logic to overcome sequential performance bottlenecks[cite: 700, 702, 703].

[cite_start]By leveraging **DMA-enabled memory access** and **dual FIFO buffering**, the design decouples memory latency from high-speed computation, enabling high-throughput execution[cite: 704, 780].

## Key Features
* [cite_start]**Fully Pipelined Architecture:** Utilizes a 64-bit Multiply-Accumulate (MAC) unit capable of processing one vector element per clock cycle once the pipeline is primed[cite: 704, 816].
* [cite_start]**Autonomous DMA Master:** Implements an **Avalon-MM Master interface** that autonomously fetches vector data from SDRAM without CPU intervention[cite: 704, 773, 779].
* [cite_start]**Decoupled Memory Buffering:** Employs dual 64-entry FIFOs to synchronize data streams and hide unpredictable SDRAM latency[cite: 704, 783, 784, 787].
* [cite_start]**Hardware/Software Co-Design:** Includes a complete C-based software stack to configure the accelerator via memory-mapped registers (Avalon-MM Slave) and verify results against a software baseline[cite: 703, 705, 764].



## Technical Specifications
| Component | Implementation Details |
| :--- | :--- |
| **FPGA Platform** | [cite_start]Terasic DE1-SoC (Cyclone V) [cite: 702] |
| **HDL** | [cite_start]SystemVerilog [cite: 703] |
| **Bus Interface** | [cite_start]Avalon Memory-Mapped (Master & Slave) [cite: 703, 764, 773] |
| **MAC Unit** | [cite_start]64-bit precision to prevent overflow [cite: 704, 816] |
| **Timer** | [cite_start]Avalon Interval Timer (Cycle-accurate, 100 MHz) [cite: 706, 836] |

## Performance Results
[cite_start]The accelerator was tested against a baseline software implementation (simple C loop) running on the ARM Cortex-A9[cite: 705].

| Vector Size (N) | Software (Cycles) | Hardware (Cycles) | Speedup (SW/HW) |
| :--- | :--- | :--- | :--- |
| 100 | 8,108 | 1,376 | [cite_start]**5.89x** [cite: 981] |
| 200 | 9,948 | 1,416 | [cite_start]**7.03x** [cite: 981] |
| 1,000 | 63,293 | 22,442 | [cite_start]**2.82x** [cite: 981] |
| 10,000 | 632,031 | 221,996 | [cite_start]**2.85x** [cite: 981] |

**Analysis:**
* [cite_start]**Startup Zone:** For very small vectors (N=10), hardware setup and SDRAM latency overhead dominate, leading to lower speedup[cite: 984].
* [cite_start]**Sweet Spot:** Optimal performance is reached between $N=100$ and $N=200$, where the MAC unit achieves near-peak throughput[cite: 986, 989].
* [cite_start]**Saturation Zone:** Beyond $N=500$, speedup plateaus (~2.85x) due to the memory bandwidth limitations of the 16-bit SDRAM interface[cite: 990, 991, 1027].



## Repository Structure
* [cite_start]`vec_mul_avalon_interface_32.sv`: Avalon-MM interface logic[cite: 1258].
* [cite_start]`vec_mul_pipe_core_32.sv`: Core computational logic and FSM[cite: 1383].
* [cite_start]`main.c`: ARM Cortex-A9 host application for performance measurement[cite: 1127].

## How to Run
1.  [cite_start]**Hardware:** Open the project in **Quartus Prime Lite**, compile the design, and program the DE1-SoC board[cite: 843].
2.  [cite_start]**Software:** Compile the C code using an SoC EDS environment or cross-compiler[cite: 747, 752].
3.  **Execution:** Run the executable on the ARM HPS. [cite_start]Use the terminal interface to enter vector sizes and observe cycle-accurate speedup results[cite: 1071].

---
[cite_start]**Authors:** Shaba Altaf Shaon and Sanjoy Dev [cite: 697]  
[cite_start]**Course:** CPE 523 Hardware/Software Co-design, UAH [cite: 698]

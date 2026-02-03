#include<stdio.h>
#include<stdlib.h>

#define H2F_BASE 0xFF200000
#define VEC_MUL_BASE 0x00000080
#define FPGA_SDRAM_BASE 0xC0000000
#define ACC_SDRAM_BASE 0x00000000

//Interval Timer
#define INTERVAL_TIMER_BASE 0xFF202000
#define CLK_FREQ 100000000.0

//Register offset
#define CTRL_REG 0
#define VEC_LENGTH 1
#define vecA_BaseAddress_REG 2
#define vecB_BaseAddress_REG 3
#define RES_LO 4
#define RES_HI 5

//Timer Functions
static inline void init_timer(volatile unsigned int* tbase){
	*(tbase + 1) = 0x8;     // STOP=1 in control reg
    *(tbase + 2) = 0xFFFF;  // period low
    *(tbase + 3) = 0xFFFF;  // period high
    *(tbase + 1) = 0x6;     // Start=1, CONT=1 (continuous mode)
}


static inline unsigned int read_timer(volatile unsigned int* tbase) {
	
	*(tbase + 4) = 0;                   // trigger snapshot
    unsigned int lo = *(tbase + 4);     // read SNAP Lower 
    unsigned int hi = *(tbase + 5);     // read SNAP Higher 
    return (hi << 16) | (lo & 0xFFFF); 	//return the snapped cc 
}



static inline void stop_timer(volatile unsigned int* tbase){
	*(tbase + 1) = 0x8;     // STOP=1 in control reg
	
}


long long vec_mul_hw_64(volatile unsigned int *vec_reg, unsigned int addressA, unsigned int addressB, int N, unsigned int* total_time) {
	volatile unsigned int * TIMER_ptr = (volatile unsigned int *) INTERVAL_TIMER_BASE;
	
	
	long long result = 0; 
	
	
	init_timer(TIMER_ptr);
	unsigned int start_time = read_timer(TIMER_ptr); //Start timer 
	
	//Write Registers
	vec_reg[VEC_LENGTH] = N; 
	vec_reg[vecA_BaseAddress_REG] = addressA; 
	vec_reg[vecB_BaseAddress_REG] = addressB; 
	
	//Start signal for accelerator
	vec_reg[CTRL_REG] = 1; 
	
	//This is the busy bit for the control reg. BUSY = 1 (RUN), BUSY = 0 (DONE)
	// When done we can get the result
	while((vec_reg[CTRL_REG] & 0x1) == 1);
	
	//Read Result HI and LO
	unsigned int res_lo = vec_reg[RES_LO];
	unsigned int res_hi = vec_reg[RES_HI];
	result =  ((long long) res_hi <<32) | res_lo;
	
	stop_timer(TIMER_ptr);
	unsigned int end_time = read_timer(TIMER_ptr);
	
	//Calculate the time and stop the timer 
	*total_time = start_time-end_time;
	
	
	//Concat the results first shift res_hi to upper 32 bits and then concat with res_lo 
	return result; 
	
}

long long vec_mul_sw_64 (volatile int *mem_ptr, int addressA, int addressB, int N, unsigned int* total_time){
	volatile unsigned int * TIMER_ptr = (volatile unsigned int *) INTERVAL_TIMER_BASE;
	
	
	long long result = 0; 
	
	init_timer(TIMER_ptr); 
	unsigned int start_time = read_timer(TIMER_ptr); //Start timer 
	
	//We initialize the vectors which points to the start address of SDRAM's each vector space 
	volatile int *vec_a = mem_ptr + addressA;
	volatile int *vec_b = mem_ptr + addressB; 
	
	//Calculate the vector dot product and accumulate in result 
	for (int i = 0; i<N; i++){
		result+=(long long) vec_a[i] * vec_b[i];
	}
	
	stop_timer(TIMER_ptr);
	
	unsigned int end_time = read_timer(TIMER_ptr);
	//Calculate the time and stop the timer 
	*total_time = start_time-end_time;

	
	return result; 
	
} 

int main(){
	volatile unsigned int *vec_reg = (volatile unsigned int *)(VEC_MUL_BASE + H2F_BASE);  //connects to the accelerator 
	volatile int *sdram_ptr = (volatile int *)(FPGA_SDRAM_BASE);
	
	unsigned int time_sw, time_hw; 
	
	
	printf("Welcome to Vector Dot Product Multiplication Calculator! \n"); 
	while(1){
		int N = 0; 
		printf("\nEnter the size of Vector: "); 
		scanf("%d", &N);

		//Start index in SDRAM 
		int addressA_startIndex = 0; 
		int addressB_startIndex = N; 
		
		//for the accelerator 
		unsigned int vecA_address = ACC_SDRAM_BASE + (addressA_startIndex*4);
		unsigned int vecB_address = ACC_SDRAM_BASE + (addressB_startIndex*4); 
		
		srand(0); 
		//Put random numbers in both the vectors 
		for(int i=0; i<N; i++){
			//generate random numbers from 0-9
			sdram_ptr[addressA_startIndex+i] = rand() % 10; 
			sdram_ptr[addressB_startIndex+i] = rand() % 10;
		}
		
		//Software RUN 
		long long res_sw = vec_mul_sw_64 (sdram_ptr, addressA_startIndex, addressB_startIndex, N, &time_sw); 
		
		printf("\n SW Result: %lld; Clock Cycles: %u cc ", res_sw, time_sw);
		
		//Hardware RUN 
		long long res_hw = vec_mul_hw_64 (vec_reg, vecA_address, vecB_address, N, &time_hw);
			
		printf("\n HW Result: %lld; Clock Cycles: %u cc ", res_hw, time_hw);
		
		
		//Check Speedup 
		printf("\nSpeedup: %.2fx\n", (double)time_sw/(double)time_hw); 
		
		printf("Continue (y/n)? ");
        char sel; scanf(" %c", &sel);
        if (sel == 'n' || sel == 'N') break;
		
		
	}
	return 0; 
	
}

module vec_mul_avalon_interface_32(
	//Avalon MM slave interface 
	input logic clock, 
	input logic resetn, 
	input logic read, 				//read signal from CPU 
	input logic write, 				//Write signal from CPU 
	input logic chipselect, 		//Component selection 
	input logic [2:0] address, 		//Register MAP offset 
	input logic [31:0] writedata, 	//Data from CPU
	output logic [31:0] readdata, 	//Data to CPU 
	
	//Avalon MM master interface (connected to SDRAM)
	output logic [31:0] avm_address, 		//address to read from SDRAM
	output logic avm_read, 					//read signal to SDRAM
	input logic [31:0] avm_readdata, 		//data from SDRAM 
	input logic avm_readdatavalid, 			//new data delivery signal 
	input logic avm_waitrequest, 			//Memory busy signal (need to wait)
	output logic [3:0] avm_bytenable, 		//bytes to read
	output logic [7:0] avm_burstcount		//number of items to read 
	
	
); 


	//The register MAP used: 
	//Address 0 Control&Busy (Read/Write) Bit 0: busy flag; Writing to this reg starts the process 
	//Address 1 VEC_Length (Read/Write) Number of elements "N"
	//Address 2 vecA_baseAddr (Read/Write) 	Base address of Vector A in SDRAM  
	//Address 3 vecB_baseAddr (Read/Write)  Base address of Vector B in SDRAM 
	//Address 4 RES_LO	(Read)		Lower 32 Bits of dot product Result 
	//Address 5 RES_HI 	(Read)		Upper 32 Bits of dot product Result 
	//Total 64 Bits for result 
	
	
	//Internal Registers 
	logic [31:0] vec_length; 		//Value of N, number of elements 
	logic [31:0] vecA_baseAddr;		//Base address of A in SDRAM 
	logic [31:0] vecB_baseAddr; 	//Base address of B in SDRAM 
	logic [31:0] RES_LO; 			//Lower 32 Bits of dot product Result
	logic [31:0] RES_HI;			//Upper 32 Bits of dot product Result
	
	//Signals for core computation 
	logic dot_start; 
	logic dot_busy; 
	logic dot_busy_prev; 
	//64 bit Dot product result 
	logic [63:0] dot_result;
	
	
	//computation start logic 
	assign dot_start = chipselect & write & (address == 3'd0); //Address 0 in for Control, writing anything starts the computation 
	
	
	vec_mul_pipe_core_32 coreComp (
		//Avalon MM slave
		.clock(clock),
		.resetn(resetn), 
		.start(dot_start), 					//start of process
		.length(vec_length),			//length of the vectors 
		.vecA_baseAddr(vecA_baseAddr),	//start address of Vector A
		.vecB_baseAddr(vecB_baseAddr), 	//Start address of Vector B
		.busy(dot_busy), 					//busy status 
		.result(dot_result), 		//accumulated result 
		
		
		//Avalon MM master (connected to the SDRAM)
		.avm_address(avm_address), 	//address to read from SDRAM 
		.avm_read(avm_read), 				//read signal to SDRAM 
		.avm_readdata(avm_readdata),		//data from SDRAM 
		.avm_readdatavalid(avm_readdatavalid), 		//new data delivery signal 
		.avm_waitrequest(avm_waitrequest), 		//Memory busy signal (need to wait)
		.avm_bytenable(avm_bytenable), 	//bytes to read
		.avm_burstcount(avm_burstcount)	//number of items to read 	
	
	
	);
	
	//Write logic from CPU to FPGA 
	always_ff @(posedge clock or negedge resetn) begin 
	
		if(!resetn) begin 
			vecA_baseAddr <= 32'b0; 
			vecB_baseAddr <= 32'b0;
			RES_LO <= 32'b0; 
			RES_HI <= 32'b0; 
			dot_busy_prev <= 1'b0; 
			
		end 
		
		else begin 
			if (chipselect & write) begin 
				case(address) 
					3'd1:  vec_length <= writedata; 		//Writes length 
					3'd2:  vecA_baseAddr <= writedata;  	//Writes Base address of A
					3'd3:  vecB_baseAddr <= writedata; 		//Writes Base address of B 
					default: ; 
				endcase 
			end 
			
			//Will need to store the result 
			//check if it is busy in the previous cycle
			dot_busy_prev <= dot_busy; 
			if(dot_busy_prev && !dot_busy) begin 
				RES_LO <= dot_result[31:0]; 
				RES_HI <= dot_result[63:32]; 
			end 
		end
	end
	
	//Read logic from FPGA to CPU 
	always_comb begin 
		readdata = 32'b0; 
		
		if(chipselect & read) begin 
			case(address) 
				3'd0: readdata = {31'b0, dot_busy}; //Control/Busy Register 
				3'd1: readdata = vec_length; 		//Read back Length N 
				3'd2: readdata = vecA_baseAddr; 	//Read back Base address of A 
				3'd3: readdata = vecB_baseAddr;		//Read back Base address of B 
				3'd4: readdata = RES_LO; 			//Read Lower 32 bits Result
				3'd5: readdata = RES_HI; 			//Read Upper 32 bits Result 
				default: readdata = 32'b0; 
			endcase
		end 
	end 
	
endmodule 
	
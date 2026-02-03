//We will use 3 states here: IDLE, RUN, DONE

module vec_mul_pipe_core_32 (
	//Avalon MM slave
	input logic clock,
	input logic resetn, 
	input logic start, 					//start of process
	input logic [31:0] length,			//length of the vectors 
	input logic [31:0] vecA_baseAddr,	//start address of Vector A
	input logic [31:0] vecB_baseAddr, 	//Start address of Vector B
	output logic busy, 					//busy status 
	output logic [63:0] result, 		//accumulated result 
	
	
	//Avalon MM master (connected to the SDRAM)
	output logic [31:0] avm_address, 	//address to read from SDRAM 
	output logic  avm_read, 				//read signal to SDRAM 
	input logic [31:0] avm_readdata,		//data from SDRAM 
	input logic avm_readdatavalid, 		//new data delivery signal 
	input logic avm_waitrequest, 		//Memory busy signal (need to wait)
	output logic [3:0] avm_bytenable, 	//bytes to read
	output logic [7:0] avm_burstcount	//number of items to read 
	


);
	
	
	//2 FIFO Buffers
	//One for Vector A and One for Vector Buffers
	//Used for calculation of the vector dot product so that the calculation will not totally depend on the memory
	//also while fetching from memory some data might lost 
	localparam FIFO_DEPTH = 64; 
	logic [31:0] FIFO_A [0:FIFO_DEPTH-1]; 						//FIFO for vector A 
	logic [31:0] FIFO_B [0:FIFO_DEPTH-1]; 						//FIFO for vector B
	logic [$clog2(FIFO_DEPTH):0] FIFO_A_count, FIFO_B_count;	//available items in the FIFOs
	logic [$clog2(FIFO_DEPTH)-1:0] write_A_ptr, write_B_ptr, read_A_ptr, read_B_ptr;	//Fifo read and write pointers
	
	//state machine 
	typedef enum logic [1:0] {IDLE, RUN, DONE} state_t; 
	state_t state; 
	
	//Internal logics
	logic [31:0] read_req_index; 		//number of read requests sent, also works as index 
	logic [31:0] calculation_index; 	//number of calculations done 
	logic [31:0] vec_length; 			//vector length 
	logic [63:0] accum; 				//accumulated dot product 
	logic readReq_b; 					//0 = request is A, 1 = request if B 
	logic dataRecv_b; 					//0 = data received is A, 1 = data received is B 
	
	assign busy = (state != IDLE); 		//busy if not in IDLE 
	assign result = accum; 				//Get the total vector dot product from accum 
	
	assign avm_burstcount = 8'b1; 		//read 1 word at a time 
	assign avm_bytenable = 4'b1111; 		//read all 4 bytes (32 bits)
	
	//Combinational logic to calculate the next address 
	always_comb begin 
		avm_address = 0; 
		avm_read = 0; 
		
		//Requests for Data in RUN state and until everything is fetched 
		if (state == RUN && read_req_index < vec_length) begin 
			//checks if FIFO has space 
			if(FIFO_A_count < (FIFO_DEPTH-2) && FIFO_B_count < (FIFO_DEPTH-2)) begin 
				avm_read = 1'b1; 	//read signal to SDRAM 
				
				//Address calculation (Base + )
				if(!readReq_b)
					avm_address = vecA_baseAddr + (read_req_index << 2); //Request vec A data
				else 
					avm_address = vecB_baseAddr + (read_req_index << 2); //Request vec B data 
			end
		end
	end 
	
	//Main Sequential Logic

	always_ff @(posedge clock or negedge resetn) begin 
	
		if(!resetn) begin 
			//reset everything to 0 
			state <= IDLE; 
			read_req_index <= 0; 
			calculation_index <= 0; 
			vec_length <= 0; 
			accum <= 0; 
			readReq_b <= 0; 
			dataRecv_b <= 0; 
			write_A_ptr <=0; 
			write_B_ptr <= 0; 
			read_A_ptr <= 0; 
			read_B_ptr <= 0; 
			
		end 
		
		else begin 
			case(state) 
				IDLE: begin 
					if (start) begin 
						state <= RUN;			//Next state will go to RUN  
						vec_length <= length; 	//vector length 
						//else everything in IDLE state will remain 0
						read_req_index <= 0; 
						calculation_index <= 0; 
						accum <= 0;
						readReq_b <= 0; 
						dataRecv_b <= 0; 
						write_A_ptr <=0; 
						write_B_ptr <= 0; 
						read_A_ptr <= 0; 
						read_B_ptr <= 0; 
					end 
					
				end
				RUN: begin 

					//if master_read (signal) is high and no wait from SDRAM 
					if (avm_read && !avm_waitrequest) begin 
						
						//If requested B, then the pair just finished (..A, B) so we will inrease the index for the next pair 
						if (readReq_b) begin 
							read_req_index <= read_req_index + 1;
						end 
						
						//we toggle from A to B or B to A 
						readReq_b <= ~readReq_b; 
					end 
					
					//If all the index's calculation is done up to length then the next state will be DONE 
					if (calculation_index == vec_length) begin
						state <= DONE; 
						
					end 
				end 
				
				DONE: begin 
					state <= IDLE; 	//in DONE state we just transit to the IDLE state 
				end 
			endcase 
			
			
			//Data push in FIFO 
			//Checks if the new data is ready  
			if (avm_readdatavalid) begin 
				//whose turn? A or B 
				if(!dataRecv_b) begin 
					FIFO_A[write_A_ptr] <= avm_readdata;		//push it into buffer 
					write_A_ptr <= write_A_ptr + 1; 			//increase the write pointer 
					FIFO_A_count <= FIFO_A_count + 1; 			//increase the FIFOA counter 
				end
				
				else begin 
					FIFO_B[write_B_ptr] <= avm_readdata;		//push it into buffer 
					write_B_ptr <= write_B_ptr + 1; 			//increase the write pointer 
					FIFO_B_count <= FIFO_B_count + 1; 			//increase the FIFOB counter 
				end 
				
				//toggle to the next A to B or B to A 
				dataRecv_b <= ~dataRecv_b;
			end 
			
			//Calculation in MAC 
			//So after receiving the response from the SDRAM to FIFOs when we have values in the Buffer we can start out MAC 
			if (state == RUN && (FIFO_A_count > 0) && (FIFO_B_count > 0)) begin 
				//runs the main calculation logic using the read pointer of FIFO 
				accum <= accum + (($signed(FIFO_A[read_A_ptr]))*($signed(FIFO_B[read_B_ptr]))); 
				
				//after calcualtion we increase the read pointer and the calculation index 
				read_A_ptr <= read_A_ptr+1; 
				read_B_ptr <= read_B_ptr+1; 
				calculation_index <= calculation_index+1; 
				
				//Done with the calculation
				//Need to update the FIFO counters 
				//In pipelined, both a paired Data can be received and another calcualted at same cycle (counter remains same)
				//If only calculated, we decrement the counter 
				//For FIFO A
				if(avm_readdatavalid && !dataRecv_b) begin 
					FIFO_A_count <= FIFO_A_count; 	//Both Data received and calculated 
				end 
				
				else begin 
					FIFO_A_count <= FIFO_A_count-1; //Only calculated 
				end 
				
				//For FIFO B 
				if (avm_readdatavalid && dataRecv_b) begin 
					FIFO_B_count <= FIFO_B_count; //Both Data rececived and calculated 
				end 
				
				else begin 
					FIFO_B_count <= FIFO_B_count-1; //Only calculated 
				end 
			end 
				
				
		end
	end 
	
endmodule 
use work.bv_arithmetic.all; 
use work.dlx_types.all; 

--Student: Yinbo Chen

entity simpleRisc_controller is
	port(ir_control: in dlx_word;
	     alu_out_control: in dlx_word; 
	     regfile_out_bus_control: in dlx_word; 
	     alu_error_control: in error_code; 
	     clock_control: in bit; 
	     control_regfile_mux: out bit; 
	     control_mem_addr_mux: out bit;
	     control_pc_mux: out bit; 
	     control_writeback_mux: out bit; 
	     control_op2r_mux: out bit; 
	     control_alu_func: out alu_operation_code; 
	     control_regfile_index: out register_index;
	     control_regfile_readnotwrite: out bit; 
	     control_regfile_clk: out bit;   
	     control_mem_clk: out bit;
	     control_mem_readnotwrite: out bit;  
	     control_ir_clk: out bit;    
             control_pc_clk: out bit; 
	     control_op1r_clk: out bit; 
	     control_op2r_clk: out bit;
	     control_alu_out_reg_clk: out bit 
	     ); 
end simpleRisc_controller; 

architecture behavior of simpleRisc_controller is
begin
	behav: process(clock_control) is 
		type state_type is range 1 to 20; 
		variable state: state_type := 1; 
		variable opcode: opcode_type; 
		variable destination,operand1,operand2 : register_index; 
		variable func_code : alu_operation_code; 
		variable condition: dlx_word; 

	begin
		if clock_control'event and clock_control = '1' then
		
		   case state is
			when 1 => -- fetch the instruction, for all types
				-- 
				control_mem_readnotwrite <= '1' after 5 ns; 
				control_mem_clk <= '1' after 5 ns; 
				control_mem_addr_mux <= '0' after 5 ns; -- instr addr comes from pc
				control_ir_clk <= '1' after 25 ns; -- latch the instruction into IR;
				state := 2; 
			when 2 => 
				 -- decode the instruction
		  		 opcode := ir_control(31 downto 26);
		     		
		   		 operand1 := ir_control(25 downto 21);
		   		 operand2 := ir_control(20 downto 16); 
 				 destination := ir_control(15 downto 11);
		   		 func_code := ir_control(10 downto 7);

				-- figure out which instruction and branch to correct state
	
			 	if opcode = "000000" then -- LOAD
					state := 6; 
				elsif opcode = "000001" then  -- STORE 
					state := 10;
				elsif opcode = "000010" then -- ALU
					state := 3;
				elsif opcode = "000011" or opcode = "000100" or opcode = "000101" then -- jumps
					state := 14;
				else -- error
				end if; 
  
			when 3 =>  -- ALU destination, operand1, operand2
				control_regfile_readnotwrite <= '1' after 15 ns; -- get operand1 from regfile
				control_regfile_index <= operand1 after 15 ns;
				control_regfile_clk <= '1' after 15 ns; 
				control_op1r_clk <= '1' after 30 ns; -- put it in op1r
				state := 4; 
			when 4 =>  --ALU operation read op2 from mux
				control_regfile_readnotwrite <= '1' after 15 ns;
				control_op2r_mux <= '0' after 15 ns;
				control_regfile_index <= operand2 after 15 ns;
				control_regfile_clk <= '1' after 15 ns;
				control_op2r_clk <= '1' after 30 ns; -- put it in op2r
				state := 5; 
			when 5 => --ALU operation
				control_alu_func <= func_code; -- combine op2r and op1r with func code
				control_alu_out_reg_clk <= '1' after 15 ns; -- arrive alu_out_reg
				control_writeback_mux <= '0' after 30 ns; -- via alu_out_bus to writeback_mux with value 0
				control_regfile_mux <= '0' after 30 ns; -- arrive regfile_mux with value 0 to data_in
				control_regfile_readnotwrite <= '0' after 30 ns; --write back to destination
				control_regfile_index <= destination after 30 ns;
				control_regfile_clk <= '1' after 30 ns; -- regfile is ready
				-- PC <= PC +1
				control_pc_mux <= '0' after 15 ns; --pcplusone_out into pc_in with value 0
				control_pc_clk <= '1' after 30 ns; -- pc+ 1 is ready

				state := 1;	
            			
			when 6 =>  -- LD destination,base(operand1)
				control_pc_mux <= '0' after 15 ns;
				control_pc_clk <= '1' after 30 ns;
				state := 7; 
			when 7 => 
				-- from pc_out via mem_addr_mux and mem_addr_in and mem_data_bus to op2r_mux with value 1
				control_mem_addr_mux <= '0' after 5 ns;
				control_mem_readnotwrite <= '1' after 5 ns;
				control_mem_clk <= '1' after 5 ns;
				control_op2r_mux <= '1' after 15 ns;
				control_op2r_clk <= '1' after 30 ns;
				--read operand 1 index to op1r
				control_regfile_readnotwrite <= '1' after 5 ns;
				control_regfile_index <= operand1 after 5 ns;
				control_regfile_clk <= '1' after 5 ns;
				control_op1r_clk <= '1' after 30 ns;	
				state := 8;
			when 8 => --ALU unsign add operation	
				control_alu_func <= "0000"; -- alu unsign add
				control_alu_out_reg_clk <= '1' after 15 ns;
				state := 9; 
			when 9 => --from alu_out_reg via mem_addr_mux to memory to mem_data_bus to regfile_mux
				control_mem_addr_mux <= '1' after 5 ns;
				control_mem_clk <= '1' after 5 ns;
				control_mem_readnotwrite <= '1' after 5 ns;
				control_regfile_mux <= '1' after 15 ns;
				control_regfile_index <=  destination after 5 ns;
				control_regfile_readnotwrite <= '0' after 30 ns;
				control_regfile_clk <= '1' after 30 ns; --regfile[destination] is ready
				--pc++
				control_pc_mux <= '0' after 15 ns; 
				control_pc_clk <= '1' after 30 ns; 			
				state := 1; 

			when 10 =>  -- STO  operand1,base[destination]
				--pc++
				control_pc_mux <= '0' after 15 ns; 
				control_pc_clk <= '1' after 30 ns; 	
				state := 11; 
			when 11 => --pc to mem_addr_mux to mem_addr_in to memory via data_bus to op2r_mux, arrive op2r
				control_mem_addr_mux <= '0' after 15 ns;
				control_mem_clk <= '1' after 15 ns;
				control_mem_readnotwrite <= '1' after 5 ns;
				control_op2r_mux <= '1' after 15 ns;
				control_op2r_clk <= '1' after 30 ns; --finish Mem[pc]->op2r
				--start regfile[destination]-> op1r
				control_regfile_readnotwrite <= '1' after 15 ns;
				control_regfile_index <= destination after 30 ns;
				control_regfile_clk <= '1' after 15 ns; 
				control_op1r_clk <= '1' after 30 ns; --op1r is ready
				state := 12; 
			when 12 => --similar to state 8 (ALU unsign add operation)
				control_alu_func <= "0000";
				control_alu_out_reg_clk <= '1' after 15 ns;
				
				state := 13; 
			when 13 =>   
				--Regfile[operand1] from op1r goes regfile_out to writeback_mux with value 1
				control_regfile_readnotwrite <= '1' after 30 ns; -- get operand1 from regfile
				control_regfile_index <= operand1 after 30 ns;
				control_regfile_clk <= '1' after 30 ns; 
				control_writeback_mux <= '1' after 15 ns;
				--alu_out_reg via mem_addr_mux to memory and write
				control_mem_addr_mux <= '1' after 15 ns;
				control_mem_readnotwrite <= '0' after 5 ns; --write
				control_mem_clk <= '1' after 15 ns; --finish writing
				--pc++
				control_pc_mux <= '0' after 15 ns; 
				control_pc_clk <= '1' after 30 ns; 
				state := 1;		
            
			when 14 => -- JMP   JZ op2,base[op1]  JNZ op2,base[op1]
				--pc++
				control_pc_mux <= '0' after 15 ns; 
				control_pc_clk <= '1' after 30 ns; 
				state := 15; 
			when 15 => 
				--Mem[pc]-> op2r
				-- pc(from state 14) to mem_addr_mux(0) via mem_add_in to memory, via mem_data_bus to op2r_mux(1), arrive op2r
				--I removed some values for jump states with ? mark, you may need to figure it out by yourself.
            control_mem_addr_mux <= '?' after 15 ns;
				control_mem_readnotwrite <= '?' after 15 ns;
				control_mem_clk <= '?' after 15 ns;
				control_op2r_mux <= '?' after 15 ns;
				control_op2r_clk <= '?' after 15 ns;
				--Regs[operand1]-> op1r
				control_regfile_readnotwrite <= '?' after 15 ns;
				control_regfile_index <= ? after 15 ns;
				control_regfile_clk <= '?' after 15 ns;
				control_op1r_clk <= '?' after 30 ns;
				state := 16; 
			when 16 =>--ALU operation
				control_alu_func <= "?" after 30 ns; -- alu unsign add
				control_alu_out_reg_clk <= '?' after 15 ns;
				state := 17;
			when 17 =>  
				--Regfile[operand2]-> control ???? do I need to writeback?
				control_regfile_readnotwrite <= '?' after 15 ns;
				control_regfile_index <= ? after 15 ns;
				control_regfile_clk <= '?' after 15 ns;

				state := 18;
			when 18 => 
				if opcode = "000100" then --JZ
					if(alu_out_control = X"00000000") then
						control_pc_mux <= '?' after 15 ns;
						control_pc_clk <= '?' after 30 ns;
					else
						control_pc_mux <= '?' after 15 ns;
						control_pc_clk <= '?' after 30 ns;
					end if;
				elsif opcode = "000101" then --JNZ
					if( alu_out_control /= X"00000000") then	
						control_pc_mux <= '?' after 15 ns;
						control_pc_clk <= '?' after 30 ns;
					else
						control_pc_mux <= '?' after 15 ns;
						control_pc_clk <= '?' after 30 ns;
					end if;	
				else --JMP
					control_pc_mux <= '?' after 15 ns;
					control_pc_clk <= '?' after 30 ns;
				end if;
				state := 1;
			when others => null; 
		   end case; 
		elsif clock_control'event and clock_control = '0' then
			-- reset all the register clocks
			control_pc_clk <= '0'; 
			control_ir_clk <= '0'; 
			control_op1r_clk <= '0';
			control_op2r_clk <= '0';
			control_mem_clk <= '0';
			control_regfile_clk <= '0';	
			control_alu_out_reg_clk <= '0'; 		
		end if; 
	end process behav;
end behavior;	

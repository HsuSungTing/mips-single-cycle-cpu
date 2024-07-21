//seq
module InstructionMemory(Address, Instruction); //我先用他的
	input [31:0] Address;
	output reg [31:0] Instruction;//這邊感覺應該寫成RF會更像memory，這邊是用comb來模擬
	always @(*)
		case (Address)
		//I: {op	rs	rt	immediate}
		//R: {op	rs	rt	rd	shamt	funct}
			32'd0:     Instruction <= {6'd8,5'd0,5'd8, 16'd60};//I type: addi $s0, $zero, 60 
			32'd4:     Instruction <= {6'd0,5'd8,5'd10,5'd9, 5'd0,6'd32}; //R type: add $s1, $s0, $s2
			32'd8:     Instruction <= {6'd8,5'd0,5'd15, 16'd85};//I type: addi $s7, $zero, 100 
			32'd12:    Instruction <= {6'd0,5'd15,5'd8, 5'd10,5'd0,6'd34};//R type: sub $s2, $s7, $s0 | s2=rd s1=rs s0=rt
			32'd16:    Instruction <= {6'd4,5'd11,5'd12, 16'd3};//I type: beq $s4, $s3, 3 
			32'd20:    Instruction <= {6'd35,5'd8,5'd11,16'd70};//I type: lw $s3,.70(s0)
			32'd24:    Instruction <= {6'd43,5'd11,5'd10,16'd50};//I type: sw $s2,.50(s3) s2=rt, s1=rs
			32'd28:    Instruction <= {6'd0,5'd9,5'd10,5'd12,5'd0,6'd42};//R type: slt $s4, $s1, $s2
			32'd32:    Instruction <= {6'd0,5'd10,5'd11,5'd13,5'd0,6'd36};//R type: and  $s5, $s2, $s3
			32'd36:    Instruction <= {6'd43,5'd12,5'd8,16'd20};//I type: sw $s0,.20(s4) s2=rt, s1=rs
			32'd40:    Instruction <= {6'd35,5'd12,5'd14,16'd20};//I type: lw $s6,.20(s4)
			32'd44:    Instruction <= {6'd0,5'd11,5'd12,5'd14,5'd0,6'd37};//R type: or  $s6, $s4, $s3
			32'd48:    Instruction <= {6'd2,26'd5};//J type: j 5(address=20)
			32'd52:    Instruction <= {6'd0,5'd11,5'd12,5'd14,5'd0,6'd37};//R type: or  $s6, $s4, $s3
			default: Instruction <= 32'h00000000;
		endcase
endmodule

//seq
module RegisterFile(Reset, clk, RegWrite, Read_register1, Read_register2, Write_register, Write_data,Write_enable, Read_data1, Read_data2);
	input Reset,clk,Write_enable;
	input RegWrite;
    input [4:0] Read_register1, Read_register2, Write_register;
    input [31:0]Write_data;
    output [31:0]Read_data1, Read_data2;
	reg [31:0] RF_data[31:0];

	//他沒有write enable，如果同時寫和讀應該會出事，所以我這邊用助教的寫法
	//RF到底初始化
	integer i;
	always@(posedge Reset,posedge clk)begin
		if(Reset)begin
			for (i = 0; i < 32; i = i + 1)RF_data[i] <= 32'd200;
		end
		else if(Write_enable==1'b1&&RegWrite==1'b1)RF_data[Write_register]<=Write_data;//其實沒有所有情況都涵蓋
		else begin
			for (i = 0; i < 32; i = i + 1)RF_data[i] <= RF_data[i]; //這邊這樣寫OK嗎?
		end
	end
	//	每次用seqential都怪怪的
	// always@(posedge Reset,posedge clk)begin
	// 	if(Reset)begin
	// 		Read_data1<=32'd0;Read_data2<=32'd0;
	// 	end
	// 	else begin
	// 		Read_data1<=RF_data[Read_register1];Read_data2<=RF_data[Read_register2];
	// 	end
	// end
	assign Read_data1 = (Read_register1 == 5'b00000)? 32'h00000000: RF_data[Read_register1];
	assign Read_data2 = (Read_register2 == 5'b00000)? 32'h00000000: RF_data[Read_register2];
endmodule

//基本上就是RAM，主要是長期資料會回存在這裡，要用lw才能把資料讀出來，sw寫回，lw要記得把某個資料存在哪裡
module DataMemory(Reset, clk, Address, Write_data, Read_data,MemtoReg, MemWrite);
    parameter RAM_SIZE = 256;
	parameter RAM_SIZE_BIT = 8;
	input Reset, clk,MemtoReg, MemWrite;//先不放memread，無條件Read
	input [31:0]Address,Write_data;//read和write都是用同個address
	output [31:0]Read_data;
	wire [7:0]true_Address;
	assign true_Address=Address[7:0];
	reg [31:0] RAM_data[RAM_SIZE - 1: 0];
	integer i;
	always@(posedge Reset,posedge clk)begin
		if(Reset)begin
			for (i = 0; i < RAM_SIZE; i = i + 1)RAM_data[i] <= 32'd5;
		end
		else if(MemWrite==1'b1)RAM_data[true_Address]<=Write_data;//其實沒有所有情況都涵蓋
		else begin
			for (i = 0; i < RAM_SIZE; i = i + 1)RAM_data[i] <= RAM_data[i]; //這邊這樣寫OK嗎?
		end
	end

	// always@(posedge Reset,posedge clk)begin
	// 	if(Reset)begin
	// 		Read_data<=32'd0;
	// 	end
	// 	else begin
	// 		Read_data<=RAM_data[Address];
	// 	end
	// end
	assign Read_data=RAM_data[true_Address];
endmodule

//comb
module Control(Ins_31_26,Jump,Branch,RegDst,MemRead,MemtoReg,MemWrite,ALUSrc,RegWrite);
	input [5:0]Ins_31_26;
	output reg Jump,Branch,RegDst,MemRead,MemtoReg,MemWrite,ALUSrc,RegWrite;
	always@(*)begin
		case (Ins_31_26)
			//0的話代表R type
			6'd0:  begin
				Jump=1'b0;Branch=1'b0;RegDst=1'b1;MemRead=1'b0;MemtoReg=1'b0;
				MemWrite=1'b0;ALUSrc=1'b0;RegWrite=1'b1;
			end
			//2的話代表j
			6'd2:  begin
				Jump=1'b1;Branch=1'b0;RegDst=1'b0;MemRead=1'b0;MemtoReg=1'b0;
				MemWrite=1'b0;//here
				ALUSrc=1'b0;RegWrite=1'b0;
			end
			//4的話代表beq
			6'd4:  begin
				Jump=1'b0;Branch=1'b1;RegDst=1'b0;MemRead=1'b0;MemtoReg=1'b0;
				MemWrite=1'b0;//here
				ALUSrc=1'b1;RegWrite=1'b0;
			end
			//8的話代表addi
			6'd8:begin
				Jump=1'b0;Branch=1'b0;RegDst=1'b0;MemRead=1'b0;MemtoReg=1'b0;
				MemWrite=1'b0;ALUSrc=1'b1;//要做sign extend
				RegWrite=1'b1;
			end     
			//35的話代表lw
			6'd35:begin
				Jump=1'b0;Branch=1'b0;RegDst=1'b0;MemRead=1'b1;MemtoReg=1'b1;
				MemWrite=1'b0;ALUSrc=1'b1;RegWrite=1'b1;
			end     
			//43的話代表sw
			6'd43:begin
				Jump=1'b0;Branch=1'b0;RegDst=1'b0;MemRead=1'b0;MemtoReg=1'b0;
				MemWrite=1'b1;ALUSrc=1'b1;RegWrite=1'b0;
			end    
			default:begin
				Jump=1'b0;Branch=1'b0;RegDst=1'b0;MemRead=1'b0;MemtoReg=1'b0;
				MemWrite=1'b0;ALUSrc=1'b0;RegWrite=1'b0;
			end
		endcase
	end
endmodule

//comb
module ALU_and_Control(data_1,data_2,Ins_31_26,Ins_5_0,Ins_15_0,ALU_result);
	input [5:0] Ins_31_26,Ins_5_0;
	input [15:0] Ins_15_0;
	input [31:0]data_1,data_2;
	output reg [31:0] ALU_result;

	always@(*)begin
		if(Ins_31_26==6'd0)begin //R type
			if(Ins_5_0==6'd32)begin //add $s1, $s0, $zero
				ALU_result=data_1+data_2;
			end
			else if(Ins_5_0==6'd34)begin //R type: sub $s2, $s1, $s0
				ALU_result=data_1-data_2;
			end
			else if(Ins_5_0==6'd36)begin
				ALU_result=data_1 & data_2;
			end
			else if(Ins_5_0==6'd37)begin //R type: or  $s6, $s4, $s3
				ALU_result=data_1 | data_2;
			end
			else if(Ins_5_0==6'd42)begin //R type: slt $s4, $s1, $s2
				if(data_1>=data_2)ALU_result=32'd0;
				else ALU_result=32'd1;
			end
			else begin
				ALU_result=32'd0;
			end
		end
		else if(Ins_31_26==6'd2)begin //beq 
			ALU_result=32'd0;
		end
		else if(Ins_31_26==6'd4)begin //beq 
			ALU_result=data_1-data_2;
		end
		else if(Ins_31_26==6'd8)begin //addi $s0, $zero, 100 
			ALU_result=data_1+{16'd0,Ins_15_0};
		end
		else if(Ins_31_26==6'd35)begin//lw
			ALU_result=data_1+{16'd0,Ins_15_0};
		end
		else if(Ins_31_26==6'd43)begin//sw
			ALU_result=data_1+{16'd0,Ins_15_0};
		end
		else begin
			ALU_result=32'd0;
		end
	end
endmodule

module CPU(Reset, clk);
	input Reset, clk;
	reg [31:0]pc;
	reg [4:0]Read_register1,Read_register2, Write_register;
	wire [31:0]cur_Insctructions;
	wire [5:0]Ins_31_26;
	wire Jump,Branch,RegDst,MemRead,MemtoReg,MemWrite,RegWrite;
	assign Ins_31_26=cur_Insctructions[31:26];
	//----------------------------------------------------------------------------------
	reg [31:0]next_pc;
	always@(posedge Reset,posedge clk)begin
		if(Reset)pc<=32'd0;
		else pc<=next_pc;
	end
	
	Control U0(.Ins_31_26(Ins_31_26),.Jump(Jump),.Branch(Branch),.RegDst(RegDst),.MemRead(MemRead),.MemtoReg(MemtoReg),.MemWrite(MemWrite),.ALUSrc(ALUSrc),.RegWrite(RegWrite));
	InstructionMemory U1(.Address(pc),.Instruction(cur_Insctructions));
	
	//-----------cur_Insctructions mapping到Read_register1,Read_register2,Write_register;缺writ_edata------------------
	always@(*)begin
		Read_register1=cur_Insctructions[25:21];//rs
		Read_register2=cur_Insctructions[20:16];//rt
		if(RegDst==1'b0)Write_register=cur_Insctructions[20:16];//I type
		else Write_register=cur_Insctructions[15:11];           //R type
	end
	//-----------------------------------------------------------------------------------
	reg [31:0]Write_data;
	wire [31:0]Read_data1,Read_data2;
	RegisterFile U2(.Reset(Reset),.clk(clk),.RegWrite(RegWrite),.Read_register1(Read_register1),.Read_register2(Read_register2),.Write_register(Write_register),.Write_data(Write_data),.Write_enable(1'b1),.Read_data1(Read_data1),.Read_data2(Read_data2));
	//-----------------------------------------------------------------------------------
	wire [5:0]Ins_5_0;
	assign Ins_5_0=cur_Insctructions[5:0];
	wire [15:0]Ins_15_0;
	assign Ins_15_0=cur_Insctructions[15:0];
	wire [31:0]ALU_result;
	
	ALU_and_Control U3(.data_1(Read_data1),.data_2(Read_data2),.Ins_31_26(Ins_31_26),.Ins_5_0(Ins_5_0),.Ins_15_0(Ins_15_0),.ALU_result(ALU_result));
	//----------------------------------------------------------------------------------
	wire [17:0]branch_offset;
	wire [31:0]jump_offset;
	assign branch_offset={Ins_15_0,2'd0};//offset 要乘以4
	assign jump_offset={4'd0,cur_Insctructions[25:0],2'd0};
	always@(*)begin
		if(Branch==1'b1&&ALU_result==32'd0)next_pc=pc+32'd4+{14'd0,branch_offset};
		else if(Jump==1'b1)next_pc=jump_offset;
		else next_pc=pc+32'd4;
	end

	//-----------------------------------------------------------------------------------
	wire [31:0]Read_data_from_ram;
	always@(*)begin
		if(MemtoReg==1'b1)Write_data=Read_data_from_ram;
		else Write_data=ALU_result;
	end
	DataMemory U4(.Reset(Reset),.clk(clk),.Address(ALU_result),.Write_data(Read_data2),.Read_data(Read_data_from_ram),.MemtoReg(MemtoReg),.MemWrite(MemWrite));
endmodule
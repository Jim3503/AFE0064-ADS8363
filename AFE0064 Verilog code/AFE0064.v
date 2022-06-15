
//////////////////////////////////////////////////////////////////////////////////
// Company: CARERAY medical system co., ltd.
// Design Name: 	 AFEXR0064.v
// Module Name:    AFEXR0064+ADS8363 EVM 
// Project Name:   Digital X-ray Module
// Description: this file control AFEXR0064 integrating charge on 64 pixel and output analog in serial.
//					 see AFEXR0064.pdf for detail				

/*****************************************************************************************************************************/
//History:
// Author : Jack Li
// Created on April,2011
// Version 1.0
//
//////////////////////////////////////////////////////////////////////////////////

`define t1_period    1000
`define t2_period    1000
`define Num_out      1000
`define TFT_ON       1000
`define TFT_OFF      1000
`define integrate_wait 1000
`define t8_period    1000
`define one_us       1000

`timescale 1ns / 1ps

module AFE0064(
    input rst_n,//reset input, low is valid
    input clk,//system clock
	 output reg AFE_IRST,//Resets the AFE on rising edge
    output reg AFE_SHR,//samples ¡®reset¡¯ level of integrator on rising edge  
    output reg AFE_INTG,//integrate pixel signal when high
    output reg AFE_SHS,//samples signal on rising edge
    output reg AFE_CLK,//outputs the analog voltage from each integrator channel on each rising edge
    output AFE_DF_SM,//Digital control to dump compensation charge on integrator capacitor,
    output reg AFE_ENTRI,//High on this pin enables tri-state of analog output drivers after shift out of data for all 64 channels 
	 output AFE_PGA0,//
	 output AFE_PGA1,
	 output AFE_PGA2
    );

parameter[3:0] // state machine enum code, johnson code
	AFE_rst = 4'b0000,//reset AFE
	AFE_rst_wait = 4'b0001,//wait after AFE_rst, and then output analog output
	AFE_output = 4'b0011,//clock analog output
	AFE_rst_hold = 4'b0111,//sample and hold reset level
	AFE_rst_hold_wait = 4'b0110,//wait after AFE_rst_hold, and then integrate pixel
	AFE_TFT_ON = 4'b0100,//integrate pixel when TFT_ON 
	AFE_TFT_OFF = 4'b1100,//integrate pixel when TFT_OFF 
	AFE_integrate_wait = 4'b1000,//wait after AFE_integrate, and then hold signal
	AFE_Signal_Hold = 4'b1001,//hold signal
	AFE_Signal_Hold_wait = 4'b1011;//wait after AFE_Signal_Hold, and then reset AFE
	
	
reg [3:0] state, next_state ;//state machine for AFE
reg [2:0] t1_counter;//counter for AFE_rst, AFE_SHR and AFE_SHS, it should be larger than 30ns
reg [2:0] t2_counter;//counter for AFE_rst_wait and AFE_rst_hold_wait, it should be larger than 30ns
reg [2:0] t8_counter;//counter for AFE_Signal_Hold_wait, it should be larger than 30ns
reg [5:0] clk_counter;//counter for AFE_CLK
reg [5:0] out_counter;//output counter to clock analog out
reg [16:0] TFT_ON_counter;//counter for integrating signal on pixel when TFT_ON
reg [5:0] TFT_OFF_counter;//counter for integrating signal on pixel when TFT_OFF
reg [8:0] intg_wait_counter;//counter for waiting after integration
assign AFE_DF_SM = 1'b1;
//assign AFE_ENTRI = 1'b0;
assign {AFE_PGA0,AFE_PGA1,AFE_PGA2} = 3'b111;
//increase t1_counter when AFE_rst, AFE_SHR and AFE_SHS
always@(posedge clk)
begin
	if((!rst_n)||((state!=AFE_rst)&&(state!=AFE_rst_hold)&&(state!=AFE_Signal_Hold)))//clear counter when necessary
		t1_counter <= 0;
	else
		t1_counter <= t1_counter+1;
end
//increase t2_counter when AFE_rst_wait and AFE_rst_hold_wait
always@(posedge clk)
begin
	if((state!=AFE_rst_wait)&&(state!=AFE_rst_hold_wait))//clear counter when necessary
		t2_counter <= 0;
	else
		t2_counter <= t2_counter+1;
end
//increase t8_counter when AFE_Signal_Hold_wait
always@(posedge clk)
begin
	if(state!=AFE_Signal_Hold_wait)//clear counter when it doesn't work
		t8_counter <= 0;
	else
		t8_counter <= t8_counter+1;
end
//determine next state according to current state and other input signal	
always @ (state or t1_counter or t2_counter or out_counter or TFT_ON_counter or TFT_OFF_counter or intg_wait_counter or t8_counter) begin
	next_state = AFE_rst;//default value
	// state machine
	case (state) 
		AFE_rst:
		begin
			if(t1_counter < `t1_period) //wait until time out
			begin
				next_state = AFE_rst;
			end
			else 
			next_state = AFE_rst_wait; 
		end
		AFE_rst_wait:
		begin
			if(t2_counter < `t2_period) //wait until time out
			next_state = AFE_rst_wait;
			else 
			next_state = AFE_output;
		end
		AFE_output:
		begin
			if(out_counter!= `Num_out)next_state = AFE_output;//wait until 33 AFE_CLK
			else next_state = AFE_rst_hold;
		end
		AFE_rst_hold://wait until time out
		begin
			if(t1_counter < `t1_period) 
			begin
				next_state = AFE_rst_hold;
			end
			else next_state = AFE_rst_hold_wait;
		end
		AFE_rst_hold_wait://wait until time out
		begin
			if(t2_counter < `t2_period) next_state = AFE_TFT_ON;
			else next_state = AFE_rst_hold_wait;
		end
		AFE_TFT_ON://wait for TFT_ON time out
		begin
			if(TFT_ON_counter != `TFT_ON) next_state = AFE_TFT_ON;
			else next_state = AFE_TFT_OFF;
		end
		AFE_TFT_OFF://wait for a while when TFT is turned off
		begin
			if(TFT_OFF_counter != `TFT_OFF) next_state = AFE_TFT_OFF;
			else next_state = AFE_integrate_wait;
		end
		AFE_integrate_wait:
			if(intg_wait_counter != `integrate_wait) 
			next_state = AFE_integrate_wait;
			else next_state = AFE_Signal_Hold;
		AFE_Signal_Hold://wait until time out
		begin
			if(t1_counter < `t1_period) 
			next_state = AFE_Signal_Hold;
			else next_state = AFE_Signal_Hold_wait;
		end
		AFE_Signal_Hold_wait://wait until time out
		begin
			if(t8_counter < `t8_period)
			 next_state = AFE_Signal_Hold_wait;
			else next_state = AFE_rst;
		end
	endcase
	end
// build the state flip-flops
always @ (posedge clk or negedge rst_n)
begin
	if (!rst_n) state <= AFE_rst ;
	else state <= next_state ;
end
//increase counter for AFE clock
always@(posedge clk )
begin
	if ((!rst_n)||(state != AFE_output)) clk_counter<=0;
	else if(clk_counter!= `one_us)clk_counter <= clk_counter+1;
		else clk_counter<=0;
end
//generate AFE clock
always@(posedge clk )
begin
	if (state != AFE_output) AFE_CLK<=1'b0;
	else if(clk_counter== 0) AFE_CLK <= ~AFE_CLK;
end
//increase counter to clock analog output
always@(posedge clk )
begin
	if (state != AFE_output) out_counter<=0;
	else if((clk_counter== (`one_us-2))&&(!AFE_CLK))
		out_counter <= out_counter+1;//state will be changed before AFE_CLK transition
end
//increase counter for integrating when TFT_ON
always@(posedge clk )
begin
	if (state != AFE_TFT_ON) TFT_ON_counter<=0;
	else TFT_ON_counter <= TFT_ON_counter+1;
end
//increase counter for integrating when TFT_OFF
always@(posedge clk )
begin
	if (state != AFE_TFT_OFF) TFT_OFF_counter<=0;
	else TFT_OFF_counter <= TFT_OFF_counter+1;
end
//increase counter for waiting when integrating
always@(posedge clk )
begin
	if (state != AFE_integrate_wait) intg_wait_counter<=0;
	else intg_wait_counter <= intg_wait_counter+1;
end
//register output according to state of AFE
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n) 
	begin
		AFE_IRST <= 1'b0;
		AFE_SHR <= 1'b0;
		AFE_INTG <= 1'b0;
		AFE_SHS <= 1'b0;
		AFE_ENTRI <= 1'b1;
		//AFE_ENTRI <= 1'b0;
	end
	else
	begin
		AFE_IRST <= 1'b0;
		AFE_SHR <= 1'b0;
		AFE_INTG <= 1'b0;
		AFE_SHS <= 1'b0;
		AFE_ENTRI <= 1'b1;
		//AFE_ENTRI <= 1'b0;
		case (state) 
			AFE_rst:
			begin
				if(next_state == AFE_rst) 
				begin
					AFE_IRST <= 1'b1;
					//AFE_ENTRI <= 1'b1;
				end
				else 
				begin
					AFE_IRST <= 1'b0;
					//AFE_ENTRI <= 1'b0;
				end
			end
			AFE_output:
			begin
				if(next_state == AFE_rst_hold) 
				begin 
					AFE_SHR <= 1'b1;
					//AFE_ENTRI <= 1'b1;
				end
				else 
				begin
					AFE_SHR <= 1'b0;
					//AFE_ENTRI <= 1'b0;
				end
			end
			AFE_rst_hold:
			begin
				if(next_state == AFE_rst_hold) AFE_SHR <= 1'b1;
				else AFE_SHR <= 1'b0;
			end
			AFE_rst_hold_wait:
			begin
				if(next_state == AFE_TFT_ON) AFE_INTG <= 1'b1;
				else AFE_SHR <= 1'b0;
			end
			AFE_TFT_ON:
				AFE_INTG <= 1'b1;
			AFE_TFT_OFF:
			begin
				if(next_state == AFE_TFT_OFF) AFE_INTG <= 1'b1;
				else AFE_INTG <= 1'b0;
			end
			AFE_integrate_wait:
				if(next_state == AFE_Signal_Hold) AFE_SHS <= 1'b1;
				else AFE_SHS <= 1'b0;
			AFE_Signal_Hold:
			begin
				if(next_state == AFE_Signal_Hold) AFE_SHS <= 1'b1;
				else AFE_SHS <= 1'b0;
			end
			AFE_Signal_Hold_wait:
			begin
				if(next_state == AFE_rst) AFE_IRST <= 1'b1;
				else AFE_IRST <= 1'b0;
			end
		endcase
	end
end
endmodule

// ===========================================================================
//                    Copyright 2010
//          Texas Instruments Deutschland GmbH
//                 All rights reserved
//
// Filename:          spirec.v
// Modelname:         SPIREC
// Title:             Controls the 20-bit serial output communication
// Purpose:           Synthesis
// Comment:            Gate-equivalents
// Assumptions:       x
// Limitations:       x
// Specification ref: ADS8363
// ---------------------------------------------------------------------------
// Modification History:
// ---------------------------------------------------------------------------
// Version | Author |  Date  | Changes
// --------|--------|--------|------------------------------------------------
//  0.9    |  Bad   |11.07.08| Copied from ADS7863BENCH project
// --------|--------|--------|------------------------------------------------
//  1.0    |  Bad   |15.08.08| Add special read mode control
// --------|--------|--------|------------------------------------------------
//  1.1    |  Bad   |18.08.08| Full clock mode compliant
// --------|--------|--------|------------------------------------------------
//  1.2    |  Bad   |02.09.08| CID_ACTIVE added
// --------|--------|--------|------------------------------------------------
//  1.3    |  Bad   |18.17.08| Reduced SPIDINB_Q to 18bit
// --------|--------|--------|------------------------------------------------
//  1.4    |  Bad   |28.04.09| Add manual channel selection and CID support
//         |        |        | Now data is stored in correct output register
// --------|--------|--------|------------------------------------------------
//  1.5    |  Bad   |04.05.09| Add sequential mode
// --------|--------|--------|------------------------------------------------
//  1.6    |  Bad   |04.06.09| Add pseudo differential mode
// --------|--------|--------|------------------------------------------------
//  1.7    |  Bad   |10.06.09| Remove channels 2 and 3
// --------|--------|--------|------------------------------------------------
//  1.8    |  Bad   |12.06.09| Add FIFO mode
// --------|--------|--------|------------------------------------------------
//  1.9    |  Bad   |15.06.09| Add FIFO mode with one data output
// --------|--------|--------|------------------------------------------------
//  1.10   |  Bad   |20.07.09| Add FIFO mode without sequencer
// --------|--------|--------|------------------------------------------------
//  1.11   |  Bad   |29.07.09| Put SPISTE on BUFG for the FFs
// --------|--------|--------|------------------------------------------------
//  2.0    |  Bad   |07.09.09| MODE is not latched anymore
// --------|--------|--------|------------------------------------------------
//  2.1    |  Bad   |09.09.09| Add FIFO_EN
// --------|--------|--------|------------------------------------------------
//  2.2    |  Bad   |10.09.09| Remove single RD function during sequence mode
// --------|--------|--------|------------------------------------------------
//  2.3    |  Bad   |11.09.09| FIRST_Q is toggling when no conversions 
// --------|--------|--------|------------------------------------------------
//  2.4    |  Bad   |15.02.10| READDATA is set correct in special read mode
// --------|--------|--------|------------------------------------------------
//  2.5    |  Bad   |19.02.10| READDATA is set correct in FIFO mode
// --------|--------|--------|------------------------------------------------
//  2.6    |  Bad   |31.03.10| READDATA is sampled in the beginning of a RD
// --------|--------|--------|------------------------------------------------
//  3.0    |  Bad   |09.04.10| READDATA is set correct in all modes
// --------|--------|--------|------------------------------------------------
// ===========================================================================

`timescale 1 ns / 1 ns

module SPIREC (
  input  wire          CLK,
  input  wire          RESET_N,
  input  wire          SPISTE,
  input  wire          SPIDINA,
  input  wire          SPIDINB,
  input  wire          BUSY,
  output wire   [17:0] DATAINA0,
  output wire   [17:0] DATAINA1,
  output wire   [17:0] DATAINB0,
  output wire   [17:0] DATAINB1,
  output wire          DAV,
  input  wire          SECOND,
  output wire   [15:0] READDATA,
  input  wire    [1:0] MODE,
  input  wire    [1:0] CHANNEL,
  input  wire   [15:0] SEQ_FIFO,
  input  wire          PDE_MODE,
  input  wire          FC_MODE,
  input  wire          SMODE4,
  input  wire          CID_ACTIVE,
  input  wire          FIFO_EN,
  input  wire          DEV_SEL);

// ---------------------------------

reg     [9:0] COUNT_Q;
reg     [9:0] COUNT_D;
reg     [2:0] COUNT2_Q;
reg     [2:0] COUNT2_D;

reg    [37:0] SPIDINA_Q;
reg    [37:0] SPIDINA_D;
reg    [17:0] SPIDINB_Q;
reg    [17:0] SPIDINB_D;
reg    [17:0] DATAINA0_Q;
reg    [17:0] DATAINA0_D;
reg    [17:0] DATAINA1_Q;
reg    [17:0] DATAINA1_D;
reg    [17:0] DATAINB0_Q;
reg    [17:0] DATAINB0_D;
reg    [17:0] DATAINB1_Q;
reg    [17:0] DATAINB1_D;
reg    [15:0] READDATA_Q;
reg    [15:0] READDATA_D;

reg           DAV_Q;
reg           DAV_D;
reg     [2:0] STATE_Q;
reg     [2:0] STATE_D;
reg     [1:0] CHANNEL_Q;
reg     [1:0] CHANNEL_D;
reg           SECOND_Q;
reg           SECOND_D;
reg           FIRST_Q;
reg           FIRST_D;

wire          SEQ_MODE;

// ---------------------------------

assign DATAINA0 = DATAINA0_Q;
assign DATAINB0 = DATAINB0_Q;
assign DATAINA1 = DATAINA1_Q;
assign DATAINB1 = DATAINB1_Q;
assign DAV      = DAV_Q;
assign READDATA = READDATA_Q;

assign SEQ_MODE = PDE_MODE & MODE[0] & !FC_MODE;

// ---------------------------------

parameter IDLE             = 3'b000;
parameter WAIT_FOR_START   = 3'b001;
parameter RECIEVE_DATA     = 3'b010;
parameter LATCH_DATA       = 3'b011;
parameter ISSUE_DAV        = 3'b100;

// ---------------------------------

   
always @(*)
  begin
    SPIDINA_D <= SPIDINA_Q;
    SPIDINB_D <= SPIDINB_Q;
    COUNT_D   <= COUNT_Q;
    COUNT2_D  <= COUNT2_Q;
    CHANNEL_D <= CHANNEL_Q;
    DATAINA0_D <= DATAINA0_Q;
    DATAINB0_D <= DATAINB0_Q;
    DATAINA1_D <= DATAINA1_Q;
    DATAINB1_D <= DATAINB1_Q;
    SECOND_D <= SECOND_Q;
    READDATA_D <= READDATA_Q;
    DAV_D <= 1'b0;
    FIRST_D <= FIRST_Q;
    case (STATE_Q)
      IDLE:
        begin
          COUNT_D <= 9'h00;
          if (SPISTE)
            STATE_D <= WAIT_FOR_START;
          else
            STATE_D <= IDLE;
        end
      WAIT_FOR_START:
        begin
          COUNT_D <= 9'h00;
          COUNT2_D <= 2'h0;
          if (SPISTE)
            STATE_D <= WAIT_FOR_START;
          else
            begin
	      COUNT_D <= COUNT_Q + 1'b1;
              SECOND_D <= (SEQ_MODE & FIFO_EN) ? SECOND_Q : SECOND;
              SPIDINA_D <= {SPIDINA_Q[36:0], SPIDINA};
              SPIDINB_D <= {SPIDINB_Q[16:0], SPIDINB};
              STATE_D <= RECIEVE_DATA;
              if (MODE[1])
                FIRST_D <= (BUSY) ? 1'b1 : !FIRST_Q;
              else
                FIRST_D <= FIRST_Q;  
            end  
        end
      RECIEVE_DATA:
        begin
          /////////////////// Sequencer active, with FIFO
	  if (SEQ_MODE && FIFO_EN)
            begin
              SPIDINA_D <= {SPIDINA_Q[36:0], SPIDINA};
              SPIDINB_D <= {SPIDINB_Q[16:0], SPIDINB};
              COUNT_D <= COUNT_Q + 1'b1;
              if (COUNT_Q[3:0] == 4'h1)
                begin
                  DAV_D <= (COUNT_Q > 9'h5);
                  CHANNEL_D <= !CHANNEL_Q;
                end  
              if (COUNT_Q[3:0] == 4'h0)
                begin
                  if (MODE == 2'h3)
                    begin
                      if (SECOND_Q && (COUNT_Q < 9'h015))
                        READDATA_D <= SPIDINA_Q[15:0];
                      else
                        begin
                          DATAINA0_D <= (CHANNEL_Q[0]) ? SPIDINA_Q[15:0] : DATAINA0_Q;
                          DATAINB0_D <= (CHANNEL_Q[0]) ? DATAINB0_Q : SPIDINA_Q[15:0];
                        end  
                    end
                  else
                    begin
                      if (SECOND_Q && (COUNT_Q < 9'h015))
                        READDATA_D <= SPIDINA_Q[15:0];
                      else
                        begin
                          DATAINA0_D <= SPIDINA_Q[15:0];
                          DATAINB0_D <= SPIDINB_Q[15:0];
                        end  
                    end    
                end
              if (MODE == 2'h3)
                begin
                  if (DEV_SEL)
                    begin
                      if ( (COUNT_Q[9:5] == ((SEQ_FIFO[13:12] + 1'b1)*(SEQ_FIFO[1:0] + 1'b1))) ||
                          ((COUNT_Q[9:4] == 6'h06) && (SEQ_FIFO[13:12] == 2'h3) && (SEQ_FIFO[1:0] == 2'h0)) ||
                          ((COUNT_Q[9:4] == 6'h0C) && (SEQ_FIFO[13:12] == 2'h3) && (SEQ_FIFO[1:0] == 2'h1)) ||
                          ((COUNT_Q[9:4] == 6'h12) && (SEQ_FIFO[13:12] == 2'h3) && (SEQ_FIFO[1:0] == 2'h2)) ||
                          ((COUNT_Q[9:4] == 6'h18) && (SEQ_FIFO[13:12] == 2'h3) && (SEQ_FIFO[1:0] == 2'h3))) 
                        begin
                          STATE_D <= ISSUE_DAV;
                          SECOND_D <= SECOND;
                        end  
                      else
                        STATE_D <= RECIEVE_DATA;  
                    end    
                  else
                    begin
                      if (COUNT_Q[9:5] == ((SEQ_FIFO[13:12] + 1'b1)*(SEQ_FIFO[1:0] + 1'b1)))
                        begin
                          STATE_D <= ISSUE_DAV;
                          SECOND_D <= SECOND;
                        end  
                      else
                        STATE_D <= RECIEVE_DATA;  
                    end    
                end
              else
                begin      
                  if (DEV_SEL)
                    begin
                      if ( (COUNT_Q[9:4] == ((SEQ_FIFO[13:12] + 1'b1)*(SEQ_FIFO[1:0] + 1'b1))) ||
                          ((COUNT_Q[9:4] == 6'h3) && (SEQ_FIFO[13:12] == 2'h3) && (SEQ_FIFO[1:0] == 2'h0)) ||
                          ((COUNT_Q[9:4] == 6'h6) && (SEQ_FIFO[13:12] == 2'h3) && (SEQ_FIFO[1:0] == 2'h1)) ||
                          ((COUNT_Q[9:4] == 6'h9) && (SEQ_FIFO[13:12] == 2'h3) && (SEQ_FIFO[1:0] == 2'h2)) ||
                          ((COUNT_Q[9:4] == 6'hC) && (SEQ_FIFO[13:12] == 2'h3) && (SEQ_FIFO[1:0] == 2'h3))) 
                        begin
                          STATE_D <= ISSUE_DAV;
                          SECOND_D <= SECOND;
                        end  
                      else
                        STATE_D <= RECIEVE_DATA;  
                    end    
                  else
                    begin
                      if (COUNT_Q[9:4] == ((SEQ_FIFO[13:12] + 1'b1)*(SEQ_FIFO[1:0] + 1'b1)))
                        begin
                          STATE_D <= ISSUE_DAV;
                          SECOND_D <= SECOND;
                        end  
                      else
                        STATE_D <= RECIEVE_DATA;  
                    end  
                end      
            end
          /////////////////// FIFO active without sequencer
          else if (!SEQ_MODE && FIFO_EN)   
            begin
              SPIDINA_D <= {SPIDINA_Q[36:0], SPIDINA};
              SPIDINB_D <= {SPIDINB_Q[16:0], SPIDINB};
              if (CID_ACTIVE)
                COUNT_D <= COUNT_Q + 1'b1;
              else
                begin
                  if (COUNT_Q[3:0] == 4'h5)
                    begin
                      COUNT2_D <= COUNT2_Q + 1'b1;
                      COUNT_D <= COUNT_Q + (COUNT2_Q == 3'h4);
                    end
                  else
                    begin
                      COUNT_D <= COUNT_Q + 1'b1;
                      COUNT2_D <= 3'h0;
                    end  
                end  
              if (COUNT_Q[3:0] == 4'h1)
                begin
                  DAV_D <= (COUNT_Q > 9'h5);
                  CHANNEL_D <= !CHANNEL_Q;
                end  
              if (COUNT_Q[3:0] == 4'h0)
                begin
                  if (CID_ACTIVE)
                    begin
                      if (MODE == 2'h3)
                        begin
                          if      (SECOND && (COUNT_Q < 9'h015) &&  CID_ACTIVE)
                            READDATA_D <= SPIDINA_Q[15:0];
                          else if (SECOND_Q && (COUNT_Q < 9'h015) && !CID_ACTIVE)
                            READDATA_D <= SPIDINA_Q[15:0];
                          else
                            begin
                              DATAINA0_D <= (CHANNEL_Q[0]) ? SPIDINA_Q[15:0] : DATAINA0_Q;
                              DATAINB0_D <= (CHANNEL_Q[0]) ? DATAINB0_Q : SPIDINA_Q[15:0];
                            end  
                        end
                      else
                        begin
                          if      (SECOND && (COUNT_Q < 9'h015) &  CID_ACTIVE)
                            READDATA_D <= SPIDINA_Q[15:0];
                          else if (SECOND_Q && (COUNT_Q < 9'h015) & !CID_ACTIVE)
                            READDATA_D <= SPIDINA_Q[15:0];
                          else
                            begin
                              DATAINA0_D <= SPIDINA_Q[15:0];
                              DATAINB0_D <= SPIDINB_Q[15:0];
                            end  
                        end    
                    end
                  else
                    begin  
                      if (MODE == 2'h3)
                        begin
                          if      (SECOND && (COUNT_Q < 9'h015) &  CID_ACTIVE)
                            READDATA_D <= SPIDINA_Q[17:2];
                          else if (SECOND_Q && (COUNT_Q < 9'h015) & !CID_ACTIVE)
                            READDATA_D <= SPIDINA_Q[17:2];
                          else
                            begin
                              DATAINA0_D <= (CHANNEL_Q[0]) ? SPIDINA_Q[17:2] : DATAINA0_Q;
                              DATAINB0_D <= (CHANNEL_Q[0]) ? DATAINB0_Q : SPIDINA_Q[17:2];
                            end  
                        end
                      else
                        begin
                          if      (SECOND && (COUNT_Q < 9'h015) &  CID_ACTIVE)
                            READDATA_D <= SPIDINA_Q[17:2];
                          else if (SECOND_Q && (COUNT_Q < 9'h015) & !CID_ACTIVE)
                            READDATA_D <= SPIDINA_Q[17:2];
                          else
                            begin
                              DATAINA0_D <= SPIDINA_Q[17:2];
                              DATAINB0_D <= SPIDINB_Q[17:2];
                            end  
                        end    
                    end    
                end
              if (MODE == 2'h3)
                begin
                  if (DEV_SEL)
                    begin
                      if (SMODE4)
                        begin
                          if (COUNT_Q[9:6] == (SEQ_FIFO[1:0] + 1'b1))
                            STATE_D <= ISSUE_DAV;
                          else
                            STATE_D <= RECIEVE_DATA;  
                        end
                      else
                        begin
                          if (COUNT_Q[9:5] == (SEQ_FIFO[1:0] + 1'b1))
                            STATE_D <= ISSUE_DAV;
                          else
                            STATE_D <= RECIEVE_DATA;  
                        end  
                    end    
                  else
                    begin
                      if (SMODE4)
                        begin
                          if (COUNT_Q[9:6] == ((SEQ_FIFO[13:12] + 1'b1)*(SEQ_FIFO[1:0] + 1'b1)))
                            STATE_D <= ISSUE_DAV;
                          else
                            STATE_D <= RECIEVE_DATA;  
                        end
                      else
                        begin
                          if (COUNT_Q[9:4] == ((SEQ_FIFO[13:12] + 1'b1)*(SEQ_FIFO[1:0] + 1'b1)))
                            STATE_D <= ISSUE_DAV;
                          else
                            STATE_D <= RECIEVE_DATA;  
                        end  
                    end    
                end
              else
                begin      
                  if (DEV_SEL)
                    begin
                      if ( (COUNT_Q[9:5] == (SEQ_FIFO[1:0] + 1'b1)) ||
                          ((COUNT_Q[9:4] == 6'h06) && (SEQ_FIFO[13:12] == 2'h3) && (SEQ_FIFO[1:0] == 2'h0)) ||
                          ((COUNT_Q[9:4] == 6'h0C) && (SEQ_FIFO[13:12] == 2'h3) && (SEQ_FIFO[1:0] == 2'h1)) ||
                          ((COUNT_Q[9:4] == 6'h12) && (SEQ_FIFO[13:12] == 2'h3) && (SEQ_FIFO[1:0] == 2'h2)) ||
                          ((COUNT_Q[9:4] == 6'h18) && (SEQ_FIFO[13:12] == 2'h3) && (SEQ_FIFO[1:0] == 2'h3))) 
                        STATE_D <= ISSUE_DAV;
                      else
                        STATE_D <= RECIEVE_DATA;  
                    end    
                  else
                    begin
                      if (COUNT_Q[9:5] == ((SEQ_FIFO[13:12] + 1'b1)*(SEQ_FIFO[1:0] + 1'b1)))
                        STATE_D <= ISSUE_DAV;
                      else
                        STATE_D <= RECIEVE_DATA;  
                    end  
                end      
            end
          /////////////////// Neither FIFO nor sequencer
          else
            begin  
              SPIDINA_D <= {SPIDINA_Q[36:0], SPIDINA};
              SPIDINB_D <= {SPIDINB_Q[16:0], SPIDINB};
              COUNT_D <= COUNT_Q + 1'b1;
              if (CID_ACTIVE)
                begin
                  if (((COUNT_Q == 10'h00F) && !(SMODE4 && MODE[1])) ||
                      ((COUNT_Q == 10'h01F) &&  (SMODE4 && MODE[1])))
        	        STATE_D <= LATCH_DATA;
        	      else
        	        STATE_D <= RECIEVE_DATA;
                end      
              else
                begin
                  if (((COUNT_Q == 10'h011) && !(SMODE4 && MODE[1])) ||
                      ((COUNT_Q == 10'h025) &&  (SMODE4 && MODE[1])))
        	        STATE_D <= LATCH_DATA;
        	      else
        	        STATE_D <= RECIEVE_DATA;
                end
            end    
        end
      LATCH_DATA:
        begin
          if (SECOND_Q && !SMODE4)
            begin
              READDATA_D <= (CID_ACTIVE) ? SPIDINA_Q[15:0] : SPIDINA_Q[15:0];
              SECOND_D <= 1'b0; 
            end  
          else if (SECOND_Q && SMODE4)
            begin
              READDATA_D <= (CID_ACTIVE) ? SPIDINA_Q[31:16] : SPIDINA_Q[35:20];
              SECOND_D <= 1'b0; 
            end  
          else
            begin
              CHANNEL_D <= CHANNEL;
              case (MODE)
                2'h0: begin                 // Mode I
                        if (PDE_MODE)
                          begin
                            DATAINA0_D <= {2'b0, SPIDINA_Q[15:0]};
                            DATAINB0_D <= {2'b0, SPIDINB_Q[15:0]};
                          end  
                        else if (CID_ACTIVE)
                          begin
                            DATAINA0_D <= (!CHANNEL[1]) ? {2'b0, SPIDINA_Q[15:0]} : DATAINA0_Q;
                            DATAINB0_D <= (!CHANNEL[1]) ? {2'b0, SPIDINB_Q[15:0]} : DATAINB0_Q;
                            DATAINA1_D <= ( CHANNEL[1]) ? {2'b0, SPIDINA_Q[15:0]} : DATAINA1_Q;
                            DATAINB1_D <= ( CHANNEL[1]) ? {2'b0, SPIDINB_Q[15:0]} : DATAINB1_Q;
                          end  
                        else
                          begin
                            DATAINA0_D <= (!CHANNEL[1]) ? SPIDINA_Q[17:0] : DATAINA0_Q;
                            DATAINB0_D <= (!CHANNEL[1]) ? SPIDINB_Q[17:0] : DATAINB0_Q;
                            DATAINA1_D <= ( CHANNEL[1]) ? SPIDINA_Q[17:0] : DATAINA1_Q;
                            DATAINB1_D <= ( CHANNEL[1]) ? SPIDINB_Q[17:0] : DATAINB1_Q;
                          end  
                      end
                2'h2: begin                 // Mode II
                        if (CID_ACTIVE)
                          begin
                            if (SMODE4)
                              begin
                                DATAINA0_D <= (!CHANNEL[1]) ? {2'h0, SPIDINA_Q[15:0]}  : DATAINA0_Q;
                                DATAINB0_D <= (!CHANNEL[1]) ? {2'h0, SPIDINA_Q[31:16]} : DATAINB0_Q;
                                DATAINA1_D <= ( CHANNEL[1]) ? {2'h0, SPIDINA_Q[15:0]}  : DATAINA1_Q;
                                DATAINB1_D <= ( CHANNEL[1]) ? {2'h0, SPIDINA_Q[31:16]} : DATAINB1_Q;
                              end
                            else
                              begin
                                DATAINA0_D <= (!CHANNEL[1] && !FIRST_Q) ? SPIDINA_Q[17:0] : DATAINA0_Q;
                                DATAINB0_D <= (!CHANNEL[1] &&  FIRST_Q) ? SPIDINA_Q[17:0] : DATAINB0_Q;
                                DATAINA1_D <= ( CHANNEL[1] && !FIRST_Q) ? SPIDINA_Q[17:0] : DATAINA1_Q;
                                DATAINB1_D <= ( CHANNEL[1] &&  FIRST_Q) ? SPIDINA_Q[17:0] : DATAINB1_Q;
                              end  
                          end
                        else
                          begin
                            if (SMODE4)
                              begin
                                DATAINA0_D <= (!CHANNEL[1] && !SPIDINA_Q[16]) ? SPIDINA_Q[17:0]  : DATAINA0_Q;
                                DATAINB0_D <= (!CHANNEL[1] &&  SPIDINA_Q[36]) ? SPIDINA_Q[37:20] : DATAINB0_Q;
                                DATAINA1_D <= ( CHANNEL[1] && !SPIDINA_Q[16]) ? SPIDINA_Q[15:0]  : DATAINA1_Q;
                                DATAINB1_D <= ( CHANNEL[1] &&  SPIDINA_Q[36]) ? SPIDINA_Q[37:20] : DATAINB1_Q;
                              end
                            else
                              begin
                                DATAINA0_D <= (!CHANNEL[1] && !SPIDINA_Q[16]) ? {2'h0, SPIDINA_Q[15:0]} : DATAINA0_Q;
                                DATAINB0_D <= (!CHANNEL[1] &&  SPIDINA_Q[16]) ? {2'h0, SPIDINA_Q[15:0]} : DATAINB0_Q;
                                DATAINA1_D <= ( CHANNEL[1] && !SPIDINA_Q[16]) ? {2'h0, SPIDINA_Q[15:0]} : DATAINA1_Q;
                                DATAINB1_D <= ( CHANNEL[1] &&  SPIDINA_Q[16]) ? {2'h0, SPIDINA_Q[15:0]} : DATAINB1_Q;
                              end  
                          end        
                      end
                2'h1: begin                 // Mode III
                        if (CID_ACTIVE)
                          begin
                            DATAINA0_D <= {2'h0, SPIDINA_Q[15:0]};
                            DATAINB0_D <= {2'h0, SPIDINB_Q[15:0]};
                            DATAINA1_D <= {2'h0, SPIDINA_Q[15:0]};
                            DATAINB1_D <= {2'h0, SPIDINB_Q[15:0]};
                          end  
                        else
                          begin
                            DATAINA0_D <= ( SPIDINA_Q[17]) ? DATAINA0_Q : SPIDINA_Q;
                            DATAINB0_D <= ( SPIDINB_Q[17]) ? DATAINB0_Q : SPIDINB_Q;
                            DATAINA1_D <= (!SPIDINA_Q[17]) ? DATAINA1_Q : SPIDINA_Q;
                            DATAINB1_D <= (!SPIDINB_Q[17]) ? DATAINB1_Q : SPIDINB_Q;
                          end  
                      end
                2'h3: begin                 // Mode IV
                        if (SMODE4)
                          begin
                            if (CID_ACTIVE || SEQ_MODE)
                              begin
                                DATAINA0_D <= SPIDINA_Q[15:0];
                                DATAINB0_D <= SPIDINA_Q[31:16];
                                DATAINA1_D <= (!SEQ_MODE) ? SPIDINA_Q[15:0]  : DATAINA1_Q;
                                DATAINB1_D <= (!SEQ_MODE) ? SPIDINA_Q[31:16] : DATAINB1_Q;
                              end
                            else
                              begin
                                DATAINA0_D <= (SPIDINA_Q[17:16] == 2'h0) ? SPIDINA_Q[17:0]  : DATAINA0_Q;
                                DATAINB0_D <= (SPIDINA_Q[37:36] == 2'h1) ? SPIDINA_Q[37:20] : DATAINB0_Q;
                                DATAINA1_D <= (SPIDINA_Q[17:16] == 2'h2) ? SPIDINA_Q[17:0]  : DATAINA1_Q;
                                DATAINB1_D <= (SPIDINA_Q[37:36] == 2'h3) ? SPIDINA_Q[37:20] : DATAINB1_Q;
                              end
                          end  
                        else    
                          begin
                            if (CID_ACTIVE || SEQ_MODE)
                              begin
                                DATAINA0_D <= (!FIRST_Q ||  SEQ_MODE) ? SPIDINA_Q[17:0] : DATAINA0_Q;
                                DATAINB0_D <= ( FIRST_Q && !SEQ_MODE) ? SPIDINA_Q[17:0] : DATAINB0_Q;
                                DATAINA1_D <= (!FIRST_Q && !SEQ_MODE) ? SPIDINA_Q[17:0] : DATAINA1_Q;
                                DATAINB1_D <= ( FIRST_Q && !SEQ_MODE) ? SPIDINA_Q[17:0] : DATAINB1_Q;
                              end
                            else
                              begin
                                DATAINA0_D <= (SPIDINA_Q[17:16] == 2'h0) ? SPIDINA_Q[17:0] : DATAINA0_Q;
                                DATAINB0_D <= (SPIDINA_Q[17:16] == 2'h1) ? SPIDINA_Q[17:0] : DATAINB0_Q;
                                DATAINA1_D <= (SPIDINA_Q[17:16] == 2'h2) ? SPIDINA_Q[17:0] : DATAINA1_Q;
                                DATAINB1_D <= (SPIDINA_Q[17:16] == 2'h3) ? SPIDINA_Q[17:0] : DATAINB1_Q;
                              end  
                          end    
                      end
              endcase
            end
          STATE_D <= ISSUE_DAV;
          COUNT_D <= 9'h00;
        end  
      ISSUE_DAV:
        begin
          DAV_D <= 1'b1;
          if (MODE == 2'h3)
            CHANNEL_D <= 2'h0;
          if (SPISTE)
            STATE_D <= WAIT_FOR_START;  
          else
            STATE_D <= IDLE;
        end  
      default:
        begin
          STATE_D <= IDLE;
        end   
    endcase    
  end

// ---------------------------------

always @(negedge CLK or negedge RESET_N)
  begin
    if (!RESET_N)
      begin
        COUNT_Q <= 10'h00;
        COUNT2_Q <= 3'h0;
        SPIDINA_Q <= 38'h0;
        SPIDINB_Q <= 38'h0;
        READDATA_Q <= 15'h0;
        SECOND_Q <= 1'b0;
        STATE_Q <= IDLE;
        FIRST_Q <= 1'b0;
      end  
    else
      begin
        COUNT_Q <= COUNT_D;
        COUNT2_Q <= COUNT2_D;
        SPIDINA_Q <= SPIDINA_D;
        SPIDINB_Q <= (MODE[1]) ? SPIDINB_Q : SPIDINB_D;
        STATE_Q <= STATE_D;
        SECOND_Q <= SECOND_D;
        READDATA_Q <= READDATA_D;
        FIRST_Q <= FIRST_D;
      end  
  end

always @(posedge CLK or negedge RESET_N)
  begin
    if (!RESET_N)
      begin
        DATAINA0_Q <= 18'h0;
        DATAINB0_Q <= 18'h0;
        DATAINA1_Q <= 18'h0;
        DATAINB1_Q <= 18'h0;
        DAV_Q <= 1'b0;
        CHANNEL_Q <= 2'b0;
      end  
    else
      begin
        DATAINA0_Q <= DATAINA0_D;
        DATAINB0_Q <= DATAINB0_D;
        DATAINA1_Q <= DATAINA1_D;
        DATAINB1_Q <= DATAINB1_D;
        DAV_Q <= DAV_D;
        CHANNEL_Q <= CHANNEL_D;
      end  
  end

endmodule

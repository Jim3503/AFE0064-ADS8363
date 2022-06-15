// ===========================================================================
//                    Copyright 2010
//          Texas Instruments Deutschland GmbH
//                 All rights reserved
//
// Filename:          spisend.v
// Modelname:         SPISEND
// Title:             Controls the 16-bit serial output communication
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
//  0.9    |  Bad   |20.03.06| Copy from ADS7863BENCH project
// --------|--------|--------|------------------------------------------------
//  1.0    |Giesbert|16.07.08| Adapt to 16-bit
// --------|--------|--------|------------------------------------------------
//  1.1    |  Bad   |18.08.08| Full clock mode compliant
// --------|--------|--------|------------------------------------------------
//  1.2    |  Bad   |26.01.09| Sending of burning commands added
// --------|--------|--------|------------------------------------------------
//  1.3    |  Bad   |23.04.09| Extracting configuration register
// --------|--------|--------|------------------------------------------------
//  1.4    |  Bad   |29.04.09| Extracting mode pin tristate control 
// --------|--------|--------|------------------------------------------------
//  1.5    |  Bad   |05.05.09| Extracting sequence/FIFO register 
// --------|--------|--------|------------------------------------------------
//  1.6    |  Bad   |05.05.09| Moved CONF_REG_Q from CLK to CLK_N 
// --------|--------|--------|------------------------------------------------
//  1.6.1  |  Bad   |28.01.10| Remove CONF_REG_D to avoid synthesis warning 
// --------|--------|--------|------------------------------------------------
//  1.7    |  Bad   |19.02.10| Block SECOND when writing to DUT 
// --------|--------|--------|------------------------------------------------
//  1.7.1  |  Bad   |22.02.10| Not blocking SECOND when access trim registers 
// --------|--------|--------|------------------------------------------------
//  2.0    |  Bad   |31.03.10| SECOND only rises when read access is chosen 
// --------|--------|--------|------------------------------------------------
// ===========================================================================

`timescale 1 ns / 1 ns

module SPISEND (
  input  wire          CLK,
  input  wire          CLK_N,
  input  wire          RESET_N,
  input  wire   [15:0] DATA,
  input  wire   [15:0] TDATA1,
  input  wire   [15:0] TDATA2,
  input  wire   [15:0] BURN_DATA,
  input  wire          SPISTE,
  output wire          SPIDOUT,
  input  wire          POWER,
  input  wire          START,
  input  wire          START_BURN,
  output wire          SECOND,
  input  wire          WAKEUP,
  output wire   [15:0] CONF_REG,
  output wire   [15:0] SEQ_FIFO,
  output wire          MX_EN,
  input  wire          DEV_SEL);

// ---------------------------------

reg     [4:0] COUNT_Q;
reg     [4:0] COUNT_D;

reg    [17:0] SPIDOUT_Q;
reg    [17:0] SPIDOUT_D;

reg     [1:0] STATE_Q; // for status machine, current status
reg     [1:0] STATE_D; // next status

reg    [15:0] CONF_REG_Q;
reg    [15:0] CONF_REG2_Q;
reg    [15:0] CONF_REG2_D;
reg    [15:0] SEQ_FIFO_Q;
reg    [15:0] SEQ_FIFO_D;

reg           START_Q;
reg           START_BURN_Q;
reg           START1_Q;
reg           START1_BURN_Q;
reg           START1_BURN_D;

reg           FIRST_Q;
reg           FIRST_D;
reg           SECOND2_Q;
reg           SECOND_Q;
reg           SECOND_D;
reg           SERVO_Q;
reg           SERVO_D;
reg           COMP_Q;
reg           COMP_D;
reg           MX_EN_Q;
reg           MX_EN_D;

reg           START_RESET_Q;
reg           START_RESET_D;

// ---------------------------------

assign SPIDOUT  = POWER & !SPISTE & SPIDOUT_Q[17];
assign SECOND   = SECOND2_Q;
assign CONF_REG = CONF_REG_Q;
assign SEQ_FIFO = SEQ_FIFO_Q;
assign MX_EN    = MX_EN_Q;

// --------------------------------- state definition
parameter IDLE             = 2'b00;
parameter WAIT_FOR_START   = 2'b01;
parameter SEND_DATA        = 2'b10;

// ---------------------------------

always @(*)
  begin
    SPIDOUT_D <= SPIDOUT_Q;
    COUNT_D <= COUNT_Q;
    FIRST_D <= FIRST_Q;
    START1_BURN_D <= START1_BURN_Q;
    CONF_REG2_D <= CONF_REG2_Q;
    SEQ_FIFO_D <= SEQ_FIFO_Q;
    SECOND_D <= SECOND_Q;
    SERVO_D <= SERVO_Q;
    COMP_D <= COMP_Q;
    MX_EN_D <= MX_EN_Q;
    START_RESET_D <= 1'b1;
    case (STATE_Q)
      IDLE:
        begin
          COUNT_D <= 5'h00;
          if (SPISTE)
            begin
              STATE_D <= WAIT_FOR_START;
            end    
          else
            STATE_D <= IDLE;
        end
      WAIT_FOR_START:
        begin
          STATE_D <= WAIT_FOR_START;
          if (START1_Q & FIRST_Q)
            begin
              SPIDOUT_D <= {TDATA1, 2'h0};  // 16bit data + 2 bit 0
              CONF_REG2_D <= TDATA1;
            end  
          else if (START1_Q & SECOND_Q)
            begin
              SPIDOUT_D <= {TDATA2, 2'h0};
              if ((CONF_REG2_Q[13:11] == 3'h5) && (CONF_REG2_Q[7:4] == 4'h0)) 
                SERVO_D <= TDATA2[6];
              if ((CONF_REG2_Q[13:11] == 3'h5) && (CONF_REG2_Q[7:4] == 4'hB)) 
                COMP_D <= TDATA2[5];
              if (((CONF_REG2_Q[13:12] == 2'h1) && (CONF_REG2_Q[3:0] == 4'h5) &&  DEV_SEL) ||
                  ((CONF_REG2_Q[13:12] == 2'h1) && (CONF_REG2_Q[3:0] == 4'h9) && !DEV_SEL))
                SEQ_FIFO_D <= TDATA2;
            end  
          else if (START_BURN_Q)
            SPIDOUT_D <= {BURN_DATA, 2'h0};
          else
            begin
              SPIDOUT_D <= (WAKEUP) ? {DATA[15:12], 1'b0, DATA[10:0], 2'h0} : {DATA, 2'h0};
              CONF_REG2_D <= (WAKEUP) ? {DATA[15:12], 1'b0, DATA[10:0]} : DATA;
            end  
          if (SPISTE)
            begin
            end    
          else
            begin
              START1_BURN_D <= START_BURN_Q;
              STATE_D <= SEND_DATA;
              COUNT_D <= COUNT_Q + 1'b1;
            end  
        end
      SEND_DATA:
        begin
          if ((COUNT_Q == 5'h0F) && !MX_EN_Q)
            MX_EN_D <= SERVO_Q | COMP_Q;
          if ((COUNT_Q == 5'h10) && MX_EN_Q)                    // Delay one clock to avoid driving conflict on Mx line
            MX_EN_D <= SERVO_Q | COMP_Q;
          if (COUNT_Q < 5'h11)
            SPIDOUT_D <= {SPIDOUT_Q[16:0], SPIDOUT_Q[17]};
          else
            SPIDOUT_D <= 18'h0;
          COUNT_D <= COUNT_Q + 1'b1;
          if (COUNT_Q == 5'h11)
            begin
               if (START1_Q & !SECOND_Q)
                 FIRST_D <= 1'b1;
               if (START1_Q & FIRST_Q & !SECOND_Q)
                 begin
                    FIRST_D <= 1'b0;
                    SECOND_D <= 1'b1;
                 end  
               if (START1_Q & SECOND_Q)
                 SECOND_D <= 1'b0;
               START_RESET_D <= ~((START1_Q & SECOND_Q) || START1_BURN_Q);
               STATE_D <= IDLE;
            end
          else
            begin
               STATE_D <= SEND_DATA;
            end
        end
      default:
        begin
          STATE_D <= IDLE;
        end   
    endcase
  end

// ---------------------------------

always @(posedge CLK_N or negedge RESET_N)
  begin
    if (!RESET_N)
      begin
        COUNT_Q <= 5'h00;
        STATE_Q <= IDLE;
        START1_BURN_Q <= 1'b0;
        MX_EN_Q <= 1'b0;
        CONF_REG_Q <= 16'h0;
      end  
    else
      begin
        COUNT_Q <= COUNT_D;
        STATE_Q <= STATE_D;
        START1_BURN_Q <= START1_BURN_D;
        MX_EN_Q <= MX_EN_D;
        CONF_REG_Q <= CONF_REG_Q;
        if (SPISTE)
          begin
            CONF_REG_Q[15:12] <=  CONF_REG2_Q[15:12];
            CONF_REG_Q[11:0]  <= (CONF_REG2_Q[13:12] == 2'h1) ? CONF_REG2_Q[11:0] : CONF_REG_Q[11:0];
          end  
      end  
  end

always @(posedge CLK or negedge RESET_N)
  begin
    if (!RESET_N)
      begin
        SPIDOUT_Q <= 18'h0;
        CONF_REG2_Q <= 16'h0;
        SEQ_FIFO_Q <= 16'h0;
        START1_Q <= 1'b0;
        FIRST_Q <= 1'b0;
        SECOND_Q <= 1'b0;
        SECOND2_Q <= 1'b0;
        START_RESET_Q <= 1'b1;
        SERVO_Q <= 1'b0;
        COMP_Q <= 1'b0;
      end  
    else
      begin
        SPIDOUT_Q <= SPIDOUT_D;
        CONF_REG2_Q <= CONF_REG2_D;
        SEQ_FIFO_Q <= SEQ_FIFO_D;
        FIRST_Q <= FIRST_D;
        SECOND_Q <= SECOND_D;
        if (DEV_SEL)             // ADS8363
          begin
            SECOND2_Q <= ((TDATA1[2:0]   == 3'h1) ||
                          (TDATA1[2:0]   == 3'h3) ||
                          (TDATA1[2:0]   == 3'h6) ||
                          (TDATA1[13:11] == 3'h4)) ? SECOND_D : 1'b0;
          end
        else                     // ADS8368
          begin
            SECOND2_Q <= ((TDATA1[3:0]   == 4'h1) ||
                          (TDATA1[3:0]   == 4'h3) ||
                          (TDATA1[3:0]   == 4'h6) ||
                          (TDATA1[3:0]   == 4'hB) ||
                          (TDATA1[3:0]   == 4'hE) ||
                          (TDATA1[13:11] == 3'h4)) ? SECOND_D : 1'b0;
          end    
        START1_Q <= START_Q;
        START_RESET_Q <= START_RESET_D;
        SERVO_Q <= SERVO_D;
        COMP_Q <= COMP_D;
      end  
  end

// ---------------------------------

wire          START_RESET_N;

assign START_RESET_N = RESET_N & START_RESET_Q;

always @(posedge START or negedge START_RESET_N)
  begin
    if (!START_RESET_N)
      START_Q <= 1'b0;
    else
      START_Q <= 1'b1;  
  end

always @(posedge START_BURN or negedge START_RESET_N)
  begin
    if (!START_RESET_N)
      START_BURN_Q <= 1'b0;
    else
      START_BURN_Q <= 1'b1;  
  end

endmodule

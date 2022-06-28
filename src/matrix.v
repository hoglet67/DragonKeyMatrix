// =======================================================================
// PS/2 to Dragon Keyboard Matrix adapter
//
// Copyright (C) 2022 David Banks
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see http://www.gnu.org/licenses/.
// =======================================================================

module matrix
  (
   // gop signals
   input        fastclk,
   output       fcs,

// output [8:2] tp,
// input [2:1]  sw,

   // dragon signals
   output [7:0] pa,
   input [7:0]  pb,

   // ps/2 signals
   input        ps2_data,
   input        ps2_clk
   );

   // ===============================================================
   // Internal Reset
   // ===============================================================

   reg [7:0]       reset_counter = 8'h00;
   wire            nRESET = reset_counter[7];

   always @(posedge fastclk)
      if (!reset_counter[7])
        reset_counter <= reset_counter + 1;

   assign fcs = 1'b1;

   // ===============================================================
   // PS/2 keyboard interface
   // ===============================================================

   wire [7:0]       keyb_data;
   wire             keyb_valid;
   wire             keyb_error;

   ps2_intf ps2
     (
      .CLK      (fastclk),
      .nRESET   (nRESET),
      .PS2_CLK  (ps2_clk),
      .PS2_DATA (ps2_data),
      .DATA     (keyb_data),
      .VALID    (keyb_valid),
      .error    (keyb_error)
      );

   // ===============================================================
   // Atom Matrix
   // ===============================================================

   reg             rel;
   reg             extended;
   reg [6:0]       keys[0:7];
   wire [6:0]      keys_out;

   assign keys_out = (keys[0] | {7{pb[0]}}) &
                     (keys[1] | {7{pb[1]}}) &
                     (keys[2] | {7{pb[2]}}) &
                     (keys[3] | {7{pb[3]}}) &
                     (keys[4] | {7{pb[4]}}) &
                     (keys[5] | {7{pb[5]}}) &
                     (keys[6] | {7{pb[6]}}) &
                     (keys[7] | {7{pb[7]}});

   assign pa[0] = keys_out[0] ? 1'bZ : 1'b0;
   assign pa[1] = keys_out[1] ? 1'bZ : 1'b0;
	assign pa[2] = 1'bZ; // Pin 3 on PL1 is a GND connection
   assign pa[3] = keys_out[2] ? 1'bZ : 1'b0;
   assign pa[4] = keys_out[3] ? 1'bZ : 1'b0;
   assign pa[5] = keys_out[4] ? 1'bZ : 1'b0;
   assign pa[6] = keys_out[5] ? 1'bZ : 1'b0;
   assign pa[7] = keys_out[6] ? 1'bZ : 1'b0;

//          LSB              $FF02                    MSB
//        | PB0   PB1   PB2   PB3   PB4   PB5   PB6   PB7 <- column
//    ----|----------------------------------------------
//    PA0 |   0     1     2     3     4     5     6     7    LSB
//    PA1 |   8     9     :     ;     ,     -     .     /     $
//    PA2 |   @     A     B     C     D     E     F     G     F
//    PA3 |   H     I     J     K     L     M     N     O     F
//    PA4 |   P     Q     R     S     T     U     V     W     0
//    PA5 |   X     Y     Z    Up  Down  Left Right Space     0
//    PA6 | ENT   CLR   BRK   N/C   N/C   N/C   N/C  SHFT
//    PA7 - Comparator input                                 MSB
//     ^


   always @(posedge fastclk) begin

      if (!nRESET) begin

         rel <= 1'b0;
         extended <= 1'b0;
         keys[0] <= 7'b1111111;
         keys[1] <= 7'b1111111;
         keys[2] <= 7'b1111111;
         keys[3] <= 7'b1111111;
         keys[4] <= 7'b1111111;
         keys[5] <= 7'b1111111;
         keys[6] <= 7'b1111111;
         keys[7] <= 7'b1111111;

      end else begin

         if (keyb_valid) begin
            //  Decode keyboard input
            if (keyb_data == 8'he0) begin
               //  Extended key code follows
               extended <= 1'b1;
            end else if (keyb_data == 8'hf0) begin
               //  Release code follows
               rel <= 1'b1;
               //  Cancel extended/release flags for next time
            end else if (extended) begin
               // Extended keys.
               rel <= 1'b0;
               extended <= 1'b0;
               case (keyb_data)
                 8'h75: keys[3][5] <= rel; // UP
                 8'h72: keys[4][5] <= rel; // DOWN
                 8'h6b: keys[5][5] <= rel; // LEFT
                 8'h74: keys[6][5] <= rel; // RIGHT
                 8'h6c: keys[1][6] <= rel; // HOME (CLEAR)					  
               endcase
            end else begin
               rel <= 1'b0;
               extended <= 1'b0;
               //  Decode scan codes
               case (keyb_data)
                 // Row 0
                 8'h45: keys[0][0] <= rel; // 0
                 8'h16: keys[1][0] <= rel; // 1
                 8'h1E: keys[2][0] <= rel; // 2
                 8'h26: keys[3][0] <= rel; // 3
                 8'h25: keys[4][0] <= rel; // 4
                 8'h2E: keys[5][0] <= rel; // 5
                 8'h36: keys[6][0] <= rel; // 6
                 8'h3D: keys[7][0] <= rel; // 7
                 // Row 1
                 8'h3E: keys[0][1] <= rel; // 8
                 8'h46: keys[1][1] <= rel; // 9
                 8'h52: keys[2][1] <= rel; // '   full colon substitute
                 8'h4C: keys[3][1] <= rel; // ;
                 8'h41: keys[4][1] <= rel; // ,
                 8'h4E: keys[5][1] <= rel; // -
                 8'h55: keys[5][1] <= rel; // = (alternative)
                 8'h49: keys[6][1] <= rel; // .
                 8'h4A: keys[7][1] <= rel; // /
                 // Row 2
                 8'h0D: keys[0][2] <= rel; // @ (TAB)
                 8'h1C: keys[1][2] <= rel; // A
                 8'h32: keys[2][2] <= rel; // B
                 8'h21: keys[3][2] <= rel; // C
                 8'h23: keys[4][2] <= rel; // D
                 8'h24: keys[5][2] <= rel; // E
                 8'h2B: keys[6][2] <= rel; // F
                 8'h34: keys[7][2] <= rel; // G
                 // Row 3
                 8'h33: keys[0][3] <= rel; // H
                 8'h43: keys[1][3] <= rel; // I
                 8'h3B: keys[2][3] <= rel; // J
                 8'h42: keys[3][3] <= rel; // K
                 8'h4B: keys[4][3] <= rel; // L
                 8'h3A: keys[5][3] <= rel; // M
                 8'h31: keys[6][3] <= rel; // N
                 8'h44: keys[7][3] <= rel; // O
                 // Row 4
                 8'h4D: keys[0][4] <= rel; // P
                 8'h15: keys[1][4] <= rel; // Q
                 8'h2D: keys[2][4] <= rel; // R
                 8'h1B: keys[3][4] <= rel; // S
                 8'h2C: keys[4][4] <= rel; // T
                 8'h3C: keys[5][4] <= rel; // U
                 8'h2A: keys[6][4] <= rel; // V
                 8'h1D: keys[7][4] <= rel; // W
                 // Row 5
                 8'h22: keys[0][5] <= rel; // X
                 8'h35: keys[1][5] <= rel; // Y
                 8'h1A: keys[2][5] <= rel; // Z
                                           // Up
                                           // Down
                 8'h66: keys[5][5] <= rel; // BACKSPACE (left alternative)	
                                           // Right
                 8'h29: keys[7][5] <= rel; // SPACE
                 // Row 6
                 8'h5A: keys[0][6] <= rel; // RETURN
					                            // Home
                 8'h76: keys[2][6] <= rel; // ESCAPE (BREAK)
                                           // N/C
                                           // N/C
                                           // N/C
                                           // N/C
                 8'h12: keys[7][6] <= rel; // Left SHIFT
                 8'h59: keys[7][6] <= rel; // Right SHIFT
               endcase
            end
         end
      end
   end // always @ (posedge fastclk)

endmodule

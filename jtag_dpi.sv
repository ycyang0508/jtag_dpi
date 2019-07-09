/*
 * TCP/IP controlled DPI JTAG Interface.
 * Based on Julius Baxter's work on jp_vpi.c
 *
 * Copyright (C) 2012 Franck Jullien, <franck.jullien@gmail.com>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation  and/or other materials provided with the distribution.
 * 3. Neither the names of the copyright holders nor the names of any
 *    contributors may be used to endorse or promote products derived from this
 *    software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

`define CMD_RESET		0
`define CMD_TMS_SEQ		1
`define CMD_SCAN_CHAIN		2
`define CMD_SCAN_CHAIN_FLIP_TMS	3
`define CMD_STOP_SIMU		4

module jtag_dpi
#(	parameter DEBUG_INFO = 0,
  parameter TP = 1,
  parameter TCK_HALF_PERIOD = 50, // Clock half period (Clock period = 100 ns => 10 MHz)
  parameter  CMD_DELAY = 1000
)
(
 output reg	tms,
 output reg	tck,
 output reg	tdi,
 input		tdo,
 input		enable,
 input		init_done);



    import "DPI-C" context function void dpi_check_for_command(output int cmd, output int length, output int nb_bits, output byte unsigned bufferOut[]);
    import "DPI-C" context function void dpi_send_result_to_server(input int length, input int nb_bits, input byte unsigned bufferIn[]);



  integer		cmd;
  integer		length;
  integer		nb_bits;

  byte unsigned int_buffer_out[0:4095];   // Data storage from the jtag server
  byte unsigned int_buffer_in[0:4095];   // Data storage to the jtag server

  integer		flip_tms;

  reg[7:0]	data_out;
  reg[7:0]	data_in;

  integer		debug;

    assign		tms_o = tms;
    assign		tck_o = tck;
    assign		tdi_o = tdi;

    initial
    begin
        tck		<= #TP 1'b0;
        tdi		<= #TP 1'bz;
        tms		<= #TP 1'b0;

        data_out	<= 32'h0;
        data_in		<= 32'h0;

        // Insert a #delay here because we need to
        // wait until the PC isn't pointing to flash anymore
        // (this is around 20k ns if the flash_crash boot code
        // is being booted from, else much bigger, around 10mil ns)
        wait(init_done)
            main;
    end

    task main;
        begin
            int retry = 0;
            $display("JTAG debug module with VPI interface enabled\n");            
            reset_tap;
            goto_run_test_idle_from_reset;

            while (1)
            begin

                // Check for incoming command
                // wait until a command is sent
                // poll with a delay here
                cmd = -1;

                while (cmd == -1)
                begin
                    #CMD_DELAY dpi_check_for_command(cmd, length, nb_bits, int_buffer_out);
                    if (cmd == -1) 
                    begin                            
                        #TCK_HALF_PERIOD;
                        retry++;
                        //$display("RTL> dpi_check_for_command %d",retry); 
                    end
                end
                /*
                $display("RTL> new cmd %d %d %d",cmd,length,nb_bits);
                for(int i = 0;i < length;i++)
                begin
                    $display("RTL> bufOut[%d] = %d",i,int_buffer_out[i]);
                end
                */

                // now switch on the command
                case (cmd)

                    `CMD_RESET :
                        begin
                            if (DEBUG_INFO)
                                $display("%t ----> CMD_RESET %h\n", $time, length);
                            reset_tap;
                            goto_run_test_idle_from_reset;
                        end

                    `CMD_TMS_SEQ :
                        begin
                            if (DEBUG_INFO)
                                $display("%t ----> CMD_TMS_SEQ\n", $time);
                            do_tms_seq;
                        end

                    `CMD_SCAN_CHAIN :
                        begin
                            if (DEBUG_INFO)
                                $display("%t ----> CMD_SCAN_CHAIN\n", $time);
                            flip_tms = 0;
                            do_scan_chain;
                            dpi_send_result_to_server(length, nb_bits, int_buffer_in);
                        end

                    `CMD_SCAN_CHAIN_FLIP_TMS :
                        begin
                            if (DEBUG_INFO)
                                $display("%t ----> CMD_SCAN_CHAIN_FLIP_TMS\n", $time);
                            flip_tms = 1;
                            do_scan_chain;
                            dpi_send_result_to_server(length, nb_bits, int_buffer_in);
                        end

                    `CMD_STOP_SIMU :
                        begin
                            if (DEBUG_INFO)
                                $display("%t ----> End of simulation\n", $time);
                            $finish();
                        end

                    default: begin
                            $display("Somehow got to the default case in the command case statement.");
                            $display("Command was: %x", cmd);
                            $display("Exiting...");
                            $finish();
                        end

                endcase // case (cmd)

            end // while (1)
        end

    endtask // main


    // Generation of the TCK signal
    task gen_clk;
        input[31:0] number;
        integer i;

        begin
            for (i = 0; i < number; i = i + 1)
            begin
                #TCK_HALF_PERIOD tck <= 1;
                #TCK_HALF_PERIOD tck <= 0;
            end
        end

    endtask

    // TAP reset
    task reset_tap;
        begin
            if (DEBUG_INFO)
                $display("(%0t) Task reset_tap", $time);
            tms <= #1 1'b1;
            gen_clk(5);
        end

    endtask


    // Goes to RunTestIdle state
    task goto_run_test_idle_from_reset;
        begin
            if (DEBUG_INFO)
                $display("(%0t) Task goto_run_test_idle_from_reset", $time);
            tms <= #1 1'b0;
            gen_clk(1);
        end

    endtask

    //
    task do_tms_seq;

        integer		i,
            j;
        reg[31:0]	data;
        integer		nb_bits_rem;
        integer		nb_bits_in_this_byte;

        begin
            if (DEBUG_INFO)
                $display("(%0t) Task do_tms_seq of %d bits (length = %d)", $time, nb_bits, length);

            // Number of bits to send in the last byte
            nb_bits_rem = nb_bits % 8;

            for (i = 0; i < length; i = i + 1)
            begin
                // If we are in the last byte, we have to send only
                // nb_bits_rem bits. If not, we send the whole byte.
                nb_bits_in_this_byte = (i == (length - 1)) ? nb_bits_rem : 8;

                data = int_buffer_out[i];
                for (j = 0; j < nb_bits_in_this_byte; j = j + 1)
                begin
                    tms <= #1 1'b0;
                    if (data[j] == 1)
                    begin
                        tms <= #1 1'b1;
                    end
                    gen_clk(1);
                end
            end

            tms <= #1 1'b0;
        end

    endtask


    //
    task do_scan_chain;

        integer		_bit;
        integer		nb_bits_rem;
        integer		nb_bits_in_this_byte;
        integer		index;

        begin
            if (DEBUG_INFO)
                $display("(%0t) Task do_scan_chain of %d bits (length = %d)", $time, nb_bits, length);

            // Number of bits to send in the last byte
            nb_bits_rem = nb_bits % 8;

            for (index = 0; index < length; index = index + 1)
            begin
                // If we are in the last byte, we have to send only
                // nb_bits_rem bits if it's not zero.
                // If not, we send the whole byte.
                nb_bits_in_this_byte = (index == (length - 1)) ? ((nb_bits_rem == 0) ? 8 : nb_bits_rem) : 8;

                data_out = int_buffer_out[index];
                for (_bit = 0; _bit < nb_bits_in_this_byte; _bit = _bit + 1)
                begin
                    tdi <= 1'b0;
                    if (data_out[_bit] == 1'b1)
                    begin
                        tdi <= 1'b1;
                    end

                    // On the last bit, set TMS to '1'
                    if (((_bit == (nb_bits_in_this_byte - 1)) && (index == (length - 1))) && (flip_tms == 1))
                    begin
                        tms <= 1'b1;
                    end

                    #TCK_HALF_PERIOD tck <= 1;
                    data_in[_bit] <= tdo;
                    #TCK_HALF_PERIOD tck <= 0;
                end
                int_buffer_in[index] = data_in;
            end

            tdi <= 1'b0;
            tms <= 1'b0;
        end

    endtask

    initial
    begin end

endmodule

jtag_dpi
========

TCP/IP controlled DPI JTAG Interface.

    +------------------+     +-----------------+     +------------------+      +----------+
    +                  +     +                 +     +                  +      +          +
    + Testbench client + <=> + JTAG DPI server + <-> + JTAG DPI verilog + <--> + JTAG TAP +
    +                  +     +                 +     +                  +      +          +
    +------------------+     +-----------------+     +------------------+      +----------+
        test_client.c             jtag_dpi.c               jtag_dpi.sv             any tap...
    -------------------- TCP  ------------------  DPI ---------------------   --------------
    --------------------      ---------------------------------------------   --------------

A testbench is provided and can be run with:

    cd sim/run
    make sim

This simulation requires icarus verilog.
Result output is a waveform in VCD format.

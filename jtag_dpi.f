-dpiheader dpiheader.h 
-Wcxx,-std=c++11,-fpermissive,-lpthread,-fPIC,-shared
-I./
-ccargs -std=c++11
-cpost
$TOPDIR/rtl/jtag_dpi/jtag_common.c
$TOPDIR/rtl/jtag_dpi/jtag_dpi.c
-end
$TOPDIR/rtl/jtag_dpi/jtag_dpi.sv

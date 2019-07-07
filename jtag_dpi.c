/*
 * TCP/IP controlled VPI JTAG Interface.
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
#include <svdpi.h>
#include <stdio.h>
#include <stdlib.h>
#include <arpa/inet.h>
#include "jtag_common.h"


static int is_host_little_endian(void)
{
	return (htonl(25) != 25);
}

static uint32_t from_little_endian_u32(uint32_t val)
{
	return is_host_little_endian() ? val : htonl(val);
}

static uint32_t to_little_endian_u32(uint32_t val)
{
	return from_little_endian_u32(val);
}

void dpi_check_for_command(int *cmd,int *length,int *nb_bits,const svOpenArrayHandle buffer_out)
{
    int i;
    struct jtag_cmd vpi;
	unsigned loaded_words = 0;
	//struct t_vpi_value argval;
	int *pBuf;
    

    if (check_for_command(&vpi))
	  return;

    //printf("Array Left %d, Array Right %d \n\n", svLeft(buffer_out,1), svRight(buffer_out, 1) );

    vpi.cmd = from_little_endian_u32(vpi.cmd);
	vpi.length = from_little_endian_u32(vpi.length);
	vpi.nb_bits = from_little_endian_u32(vpi.nb_bits);

    for(i = 0;i < vpi.length;i++)
    {
        pBuf = svGetArrElemPtr1(buffer_out, i);
        *pBuf = vpi.buffer_out[i];
    }
    *cmd = vpi.cmd;
    *length = vpi.length;
    *nb_bits = vpi.nb_bits;
    /*
    printf("dpi_check_for_command info %d %d %d\n",*cmd,*length,*nb_bits);
    for(i = 0;i < vpi.length;i++)
    {
        printf("bufOut[%d] = %d\n",i,vpi.buffer_out[i]);
    }
    */
}

void dpi_send_result_to_server(int length,int nb_bits,const svOpenArrayHandle buffer_in)
{
    int i;
	struct jtag_cmd vpi;
	int *pBuf;
 
    vpi.length = length;
    vpi.nb_bits = nb_bits;

    // Handle endianness
	vpi.cmd = to_little_endian_u32(vpi.cmd);
	vpi.length = to_little_endian_u32(vpi.length);
	vpi.nb_bits = to_little_endian_u32(vpi.nb_bits);

    for(i = 0;i < length;i++)
    {
        pBuf = svGetArrElemPtr1(buffer_in, i);
        vpi.buffer_in[i] = *pBuf;
    }

    /*
    printf("dpi_send_result_to_server %d %d\n",vpi.length,vpi.nb_bits);
    for(i =0;i< length;i++)
    {
        pBuf = svGetArrElemPtr1(buffer_in, i);
        printf("dpi_send_result_to_server buffer_in[%d] = %d\n",i,*pBuf);
    }
    */

	if (send_result_to_server(&vpi))
		printf("jtag_dpi: ERROR: error during write to server\n");

}


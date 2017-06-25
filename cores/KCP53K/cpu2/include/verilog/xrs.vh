`ifndef KCP53K_XRS_VH
`define KCP53K_XRS_VH

// The following settings for rwe_i are selected so that common sizes have as
// many bits in common as possible.  The hope is that synthesis tools will pick
// up on this and minimize logic synthesized accordingly.

`define XRS_RWE_NO	(3'b000)
`define XRS_RWE_U8	(3'b001)
`define XRS_RWE_U16	(3'b010)
`define XRS_RWE_U32	(3'b011)
`define XRS_RWE_S64	(3'b100)
`define XRS_RWE_S8	(3'b101)
`define XRS_RWE_S16	(3'b110)
`define XRS_RWE_S32	(3'b111)

`endif


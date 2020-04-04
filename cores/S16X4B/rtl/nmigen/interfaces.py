from nmigen import Signal


# Unprefixed opcodes are 100% backward compatible with S16X4A.
# New addition is the use of opcode 8 as an escape prefix.
# Additionally, opcode 9 is reserved as a prefix for future
# use.
OPC_NOP = 0
OPC_LIT = 1
OPC_FWM = 2
OPC_SWM = 3
OPC_ADD = 4
OPC_AND = 5
OPC_XOR = 6
OPC_ZGO = 7
OPC_prefix8 = 8
OPC_prefix9 = 9
OPC_FBM = 10
OPC_SBM = 11
OPC_LCALL = 12
OPC_ICALL = 13
OPC_GO = 14
OPC_NZGO = 15

# 8-prefixed opcodes below.
PFX8_FCR = 0   # Fetch Control Register
PFX8_SCR = 1   # Store Control Register
PFX8_INW = 2   # Read word from I/O device
PFX8_OUTW = 3  # Write word to I/O device
PFX8_unk4 = 4
PFX8_unk5 = 5
PFX8_unk6 = 6
PFX8_unk7 = 7
PFX8_unk8 = 8
PFX8_unk9 = 9
PFX8_unkA = 10
PFX8_unkB = 11
PFX8_unkC = 12
PFX8_unkD = 13
PFX8_unkE = 14
PFX8_unkF = 15

# Address Types
#
# AT_O is a 3 bit signal.  5 out of the 8 cycle types are defined.
# Values are defined so that AT_O[0:2] can be tied directly to
# hardware expecting VPA_O and VDA_O of a 65816 or S16X4A.
#
#     2       1       0
# +-------+-------+-------+
# | IOREQ |  VPA  |  VDA  |
# +-------+-------+-------+
#
# (I avoid the use of "Cycle Type" because this term has some
# prior-defined meaning in the context of a Wishbone interconnect.)

AT_IDLE = 0  # Bus is idle; address is meaningless.
AT_DAT = 1   # Bus is presenting a data memory address.
AT_PGM = 2   # Bus is presenting a program memory address.
AT_ARG = 3   # Bus is presenting a program memory address, but for an operand.
AT_unk4 = 4  #
AT_IO = 5    # Bus is presenting an I/O port address.
AT_unk6 = 6  #
AT_unk7 = 7  #


def create_s16x4b_interface(self, platform=''):
    self.adr_o = Signal(15)   # Word address
    self.we_o = Signal(1)
    self.cyc_o = Signal(1)
    self.stb_o = Signal(1)
    self.sel_o = Signal(2)
    self.at_o = Signal(3)     # New with S16X4B; replaces vda_o and vpa_o
    self.dat_o = Signal(16)
    self.ack_i = Signal(1)
    self.err_i = Signal(1)    # New with S16X4A (then called ABORT_I)
    self.dat_i = Signal(16)
    self.irq_i = Signal(16)   # New with S16X4B

    if platform == 'formal':
        self.fv_pc = Signal(15)
        self.fv_iw = Signal(16)
        self.fv_f_e = Signal(1)
        self.fv_u = Signal(16)
        self.fv_v = Signal(16)
        self.fv_w = Signal(16)
        self.fv_x = Signal(16)
        self.fv_y = Signal(16)
        self.fv_z = Signal(16)
        self.fv_opc = Signal(4)
        self.fv_cycle_done = Signal(1)



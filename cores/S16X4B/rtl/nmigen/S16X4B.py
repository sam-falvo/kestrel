from nmigen.test.utils import FHDLTestCase
from nmigen import (
    Elaboratable,
    Module,
    ResetSignal,
    Signal,
    Const,
)
from nmigen.hdl.ast import (
    Assert,
    Assume,
    Fell,
    Past,
    Stable,
)

# This module implements the S16X4B processor, a port of the S16X4A
# processor from Verilog to nMigen.  Along the way, some additional
# instructions and facilities have been added, mainly surrounding
# interrupt and I/O processing facilities.


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
PFX8_FWC = 0
PFX8_SWC = 1
PFX8_INW = 2
PFX8_OUTW = 3
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

AT_IDLE = 0
AT_DAT = 1
AT_PGM = 2
AT_ARG = 3
AT_unk4 = 4
AT_IO = 5
AT_unk6 = 6
AT_unk7 = 7


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
    self.dat_i = Signal(1)
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


class S16X4B(Elaboratable):
    def __init__(self, platform=''):
        super().__init__()
        create_s16x4b_interface(self, platform=platform)

    def elaborate(self, platform):
        m = Module()
        sync = m.d.sync
        comb = m.d.comb

        # Processor state
        f_e = Signal(1, reset=1)           # fetch(1)/execute(0)
        pc = Signal(15, reset=0)           # Program Counter
        iw = Signal(16)                    # Instruction Word
        U = Signal(16, reset=0)            # Evaluation stack bottom
        V = Signal(16, reset=0)
        W = Signal(16, reset=0)
        X = Signal(16, reset=0)
        Y = Signal(16, reset=0x0002)       # Processor core version tag.
        Z = Signal(16, reset=0)            # Evaluation stack top

        opc = Signal(4)                    # Currently executing opcode
        comb += opc.eq(iw[12:16])

        # Our master interface implements Wishbone B.3, and only with
        # simple bus transactions at that.  CYC_O will always equal
        # STB_O.
        comb += self.stb_o.eq(self.cyc_o)

        # Default bus conditions
        comb += [
            self.adr_o.eq(0),
            self.we_o.eq(0),
            self.at_o.eq(0),
            self.sel_o.eq(0),
            self.cyc_o.eq(0),
        ]

        # Instruction fetch logic
        #
        # last_instruction is asserted when we're executing the
        # last instruction in the IW register.
        last_instruction = Signal(1)
        comb += last_instruction.eq(~f_e & (iw[0:12] == 0))

        # Force U-Z to be actual registers.  Unless they're
        # explicitly modified elsewhere, these should *never*
        # change.
        sync += [
            U.eq(U),
            V.eq(V),
            W.eq(W),
            X.eq(X),
            Y.eq(Y),
            Z.eq(Z),
        ]

        # If we're fetching an instruction, then set the IW register
        # with the fetched data and increment the PC.
        with m.If(f_e):
            comb += [
                self.adr_o.eq(pc),
                self.we_o.eq(0),
                self.at_o.eq(AT_PGM),
                self.sel_o.eq(3),
                self.cyc_o.eq(1),
            ]

            with m.If(self.ack_i):
                sync += [
                    f_e.eq(0),
                    iw.eq(self.dat_i),
                    pc.eq(pc+1),
                ]

        # Execute instructions.  cycle_done is asserted when it's safe
        # to move to the next opcode in the instruction word.
        cycle_done = Signal(1)
        comb += cycle_done.eq((~self.cyc_o) | (self.cyc_o & self.ack_i))

        with m.If(~f_e):
            with m.If(cycle_done):
                sync += iw.eq(iw << 4)
                with m.If(last_instruction):
                    sync += f_e.eq(1)

            with m.If(opc == OPC_LIT):
                comb += [
                    self.adr_o.eq(pc),
                    self.we_o.eq(0),
                    self.at_o.eq(AT_ARG),
                    self.sel_o.eq(3),
                    self.cyc_o.eq(1),
                ]

                with m.If(self.ack_i):
                    sync += [
                        pc.eq(pc+1),
                        U.eq(V),
                        V.eq(W),
                        W.eq(X),
                        X.eq(Y),
                        Y.eq(Z),
                        Z.eq(self.dat_i),
                    ]

        if platform == 'formal':
            comb += [
                self.fv_pc.eq(pc),
                self.fv_iw.eq(iw),
                self.fv_f_e.eq(f_e),
                self.fv_u.eq(U),
                self.fv_v.eq(V),
                self.fv_w.eq(W),
                self.fv_x.eq(X),
                self.fv_y.eq(Y),
                self.fv_z.eq(Z),
                self.fv_opc.eq(opc),
                self.fv_cycle_done.eq(cycle_done),
            ]

        return m


def stack_is_stable(self):
    return [
        Assert(Stable(self.fv_z)),
        Assert(Stable(self.fv_y)),
        Assert(Stable(self.fv_x)),
        Assert(Stable(self.fv_w)),
        Assert(Stable(self.fv_v)),
        Assert(Stable(self.fv_u)),
    ]


class S16X4BFormal(Elaboratable):
    def __init__(self):
        super().__init__()
        create_s16x4b_interface(self, platform="formal")

    def elaborate(self, platform):
        m = Module()
        sync = m.d.sync
        comb = m.d.comb

        # This flag indicates when it's safe to use Past(), Stable(), etc.
        # Required so we can detect the start of simulation and prevent literal
        # edge cases from giving false negatives concerning the behavior of the
        # Past and Stable functions.
        z_past_valid = Signal(1, reset=0)
        sync += z_past_valid.eq(1)

        dut = S16X4B(platform=platform)
        m.submodules.dut = dut
        rst = ResetSignal()

        past_valid = Signal()
        comb += past_valid.eq(z_past_valid & Stable(rst) & ~rst)

        # Connect DUT outputs
        comb += [
            self.adr_o.eq(dut.adr_o),
            self.we_o.eq(dut.we_o),
            self.cyc_o.eq(dut.cyc_o),
            self.stb_o.eq(dut.stb_o),
            self.sel_o.eq(dut.sel_o),
            self.at_o.eq(dut.at_o),
            self.dat_o.eq(dut.dat_o),

            self.fv_pc.eq(dut.fv_pc),
            self.fv_iw.eq(dut.fv_iw),
            self.fv_f_e.eq(dut.fv_f_e),
            self.fv_u.eq(dut.fv_u),
            self.fv_v.eq(dut.fv_v),
            self.fv_w.eq(dut.fv_w),
            self.fv_x.eq(dut.fv_x),
            self.fv_y.eq(dut.fv_y),
            self.fv_z.eq(dut.fv_z),
            self.fv_opc.eq(dut.fv_opc),
        ]

        # Connect DUT inputs.  These will be driven by the formal verifier
        # for us, based on assertions and assumptions.
        comb += [
            dut.ack_i.eq(self.ack_i),
            dut.err_i.eq(self.err_i),
            dut.dat_i.eq(self.dat_i),
            dut.irq_i.eq(self.irq_i),
        ]

        # As a Wishbone B.3 compatible master, whenever CYC_O is asserted,
        # so too is STB_O.
        with m.If(self.cyc_o):
            sync += Assert(self.stb_o)
            
        # If the processor is reset, processor must commence instruction
        # execution at address 0.
        with m.If(z_past_valid & Fell(rst)):
            sync += [
                Assert(self.adr_o == 0),
                Assert(self.we_o == 0),
                Assert(self.stb_o == 1),
                Assert(self.sel_o == 0x3),
                Assert(self.at_o == AT_PGM),
            ]

        # If the processor is mid-bus-cycle and no acknowledgement exists
        # yet, we must insert a wait state.
        with m.If(past_valid & Past(self.stb_o) & ~Past(self.ack_i)):
            sync += [
                Assert(Stable(self.adr_o)),
                Assert(Stable(self.we_o)),
                Assert(Stable(self.stb_o)),
                Assert(Stable(self.sel_o)),
                Assert(Stable(self.at_o)),
            ]

        # If we're fetching an instruction, the PC increments when the cycle
        # is acknowledged.  If we're fetching an opcode word, then make sure
        # that IW is loaded with the fetched data.

        with m.If(
            past_valid &
            Past(self.stb_o) &
            ((Past(self.at_o) == AT_PGM) | (Past(self.at_o) == AT_ARG)) &
            Past(self.ack_i)
        ):
            sync += Assert(self.fv_pc == (Past(self.fv_pc)+1)[0:15])

        with m.If(
            past_valid &
            Past(self.stb_o) &
            (Past(self.at_o) == AT_PGM) &
            Past(self.ack_i)
        ):
            sync += Assert(self.fv_iw == Past(self.dat_i))

        # Fetching an instruction word with all NOPs will cause one
        # execution cycle to elapse, and then it should commence fetching
        # another instruction word.  Put another way, instruction
        # slot 1 is always executed; but if slots 2-4 are NOPs, then we
        # just fetch the next instruction word right away.

        with m.If(
            past_valid &
            Past(self.stb_o) &
            (Past(self.at_o) == AT_PGM) &
            Past(self.ack_i) &
            (Past(self.dat_i) == 0)
        ):
            sync += [
                Assert(~self.fv_f_e),
                Assert(~self.stb_o),
            ]

        # (if previous instruction was not a memory or I/O operation)
        with m.If(
            past_valid &
            ~Past(self.fv_f_e) &
            (Past(self.fv_iw)[0:12] == 0) &
            ~Past(self.stb_o)
        ):
            sync += [
                Assert(self.fv_f_e),
                Assert(self.adr_o == Past(self.fv_pc)),
                Assert(~self.we_o),
                Assert(self.sel_o == 3),
                Assert(self.stb_o),
                Assert(self.at_o == AT_PGM),
            ]

        # (if previous instruction was a mem/I/O op, and it's completed)
        # (excluding LIT, as that advances PC.)
        with m.If(
            past_valid &
            ~Past(self.fv_f_e) &
            (Past(self.fv_iw)[0:12] == 0) &
            (Past(self.fv_opc) != OPC_LIT) &
            Past(self.stb_o) &
            Past(self.ack_i)
        ):
            sync += [
                Assert(self.fv_f_e),
                Assert(self.adr_o == Past(self.fv_pc)),
                Assert(~self.we_o),
                Assert(self.sel_o == 3),
                Assert(self.stb_o),
                Assert(self.at_o == AT_PGM),
            ]

        # If the currently executing opcode is NOP, then processor state should
        # remain stable.
        with m.If(
            past_valid &
            ~Past(self.fv_f_e) &
            (Past(self.fv_opc) == OPC_NOP)
        ):
            sync += [
                Assert(self.fv_u == Past(self.fv_u)),
                Assert(self.fv_v == Past(self.fv_v)),
                Assert(self.fv_w == Past(self.fv_w)),
                Assert(self.fv_x == Past(self.fv_x)),
                Assert(self.fv_y == Past(self.fv_y)),
                Assert(self.fv_z == Past(self.fv_z)),
            ]

        # If loading a literal, push the fetched value onto the stack.
        with m.If(
            past_valid &
            ~self.fv_f_e &
            (self.fv_opc == OPC_LIT)
        ):
            comb += [
                Assert(self.adr_o == self.fv_pc),
                Assert(~self.we_o),
                Assert(self.sel_o == 3),
                Assert(self.at_o == AT_ARG),
                Assert(self.stb_o),
            ]
 
        with m.If(
            past_valid &
            ~Past(self.fv_f_e) &
            (Past(self.fv_opc) == OPC_LIT) &
            Past(self.ack_i)
        ):
            sync += [
                Assert(self.fv_z == Past(self.dat_i)),
                Assert(self.fv_y == Past(self.fv_z)),
                Assert(self.fv_x == Past(self.fv_y)),
                Assert(self.fv_w == Past(self.fv_x)),
                Assert(self.fv_v == Past(self.fv_w)),
                Assert(self.fv_u == Past(self.fv_v)),
                Assert(self.fv_pc == (Past(self.fv_pc)+1)[0:15]),
            ]

        with m.If(
            past_valid &
            ~Past(self.fv_f_e) &
            (Past(self.fv_opc) == OPC_LIT) &
            ~Past(self.ack_i)
        ):
            sync += [
                *stack_is_stable(self),
                Assert(Stable(self.fv_pc)),
            ]

        return m
        

class S16X4BFormalTest(FHDLTestCase):
    def test_s16x4b(self):
        self.assertFormal(S16X4BFormal(), mode='bmc', depth=100)
        self.assertFormal(S16X4BFormal(), mode='prove', depth=100)

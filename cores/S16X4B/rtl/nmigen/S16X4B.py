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
OPC_LI = 1
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

    
class S16X4B(Elaboratable):
    def __init__(self, platform=''):
        super().__init__()
        create_s16x4b_interface(self, platform=platform)

    def elaborate(self, platform):
        m = Module()
        sync = m.d.sync
        comb = m.d.comb

        # Processor state
        t0 = Signal(1, reset=1)            # instruction fetch
        t1 = Signal(1, reset=0)            # execution cycle (T1-T4)

        pc = Signal(15, reset=0)           # Program Counter
        iw = Signal(16)                    # Instruction Word

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
        with m.If(t0):
            comb += [
                self.adr_o.eq(pc),
                self.we_o.eq(0),
                self.at_o.eq(AT_PGM),
                self.sel_o.eq(3),
                self.cyc_o.eq(1),
            ]

            with m.If(self.ack_i):
                sync += [
                    t0.eq(0),
                    t1.eq(1),
                    iw.eq(self.dat_i),
                    pc.eq(pc+1),
                ]

        if platform == 'formal':
            comb += [
                self.fv_pc.eq(pc),
                self.fv_iw.eq(iw),
            ]

        return m


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

        return m
        

class S16X4BFormalTest(FHDLTestCase):
    def test_s16x4b(self):
        self.assertFormal(S16X4BFormal(), mode='bmc', depth=100)
        self.assertFormal(S16X4BFormal(), mode='prove', depth=100)

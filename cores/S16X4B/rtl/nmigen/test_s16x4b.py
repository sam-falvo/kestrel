from nmigen.test.utils import FHDLTestCase
from nmigen import (
    Const,
    Elaboratable,
    Module,
    ResetSignal,
    Signal,
)
from nmigen.hdl.ast import (
    Assert,
    Assume,
    Fell,
    Past,
    Stable,
)

from interfaces import (
    AT_ARG,
    AT_DAT,
    AT_PGM,
    create_s16x4b_interface,
    OPC_ADD,
    OPC_AND,
    OPC_FWM,
    OPC_GO,
    OPC_ICALL,
    OPC_LCALL,
    OPC_LIT,
    OPC_NOP,
    OPC_NZGO,
    OPC_SWM,
    OPC_XOR,
    OPC_ZGO,
)

from S16X4B import S16X4B


class S16X4BFormal(Elaboratable):
    def __init__(self):
        super().__init__()
        create_s16x4b_interface(self, platform="formal")

    def stack_is_stable(self, except_z=None):
        if except_z is None:
            except_z = Past(self.fv_z)
        return [
            Assert(self.fv_z == except_z),
            Assert(Stable(self.fv_y)),
            Assert(Stable(self.fv_x)),
            Assert(Stable(self.fv_w)),
            Assert(Stable(self.fv_v)),
            Assert(Stable(self.fv_u)),
        ]
    
    def stack_pop_1(self, new_z):
        return [
            Assert(self.fv_z == new_z),
            Assert(self.fv_y == Past(self.fv_x)),
            Assert(self.fv_x == Past(self.fv_w)),
            Assert(self.fv_w == Past(self.fv_v)),
            Assert(self.fv_v == Past(self.fv_u)),
            Assert(self.fv_u == Past(self.fv_u)),
        ]
    
    def stack_pop_2(self):
        return [
            Assert(self.fv_z == Past(self.fv_x)),
            Assert(self.fv_y == Past(self.fv_w)),
            Assert(self.fv_x == Past(self.fv_v)),
            Assert(self.fv_w == Past(self.fv_u)),
            Assert(self.fv_v == Past(self.fv_u)),
            Assert(self.fv_u == Past(self.fv_u)),
        ]

    def is_word_fetch(self, address_type=AT_PGM, address=None):
        if address is None:
            address = self.fv_pc
        return [
            Assert(self.adr_o == address),
            Assert(self.at_o == address_type),
            Assert(~self.we_o),
            Assert(self.sel_o == 3),
            Assert(self.stb_o),
        ]

    def bus_is_stable(self):
        return [
            Assert(Stable(self.adr_o)),
            Assert(Stable(self.we_o)),
            Assert(Stable(self.stb_o)),
            Assert(Stable(self.sel_o)),
            Assert(Stable(self.at_o)),
        ]

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
            sync += self.is_word_fetch(address=0, address_type=AT_PGM)

        # If the processor is mid-bus-cycle and no acknowledgement exists
        # yet, we must insert a wait state.
        with m.If(past_valid & Past(self.stb_o) & ~Past(self.ack_i)):
            sync += self.bus_is_stable()

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
            sync += Assert(~self.fv_f_e)

        # (if previous instruction was not a memory or I/O operation
        # and was not a branch instruction, whose cases are handled
        # elsewhere...)
        with m.If(
            past_valid &
            ~Past(self.fv_f_e) &
            (Past(self.fv_iw)[0:12] == 0) &
            (Past(self.fv_opc) != OPC_ZGO) &
            (Past(self.fv_opc) != OPC_NZGO) &
            (Past(self.fv_opc) != OPC_GO) &
            (Past(self.fv_opc) != OPC_LCALL) &
            (Past(self.fv_opc) != OPC_ICALL) &
            ~Past(self.stb_o)
        ):
            sync += [
                Assert(self.fv_f_e),
                *self.is_word_fetch(address=Past(self.fv_pc), address_type=AT_PGM),
            ]

        # (if previous instruction was a mem/I/O op, and it's completed)
        # (excluding LIT, as that advances PC; LIT is checked elsewhere.)
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
                *self.is_word_fetch(address=Past(self.fv_pc), address_type=AT_PGM),
            ]

        # If the currently executing opcode is NOP, then processor state should
        # remain stable.
        with m.If(
            past_valid &
            ~Past(self.fv_f_e) &
            (Past(self.fv_opc) == OPC_NOP)
        ):
            sync += self.stack_is_stable()

        # If loading a literal, push the fetched value onto the stack.
        with m.If(
            past_valid &
            ~self.fv_f_e &
            (self.fv_opc == OPC_LIT)
        ):
            comb += self.is_word_fetch(address=self.fv_pc, address_type=AT_ARG)
 
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
                *self.stack_is_stable(),
                Assert(Stable(self.fv_pc)),
            ]
 
        # If fetching a word from memory, Z provides the memory address.
        # Low bit of Z is ignored.  (Issue: support misalignment traps
        # in the future?)
        with m.If(
            past_valid &
            ~self.fv_f_e &
            (self.fv_opc == OPC_FWM)
        ):
            comb += self.is_word_fetch(address=self.fv_z[1:16], address_type=AT_DAT)
 
        with m.If(
            past_valid &
            ~Past(self.fv_f_e) &
            (Past(self.fv_opc) == OPC_FWM) &
            Past(self.ack_i)
        ):
            sync += self.stack_is_stable(except_z=Past(self.dat_i))

        with m.If(
            past_valid &
            ~Past(self.fv_f_e) &
            (Past(self.fv_opc) == OPC_FWM) &
            ~Past(self.ack_i)
        ):
            sync += self.stack_is_stable()

        # If storing a word from memory, Z provides the memory address,
        # and Y the data to store.  Both are consumed.  Low bit of Z
        # is ignored.  (Issue: support misalignment traps in the future?)
        with m.If(
            past_valid &
            ~self.fv_f_e &
            (self.fv_opc == OPC_SWM)
        ):
            comb += [
                Assert(self.adr_o == self.fv_z[1:16]),
                Assert(self.we_o),
                Assert(self.sel_o == 3),
                Assert(self.at_o == AT_DAT),
                Assert(self.stb_o),
                Assert(self.dat_o == self.fv_y),
            ]
 
        with m.If(
            past_valid &
            ~Past(self.fv_f_e) &
            (Past(self.fv_opc) == OPC_SWM) &
            Past(self.ack_i)
        ):
            sync += self.stack_pop_2()

        with m.If(
            past_valid &
            ~Past(self.fv_f_e) &
            (Past(self.fv_opc) == OPC_SWM) &
            ~Past(self.ack_i)
        ):
            sync += self.stack_is_stable()

        # Original Steamer-16 operators, + AND XOR
        with m.If(
            past_valid &
            ~Past(self.fv_f_e) &
            (Past(self.fv_opc) == OPC_ADD)
        ):
            sync += self.stack_pop_1((Past(self.fv_z) + Past(self.fv_y))[0:16])

        with m.If(
            past_valid &
            ~Past(self.fv_f_e) &
            (Past(self.fv_opc) == OPC_AND)
        ):
            sync += self.stack_pop_1(Past(self.fv_z) & Past(self.fv_y))

        with m.If(
            past_valid &
            ~Past(self.fv_f_e) &
            (Past(self.fv_opc) == OPC_XOR)
        ):
            sync += self.stack_pop_1(Past(self.fv_z) ^ Past(self.fv_y))

        # ZGO branches conditionally.  If Y=0, PC becomes the address in Z.
        # (Low bit of Z is ignored.)  Otherwise PC is left unchanged.
        # A successful branch takes immediate effect.
        with m.If(
            past_valid &
            ~Past(self.fv_f_e) &
            (Past(self.fv_opc) == OPC_ZGO) &
            (Past(self.fv_y) == 0)
        ):
            sync += [
                *self.stack_pop_2(),
                Assert(self.fv_f_e),
                *self.is_word_fetch(address=Past(self.fv_z)[1:16], address_type=AT_PGM),
            ]

        with m.If(
            past_valid &
            ~Past(self.fv_f_e) &
            (Past(self.fv_opc) == OPC_ZGO) &
            (Past(self.fv_y) != 0)
        ):
            sync += self.stack_pop_2()

            with m.If(Past(self.fv_iw)[0:12] == 0):
                sync += [
                    Assert(self.fv_f_e),
                    *self.is_word_fetch(address=self.fv_pc, address_type=AT_PGM),
                ]

            with m.If(Past(self.fv_iw)[0:12] != 0):
                sync += Assert(~self.fv_f_e)

        return m
        

class S16X4BFormalTest(FHDLTestCase):
    def test_s16x4b(self):
        self.assertFormal(S16X4BFormal(), mode='bmc', depth=100)
        self.assertFormal(S16X4BFormal(), mode='prove', depth=100)

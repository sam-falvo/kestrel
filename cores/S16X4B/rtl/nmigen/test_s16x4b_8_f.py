# This module implements the S16X4B processor, a port of the S16X4A
# processor from Verilog to nMigen.  Along the way, some additional
# instructions and facilities have been added, mainly surrounding
# interrupt and I/O processing facilities.


from nmigen.test.utils import FHDLTestCase
from nmigen import (
    Cat,
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
    AT_DAT,
    AT_PGM,
    OPC_FBM,
    OPC_GO,
    OPC_ICALL,
    OPC_LCALL,
    OPC_NZGO,
    OPC_SBM,
    create_s16x4b_interface,
)

from S16X4B import S16X4B


class S16X4B_8toF_Formal(Elaboratable):
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

    def stack_push_1(self, new_z):
        return [
            Assert(self.fv_z == new_z),
            Assert(self.fv_y == Past(self.fv_z)),
            Assert(self.fv_x == Past(self.fv_y)),
            Assert(self.fv_w == Past(self.fv_x)),
            Assert(self.fv_v == Past(self.fv_w)),
            Assert(self.fv_u == Past(self.fv_v)),
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

    def is_byte_fetch(self, address_type=AT_DAT, address=None):
        if address is None:
            address = self.fv_z
        return [
            Assert(self.adr_o == address[1:16]),
            Assert(self.at_o == address_type),
            Assert(~self.we_o),
            Assert(self.sel_o[0] == ~self.sel_o[1]),
            Assert(self.sel_o[1] == address[0]),
            Assert(self.stb_o),
        ]

    def is_byte_store(self, address_type=AT_DAT, lane=0):
        if lane == 0:
            data = Cat(self.fv_y[0:8], self.fv_y[0:8])
        else:
            data = Cat(self.fv_y[8:16], self.fv_y[8:16])

        return [
            Assert(self.adr_o == self.fv_z[1:16]),
            Assert(self.dat_o == data),
            Assert(self.at_o == address_type),
            Assert(self.we_o),
            Assert(self.sel_o[0] == ~self.sel_o[1]),
            Assert(self.sel_o[1] == self.fv_z[0]),
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
            self.trap_o.eq(dut.trap_o),

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

        # If fetching a byte from memory, Z provides the memory address.
        # Low bit of Z determines which byte lane to use.
        with m.If(
            past_valid &
            ~self.fv_f_e &
            ~self.trap_o &
            (self.fv_opc == OPC_FBM)
        ):
            comb += [
                *self.is_byte_fetch(address=self.fv_z, address_type=AT_DAT),
                Assert(self.sel_o[0] == ~self.sel_o[1]),
            ]

        with m.If(
            past_valid &
            ~Past(self.fv_f_e) &
            (Past(self.fv_opc) == OPC_FBM) &
            Past(self.sel_o)[0] &
            Past(self.stb_o) &
            Past(self.ack_i) &
            ~Past(self.err_i)
        ):
            sync += self.stack_is_stable(except_z=Cat(Past(self.dat_i)[0:8], Const(0, 8)))

        with m.If(
            past_valid &
            ~Past(self.fv_f_e) &
            (Past(self.fv_opc) == OPC_FBM) &
            Past(self.sel_o)[1] &
            Past(self.stb_o) &
            Past(self.ack_i) &
            ~Past(self.err_i)
        ):
            sync += self.stack_is_stable(except_z=Cat(Past(self.dat_i)[8:16], Const(0, 8)))

        with m.If(
            past_valid &
            ~Past(self.fv_f_e) &
            (Past(self.fv_opc) == OPC_FBM) &
            Past(self.stb_o) &
            ~Past(self.ack_i) &
            ~Past(self.err_i)
        ):
            sync += self.stack_is_stable()

        # If storing a byte to memory, Z provides the memory address.
        # Low bit of Z determines which byte lane to use.
        with m.If(
            past_valid &
            ~self.fv_f_e &
            (self.fv_opc == OPC_SBM) &
            ~self.fv_z[0] &
            ~self.trap_o
        ):
            comb += [
                *self.is_byte_store(address_type=AT_DAT, lane=0),
                Assert(self.sel_o[0] == ~self.sel_o[1]),
            ]
 
        with m.If(
            past_valid &
            ~self.fv_f_e &
            (self.fv_opc == OPC_SBM) &
            self.fv_z[0] &
            ~self.trap_o
        ):
            comb += [
                *self.is_byte_store(address_type=AT_DAT, lane=1),
                Assert(self.sel_o[0] == ~self.sel_o[1]),
            ]

        with m.If(
            past_valid &
            ~Past(self.fv_f_e) &
            (Past(self.fv_opc) == OPC_SBM) &
            Past(self.stb_o) &
            Past(self.ack_i) &
            ~Past(self.err_i)
        ):
            sync += self.stack_pop_2()

        with m.If(
            past_valid &
            ~Past(self.fv_f_e) &
            (Past(self.fv_opc) == OPC_SBM) &
            Past(self.stb_o) &
            ~Past(self.ack_i) &
            ~Past(self.err_i)
        ):
            sync += self.stack_is_stable()

        # If calling a subroutine with LCALL,
        # the data stack is pushed with the return address,
        # and the remaining slots are treated as a signed
        # word displacement to the *current* program counter,
        # not the address of the LCALL instruction.
        with m.If(
            past_valid &
            ~self.fv_f_e &
            (self.fv_opc == OPC_LCALL)
        ):
            comb += Assert(~self.stb_o)

        with m.If(
            past_valid &
            ~Past(self.fv_f_e) &
            (Past(self.fv_opc) == OPC_LCALL)
        ):
            d12 = Past(self.fv_iw)[0:12]
            displacement = Cat(d12, d12[11], d12[11], d12[11])
            sync += [
                Assert(self.fv_pc == (Past(self.fv_pc) + displacement)[0:15]),
                *self.is_word_fetch(address=self.fv_pc, address_type=AT_PGM),
                *self.stack_push_1(Cat(Const(0, 1), Past(self.fv_pc))),
            ]

        # If calling a subroutine with ICALL,
        # the Z and PC registers are swapped.
        # The low-bit of Z is ignored, and the low bit of PC
        # is assumed to be 0.
        with m.If(
            past_valid &
            ~self.fv_f_e &
            (self.fv_opc == OPC_ICALL)
        ):
            comb += Assert(~self.stb_o)

        with m.If(
            past_valid &
            ~Past(self.fv_f_e) &
            (Past(self.fv_opc) == OPC_ICALL)
        ):
            sync += [
                Assert(self.fv_pc == Past(self.fv_z)[1:16]),
                *self.is_word_fetch(address=self.fv_pc, address_type=AT_PGM),
                *self.stack_is_stable(except_z=Cat(Const(0, 1), Past(self.fv_pc))),
            ]

        # GO branches unconditionally.
        with m.If(
            past_valid &
            ~Past(self.fv_f_e) &
            (Past(self.fv_opc) == OPC_GO)
        ):
            sync += [
                *self.stack_pop_1(Past(self.fv_y)),
                Assert(self.fv_f_e),
                *self.is_word_fetch(address=Past(self.fv_z)[1:16], address_type=AT_PGM),
            ]

        # NZGO branches conditionally.  If Y!=0, PC becomes the address in Z.
        # (Low bit of Z is ignored.)  Otherwise PC is left unchanged.
        # A successful branch takes immediate effect.
        with m.If(
            past_valid &
            ~Past(self.fv_f_e) &
            (Past(self.fv_opc) == OPC_NZGO) &
            (Past(self.fv_y) != 0)
        ):
            sync += [
                *self.stack_pop_2(),
                Assert(self.fv_f_e),
                *self.is_word_fetch(address=Past(self.fv_z)[1:16], address_type=AT_PGM),
            ]

        with m.If(
            past_valid &
            ~Past(self.fv_f_e) &
            (Past(self.fv_opc) == OPC_NZGO) &
            (Past(self.fv_y) == 0)
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
        

class S16X4B_8toF_FormalTest(FHDLTestCase):
    def test_8toF(self):
        self.assertFormal(S16X4B_8toF_Formal(), mode='bmc', depth=100)
        self.assertFormal(S16X4B_8toF_Formal(), mode='prove', depth=100)

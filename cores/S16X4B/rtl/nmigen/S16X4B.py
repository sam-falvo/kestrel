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
    AT_ARG,
    AT_DAT,
    AT_PGM,
    OPC_ADD,
    OPC_AND,
    OPC_FBM,
    OPC_FWM,
    OPC_GO,
    OPC_ICALL,
    OPC_LCALL,
    OPC_LIT,
    OPC_NOP,
    OPC_NZGO,
    OPC_SBM,
    OPC_SWM,
    OPC_XOR,
    OPC_ZGO,
    create_s16x4b_interface,
)


class S16X4B(Elaboratable):
    def __init__(self, platform=''):
        super().__init__()
        create_s16x4b_interface(self, platform=platform)

    def __push_1(self, data):
        return [
            self.U.eq(self.V),
            self.V.eq(self.W),
            self.W.eq(self.X),
            self.X.eq(self.Y),
            self.Y.eq(self.Z),
            self.Z.eq(data),
        ]

    def __pop_1(self, new_z):
        return [
            self.Z.eq(new_z),
            self.Y.eq(self.X),
            self.X.eq(self.W),
            self.W.eq(self.V),
            self.V.eq(self.U),
            self.U.eq(self.U),
        ]

    def __pop_2(self):
        return [
            self.Z.eq(self.X),
            self.Y.eq(self.W),
            self.X.eq(self.V),
            self.W.eq(self.U),
            self.V.eq(self.U),
            self.U.eq(self.U),
        ]

    def elaborate(self, platform):
        m = Module()
        sync = m.d.sync
        comb = m.d.comb

        # Processor state (S16X4)
        f_e = Signal(1, reset=1)                    # fetch(1)/execute(0)
        pc = Signal(15, reset=0)                    # Program Counter
        iw = Signal(16)                             # Instruction Word

        X = self.X = Signal(16)                     # Bottom of evaluation stack.
        Y = self.Y = Signal(16)
        Z = self.Z = Signal(16, reset=2)            # Top of eval stack (version tag)

        # Processor state (S16X4A)
        U = self.U = Signal(16)                     # New bottom of eval stack
        V = self.V = Signal(16)
        W = self.W = Signal(16)
        
        # Processor state (S16X4B)
        current_slot = Signal(2)
        ipa = Signal(len(pc))
        ie = Signal(len(self.dat_i))
        ehpc = Signal(len(pc))

        epc = Signal(len(pc))
        eiw = Signal(len(iw))
        eipa = Signal(len(ipa))
        eie = Signal(len(ie))
        efe = Signal(len(f_e))
        ecs = Signal(len(current_slot))
        eat = Signal(len(self.at_o))

        # Currently executing opcode
        opc = Signal(4)
        take_trap = Signal(1)

        comb += [
            opc.eq(iw[12:16]),
            self.trap_o.eq(take_trap),
        ]

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

        # Handle traps.  Traps should contain enough information
        # to allow a return-from-interrupt instruction to restart
        # the instruction which caused the trap.  This should
        # let a designer use an external memory-management unit
        # to implement virtual memory or memory protection features.
        with m.If(take_trap):
            sync += [
                take_trap.eq(0),

                efe.eq(f_e),
                epc.eq(pc),
                eiw.eq(iw),
                eipa.eq(ipa),
                eie.eq(ie),
                ecs.eq(current_slot),

                f_e.eq(1),
                pc.eq(ehpc),
                ie.eq(0),
            ]

        # If we're fetching an instruction, then set the IW register
        # with the fetched data and increment the PC.  For the benefit
        # of exception handlers, we also set IPA to the address of the
        # fetched instruction, to facilitate restartability.
        with m.If(f_e & ~take_trap):
            comb += [
                self.adr_o.eq(pc),
                self.we_o.eq(0),
                self.at_o.eq(AT_PGM),
                self.sel_o.eq(3),
                self.cyc_o.eq(1),
            ]

            with m.If(self.ack_i & ~self.err_i):
                sync += [
                    f_e.eq(0),
                    iw.eq(self.dat_i),
                    pc.eq(pc+1),
                ]

            with m.If(self.err_i):
                sync += [
                    take_trap.eq(1),
                    eat.eq(self.at_o),
                ]

        # Execute instructions.  cycle_done is asserted when it's safe
        # to move to the next opcode in the instruction word.
        cycle_done = Signal(1)
        comb += cycle_done.eq((~self.cyc_o) | (self.cyc_o & self.ack_i & ~self.err_i))

        with m.If(~f_e & ~take_trap):
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

                with m.If(self.ack_i & ~self.err_i):
                    sync += [
                        *self.__push_1(self.dat_i),
                        pc.eq(pc+1),
                    ]

                with m.If(self.err_i):
                    sync += [
                        take_trap.eq(1),
                        eat.eq(self.at_o),
                    ]

            with m.If(opc == OPC_FWM):
                comb += [
                    self.adr_o.eq(Z[1:]),
                    self.we_o.eq(0),
                    self.at_o.eq(AT_DAT),
                    self.sel_o.eq(3),
                    self.cyc_o.eq(1),
                ]

                with m.If(self.ack_i & ~self.err_i):
                    sync += [
                        Z.eq(self.dat_i),
                    ]

                with m.If(self.err_i):
                    sync += [
                        take_trap.eq(1),
                        eat.eq(self.at_o),
                    ]

            with m.If(opc == OPC_FBM):
                comb += [
                    self.adr_o.eq(Z[1:]),
                    self.we_o.eq(0),
                    self.at_o.eq(AT_DAT),
                    self.sel_o.eq(Cat(~Z[0], Z[0])),
                    self.cyc_o.eq(1),
                ]

                with m.If(self.ack_i & ~self.err_i):
                    with m.If(Z[0]):
                        sync += Z.eq(Cat(self.dat_i[8:16], Const(0, 8)))
                    with m.If(~Z[0]):
                        sync += Z.eq(Cat(self.dat_i[0:8], Const(0, 8)))

                with m.If(self.err_i):
                    sync += [
                        take_trap.eq(1),
                        eat.eq(self.at_o),
                    ]

            with m.If(opc == OPC_SWM):
                comb += [
                    self.adr_o.eq(Z[1:]),
                    self.dat_o.eq(Y),
                    self.we_o.eq(1),
                    self.at_o.eq(AT_DAT),
                    self.sel_o.eq(3),
                    self.cyc_o.eq(1),
                ]

                with m.If(self.ack_i & ~self.err_i):
                    sync += self.__pop_2()
 
                with m.If(self.err_i):
                    sync += [
                        take_trap.eq(1),
                        eat.eq(self.at_o),
                    ]

            with m.If(opc == OPC_SBM):
                comb += [
                    self.adr_o.eq(Z[1:]),
                    self.we_o.eq(1),
                    self.at_o.eq(AT_DAT),
                    self.sel_o.eq(Cat(~Z[0], Z[0])),
                    self.cyc_o.eq(1),
                ]

                with m.If(~Z[0]):
                    comb += self.dat_o.eq(Cat(Y[0:8], Y[0:8]))

                with m.If(Z[0]):
                    comb += self.dat_o.eq(Cat(Y[8:16], Y[8:16]))

                with m.If(self.ack_i & ~self.err_i):
                    sync += self.__pop_2()

                with m.If(self.err_i):
                    sync += [
                        take_trap.eq(1),
                        eat.eq(self.at_o),
                    ]

            with m.If(opc == OPC_ADD):
                sync += self.__pop_1((Z + Y)[0:16])

            with m.If(opc == OPC_AND):
                sync += self.__pop_1(Z & Y)

            with m.If(opc == OPC_XOR):
                sync += self.__pop_1(Z ^ Y)

            with m.If(opc == OPC_ZGO):
                sync += self.__pop_2()
                with m.If(Y == 0):
                    sync += [
                        pc.eq(Z[1:]),
                        f_e.eq(1),
                    ]

            with m.If(opc == OPC_LCALL):
                sync += [
                    *self.__push_1(Cat(Const(0, 1), pc)),
                    pc.eq((pc + Cat(iw[0:12], iw[11], iw[11], iw[11]))[0:15]),
                    f_e.eq(1),
                ]

            with m.If(opc == OPC_ICALL):
                sync += [
                    Z.eq(Cat(Const(0, 1), pc)),
                    pc.eq(Z[1:]),
                    f_e.eq(1),
                ]

            with m.If(opc == OPC_GO):
                sync += [
                    *self.__pop_1(Y),
                    f_e.eq(1),
                    pc.eq(Z[1:]),
                ]

            with m.If(opc == OPC_NZGO):
                sync += self.__pop_2()
                with m.If(Y != 0):
                    sync += [
                        pc.eq(Z[1:]),
                        f_e.eq(1),
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
                self.fv_current_slot.eq(current_slot),
                self.fv_epc.eq(epc),
                self.fv_ecs.eq(ecs),
                self.fv_efe.eq(efe),
                self.fv_eat.eq(eat),
                self.fv_eiw.eq(eiw),
                self.fv_eipa.eq(eipa),
                self.fv_ipa.eq(ipa),
                self.fv_ie.eq(ie),
                self.fv_eie.eq(eie),
                self.fv_ehpc.eq(ehpc),
            ]

        return m

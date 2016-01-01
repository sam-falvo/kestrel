; BIOS Data Area.

bd_tag		= 0			; D BIOS Data Format tag ($B105)
bd_jumptab	= bd_tag + 8		; D Pointer to BIOS jump table
bd_bitplane	= bd_jumptab + 8	; D Pointer to MGIA framebuffer.
bd_planesz	= bd_bitplane + 8	; D Size of said framebuffer, bytes.
bd_cx		= bd_planesz + 8	; H Cursor X position
bd_cy		= bd_cx + 2		; H Cursor Y position
bd_maxcol	= bd_cy + 2		; H Maximum number of columns (typ. 80)
bd_maxrow	= bd_maxcol+2		; H Maximum number of rows (typ. 60)
bd_planebw	= bd_maxrow+2		; H Width of bitmap in bytes
bd_planeh	= bd_planebw+2		; H Height of bitmap in pixels
bd_chidecnt	= bd_planeh+2		; H Cursor hide counter.
bd_cblink	= bd_chidecnt+2		; B 0 if cursor invisible.
bd_padding1	= bd_cblink+1		; B reserved.
bd_fontform	= bd_padding1+1		; D Pointer to system font image.
bd_sp		= bd_fontform+8		; D Interrupted task stack pointer
bd_irqvecs	= bd_sp+8		; D Start of BIOS IRQ/trap vectors
  bd_ialnvec	= bd_irqvecs+0		; D Instr Alignment fault
  bd_iaccvec	= bd_ialnvec+8		; D Instr Access fault
  bd_iillvec	= bd_iaccvec+8		; D Illegal Instruction fault
  bd_ibrkvec	= bd_iillvec+8		; D EBREAK instruction trap
  bd_lalnvec	= bd_ibrkvec+8		; D Load alignment fault
  bd_laccvec	= bd_lalnvec+8		; D Load access fault
  bd_salnvec	= bd_laccvec+8		; D Store/AMO alignment fault
  bd_saccvec	= bd_salnvec+8		; D Store/AMO access fault
  bd_uenvvec	= bd_saccvec+8		; D ECALL from U-mode trap
  bd_senvvec	= bd_uenvvec+8		; D ECALL from S-mode trap
  bd_henvvec	= bd_senvvec+8		; D ECALL from H-mode trap
  bd_menvvec	= bd_henvvec+8		; D ECALL from M-mode trap
  bd_trap12	= bd_menvvec+8		; D reserved.
  bd_trap13	= bd_trap12+8		; D reserved.
  bd_trap14	= bd_trap13+8		; D reserved.
  bd_trap15	= bd_trap14+8		; D reserved.

  bd_swivec	= bd_trap15+8		; D Software interrupt
  bd_timvec	= bd_swivec+8		; D CPU Timer expire
  bd_kiavec	= bd_timvec+8		; D KIA interrupt
  bd_irq3	= bd_kiavec+8		; D reserved.
  bd_irq4	= bd_irq3+8		; D reserved.
  bd_irq5	= bd_irq4+8		; D reserved.
  bd_irq6	= bd_irq5+8		; D reserved.
  bd_irq7	= bd_irq6+8		; D reserved.
  bd_irq8	= bd_irq7+8		; D reserved.
  bd_irq9	= bd_irq8+8		; D reserved.
  bd_irq10	= bd_irq9+8		; D reserved.
  bd_irq11	= bd_irq10+8		; D reserved.
  bd_irq12	= bd_irq11+8		; D reserved.
  bd_irq13	= bd_irq12+8		; D reserved.
  bd_irq14	= bd_irq13+8		; D reserved.
  bd_irq15	= bd_irq14+8		; D reserved.
bd_rawque	= bd_irq15+8		; H*16 raw keyboard queue
bd_ascque	= bd_rawque+32		; B*16 ASCII keyboard queue
bd_rawhd	= bd_ascque+16		; B raw queue head
bd_rawtl	= bd_rawhd+1		; B raw queue tail
bd_aschd	= bd_rawtl+1		; B ASCII queue head
bd_asctl	= bd_aschd+1		; B ASCII queue tail
bd_padding2	= bd_asctl+1		; W reserved.


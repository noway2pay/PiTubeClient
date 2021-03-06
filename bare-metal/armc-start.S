
//  Part of the Raspberry-Pi Bare Metal Tutorials
//  Copyright (c) 2013-2015, Brian Sidebotham
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  1. Redistributions of source code must retain the above copyright notice,
//      this list of conditions and the following disclaimer.
//
//  2. Redistributions in binary form must reproduce the above copyright notice,
//      this list of conditions and the following disclaimer in the
//      documentation and/or other materials provided with the distribution.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.

//  Relocate to just below 32MB

.equ    RELOCATE_TO,      0x01F00000
#ifdef RPI2
.equ    RELOCATE_FROM,    0x00000000
#else
.equ    RELOCATE_FROM,    0x00008000
#endif
.equ    RELOCATE_LENGTH,  0x00100000

.equ    SVR_STACK,        0x01F00000
.equ    IRQ_STACK,        0x01EF0000
.equ    USER_STACK,       0x01EE0000
.equ    ABORT_STACK,      0x01ED0000
.equ    UNDEFINED_STACK,  0x01EC0000

.equ    SCTLR_ENABLE_DATA_CACHE,        0x4
.equ    SCTLR_ENABLE_BRANCH_PREDICTION, 0x800
.equ    SCTLR_ENABLE_INSTRUCTION_CACHE, 0x1000

.section ".text.startup"

.global _start
.global _get_cpsr
.global _get_stack_pointer
.global _exception_table
.global _enable_interrupts
.global _disable_interrupts
.global _user_exec
.global _error_handler_wrapper
.global _escape_handler_wrapper
.global _exit_handler_wrapper
.global _get_cpsr
.global _enable_unaligned_access
.global _enable_l1_cache
        
// From the ARM ARM (Architecture Reference Manual). Make sure you get the
// ARMv5 documentation which includes the ARMv6 documentation which is the
// correct processor type for the Broadcom BCM2835. The ARMv6-M manuals
// available on the ARM website are for Cortex-M parts only and are very
// different.
//
// See ARM section A2.2 (Processor Modes)

.equ    CPSR_MODE_USER,         0x10
.equ    CPSR_MODE_FIQ,          0x11
.equ    CPSR_MODE_IRQ,          0x12
.equ    CPSR_MODE_SVR,          0x13
.equ    CPSR_MODE_ABORT,        0x17
.equ    CPSR_MODE_HYP,          0x1A
.equ    CPSR_MODE_UNDEFINED,    0x1B
.equ    CPSR_MODE_SYSTEM,       0x1F

.equ    CPSR_MODE_MASK,         0x1F

// See ARM section A2.5 (Program status registers)
.equ    CPSR_A_BIT,             0x100
.equ    CPSR_IRQ_INHIBIT,       0x80
.equ    CPSR_FIQ_INHIBIT,       0x40
.equ    CPSR_THUMB,             0x20

_start:
    ldr pc, _reset_h
    ldr pc, _undefined_instruction_vector_h
    ldr pc, _software_interrupt_vector_h
    ldr pc, _prefetch_abort_vector_h
    ldr pc, _data_abort_vector_h
    ldr pc, _unused_handler_h
    ldr pc, _interrupt_vector_h
    ldr pc, _fast_interrupt_vector_h

_reset_h:                           .word   _copy_to_high_memory - RELOCATE_TO + RELOCATE_FROM
_undefined_instruction_vector_h:    .word   _undefined_instruction_handler_
_software_interrupt_vector_h:       .word   _swi_handler_
_prefetch_abort_vector_h:           .word   _prefetch_abort_handler_
_data_abort_vector_h:               .word   _data_abort_handler_
_unused_handler_h:                  .word   _reset_
_interrupt_vector_h:                .word   interrupt_vector
_fast_interrupt_vector_h:           .word   fast_interrupt_vector

_irq_stack:                         .word   IRQ_STACK
_svr_stack:                         .word   SVR_STACK
_user_stack:                        .word   USER_STACK
_undefined_stack:                   .word   UNDEFINED_STACK
_abort_stack:                       .word   ABORT_STACK

_patch_data:                        .word _reset_
_patch_address:                     .word _reset_h

_copy_to_high_memory:
    // We need to copy ourself to high memory
    mov     r0, #RELOCATE_FROM
    mov     r1, #RELOCATE_TO
    mov     r2, #RELOCATE_LENGTH
_copy_loop:
    // copy 16 bytes
    ldmia   r0!,{r3, r4, r5, r6}
    stmia   r1!,{r3, r4, r5, r6}
    subs    r2, r2, #16
    bge     _copy_loop
    // patch the reset vector to bypass the copy code
    ldr     r0, _patch_data
    ldr     r1, _patch_address
    str     r0, [r1]
    // jump to high memory
    mov     pc, r0

    // execution resumes here in high memory
_reset_:

    // On a Raspberry Pi 2 we enter in HYP mode, and need to force a switch to supervisor mode
    // This should be safe on a older Pi
#ifdef RPI2
    // Test which core we are running on
    mrc     p15, 0, r0, c0, c0, 5
    ands    r0, #3
    // Put cores 1-3 into a tight loop
    bne     _core_loop

    mrs     r0, cpsr
    eor     r0, r0, #CPSR_MODE_HYP
    tst     r0, #CPSR_MODE_MASK
    bic     r0 , r0 , #CPSR_MODE_MASK
    orr     r0 , r0 , #CPSR_IRQ_INHIBIT | CPSR_FIQ_INHIBIT | CPSR_MODE_SVR
    bne     _not_in_hyp_mode
    orr     r0, r0, #CPSR_A_BIT
    adr     lr, _reset_continue
    msr     spsr_cxsf, r0
    .word 0xE12EF30E  // msr_elr_hyp lr
    .word 0xE160006E  // eret
_core_loop:
    b       _core_loop    
_not_in_hyp_mode:
    msr    cpsr_c, r0
_reset_continue:
#endif
        
        
    // We enter execution in supervisor mode. For more information on
    // processor modes see ARM Section A2.2 (Processor Modes)

    mov     r0, #RELOCATE_TO
    mov     r1, #0x00000000
    ldmia   r0!,{r2, r3, r4, r5, r6, r7, r8, r9}
    stmia   r1!,{r2, r3, r4, r5, r6, r7, r8, r9}
    ldmia   r0!,{r2, r3, r4, r5, r6, r7, r8, r9}
    stmia   r1!,{r2, r3, r4, r5, r6, r7, r8, r9}

    // Initialise Stack Pointers ---------------------------------------------

    // We're going to use interrupt mode, so setup the interrupt mode
    // stack pointer which differs to the application stack pointer:
    mov r0, #(CPSR_MODE_IRQ | CPSR_IRQ_INHIBIT | CPSR_FIQ_INHIBIT )
    msr cpsr_c, r0
    ldr sp, _irq_stack

    // Also setup the stack used for undefined exceptions
    mov r0, #(CPSR_MODE_UNDEFINED | CPSR_IRQ_INHIBIT | CPSR_FIQ_INHIBIT )
    msr cpsr_c, r0
    ldr sp, _undefined_stack


    // Also setup the stack used for prefetch and data abort exceptions
    mov r0, #(CPSR_MODE_ABORT | CPSR_IRQ_INHIBIT | CPSR_FIQ_INHIBIT )
    msr cpsr_c, r0
    ldr sp, _abort_stack

    // Finally, a user/system mode stack, although the application will likely reset this
    mov r0, #(CPSR_MODE_SYSTEM | CPSR_IRQ_INHIBIT | CPSR_FIQ_INHIBIT )
    msr cpsr_c, r0
    ldr sp, _user_stack

    // Switch back to supervisor mode (our application mode) and
    // set the stack pointer. Remember that the stack works its way
    // down memory, our heap will work it's way up from after the
    // application.
    mov r0, #(CPSR_MODE_SVR | CPSR_IRQ_INHIBIT | CPSR_FIQ_INHIBIT )
    msr cpsr_c, r0
    ldr sp, _svr_stack

    // Enable VFP ------------------------------------------------------------

#ifdef RPI2
    //1. Set the CPACR for access to CP10 and CP11, and clear the ASEDIS and D32DIS bits:
    ldr     r0, =(0xf << 20)
    mcr     p15, 0, r0, c1, c0, 2

    // 2. Set the FPEXC EN bit to enable the NEON MPE:
    mov     r0, #0x40000000 
    vmsr    fpexc, r0
        
#else   
    // r1 = Access Control Register
    MRC p15, #0, r1, c1, c0, #2
    // enable full access for p10,11
    ORR r1, r1, #(0xf << 20)
    // ccess Control Register = r1
    MCR p15, #0, r1, c1, c0, #2
    MOV r1, #0
    // flush prefetch buffer because of FMXR below
    MCR p15, #0, r1, c7, c5, #4
    // and CP 10 & 11 were only just enabled
    // Enable VFP itself
    MOV r0,#0x40000000
    // FPEXC = r0
    FMXR FPEXC, r0
#endif
        
    // The c-startup function which we never return from. This function will
    // initialise the ro data section (most things that have the const
    // declaration) and initialise the bss section variables to 0 (generally
    // known as automatics). It'll then call main, which should never return.
    bl      _cstartup

    // If main does return for some reason, just catch it and stay here.
_inf_loop:
    b       _inf_loop


_get_stack_pointer:
    mov     r0, sp
    mov     pc, lr

_get_cpsr:
    mrs     r0, cpsr
    mov     pc, lr

_enable_interrupts:
    mrs     r0, cpsr
    bic     r0, r0, #CPSR_IRQ_INHIBIT
    msr     cpsr_c, r0
    mov     pc, lr

_disable_interrupts:
    mrs     r0, cpsr
    orr     r0, r0, #CPSR_IRQ_INHIBIT
    msr     cpsr_c, r0
    mov     pc, lr

_undefined_instruction_handler_:
    stmfd    sp!, {r0-r12, lr}
    mrs      r0, spsr             // Get spsr.
    stmfd    sp!, {r0}            // Store spsr onto stack.
    mov      r0, sp
    bl       undefined_instruction_handler

_prefetch_abort_handler_:
    stmfd    sp!, {r0-r12, lr}
    mrs      r0, spsr             // Get spsr.
    stmfd    sp!, {r0}            // Store spsr onto stack.
    mov      r0, sp
    bl       prefetch_abort_handler

_data_abort_handler_:
    stmfd    sp!, {r0-r12, lr}
    mrs      r0, spsr             // Get spsr.
    stmfd    sp!, {r0}            // Store spsr onto stack.
    mov      r0, sp
    bl       data_abort_handler

_swi_handler_:
    stmfd    sp!, {r0-r11,r12,lr} // Store registers.
    mov      r1, sp               // Set pointer to parameters.
    mrs      r0, spsr             // Get spsr.
    stmfd    sp!, {r0,r3}         // Store spsr onto stack and another register to maintain
                                  // 8-byte-aligned stack. This is only really needed in case of
                                  // nested SVCs.
    ldr      r0, [lr, #-4]        // Calculate address of SWI instruction and load it into r0.
    bic      r0, r0, #0xFF000000  // Mask off top 8 bits of instruction to give SWI number.
                                  // r0 now contains SWI number
                                  // r1 now contains pointer to stacked registers
    bl       C_SWI_Handler        // Call C routine to handle the SWI.
    ldmfd    sp!, {r0,r3}         // Get spsr from stack.
    msr      spsr_cf, r0          // Restore spsr.
    ldmfd    sp!, {r0-r11,r12,pc}^// Restore registers and return.

_user_exec:

    // This must only be called from supervisor mode....
        
    stmfd    sp!, {r0-r5, lr}     // r0 contains address of the code to execute in user mode
                                  // r1..r3 contain parameters, r4 is a scratch register
                                  // r5 is pushed to maintain 8 byte stack alignment

    mov      r4, r0               // Save r0 into the scratch register
        
    mrs      r0, spsr             // Get spsr    
    stmfd    sp!, {r0}            // Save spsr, as this (and lr) will be corrupted by nested swis

    mov      r0, #0                  // New code may have just been written to memory, so
    mcr      p15, 0, r0, c7, c10, 0  // Clean entire data cache
        
    mrs      r0, cpsr
    bic      r0, r0, #0x1f
    orr      r0, r0, #CPSR_MODE_USER
    msr      cpsr_c, r0           // Change to user mode

    mov      r0, r1               // Copy the params
    mov      r1, r2
    mov      r2, r3
        
    blx      r4                   // Call the address of the user program        
                                  // On return, the exit code is now in R0
    
    svc      0x000016             // Change back to supervisor mode (OS_EnterOS)

    str      r0, [sp, #4]         // Save the exit code so it will end up back in r0
        
    ldmfd    sp!, {r0}            // Get spsr from stack.
    msr      spsr_c, r0           // Restore spsr.
        
    ldmfd    sp!, {r0-r5, pc}     // Restore registers and return.
        
        
    // Called with the error buffer ppointer in R0 and the error handler address in R1
_error_handler_wrapper:

    // Move to user mode
    mov      r4, #(CPSR_MODE_USER | CPSR_FIQ_INHIBIT )
    msr      cpsr_c, r4

    // Continue execution of the error handler
    mov      pc, r1

    // Called with the escape flag value in R0 and the escape handler address in R1
_escape_handler_wrapper:

    // Preserve the registers the escape handler will use
    stmfd    sp!, {r11-r12, lr}

    // Move the escape flag into R11
    mov      r11, r0

    // Call the escape handler
    blx      r1

    // Restore stacked resisters and return
    ldmfd    sp!, {r11-r12, lr}
    mov      pc, lr

    // Called with the R12 value in R0 and the exit handler address in R1
_exit_handler_wrapper:

    // Move the "R12 value" into R12
    mov      r12, r0

    // Move to user mode
    mov      r4, #(CPSR_MODE_USER | CPSR_FIQ_INHIBIT )
    msr      cpsr_c, r4

    // Continue execution of the exit handler
    mov      pc, r1
        
_enable_unaligned_access:

    mrc      p15, 0, r0, c1, c0, 0   // read SCTLR
    bic      r0, r0, #2              // A (no unaligned access fault)
    orr      r0, r0, #1 << 22        // U (v6 unaligned access model)
    mcr      p15, 0, r0, c1, c0, 0   // write SCTLR
    mov      pc, lr
        
    // Enable L1 Cache -------------------------------------------------------

_enable_l1_cache:
        
    // R0 = System Control Register
    mrc p15,0,r0,c1,c0,0

    // Enable caches and branch prediction
    orr r0,#SCTLR_ENABLE_BRANCH_PREDICTION
    orr r0,#SCTLR_ENABLE_DATA_CACHE
    orr r0,#SCTLR_ENABLE_INSTRUCTION_CACHE

    // System Control Register = R0
    mcr p15,0,r0,c1,c0,0

    mov      pc, lr
        

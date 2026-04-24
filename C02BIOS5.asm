;**************************************************************************************************
;*    C02BIOS 5.1 - Release version for Pocket SBC  (c)2013-2025 by Kevin E. Maier 04/04/2026     *
;*                                                                                                *
;* BIOS Version 5.1 supports the following 3.3V hardware specification:                           *
;*                                                                                                *
;*  - W65C02S with clock rate up to 8.0 MHz                                                       *
;*  - AS6C1008 128KB Static RAM mapped to 60KB or 62KB                                            *
;*  - SST39LF-010 128KB Flash ROM mapped to 2KB or 4KB                                            *
;*  - ATF1504ASV Single Glue Logic                                                                *
;*  - NXP SC28L92 DUART for Console Port / Aux Serial Port / Timer                                *
;*  - MicroDrive IDE PATA interface with 16-bit data port                                         *
;*  - DS1318 Realtime Clock - 32-bit binary Epoch time                                            *
;*  - TL7533 Reset Circuit (positive & negative Reset signals)                                    *
;*  - TL7533 Reset Circuit (positive & negative NMI/Panic signals)                                *
;*                                                                                                *
;* Hardware map is flexible via Glue logic                                                        *
;*  - SC28L92 DUART mapped to $FE00 - $FE0F (16 bytes)                                            *
;*  - $FE10 - $FE1F is currently unmapped                                                         *
;*  - DS1318 RTC mapped to $FE20 - $FE1F (16 bytes)                                               *
;*  - IDE Controller and 16-bit data port mapped to $FE30 - $FE3F (16 bytes)                      *
;*                                                                                                *
;* BIOS Functions are divided into groups as follows:                                             *
;*                                                                                                *
;* SC28L92 DUART functions:                                                                       *
;* - Full duplex interrupt-driven/buffered I/O for both DUART Channels                            *
;* - Precision timer services with 10ms accuracy                                                  *
;* - RTC based Jiffy Clock, 32-bit count of seconds (EPOCH time)                                  *
;* - Accurate delays from 10ms to ~46 hours                                                       *
;* - 10ms Benchmark Timing to 65535.99 seconds                                                    *
;*                                                                                                *
;* IDE Controller Functions supporting PATA 16-bit Data Transfers:                                *
;* - Uses Logical Block Addressing (LBA) Mode only                                                *
;* - Multiple Block transfers are supported for Read/Write Block commands                         *
;* - Reset IDE (recalibrate command)                                                              *
;* - Get IDE Status and Extended Error codes                                                      *
;* - Get IDE Identification Block                                                                 *
;* - Read a Block from IDE device                                                                 *
;* - Write a Block to IDE device                                                                  *
;* - Set the LBA Block ID for Read/Write                                                          *
;* - Set the Memory Address to transfer Block data to/from                                        *
;* - Enable/Disable the Write Cache on IDE controller                                             *
;*                                                                                                *
;* Maxim DS1318 Realtime Clock functions:                                                         *
;* - Detect RTC and Load software RTC variables                                                   *
;*                                                                                                *
;* BIOS Features:                                                                                 *
;* - Extendable BIOS structure with soft vectors                                                  *
;* - Soft config parameters for I/O devices                                                       *
;* - Monitor cold/warm start soft vectored now optional                                           *
;* - Panic Routine to restore Vectors and Reinitialize Console only                               *
;* - Bootable default from IDE controller LBA 0                                                   *
;* - Fully relocatable code (sans page $FF)                                                       *
;* - JUMP Table at $FF00 - 32 functions                                                           *
;* - Default memory allocation of 2KB (includes 64 bytes of I/O mapping)                          *
;**************************************************************************************************
        PL      66      ;Page Length
        PW      132     ;Page Width (# of char/line)
        CHIP    W65C02S ;Enable WDC 65C02 instructions
        PASS1   OFF     ;Set ON when used for debug
        INCLIST ON      ;Set ON for listing Include files
;**************************************************************************************************
;C02BIOS Version 5.x is "loosely" based on C02BIOS Version 4.02.
;
; - Main changes are to support minimal ROM usage and add IDE Boot capability.
; - Include Bencharking routines into BIOS.
; - Provide DOS/65 Boot and usage without C02 Monitor code.
; - Provide an additional 6KB of RAM space for DOS/65 TEA (removal of C02Monitor).
; - Remove IDE LBA Verify routine (not used for DOS/65).
; - Remove RTC NVRAM block read/write (DS1318 has no such NVRAM - replaces DS15x1).
; - Add support for DS1318 RTC as 32-bit EPOCH time in 1-second increments.
;
; - Changes to Page Zero to condense usage for IDE Bootable BIOS (includes DOS/65 usage).
; - Restructure BIOS Jump table for new hardware config (calls are different from 4.x releases).
;
;**************************************************************************************************
;This BIOS uses a single source file for constants and variables.
;
        INCLUDE         C02Constants5.asm
;
;**************************************************************************************************
;Monitor JUMP table: 32 JUMP calls are Defined, only two shown here are required.
; Note: Monitor entry points are currently for debugging purposes.
; - once the BIOS and Bootable hardware and software is completed, these will be changed.
;
M_COLD_MON      .EQU    $F000           ;Call 00        Monitor Cold Start
M_WARM_MON      .EQU    $F003           ;Call 01        Monitor Warm Start
;
;**************************************************************************************************
        .ORG    $F800   ;2KB reserved for BIOS, I/O device selects (48 bytes)                     *
;**************************************************************************************************
;                                    START OF BIOS CODE                                           *
;**************************************************************************************************
;C02BIOS version used here is 5.1 (new release with IDE bootable support)
;
; Contains the base BIOS routines in top 2KB of Flash ROM
; - $F800 - $FDFF Core BIOS routines (1536 bytes)
; - $FE00 - $FE3F reserved for hardware devices (64 bytes)
; - $FE40 - $FEFF used for Vector and Hardware configuration and text data (192 bytes)
; - $FF00 - $FFFF JMP table, startup, NMI/BRK/IRQ pre-post routines, init, BIOS msg (256 bytes)
;
; UPDATES:
; NOTE: Version 5.x BIOS changes include:
; - Vector and Config Data moved to Page $02
; - Console I/O buffer moved to Page $03
; - Second Serial port buffer moved to Page $04
; - Page $05 reserved for future expansion/changes
; - Disk LBA buffer is at Pages $06 - $07
;
; - Update to Version 5.1
; - Changes to the IDE BIOS to perform a Software Reset for the Reset_IDE call.
; - Changes to the Cold Start to provide a timeout to either Boot from the IDE device or jump to
; - the Monitor Cold Start vector.
;**************************************************************************************************
; The following 32 functions are provided by BIOS via the JMP Table
;
; $FF00 IDE_RESET       ;Reset IDE Controller (Recalibrate Command)
; $FF03 IDE_GET_STAT    ;Get Status and Error code
; $FF06 IDE_IDENTIFY    ;Load IDE Identity Data to LBA Buffer
; $FF09 IDE_READ_LBA    ;Read LBA into memory
; $FF0C IDE_WRITE_LBA   ;Write LBA from memory
; $FF0F IDE_SET_LBA     ;Set LBA number (24-bit support only)
; $FF12 IDE_SET_ADDR    ;Set LBA transfer address (16-bit plus block count)
; $FF15 IDE_EN_CACHE    ;Enable/Disable IDE Write Cache
;
; $FF18 CHR_STAT        ;Check Console Status
; $FF1B CHRIN_NW        ;Data input from console (no waiting, clear carry if none)
; $FF1E CHRIN           ;Data input from console
; $FF21 CHROUT          ;Data output to console
;
; $FF24 CHRIN2          ;Data input from aux port
; $FF27 CHROUT2         ;Data output to aux port
;
; $FF2A CNT_INIT        ;Reset Benchmark timing counters
; $FF2D CNT_STRT        ;Start 10ms Benchmark timing counter
; $FF30 CNT_STOP        ;Stop 10ms Benchmark timing counter
; $FF33 CNT_DISP        ;Display Benchmark counter timing
;
; $FF36 SET_DLY         ;Set delay value for milliseconds and 16-bit counter
; $FF39 EXE_MSDLY       ;Execute millisecond delay 1-256 * 10 milliseconds
; $FF3C EXE_LGDLY       ;Execute long delay; millisecond delay * 16-bit count
;
; $FF3F PROMPTR         ;Print string to console
;
; $FF42 RTC_INIT        ;Initialize software RTC from DS1318 hardware RTC
;
; $FF45 PRSTAT          ;Display CPU registers to console
;
; $FF48 Reserved        ;Reserved for future expansion
;
; $FF4B INIT_VEC        ;Initialize soft vectors at $0200 from ROM
; $FF4E INIT_CFG        ;Initialize soft config data at $0220 from ROM
;
; $FF51 INIT_28L92      ;Initialize SC28L92 - Port A as console at 115.2K, 8-N-1 RTS/CTS
; $FF54 RESET_28L92     ;Reset SC28L92 - called before INIT_28L92
;
; $FF57 PANIC           ;Execute PANIC routine (disables IDE controller)
; $FF5A BOOT_IDE        ;Boot IDE device - load LBA 0 to $0800 and jump to it
;
; $FF5D COLDSTRT        ;System cold start - RESET vector for W65C02S
;**************************************************************************************************
;                    Data In and Out routines for Console I/O buffer                              *
;**************************************************************************************************
;Data Input Port A routine:
;
; CHR_STAT checks to see if the input buffer has any characters and returns with the buffer count
; in the A Reg. Any value from $00 - $7F is valid.
;
; CHRIN_NW uses CHRIN, returns if data is not available from the buffer with carry flag clear,
; - else returns with data in A reg and carry flag set.
;
; CHRIN waits for data to be in the receive buffer, then returns with data in A reg.
; Receive is IRQ driven/buffered with a size of 128 bytes.
;
CHR_STAT        LDA     ICNT_A          ;Get Buffer Count (4)
                RTS                     ;Return to caller (6)
;
CHRIN_NW        CLC                     ;Clear Carry flag for no data (2)
                LDA     ICNT_A          ;Get buffer count (4)
                BNE     GET_CH          ;Branch if buffer is not empty (2/3)
                RTS                     ;Or return to caller (6)
;
CHRIN           LDA     ICNT_A          ;Get data count (3)
                BEQ     CHRIN           ;If zero (no data, loop back) (2/3)
;
GET_CH          PHY                     ;Save Y Reg (3)
                LDY     IHEAD_A         ;Get the buffer head pointer (3)
                LDA     IBUF_A,Y        ;Get the data from the buffer (4)
                INC     IHEAD_A         ;Increment head pointer (5)
                RMB7    IHEAD_A         ;Strip off bit 7, 128 bytes only (5)
                DEC     ICNT_A          ;Decrement the buffer count (5)
;
                PLY                     ;Restore Y Reg (4)
                SEC                     ;Set Carry flag for data available (2)
                RTS                     ;Return to caller with data in A Reg (6)
;
;Data Output Port A routine:
; CHROUT puts the data in the A Reg into the xmit buffer, data in A Reg is preserved on exit.
; Transmit is IRQ driven/buffered with a size of 128 bytes.
;
CHROUT          PHY                     ;Save Y Reg (3)
OUTCH           LDY     OCNT_A          ;Get data output count in buffer (3)
                BMI     OUTCH           ;Check against limit, loop back if full (2/3)
;
                LDY     OTAIL_A         ;Get the buffer tail pointer (3)
                STA     OBUF_A,Y        ;Place data in the buffer (5)
                INC     OTAIL_A         ;Increment Tail pointer (5)
                RMB7    OTAIL_A         ;Strip off bit 7, 128 bytes only (5)
                INC     OCNT_A          ;Increment data count (5)
;
                LDY     #%00000100      ;Get mask for xmit on (2)
                STY     UART_COMMAND_A  ;Turn on xmit (4)
;
                PLY                     ;Restore Y Reg (4)
                RTS                     ;Return to caller (6)
;
;Data Input Port B routine:
; CHRIN2 waits for data to be in the receive buffer, then returns with data in A reg.
; Receive is IRQ driven/buffered with a size of 128 bytes.
;
CHRIN2          LDA     ICNT_B          ;Get data count (3)
                BEQ     CHRIN2          ;If zero (no data, loop back) (2/3)
;
                PHY                     ;Save Y Reg (3)
                LDY     IHEAD_A         ;Get the buffer head pointer (3)
                LDA     IBUF_B,Y        ;Get the data from the buffer (4)
                INC     IHEAD_B         ;Increment head pointer (5)
                RMB7    IHEAD_B         ;Strip off bit 7, 128 bytes only (5)
                DEC     ICNT_B          ;Decrement the buffer count (5)
;
                PLY                     ;Restore Y Reg (4)
                RTS                     ;Return to caller with data in A Reg (6)
;
;Data Output Port B routine:
; CHROUT2 puts the data in the A Reg into the xmit buffer, data in A Reg is preserved on exit.
; Transmit is IRQ driven/buffered with a size of 128 bytes.
;
CHROUT2         PHY                     ;Save Y Reg (3)
OUTCH2          LDY     OCNT_B          ;Get data output count in buffer (3)
                BMI     OUTCH2          ;Check against limit, loop back if full (2/3)
;
                LDY     OTAIL_B         ;Get the buffer tail pointer (3)
                STA     OBUF_B,Y        ;Place data in the buffer (5)
                INC     OTAIL_B         ;Increment Tail pointer (5)
                RMB7    OTAIL_B         ;Strip off bit 7, 128 bytes only (5)
                INC     OCNT_B          ;Increment data count (5)
;
                LDY     #%00000100      ;Get mask for xmit on (2)
                STY     UART_COMMAND_B  ;Turn on xmit (4)
;
                PLY                     ;Restore Y Reg (4)
                RTS                     ;Return to caller (6)
;
;**************************************************************************************************
;START of IDE Data Transfer Routines for Hitachi 3K8 MicroDrive
; These routines requires loading the requested LBA into the appropriate registers and
; issuing the READ or WRITE command. The LBA limit supported for the BIOS are bits 0-23,
; so bits 24-27 are always set to 0. This provides access to IDE devices up to 8GB.
;
; Once the registers/parameters are setup, the Read or Write Block command is issued.
; This results in an interrupt being generated. The ISR handles the transfer of LBA
; data from the IDE Drive to memory. Write operations move data from memory to IDE Drive here,
; but uses an interrupt to finalize the transfer.
;
; The registers used are the same for read/write. These are:
;
;       IDE_COMMAND = function requested (20h = READ LBA command - 30h = WRITE LBA command)
;       IDE_DRV_HEAD = (Upper 4 bits) used as:
;               bit 7 = 1 per Seagate documentation
;               bit 6 = 1 for LBA mode
;               bit 5 = 1 per Seagate documentation
;               bit 4 = 0 for Drive 0
;       IDE_DRV_HEAD = LBA Address bits 27-24 (lower 4 bits) - not used, always 0000
;       IDE_CYL_HIGH = LBA Address bits 23-16
;       IDE_CYL_LOW = LBA Address bits 15-8
;       IDE_SCT_NUM = LBA Address bits 7-0
;       IDE_SCT_CNT = number of blocks to read
;**************************************************************************************************
;
IDE_READ_LBA                            ;Read a Block of data from IDE device
;
                JSR     IDE_SET_PARMS   ;Setup required parameters (6)
                LDA     #$20            ;Get Read LBA command (2)
IDENT_READ                              ;Identify Command jumps here to complete
                SMB3    MATCH           ;Set Read LBA bit (5)
                STA     IDE_COMMAND     ;Send command to IDE Controller (4)
;
LBA_RD_CMD
                LDA     IDE_ALT_STATUS  ;Get IDE Alternate Status register (4)
                BMI     LBA_RD_CMD      ;Loop until IDE controller not Busy (2/3)
;
LBA_RD_WAIT
                LDA     IDE_ALT_STATUS  ;Get IDE Alternate Status register (4)
                CMP     #$50            ;Compare for ready (2)
                BNE     LBA_RD_ERR      ;If not, check for error condition (2/3)
LBA_RD_OK
                BBS3    MATCH,LBA_RD_OK ;Wait for Read completed via ISR (5/6,7)
                RTS                     ;Return to caller (status in A Reg) (6)
LBA_RD_ERR
                LSR     A               ;Shift error bit to carry (2)
                BCC     LBA_RD_WAIT     ;If clear, loop back and continue waiting (2/3)
;
                RMB3    MATCH           ;Reset Read LBA bit (no ISR invoked) (5)
IDE_RWV_FIN
                LDA     IDE_ALT_STATUS  ;Get IDE Alternate Status register (4)
                STA     IDE_STATUS_RAM  ;Update RAM Status Register (3)
                RTS                     ;Return to caller (6)
;**************************************************************************************************
;
IDE_WRITE_LBA                           ;Write a block of data to LBA
;
                JSR     IDE_SET_PARMS   ;Setup required parameters (6)
;
                SMB2    MATCH           ;Set Write LBA bit (5)
                LDA     #$30            ;Get Write LBA command (2)
                STA     IDE_COMMAND     ;Send command to IDE Controller (4)
LBA_WR_CMD
                LDA     IDE_ALT_STATUS  ;Get IDE Alternate Status register (4)
                BMI     LBA_WR_CMD      ;Loop until IDE controller not Busy (2/3)
                LSR     A               ;Shift Error bit into Carry flag (2)
                BCS     IDE_WRITE_ERR   ;If Carry set, IDE error (2/3)
;
; Write Block routine integrated into IDE_WRITE_LBA
; - High byte needs to be loaded into the latch before the
;   low byte is loaded into the Data Register!
;
IDE_WRITE_BLK                           ;Write a block of data
                PHY                     ;Save Y reg (3)
                LDY     #$01            ;Set offset for high byte latch (2)
;
IDE_WRITE_LOOP
                LDA     IDE_ALT_STATUS  ;Get IDE Alternate Status register (4)
                AND     #%00001000      ;Check for DRQ active (2)
                BEQ     IDE_WR_FIN      ;If not active, exit (below) (2/3)
IDE_WR_WBLK
                LDA     (BIOS_XFERL),Y  ;Get first byte of buffer+1 (5)
                STA     IDE_16_WRITE    ;Place into high byte latch (4)
                LDA     (BIOS_XFERL)    ;Get first byte of buffer (5)
                STA     IDE_DATA        ;Write buffer to IDE (writes a word) (4)
;
; - Buffer index needs to be incremented twice
;
                INC     BIOS_XFERL      ;Increment pointers once (5)
                BNE     IDE_WR_BLK1     ; (2/3)
                INC     BIOS_XFERH      ; (5)
IDE_WR_BLK1
                INC     BIOS_XFERL      ;Increment pointers again (5)
                BNE     IDE_WRITE_LOOP  ; (2/3)
                INC     BIOS_XFERH      ; (5)
                BRA     IDE_WRITE_LOOP  ;Loop back for 256 words (3)
;
IDE_WR_FIN
; When DRQ ends, 512 bytes have been sent to IDE controller. Controller then sets BUSY,
; when finished processing data, controller clears BUSY and generates an interrupt.
; So, we test for BUSY first and wait until the block is written.
;
                LDA     IDE_ALT_STATUS  ;Get IDE Alternate Status register (4)
                BMI     IDE_WR_FIN      ;Loop until BUSY bit is clear (2/3)
;
                DEC     BIOS_XFERC      ;Decrement Block Count to transfer (5)
                BNE     IDE_WRITE_LOOP  ;If not zero, branch back to write next LBA (2/3)
;
WR_WAIT
                BBS2    MATCH,WR_WAIT   ;Wait for Write completed via ISR (5/6,7)
                PLY                     ;Restore Y reg (4)
                RTS                     ;Return to caller (6)
IDE_WRITE_ERR
                RMB2    MATCH           ;Reset Write LBA bit (no ISR) (5)
                BRA     IDE_RWV_FIN     ;Branch and finish up (3)
;**************************************************************************************************
;
IDE_SET_ADDRESS                         ;Set Address for LBA (read/write)
;
;This routine uses the A,Y,X registers to setup the address in memory that a block
; will be read to or written from (16-bit address), along with the block count.
; The Register usage is as follows:
;       A Register = Memory address low byte
;       Y Register = Memory address high byte
;       X Register = Block count to transfer
                STA     LBA_ADDR_LOW    ;Set LBA low byte address (3)
                STY     LBA_ADDR_HIGH   ;Set LBA high byte address (3)
                STX     LBA_XFER_CNT    ;Set LBA Block count for xfer (3)
                RTS                     ;Return to caller (6)
;**************************************************************************************************
;
IDE_SET_LBA                             ;Set LBA block for transfer (read/write)
;
;This routine sets the variables used to select the starting LBA for transfer.
; The Register usage is as follows:
;       A Register = LBA Address bits 7-0
;       Y Register = LBA Address bits 15-8
;       X Register = LBA Address bits 23-16
                STA     LBA_LOW_BYTE    ;Store Address bits 0-7 (3)
                STY     LBA_HIGH_BYTE   ;Store Address bits 8-15 (3)
                STX     LBA_EXT_BYTE    ;Store Address bits 16-23 (3)
                RTS                     ;Return to caller (6)
;**************************************************************************************************
;
IDE_SET_PARMS                           ;Set All parameters for LBA transfers
;
;This routine sets the LBA number used for all transfers.
; The IDE Controller is checked first to ensure it's ready to receive parameters, then the
; the requested LBA (stored in Page Zero variables) are loaded into the IDE Controller registers,
; followed by the required Mode parameters. The transfer address is then setup which points to
; the memory location for the start of the data transfer.
;
                LDA     IDE_ALT_STATUS  ;Get IDE Alternate Status register (4)
                BMI     IDE_SET_PARMS   ;Loop until BUSY bit is clear (2/3)
;
; Transfer parameters from working memory to IDE drive
;
                LDA     LBA_EXT_BYTE    ;Set LBA bits 23-16 (3)
                STA     IDE_CYL_HIGH    ;Send to IDE (4)
                LDA     LBA_HIGH_BYTE   ;Set LBA bits 15-8 (3)
                STA     IDE_CYL_LOW     ;Send to IDE (4)
                LDA     LBA_LOW_BYTE    ;Get LBA bits 7-0 (3)
                STA     IDE_SCT_NUM     ;Send to IDE (4)
                LDA     LBA_XFER_CNT    ;Get Block count to read (3)
                STA     IDE_SCT_CNT     ;Send to IDE (4)
;
IDE_SET_PARMS2                          ;Set partial parameters (non LBA xfer commands)
;
                LDA     #%11100000      ;Set Drive 0, LBA mode, LBA bits 27-24 as 0 (2)
                STA     IDE_DRV_HEAD    ;Send to IDE controller (4)
;
                LDA     LBA_ADDR_LOW    ;Setup buffer address (3)
                STA     BIOS_XFERL      ;Store low byte (3)
                LDA     LBA_ADDR_HIGH   ;Block Buffer Address (3)
                STA     BIOS_XFERH      ;Store high byte (3)
                LDA     LBA_XFER_CNT    ;Get Block count to read (3)
                STA     BIOS_XFERC      ;Set BIOS Block count to Xfer (3)
                STZ     IDE_STATUS_RAM  ;Clear RAM Status Register, ISR updates it (3)
                RTS                     ;Return to caller (6)
;**************************************************************************************************
;
TST_IDE_RDY
;
;Test for IDE Controller Ready
;
;This routine tests that the IDE Controller is ready and can accept a command for execution.
; There are two bits in the status register to qualify this:
; Bit 6 is for Ready and bit 4 is for Seek Complete. Both should be active to qualify the
; drive as being ready (per Hitachi Microdrive documentation).
; Note: It's also possible that bit 0 might be set, which indicates an error condition.
; If an error has occurred, we should test for this and branch to handle the error condition.
;
                LDA     IDE_ALT_STATUS  ;Get IDE Alternate Status register (4)
                CMP     #$51            ;Test for Ready and Error bits on (2)
                BEQ     IDE_RD_ERR      ;If yes, branch to error routine (2/3)
                CMP     #$50            ;Test for Ready bits on (2)
                BNE     TST_IDE_RDY     ;If not, loop back until ready (2/3)
                RTS                     ;Return to Caller (6)
;**************************************************************************************************
;
IDE_BOOT
;
;IDE Controller Boot routine
;
;This routine sets up the IDE Controller to load the first logical block from the disk.
; This should be the partition record. Once loaded, the IDE controller is checked for any
; error condition, then the partition record data is checked for the proper signature.
; If the signature is correct, control is turned over to the partition record code,
; otherwise, the appropiate error message is displayed and the system is halted.
;
                BBR5    MATCH,IDE_NOT_FOUND     ;Check for Drive Present, branch if not (5/6)
;
                LDA     #$00            ;Load low byte LBA address (2)
                TAY                     ;Same for high LBA address (2)
                TAX                     ;Same for extended LBA address (2)
                JSR     IDE_SET_LBA     ;Call BIOS to setup LBA number (6)
;
                LDA     #<LBA_BUFFER    ;Set Address low byte (2)
                LDY     #>LBA_BUFFER    ;Set Address high byte (2)
                LDX     #$01            ;Set Block count to 1 (2)
                JSR     IDE_SET_ADDRESS ;Set Xfer address and block count (6)
;
                JSR     IDE_READ_LBA    ;Read Block Zero to Buffer (6)
                LDA     IDE_STATUS_RAM  ;Get Status from BIOS call (3)
                LSR     A               ;Shift error bit to carry (2)
                BCS     IDE_RD_ERR      ;Branch if error (2/3)
;
                LDX     #252            ;Get offset to signature (2)
                LDA     LBA_BUFFER,X    ;Get signature byte (4)
                CMP     #$02            ;Compare to $02 (2)
                BNE     BAD_PART_BLK    ;Branch if incorrect (2/3)
                INX                     ;Increment index to next signature byte (2)
                LDA     LBA_BUFFER,X    ;Get signature byte (4)
                CMP     #$65            ;Compare to $65 (2)
                BNE     BAD_PART_BLK    ;Branch if incorrect (2/3)
;
;Signature is good!
; Now see if the user prefers to boot from the IDE drive or jump to the ROM Monitor
;
USER_TIMEOUT
; Once the partition block is loaded and signature verified, a timeout os started to
; allow the user to jump into the Monitor code instead of default booting from the
; IDE drive. This is also a safety in case the Boot Record is either damaged or
; incorrectly configured as well as the boot image loaded by the Boot Record has any
; issues. A default 5 seconds timeout should be sufficient to allow the user to interrupt
; the boot process. The "ESC" key will be used to interrupt the boot and enter the Monitor.
;
                LDA     #100            ;Setup timer for 1 second on MS delay (2)
                LDX     #0              ;Setup timer for 0 multiplier (2)
                LDY     #0              ; (2)
                JSR     SET_DLY         ;Call routine to set values (6)
;
                LDA     #<BOOT_INT      ;Boot interrupt message (2)
                LDY     #>BOOT_INT      ; (2)
                JSR     PROMPTR         ;Send message to console (6)
;
                LDX     #05             ;Set index for a 5 second loop (2)
BOOT_LOOP
                LDA     #'.'            ;Get period character (2)
                JSR     CHROUT          ;Send to console (6)
                JSR     EXE_MSDLY       ;Execute 1 second delay (6)
                JSR     CHRIN_NW        ;Check for console input (no waiting) (6)
                BCS     CHK_INT         ;Input exists, check for ESC (2/3)
                DEX                     ;Decrement count (2)
                BNE     BOOT_LOOP       ;Branch back and continue timeout (2/3)
                JMP     LBA_BUFFER      ;We're done waiting, execute partition code (3)
CHK_INT
                CMP     #$1B            ;Check for ESC (2)
                BEQ     ABORT_BOOT      ;Branch to Monitor (2/3)
                DEX                     ;Decrement index count (2)
                BRA     BOOT_LOOP       ;Branch back and continue timeout (3)
        
ABORT_BOOT
                JSR     CROUT           ;Send CR/LF to console (6)
                JMP     M_COLD_MON      ;Jump to the ROM Monitor cold start vector(3)
BAD_PART_BLK
                LDA     #<BPART_MSG     ;Bad Partition message (2)
                LDY     #>BPART_MSG     ; (2)
                BRA     IDE_NO_BOOT     ;Send message, enter Monitor Cold Start (3)
IDE_RD_ERR
                LDA     #<DRIVE_MSG     ;Microdrive Error message (2)
                LDY     #>DRIVE_MSG     ; (2)
                BRA     IDE_NO_BOOT     ;Send message, enter Monitor Cold Start (3)
IDE_NOT_FOUND
                LDA     #<NO_DRIVE_MSG  ;No Microdrive Error message (2)
                LDY     #>NO_DRIVE_MSG  ; (2)
IDE_NO_BOOT     JSR     PROMPTR         ;Send Message to console (6)
                JMP     M_COLD_MON      ;Enter Monitor Cold Start (3)
;
;**************************************************************************************************
;Delay Routines: SET_DLY sets up the MSDELAY value and also sets the 16-bit Long Delay
; On entry, A Reg = 10-millisecond count, X Reg = High multiplier, Y Reg = Low multiplier
; these values are used by the EXE_MSDLY and EXE_LGDLY routines. Minimum delay is 10ms
; values for MSDELAY are $00-$FF ($00 = 256 times)
; values for Long Delay are $0000-$FFFF (0-65535 times MSDELAY)
; longest delay is 65,535*256*10ms = 16,776,960 * 0.01 = 167,769.60 seconds
;
;NOTE: All delay execution routines preserve registers (EXE_MSDLY, EXE_LGDLY)
;
SET_DLY         STA     SETMS           ;Save Millisecond count (3)
                STY     DELLO           ;Save Low multiplier (3)
                STX     DELHI           ;Save High multiplier (3)
                RTS                     ;Return to caller (6)
;
;EXE MSDELAY routine is the core delay routine. It sets the MSDELAY count value from the
; SETMS variable, enables the MATCH flag, then waits for the MATCH flag to clear.
;
EXE_MSDLY       PHA                     ;Save A Reg (3)
                SMB7    MATCH           ;Set MATCH flag bit (5)
                LDA     SETMS           ;Get delay seed value (3)
                STA     MSDELAY         ;Set MS delay value (3)
;
MATCH_LP        BBS7    MATCH,MATCH_LP  ;Test MATCH flag, loop until cleared (5/6,7)
                PLA                     ;Restore A Reg (4)
                RTS                     ;Return to caller (6)
;
;EXE LONG Delay routine is the 16-bit multiplier for the MSDELAY routine.
; It loads the 16-bit count from DELLO/DELHI, then loops the MSDELAY routine
; until the 16-bit count is decremented to zero.
;
EXE_LGDLY       PHX                     ;Save X Reg (3)
                PHY                     ;Save Y Reg (3)
                LDX     DELHI           ;Get high byte count (3)
                INX                     ;Increment by one (checks for $00 vs $FF) (2)
                LDY     DELLO           ;Get low byte count (3)
                BEQ     SKP_DLL         ;If zero, skip to high count (2/3)
DO_DLL          JSR     EXE_MSDLY       ;Call millisecond delay (6)
                DEY                     ;Decrement low count (2)
                BNE     DO_DLL          ;Branch back until done (2/3)
;
SKP_DLL         DEX                     ;Decrement high byte index (2)
                BNE     DO_DLL          ;Loop back to D0_DLL (will run 256 times) (2/3)
                PLY                     ;Restore Y Reg (4)
                PLX                     ;Restore X Reg (4)
                RTS                     ;Return to caller (6)
;
;**************************************************************************************************
;COUNTER BENCHMARK TIMING ROUTINES
; To enable some basic benchmarking, the following routines are part of C02BIOS version 5.x
;
; - CNT_INIT is used to zero the timing variables
; - CNT_STRT is used to start the timing by setting bit 6 of the MATCH flag
; - CNT_STOP is used to stop the timing by clearing bit 6 of the MATCH flag
; - CNT_DISP is used to display the benchmark counter output (also stops the timing)
;
; Using the existing 10ms Jiffy Clock, three bytes of Page zero are used to hold variables;
; - MS10_CNT - a 10ms count variable for 0.01 resolution of timing - resets at 100 counts (1 second)
; - SECL_CNT - a low byte seconds count
; - SECH_CNT - a high byte seconds count
; This provides up to 65,535.99 seconds of timing with 0.01 seconds resolution
; - NOTE: the count variables reset to zero after 65,535.99 seconds!
;
; The interrupt handler for the DUART timer increments the timing variables when bit 6 of the
; MATCH flag is active.
;
CNT_INIT        RMB6    MATCH           ;Clear bit 6 of MATCH flag, ensure timing is disabled (5)
                STZ     MS10_CNT        ;Zero 10ms timing count (3)
                STZ     SECL_CNT        ;Zero low byte of seconds timing count (3)
                STZ     SECH_CNT        ;Zero high byte of seconds timing count (3)
                RTS                     ;Return to caller (6)
;
CNT_STRT        SMB6    MATCH           ;Set bit 6 of MATCH flag to enable timing (5)
                RTS                     ;Return to caller (6)
;
CNT_STOP        RMB6    MATCH           ;Clear bit 6 of MATCH flag to disable timing (5)
                RTS                     ;Return to caller (6)
;
;Display Benchmark timer:
; Benchmark timer is stopped by clearing bit 6 of MATCH flag. Once the Benchmark counter is
; stopped, the HEX2ASC routine prints the 16-bit seconds count, followed by a period,
; then the HEX8ASC routine prints the hundreds count followed by the "Seconds" message.
;
CNT_DISP        RMB6    MATCH           ;Stop Benchmark Counter (5)
                LDA     SECL_CNT        ;Get seconds low count (3)
                LDY     SECH_CNT        ;Get seconds high count (3)
                JSR     HEX2ASC         ;Print 16-bit decimal value (6)
;
                LDA     #"."            ;Get period character (2)
                JSR     CHROUT          ;Send "." to console (6)
                LDA     MS10_CNT        ;Get hundreds of seconds (3)
;
; Drop into HEX8ASC
;
;HEX8ASC - Accepts 8-bit Hexadecimal value (00-99 decimal) and converts to ASCII numeric values.
; A Register contains the single byte value on entry and outputs the two ASCII numeric values.
; leading zero is output as it is used for showing hundredths of a second after a decimal point.
HEX8ASC         LDY     #$FF            ;Load Y Reg with "-1" (2)
                SEC                     ;Set carry for subtraction (2)
HEX8LP1         INY                     ;Increment 10's count (starts at zero) (2)
                SBC     #10             ;Subtract 10 decimal (2)
                BCS     HEX8LP1         ;Branch back if >10 (2/3)
                ADC     #$3A            ;Add the last 10 back plus $30 (ASCII "0") (2)
                PHA                     ;Save 1's count to the Stack (3)
                TYA                     ;Get the 10's count (2)
                CLC                     ;Clear carry for add (2)
                ADC     #$30            ;Add $30 for ASCII digit (3)
                JSR     CHROUT          ;Print the first digit (10's)
                PLA                     ;Get 1's count from the Stack (4)
                JSR     CHROUT          ;Print the second digit, return (6)
;
                LDA     #<MSG_SEC       ;Get message for " Seconds" (2)
                LDY     #>MSG_SEC       ; (2)
PRMPT_SC        BRA     PROMPTR         ;Send to console, return (3)
;
;HEX2ASC - Accepts 16-bit Hexadecimal value and converts to an ASCII decimal string. Input is
; via the A and Y Registers and output is up to 5 ASCII digits in DATABUFF. The High Byte is in
; the Y Register and Low Byte is in the A Register. Output data is placed in variable DATABUFF
; and terminated with a null character.
; Note: leading zeros are suppressed. PROMPTR routine is used to print the ASCII decimal value.
; Core routine based on Michael Barry's code. Saves many bytes with two updates/changes ;-)
HEX2ASC         STA     BINVALL         ;Save Low byte (3)
                STY     BINVALH         ;Save High byte (3)
                LDX     #5              ;Get ASCII buffer offset (2)
                STZ     DATABUFF,X      ;Zero last buffer byte for null end (4)
;
CNVERT          LDA     #$00            ;Clear remainder (2)
                LDY     #16             ;Set loop count for 16-bits (2)
;
DVLOOP          CMP     #$05            ;Partial remainder >= 10/2 (2)
                BCC     DVLOOP2         ;Branch if less (2/3)
                SBC     #$05            ;Update partial (carry set) (2)
;
DVLOOP2         ROL     BINVALL         ;Shift carry into dividend (4)
                ROL     BINVALH         ;Which will be quotient (4)
                ROL     A               ;Rotate A Reg (3)
                DEY                     ;Decrement count (2)
                BNE     DVLOOP          ;Branch back until done (2/3)
                ORA     #$30            ;OR in $30 for ASCII (2)
;
                DEX                     ;Decrement buffer offset (2)
                STA     DATABUFF,X      ;Store digit into buffer (3)
;
                LDA     BINVALL         ;Get the Low byte (3)
                ORA     BINVALH         ;OR in the High byte (check for zero) (3)
                BNE     CNVERT          ;Branch back until done (2/3)
;
;Conversion is complete, get the string address, add offset, then call prompt routine and return
; note: DATABUFF is fixed location in Page 0, carry flag need not be cleared as result can never
; set flag after ADC instruction.
                TXA                     ;Get buffer offset (2)
                ADC     #<DATABUFF      ;Add Low byte address (2)
                LDY     #>DATABUFF      ;Get High byte address (2)
;
;Drop into Prompt routine to print the 16-bit seconds count to console
;
;PROMPTR routine: takes message address in Y/A and prints via PROMPT2 routine
PROMPTR         STA     STRINGL         ;Store low byte (3)
                STY     STRINGH         ;Store high byte (3)
;
;PROMPT2 routine: prints message at address (PROMPTL) till null character found
PROMPT2         LDA     (STRINGL)       ;Get string data (5)
                BEQ     PR_EXIT         ;If null character, exit (2/3)
                JSR     CHROUT          ;Send character to terminal (6)
                INC     STRINGL         ;Increment low byte index (5)
                BNE     PROMPT2         ;Loop back for next character (2/3)
                INC     STRINGH         ;Increment high byte index (5)
                BRA     PROMPT2         ;Loop back and continue printing (3)
PR_EXIT         RTS                     ;Return to caller
;
;**************************************************************************************************
;Initializing the SC28L92 DUART as a Console.
;An anomaly in the W65C02 processor requires a different approach in programming the SC28L92
; for proper setup/operation. The SC28L92 uses three Mode Registers which are accessed at the same
; register in sequence. There is a command that Resets the Mode Register pointer (to MR0) that is
; issued first. Then MR0/1/2 are loaded in sequence. The problem with the W65C02 is a false read of
; the register when using indexed addressing (i.e., STA UART_REGISTER,X). This results in the Mode
; Register pointer being moved to the next register, so the write to next MRx never happens. While
; the indexed list works fine for all other register functions/commands, the loading of the
; Mode Registers need to be handled separately.
;
;NOTE: the W65C02 will function normally "if" a page boundary is crossed as part of the STA
; (i.e., STA $FDFF,X) where the value of the X Register is high enough to cross the page boundary.
; Programming in this manner would be confusing and require modification if the base I/O address
; is changed for a different hardware I/O map.
;
;There are two routines called to setup the 28L92 DUART:
;
;The first routine is a RESET of the DUART.
; It issues the following sequence of commands:
;  1- Reset Break Change Interrupts
;  2- Reset Receivers
;  3- Reset Transmitters
;  4- Reset All errors
;
;The second routine initializes the 28L92 DUART for operation. It uses two tables of data; one for
; the register offset and the other for the register data. The table for register offsets is
; maintained in ROM. The table for register data is copied to page $02, making it soft data. If
; needed, operating parameters can be altered and the DUART re-initialized via the ROM routine.
;
; Note: A hardware reset will reset the SC28L92 and the default ROM config will be initialized.
; Also note that the Panic routine invoked by a NMI trigger will also reset the DUART to the
; default ROM config.
;
INIT_IO         JSR     RESET_28L92     ;Reset the SC28L92 DUART (both channels) (6)
                LDA     #DF_TICKS       ;Get divider for jiffy clock (100x10ms = 1 second) (2)
                STA     TICKS           ;Preload TICK count (3)
;
;This routine sets the initial operating mode of the DUART
;
INIT_28L92      SEI                     ;Disable interrupts (2)
;
                LDX     #INIT_DUART_E-INIT_DUART ;Get the Init byte count (2)
28L92_INT       LDA     LOAD_28L92-1,X  ;Get Data for 28L92 Register (4)
                LDY     INIT_OFFSET-1,X ;Get Offset for 28L92 Register (4)
                STA     SC28L92_BASE,Y  ;Store Data to selected register (5)
                DEX                     ;Decrement count (2)
                BNE     28L92_INT       ;Loop back until all registers are loaded (2/3)
;
; Mode Registers are NOT reset to MR0 by above INIT_28L92!
; The following resets the MR pointers for both channels, then sets the MR registers
; for each channel. Note: the MR index is incremented to the next location after the write.
; NOTE: These writes can NOT be done via indexed addressing modes!
;
                LDA     #%10110000      ;Get mask for MR0 Reset (2)
                STA     UART_COMMAND_A  ;Reset Pointer for Port A (4)
                STA     UART_COMMAND_B  ;Reset Pointer for Port B (4)
;
                LDX     #$03            ;Set index for 3 bytes to xfer (2)
MR_LD_LP        LDA     LOAD_28L92+15,X ;Get MR data for Port A (4)
                STA     UART_MODEREG_A  ;Send to 28L92 Port A (4)
                LDA     LOAD_28L92+18,X ;Get MR data for Port B (4)
                STA     UART_MODEREG_B  ;Send to 28L92 Port B (4)
                DEX                     ;Decrement index to next data (2)
                BNE     MR_LD_LP        ;Branch back till done (2/3)
;
                CLI                     ;Enable interrupts (2)
;
; Start Counter/Timer
;
                LDA     UART_START_CNT  ;Read register to start counter/timer (4)
                RTS                     ;Return to caller (6)
;
; This routine does a Reset of the SC28L92 - both channels
;
RESET_28L92     LDX     #UART_RDATAE-UART_RDATA1 ;Get the Reset commands byte count (2)
UART_RES1       LDA     UART_RDATA1-1,X ;Get Reset commands (4)
                STA     UART_COMMAND_A  ;Send to UART A CR (4)
                STA     UART_COMMAND_B  ;Send to UART B CR (4)
                DEX                     ;Decrement the command list index (2)
                BNE     UART_RES1       ;Loop back until all are sent (2/3)
                RTS                     ;Return to caller (6)
;
;**************************************************************************************************
;START OF PANIC ROUTINE
;The Panic routine is for debug of system problems, i.e., a crash. The hardware design requires a
; debounced NMI trigger button which is manually operated when the system crashes or malfunctions.
;
;User presses the NMI (panic) button. The NMI vectored routine will perform the following tasks:
; 1- Save CPU registers in page zero locations
; 2- Reset the MicroDrive and disable interrupts
; 3- Clear all Console I/O buffer pointers
; 4- Call the ROM routines to init the vectors and config data (page $02)
; 5- Call the ROM routines to reset/init the DUART (SC28L92)
; 6- Enter the Monitor via the warm start vector **
;
; Note: The additional hardware detection (RTC/IDE) are NOT executed with the Panic routine!
; The interrupt vectors are restored without including the additional ISR for the IDE controller.
; The Microdrive Reset_Off command is also set to disable any bus activity.
;
; Note: no memory is cleared except the required pointers/vectors to restore the system.
;
NMI_VECTOR      SEI                     ;Disable interrupts (2)
                STA     AREG            ;Save A Reg (3)
                STX     XREG            ;Save X Reg (3)
                STY     YREG            ;Save Y Reg (3)
                PLA                     ;Get Processor Status (4)
                STA     PREG            ;Save in PROCESSOR STATUS preset/result (3)
                TSX                     ;Get Stack pointer (4)
                STX     SREG            ;Save STACK POINTER (3)
                PLA                     ;Pull RETURN address from STACK (4)
                STA     PCL             ;Store Low byte (3)
                PLA                     ;Pull high byte (4)
                STA     PCH             ;Store High byte (3)
;
                LDA     #%00000110      ;Get mask for MicroDrive Reset/IRQ disable (2)
                STA     IDE_DEV_CTRL    ;Send to MicroDrive (4)
;
                STZ     UART_IMR        ;Disable ALL interrupts from UART (4)
;
                LDX     #$0C            ;Set count for 12 (2)
PAN_LP1         STZ     ICNT_A-1,X      ;Clear DUART I/O pointers (3)
                DEX                     ;Decrement index (2)
                BNE     PAN_LP1         ;Branch back till done (2/3)
;
                JSR     INIT_PG02       ;Xfer default Vectors/HW Config to $0200 (6)
                JSR     INIT_IO         ;Reset and Init the UART for Console (6)
;
                LDA     #%00000010      ;Get mask for MicroDrive Reset off (2)
                STA     IDE_DEV_CTRL    ;Send to MicroDrive (4)
;
                JMP     (NMIRTVEC0)     ;Jump to NMI Return Vector (Monitor Warm Start) (6)
;
;**************************************************************************************************
;BRK/IRQ Interrupt service routines
;The pre-process routine located in page $FF soft-vectors to INTERUPT0/BRKINSTR0 below
;       These are the routines that handle BRK and IRQ functions
;       The BRK handler saves CPU details for register display
;       - A Monitor can provide a disassembly of the last executed instruction
;       - A Received Break is also handled here (ExtraPutty/Windows or Serial/OSX)
;
; SC28L92 handler
;       The 28L92 IRQ routine handles Transmit, Receive, Timer and Received-Break interrupts
;       - Transmit and Receive each have a 128 byte circular FIFO buffer in memory per channel
;       - Xmit IRQ is controlled (On/Off) by the handler and the CHROUT(2) routine
;
; The 28L92 Timer resolution is 10ms and used as a Jiffy Clock for RTC, delays and benchmarking
;**************************************************************************************************
;BIOS routines to handle interrupt-driven I/O for the SC28L92
; NOTE: IP0 Pin is used for RTS, which is automatically handled in the chip. As a result,
; the upper 2 bits of the ISR are not used in the handler. The Lower 5 bits are used, but
; the lower two are used to determine when to disable transmit after the buffer is empty.
;
;The DUART_ISR bits are defined as follows:

; Bit7          ;Input Change Interrupt
; Bit6          ;Change Break B Interrupt
; Bit5          ;RxRDY B Interrupt
; Bit4          ;TxRDY B Interrupt
; Bit3          ;Counter Ready Interrupt
; Bit2          ;Change Break A Interrupt
; Bit1          ;RxRDY A Interrupt
; Bit0          ;TxRDY A Interrupt
;
; SC8L92 uses all bits in the Status Register!
; - for Receive Buffer full, we set a bit in the SC28L92 Misc. Register, one for each Port.
; Note that the Misc. Register in the SC28L92 is a free byte for storing the flags, as it's
; not used when the DUART is configured in Intel mode! Freebie Register for us to use ;-)
;
; NOTE: The entry point for the BRK/IRQ handler is below at label INTERUPT0
;**************************************************************************************************
;ISR Routines for SC28L92 Port B
;
; The operation is the same as Port A below, sans the fact that the Break detection only resets
; the DUART channel and returns, while Port A uses Break detection for other functions within
; the BIOS structure, and processes the BRK routine shown further down.
;
UARTB_RCV       LDY     ICNT_B          ;Get input buffer count (3)
                BMI     BUFFUL_B        ;Check against limit ($80), branch if full (2/3)
;
UARTB_RCVLP     LDA     UART_STATUS_B   ;Get Status Register (4)
                BIT     #%00000001      ;Check RxRDY active (2)
                BEQ     UARTB_CXMT      ;If RxRDY not set, FIFO is empty, check Xmit (2/3)

                LDA     UART_RECEIVE_B  ;Else, get data from 28L92 (4)
                LDY     ITAIL_B         ;Get the tail pointer to buffer (3)
                STA     IBUF_B,Y        ;Store into buffer (5)
                INC     ITAIL_B         ;Increment tail pointer (5)
                RMB7    ITAIL_B         ;Strip off bit 7, 128 bytes only (5)
                INC     ICNT_B          ;increment data count (5)
                BPL     UARTB_RCVLP     ;If input buffer not full, check for more FIFO data (2/3)
;
UARTB_CXMT      LDA     UART_ISR        ;Get 28L92 ISR Reg (4)
                BIT     #%00010000      ;Check for Xmit B active (2)
                BEQ     REGEXT_B        ;Exit if inactive (2/3)
;
; To take advantage of the onboard FIFO, we test the TxRDY bit in the Status Register. If the
; bit is set, then there is more room in the FIFO. The ISR routine here will attempt to fill
; the FIFO from the Output Buffer. This saves processing time in the ISR itself.
;
UARTB_XMT       LDA     OCNT_B          ;Get output buffer count, any data to xmit? (3)
                BEQ     NODATA_B        ;If zero, no data left, turn off xmit (2/3)
;
UARTB_XMTLP     LDA     UART_STATUS_B   ;Get Status Register (4)
                BIT     #%00000100      ;Check TxRDY active (2)
                BEQ     REGEXT_B        ;If TxRDY not set, FIFO is full, exit ISR (2/3)
;
                LDY     OHEAD_B         ;Get the head pointer to buffer (3)
                LDA     OBUF_B,Y        ;Get the next data (4)
                STA     UART_TRANSMIT_B ;Send the data to 28L92 (4)
                INC     OHEAD_B         ;Increment head pointer (5)
                RMB7    OHEAD_B         ;Strip off bit 7, 128 bytes only (5)
                DEC     OCNT_B          ;Decrement counter (5)
                BNE     UARTB_XMTLP     ;If more data, loop back to send it (2/3)
;
;No more buffer data to send, check SC28L92 TxEMT and disable transmit if empty.
; Note: If the TxEMT bit is set, then the FIFO is empty and all data has been sent.
;
NODATA_B        LDY     #%00001000      ;Else, get mask for xmit off (2)
                STY     UART_COMMAND_B  ;Turn off xmit (4)
REGEXT_B        JMP     (IRQRTVEC0)     ;Return to Exit/ROM IRQ handler (6)
;
BUFFUL_B        LDY     #%00010000      ;Get Mask for Buffer full (2)
                STY     UART_MISC       ;Save into 28L92 Misc. Register (4)
                BRA     REGEXT_B        ;Exit IRQ handler (3)
;
;Received Break handler for Port B
;
UARTB_BRK       LDA     UART_STATUS_B   ;Get DUART Status Register (4)
                BMI     BREAKEY_B       ;If bit 7 set, received Break was detected (2/3)
;
; If a received Break was not the cause, we should reset the DUART Port as the cause
; could have been a receiver error, i.e., parity or framing
;
                LDX     #UART_RDATAE-UART_RDATA ;Get index count (2)
UARTB_RST1      LDA     UART_RDATA-1,X  ;Get Reset commands (4)
                STA     UART_COMMAND_B  ;Send to DUART CR (4)
                DEX                     ;Decrement the command list (2)
                BNE     UARTB_RST1      ;Loop back until all are sent (2/3)
                BRA     REGEXT_B        ;Exit (3)
;
; A received Break was the cause. Just reset the receiver and return.
;
BREAKEY_B       LDA     #%01000000      ;Get Reset Received Break command (2)
                STA     UART_COMMAND_B  ;Send to DUART to reset (4)
                LDA     #%01010000      ;Get Reset Break Interrupt command (2)
                STA     UART_COMMAND_B  ;Send to DUART to reset (4)
                BRA     REGEXT_B        ;Exit (3)
;
;**************************************************************************************************
;This is the IRQ handler entry point for the SC28L92 DUART.
; This is the first IRQ handler unless an IDE device is found during cold start. By default, it
; will take 25 clock cycles to arrive here after an interrupt is generated. If an IDE device is
; present, the IDE handler will be processed first. If no IDE interrupt is active, it will take
; an additional 33 cycles to arrive here.
;
; The ISR checks for interrupt sources as follows:
; - Timer/Counter, to ensure accurate software RTC and benchmark/delay timings
; - Serial Port 2, to provide fast data transfers to a separate device
; - Serial Port 1, for standard Console access
;
INTERUPT0                               ;Interrupt 0 to handle the SC28L92 DUART
                LDA     UART_ISR        ;Get the UART Interrupt Status Register (4)
                BEQ     REGEXT_0        ;If no bits are set, exit handler (2/3)
;
                BIT     #%00001000      ;Test for Counter ready (RTC) (2)
                BNE     UART_RTC        ;If yes, go increment RTC variables (2/3)
;
                BIT     #%01000000      ;Test for Break on B (2)
                BNE     UARTB_BRK       ;If yes, Reset the DUART receiver (2/3)
;
                BIT     #%00100000      ;Test for RHR B having data (2)
                BNE     UARTB_RCV       ;If yes, put the data in the buffer (2/3)
;
                BIT     #%00010000      ;Test for THR B ready to receive data (2)
                BNE     UARTB_XMT       ;If yes, get data from the buffer (2/3)
;
                BIT     #%00000100      ;Test for Break on A (2)
                BNE     UARTA_BRK       ;If yes, Reset the DUART receiver (2/3)
;
                BIT     #%00000010      ;Test for RHR A having data (2)
                BNE     UARTA_RCV       ;If yes, put the data in the buffer (2/3)
;
                BIT     #%00000001      ;Test for THR A ready to receive data (2)
                BNE     UARTA_XMT       ;If yes, get data from the buffer (2/3)
;
; if none of the above bits caused the IRQ, the only bit left is the change input port.
; just save it in the temp IRT register in page zero and exit.
;
                STA     UART_IRT        ;Save the 28L92 ISR for later use (3)
REGEXT_0        JMP     (IRQRTVEC0)     ;Return to Exit/ROM IRQ handler (6)
;
UART_RTC        JMP     UART_RTC0       ;Jump to RTC handler (3)
;
;**************************************************************************************************
;ISR Routines for SC28L92 Port A
;
; The Receive Buffer is checked first to ensure there is open space in the buffer.
; By loadng the input count, bit7 will be set if it is full, which will set the "N"
; flag in the CPU status register. If this is the case, we exit to BUFFUL_A and set
; a bit in the SC28L92 Misc. Register. If the buffer has space, we continue.
; 
; To take advantage of the onboard FIFO, we test the RxRDY bit in the Status Register.
; If the bit is set, the FIFO has data and the routine moves data from the FIFO into
; the Receive buffer. We loop back and contnue moving data from the FIFO to the buffer
; until the RxRDY bit is cleared (FIFO empty). If the FIFO is empty, we branch and
; check for a pending Transmit interrupt, just to save some ISR time.
;
; NOTE: the receiver is configured to use the Watchdog function. This will generate a
; receiver interrupt within 64 bit times once data is received (and the FIFO has not
; reached it's configured fill level). This provides the required operation for use
; as a console, as single character commands are common and would not fill the FIFO,
; which generates an interrupt based on the configured FIFO fill level.
;
UARTA_RCV       LDY     ICNT_A          ;Get input buffer count (3)
                BMI     BUFFUL_A        ;Check against limit ($80), branch if full (2/3)
;
UARTA_RCVLP     LDA     UART_STATUS_A   ;Get Status Register (4)
                BIT     #%00000001      ;Check RxRDY active (2)
                BEQ     UARTA_CXMT      ;If RxRDY not set, FIFO is empty, check Xmit (2/3)

                LDA     UART_RECEIVE_A  ;Else, get data from 28L92 (4)
                LDY     ITAIL_A         ;Get the tail pointer to buffer (3)
                STA     IBUF_A,Y        ;Store into buffer (5)
                INC     ITAIL_A         ;Increment tail pointer (5)
                RMB7    ITAIL_A         ;Strip off bit 7, 128 bytes only (5)
                INC     ICNT_A          ;Increment input bufffer count (5)
                BPL     UARTA_RCVLP     ;If input buffer not full, check for more FIFO data (2/3)
;
UARTA_CXMT      LDA     UART_ISR        ;Get 28L92 ISR Reg (4)
                BIT     #%00000001      ;Check for Xmit A active (2)
                BEQ     REGEXT_A        ;Exit if inactive, else drop into Xmit code (2/3)
;
;To take advantage of the onboard FIFO, we test the TxRDY bit in the Status Register.
; If the bit is set, then there is more room in the FIFO. The ISR routine here will attempt to
; fill the FIFO from the Output Buffer. This saves processing time in the ISR itself.
;
UARTA_XMT       LDA     OCNT_A          ;Get output buffer count, any data to xmit? (3)
                BEQ     NODATA_A        ;If zero, no data left, turn off xmit (2/3)
;
UARTA_XMTLP     LDA     UART_STATUS_A   ;Get Status Register (4)
                BIT     #%00000100      ;Check TxRDY active (2)
                BEQ     REGEXT_A        ;If TxRDY not set, FIFO is full, exit ISR (2/3)
;
                LDY     OHEAD_A         ;Get the head pointer to buffer (3)
                LDA     OBUF_A,Y        ;Get the next data (4)
                STA     UART_TRANSMIT_A ;Send the data to 28L92 (4)
                INC     OHEAD_A         ;Increment head pointer (5)
                RMB7    OHEAD_A         ;Strip off bit 7, 128 bytes only (5)
                DEC     OCNT_A          ;Decrement output buffer count (5)
                BNE     UARTA_XMTLP     ;If more data, loop back to send it (2/3)
;
;No more buffer data to send, check SC28L92 TxEMT and disable transmit if empty.
; Note: If the TxEMT bit is set, then the FIFO is empty and all data has been sent.
;
NODATA_A        LDY     #%00001000      ;Else, get mask for xmit off (2)
                STY     UART_COMMAND_A  ;Turn off xmit (4)
REGEXT_A        JMP     (IRQRTVEC0)     ;Return to Exit/ROM IRQ handler (6)
;
BUFFUL_A        LDY     #%00000001      ;Get Mask for Buffer full (2)
                STY     UART_MISC       ;Save into 28L92 Misc. Register (4)
                BRA     REGEXT_A        ;Exit IRQ handler (3)
;
;Received Break handler for Port A
;
UARTA_BRK       LDA     UART_STATUS_A   ;Get DUART Status Register (4)
                BMI     BREAKEY_A       ;If bit 7 set, received Break was detected (2/3)
;
; If a received Break was not the cause, we should reset the DUART Port as the cause
; could have been a receiver error, i.e., parity or framing
;
                LDX     #UART_RDATAE-UART_RDATA ;Get index count (2)
UARTA_RST1      LDA     UART_RDATA-1,X  ;Get Reset commands (4)
                STA     UART_COMMAND_A  ;Send to DUART CR (4)
                DEX                     ;Decrement the command list (2)
                BNE     UARTA_RST1      ;Loop back until all are sent (2/3)
                BRA     REGEXT_A        ;Exit (3)
;
; A received Break was the cause. Reset the receiver and process the BRK routine.
;
BREAKEY_A       LDA     #%01000000      ;Get Reset Received Break command (2)
                STA     UART_COMMAND_A  ;Send to DUART to reset (4)
                LDA     #%01010000      ;Get Reset Break Interrupt command (2)
                STA     UART_COMMAND_A  ;Send to DUART to reset (4)
;
BREAKEY         CLI                     ;Enable IRQ, drop into BRK handler (2)
;
;**************************************************************************************************
;
; BRK Vector defaults to here
;
BRKINSTR0       PLY                     ;Restore Y Reg (4)
                PLX                     ;Restore X Reg (4)
                PLA                     ;Restore A Reg (4)
                STA     AREG            ;Save A Reg (3)
                STX     XREG            ;Save X Reg (3)
                STY     YREG            ;Save Y Reg (3)
                PLA                     ;Get Processor Status (4)
                STA     PREG            ;Save in PROCESSOR STATUS preset/result (3)
                TSX                     ;Xfer STACK pointer to X Reg (2)
                STX     SREG            ;Save STACK pointer (3)
;
                PLX                     ;Pull Low RETURN address from STACK then save it (4)
                STX     PCL             ;Store program counter Low byte (3)
                PLY                     ;Pull High RETURN address from STACK then save it (4)
                STY     PCH             ;Store program counter High byte (3)
                BBR4    PREG,DO_NULL    ;Check for BRK bit set (5/6,7)
;
; This call simply shows CPU Register contents and invoked by a BRK opcode.
;
                JSR     PRSTAT          ;Display CPU status (6)
;
; Note: This routine only clears Port A, as it is used for the Console
;
DO_NULL         LDA     #$00            ;Clear all Processor Status Register bits (2)
                PHA                     ;Push it to Stack (3)
                PLP                     ;Pull it to Processor Status (4)
                STZ     ITAIL_A         ;Clear input buffer pointers (3)
                STZ     IHEAD_A         ; (3)
                STZ     ICNT_A          ; (3)
                JMP     (BRKRTVEC0)     ;Done BRK service process, re-enter monitor (6)
;
PRSTAT          
                LDA     #<PSTAT_MSG     ;CPU Status message (2)
                LDY     #>PSTAT_MSG     ; (2)
                JSR     PROMPTR         ;Send to console (6)
                LDA     PCL             ;Get PC Low byte (3)
                LDY     PCH             ;Get PC High byte (3)
                JSR     PRWORD          ;Print 16-bit word (6)
                JSR     SPC             ;Send 1 space (6)
;
                LDX     #$04            ;Set for count of 4 (2)
REGPLOOP        LDA     PREG,X          ;Start with A Reg variable (4)
                JSR     PRBYTE          ;Print it (6)
                JSR     SPC             ;Send 1 space (6)
                DEX                     ;Decrement count (2)
                BNE     REGPLOOP        ;Loop back till all 4 are sent (2/3)
;
                LDA     PREG            ;Get Status Register preset (3)
                LDX     #$08            ;Get the index count for 8 bits (2)
SREG_LP         ASL     A               ;Shift bit into Carry (2)
                PHA                     ;Save current (shifted) SR value (3)
                LDA     #$30            ;Load an Ascii zero (2)
                ADC     #$00            ;Add zero (with Carry) (2)
                JSR     CHROUT          ;Print bit value (0 or 1) (6)
                PLA                     ;Get current (shifted) SR value (4)
                DEX                     ;Decrement bit count (2)
                BNE     SREG_LP         ;Loop back until all 8 printed, drop to CROUT (2/3)
;
;Send CR/LF to terminal
CROUT           PHA                     ;Save A Reg (3)
                LDA     #$0D            ;Get ASCII Return (2)
                JSR     CHROUT          ;Send to terminal (6)
                LDA     #$0A            ;Get ASCII Linefeed (2)
SENDIT          JSR     CHROUT          ;Send to terminal (6)
                PLA                     ;Restore A Reg (4)
                RTS                     ;Return to caller (6)
;
SPC             PHA                     ;Save character in A Reg (3)
                LDA     #$20            ;Get ASCII Space (2)
                BRA     SENDIT          ;Branch to send (3)
;
;PRBYTE subroutine: Converts a single Byte to 2 HEX ASCII characters and sends to console on
; entry, A Reg contains the Byte to convert/send. Register contents are preserved on entry/exit.
PRBYTE          PHA                     ;Save A Register (3)
                PHY                     ;Save Y Register (3)
PRBYT2          JSR     BIN2ASC         ;Convert A Reg to 2 ASCII Hex characters (6)
                JSR     CHROUT          ;Print high nibble from A Reg (6)
                TYA                     ;Transfer low nibble to A Reg (2)
                JSR     CHROUT          ;Print low nibble from A Reg (6)
                PLY                     ;Restore Y Register (4)
                PLA                     ;Restore A Register (4)
                RTS                     ;Return to caller (6)
;
;PRWORD subroutine: Converts a 16-bit word to 4 HEX ASCII characters and sends to console. On
; entry, A Reg contains Low Byte, Y Reg contains High Byte. Registers are preserved on entry/exit.
; NOTE: Routine changed for consistency; A Reg = Low byte, Y Reg = High byte on 2nd May 2020
PRWORD          PHA                     ;Save A Register (Low) (3)
                PHY                     ;Save Y Register (High) (3)
                PHA                     ;Save Low byte again (3)
                TYA                     ;Xfer High byte to A Reg (2)
                JSR     PRBYTE          ;Convert and print one HEX character (00-FF) (6)
                PLA                     ;Get Low byte value (4)
                BRA     PRBYT2          ;Finish up Low Byte and exit (3)
;
;BIN2ASC subroutine: Convert single byte to two ASCII HEX digits
; Enter: A Register contains byte value to convert
; Return: A Register = high digit, Y Register = low digit
BIN2ASC         PHA                     ;Save A Reg on stack (3)
                AND     #$0F            ;Mask off high nibble (2)
                JSR     ASCII           ;Convert nibble to ASCII HEX digit (6)
                TAY                     ;Move to Y Reg (2)
                PLA                     ;Get character back from stack (3)
                LSR     A               ;Shift high nibble to lower 4 bits (2)
                LSR     A               ; (2)
                LSR     A               ; (2)
                LSR     A               ; (2)
;
ASCII           CMP     #$0A            ;Check for 10 or less (2)
                BCC     ASCOK           ;Branch if less than 10 (2/3)
                ADC     #$06            ;Add $06+CF ($07) for A-F (2)
ASCOK           ADC     #$30            ;Add $30 for ASCII (2)
                RTS                     ;Return to caller (6)
;
; Text Data for the BIOS CPU Register Display:
;
PSTAT_MSG
        .DB     $0D,$0A
        .DB      "   PC  AC XR YR SP NV-BDIZC",$0D,$0A
        .DB     "; "
        .DB     $00
;
;**************************************************************************************************
;
;Entry for ISR to service the timer/counter interrupt.
;
; NOTE: Stop timer cmd resets the interrupt flag, counter continues to generate interrupts.
; NOTE: 38 clock cycles to here from INTERUPT0 - 68 in total, sans IDE ISR if active.
;
UART_RTC0       LDA     UART_STOP_CNT   ;Get Command mask for stop timer (4)
;
; Check the MATCH flag bit7 to see if a Delay is active. If yes, decrement the MSDELAY
; variable once each pass until it is zero, then clear the MATCH flag bit7
;
                BBR7    MATCH,SKIP_DLY  ;Skip Delay if bit7 is clear (5/6,7)
                DEC     MSDELAY         ;Decrement Millisecond delay variable (5)
                BNE     SKIP_DLY        ;If not zero, skip (2/3)
                RMB7    MATCH           ;Else clear MATCH flag (5)
;
; Check the MATCH flag bit6 to see if Benchmarking is active. If yes, increment the
; variables once each pass until the MATCH flag bit6 is inactive.
;
SKIP_DLY        BBR6    MATCH,SKIP_CNT  ;Skip Count if bit6 is clear (5/6,7)
                INC     MS10_CNT        ;Else, increment 10ms count (5)
                LDA     MS10_CNT        ;Load current value (3)
                CMP     #100            ;Compare for 1 second elapsed time (2)
                BCC     SKIP_CNT        ;If not, skip to RTC update (2/3)
                STZ     MS10_CNT        ;Else, zero 10ms count (3)
                INC     SECL_CNT        ;Increment low byte elapsed seconds (5)
                BNE     SKIP_CNT        ;If no overflow, skip to RTC update (2/3)
                INC     SECH_CNT        ;Else, increment high byte elapsed seconds (5)
;
SKIP_CNT        DEC     TICKS           ;Decrement RTC tick count (5)
                BNE     REGEXT_RTC      ;Exit if not zero (2/3)
                LDA     #DF_TICKS       ;Get default tick count (2)
                STA     TICKS           ;Reset tick count (3)
;
                INC     SECS_0          ;Increment lower clock byte (5)
                BNE     SKIP_1          ;If not zero, skip next update (2/3)
;
                INC     SECS_1          ;Increment second clock byte (5)
                BNE     SKIP_1          ;If not zero, skip next update (2/3)
;
                INC     SECS_2          ;Increment third clock byte (5)
                BNE     SKIP_1          ;If not zero, skip next update (2/3)
;
                INC     SECS_3          ;Increment fourth clock byte (5)
SKIP_1
REGEXT_RTC      JMP     (IRQRTVEC0)     ;Return to Exit/ROM IRQ handler (6)     
;
;**************************************************************************************************
;
;Core routines that are used to detect and configure additional I/O devices.
; The I/O devices supported by the 5.x Release of C02BIOS contains two I/O devices:
; - A Maxim DS1318 Realtime Clock - new device!
; - An IDE Device, i.e., IBM/Hitachi MicroDrive
;
;The first routine detects the DS1318 RTC, followed by the routine to detect the IDE device.
;
;**************************************************************************************************
;
;This routine detects the DS1318 RTC.
;
; According to the datasheet, the TE and ENOSC bits in register offset 0Ah will be set to "1"
; for normal update operation and the CCFG1 and CCFG0 bits will be "0" for normal operation.
;
; Note: With the W65C02 CPU, when an empty address is read by the CPU, the data that comes back
; will be a phantom of the upper byte of the address, or FEh for our hardware.
; This technique is used to detect both the DS1318 and the IDE device.
; If the TE and ENOSC are "1" and the CCFG1 and CCFG0 bits are "0", then the RTC is present and
; functioning. Only the upper 4 bits are needed to sense this, so we mask off the lower 4 bits
; and compare to "%11000000" to confirm the RTC.
;
DETECT_RTC
                LDA     RTC_CONTROL_A   ;Get RTC Control Reg A (3)
                AND     #%11110000      ;Mask off bits for TE, ENOSC, CCFG1/0 (2)
                CMP     #$11000000      ;Bits 7/6 should be on, 5/4 should be off (2)
                BEQ     FOUND_RTC       ;If bits are off, RTC is present (2/3)
                RTS                     ;Else Return, RTC not found (6)
;
FOUND_RTC
                SMB4    MATCH           ;Set Match Bit 4 for RTC present (5)
                LDX     #$00            ;Zero Index for RTC message (2)
RTC_MSG_LP
                LDA     RTC_MSG,X       ;Get BIOS init msg (4)
                BEQ     INIT_RTC_NC     ;If zero, msg done, go Init RTC (2/3)
                JSR     CHROUT          ;Send to console (6)
                INX                     ;Increment Index
                BRA     RTC_MSG_LP      ;Loop back until done (3)
;
;This routine reads the Binary data registers from the DS1318 RTC. Note that the DS1318 does not
; keep time and date variables, but a 32-bit binary number held in 4 registers. The 32-bit value
; is set by a separate program that considers "0000h" as Epoch time. As a result, if no RTC is
; present, the BIOS 32-bit RTC count starts at "0000h".
;
INIT_RTC
                BBR4    MATCH,NO_RTC    ;Check for RTC present, else exit (5/6,7)
;
INIT_RTC_NC
                LDX     #DF_TICKS       ;Get BIOS default Tick count (2)
                STX     TICKS           ;Reset the Tick count (3)
;
RTC_UIP_LP
                LDA     RTC_STATUS      ;Get RTC Status register (3)
                AND     #%01000000      ;Mask UIP bit (2)
                BNE     RTC_UIP_LP      :Loop back util update is finished (2/3)
;
                LDX     #$00            ;Set X reg to zero for data xfer (2)
                LDA     #%10000000      ;Get TE Bit mask (2)
                TRB     RTC_CONTROL_A   ;Turn off TE Bit to disable update (6)
;
RTC_LOAD_LOOP
                LDA     RTC_SECONDS_0,X ;Get data from RTC (4)
                STA     SECS_0,X        ;Store into RAM (4)
                INX                     ;Increment index
                CPX     #$04            ;Check for all 4 moved (2)
                BNE     RTC_LOAD_LOOP   ;Loop back until done (2/3)
;
                LDA     #%10000000      ;Get TE Bit mask (2)
                TSB     RTC_CONTROL_A   ;Turn on TE Bit to enable update (6)
NO_RTC          RTS                     ;Return to caller (6)
;
;**************************************************************************************************
;
;This routine detects the IDE Port
; To detect the IDE controller, it can be a bit tricky. It might take several seconds from a
; physical Reset of the IDE Controller before the Busy flag goes off. During this time, any
; commands sent to the IDE controller will fail. As I like to say, "timing is everything". After
; quite a bit of testing, the easy way to detect the IDE controller present is to load the
; IDE_STATUS register. If an IDE Controller is not present, the A Reg will show a phantom address
; of $FE (high order IDE hardware address) and any initialization can be bypassed.
;
; If the IDE controller is present, the IDE_STATUS read may be invalid, so it's necessary
; to test the BUSY flag of the status register. Once the IDE Controller is no longer busy,
; the controller can be initialized. This does create an obvious pause in the startup, but
; ensures that the IDE controller can be reliably detected and initialized at boot time.
;
; As interrupts are disabled on the IDE Controller initially, it needs to be enabled before the
; setup is completed. A separate routine enables interrupts and is also called by the Reset-Diag
; function (JMP $FF00).
;
DETECT_IDE
                LDA     IDE_STATUS      ;Get the IDE Status (4)
                CMP     #$FE            ;Check for an empty (phantom) address (2)
                BNE     IDE_INIT        ;If not #$FE, try to Init the IDE controller (2/3)
                RTS                     ;Else, return to caller, no IDE controller found (6)
;
;Init the IDE controller
; First, test for the IDE controller ready. If that works, execute the IDE device Diagnostics and
; check for successful completion. If it fails, exit without linking the IDE controller into the
; IRQ chain. Else, link IRQ chain and show message that the IDE device is found.
;
IDE_INIT
                LDA     IDE_ALT_STATUS  ;Get IDE Alternate Status register (4)
                BMI     IDE_INIT        ;Loop until BUSY bit is clear (2/3)
;
                JSR     IDE_DIAG        ;Run the self diagnostic (6)
                CMP     #$50            ;Check for $50 on A reg (drive ready) (2)
                BNE     NO_IDE          ;If not, no IDE present (2/3)
                CPX     #$01            ;X Reg will show #$01 if diags successful (2)
                BNE     NO_IDE          ;If failed, exit (2/3)
;
; IDE Controller found and passed initial self diagnostics test.
; Send IDE Found message to terminal, note: X reg = $01.
;
                SMB5    MATCH           ;Set Match Bit 5 for IDE present (5)
IDE_MSG_LP      LDA     IDE_MSG-1,X     ;Get BIOS init msg (minus 1 for X reg=1) (4)
                BEQ     IDE_SETUP       ;If zero, msg done, go setup IDE (2/3)
                JSR     CHROUT          ;Send to console (6)
                INX                     ;Increment Index (2)
                BRA     IDE_MSG_LP      ;Loop back until done (3)
;
NO_IDE          JMP     IDE_RD_ERR      ;Jump to drive error message (3)
;
;IDE Setup
; This will insert the IDE Controller ISR into the Interrupt Handler chain.
;
; First, disable interrupts, capture the current IRQ exit vector address
; and save it to the first Insert Vector. Second, load the IDE ISR routine
; address and store it to the main IRQ exit vector, then re-enable interrupts.
;
; Second, this routine will execute an Identify IDE command to load the Soft
; Config Data for the maximum LBA Count accessible by the current IDE device.
;
; Note: For performnce, the IDE ISR will be inserted before the DUART ISR!
;
IDE_SETUP                               ;Insert IDE ISR into IRQ chain
;
; To load the IDE ISR Handler BEFORE the existing DUART ISR Handler:
                SEI                     ;Disable interrupts (2)
;
                LDA     IRQVEC0         ;Get low byte of current IRQ Exit (4)
                LDY     IRQVEC0+1       ;Get high byte of current IRQ Exit (4)
                STA     VECINSRT0       ;Save low byte of IRQ Exit to insert 0 (4)
                STY     VECINSRT0+1     ;Save high byte of IRQ Exit to insert 0 (4)
;
                LDA     #<INTERUPT1     ;Get low byte of IDE ISR (2)
                LDY     #>INTERUPT1     ;Get high byte of IDE ISR (2)
                STA     IRQVEC0         ;Save low byte of IRQ Exit (4)
                STY     IRQVEC0+1       ;Save high byte of IRQ Exit (4)
;
                CLI                     ;Enable interrupts (2)
                JSR     IDE_EN_IRQ      ;Enable IDE Controller interrupt (6)
;
; Drop into Identify Drive routine
;
IDE_IDENTIFY                            ;Identify Device
;
; This requests a 512-byte block of data that shows capabilities, CHS (not used), LBA Count, etc.
; The format is similar to Read LBA, except no LBA parameter is required. It effectively works as
; a Read Block operation and the data transferred is handled by the ISR for a Read Block.
; NOTE: The Identify Command is coded to load into the LBA_BUFFER (default address $0600).
;
                LDA     #<LBA_BUFFER    ;Set Address low byte (2)
                LDY     #>LBA_BUFFER    ;Set Address high byte (2)
                LDX     #$01            ;Set Block count to 1 (2)
                JSR     IDE_SET_ADDRESS ;Set Xfer address and block count (6)
IDENT_WAIT
                LDA     IDE_ALT_STATUS  ;Get IDE Alternate Status register (4)
                BMI     IDENT_WAIT      ;Loop until BUSY bit is clear (2/3)


                JSR     IDE_SET_PARMS2  ;Setup required parameters (no LBA parameter) (6)
;
                LDA     #$EC            ;Get Identify Command (2)
                JSR     IDENT_READ      ;Use READ_LBA routine to finish (6)
;
; Identify data loaded in buffer. Now extract LBA count and store to Soft Config Data for usage
; by access routines (Read/Write). Four bytes are used and the format from the Identify
; Command are Low-order Word / High-order Word, where each word is in Big Endian. We will store
; the LBA count as Little Endian, Low-order Word / High-order Word.
; The offset from the buffer are Words 60-61 (decimal).
;
; A table is used to index the offset of bytes to move into consecutive soft data.
;
                LDX     #$04            ;Set count for 4 bytes (2)
LBA_SIZE        LDY     LBA_OFFSET-1,X  ;Get Offset to LBA count (4)
                LDA     (LBA_ADDR_LOW),Y        ;Load LBA Data (5)
                STA     LOAD_IDE-1,X    ;Store to Soft Config Data (5)
                DEX                     ;Decrement count (2)
                BNE     LBA_SIZE        ;Loop back until done (2/3)
SET_CACHE_WR    LDA     #$02            ;Command for set write cache (2)
;
; Enable/Disable Write Cache for Microdrive (single call)
; - to use: A Reg contains $02 to enable or $82 to disable
;
IDE_SET_CACHE
                STA     IDE_FEATURE     ;Send to IDE controller (4)
                LDA     #%11100000      ;Get Drive 0, LBA. mode, etc. (2)
                STA     IDE_DRV_HEAD    ;Send to IDE controller (4)
                LDA     #$EF            ;Get Set Features Command (2)
                STA     IDE_COMMAND     ;Send Command to set feature (4)
                JSR     TST_IDE_RDY     ;Test for Drive ready (6)
                LDA     IDE_STATUS      ;Get Status (4)
                LDX     IDE_ERROR       ;Get Error (if any) (4)
                RTS                     ;Return to Caller (6)
;
; Reset IDE Controller and run Diagnostics
; The RECAL routine disables the IRQ function, so the routine to enable the IRQ
; is called, then drops into the get status routine before returning.
;
; Note: If an error occurs, the drive must be Reset to clear the error code!
; There are only 3 ways to clear a driver error:
; - Send a software reset command
; - Toggle the hardware Reset line
; - Perform a PowerOff/PowerOn sequence
;
; A software reset of the IDE controller is done by setting the SRST bit in the
; command register to a "1" for at least 5 microseconds, then clearing the SRST bit
; back to a "0".
;
; The IDE_RESET routine here will first perform a Software Reset to the controller,
; then issue a Drive Recalibrate command reset the Write Cache to on, then exit.
;
IDE_RESET                               ;Do a Reset of IDE device
                LDA     #%00000100      ;Get mask to set software reset (SRST bit) (2)
                STA     IDE_DEV_CTRL    ;Send to control register (4)
;
                LDA     #1              ;Setup timer for 10ms on MS delay (2)
                LDX     #0              ;Setup timer for 0 multiplier (2)
                LDY     #0              ; (2)
                JSR     SET_DLY         ;Call routine to set values (6)
                JSR     EXE_MSDLY       ;Execute 10ms delay (6)
;
                LDA#%0000000            ;Get mask to reset software reset (SRST bit) (2)
                STA     IDE_DEV_CTRL    ;Send to control register (4)
;
                JSR     IDE_RECAL       ;Call IDE_RESET (set LBA mode) (6)
                JSR     SET_CACHE_WR    ;Enable Write Cache (6)
                LDA     #%00001000      ;Get Mask to enable IRQ (2)
                STA     IDE_DEV_CTRL    ;Send to control register (4)
;
; Drop into Get Status routine after Diagnostics are run
;
IDE_GET_STATUS                          ;Get Status/Error registers from the IDE controller
;
; This routine gets the current status of the IDE Controller and can be issued at any time.
; It does not rely on any interrupt capability as it's a simple read of the Status and the
; Error registers from the IDE Controller.
;
; Note: This routine should be called whenever an Error has occurred. It returns the contents of
; the Error Register in the X Register and the contents of the Status Register in the A Register.
;
; Details for the Registers are:
;
; Error Register:
;Bit 7 - CRC Error or Bad Block error
;Bit 6 - Uncorrectable Data Error
;Bit 5 - 0 (not used) MC (used for Removable-Media drives)
;Bit 4 - ID Not Found
;Bit 3 - 0 (not used) MCR (used for Removable-Media drives)
;Bit 2 - Aborted Command error
;Bit 1 - Track Zero not found error
;Bit 0 - Data Address Mark Not Found
;
; Status Register:
;Bit 7 - Busy - IDE Controller is Busy (all other bits invalid)
;Bit 6 - Drive Ready (IDE Controller Ready to accept Commands)
;Bit 5 - Drive Write Fault - Write Fault error has occurred
;Bit 4 - Drive Seek Complete - is active when the drive is not seeking
;Bit 3 - Data Request - bit set when the IDE Controller has Data to transfer (R/W)
;Bit 2 - Correctable Data - bit set when bad data was found and corrected (ECC)
;Bit 1 - Index - bit toggled from 0 to 1 once per disk revolution
;Bit 0 - Error - bit set when previous command ended with some sort of error
;
                LDA     IDE_ALT_STATUS  ;Get IDE Alternate Status register (4)
                BMI     IDE_GET_STATUS  ;Loop until BUSY bit is clear (2/3)
;
                LDA     IDE_STATUS      ;Get IDE Status Register (4)
                LDX     IDE_ERROR       ;Get IDE Error Register (4)
                RTS                     ;Return to Caller (6)
;
IDE_DIAG                                ;Run internal Diagnostics on the IDE controller
;
;This is a basic self test for the IDE controller. This runs some internal tests for the
; IDE controller and returns with drive ready bits active ($50) and the error register as
; $01 if successful. For Diagnostics, the Error Register contains unique codes as follows:
;
;01h - No error Detected
;02h - Formatter device error
;03h - Sector Buffer error
;04h - ECC Circuitry error
;05h - Controller Microprocessor error
;8xH - Device 1 failed (not valid with a single drive system)
;
; Note: 80h ORed in for the Slave (second) Drive, lower bit definitions are the same!
;
                LDA     #$90            ;Get Diagnostic Command (2)
                BRA     IDE_SEND_CMD    ;Branch and send Command to IDE (3)
;
IDE_RECAL                               ;Recalibrate Command
;
;This is the Recalibrate Command ($1x). Upon issue the IDE controller will move the heads to
; Cylinder 0 and read Head 0, Sector 1. If unsuccessful, an error will be posted.
;
                LDA     #$10            ;Get Recalibrate Command (2)
;
IDE_SEND_CMD                            ;Send a Command to the IDE controller
;
;Accepts a Command code via the A reg and sets up the necessary IDE Controller
; registers to accept it. It also tests to ensure the controller is ready
; to accept the command and get the Status and Error registers on return.
;
                TAX                     ;Save Command to X Reg (2)
                JSR     TST_IDE_RDY     ;Wait for IDE to be ready (6)
                LDA     #%00001010      ;Get Mask to disable IRQ (2)
                STA     IDE_DEV_CTRL    ;Send to control register (4)
                LDA     #%11100000      ;Get Select Mask (LBA Mode, Drive 0) (2)
                STA     IDE_DRV_HEAD    ;Select Drive 0 (4)
;
                STX     IDE_COMMAND     ;Send command to IDE (4)
SEND_CMD_LP
                LDA     IDE_ALT_STATUS  ;Get IDE Alternate Status register (4)
                BMI     SEND_CMD_LP     ;Loop until BUSY bit is clear (2/3)
;
                LDA     IDE_STATUS      ;Get IDE Status Register (4)
                LDX     IDE_ERROR       ;Get IDE Error Register (4)
                RTS                     ;Return to caller (6)
;
; Enable Interrupts on the IDE Controller. This needs to be executed during initial setup
; and anytime the Reset/Diag BIOS function is called.
;
IDE_EN_IRQ                              ;Enable IDE Controller interrupt
                JSR     TST_IDE_RDY     ;Wait for IDE to be ready (6)
                LDA     #%00001000      ;Get Mask to enable IRQ (2)
                STA     IDE_DEV_CTRL    ;Send to control register (4)
                RTS                     ;Return to caller (6)
;
;**************************************************************************************************
;
;Interrupt 1 - This is the ISR which is responsible for servicing the IDE controller.
; The RTC does not require any ISR capabilities as no Alarm functions are being used in the BIOS.
; There are extra inserts which can be used if needed at a later date.
; The only functions that might make sense would be to add the Alarm function at a future date.
;
;The ISR for the IDE controller will handle the data transfer for LBA read/write functions
; and handle any error conditions. By design, the 16-bit Data Transfer feature is used for:
; Reading and Writing of all LBA block data and the IDE Identification data.
;
;The BIOS is using the Alternate Status register to determine if DRQ (Data Request) is active.
; This works as a handshake for 16-bit data transfers without issue. Note that the normal Status
; register resets the interrupt when read, so this is only done once in the ISR per loop.
;
;Update: This ISR has been moved to the front of the ISR chain, i.e., this ISR routine gets
; serviced first, then jumps to the next ISR, which services the DUART. This makes a noticeable
; improvement in data transfer from the IDE controller. Note that overhead for this routine will
; add 33 clock cycles if it just exits (IDE controller did not generate an interrupt).
;
;To check if an interrupt has been generated by the IDE controller, the Alternate Status register
; will be read. This contains the same information as the standard Status register but will NOT
; reset the interrupt on the IDE controller. By reading the Alternate Status register first, we
; can determine what the status of the IDE controller is and take action if required.
; Note that not all bit settings imply an interrupt was generated. Specifically, looking at the
; bit definitions below, Bits 6 and 4 are set when the IDE is ready, hence a normal condition
; where nothing requires any attention. Also, a Busy condition can imply the IDE controller is
; working on a command but may not have generated an interrupt yet. If The Busy bit (7) is set,
; then all other bits are invalid per Seagate documentation, so we test for that first.
;
;One annoying feature of IDE is "when" interrupts are generated. For any Read operation, once
; the command has been accepted, data is placed into the IDE buffer, followed by generating
; an interrupt to the system. Once this is done, the system will read the data. By accessing the
; Status register, the interrupt will be reset. This is normal operation. For a write operation,
; The command is sent, then DRQ goes active, which requires the data be sent to the IDE Device.
; Once the data is written, an interrupt is generated after it's writing is completed.
; As a result, there's little value of having an ISR for servicing the write function.
; As interrupts are enabled for the IDE Controller, all generated interrupts must be handled.
;
; Status Register bits as defined as follows:
;       - Bit 7 = Busy (a Command has been accepted)
;       - Bit 6 = Ready (IDE controller is ready to accept a command)
;       - Bit 5 = Write Fault (A write command failed against the media)
;       - Bit 4 = DSC (is set when a Seek is completed)
;       - Bit 3 = Data Request (set when there is data to transfer, read or write)
;       - Bit 2 = Correction (set when a recoverable data error was corrected)
;       - Bit 1 = 0 (not used)
;       - Bit 0 = Error (set when the previous command had an unrecoverable error)
;
;       NOTE: 25 clock cycles to here if DUART ISR is second!
;
INTERUPT1                               ;Interrupt 1 (IDE)
                LDA     IDE_ALT_STATUS  ;Get Alternate Status Register (4)
                BMI     REGEXT01        ;If Busy bit active, just exit (2/3)
;
; - Check for Data Request (DRQ), as the Read LBA operation is the main function
;   of the ISR, which will handle the data transfer from the IDE controller to store the
;   data into memory. This ISR will handle single and multiple block transfers.
;
                LDA     IDE_STATUS      ;Get Status (resets IRQ) (4)
                AND     #%00001000      ;Check for DRQ (2)
                BNE     IDE_READ_BLK    ;Branch if active (2/3)
;
;If no DRQ is sensed, the other possibility is a LBA Write has occurred and an IRQ
; was generated after the transfer. So we check for this and branch accordingly.
;
                BBS2    MATCH,IDE_WRIT_BLK      ;If Bit 2 set, Write operation (5/6,7)
                BRA     REGEXT01        ;Exit ISR handler (3)
;
IDE_READ_BLK                            ;IDE Read a Block of data
;
;Note: Arrival here means that the DRQ bit in the status register is active.
; This implies that:
;  1- A LBA Block Read is in progress. If so, the data transfer will be handled below.
;     This also handles multiple LBA Reads and manages the pointers and such. It also
;     clears the LBA Read bit in the MATCH Flag when completed.
;
;  2- A LBA Block Write with multilpe blocks is in progress. If so, the actual data
;     transfer is handled via the IDE WRITE Block routine. An interrupt is generated
;     at the end of each LBA transfer, so that is monitored here and the LBA Write bit
;     in the MATCH Flag is cleared when there are no more blocks to transfer.
;
;Also realize that this ISR will be executed every time the DUART generates an interrupt.
; This will happen every 10ms for the Jiffy-Clock timer and for character transmit and receive.
;
                BBR3    MATCH,REGEXT01  ;If Bit 3 clear, IDE Write (5/6,7)
;
LBA_XFER        LDA     IDE_ALT_STATUS  ;Get Status (4)
                AND     #%00001000      ;Check for DRQ (2)
                BEQ     IDE_RD_DONE     ;If not active, done, exit (2/3)
;
IDE_RD_RBLK
                LDA     IDE_DATA        ;Read low byte (high byte in latch) (4)
                STA     (BIOS_XFERL)    ;Store low byte (5)
                INC     BIOS_XFERL      ;Increment pointers (5)
                BNE     IDE_RD_BLK1     ; (2/3)
                INC     BIOS_XFERH      ; (5)
IDE_RD_BLK1
                LDA     IDE_16_READ     ;Read high byte from latch (4)
                STA     (BIOS_XFERL)    ;Store high byte (5)
                INC     BIOS_XFERL      ;Increment pointers (5)
                BNE     LBA_XFER        ;Loop back to Xfer, saves 3 clock cycles (2/3)
                INC     BIOS_XFERH      ; (5)
                BRA     LBA_XFER        ;Loop back till no more DRQs (3)
;
IDE_RD_DONE     DEC     BIOS_XFERC      ;Decrement Block Count to transfer (5)
                BNE     IDE_ALL_DONE    ;Branch around Flag Reset until all blocks moved (2/3)
                RMB3    MATCH           ;Clear Read Block flag (5)
;
IDE_ALL_DONE    LDA     IDE_ALT_STATUS  ;Get Alternate Status Register (4)
                STA     IDE_STATUS_RAM  ;Save it to RAM location (3)
REGEXT01        JMP     (VECINSRT0)     ;Exit ISR handler (6)
;
IDE_WRIT_BLK                            ;IDE Write a Block of data
                LDA     BIOS_XFERC      ;Check Block Count to transfer (3)
                BNE     IDE_ALL_DONE    ;Branch to exit if more blocks need to be moved (2/3)
                RMB2    MATCH           ;Clear Write Block flag (5)
                BRA     IDE_ALL_DONE    ;Branch and finish ISR (3)
;
;END OF BIOS CODE for Pages $F8 through $FD
;**************************************************************************************************
        .ORG    $FE00   ;Reserved for I/O space - do NOT put code here
;
;There are limited I/O selects for the C02 Pocket V3 hardware as below:
;
; I/O-0 = $FE00-$FE0F  NXP SC28L92 DUART (16 bytes)
; I/O-1 = $FE10-$FE1F  Maxim DS1318 Binary RTC (16 bytes)
; I/O-2 = $FE20-$FE2F  MicroDrive PATA with 16-bit Data Latch (16 bytes)
; I/O-3 = $FE30-$FE3F  Available for future hardware if needed (16 bits)
;
;**************************************************************************************************
;
        .ORG    $FE40   ;Reserved space for Soft Vector and I/O initialization data
;
;START OF BIOS DEFAULT VECTOR DATA AND HARDWARE CONFIGURATION DATA
;
;There are 192 bytes of ROM space remaining on page $FE from $FE40 - $FEFF
; 64 bytes of this are copied to page $02 and used for soft vectors/hardware soft configuration.
; 32 bytes are for vectors and 32 bytes are for hardware config. The last 32 bytes are only held
; in ROM and are used for hardware configuration that should not be changed.
;
;The default location for the NMI/BRK/IRQ Vector data is at $0200. They are defined at the top of
; the source file. There are 8 defined vectors and 8 vector inserts, all are free for base config.
;
;The default location for the hardware configuration data is at $0220. It is a freeform table which
; is copied from ROM to page $02. The allocated size for the hardware config table is 32 bytes.
;
VEC_TABLE      ;Vector table data for default ROM handlers
;
                .DW     NMI_VECTOR      ;NMI Location in ROM
                .DW     BRKINSTR0       ;BRK Location in ROM
                .DW     INTERUPT0       ;IRQ Location in ROM
;
                .DW     M_WARM_MON      ;NMI return handler in ROM
                .DW     M_WARM_MON      ;BRK return handler in ROM
                .DW     IRQ_EXIT0       ;IRQ return handler in ROM
;
                .DW     M_COLD_MON      ;Monitor Cold start
                .DW     M_WARM_MON      ;Monitor Warm start
;
;Vector Inserts (total of 8)
; These can be used as required. Note that the IDE init routine will use Insert 0 if a valid
; IDE controller is found and successfully initialized.
; Also, the NMI/BRK/IRQ and the Monitor routines are vectored, so these can also be extended,
; if needed, by using reserved vector locations.
;
                .DW     $FFFF           ;Insert 0 Location (used if IDE is found)
                .DW     $FFFF           ;Insert 1 Location
                .DW     $FFFF           ;Insert 2 Location
                .DW     $FFFF           ;Insert 3 Location
                .DW     $FFFF           ;Insert 4 Location
                .DW     $FFFF           ;Insert 5 Location
                .DW     $FFFF           ;Insert 6 Location
                .DW     $FFFF           ;Insert 7 Location
;
;Configuration Data - The following tables contains the default data used for:
; - Reset of the SC28L92 (RESET_28L92 routine)
; - Init of the SC28L92 (INIT_28L92 routine)
; - Basic details for register definitions are below, consult SC28L92 DataSheet
; - Note: Output Port bits OP0/OP1 must be set for RTS to work on Ports A and B
;
;Mode Register 0 definition
; Bit7          ;Rx Watchdog Control
; Bit6          ;RX-Int(2) Select
; Bit5/4        ;Tx-Int fill level
; Bit3          ;FIFO size
; Bit2          ;Baud Rate Extended II
; Bit1          ;Test 2 (don't use)
; Bit0          ;Baud Rate Extended I
;
;Mode Register 1 definition
; Bit7          ;RxRTS Control - 1 = Yes
; Bit6          ;RX-Int(1) Select
; Bit5          ;Error Mode - 0 = Character
; Bit4/3        ;Parity Mode - 10 = No Parity
; Bit2          ;Parity Type - 0 = Even (doesn't matter)
; Bit1/0        ;Bits Per Character - 11 = 8
;
;Mode Register 2 Definition
; Bit7/6        ;Channel Mode   - 00 = Normal
; Bit5          ;TxRTS Control - 0 = Yes
; Bit4          ;TxCTS Enable - 1 = Yes
; Bit3-0        ;Stop Bits - 0111 = 1 Stop Bit
;
;Baud Rate Clock Definition (Extended Mode I)
; Upper 4 bits = Receive Baud Rate
; Lower 4 bits = Transmit Baud Rate
; for 115.2K setting is %11001100
; Also set ACR Bit7 = 1 for extended rates (115.2K)
;
;Command Register Definition
; Bit7-4        ;Special commands
; Bit3          ;Disable Transmit
; Bit2          ;Enable Transmit
; Bit1          ;Disable Receive
; Bit0          ;Enable Receive
;
;Aux Control Register Definition
; Bit7          ;BRG Set Select - 1 = Extended
; Bit6-5-4      ;Counter/Timer operating mode 110 = Counter mode from XTAL
; Bit3-2-1-0    ;Enable IP3-2-1-0 Change Of State (COS) IRQ
;
;Interrupt Mask Register Definition
; Bit7          ;Input Change Interrupt 1 = On
; Bit6          ;Change Break B Interrupt 1 = On
; Bit5          ;RxRDY B Interrupt 1 = On
; Bit4          ;TxRDY B Interrupt 1 = On
; Bit3          ;Counter Ready Interrupt 1 = On
; Bit2          ;Change Break A Interrupt 1 = On
; Bit1          ;RxRDY A Interrupt 1 = On
; Bit0          ;TxRDY A Interrupt 1 = On
;
CFG_TABLE       ;Configuration table for hardware devices
;
;Data commands are sent in reverse order from list. This list is the default initialization for
; the DUART as configured for use as a Console connected to either ExtraPutty(WIN) or Serial(OSX)
; The data here is copied to page $02 and is used to configure the DUART during boot up. The soft
; data can be changed and the core INIT_28L92 routine can be called to reconfigure the DUART.
; NOTE: the register offset data is not kept in soft config memory as the initialization
; sequence should not be changed!
;
; Both serial ports are configured at startup!
; - Port A is used as the console.
; - Port B is in idle mode or used for Reader/Punch (DOS/65).
;
INIT_DUART       ;Start of DUART Initialization Data
                .DB     %00000011       ;Enable OP0/1 for RTS control Port A/B
                .DB     %00001010       ;Disable Receiver/Disable Transmitter B
                .DB     %00001001       ;Enable Receiver/Disable Transmitter A
                .DB     %00001111       ;Interrupt Mask Register setup
                .DB     %11100000       ;Aux Register setup for Counter/Timer
                .DB     %01001000       ;Counter/Timer Upper Preset
                .DB     %00000000       ;Counter/Timer Lower Preset
                .DB     %11001100       ;Baud Rate clock for Rcv/Xmt - 115.2K B
                .DB     %11001100       ;Baud Rate clock for Rcv/Xmt - 115.2K A
                .DB     %00110000       ;Reset Transmitter B
                .DB     %00100000       ;Reset Receiver B
                .DB     %00110000       ;Reset Transmitter A
                .DB     %00100000       ;Reset Receiver A
                .DB     %00000000       ;Interrupt Mask Register setup
                .DB     %11110000       ;Command Register A - disable Power Down
INIT_DUART_E    ;End of DUART Initialization Data
;
                .DB     $FF             ;Spare byte for offset to MR data
;
;Mode Register Data is defined separately. Using the loop routine above to send this data to
; the DUART does not work properly. See the description of the problem using Indexed addressing
; to load the DUART registers above. This data is also kept in soft config memory in page $02.
; Note that this data is also in reverse order for loading into MRs!
;
MR2_DAT_A       .DB     %00010111       ;Mode Register 2 data
MR1_DAT_A       .DB     %11010011       ;Mode Register 1 Data
MR0_DAT_A       .DB     %11111001       ;Mode Register 0 Data
;
MR2_DAT_B       .DB     %00010111       ;Mode Register 2 data
MR1_DAT_B       .DB     %11010011       ;Mode Register 1 Data
MR0_DAT_B       .DB     %11000001       ;Mode Register 0 Data
;
;Reserved for additional I/O devices (10 bytes free)
;
                .DB     $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
;
;Reset DUART Data is listed here. The sequence and commands do not require changes for any reason.
; These are maintained in ROM only. A total of 32 bytes are available for hard configuration data.
; These are the Register Offsets and Reset Data for the DUART.
;
UART_RDATA      ;DUART Reset Data for Received Break (ExtraPutty/Serial Break)
                .DB     %00000001       ;Enable Receiver
;
UART_RDATA1     ;Smaller list for entry level Reset (RESET_28L92)
                .DB     %01000000       ;Reset All Errors
                .DB     %00110000       ;Reset Transmitter
                .DB     %00100000       ;Reset Receiver
                .DB     %01010000       ;Reset Break Change Interrupt
UART_RDATAE     ;End of DUART Reset Data
;
INIT_OFFSET     ;Start of DUART Initialization Register Offsets
                .DB     $0E             ;Set Output Port bits
                .DB     $0A             ;Command Register B
                .DB     $02             ;Command Register A
                .DB     $05             ;Interrupt Mask Register
                .DB     $04             ;Aux Command Register
                .DB     $06             ;Counter Preset Upper
                .DB     $07             ;Counter Preset Lower
                .DB     $09             ;Baud Clock Register B
                .DB     $01             ;Baud Clock Register A
                .DB     $0A             ;Command Register Port B
                .DB     $0A             ;Command Register Port B
                .DB     $02             ;Command Register Port A
                .DB     $02             ;Command Register Port A
                .DB     $05             ;Interrupt Mask Register
                .DB     $02             ;Command Register Port A
INIT_OFFSETE    ;End of DUART Initialization Register Offsets
;
        .ORG    $FEA0   ;Reserved space for BIOS Text Data
;
; Text Data for the BIOS routines are located here at the end of page $FE.
; - 96 bytes are reserved.
;
; Text Messages for the BIOS used for IDE Boot:
;
NO_DRIVE_MSG
        .DB     "No IDE Device!",13,10,0        ;No Drive Found message
;
DRIVE_MSG
        .DB     "Drive Error!",13,10,0          ;No drive Found message
;
BPART_MSG
        .DB     "Bad Partition!",13,10,0        ;Incorrect Partition message
;
BOOT_INT
        .DB     "Press (ESC) to enter Monitor",13,10,0  ;Interrupt IDE Boot message
;
; Text Data for the BIOS Benchmark Ouput routine:
;
MSG_SEC
        .DB     " Seconds",13,10,0
;
;END OF BIOS VECTOR DATA AND HARDWARE DEFAULT CONFIGURATION DATA
;**************************************************************************************************
;START OF TOP PAGE - DO NOT MOVE FROM THIS ADDRESS!! JUMP Table starts here.
; - BIOS calls are listed below - total of 32, Reserved calls are for future hardware support.
; - "B_" JUMP Tables entries are for BIOS routines, provides isolation between BIOS and other code.
; - BIOS Version 5.x provides bootble support from an IDE controller (IBM/Hitachi Microdrive).
;
; NOTE: All Jump table calls add 3 clock cycles to execution time for each BIOS function.
;
        .ORG    $FF00   ;BIOS JMP Table, Cold Init and Vector handlers
;
B_IDE_RESET     JMP     IDE_RESET       ;Call 00 $FF00 (3)
B_IDE_GET_STAT  JMP     IDE_GET_STATUS  ;Call 01 $FF03 (3)
B_IDE_IDENTIFY  JMP     IDE_IDENTIFY    ;Call 02 $FF06 (3)
B_IDE_READ_LBA  JMP     IDE_READ_LBA    ;Call 03 $FF09 (3)
B_IDE_WRITE_LBA JMP     IDE_WRITE_LBA   ;Call 04 $FF0C (3)
B_IDE_SET_LBA   JMP     IDE_SET_LBA     ;Call 05 $FF0F (3)
B_IDE_SET_ADDR  JMP     IDE_SET_ADDRESS ;Call 06 $FF12 (3)
B_IDE_SET_CACHE JMP     IDE_SET_CACHE   ;Call 07 $FF15 (3)
;
B_CHR_STAT      JMP     CHR_STAT        ;Call 09 $FF18 (3)
B_CHRIN_NW      JMP     CHRIN_NW        ;Call 10 $FF1B (3)
B_CHRIN         JMP     CHRIN           ;Call 11 $FF1E (3)
B_CHROUT        JMP     CHROUT          ;Call 12 $FF21 (3)
;
B_CHRIN2        JMP     CHRIN2          ;Call 13 $FF24 (3)
B_CHROUT2       JMP     CHROUT2         ;Call 14 $FF27 (3)
;
B_CNT_INIT      JMP     CNT_INIT        ;Call 15 $FF2A (3)
B_CNT_STRT      JMP     CNT_STRT        ;Call 16 $FF2D (3)
B_CNT_STOP      JMP     CNT_STOP        ;Call 17 $FF30 (3)
B_CNT_DISP      JMP     CNT_DISP        ;Call 18 $FF33 (3)
;
B_SET_DLY       JMP     SET_DLY         ;Call 19 $FF36 (3)
B_EXE_MSDLY     JMP     EXE_MSDLY       ;Call 20 $FF39 (3)
B_EXE_LGDLY     JMP     EXE_LGDLY       ;Call 21 $FF3C (3)
;
B_PROMPTR       JMP     PROMPTR         ;Call 23 $FF3F (3)
;
B_RTC_INIT      JMP     INIT_RTC        ;Call 08 $FF42 (3)
;
B_PRSTAT        JMP     PRSTAT          ;Call 24 $FF45 (3)
;
B_RESERVE0      JMP     RESERVE         ;Call 24 $FF48 (3)
;
B_INIT_VEC      JMP     INIT_VEC        ;Call 25 $FF4B (3)
B_INIT_CFG      JMP     INIT_CFG        ;Call 26 $FF4E (3)
;
B_INIT_28L92    JMP     INIT_28L92      ;Call 27 $FF51 (3)
B_RESET_28L92   JMP     RESET_28L92     ;Call 28 $FF54 (3)
;
B_PANIC         JMP     NMI_VECTOR      ;Call 29 $FF57 (3)
B_IDE_BOOT      JMP     IDE_BOOT        ;Call 30 $FF5A (3)
;
B_COLDSTRT                              ;Call 31 $FF5D
                SEI                     ;Disable Interrupts (safety) (2)
                CLD                     ;Clear decimal mode (safety) (2)
                LDX     #$00            ;Index for length of page (256 bytes) (2)
PAGE0_LP        STZ     $00,X           ;Clear Page Zero (4)
                DEX                     ;Decrement index (2)
                BNE     PAGE0_LP        ;Loop back till done (2/3)
                DEX                     ;LDX #$FF ;-) (2)
                TXS                     ;Set Stack Pointer (2)
;
                JSR     INIT_PG02       ;Xfer default Vectors/HW Config to Page $02 (6)
                JSR     INIT_IO         ;Init I/O - DUART (Console/Timer) (6)
;
; Send BIOS init msg to console - note: X Reg is zero on return from INIT_IO
;
BMSG_LP         LDA     BIOS_MSG,X      ;Get BIOS init msg (4)
                BEQ     CHECK_IO        ;If zero, msg done, Test for extra I/O (2/3)
                JSR     CHROUT          ;Send to console (6)
                INX                     ;Increment Index (2)
                BRA     BMSG_LP         ;Loop back until done (3)
CHECK_IO
                JSR     DETECT_RTC      ;Detect and Init RTC (6)
                JSR     DETECT_IDE      ;Detect and Init IDE (6)
                JSR     RESERVE         ;Reserve one more Init routine for future use (6)
                BRA     B_IDE_BOOT      ;Branch to Boot IDE device (3)
;
;This front end for the IRQ vector, saves the CPU registers and determines if a BRK instruction
; was the cause. There are 25 clock cycles to jump to the IRQ vector, and there are 26 clock cycles
; to jump to the BRK vector. Note that there is an additional 18 clock cycles for the IRQ return
; vector, which restores the registers. This creates an overhead of 43 (IRQ) or 44 (BRK) clock
; cycles, plus whatever the ISR or BRK service routines add.
;
IRQ_VECTOR                              ;This is the ROM start for the BRK/IRQ handler
                PHA                     ;Save A Reg (3)
                PHX                     ;Save X Reg (3)
                PHY                     ;Save Y Reg (3)
                TSX                     ;Get Stack pointer (2)
                LDA     $0100+4,X       ;Get Status Register (4)
                AND     #$10            ;Mask for BRK bit set (2)
                BNE     DO_BRK          ;If set, handle BRK (2/3)
                JMP     (IRQVEC0)       ;Jump to Soft vectored IRQ Handler (6)
DO_BRK          JMP     (BRKVEC0)       ;Jump to Soft vectored BRK Handler (6)
;
NMI_ROM         JMP     (NMIVEC0)       ;Jump to Soft vectored NMI handler (6)
;
;This is the standard return for the IRQ/BRK handler routines (18 clock cycles)
;
IRQ_EXIT0       PLY                     ;Restore Y Reg (4)
                PLX                     ;Restore X Reg (4)
                PLA                     ;Restore A Reg (4)
                RTI                     ;Return from IRQ/BRK routine (6)
;
INIT_PG02       JSR     INIT_VEC        ;Init the Soft Vectors first (6)
INIT_CFG        LDY     #$40            ;Get offset to Config data (2)
                BRA     DATA_XFER       ;Go move the Config data to page $02 (3)
;
INIT_VEC        LDY     #$20            ;Get offset to Vector data (2)
DATA_XFER       SEI                     ;Disable Interrupts, can be called via JMP table (2)
                LDX     #$20            ;Set count for 32 bytes (2)
DATA_XFLP       LDA     VEC_TABLE-1,Y   ;Get ROM table data (4)
                STA     SOFTVEC-1,Y     ;Store in Soft table location (4)
                DEY                     ;Decrement index (2)
                DEX                     ;Decrement count (2)
                BNE     DATA_XFLP       ;Loop back till done (2/3)
                CLI                     ;Re-enable interrupts (2)
RESERVE         RTS                     ;Return to caller (6)
;
RTC_MSG
;
;This is a short BIOS message that is displayed when the DS1318 RTC is found
                .DB     "RTC found"
                .DB     $0D,$0A,$00
;
IDE_MSG
;
;This is a short BIOS message that is displayed when the IDE controller is found
                .DB     "IDE found"
                .DB     $0D,$0A,$00
;
;The offset data here is used as an index to the Identity Block of Data from the IDE controller
LBA_OFFSET      .DB     120,121,122,123 ;Offset Data for LBA Size
;
;This BIOS version does not rely on CPU clock frequency for RTC timing. Timing is based on the
; SC28L92 DUART Timer/Counter which has a fixed frequency of 3.6864MHz. Jiffy clock set at 10ms.
; Edit Displayed clock rate at CPU_CLK below as needed if running "other" than 8MHz.
;
        .ORG    $FFD0   ;Hard coded BIOS message to the top of memory (Monitor uses this)
;
;BIOS init message - sent before jumping to the monitor coldstart vector.
; Changed for BIOS 5.x release, as CPU clock speeds can exceed 10MHz.
; - BIOS version is "5.x" while CPU speed is now two digits.
;
BIOS_MSG        .DB     $0D,$0A         ;CR/LF
                .DB     "C02BIOS 5.1"   ;Updated Release Version
                .DB     $0D,$0A         ;CR/LF
                .DB     "W65C02@"       ;Display CPU type
CPU_CLK         .DB     "8MHz "         ;Displayed CPU Clock frequency
                .DB     $0D,$0A         ;CR/LF
                .DB     "04/04/2026"    ;DD/MM/YYYY
                .DB     $0D,$0A,$00     ;CR/LF and terminate string
;
        .ORG    $FFFA   ;W65C02 Vectors:
;
                .DW     NMI_ROM         ;NMI
                .DW     B_COLDSTRT      ;RESET
                .DW     IRQ_VECTOR      ;IRQ/BRK
        .END
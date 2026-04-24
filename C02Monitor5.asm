;**************************************************************************************************
;*   C02Monitor 5.1 - Release version for Pocket SBC  (c)2013-2026 by Kevin E. Maier 04/04/2026   *
;*                                                                                                *
;*  Monitor Functions are divided into groups as follows:                                         *
;*   1. Memory Operations:                                                                        *
;*      - Fill Memory: Source, Length, Value (prompts for commit)                                 *
;*      - Move Memory: Source, Target, Length (prompts for commit)                                *
;*      - Compare Memory: Source, Target, Length                                                  *
;*      - Display Memory as Hex/ASCII: Address start - 256 consecutive bytes displayed            *
;*      - Execute from Memory: Start address                                                      *
;*                                                                                                *
;*   2. Register Operations:                                                                      *
;*      - Display All Registers                                                                   *
;*      - Display/Edit A, X, Y, (S)tack Pointer, (P)rocessor Status                               *
;*                                                                                                *
;*   3. Timer/Counter Functions: (C02BIOS)                                                        *
;*      - RTC function based on 10ms Jiffy Clock: Ticks plus 32-bit binary counter                *
;*      - Benchmark timing up to 65535.99 seconds with 10ms resolution                            *
;*                                                                                                *
;*   5. Control-Key Functions:                                                                    *
;*      - CTRL-B: Starts Rich Leary's DOS/65 my RAM Version 3.21                                  *
;*      - CTRL-L: Xmodem Loader w/CRC-16 Support, auto detect S19 Records from WDC Linker         *
;*      - CTRL-R: Reset System - Initiates Cold Start of BIOS and Monitor                         *
;*      - CTRL-Z: Zeros out ALL RAM and initiates Cold Start of BIOS and Monitor                  *
;*                                                                                                *
;*   6. Panic Button (NMI Support Routine in C02BIOS)                                             *
;*      - Re-initializes Vector and Configuration Data in Page $03                                *
;*      - Clears Console Buffer pointers in Page $00 and restarts Console only                    *
;**************************************************************************************************
        PL      66      ;Page Length
        PW      132     ;Page Width (# of char/line)
        CHIP    W65C02S ;Enable WDC 65C02 instructions
        PASS1   OFF     ;Set ON for debugging
        INCLIST ON      ;Set ON for listing Include files
;**************************************************************************************************
; Page Zero definitions $00 to $9F reserved for user routines
; NOTES:- Locations $00 and $01 are used to zero RAM (calls CPU reset)
;       - EEPROM Byte Write routine loaded into Page Zero at $88-$9C
;       - Enhanced Basic uses locations $00 - $85
;**************************************************************************************************
;
; This BIOS and Monitor version also use a common source file for constants and variables used by
; both. This just simplifies keeping both code pieces in sync.
;
        INCLUDE         C02Constants5.asm
;
;**************************************************************************************************
;
; Note: The hardware configuration has been changed to increase the available RAM in the system!
;       This change (PLD reconfig) results in 56KB of RAM and reduced EEPROM to 8KB. This is done
;       to provide a larger TEA for the bootable RAM version of DOS/65. This change results in the
;       code to write to the EEPROM insitu no longer working. This is due to the unlock sequence
;       needed, as it requires a minimum of 22KB addressable memory space. For now, any EEPROM
;       changes required must be done by using a programmer.
;
;**************************************************************************************************
;The following 32 functions are provided by BIOS via the JMP Table below
;**************************************************************************************************
;BIOS JUMP Table starts here:
;       - BIOS calls are listed below - total of 32
;       - Reserved calls are for future hardware support
;
; $FF00 IDE_RESET       ;Reset IDE Controller (Recalibrate Command)
; $FF03 IDE_GET_STAT    ;Get Status and Error code
; $FF06 IDE_IDENTIFY    ;Load IDE Identity Data at $0600
; $FF09 IDE_READ_LBA    ;Read LBA into memory
; $FF0C IDE_WRITE_LBA   ;Write LBA from memory
; $FF0F IDE_SET_LBA     ;Set LBA number (24-bit support only)
; $FF12 IDE_SET_ADDR    ;Set LBA transfer address (16-bit plus block count)
; $FF15 IDE_EN_CACHE    ;Enable/Disable IDE Write Cache
;
; $FF18 CHT_STAT        ;Status for Console - A reg is non-zero is data exists
; $FF1B CHRIN_NW        ;Data input from console, no waiting, clear carry if none
; $FF1E CHRIN           ;Data input from console
; $FF21 CHROUT          ;Data output to console
;
; $FF24 CHRIN2          ;Data input from aux port
; $FF27 CHROUT2         ;Data output to aux port
;
; $FF2A CNT_INIT        ;Reset Benchmark timing counters/Start 10ms benchmark timer
; $FF2D CNT_STRT        ;Start 10ms benchmark timing counter
; $FF30 CNT_STOP        ;Stop 10ms benchmark timing counter
; $FF33 CNT_DISP        ;Display benchmark counter timing (code added from C02 Monitor)
;
; $FF36 SET_DLY         ;Set delay value for milliseconds and 16-bit counter
; $FF39 EXE_MSDLY       ;Execute millisecond delay 1-256 * 10 milliseconds
; $FF3C EXE_LGDLY       ;Execute long delay; millisecond delay * 16-bit count
;
; $FF3F RTC_INIT        ;Check for RTC chip and Initialize thr RTC variables
;
; $FF42 PROMPTR         ;Print a String from A/Y registers
;
; $FF45 PRSTAT          ;Show CPU Status
;
; $FF48 Reserved        ;Reserved for future expansion
;
; $FF4B INIT_VEC        ;Initialize soft vectors at $0300 from ROM
; $FF4E INIT_CFG        ;Initialize soft config values at $0320 from ROM
;
; $FF51 INIT_28L92      ;Initialize SC28L92 - Port A as console at 115.2K, 8-N-1 RTS/CTS
; $FF54 RESET_28L92     ;Reset SC28L92 - called before INIT_28L92
;
; $FF57 PANIC           ;Execute PANIC routine
; $FF5A BOOT_IDE        ;Boot IDE device - load LBA 0 to $0800 and jump to it
;
; $FF5D COLDSTRT        ;System cold start - RESET vector for 65C02
;
;**************************************************************************************************
;
B_IDE_RESET             .EQU    $FF00   ;Call 00
B_IDE_GET_STAT          .EQU    $FF03   ;Call 01
B_IDE_IDENTIFY          .EQU    $FF06   ;Call 02
B_IDE_READ_LBA          .EQU    $FF09   ;Call 03
B_IDE_WRITE_LBA         .EQU    $FF0C   ;Call 04
B_IDE_SET_LBA           .EQU    $FF0F   ;Call 05
B_IDE_SET_ADDR          .EQU    $FF12   ;Call 06
B_IDE_EN_CACHE          .EQU    $FF15   ;Call 07
;
B_CHR_STAT              .EQU    $FF18   ;Call 08
B_CHRIN_NW              .EQU    $FF1B   ;Call 09
B_CHRIN                 .EQU    $FF1E   ;Call 10
B_CHROUT                .EQU    $FF21   ;Call 11
;
B_CHRIN2                .EQU    $FF24   ;Call 12
B_CHROUT2               .EQU    $FF27   ;Call 13
;
B_CNT_INIT              .EQU    $FF2A   ;Call 14
B_CNT_STRT              .EQU    $FF2D   ;Call 15
B_CNT_STOP              .EQU    $FF30   ;Call 16
B_CNT_DISP              .EQU    $FF33   ;Call 17
;
B_SET_DLY               .EQU    $FF36   ;Call 18
B_EXE_MSDLY             .EQU    $FF39   ;Call 19
B_EXE_LGDLY             .EQU    $FF3C   ;Call 20
;
B_PROMPTR               .EQU    $FF3F   ;Call 21
;
B_RTC_INIT              .EQU    $FF42   ;Call 22
;
B_PRSTAT                .EQU    $FF45   ;Call 23
;
B_RESERVE0              .EQU    $FF48   ;Call 24
;
B_INIT_VEC              .EQU    $FF4B   ;Call 25
B_INIT_CFG              .EQU    $FF4E   ;Call 26
;
B_INIT_28L92            .EQU    $FF51   ;Call 27
B_RESET_28L92           .EQU    $FF54   ;Call 28
;
B_WRMMNVEC0             .EQU    $FF57   ;Call 29
B_CLDMNVEC0             .EQU    $FF5A   ;Call 30
;
B_COLDSTRT              .EQU    $FF5D   ;Call 31
;
BIOS_MSG                .EQU    $FFD0   ;BIOS Startup Message is hard-coded here
;**************************************************************************************************
        .ORG $F000                      ;2KB reserved for Monitor ($F000 through $F7FF)
;**************************************************************************************************
;Monitor JUMP Table starts here:
;       - Monitor calls are listed below - total of 2
;       - Reserved calls are for future Monitor functions
;
M_COLD_MON      JMP     COLD_MON        ;Call 00 $F000
M_WARM_MON      JMP     WARM_MON        ;Call 01 $F003
;
;START OF MONITOR CODE
;**************************************************************************************************
;*                      This is the Monitor Cold start vector                                     *
;**************************************************************************************************
COLD_MON        LDA     #$00            ;Get intro msg / BEEP / Query
                JSR     PROMPT          ;Send to Console
;
;**************************************************************************************************
;*                              Command input loop                                                *
;**************************************************************************************************
;*                      This is the Monitor Warm start vector                                     *
;**************************************************************************************************
WARM_MON        LDX     #$FF            ;Initialize Stack pointer
                TXS                     ;Xfer to stack
                RMB7    CMDFLAG         ;Clear bit7 of command flag
                LDA     #$01            ;Get prompt msg
                JSR     PROMPT          ;Send to terminal
;
CMON            JSR     RDCHAR          ;Wait for keystroke (converts to upper-case)
                LDX     #MONTAB-MONCMD-1        ;Get command list count
CMD_LP          CMP     MONCMD,X        ;Compare to command list
                BNE     CMD_DEC         ;Check for next command and loop
                PHA                     ;Save keystroke
                TXA                     ;Xfer Command index to A Reg
                ASL     A               ;Multiply keystroke value by 2 (command offset)
                TAX                     ;Xfer Command offset address to table MONTAB
                PLA                     ;Restore keystroke (some commands send to terminal)
                JSR     DOCMD           ;Call Monitor command processor as a subroutine
                BRA     WARM_MON        ;Command processed, branch / wait for next command
DOCMD           JMP     (MONTAB,X)      ;Execute command from Table
;
CMD_DEC         DEX                     ;Decrement index count
                BPL     CMD_LP          ;If more to check, loop back
                JSR     BEEP            ;Beep for error, not valid command character
                BRA     CMON            ;Branch back and re-enter Monitor
;
;**************************************************************************************************
;*                      Basic Subroutines used by multiple routines                               *
;**************************************************************************************************
;
;ASC2BIN subroutine: Convert 2 ASCII HEX digits to a binary (byte) value
; Enter: A Register = high digit, Y Register = low digit
; Return: A Register = binary value
; Updated routine via Mike Barry... saves 3 bytes, 10 clock cycles
ASC2BIN         STZ     TEMP1           ;Clear TEMP1
                JSR     BINARY          ;Convert high digit to 4-bit nibble
                ASL     A               ;Shift to high nibble
                ASL     A
                ASL     A
                ASL     A
                STA     TEMP1           ;Store it in temp area
                TYA                     ;Get Low digit
;
BINARY          EOR     #$30            ;ASCII -> HEX nibble
                CMP     #$0A            ;Check for result < 10
                BCC     BNOK            ;Branch if 0-9
                SBC     #$67            ;Else subtract for A-F
BNOK            ORA     TEMP1           ;OR in temp value
RESERVED        RTS                     ;Return to caller
;
;BIN2ASC subroutine: Convert single byte to two ASCII HEX digits
; Enter: A Register contains byte value to convert
; Return: A Register = high digit, Y Register = low digit
BIN2ASC         PHA                     ;Save A Reg on stack
                AND     #$0F            ;Mask off high nibble
                JSR     ASCII           ;Convert nibble to ASCII HEX digit
                TAY                     ;Move to Y Reg
                PLA                     ;Get character back from stack
                LSR     A               ;Shift high nibble to lower 4 bits
                LSR     A
                LSR     A
                LSR     A
;
ASCII           CMP     #$0A            ;Check for 10 or less
                BCC     ASCOK           ;Branch if less than 10
                ADC     #$06            ;Add $06+CF ($07) for A-F
ASCOK           ADC     #$30            ;Add $30 for ASCII
                RTS                     ;Return to caller
;
;PROMPT routine: Send indexed text string to terminal. Index is contained in A Reg.
; String buffer address is stored in variable PROMPTL/PROMPTH.
PROMPT          ASL     A               ;Multiply by two for msg table index
                TAX                     ;Xfer to X Reg - index
                LDA     MSG_TABLE,X     ;Get low byte address
                LDY     MSG_TABLE+1,X   ;Get high byte address
                JMP     B_PROMPTR       ;Use BIOS routine to send message/return
;
;SETUP subroutine: Request HEX address input from terminal
SETUP           JSR     B_CHROUT        ;Send command keystroke to terminal
                JSR     SPC             ;Send [SPACE] to terminal
                BRA     HEXIN4          ;Request a 0-4 digit HEX address input from terminal
;
;HEX input subroutines: Request 1 to 4 ASCII HEX digits from terminal, then convert digits into
; a binary value. For 1 to 4 digits entered, HEXDATAH and HEXDATAL contain the output.
; Variable BUFIDX will contain the number of digits entered
; HEXIN2 - returns value in A Reg and Y Reg only (Y Reg always $00)
; HEXIN4 - returns values in A Reg, Y Reg and INDEXL/INDEXH
; HEX2 - Prints MSG# in A Reg then calls HEXIN2, HEX4 - Prints MSG# in A Reg then calls HEXIN4
HEX4            JSR     PROMPT          ;Print MSG # from A Reg
HEXIN4          LDX     #$04            ;Set for number of characters allowed
                JSR     HEXINPUT        ;Convert digits
                STY     INDEXH          ;Store to INDEXH
                STA     INDEXL          ;Store to INDEXL
                RTS                     ;Return to caller
;
HEX2            JSR     PROMPT          ;Print MSG # from A Reg
HEXIN2          LDX     #$02            ;Set for number of characters allowed
;
;HEXINPUT subroutine: request 1 to 4 HEX digits from terminal, then convert ASCII HEX to HEX
; minor update from Mike Barry, saves a byte.
; Setup RDLINE subroutine parameters:
HEXINPUT        JSR     DOLLAR          ;Send "$" to console
                JSR     RDLINE          ;Request ASCII HEX input from terminal
                BEQ     HINEXIT         ;Exit if none (Z flag already set)
                STZ     HEXDATAH        ;Clear Upper HEX byte, Lower HEX byte will be updated
                LDY     #$02            ;Set index for 2 bytes
ASCLOOP         PHY                     ;Save it to stack
                LDA     INBUFF-1,X      ;Read ASCII digit from buffer
                TAY                     ;Xfer to Y Reg (LSD)
                DEX                     ;Decrement input count
                BEQ     NO_UPNB         ;Branch if no upper nibble
                LDA     INBUFF-1,X      ;Read ASCII digit from buffer
                BRA     DO_UPNB         ;Branch to include upper nibble
NO_UPNB         LDA     #$30            ;Load ASCII "0" (MSD)
DO_UPNB         JSR     ASC2BIN         ;Convert ASCII digits to binary value
                PLY                     ;Get index from stack
                STA     HEXDATAH-1,Y    ;Write byte to indexed buffer location
                TXA                     ;Check for zero, (no digits left)
                BEQ     HINDONE         ;If not, exit
                DEY                     ;Else, decrement to next byte set
                DEX                     ;Decrement index count
                BNE     ASCLOOP         ;Loop back for next byte
HINDONE         LDY     HEXDATAH        ;Get High Byte
                LDA     HEXDATAL        ;Get Low Byte
                LDX     BUFIDX          ;Get input count (set Z flag)
HINEXIT         RTS                     ;And return to caller
;
;RDLINE subroutine: Store keystrokes into buffer until [RETURN] key is struck
; Used for Hex entry, so only (0-9,A-F) are accepted entries. Lower-case alpha characters
; are converted to upper-case. On entry, X Reg = buffer length. On exit, X Reg = buffer count
; [BACKSPACE] key removes keystrokes from buffer. [ESCAPE] key aborts then re-enters monitor.
RDLINE          STX     BUFLEN          ;Store buffer length
                STZ     BUFIDX          ;Zero buffer index
RDLOOP          JSR     RDCHAR          ;Get character from terminal, convert LC2UC
                CMP     #$1B            ;Check for ESC key
                BEQ     RDNULL          ;If yes, exit back to Monitor
NOTESC          CMP     #$0D            ;Check for C/R
                BEQ     EXITRD          ;Exit if yes
                CMP     #$08            ;Check for Backspace
                BEQ     RDBKSP          ;If yes handle backspace
                CMP     #$30            ;Check for '0' or higher
                BCC     INPERR          ;Branch to error if less than '0'
                CMP     #$47            ;Check for 'G' ('F'+1)
                BCS     INPERR          ;Branch to error if 'G' or higher
                LDX     BUFIDX          ;Get the current buffer index
                CPX     BUFLEN          ;Compare to length for space
                BCC     STRCHR          ;Branch to store in buffer
INPERR          JSR     BEEP            ;Else, error, send Bell to terminal
                BRA     RDLOOP          ;Branch back to RDLOOP
STRCHR          STA     INBUFF,X        ;Store keystroke in buffer
                JSR     B_CHROUT        ;Send keystroke to terminal
                INC     BUFIDX          ;Increment buffer index
                BRA     RDLOOP          ;Branch back to RDLOOP
RDBKSP          LDA     BUFIDX          ;Check if buffer is empty
                BEQ     INPERR          ;Branch if yes
                DEC     BUFIDX          ;Else, decrement buffer index
                JSR     BSOUT           ;Send Backspace to terminal
                BRA     RDLOOP          ;Loop back and continue
EXITRD          LDX     BUFIDX          ;Get keystroke count (Z flag)
                BNE     UCOK            ;If data entered, normal exit
                BBS7    CMDFLAG,UCOK    ;Branch if bit7 of command flag active
RDNULL          JMP     (WRMMNVEC0)     ;Quit to Monitor warm start
;
;RDCHAR subroutine: Waits for a keystroke to be entered.
; if keystroke is a lower-case alphabetical, convert it to upper-case
RDCHAR          JSR     B_CHRIN         ;Request keystroke input from terminal
                CMP     #$61            ;Check for lower case value range
                BCC     UCOK            ;Branch if < $61, control code/upper-case/numeric
                SBC     #$20            ;Subtract $20 to convert to upper case
UCOK            RTS                     ;Character received, return to caller
;
;Routines to update pointers for memory operations. UPD_STL subroutine: Increments Source
; and Target pointers. UPD_TL subroutine: Increments Target pointers only, then drops into
; decrement Length pointer. Used by multiple Memory operation commands.
UPD_STL         INC     SRCL            ;Increment source low byte
                BNE     UPD_TL          ;Check for rollover
                INC     SRCH            ;Increment source high byte
UPD_TL          INC     TGTL            ;Increment target low byte
                BNE     DECLEN          ;Check for rollover
                INC     TGTH            ;Increment target high byte
;
;DECLEN subroutine: decrement 16-bit variable LENL/LENH
DECLEN          LDA     LENL            ;Get length low byte
                BNE     SKP_LENH        ;Test for LENL = zero
                DEC     LENH            ;Else decrement length high byte
SKP_LENH        DEC     LENL            ;Decrement length low byte
                RTS                     ;Return to caller
;
;DECINDEX subroutine: decrement 16 bit variable INDEXL/INDEXH
DECINDEX        LDA     INDEXL          ;Get index low byte
                BNE     SKP_IDXH        ;Test for INDEXL = zero
                DEC     INDEXH          ;Decrement index high byte
SKP_IDXH        DEC     INDEXL          ;Decrement index low byte
                RTS                     ;Return to caller
;
;INCINDEX subroutine: increment 16 bit variable INDEXL/INDEXH
INCINDEX        INC     INDEXL          ;Increment index low byte
                BNE     SKP_IDX         ;If not zero, skip high byte
                INC     INDEXH          ;Increment index high byte
SKP_IDX         RTS                     ;Return to caller
;
;Output routines for formatting, backspace, CR/LF, BEEP, etc.
; all routines preserve the A Reg on exit.
;
;BEEP subroutine: Send ASCII [BELL] to terminal
BEEP            PHA                     ;Save A Reg on Stack
                LDA     #$07            ;Get ASCII [BELL] to terminal
                BRA     SENDIT          ;Branch to send
;
;BSOUT subroutine: send a Backspace to terminal
BSOUT           JSR     BSOUT2          ;Send an ASCII backspace
                JSR     SPC             ;Send space to clear out character
BSOUT2          PHA                     ;Save character in A Reg
                LDA     #$08            ;Send another Backspace to return
BRCHOUT         BRA     SENDIT          ;Branch to send
;
BSOUT3T         JSR     BSOUT2          ;Send a Backspace 3 times
BSOUT2T         JSR     BSOUT2          ;Send a Backspace 2 times
                BRA     BSOUT2          ;Send a Backspace and return
;
;SPC subroutines: Send a Space to terminal 1,2 or 4 times
SPC4            JSR     SPC2            ;Send 4 Spaces to terminal
SPC2            JSR     SPC             ;Send 2 Spaces to terminal
SPC             PHA                     ;Save character in A Reg
                LDA     #$20            ;Get ASCII Space
                BRA     SENDIT          ;Branch to send
;
;DOLLAR subroutine: Send "$" to terminal
DOLLAR          PHA                     ;Save A Reg on STACK
                LDA     #$24            ;Get ASCII "$"
                BRA     SENDIT          ;Branch to send
;
;Send 2 CR/LFs to terminal
CR2             JSR     CROUT           ;Send CR/LF to terminal
;Send CR/LF to terminal
CROUT           PHA                     ;Save A Reg
                LDA     #$0D            ;Get ASCII Return
                JSR     B_CHROUT        ;Send to terminal
                LDA     #$0A            ;Get ASCII Linefeed
SENDIT          JSR     B_CHROUT        ;Send to terminal
                PLA                     ;Restore A Reg
                RTS                     ;Return to caller
;
;GLINE subroutine: Send a horizontal line to console used by memory display only.
GLINE           LDX     #$4F            ;Load index for 79 decimal
                LDA     #$7E            ;Get "~" character
GLINEL          JSR     B_CHROUT        ;Send to terminal (draw a line)
                DEX                     ;Decrement count
                BNE     GLINEL          ;Branch back until done
                RTS                     ;Return to caller
;
;Routines to output 8/16-bit Binary Data and ASCII characters
; PRASC subroutine: Print A-Reg as ASCII (Printable ASCII values = $20 - $7E), else print "."
PRASC           CMP     #$7F            ;Check for first 128
                BCS     PERIOD          ;If = or higher, branch
                CMP     #$20            ;Check for control characters
                BCS     ASCOUT          ;If space or higher, branch and print
PERIOD          LDA     #$2E            ;Else, print a "."
ASCOUT          JMP     B_CHROUT        ;Send byte in A-Reg, then return
;
;PRBYTE subroutine: Converts a single Byte to 2 HEX ASCII characters and sends to console on
; entry, A Reg contains the Byte to convert/send. Register contents are preserved on entry/exit.
PRBYTE          PHA                     ;Save A Register
                PHY                     ;Save Y Register
PRBYT2          JSR     BIN2ASC         ;Convert A Reg to 2 ASCII Hex characters
                JSR     B_CHROUT        ;Print high nibble from A Reg
                TYA                     ;Transfer low nibble to A Reg
                JSR     B_CHROUT        ;Print low nibble from A Reg
                PLY                     ;Restore Y Register
                PLA                     ;Restore A Register
                RTS                     ;Return to caller
;
;PRINDEX subroutine: Prints a $ sign followed by INDEXH/L
PRINDEX         JSR     DOLLAR          ;Print a $ sign
                LDA     INDEXL          ;Get Index Low byte
                LDY     INDEXH          ;Get Index High byte
;
;PRWORD subroutine: Converts a 16-bit word to 4 HEX ASCII characters and sends to console. On
; entry, A Reg contains Low Byte, Y Reg contains High Byte. Registers are preserved on entry/exit.
; NOTE: Routine changed for consistency; A Reg = Low byte, Y Reg = High byte on 2nd May 2020
PRWORD          PHA                     ;Save A Register (Low)
                PHY                     ;Save Y Register (High)
                PHA                     ;Save Low byte again
                TYA                     ;Xfer High byte to A Reg
                JSR     PRBYTE          ;Convert and print one HEX character (00-FF)
                PLA                     ;Get Low byte value
                BRA     PRBYT2          ;Finish up Low Byte and exit
;
;Continue routine: called by commands to confirm execution, when No is confirmed, return address
;is removed from stack and the exit goes back to the Monitor input loop.
;Short version prompts for (Y/N) only.
CONTINUE        LDA     #$02            ;Get msg "cont? (Y/N)" to terminal
                JSR     PROMPT          ;Send to terminal
TRY_AGN         JSR     RDCHAR          ;Get keystroke from terminal
                CMP     #$59            ;"Y" key?
                BEQ     DOCONT          ;If yes, continue/exit
                CMP     #$4E            ;If "N", quit/exit
                BEQ     DONTCNT         ;Return if not ESC
                JSR     BEEP            ;Send Beep to console
                BRA     TRY_AGN         ;Loop back, try again
DONTCNT         PLA                     ;Else remove return address
                PLA                     ;and discard it
                STZ     CMDFLAG         ;Clear all bits in command flag
DOCONT          RTS                     ;Return
;
;**************************************************************************************************
;*                              Monitor Command Processors                                        *
;**************************************************************************************************
;
;**************************************************************************************************
;*                      Basic Memory Operations (includes Ctrl-P)                                 *
;**************************************************************************************************
;
;[C] Compare routine: one memory range to another and display any addresses which do not match
;[M] Move routine: uses this section for parameter input, then branches to MOVER below
;[F] Fill routine: uses this section for parameter input but requires a fill byte value
;[CTRL-P] Program EEPROM: uses this section for parameter input and to write the EEPROM
;Uses source, target and length input parameters. Errors in compare are shown in target space.
;
; NOTE: If the PLD memory configuration is changed to increase RAM and decrease EEPROM,
;       the unlock code will not work correctly, as the minimum addressable EEPROM is
;       22KB. This is the case with the current configuration used here... 56KB of RAM
;       and 8KB of EEPROM.
;
FM_INPUT        LDA     #$08            ;Send "val: " to terminal
                JSR     HEX2            ;Use short cut version for print and input
                STA     TEMP2           ;Save fill byte to temp
                JSR     CONTINUE        ;Handle continue prompt
;
;Memory fill routine: parameter gathered below with Move/Fill,
; then a jump to here TEMP2 contains fill byte value
FILL_LP         LDA     LENL            ;Get length low byte
                ORA     LENH            ;OR in length high byte
                BEQ     DOCONT          ;Exit if zero
                LDA     TEMP2           ;Get fill byte from TEMP2
                STA     (TGTL)          ;Store in target location
                JSR     UPD_TL          ;Update Target/Length pointers
                BRA     FILL_LP         ;Loop back until done
;
; Compare/Move/Fill Memory operations ENTER HERE!!
;
;Compare/Move/Fill memory operations
CPMVFL          STA     TEMP2           ;Save command character
                JSR     B_CHROUT        ;Print command character (C/M/F)
                CMP     #$46            ;Check for F - fill memory
                BNE     PRGE_E          ;If not, continue normal parameter input
                LDA     #$06            ;Get msg " addr:"
                BRA     F_INPUT         ;Branch to handle parameter input
;
PRGE_E          LDA     #$09            ;Get " src:" msg
                JSR     HEX4            ;Use short cut version for print and get input
                STA     SRCL            ;Else, store source address in variable SRCL,SRCH
                STY     SRCH            ;Store high address
                LDA     #$0A            ;Get " tgt:" msg
F_INPUT         JSR     HEX4            ;Use short cut version for print and get input
                STA     TGTL            ;Else, store target address in variable TGTL,TGTH
                STY     TGTH            ;Store high address
                LDA     #$07            ;Get " len:" msg
                JSR     HEX4            ;Use short cut version for print and get input
                STA     LENL            ;ELSE, store length address in variable LENL,LENH
                STY     LENH            ;Store high address
;
; All input parameters for Source, Target and Length entered
                LDA     TEMP2           ;Get Command character
                CMP     #$46            ;Check for fill memory
                BEQ     FM_INPUT        ;Handle the remaining input
                CMP     #$43            ;Test for Compare
                BEQ     COMPLP          ;Branch if yes
                CMP     #$4D            ;Check for Move
                BEQ     MOVER           ;Branch if yes
;
COMPLP          LDA     LENL            ;Get low byte of length
                ORA     LENH            ;OR in High byte of length
                BEQ     QUITMV          ;If zero, nothing to compare/write
;
SKP_BURN        LDA     (SRCL)          ;Load source byte
                CMP     (TGTL)          ;Compare to target byte
                BEQ     CMP_OK          ;If compare is good, continue
;
                SMB6    TEMP2           ;Set bit 6 of TEMP2 flag (compare error)
                JSR     SPC2            ;Send 2 spaces
                JSR     DOLLAR          ;Print $ sign
                LDA     TGTL            ;Get Low byte of address
                LDY     TGTH            ;Get High byte of address
                JSR     PRWORD          ;Print word
                JSR     SPC             ;Add 1 space for formatting
;
CMP_OK          JSR     UPD_STL         ;Update pointers
                BRA     COMPLP          ;Loop back until done
;
;Parameters for move memory entered and validated, now make decision on which direction
; to do the actual move, if overlapping, move from end to start, else from start to end.
MOVER           JSR     CONTINUE        ;Prompt to continue move
                SEC                     ;Set carry flag for subtract
                LDA     TGTL            ;Get target lo byte
                SBC     SRCL            ;Subtract source lo byte
                TAX                     ;Move to X Reg temporarily
                LDA     TGTH            ;Get target hi byte
                SBC     SRCH            ;Subtract source hi byte
                TAY                     ;Move to Y Reg temporarily
                TXA                     ;Xfer lo byte difference to A Reg
                CMP     LENL            ;Compare to lo byte length
                TYA                     ;Xfer hi byte difference to A Reg
                SBC     LENH            ;Subtract length lo byte
                BCC     RIGHT           ;If carry is clear, overwrite condition exists
;
;Move memory block first byte to last byte, no overlap condition
MVNO_LP         LDA     LENL            ;Get length low byte
                ORA     LENH            ;OR in length high byte
                BEQ     QUITMV          ;Exit if zero bytes to move
                LDA     (SRCL)          ;Load source data
                STA     (TGTL)          ;Store as target data
                JSR     UPD_STL         ;Update Source/Target/Length variables
                BRA     MVNO_LP         ;Branch back until length is zero
;
;Move memory block last byte to first byte avoids overwrite in source/target overlap
RIGHT           LDX     LENH            ;Get the length hi byte count
                CLC                     ;Clear carry flag for add
                TXA                     ;Xfer High page to A Reg
                ADC     SRCH            ;Add in source hi byte
                STA     SRCH            ;Store in source hi byte
                CLC                     ;Clear carry for add
                TXA                     ;Xfer High page to A Reg
                ADC     TGTH            ;Add to target hi byte
                STA     TGTH            ;Store to target hi byte
                INX                     ;Increment high page value for use below in loop
                LDY     LENL            ;Get length lo byte
                BEQ     MVPG            ;If zero no partial page to move
                DEY                     ;Else, decrement page byte index
                BEQ     MVPAG           ;If zero, no pages to move
MVPRT           LDA     (SRCL),Y        ;Load source data
                STA     (TGTL),Y        ;Store to target data
                DEY                     ;Decrement index
                BNE      MVPRT          ;Branch back until partial page moved
MVPAG           LDA     (SRCL),Y        ;Load source data
                STA     (TGTL),Y        ;Store to target data
MVPG            DEY                     ;Decrement page count
                DEC     SRCH            ;Decrement source hi page
                DEC     TGTH            ;Decrement target hi page
                DEX                     ;Decrement page count
                BNE     MVPRT           ;Loop back until all pages moved
QUITMV          RTS                     ;Return to caller
;
;[D] HEX/TEXT DUMP command:
; Display in HEX followed by TEXT, the contents of 256 consecutive memory addresses
MDUMP           SMB7    CMDFLAG         ;Set bit7 of command flag
                JSR     SETUP           ;Request HEX address input from terminal
                BNE     LINED           ;Branch if new address entered (Z flag updated)
                LDA     TEMP1L          ;Else, point to next consecutive memory page
                STA     INDEXL          ;address saved during last memory dump
                LDA     TEMP1H          ;Xfer high byte of address
                STA     INDEXH          ;Save in pointer
LINED           JSR     DMPGR           ;Send address offsets to terminal
                JSR     GLINE           ;Send horizontal line to terminal
                JSR     CROUT           ;Send CR,LF to terminal
                LDX     #$10            ;Set line count for 16 rows
DLINE           JSR     SPC4            ;Send 4 Spaces to terminal
                JSR     PRINDEX         ;Print INDEX value
                JSR     SPC2            ;Send 2 Spaces to terminal
                LDY     #$00            ;Initialize line byte counter
GETBYT          JSR     SENGBYT         ;Use Search Engine Get Byte (excludes I/O)
                STA     SRCHBUFF,Y      ;Save in Search buffer (16 bytes)
                JSR     PRBYTE          ;Display byte as a HEX value
                JSR     SPC             ;Send Space to terminal
                JSR     INCINDEX        ;Increment Index to next byte location
                INY                     ;Increment index
                CPY     #$10            ;Check for all 16
                BNE     GETBYT          ;Loop back until 16 bytes have been displayed
                JSR     SPC             ;Send a space
                LDY     #$00            ;Reset index for SRCHBUFF
GETBYT2         LDA     SRCHBUFF,Y      ;Get buffered line (16 bytes)
                JSR     PRASC           ;Print ASCII character
                INY                     ;Increment index to next byte
                CPY     #$10            ;Check for 16 bytes
                BNE     GETBYT2         ;Loop back until 16 bytes have been displayed
                JSR     CROUT           ;Else, send CR,LF to terminal
                LDA     INDEXL          ;Get current index low
                STA     TEMP1L          ;Save to temp1 low
                LDA     INDEXH          ;Get current index high
                STA     TEMP1H          ;Save to temp1 high
                DEX                     ;Decrement line count
                BNE     DLINE           ;Branch back until all 16 done
                JSR     GLINE           ;Send horizontal line to terminal
;
;DMPGR subroutine: Send address offsets to terminal
DMPGR           LDA     #$05            ;Get msg for "addr:" to terminal
                JSR     PROMPT          ;Send to terminal
                JSR     SPC2            ;Add two additional spaces
                LDX     #$00            ;Zero index count
MDLOOP          TXA                     ;Send "00" thru "0F", separated by 1 Space, to terminal
                JSR     PRBYTE          ;Print byte value
                JSR     SPC             ;Add a space
                INX                     ;Increment the count
                CPX     #$10            ;Check for 16
                BNE     MDLOOP          ;Loop back until done
;
;Print the ASCII text header "0123456789ABCDEF"
                JSR     SPC             ;Send a space
                LDX     #$00            ;Zero X Reg for "0"
MTLOOP          TXA                     ;Xfer to A Reg
                JSR     BIN2ASC         ;Convert Byte to two ASCII digits
                TYA                     ;Xfer the low nibble character to A Reg
                JSR     B_CHROUT        ;Send least significant HEX to terminal
                INX                     ;Increment to next HEX character
                CPX     #$10            ;Check for 16
                BNE     MTLOOP          ;Branch back till done
                JMP     CROUT           ;Do a CR/LF and return
;
;[G] GO command: Begin executing program code at a specified address.
; Prompts the user for a start address, places it in COMLO/COMHI. If no address entered,
; uses default address at COMLO/COMHI. Loads the A,X,Y,P Registers from presets and does
; a JSR to the routine. Upon return, Registers are saved back to presets for display later.
; Also saves the stack pointer and status Register upon return.
; Note: Stack pointer is not changed due to IRQ service routines.
GO              SMB7    CMDFLAG         ;Set bit7 of command flag
                JSR     SETUP           ;Get HEX address (A/Y Regs hold 16-bit value)
                BEQ     EXEC_GO         ;If not, setup Regs and execute (Z flag updated)
                STA     COMLO           ;Save entered address to pointer low byte
                STY     COMHI           ;Save entered address to pointer hi byte
;
;Preload all 65C02 MPU Registers from Monitor's preset/result variables
EXEC_GO         LDA     PREG            ;Load processor status Register preset
                PHA                     ;Push it to the stack
                LDA     AREG            ;Load A-Reg preset
                LDX     XREG            ;Load X-Reg preset
                LDY     YREG            ;Load Y-Reg preset
                PLP                     ;Pull the processor status Register
;
;Call user program code as a subroutine
                JSR     DOCOM           ;Execute code at specified address
;
;Store all 65C02 MPU Registers to Monitor's preset/result variables: store results
                PHP                     ;Save the processor status Register to the stack
                STA     AREG            ;Store A-Reg result
                STX     XREG            ;Store X-Reg result
                STY     YREG            ;Store Y-Reg result
                PLA                     ;Get the processor status Register
                STA     PREG            ;Store the result
                TSX                     ;Xfer stack pointer to X-Reg
                STX     SREG            ;Store the result
                CLD                     ;Clear BCD mode in case of sloppy user code ;-)
TXT_EXT         RTS                     ;Return to caller
DOCOM           JMP     (COMLO)         ;Execute the command
;
;Search Engine GetByte routine: This routine gets the byte value from the current Index pointer
; location. It also checks the Index location FIRST. The I/O page is excluded from the actual data
; search to prevent corrupting any I/O devices which are sensitive to any READ operations outside
; the BIOS which supports it. An example is the NXP UART family, of which the SC28L92 is used here.
; Current I/O Page Range is $FE00 - $FE3F
; NOTE: $FE40 - $FEFF used for vector/config/text data - allows searching here
SENGBYT         LDA     INDEXH          ;Get High byte address for current Index
                CMP     #$FE            ;Check for Base I/O page
                BEQ     CHK_UPR         ;If yes, check for I/O range
SENRTBYT        LDA     (INDEXL)        ;Else Get byte from current pointer
                RTS                     ;Return to caller
CHK_UPR         LDA     INDEXL          ;Get Low byte address for current Index
                CMP     #$40            ;Check for end of I/O addresses
                BCS     SENRTBYT        ;Return ROM data if range is $FEA0 or higher
                LDA     #$FE            ;Get $FE as seed byte instead of I/O device read
NOWRAP          RTS                     ;Return to caller
;
;**************************************************************************************************
;*                              Processor Register Operations                                     *
;**************************************************************************************************
;
;[P] Processor Status command: Display then change PS preset/result
PRG             LDA     #$0B            ;Get MSG # for Processor Status Register
                BRA     REG_UPT         ;Finish Register update
;
;[S] Stack Pointer command: Display then change SP preset/result
SRG             LDA     #$0C            ;Get MSG # for Stack Register
                BRA     REG_UPT         ;Finish Register update
;
;[Y] Y-Register command: Display then change Y-Reg preset/result
YRG             LDA     #$0D            ;Get MSG # for Y Reg
                BRA     REG_UPT         ;Finish Register update
;
;[X] X-Register command: Display then change X-Reg preset/result
XRG             LDA     #$0E            ;Get MSG # for X Reg
                BRA     REG_UPT         ;Finish Register update
;
;[A] A-Register command: Display then change A-Reg preset/result
ARG             LDA     #$0F            ;Get MSG # for A Reg
;
REG_UPT         PHA                     ;Save MSG # to stack
                PHA                     ;Save MSG # to stack again
                JSR     PROMPT          ;Print Register message
                PLX                     ;Get Index to Registers
                LDA     PREG-$0B,X      ;Read Register (A,X,Y,S,P) preset/result
                JSR     PRBYTE          ;Display HEX value of Register
                JSR     SPC             ;Send [SPACE] to terminal
                JSR     HEXIN2          ;Get up to 2 HEX characters
                PLX                     ;Get MSG # from stack
                STA     PREG-$0B,X      ;Write Register (A,X,Y,S,P) preset/result
MNE_QUIT        RTS                     ;Return to caller
;
;[R] REGISTERS command: Display contents of all preset/result memory locations
;
PRSTAT
                JMP     B_PRSTAT        ;Use BIOS routine to show CPU Status
;
;**************************************************************************************************
;*                              Control Key Operations (Ctrl-?)                                   *
;**************************************************************************************************
;
;[CTRL-B] Boot from the Microdrive:
; - A Partition Record format has been vreated to allow booting of software from an IDE device.
; - The Partition Record is located at LBA 0 on the IDE device. This routine will set the block
; - parameters to load the first LBA from the drive and store it at the default buffer location.
; - The Partition Record has a 2-byte signature at an offset of 252 bytes. It's been decided that
; - the 2-byte signature will be $6502 as a hex word, i.e., stored $02, $65. If this is found.
; - the Monitor will jump to the beginning of the partition block loaded and it will be up to the
; - the Parition Record code to either continue a boot from disk or return to the Monitor via a
; - warm boot. The only two reasons to return are:
;       - An invalid 2-byte signature was found at the end of the Partition Record ($AA55).
;       - No Boot Record was found to be marked as Active, so there's no bootable partition.
;
; As of now, the Partition Record code has been completed, but it only loads a Boot Record from
; the active partition. The Boot Record code has not been completed as of yet, so booting DOS/65
; is a bit of a cheat for now. The PART_OFFSET (long word) contains the starting LBA of the
; bootable image. The PART_ADDRESS contains the starting address in RAM to load the bootable
; image and the PART_SIZE contains the number of 512-byte blocks to load. Finally, the PART_EXEC
; contains the address in SIM to cold start the bootable image. These variables are near the end
; of the source file. 
;
BOOT_MICRODRIVE
                LDA     PART_OFFSET+0
                LDY     PART_OFFSET+1
                LDX     PART_OFFSET+2
;
                JSR     B_IDE_SET_LBA   ;Call BIOS to setup LBA number
;
                LDA     PART_ADDRESS+0  ;Set Address low byte
                LDY     PART_ADDRESS+1  ;Set Address high byte
                LDX     PART_SIZE       ;Set Block count to 16 (8KB)
                JSR     B_IDE_SET_ADDR  ;Set Xfer address and block count
;
                JSR     B_IDE_READ_LBA  ;Read Block Zero to Buffer
                LDA     IDE_STATUS_RAM  ;Get Status from BIOS call
                LSR     A               ;Shift error bit to carry
                BCS     IDE_RD_ERR      ;Branch if error
;
                JMP     (PART_EXEC)     :Jump to SIM coldstart address
;
IDE_RD_ERR
                LDA     #$15            ;Microdrive Error message
                JMP     PROMPT          ;Send message and exit
;
;[CNTRL-L] Xmodem/CRC Load command: receives a file from console via Xmodem protocol. No cable
; swapping needed, uses Console port and buffer via the terminal program. Not a full Xmodem/CRC
; implementation, only does CRC-16 checking, no fallback. Designed for direct attach to host
; machine via com port. Can handle full 8-bit binary transfers without errors.
; Tested with: ExtraPutty (Windows 7 Pro) and Serial (OSX).
;
;Added support for Motorola S-Record formatted files automatically. Default load address is $0800.
; An input parameter is used as a Load Address (for non-S-Record files) or as a positive offset for
; any S-Record formatted file. The supported S-Record format is S19 as created by WDC Tools Linker.
; Note: this code supports the execution address in the final S9 record, but WDC Tools does not
; provide any ability to put this into their code build. WDC are aware of this.
XMODEML         SMB7    CMDFLAG         ;Set bit7 of command flag
                STZ     OPXMDM          ;Clear Xmodem flag
                LDA     #$01            ;Set block count to one
                STA     BLKNO           ;Save it for starting block #
;
                LDA     #$10            ;Get Xmodem intro msg
                JSR     HEX4            ;Print Msg, get Hex load address/S-record Offset
                BNE     XLINE           ;Branch if data entered (Z flag set from HEX4/HEXINPUT)
                TXA                     ;Xfer X Reg to A Reg (LDA #$00)
                LDY     #$08            ;Set High byte ($0800)
XLINE           STA     PTRL            ;Store to Lo pointer
                STY     PTRH            ;Store to Hi pointer
;
XMDM_LOAD ;Entry point for an external program to load data via Xmodem CRC
; To use this routine, the external program must setup the variables above which include
; the starting address (PTRL/H), clear the OPXMDM flag and set the Block count to one.
; Once completed, the message to setup the terminal program is displayed and the user
; needs to setup the terminal to send data via a filename.
;
; A 5 seconds delay is started to allow the user time to navigate to the file to be sent.
                LDA     #$11            ;Get Terminal Setup msg
                JSR     PROMPT          ;Send to console
;
;Wait for 5 seconds for user to setup xfer from terminal
                LDA     #$01            ;Set milliseconds to 1(*10 ms)
                LDX     #$01            ;Set 16-bit multiplier
                LDY     #$F4            ;to 500 decimal ($1F4)
                JSR     B_SET_DLY       ;Set Delay parameters
                JSR     B_EXE_LGDLY     ;Call long delay for 5 seconds
;
STRT_XFER       LDA     #"C"            ;Send "C" character for CRC mode
                JSR     B_CHROUT        ;Send to terminal
                LDY     #50             ;Set loop count to 50
CHR_DLY         JSR     B_EXE_MSDLY     ;Delay 1*(10ms)
                LDA     ICNT_A          ;Check input buffer count
                BNE     STRT_BLK        ;If a character is in, branch
                DEY                     ;Decrement loop count
                BNE     CHR_DLY         ;Branch and check again
                BRA     STRT_XFER       ;Else, branch and send another "C"
;
XDONE           LDA     #ACK            ;Last block, get ACK character
                JSR     B_CHROUT        ;Send final ACK
                LDY     #$02            ;Get delay count
                LDA     #$12            ;Get Good xfer message number
FLSH_DLY        STZ     ICNT_A          ;Zero Input buffer count
                STZ     ITAIL_A         ;Zero Input buffer tail pointer
                STZ     IHEAD_A         ;Zero Input buffer head pointer
;
                PHA                     ;Save Message number
                LDA     #$19            ;Load milliseconds = 250 ms (25x10ms)
                LDX     #$00            ;Load High multiplier to 0 decimal
                JSR     B_SET_DLY       ;Set Delay parameters
                JSR     B_EXE_LGDLY     ;Execute delay, (wait to get terminal back)
                PLA                     ;Get message number back
                CMP     #$13            ;Check for error msg#
                BEQ     SHRT_EXIT       ;Do only one message
                PHA                     ;Save MSG number
                BBR7    OPXMDM,END_LOAD ;Branch if no S-Record
                LDA     #$14            ;Get S-Record load address msg
                JSR     PROMPT          ;Printer header msg
                LDA     SRCL            ;Get source Low byte
                LDY     SRCH            ;Get source High byte
                JSR     PRWORD          ;Print Hex address
END_LOAD        PLA                     ;Get Message number
SHRT_EXIT       JMP     PROMPT          ;Print Message and exit
;
STRT_BLK        JSR     B_CHRIN         ;Get a character
                CMP     #$1B            ;Is it escape - quit?
                BEQ     XM_END          ;If yes, exit
                CMP     #SOH            ;Start of header?
                BEQ     GET_BLK         ;If yes, branch and receive block
                CMP     #EOT            ;End of Transmission?
                BEQ     XDONE           ;If yes, branch and exit
                BRA     STRT_ERR        ;Else branch to error
XM_END          RTS                     ;Cancelled by user, return
;
GET_BLK         LDX     #$00            ;Zero index for block receive
;
GET_BLK1        JSR     B_CHRIN         ;Get a character
                STA     RBUFF,X         ;Move into buffer
                INX                     ;Increment buffer index
                CPX     #$84            ;Compare size (<01><FE><128 bytes><CRCH><CRCL>)
                BNE     GET_BLK1        ;If not done, loop back and continue
;
                LDA     RBUFF           ;Get block number from buffer
                CMP     BLKNO           ;Compare to expected block number
                BNE     RESTRT          ;If not correct, restart the block
                EOR     #$FF            ;Create one's complement of block number
                CMP     RBUFF+1         ;Compare with rcv'd value for block number
                BEQ     BLK_OKAY        ;Branch if compare is good
;
RESTRT          LDA     #NAK            ;Get NAK character
RESTRT2         JSR     B_CHROUT        ;Send to xfer program
                BRA     STRT_BLK        ;Restart block transfer
;
BLK_OKAY        LDA     #$0A            ;Set retry value to 10
                STA     CRCCNT          ;Save it to CRC retry count
;
                JSR     CRC16_GEN       ;Generate CRC16 from Buffer data
;
                LDA     RBUFF+2,Y       ;Get received CRC hi byte (4)
                CMP     CRCHI           ;Compare against calculated CRC hi byte (3)
                BNE     BADCRC          ;If bad CRC, handle error (2/3)
                LDA     RBUFF+3,Y       ;Get CRC lo byte (4)
                CMP     CRCLO           ;Compare against calculated CRC lo byte (3)
                BEQ     GOODCRC         ;If good, go move frame to memory (2/3)
;
;CRC was bad! Need to retry and receive the last frame again. Decrement the CRC retry count,
; send a NAK and try again. Count allows up to 10 retries, then cancels the transfer.
BADCRC          DEC     CRCCNT          ;Decrement retry count
                BNE     CRCRTRY         ;Retry again if count not zero
STRT_ERR        LDA     #CAN            ;Else get Cancel code
                JSR     B_CHROUT        ;Send it to terminal program
                LDY     #$08            ;Set delay multiplier
                LDA     #$13            ;Get message for receive error
                JMP     FLSH_DLY        ;Do a flush, delay and exit
CRCRTRY         STZ     ICNT_A          ;Zero Input buffer count
                STZ     ITAIL_A         ;Zero Input buffer tail pointer
                STZ     IHEAD_A         ;Zero Input buffer head pointer 
;
                BRA     RESTRT          ;Send NAK and retry
;
;Block has been received, check for S19 record transfer
GOODCRC         BBS7    OPXMDM,XFER_S19 ;Branch if bit 7 set (active S-record)
                LDA     BLKNO           ;Else, check current block number
                DEC     A               ;Check for block 1 only (first time thru)
                BEQ     TEST_S19        ;If yes, test for S19 record
;
MOVE_BLK        LDX     #$00            ;Zero index offset to data
COPYBLK         LDA     RBUFF+2,X       ;Get data byte from buffer
                STA     (PTRL)          ;Store to target address
                INC     PTRL            ;Increment low address byte
                BNE     COPYBLK2        ;Check for hi byte loop
                INC     PTRH            ;Increment hi byte address
COPYBLK2        INX                     ;Point to next data byte
                BPL     COPYBLK         ;Loop back until done (128)
INCBLK          INC     BLKNO           ;Increment block number
                LDA     #ACK            ;Get ACK character
                BRA     RESTRT2         ;Send ACK and continue xfer
;
TEST_S19        LDA     RBUFF+2         ;Get first character
                CMP     #"S"            ;Check for S character
                BNE     MOVE_BLK        ;If not equal, no S-record, move block
                LDA     RBUFF+3         ;Get second character
                CMP     #"1"            ;Check for 1 character
                BNE     MOVE_BLK        ;If not equal, no S-record, move block
                SMB7    OPXMDM          ;Set bit 7 for S-record xfer
                STZ     IDY             ;Zero index for SRBUFF
;
;S-Record transfer routine: Xmodem is a 128 byte data block, S-Record is variable, up to
; 44 bytes needed to move a record at a time to the SRBUFF based on length, check as valid,
; then calculate the address and transfer to that location. Once the Xmodem buffer is empty,
; loop back to get the next block and continue processing S-Records until completed.
;
;RBUFF is the full Xmodem block, which starts with the block number, one's compliment of the
; block number, followed by the 128-bytes of data. The data is confirmed as "S1", which validates
; the start of a S-Record format.
;
;At first entry here, pointer IDY is zero. At all entries here, a 128 byte block has been received.
; The S-record type and length needs to be calculated, then the proper count moved to the
; SRBUFF location and both pointers (IDX/IDY) are updated.
;
;S-Record format is as follows (44 bytes max):
; 2 bytes for type: "S1" or "S9" (ASCII text)
; 2 bytes for length (ASCII Hex) - includes load address, data and checksum (not CR/LF)
; 4 bytes for load address (ASCII Hex - 16-bit load address)
; 2-32 bytes for data (ASCII Hex - 1-16 bytes of data) - always an even number
; 2 bytes for checksum (ASCII Hex - 1 byte for checksum)
; 2 bytes for CR/LF
;
;First grab the 2 bytes for the length, convert to binary and transfer the correct count of
; data from RBUFF to SRBUFF. Note: increment count by two additional for CR/LF
; then update the running index into the 128 byte record (IDX) which points to the next record.
; minor update from Mike Barry, saves a byte.
XFER_S19        STZ     IDX             ;Zero offset to RBUFF
;
S19_LOOP2       LDX     IDX             ;Load current offset to RBUFF
                LDY     IDY             ;Get current offset SRBUFF
                BNE     FIL_SRBUFF      ;Branch to complete RBUFF to SRBUFF xfer
;
                LDA     RBUFF+4,X       ;Get first ASCII length character
                LDY     RBUFF+5,X       ;Get second ASCII length character
                JSR     ASC2BIN         ;Convert to binary length
                INC     A               ;Increment length for "S1" or "S9"
                INC     A               ;Increment length for "length characters"
                INC     A               ;Increment length for "CR/LF"
                ASL     A               ;Multiply by two for 2-characters per byte
                STA     TEMP2           ;Save total bytes to move to SRBUFF
                LDY     IDY             ;Get offset to SRBUFF
;
FIL_SRBUFF      LDA     RBUFF+2,X       ;Get S-Record data
                STA     SRBUFF,Y        ;Move into SREC buffer
                INX                     ;Increment index to RBUFF
                CPX     #$81            ;Check for end of buffer
                BEQ     NXT_FRAME       ;If yes, go receive another block into the buffer
                INY                     ;Increment index to SRBUFF
                CPY     TEMP2           ;Compare to length
                BNE     FIL_SRBUFF      ;Loop back until the full record is moved to SRBUFF
;
                STX     IDX             ;Update running offset to RBUFF
                STZ     IDY             ;Reset SRBUFF index pointer (for next S-record xfer)
                JSR     SREC_PROC       ;Process the S-Record in SRBUFF
                BRA     S19_LOOP2       ;Branch back and get another S-Record
;
NXT_FRAME       STY     IDY             ;Save SRBUFF offset
INCBLK2         BRA     INCBLK          ;Increment block and get next frame
;
SREC_PROC       LDA     SRBUFF+1        ;Get the Record type character
                CMP     #"1"            ;Check for S1 record
                BEQ     S1_PROC         ;Process a S1 record
                CMP     #"9"            ;Check for S9 (final) record
                BEQ     S9_PROC         ;Process a S9 record
SREC_ERR        PLA                     ;Else, pull return address
                PLA                     ;(two) bytes from stack
                JMP     STRT_ERR        ;Jump to Xmodem error/exit routine
;
;This routine will decode the SRBUFF ASCII data to binary data.
; As each byte is two ASCII characters, the result is half the length.
; TEMP2 contains the overall length from above, plus extra to add in the "S1" or "S9" and CR/LF
; so we need to decrement TEMP2 by two to correct the required length.
SR_PROC         DEC     TEMP2           ;Decrement length
                DEC     TEMP2           ;Decrement length
;
SR_COMP         LDX     #$00            ;Zero Index
                LDY     #$00            ;Zero Index
SR_CMPLP        PHY                     ;Save Y Reg index
                LDY     SRBUFF+3,X      ;Get LS character
                LDA     SRBUFF+2,X      ;Get MS character
                JSR     ASC2BIN         ;Convert two ASCII characters to HEX byte
                PLY                     ;Restore Y Reg index
                STA     SRBUFF,Y        ;Store in SRBUFF starting at front
                INX                     ;Increment X Reg twice
                INX                     ;Points to next character pair
                INY                     ;Increment Y Reg once for offset to SRBUFF
                DEC     TEMP2           ;Decrement character count
                BNE     SR_CMPLP        ;Branch back until done
;
;SRBUFF now has the decoded HEX data, which is:
; 1 byte for length, 2 bytes for the load address, up to 16 bytes for data and 1 byte checksum
; Now calculate the checksum and ensure valid S-Record content
                STZ     CRCLO           ;Zero Checksum location
                LDX     SRBUFF          ;Load index with record length
                LDY     #$00            ;Zero index
SR_CHKSM        CLC                     ;Clear carry for add
                LDA     SRBUFF,Y        ;Get S-Record byte
                ADC     CRCLO           ;Add in checksum Temp
                STA     CRCLO           ;Update checksum Temp
                INY                     ;Increment offset
                DEX                     ;Decrement count
                BNE     SR_CHKSM        ;Branch back until done
;
                LDA     #$FF            ;Get all bits on
                EOR     CRCLO           ;Exclusive OR TEMP for one's complement
                CMP     SRBUFF,Y        ;Compare to last byte (which is checksum)
                BNE     SREC_ERR        ;If bad, exit out
                RTS                     ;Return to caller
;
S9_PROC         JSR     SR_PROC         ;Process the S-Record and checksum
                LDA     SRBUFF+1        ;Get MSB load address
                STA     COMHI           ;Store to execution pointer
                LDA     SRBUFF+2        ;Get LSB load address
                STA     COMLO           ;Store to execution pointer
                PLA                     ;Pull return address
                PLA                     ;second byte
                BRA     INCBLK2         ;Branch back to close out transfer
;
S1_PROC         JSR     SR_PROC         ;Process the S-Record and checksum
;
;Valid binary S-Record decoded at SRBUFF. Calculate offset from input, add to specified load
; address and store into memory, then loop back until done. Offset is stored in PTR L/H from
; initial input. If no input entered, BUFIDX is zero and PTR L/H is preset to $0800, so checking
; for BUFIDX being zero bypasses adding the offset, if BUFIDX is non zero, then PTR L/H contains
; the offset address which is added to TGT L/H moving the S-Record data to memory.
                LDA     SRBUFF+1        ;Get MS load address
                STA     TGTH            ;Store to target pointer
                LDA     SRBUFF+2        ;Get LS load address
                STA     TGTL            ;Store to target pointer
                LDA     BUFIDX          ;Check input count for offset required
                BEQ     NO_OFFSET       ;If Zero, no offset was entered
;
;Add in offset contained at PTR L/H to TGT L/H
                CLC                     ;Clear carry for add
                LDA     PTRL            ;Get LS offset
                ADC     TGTL            ;Add to TGTL address
                BCC     SKIP_HB         ;Skip increment HB if no carry
                INC     TGTH            ;Else increment TGTH by one
SKIP_HB         STA     TGTL            ;Save TGTL
                LDA     PTRH            ;Get MS offset
                ADC     TGTH            ;Add to TGTH
                STA     TGTH            ;Save it
;
;Check for first Block and load SRC H/L with load address
NO_OFFSET       LDA     BLKNO           ;Get Block number
                DEC     A               ;Decrement to test for block one
                BNE     NO_OFFST2       ;If not first block, skip around
                LDA     IDX             ;Get running count for first block
                CMP     #$2C            ;First S-record?
                BNE     NO_OFFST2       ;If yes, setup load address pointer
                LDA     TGTL            ;Get starting address Lo byte
                STA     SRCL            ;Save it as Source Lo byte
                LDA     TGTH            ;Get starting address Hi byte
                STA     SRCH            ;Save it as Source Hi byte
;
NO_OFFST2       LDX     SRBUFF          ;Get record length
                DEX                     ;Decrement by 3
                DEX                     ;to only transfer the data
                DEX                     ;and not the count/load address
                LDY     #$00            ;Zero index
MVE_SREC        LDA     SRBUFF+3,Y      ;Get offset to data in record
                STA     (TGTL),Y        ;Store it to memory
                INY                     ;Increment index
                DEX                     ;Decrement record count
                BNE     MVE_SREC        ;Branch back until done
XMDMQ           RTS                     ;Return to caller
;
;CRC-16 Generation program. This routine generates the 16-bit CRC for the 128 byte
;  data block stored in RBUFF. It is a separate routine as it's used in both the
;  Xmodem load and save routines. It saves 31 bytes with a small penalty in speed.
CRC16_GEN       STZ     CRCLO           ;Reset the CRC value by
                STZ     CRCHI           ;putting all bits off
                LDY     #$00            ;Set index for data offset
CALCCRC         LDA     RBUFF+2,Y       ;Get data byte
                PHP                     ;Save status Reg
                LDX     #$08            ;Load index for 8 bits
                EOR     CRCHI           ;XOR High CRC byte
CRCLOOP         ASL     CRCLO           ;Shift carry to CRC low byte
                ROL     A               ;Shift bit to carry flag
                BCC     CRCLP1          ;Branch if MSB is 1
                EOR     #$10            ;Exclusive OR with polynomial
                PHA                     ;Save result on stack
                LDA     CRCLO           ;Get CRC low byte
                EOR     #$21            ;Exclusive OR with polynomial
                STA     CRCLO           ;Save it back
                PLA                     ;Get previous result
CRCLP1          DEX                     ;Decrement index
                BNE     CRCLOOP         ;Loop back for all 8 bits
                STA     CRCHI           ;Update CRC high byte
                PLP                     ;Restore status Reg
                INY                     ;Increment index to the next data byte
                BPL     CALCCRC         ;Branch back until all 128 fed to CRC routine
                RTS                     ;Return to caller
;
;[CNTL-R] Reset System command: Resets system by calling Coldstart routine. Page Zero is
; cleared, Vectors and Config data re-initialized from ROM. All I/O devices are reset from
; initial ROM parameters. BIOS Cold Start is entered.
;
SYS_RST         LDA     #$04            ;Get msg "Reset System"
                SMB0    CMDFLAG         ;Set bit0 of command flag
                BRA     RST_ONLY        ;Branch below and handle reset
;
;[CNTL-Z] Zero command: zero RAM from $0100-$7FFF and Reset
;
ZERO            LDA     #$03            ;Get msg "Zero RAM/Reset System"
RST_ONLY        JSR     PROMPT          ;Send to terminal
                JSR     CONTINUE        ;Prompt for Continue
                BBS0    CMDFLAG,DO_COLD ;Branch if reset only
                SEI                     ;Else, disable IRQs
                LDA     #$01            ;Initialize address pointer to $0100
                STA     $01             ;Store to pointer high byte
                STZ     $00             ;Zero address low byte
                DEC     A               ;- LDA #$00
ZEROLOOP        STA     ($00)           ;Write $00 to current address
                INC     $00             ;Increment address pointer
                BNE     ZEROLOOP        ;Loop back until done
                INC     $01             ;Increment page
                LDX     $01             ;Get Page number
                CPX     #$F0            ;Check for start of ROM
                BNE     ZEROLOOP        ;Loop back IF address pointer < $E000
DO_COLD         JMP     B_COLDSTRT      ;Jump to coldstart vector
;
;END OF MONITOR CODE
;**************************************************************************************************
;                               START OF MONITOR DATA                                             *
;**************************************************************************************************
;Monitor command & jump table
; There are two parts to the Monitor command and jump table; First is the list of commands, which
; are one byte each. Alpha command characters are upper case. Second is the 16-bit address table
; that corresponds to the command routines for each command character.
;
MONCMD  .DB     $02             ;[CNTRL-B] Boot DOS/65 ROM Version
        .DB     $0C             ;[CNTRL-L] Xmodem/CRC Load
        .DB     $12             ;[CNTRL-R] Reset - same as power up
        .DB     $1A             ;[CNTRL-Z] Zero Memory - calls reset
        .DB     $41             ;A         Display/Edit A Register
        .DB     $43             ;C         Compare memory block
        .DB     $44             ;D         Display Memory contents in HEX/TEXT
        .DB     $46             ;F         Fill memory block
        .DB     $47             ;G         Go execute to <addr>
        .DB     $4D             ;M         Move memory block
        .DB     $50             ;P         Display/Edit CPU status Reg
        .DB     $52             ;R         Display Registers
        .DB     $53             ;S         Display/Edit stack pointer
        .DB     $58             ;X         Display/Edit X Register
        .DB     $59             ;Y         Display/Edit Y Register
;
MONTAB  .DW     BOOT_MICRODRIVE ;[CNTRL-B] $02 Boot from Microdrive
        .DW     XMODEML         ;[CNTRL-L] $0C Xmodem Download. Uses Console Port
        .DW     SYS_RST         ;[CNTRL-R] $12 Reset CO2Monitor
        .DW     ZERO            ;[CNTRL-Z] $1A Zero memory ($0100-$7FFF) then Reset
        .DW     ARG             ;A         $41 Examine/Edit ACCUMULATOR preset/result
        .DW     CPMVFL          ;C         $43 Compare command - new
        .DW     MDUMP           ;D         $44 HEX/TEXT dump from specified memory address
        .DW     CPMVFL          ;F         $46 Fill specified memory range with a value
        .DW     GO              ;G         $47 Execute program code at specified address
        .DW     CPMVFL          ;M         $4D Copy memory from Source to Target space
        .DW     PRG             ;P         $50 Examine/Edit CPU STATUS REGISTER preset/result
        .DW     PRSTAT          ;R         $52 Display all preset/result contents
        .DW     SRG             ;S         $53 Examine/Edit STACK POINTER preset/result
        .DW     XRG             ;X         $58 Examine/Edit X-REGISTER preset/result
        .DW     YRG             ;Y         $59 Examine/Edit Y-REGISTER preset/result
;
;**************************************************************************************************
;       C02Monitor message strings used with the PROMPT routine, terminated with a null ($00)     *
;**************************************************************************************************
MSG_00  .DB     $0D,$0A
        .DB     "(c)2013-2026 K.E.Maier",$07
        .DB     $0D,$0A
        .DB     "C02Monitor 5.1"
        .DB     $0D,$0A
        .DB     "04/04/2026"
        .DB     $0D,$0A
        .DB     "Memory Ops: "
        .DB     "[C]ompare, "
        .DB     "[D]isplay, "
        .DB     "[F]ill, "
        .DB     "[G]o Exec,"
        .DB     "[M]ove",$0D,$0A,$0A
        .DB     "Register Ops: "
        .DB     "R,A,X,Y,S,P",$0D,$0A,$0A
        .DB     "CTRL[?]: "
        .DB     "[B]oot from IDE, "
        .DB     "[L]oad, "
        .DB     "[R]eset, "
        .DB     "[Z]ero RAM/Reset",$0A
        .DB     $00
;
MSG_01  .DB     $0D,$0A
        .DB     ";-"
        .DB     $00
;
MSG_02  .DB     " cont?"
        .DB     "(y/n)"
        .DB     $00
;
MSG_03  .DB     "Zero RAM/"
MSG_04  .DB     "Reset,"
        .DB     $00
;
MSG_05  .DB     $0D,$0A
        .DB     "   "
MSG_06  .DB     " addr:"
        .DB     $00
MSG_07  .DB     " len:"
        .DB     $00
MSG_08  .DB     " val:"
        .DB     $00
MSG_09  .DB     " src:"
        .DB     $00
MSG_0A  .DB     " tgt:"
        .DB     $00
;
MSG_0B  .DB     "SR:$"
        .DB     $00
MSG_0C  .DB     "SP:$"
        .DB     $00
MSG_0D  .DB     "YR:$"
        .DB     $00
MSG_0E  .DB     "XR:$"
        .DB     $00
MSG_0F  .DB     "AC:$"
        .DB     $00
;
MSG_10  .DB     "Xmodem Download, <ESC> to abort, or"
        .DB     $0D,$0A
        .DB     "Load Address/S-Record offset:"
        .DB     $00
MSG_11  .DB     $0D,$0A
        .DB     "Setup Terminal for Data transfer."
        .DB     $0D,$0A
        .DB     $00
MSG_12  .DB     $0D,$0A
        .DB     "Data transfer complete."
        .DB     $00
MSG_13  .DB     $0D,$0A
        .DB     "Data transfer error!"
        .DB     $00
MSG_14  .DB     $0D,$0A
        .DB     "S-Record load at:$"
        .DB     $00
;
MSG_15  .DB     "IDE Drive Error!",$0A,$0D
        .DB     $00
;
MSG_TABLE       ;Message table: contains message addresses sent via the PROMPT routine
        .DW     MSG_00, MSG_01, MSG_02, MSG_03, MSG_04, MSG_05, MSG_06, MSG_07
        .DW     MSG_08, MSG_09, MSG_0A, MSG_0B, MSG_0C, MSG_0D, MSG_0E, MSG_0F
        .DW     MSG_10, MSG_11, MSG_12, MSG_13, MSG_14, MSG_15
;
; Temporary data for booting DOS/65.
; - these values point to the section of an IDE device where DOS/65 is loaded.
;
PART_OFFSET
        .LONG   131072          ;Partition offset for drive letters
PART_ADDRESS
        .DW     $D000           ;Start of Image in RAM
PART_SIZE
        .DB     16              ;Number of blocks to load
PART_EXEC
        .DW     $E400           ;Address of SIM cold start
;
;**************************************************************************************************
;                               END OF MONITOR DATA                                               *
;**************************************************************************************************
        .END
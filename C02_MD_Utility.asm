;**************************************************************************************************
;*                                                                                                *
;*                  Utility program for the MicroDrive PATA Adapter 0.91                          *
;*                                                                                                *
;*                                                                                                *
;*       This Utility provides functions to identify, test and edit a MicroDrive when present     *
;*         The following functions are provided:                                                  *
;*           - Identify MicroDrive: Vendor String, Device Serial, LBA Count in Hex/Decimal)       *
;*           - Read any LBA into memory and display contents in Hex/ASCII                         *
;*           - Write any LBA from memory and display contents in Hex/ASCII                        *
;*           - Read Full LBA count sequentially or staggered                                      *
;*           - Write Full LBA count sequentially or staggered                                     *
;*           - Benchmark reading and writing of 32MB of sequential data                           *
;*           - Transfer a block of memory to a block of Disc for writing the OS image             *
;*         - Note: Write pattern is $55AA for Sequential Write                                    *
;*                 Write pattern is User defined for Write Benchmark                              *
;*                                                                                                *
;**************************************************************************************************
        PL      66      ;Page Length
        PW      132     ;Page Width (# of char/line)
        CHIP    W65C02S ;Enable WDC 65C02 instructions
        PASS1   OFF     ;Set ON when used for debug
        INCLIST ON      ;Set ON for listing Include files
;**************************************************************************************************
;
; C02BIOS Version 5.1 is the supported BIOS level for this utility!
;
; This BIOS version also use a common source file for constants and variables used by
; both. This just simplifies keeping both code pieces in sync.
;
; 03/04/2026:
;       - fixed hardcoded parameters/pointers used for IDE LBA counts used in several code segments
;       - updated benchmarking to xfer 32KB blocks for a total of 32MB consecutive blocks of data
;
;**************************************************************************************************
;
; Page Zero definitions $00 to $9F reserved for user routines
; NOTES:- Locations $00 and $01 are used to zero RAM (calls CPU reset)
;       - EEPROM Byte Write routine loaded into Page Zero at $90-$A4
;
;       - Page Zero definitions for HEX2BCD and BCD2HEX routines, RTC setup
;
HPHANTOM        .EQU    $0010                   ; HPHANTOM MUST be located (in target memory)
HEX0AND1        .EQU    $11                     ;  immediately below the HEX0AND1 variable
HEX2AND3        .EQU    $12
HEX4AND5        .EQU    $13
HEX6AND7        .EQU    $14
;
DPHANTOM        .EQU    $0014                   ; DPHANTOM MUST be located (in target memory)
DEC0AND1        .EQU    $15                     ; immediately below the DEC0AND1 variable
DEC2AND3        .EQU    $16
DEC4AND5        .EQU    $17
DEC6AND7        .EQU    $18
DEC8AND9        .EQU    $19
;
BUFADR          .EQU    $20
BUFADRH         .EQU    $21
;
IBUFF           .EQU    $30                     ;Input buffer... lots of space available
;
RTC_LOAD        .EQU    $40                     ;Start of Data to set hardware RTC
;
;**************************************************************************************************
;
        INCLUDE         C02Constants5.asm       ;C02 BIOS/Monitor variables, etc.
        INCLUDE         C02JMP_Table_5.asm      ;JMP table for Monitor and BIOS
;
;**************************************************************************************************
PEM             .EQU    $0103   ;PEM Entry
;**************************************************************************************************
;
;       User program code can start here. Default to TEA of $0800, can be chaged as required
;
;**************************************************************************************************
;
        .ORG    $0800                           ;Start of User RAM for programs
;
; First, send an intro message to the console, Utility name and version.
; Second, send the User Menu to the console, then enter Command mode.
;
START
                LDA     #<INTRO_MSG             ;Load Message address
                LDY     #>INTRO_MSG             ;into A/Y Regs
                JSR     B_PROMPTR               ;Call Monitor routine
MENU_LOOP
                LDA     #<MENU_MSG              ;Load Menu address
                LDY     #>MENU_MSG              ;into A/Y Regs
                JSR     B_PROMPTR               ;Call Monitor routine
;
MAIN_LOOP
                JSR     RDCHAR                  ;Wait for keystroke (converts to upper-case)
                LDX     #MONTAB-MONCMD-1        ;Get command list count
CMD_LP          CMP     MONCMD,X                ;Compare to command list
                BNE     CMD_DEC                 ;Check for next command and loop
                PHA                             ;Save keystroke
                TXA                             ;Xfer Command index to A reg
                ASL     A                       ;Multiply keystroke value by 2 (command offset)
                TAX                             ;Xfer Command offsett address to table MONTAB
                PLA                             ;Restore keystroke (some commands send to terminal)
                JSR     DOCMD                   ;Call Monitor command processor as a subroutine
                BRA     MENU_LOOP               ;Command processed, branch/wait for next command
DOCMD           JMP     (MONTAB,X)              ;Execute command from Table
;
CMD_DEC         DEX                             ;Decrement index count
                BPL     CMD_LP                  ;If more to check, loop back
                JSR     BEEP                    ;Beep for error, not valid command character
                BRA     MAIN_LOOP               ;Branch back and re-enter Monitor
;
; Command Code List
;
MONCMD
        .DB     "1"                             ;Identify MicroDrive and display
        .DB     "2"                             ;Read LBA and display
        .DB     "3"                             ;Write LBA and verify
        .DB     "4"                             ;Sequential Read of all LBA
        .DB     "5"                             ;Sequential Write of all LBA
        .DB     "6"                             ;Benchmark MicroDrive Read/Write
        .DB     "M"                             ;Menu display
        .DB     "S"                             ;System Transfer RAM to Disc
        .DB     "Q"                             ;Quit Utility
MONTAB
        .DW     IDE_IDENTIFY                    ;Address of IDE Identify routine
        .DW     IDE_READ_LBA                    ;Address of IDE Read/Display LBA
        .DW     IDE_WRITE_LBA                   ;Address of IDE Write/Verify LBA
        .DW     IDE_SEQ_READ                    ;Address of Sequential LBA Read
        .DW     IDE_SEQ_WRITE                   ;Address of Sequential LBA Write
        .DW     IDE_BENCHMARK                   ;Address of IDE Benchmark
        .DW     MENU_LOOP                       ;Address of Main Menu
        .DW     SYS_XFER                        ;Address of System Transfer
        .DW     QUIT                            ;Address of Quit Utility
;
;[D] HEX/TEXT DUMP command:
; Display in HEX followed by TEXT, the contents of 256 consecutive memory addresses
;
DUMP
                STX     ROWS                    ;Save Row count
                STZ     TEMP1L                  ;Clear Offset to data
                STZ     TEMP1H                  ;used for showing loaded data from device
;
LINED           JSR     CROUT                   ;
                JSR     DMPGR                   ;Send address offsets to terminal
                JSR     GLINE                   ;Send horizontal line to terminal
                JSR     CROUT                   ;Send CR,LF to terminal
                LDX     ROWS                    ;Set line count for rows displayed
DLINE           JSR     SPC                     ;Send 4 Spaces to terminal
                JSR     SPC
                JSR     SPC
                JSR     SPC
                JSR     PROFFSET                ;Print INDEX value
                JSR     SPC                     ;Send 2 Spaces to terminal
                JSR     SPC
                LDY     #$00                    ;Initialize line byte counter
GETBYT
                LDA     (INDEXL)
                STA     SRCHBUFF,Y              ;Save in Search buffer (16 bytes)
                JSR     PRBYTE                  ;Display byte as a HEX value
                JSR     SPC                     ;Send Space to terminal
                JSR     INCINDEX                ;Increment Index to next byte location
                JSR     INCOFFSET               ;Increment Offset address
                INY                             ;Increment index
                CPY     #$10                    ;Check for all 16
                BNE     GETBYT                  ;Loop back until 16 bytes have been displayed
                JSR     SPC                     ;Send a space
                LDY     #$00                    ;Reset index for SRCHBUFF
GETBYT2         LDA     SRCHBUFF,Y              ;Get buffered line (16 bytes)
                JSR     PRASC                   ;Print ASCII character
                INY                             ;Increment index to next byte
                CPY     #$10                    ;Check for 16 bytes
                BNE     GETBYT2                 ;Loop back until 16 bytes have been displayed
                JSR     CROUT                   ;Else, send CR,LF to terminal
                DEX                             ;Decrement line count
                BNE     DLINE                   ;Branch back until all rows done
                JSR     GLINE                   ;Send horizontal line to terminal
;
;DMPGR subroutine: Send address offsets to terminal
;
DMPGR           LDA     #<SYS_ADDR_MSG          ;Get " addr:" msg
                LDY     #>SYS_ADDR_MSG          ;
                JSR     B_PROMPTR               ;Send to terminal
                JSR     SPC                     ;Add two additional spaces
                JSR     SPC
                LDX     #$00                    ;Zero index count
MDLOOP          TXA                             ;Send "00" - "0F", separated by 1 Space to terminal
                JSR     PRBYTE                  ;Print byte value
                JSR     SPC                     ;Add a space
                INX                             ;Increment the count
                CPX     #$10                    ;Check for 16
                BNE     MDLOOP                  ;Loop back until done
;
;Print the ASCII text header "0123456789ABCDEF"
;
                JSR     SPC                     ;Send a space
                LDX     #$00                    ;Zero X reg for "0"
MTLOOP          TXA                             ;Xfer to A reg
                JSR     BIN2ASC                 ;Convert Byte to two ASCII digits
                TYA                             ;Xfer the low nibble character to A reg
                JSR     B_CHROUT                ;Send least significant HEX to terminal
                INX                             ;Increment to next HEX character
                CPX     #$10                    ;Check for 16
                BNE     MTLOOP                  ;Branch back till done
                JMP     CROUT                   ;Do a CR/LF and return
;
;GLINE subroutine: Send a horizontal line to console used by memory display only.
;
GLINE           LDX     #$4F                    ;Load index for 79 decimal
                LDA     #$7E                    ;Get "~" character
GLINEL          JSR     B_CHROUT                ;Send to terminal (draw a line)
                DEX                             ;Decrement count
                BNE     GLINEL                  ;Branch back until done
                RTS                             ;Return to caller
;
;PRINT Offset subroutine: Prints a $ sign followed by TEMP1L/H
;
PROFFSET        JSR     DOLLAR                  ;Print a $ sign
                LDA     TEMP1L                  ;Get Index Low byte
                LDY     TEMP1H                  ;Get Index High byte
                JMP     PRWORD                  ;Print Word, return
;
;Increment Data offset to display
;
INCOFFSET
                INC     TEMP1L                  ;Increment low byte
                BNE     SK_HIOFF                ;If not equal, skip high byte
                INC     TEMP1H                  ;Increment high byte
SK_HIOFF        RTS                             ;Return to caller
;
; MicroDrive Routines
;
IDE_IDENTIFY
; Uses the BIOS call to load drive identity information.
; This routine will display the following information from the ID block:
;
;       Bytes $36 - $5D       Model Number:
;       Bytes $14 - $27       Serial Number:
;       Bytes $2E - $35       Firmware Revision:
;       Bytes $62 - $63       LBA Mode Support:
;       Bytes $78 - $7B       Total LBA Count:
;
; The above data is in Big Endian format or ASCII format
;
                JSR     B_IDE_IDENTIFY          ;Call BIOS routine
                JSR     SWAP_BYTE               ;Swap High/Low Bytes
;
                LDA     #<DRIVE_IDENTITY        ;Get low order offset
                LDY     #>DRIVE_IDENTITY        ;Get high order offset
                JSR     B_PROMPTR               ;Send message to console
;
;ID Block now loaded into buffer
; Next, print the description message, then print the offset to the ID block
; for ASCII text, but will need to do some transforms for Mode Support and
; LBA block count.
;
                LDA     #<MODEL_NUM             ;Get low order offset
                LDY     #>MODEL_NUM             ;Get high order offset
                JSR     B_PROMPTR               ;Send message to console
;
                LDA     #<LBA_BUFFER+$36        ;Get low order offset
                LDY     #>LBA_BUFFER+$36        ;Get high order offset
                LDX     #40                     ;Byte count to display
                JSR     STRING_OUT              ;Use string out routine
;
                LDA     #<SERIAL_NUM            ;Get low order offset
                LDY     #>SERIAL_NUM            ;Get high order offset
                JSR     B_PROMPTR               ;Send message to console
;
                LDA     #<LBA_BUFFER+$14        ;Get low order offset
                LDY     #>LBA_BUFFER+$14        ;Get high order offset
                LDX     #20                     ;Byte count to display
                JSR     STRING_OUT              ;Use string out routine
;
                LDA     #<FIRM_REV              ;Get low order offset
                LDY     #>FIRM_REV              ;Get high order offset
                JSR     B_PROMPTR               ;Send message to console
;
                LDA     #<LBA_BUFFER+$2E        ;Get low order offset
                LDY     #>LBA_BUFFER+$2E        ;Get high order offset
                LDX     #8                      ;Byte count to display
                JSR     STRING_OUT              ;Use string out routine
;
                LDA     #<MODE_SUPPORT          ;Get low order offset
                LDY     #>MODE_SUPPORT          ;Get high order offset
                JSR     B_PROMPTR               ;Send message to console
;
                LDA     LBA_BUFFER+$62          ;Get Capabilities data (bit 9 of Word 49)
                LSR     A                       ;Shift DMA bit to Carry (dont't care)
                LSR     A                       ;Shift LBA bit to Carry (do care)
                BCS     LBA_MODE_Y              ;If active, finish setup
;
                LDA     #$4E                    ;Get "N"
                BRA     LBA_MODE_N              ;Finish sending to console
LBA_MODE_Y
                LDA     #$59                    ;Get "Y"
LBA_MODE_N
                JSR     B_CHROUT                ;Send to console
;
                LDA     #<TOTAL_LBA             ;Get low order offset
                LDY     #>TOTAL_LBA             ;Get high order offset
                JSR     B_PROMPTR               ;Send message to console
;
                LDA     LBA_BUFFER+$78          ;Get LBA count data
                STA     HEX4AND5                ;Store in Page Zero work area
                LDA     LBA_BUFFER+$79          ;Get LBA count data
                STA     HEX6AND7                ;Store in Page Zero work area
                LDA     LBA_BUFFER+$7A          ;Get LBA count data
                STA     HEX0AND1                ;Store in Page Zero work area
                LDA     LBA_BUFFER+$7B          ;Get LBA count data
                STA     HEX2AND3                ;Store in Page Zero work area
;
                JSR     HEXTOBCD                ;Convert 32-bit Hex to ASCII BCD
                JSR     BCDOUT                  ;Print BCD count to console
NO_NEXT_LBA     JMP     USER_INPUT              ;Prompt user for next command
;
IDE_READ_LBA
; This routine will read a User requested LBA and display as Hex/ASCII
; - The "N" key will show the next in sequence
; - Hitting Return will end the LBA Read/Display sequence
;
                STZ     LBA_LOW_WORD            ;Zero out LBA count
                STZ     LBA_LOW_WORD+1
                STZ     LBA_HIGH_WORD
                STZ     LBA_HIGH_WORD+1
;
                LDA     #<LBA_INPUT             ;Get LBA Input message
                LDY     #>LBA_INPUT
                JSR     B_PROMPTR               ;Send to console
                JSR     GET_LBA_NUM             ;Get LBA number to read
;
                STA     LBA_LOW_WORD            ;Save Current LBA number
                STY     LBA_LOW_WORD+1          ;to local variables
                STX     LBA_HIGH_WORD
;
READ_NEXT_LBA
                JSR     CROUT                   ;Send CR/LF to console
                LDA     #<LBA_BUFFER            ;Setup LBA Buffer
                LDY     #>LBA_BUFFER            ; address
                LDX     #$01                    ;LBA count = 1
                STA     INDEXL                  ;Save Index L
                STY     INDEXH                  ;Save Index H
                JSR     B_IDE_SET_ADDR          ;Set Buffer address
;
                JSR     B_IDE_READ_LBA          ;Read LBA into Buffer
                LDA     IDE_STATUS_RAM          ;Get IDE Status
                LSR     A                       ;Shift error bit into carry
                BCS     IDE_RW_ERR              ;If carry set, handle read error
;
                LDX     #$20                    ;Set display range for 32 rows
                JSR     DUMP                    ;Display data to console
;
; Prompt user: either display the next LBA or not.
;
                LDA     #<NEXT_LBA              ;Get LBA Output message
                LDY     #>NEXT_LBA
                JSR     B_PROMPTR               ;Send to console
;
LBA_TRY_AGAIN
                JSR     RDCHAR                  ;Get input from console
                CMP     #$0D                    ;Check for C/R
                BEQ     NO_NEXT_LBA             ;If yes, exit
                CMP     #"N"                    ;Check for "N" for next
                BNE     BAD_ENTRY               ;Bad entry, branch
;
; Need to increase the current LBA number, then loop back and re-display
;
                JSR     LBA_BLK_UPDATE          ;Update LBA Block to read
;
                LDA     LBA_LOW_WORD            ;Get variables
                LDY     LBA_LOW_WORD+1
                LDX     LBA_HIGH_WORD
                JSR     B_IDE_SET_LBA           ;Set LBA to read
;
                LDA     LBA_LOW_WORD+1          ;Get LBA count data
                STA     HEX4AND5                ;Store in Page Zero work area
                LDA     LBA_LOW_WORD            ;Get LBA count data
                STA     HEX6AND7                ;Store in Page Zero work area
                LDA     LBA_HIGH_WORD+1         ;Get LBA count data
                STA     HEX0AND1                ;Store in Page Zero work area
                LDA     LBA_HIGH_WORD           ;Get LBA count data
                STA     HEX2AND3                ;Store in Page Zero work area
;
                JSR     HEXTOBCD                ;Convert and print to ASCII BCD
                LDA     #<SHOW_NEXT_LBA         ;Get LBA Output message
                LDY     #>SHOW_NEXT_LBA
                JSR     B_PROMPTR               ;Send to console
;
                JSR     BCDOUT                  ;Print BCD count to console
                BRA     READ_NEXT_LBA           ;Branch back to show next LBA
;
BAD_ENTRY
                JSR     BEEP                    ;Send error beep
                BRA     LBA_TRY_AGAIN           ;Branch and try again
;
IDE_RW_ERR
                JMP     IDE_ERROR_HANDLER       ;Jump to error handler
;
IDE_WRITE_LBA
; This routine will write a User requested LBA from the LBA_BUFFER
; - The Buffer data will be displayed first and then prompted for writing
;
                LDA     #<LBA_OUTPUT            ;Get LBA Output message
                LDY     #>LBA_OUTPUT
                JSR     B_PROMPTR               ;Send to console
                JSR     GET_LBA_NUM             ;Get LBA number to write
                LDA     #<LBA_BUFFER            ;Setup LBA Buffer
                LDY     #>LBA_BUFFER            ; address
                LDX     #$01                    ;LBA count = 1
                STA     INDEXL                  ;Save Index L
                STY     INDEXH                  ;Save Index H
                JSR     B_IDE_SET_ADDR          ;Set Buffer address
;
                LDA     #<LBA_WR_DATA           ;Get LBA Write message
                LDY     #>LBA_WR_DATA
                JSR     B_PROMPTR               ;Send to console
;
                LDX     #$20                    ;Set display range for 32 rows
                JSR     DUMP                    ;Display data to console
;
                LDA     #<LBA_WR_CNFM           ;Get LBA Confirm Write message
                LDY     #>LBA_WR_CNFM
                JSR     B_PROMPTR               ;Send to console
;
                JSR     CONTINUE                ;Prompt to confirm LBA write
;
                JSR     B_IDE_WRITE_LBA         ;Write LBA from Buffer
                LDA     IDE_STATUS_RAM          ;Get IDE Status
                LSR     A                       ;Shift error bit into carry
                BCS     IDE_RW_ERR              ;If carry set, handle write error
;
                LDA     IDE_STATUS_RAM          ;Get IDE Status
                LSR     A                       ;Shift error bit into carry
                BCS     IDE_RW_ERR              ;If carry set, handle write error
;
                JMP     USER_INPUT              ;Get user input
;
IDE_SEQ_READ
; This routine will read the entire disk data one block at a time,
; - This can take a long time as the current LBA count is displayed.
;
                LDA     #<LBA_SEQ_RD_MSG        ;Get Seq Read Message address
                LDY     #>LBA_SEQ_RD_MSG
                JSR     B_PROMPTR               ;Send to console
;
                LDA     #<LBA_SEQ_TM_MSG        ;Get Time Message address
                LDY     #>LBA_SEQ_TM_MSG
                JSR     B_PROMPTR               ;Send to console
;
                JSR     B_IDE_IDENTIFY          ;Call BIOS routine
                JSR     SWAP_BYTE               ;Swap high/low bytes
;
                LDA     #<TOTAL_LBA             ;Get low order offset
                LDY     #>TOTAL_LBA             ;Get high order offset
                JSR     B_PROMPTR               ;Send message to console
;
                LDA     LBA_BUFFER+$78          ;Get LBA count data
                STA     HEX4AND5                ;Store in Page Zero work area
                LDA     LBA_BUFFER+$79          ;Get LBA count data
                STA     HEX6AND7                ;Store in Page Zero work area
                LDA     LBA_BUFFER+$7A          ;Get LBA count data
                STA     HEX0AND1                ;Store in Page Zero work area
                LDA     LBA_BUFFER+$7B          ;Get LBA count data
                STA     HEX2AND3                ;Store in Page Zero work area
;
                JSR     HEXTOBCD                ;Convert and print to ASCII BCD
                JSR     BCDOUT                  ;Print BCD count to console
;
                LDA     #<LBA_SEQ_CFM           ;Get Message address
                LDY     #>LBA_SEQ_CFM
                JSR     B_PROMPTR               ;Send to console
;
                JSR     CONTINUE                ;Prompt user to continue
                JSR     CROUT                   ;Send CR/LF
;
                LDA     #<BENCH_BUFFER          ;Setup LBA Buffer
                LDY     #>BENCH_BUFFER          ; address
                LDX     #$01                    ;LBA count = 1
                JSR     B_IDE_SET_ADDR          ;Set Buffer address
;
                STZ     LBA_LOW_WORD            ;Zero out LBA count
                STZ     LBA_LOW_WORD+1
                STZ     LBA_HIGH_WORD
                STZ     LBA_HIGH_WORD+1
;
                LDA     #<LBA_BLKS_RD           ;Get Blocks read msg
                LDY     #>LBA_BLKS_RD
                JSR     B_PROMPTR               ;Send to console
;
SEQ_LBA_READ
                LDA     LBA_LOW_WORD            ;Get variables
                LDY     LBA_LOW_WORD+1
                LDX     LBA_HIGH_WORD
                JSR     B_IDE_SET_LBA           ;Set LBA to read
;
                LDA     #$0D                    ;Get C/R
                JSR     B_CHROUT                ;Send to console
;
                LDA     LBA_LOW_WORD+1          ;Get LBA count data
                STA     HEX4AND5                ;Store in Page Zero work area
                LDA     LBA_LOW_WORD            ;Get LBA count data
                STA     HEX6AND7                ;Store in Page Zero work area
                LDA     LBA_HIGH_WORD+1         ;Get LBA count data
                STA     HEX0AND1                ;Store in Page Zero work area
                LDA     LBA_HIGH_WORD           ;Get LBA count data
                STA     HEX2AND3                ;Store in Page Zero work area
;
                JSR     HEXTOBCD                ;Convert and print to ASCII BCD
                JSR     BCDOUT                  ;Print BCD count to console
;
OC_LOOP         LDA     OCNT_A                  ;Check output buffer count
                BNE     OC_LOOP                 ;Loop back until buffer sent
;
                JSR     B_IDE_READ_LBA          ;Read selected LBA from IDE
                LDA     IDE_STATUS_RAM          ;Get IDE Status
                CMP     #$51                    ;Check for error
                BNE     NO_RD_ERR               ;Branch if no error
;
                JMP     IDE_ERROR_HANDLER       ;Jump to error handler
;
NO_RD_ERR
                JSR     LBA_BLK_UPDATE          ;Update LBA Block to read
;
                JSR     LBA_LIMIT_CHK           ;Check LBA limit
                BCC     SEQ_LBA_READ            ;Loop back to continue (Carry clear)
;
                LDA     #<LBA_BLKS_RD_CMP       ;Get Blocks read msg
                LDY     #>LBA_BLKS_RD_CMP
                JSR     B_PROMPTR               ;Send to console
                JMP     USER_INPUT              ;Prompt User
;
LBA_BLK_UPDATE
; This routine updates the LBA block number being read or written
; - This routine is only used for the full read or write
;
                INC     LBA_LOW_WORD            ;Increment 32-bit word
                BNE     SKIP_BLK_UPDATE
                INC     LBA_LOW_WORD+1
                BNE     SKIP_BLK_UPDATE
                INC     LBA_HIGH_WORD
                BNE     SKIP_BLK_UPDATE
                INC     LBA_HIGH_WORD+1
SKIP_BLK_UPDATE RTS                             ;Return to caller
;
LBA_LIMIT_CHK
                LDA     LBA_HIGH_WORD+1         ;Get high order word
                CMP     LOAD_IDE+$03            ;Compare to Limit
                BNE     LIMIT_GOOD              ;If not, exit
                LDA     LBA_HIGH_WORD           ;Get high order word
                CMP     LOAD_IDE+$02            ;Compare to limit
                BNE     LIMIT_GOOD              ;If not, exit
                LDA     LBA_LOW_WORD+1          ;Get low order word
                CMP     LOAD_IDE+$01            ;Compare to limit
                BNE     LIMIT_GOOD              ;If not, exit
                LDA     LBA_LOW_WORD            ;Get low order word
                CMP     LOAD_IDE+$00            ;Compare to limit
                BNE     LIMIT_GOOD
                SEC                             ;Set carry for limit reached
                RTS
LIMIT_GOOD      CLC                             ;Clear carry for limit good
                RTS                             ;Return to caller
;
IDE_SEQ_WRITE
; This routine will write the entire data on the drive!!
; - A 16-bit data pattern is requested from user.
; - This routine can take a long time as the current LBA count is displayed!!
;
                LDA     #<LBA_SEQ_WR_MSG        ;Get Seq Write Message address
                LDY     #>LBA_SEQ_WR_MSG
                JSR     B_PROMPTR               ;Send to console
;
                LDA     #<LBA_SEQ_TM_MSG        ;Get time address
                LDY     #>LBA_SEQ_TM_MSG
                JSR     B_PROMPTR               ;Send to console
;
                JSR     B_IDE_IDENTIFY          ;Call BIOS routine
                JSR     SWAP_BYTE               ;Swap high/low bytes
;
                LDA     #<TOTAL_LBA             ;Get low order offset
                LDY     #>TOTAL_LBA             ;Get high order offset
                JSR     B_PROMPTR               ;Send message to console
;
                LDA     LOAD_IDE+$00            ;Get LBA count data
                STA     HEX4AND5                ;Store in Page Zero work area
                LDA     LOAD_IDE+$01            ;Get LBA count data
                STA     HEX6AND7                ;Store in Page Zero work area
                LDA     LOAD_IDE+$02            ;Get LBA count data
                STA     HEX0AND1                ;Store in Page Zero work area
                LDA     LOAD_IDE+$03            ;Get LBA count data
                STA     HEX2AND3                ;Store in Page Zero work area
;
                JSR     HEXTOBCD                ;Convert Hex to ASCII BCD
                JSR     BCDOUT                  ;Print BCD count to console
;
                LDA     #<LBA_SEQ_CFM           ;Get 1st Message address
                LDY     #>LBA_SEQ_CFM
                JSR     B_PROMPTR               ;Send to console
;
                JSR     CONTINUE                ;Prompt user to continue
                JSR     CROUT                   ;Send CR/LF
;
                LDA     #<LBA_SEQ_CFM2          ;Get 2nd Message address
                LDY     #>LBA_SEQ_CFM2
                JSR     B_PROMPTR               ;Send to console
;
                JSR     CONTINUE                ;Prompt user to continue
                JSR     CROUT                   ;Send CR/LF
;
                JSR     GET_PATTERN             ;Prompt for two-byte Hex pattern
                JSR     FILL_PATTERN            ;Fill buffer with pattern
;
                LDA     #<BENCH_BUFFER          ;Setup LBA Buffer
                LDY     #>BENCH_BUFFER          ; address
                LDX     #$01                    ;LBA count = 1
                JSR     B_IDE_SET_ADDR          ;Set Buffer address
;
                STZ     LBA_LOW_WORD            ;Zero out LBA count
                STZ     LBA_LOW_WORD+1
                STZ     LBA_HIGH_WORD
                STZ     LBA_HIGH_WORD+1
;
                LDA     #<LBA_BLKS_WR           ;Get Blocks written msg
                LDY     #>LBA_BLKS_WR
                JSR     B_PROMPTR               ;Send to console
;
SEQ_LBA_WRITE
                LDA     LBA_LOW_WORD            ;Get variables
                LDY     LBA_LOW_WORD+1
                LDX     LBA_HIGH_WORD
                JSR     B_IDE_SET_LBA           ;Set LBA to write
;
                LDA     #$0D                    ;Get C/R
                JSR     B_CHROUT                ;Send to console
;
                LDA     LBA_LOW_WORD+1          ;Get LBA count data
                STA     HEX4AND5                ;Store in Page Zero work area
                LDA     LBA_LOW_WORD            ;Get LBA count data
                STA     HEX6AND7                ;Store in Page Zero work area
                LDA     LBA_HIGH_WORD+1         ;Get LBA count data
                STA     HEX0AND1                ;Store in Page Zero work area
                LDA     LBA_HIGH_WORD           ;Get LBA count data
                STA     HEX2AND3                ;Store in Page Zero work area
;
                JSR     HEXTOBCD                ;Convert Hex to ASCII BCD
                JSR     BCDOUT                  ;Print BCD count to console

OC_LOOP2        LDA     OCNT_A                  ;Check output buffer count
                BNE     OC_LOOP2                ;Loop back until buffer sent
;
                JSR     B_IDE_WRITE_LBA         ;Write selected LBA from buffer
                LDA     IDE_STATUS_RAM          ;Get IDE Status
                CMP     #$51                    ;Check for error
                BNE     NO_WR_ERR               ;Branch if no error
;
                BRA     RD_WR_ERR               ;Branch to handle error
;
NO_WR_ERR
                JSR     LBA_BLK_UPDATE          ;Update LBA Block to write
;
                JSR     LBA_LIMIT_CHK           ;Check LBA limit
                BCC     SEQ_LBA_WRITE           ;Loop back to continue (Carry clear)
;
                LDA     #<LBA_BLKS_WR_CMP       ;Get Blocks written msg
                LDY     #>LBA_BLKS_WR_CMP
                JSR     B_PROMPTR               ;Send to console
                JMP     USER_INPUT              ;Prompt User
;
IDE_BENCHMARK
;
; The Benchmark will read or write a 32MB contiguous block of data.
;  The starting LBA is entered by the user.
;
; - The Benchmark timer in the C02 BIOS/Monitor is used to time the data transfer and shows
; - the number of seconds and hundredths of a second that it takes to complete the transfer.
; -  Note that the benchmark routines use a multiple block transfer of 64 blocks (32KB).
;
; The User is prompted for the Write function, as this overwrites a 32MB block of data on the
; - IDE device, which results in a loss of data. When executing the Write benchmark, the
; - LBA Buffer will be filled with a "55AA" pattern for a 512-byte block.
;
; Error checking is done after each LBA Read or Write function and any error will be
; - displayed and the test aborted after that.
;
                LDA     #<LBA_BENCH_INTRO       ;Get LBA Bench Intro Msg
                LDY     #>LBA_BENCH_INTRO
                JSR     B_PROMPTR               ;Send to console
BENCH_IN_LP
                JSR     RDCHAR                  ;Get character from user
                JSR     B_CHROUT                ;Send to console
                CMP     #"R"                    ;Test for Read
                BEQ     IDE_BENCH_READ          ;If yes, go set RTC
                CMP     #"W"                    ;Test for Write
                BEQ     IDE_BENCH_WRITE         ;If no, skip RTC set
                JSR     BEEP                    ;Else, error, send beep
                BRA     BENCH_IN_LP             ;Branch back and try again
;
IDE_BENCH_READ
;
; Simple test program to transfer multiple sectors - READ
;
                LDA     #<LBA_START             ;Get LBA starting # Msg
                LDY     #>LBA_START
                JSR     B_PROMPTR               ;Send to console
;
                JSR     GET_LBA_NUM             ;Get starting LBA # from user
;
                LDA     #<LBA_RD_BENCH          ;Get LBA Read Bench Msg
                LDY     #>LBA_RD_BENCH
                JSR     B_PROMPTR               ;Send to console
;
OC_LOOP3        LDA     OCNT_A                  ;Check output buffer count
                BNE     OC_LOOP3                ;Loop back until buffer sent
;
                LDA     #<BENCH_BUFFER          ;Setup LBA Buffer
                LDY     #>BENCH_BUFFER          ; address
                LDX     #$40                    ;Sector count of 64 (32KB)
                JSR     B_IDE_SET_ADDR          ;Call BIOS routine to set it
;
; Setup 1024 transfers at 64 blocks per transfer = 32MB
;
                LDX     #$00                    ;Set for 256 blocks (128KB)
                LDY     #$04                    ;Set multiplier of 4 (* 256)
                JSR     B_CNT_INIT              ;Reset Benchmark Counter
                JSR     B_CNT_STRT              ;Start Benchmark Counter
;
LBA_RBLK
                JSR     B_IDE_READ_LBA          ;Call BIOS Read Block
                LDA     IDE_STATUS_RAM          ;Get IDE Status (RAM)
                LSR     A                       ;Shift error bit into carry
                BCS     RD_WR_ERR               ;Branch if error
;
                LDA     LBA_LOW_BYTE            ;Get LBA low byte (Carry is clear)
                ADC     LBA_XFER_CNT            ;Add 64 decimal
                STA     LBA_LOW_BYTE            ;Save it back
;
                LDA     LBA_HIGH_BYTE           ;Get LBA high byte
                ADC     #$00                    ;Add carry
                STA     LBA_HIGH_BYTE           ;Save it back
;
                LDA     LBA_EXT_BYTE            ;Get LBA ext byte
                ADC     #$00                    ;Add carry
                STA     LBA_EXT_BYTE            ;Save it back
;
                DEX                             ;Decrement low index
                BNE     LBA_RBLK                ;Loop back until zero
                DEY                             ;Decrement multiplier index
                BNE     LBA_RBLK                ;Loop back until done
                JSR     B_CNT_STOP              ;Stop benchmark counter
                JSR     B_CNT_DISP              ;Print Benchmark counter
                JMP     USER_INPUT              ;Prompt User
;
RD_WR_ERR
                JMP     IDE_ERROR_HANDLER       ;Jump to error handler, then return
;
IDE_BENCH_WRITE
;
; Simple test program to transfer multiple sectors - WRITE
;
                JSR     GET_PATTERN             ;Prompt for two-byte Hex pattern
                JSR     FILL_PATTERN            ;Fill 16KB buffer with pattern
;
                LDA     #<LBA_START             ;Get LBA starting # Msg
                LDY     #>LBA_START
                JSR     B_PROMPTR               ;Send to console
;
                JSR     GET_LBA_NUM             ;Get starting LBA # from user
;
                LDA     #<LBA_BENCH_WARN        ;Get LBA Write Bench msg
                LDY     #>LBA_BENCH_WARN
                JSR     B_PROMPTR               ;Send to console
BENCH_WARN_LP
                JSR     RDCHAR                  ;Get character from user
                JSR     B_CHROUT                ;Send to console
                CMP     #"Y"                    ;Test for yes
                BEQ     BENCH_WRITE_Y           ;If yes, do write benchmark
                CMP     #"N"                    ;Test for no
                BEQ     BENCH_WRITE_N           ;If no, skip write benchmark
                JSR     BEEP                    ;Else, error, send beep
                BRA     BENCH_WARN_LP           ;Branch back and try again
BENCH_WRITE_Y
                LDA     #<LBA_WR_BENCH          ;Get LBA Write Bench msg
                LDY     #>LBA_WR_BENCH
                JSR     B_PROMPTR               ;Send to console
;
OC_LOOP4        LDA     OCNT_A                  ;Check output buffer count
                BNE     OC_LOOP4                ;Loop back until buffer sent
;
                LDA     #<BENCH_BUFFER          ;Setup LBA Buffer
                LDY     #>BENCH_BUFFER          ; address
                LDX     #$40                    ;Sector count of 64 (32KB)
                JSR     B_IDE_SET_ADDR          ;Call BIOS routine to set it
;
; Setup 1024 transfers at 64 blocks per transfer = 32MB
;
                LDX     #$00                    ;Set for 256 blocks (128KB)
                LDY     #$04                    ;Set multiplier of 4 (* 256)
                JSR     B_CNT_INIT              ;Reset Benchmark Counter
                JSR     B_CNT_STRT              ;Start Benchmark Counter
LBA_WBLK
                JSR     B_IDE_WRITE_LBA         ;Write Block
                LDA     IDE_STATUS_RAM          ;Get IDE Status
                LSR     A                       ;Shift error bit into carry
                BCS     RD_WR_ERR               ;Branch if error
;
                CLC                             ;Clear Carry for add
                LDA     LBA_LOW_BYTE            ;Get LBA low byte
                ADC     LBA_XFER_CNT            ;Add 64 decimal
                STA     LBA_LOW_BYTE            ;Save it back
;
                LDA     LBA_HIGH_BYTE           ;Get LBA high byte
                ADC     #$00                    ;Add carry
                STA     LBA_HIGH_BYTE           ;Save it back
;
                LDA     LBA_EXT_BYTE            ;Get LBA ext byte
                ADC     #$00                    ;Add carry
                STA     LBA_EXT_BYTE            ;Save it back
;
SKP_HI_WR
                DEX                             ;Decrement index
                BNE     LBA_WBLK                ;Loop until done
                DEY                             ;Decrement index high
                BNE     LBA_WBLK                ;Loop back until done
                JSR     B_CNT_STOP              ;Stop benchmark counter
                JSR     B_CNT_DISP              ;Print Benchmark counter
                JMP     USER_INPUT              ;Prompt User
;
BENCH_WRITE_N
                LDA     #<LBA_BENCH_ABORT       ;Get LBA Write Bench msg
                LDY     #>LBA_BENCH_ABORT
                JSR     B_PROMPTR               ;Send to console
;
                JMP     USER_INPUT
;
QUIT
                LDA     #<QUIT_MSG              ;Load Message address
                LDY     #>QUIT_MSG              ;into A/Y regs
                JSR     B_PROMPTR               ;Send to console/return
;
                LDA     #<LBA_BUFFER            ;Setup LBA Buffer
                LDY     #>LBA_BUFFER            ; address
                LDX     #$01                    ;LBA count = 1
                JSR     B_IDE_SET_ADDR          ;Set Buffer address
                JSR     B_IDE_RESET             ;Reset MicroDrive
;
                LDX     #$00                    ;Get warm boot function
                JMP     PEM                     ;Jump to PEM to warm boot
;
;Prompt User for what's next
; As we're outputting to a remote console, displaying the menu again could scroll the displayed
; data off the screen, so this routine pauses the program execution and let's the user decide
; on going to the menu display or just continuing on with another function.
;
USER_INPUT
                LDA     #<USER_INMSG            ;Load message address
                LDY     #>USER_INMSG            ;into A/Y reg
                JSR     B_PROMPTR               ;Send to console
                JMP     MAIN_LOOP               ;Goto main input loop
;
GET_LBA_NUM
;Get LBA number from user
                JSR     DECIN                   ;Get Decimal input, convert to BCD, then to HEX
;
                LDA     HEX6AND7                ;Low byte
                LDY     HEX4AND5
                LDX     HEX2AND3
                JMP     B_IDE_SET_LBA           ;Set LBA number
;
STRING_OUT
; String out prints a string based on the A/Y register pointing to the start of the string
; and the X reg containing how many characters to print (not a null terminated string)
;
                STA     STRINGL                 ;Set low byte address
                STY     STRINGH                 ;Set high byte address
                LDY     #$00                    ;Zero offet index
STRING_LOOP
                LDA     (STRINGL),Y             ;Get string data
                CMP     #$20                    ;Check for ASCII space
                BEQ     SKIP_SPC                ;If yes, skip printing it
                JSR     B_CHROUT                ;Send to terminal
SKIP_SPC
                INY                             ;Increment index to string
                DEX                             ;Decrement character count
                BNE     STRING_LOOP             ;Branch back until done
                RTS                             ;Return to caller
;
IDE_ERROR_HANDLER
; This routine gets the error code anytime a command returns with the error
; bit on in the status register. It uses the BIOS routine to get the error register
; and returns with the error code in the X register.
;
; the error code is matched to the list of possible codes per the Hitachi
; MicroDrive documentation, then the matching error message is sent to the console.
; After this, the IDE controller is reset and the User is prompted for the next
; action to be taken.
;
                LDA     #<IDE_CONTROLLER_ERROR  ;Get Base IDE error msg
                LDY     #>IDE_CONTROLLER_ERROR
                JSR     B_PROMPTR               ;Send to console
;
OC_LOOP5        LDA     OCNT_A                  ;Check output buffer count
                BNE     OC_LOOP5                ;Loop back until buffer sent
;
                JSR     B_IDE_GET_STAT          ;Get Status from BIOS
                TXA                             ;Xfer error code to A reg
;
                LDX     #IDE_ERROR_ADDRESS-IDE_ERROR_CODES-1    ;Get error list count
ERROR_LP        CMP     IDE_ERROR_CODES,X       ;Compare to command list
                BNE     ERROR_DEC               ;Check for next error and loop
;
; X Reg now contains error index
;
                TXA                             ;Xfer Error code index to A reg
                ASL     A                       ;Multiply error index value by 2
                TAX                             ;Xfer Error offset address to message table
;
                LDA     IDE_ERROR_ADDRESS,X     ;Get message address
                LDY     IDE_ERROR_ADDRESS+1,X
                BRA     ERROR_MSG               ;Branch below to output message and continue
;
ERROR_DEC       DEX                             ;Decrement index count
                BPL     ERROR_LP                ;If more to check, loop back
;
; No more error codes, so it must be something unknown. So print the unknown message
; to the console and return to the User prompt.
;
                LDA     #<IDE_ERROR_06          ;Get Error message address
                LDY     #>IDE_ERROR_06
ERROR_MSG
                JSR     B_PROMPTR               ;Send to console
;
OC_LOOP6        LDA     OCNT_A                  ;Check output buffer count
                BNE     OC_LOOP6                ;Loop back until buffer sent
;
                JSR     B_IDE_RESET             ;Reset IDE Controller
                JMP     USER_INPUT              ;Prompt User
;
GET_PATTERN
; Get Pattern: This prompts the User for a 2-byte Hexadecimal fill pattern.
; - This will be used by FILL_PATTERN to load the BENCH_BUFFER.
                LDA     #<PATTERN_MSG           ;Get write pattern msg
                LDY     #>PATTERN_MSG
                JSR     B_PROMPTR               ;Send to console
;
; Monitor routine will get User input and return in A/Y regs
; - Data also saved in INDEXH/INDEXL
                JSR     HEXIN4                  ;Use Monitor to get input
                JMP     CROUT                   ;Send C/R to console and return
;
FILL_PATTERN
;
; Fill Pattern: This fills the LBA buffer with a user specified data pattern.
; - The buffer address is specified by BENCH_BUFFER (at the end of our code).
; - For ease of coding, we default to a 16KB fill buffer.
; - The 16KB buffer is used by the Read and Write Benchmark routines only.
;
                LDA     #<BENCH_BUFFER          ;Setup LBA Buffer
                LDY     #>BENCH_BUFFER          ; address
                STA     TGTL                    ;Setup Page Zero pointer lo
                STY     TGTH                    ;Setup Page Zero pointer hi
;
                LDX     #$00                    ;Set Index for count
                LDY     #$40                    ; of 32KB (16K of words)
FILL_P_LOOP
                LDA     INDEXH                  ;Get High byte fill
                STA     (TGTL)                  ;Save it
                INC     TGTL                    ;Increment pointer
                BNE     SK_FILL_1               ;Skip if no rollover
                INC     TGTH                    ;Increment pointer
SK_FILL_1
                LDA     INDEXL                  ;Get Low byte fill
                STA     (TGTL)                  ;Save it
                INC     TGTL                    ;Increment pointer
                BNE     SK_FILL_2               ;Skip if no rollover
                INC     TGTH                    ;Increment pointer
SK_FILL_2
                DEX                             ;Decrement low count
                BNE     FILL_P_LOOP             ;Loop back till done
                DEY                             ;Decrement high count
                BNE     FILL_P_LOOP             'Loop back until done
                RTS                             ;Return to caller
;
; Routine to swap high and low bytes in the block space
; - used for Identity Data, as the bytes are swapped high and low
;
SWAP_BYTE
                LDA     #<LBA_BUFFER            ;Setup LBA Buffer
                LDY     #>LBA_BUFFER            ; address
                STA     BIOS_XFERL              ;Save it to page zero
                STY     BIOS_XFERH              ;variable
;
                LDX     #$00                    ;Set Index for count of 256
                LDY     #$01                    ;Load Y reg for 1-byte offset
SWAP_LOOP
                LDA     (BIOS_XFERL)            ;Get first byte
                PHA                             ;Save to stack
                LDA     (BIOS_XFERL),Y          ;Get second byte
                STA     (BIOS_XFERL)            ;Save it
                PLA                             ;Get second byte back
                STA     (BIOS_XFERL),Y          ;Save it to first byte
;
                INC     BIOS_XFERL              ;Increment index
                BNE     SWAP_SKP1               ;Branch if non-zero
                INC     BIOS_XFERH              ;Increment index
SWAP_SKP1
                INC     BIOS_XFERL              ;Increment index
                BNE     SWAP_SKP2               ;Branch if non-zero
                INC     BIOS_XFERH              ;Increment index
SWAP_SKP2
                DEX                             ;Decrement index
                BNE     SWAP_LOOP               ;Loop back till done
                RTS                             ;Return to caller
;
SYS_XFER
;
;System Transfer routine.
; This routine is used to write a section of memory to a defined set of contiguous blocks
; on the Microdrive. The purpose being to transfer the bootable image from RAM to the disc.
;
; The user is prompted for a few inputs as:
; - Starting LBA on the Microdrive
; - Starting memory address used as the source
; - Number of blocks to be transferred
;
; Once this is entered, the user is prompted to either continue or abort.
; if confirmed, the write executed and the blocks on the disc are overwritten with the
; contens of memory.
;
                LDA     #<SYS_INTRO_MSG         ;Get System Xfer Message
                LDY     #>SYS_INTRO_MSG         ;
                JSR     B_PROMPTR               ;Send to Console
;
                LDA     #<SYS_LBA_MSG           ;Get Starting LBA for xfer
                LDY     #>SYS_LBA_MSG           ;
                JSR     B_PROMPTR               ;Send to Console
                JSR     GET_LBA_NUM             ;Get starting LBA from User
;
; Use C02 Monitor routine to get a 16-bit hex address returned in A/Y
; and stored in INDEXH/INDEXL
;
                LDA     #<RAM_START_MSG         ;Get Starting RAM for xfer
                LDY     #>RAM_START_MSG         ;
                JSR     B_PROMPTR               ;Send to Console
                JSR     HEXIN4                  ;Call Monitor routine
;
                LDA     #<BLK_SIZE_MSG          ;Get LBA count for xfer
                LDY     #>BLK_SIZE_MSG          ;
                JSR     B_PROMPTR               ;Send to Console
;
                JSR     DECIN                   ;Get Decimal input, convert to BCD, then to HEX
;
                LDX     HEX6AND7                ;Get low byte (number of blocks)
                LDA     INDEXL                  ;Get RAM address to start from
                LDY     INDEXH                  ;
                JSR     B_IDE_SET_ADDR          ;Call BIOS to set address and block count
;
                LDA     #<SYS_CONFIRM_MSG       ;Get Confirm Message for xfer
                LDY     #>SYS_CONFIRM_MSG       ;
                JSR     B_PROMPTR               ;Send to Console
;
SYS_WRT_WARN_LP
                JSR     RDCHAR                  ;Get character from user
                JSR     B_CHROUT                ;Send to console
                CMP     #"Y"                    ;Test for yes
                BEQ     SYS_WRITE_GO            ;If yes, do write benchmark
                CMP     #"N"                    ;Test for no
                BEQ     SYS_WRITE_ABORT         ;If no, skip write benchmark
                JSR     BEEP                    ;Else, error, send beep
                BRA     SYS_WRT_WARN_LP         ;Branch back and try again
;
SYS_WRITE_GO
                LDA     #<SYS_WRITE_MSG         ;Get Confirm Message for xfer
                LDY     #>SYS_WRITE_MSG         ;
                JSR     B_PROMPTR               ;Send to Console
;
WAIT_SYS
                LDA     OCNT_A                  ;Get output count for console
                BNE     WAIT_SYS                ;Wait until done
;
                JSR     B_IDE_WRITE_LBA         ;Call BIOS to write image
                LDA     IDE_STATUS_RAM          ;Get IDE Status (RAM)
                LSR     A                       ;Shift error bit into carry
                BCS     IMG_WR_ERR              ;Branch if error
;
                LDA     #<SYS_COMPLETE_MSG      ;Get Confirm Message for xfer
                LDY     #>SYS_COMPLETE_MSG      ;
                JSR     B_PROMPTR               ;Send to Console
                JMP     USER_INPUT              ;Exit to main
;
IMG_WR_ERR
                JSR     IDE_ERROR_HANDLER       ;Handle Disc error
SYS_WRITE_ABORT
                JMP     USER_INPUT              ;Exit to main
;
;
; The following routines are borrowed from Brian Phelps' SyMON monitor.
; - HEXTOBCD, BCDOUT, BCDTOASC, BCDTOHEX, ASCTODEC
; - These have been rewritten to use CMOS instructions, etc.
;
;HEXTOBCD subroutine: convert a 1-8 digit HEX value to a 1-10 digit BCD value.
; Call with 8 digit (4 byte) HEX value in HEX0AND1(MSB) through HEX6AND7(LSB).
; Returns with 10 digit (5 byte) BCD result in DEC0AND1(MSB) through DEC8AND9(LSB)
;HPHANTOM is a 16 bit address used to reference an 8 bit zero-page address.
; (HEXTOBCD needs LDA $hh,Y (an invalid instruction) so we use LDA $00hh,Y instead)
; This address is not written-to nor read-from in the HEXTOBCD subroutine.
; The address is the zero-page memory location immediatly below the HEX0AND1 variable
;HEX value input buffer:
;HEX0AND1 Two most significant HEX digits
;HEX2AND3
;HEX4AND5
;HEX6AND7 Two least significant HEX digits
;BCD value output buffer (BCD accumulator):
;DEC0AND1 ;Two most significant BCD digits
;DEC2AND3
;DEC4AND5
;DEC6AND7
;DEC8AND9 ;Two least significant BCD digits
;
HEXTOBCD        STZ     DEC0AND1                ;Init (zero) buffer
                STZ     DEC2AND3
                STZ     DEC4AND5
                STZ     DEC6AND7
                STZ     DEC8AND9
                LDY     #$04                    ;Initialize HEX input buffer byte index: point to address minus 1 of LSB
                LDX     #$04                    ;Initialize multiplicand table index: point to LSB of lowest multiplicand
DECLOOP         LDA     HPHANTOM,Y              ;Read indexed byte from input buffer: Y REGISTER index always > 0 here
                AND     #$0F                    ;Zero the high digit
                JSR     MULTIPLY                ;Multiply low digit
                INX                             ;Add 5 to multiplicand table index: point to LSB of next higher multiplicand
                INX
                INX
                INX
                INX
                LDA     HPHANTOM,Y              ;Read indexed byte from input buffer: Y REGISTER index always > 0 here
                LSR     A                       ;Shift high digit to low digit, zero high digit
                LSR     A
                LSR     A
                LSR     A
                JSR     MULTIPLY                ;Multiply digit
                INX                             ;Add 5 to multiplicand table index: point to LSB of next higher multiplicand
                INX
                INX
                INX
                INX
                DEY                             ;Decrement HEX input buffer byte index
                BNE     DECLOOP                 ;LOOP back to DECLOOP IF byte index <> 0: there are more bytes to process
                RTS                             ; ELSE, done HEXTOBCD subroutine, RETURN
;
;Multiply indexed multiplicand by digit in ACCUMULATOR
;
MULTIPLY        PHA
                PHX
                PHY
                SED                             ;Switch processor to BCD arithmatic mode
                TAY                             ;Copy digit to Y REGISTER: multiplier loop counter
HMLTLOOP        CPY     #$00
                BNE     HDOADD                  ;GOTO HDOADD IF multiplier loop counter <> 0
                CLD                             ; ELSE, switch processor to BINARY arithmatic mode
                PLY
                PLX
                PLA
BCD_DONE        RTS                             ;Done MULTIPLY subroutine, RETURN
;
;Add indexed multiplicand to BCD accumulator (output buffer)
;
HDOADD          CLC
                LDA     HMULTAB,X               ;Least significant byte of indexed multiplicand
                ADC     DEC8AND9                ;Least significant byte of BCD accumulator
                STA     DEC8AND9
                LDA     HMULTAB-1,X
                ADC     DEC6AND7
                STA     DEC6AND7
                LDA     HMULTAB-2,X
                ADC     DEC4AND5
                STA     DEC4AND5
                LDA     HMULTAB-3,X
                ADC     DEC2AND3
                STA     DEC2AND3
                LDA     HMULTAB-4,X             ;Most significant byte of indexed multiplicand
                ADC     DEC0AND1                ;Most significant byte of BCD accumulator
                STA     DEC0AND1
                DEY                             ;Decrement multiplier loop counter
                BRA     HMLTLOOP                ;LOOP back to HMLTLOOP
;
;BCDOUT subroutine: convert 10 BCD digits to ASCII DECIMAL digits then send result to terminal.
;Leading zeros are supressed in the displayed result.
;Call with 10 digit (5 byte) BCD value contained in variables DEC0AND1 through DEC8AND9:
;DEC0AND1 ($15) Two most significant BCD digits
;DEC2AND3 ($16)
;DEC4AND5 ($17)
;DEC6AND7 ($18)
;DEC8AND9 ($19) Two least significant BCD digits
;
BCDOUT          LDX     #$00                    ;Initialize BCD output buffer index: point to MSB
                LDY     #$00                    ;Initialize leading zero flag: no non-zero digits have been processed
BCDOUTL         LDA     DEC0AND1,X              ;Read indexed byte from BCD output buffer
                LSR     A                       ;Shift high digit to low digit, zero high digit
                LSR     A
                LSR     A
                LSR     A
                JSR     BCDTOASC                ;Convert BCD digit to ASCII DECIMAL digit, send digit to terminal
                LDA     DEC0AND1,X              ;Read indexed byte from BCD output buffer
                AND     #$0F                    ;Zero the high digit
                JSR     BCDTOASC                ;Convert BCD digit to ASCII DECIMAL digit, send digit to terminal
                INX                             ;Increment BCD output buffer index
                CPX     #$05
                BNE     BCDOUTL                 ;LOOP back to BCDOUTL IF output buffer index <> 5
                CPY     #$00
                BNE     BCD_DONE                ; ELSE, GOTO BCDOUTDN IF any non-zero digits were processed
                LDA     #$30                    ; ELSE, send "0" to terminal
                JMP     B_CHROUT                ;Send to console
;
;BCDTOASC subroutine:
; convert BCD digit to ASCII DECIMAL digit, send digit to terminal IF it's not a leading zero
;
BCDTOASC        BNE     NONZERO                 ;GOTO NONZERO IF BCD digit <> 0
                CPY     #$00                    ; ELSE, GOTO BTADONE IF no non-zero digits have been processed
                BEQ     BCD_DONE                ;  (supress output of leading zeros)
NONZERO         INY                             ; ELSE, indicate that a non-zero digit has been processed (Y REGISTER <> 0)
                CLC                             ;Add ASCII "0" to digit: convert BCD digit to ASCII DECIMAL digit
                ADC     #$30
                JMP     B_CHROUT                ;Send converted digit to terminal
;
;BCDTOHEX subroutine: convert a 1-10 digit BCD value to a 1-8 digit HEX value.
; Call with 10 digit (5 byte) DECIMAL value in DEC0AND1(MSB) through DEC8AND9(LSB).
; Returns with 8 digit (4 byte) HEX result in HEX0AND1(MSB) through HEX6AND7(LSB)
;DPHANTOM is a 16 bit address used to reference an 8 bit zero-page address.
; (BCDTOHEX needs LDA $hh,Y (an invalid instruction) so we use LDA $00hh,Y instead)
; This address is not written-to nor read-from in the BCDTOHEX subroutine.
; The address is the zero-page memory location immediatly below the DEC0AND1 variable
;BCD value input buffer:
;DEC0AND1 ;Two most significant BCD digits
;DEC2AND3
;DEC4AND5
;DEC6AND7
;DEC8AND9 ;Two least significant BCD digits
;HEX value output buffer (HEX accumulator):
;HEX0AND1 Two most significant HEX digits
;HEX2AND3
;HEX4AND5
;HEX6AND7 Two least significant HEX digits
;
BCDTOHEX        STZ     HEX0AND1                ;Init (zero) buffer
                STZ     HEX2AND3
                STZ     HEX4AND5
                STZ     HEX6AND7
                LDY     #$05                    ;Initialize DECIMAL input buffer byte index: point to (address - 1) of LSB
                LDX     #$03                    ;Initialize multiplicand table index: point to LSB of lowest multiplicand
BCDLOOP         LDA     DPHANTOM,Y              ;Read indexed byte from input buffer: Y REGISTER index always > 0 here
                AND     #$0F                    ;Zero the high digit
                JSR     MULTPLI                 ;Multiply low digit
                INX                             ;Add 4 to multiplicand table index: point to LSB of next higher multiplicand
                INX
                INX
                INX
                LDA     DPHANTOM,Y              ;Read indexed byte from input buffer: Y REGISTER index always > 0 here
                LSR     A                       ;Shift high digit to low digit, zero high digit
                LSR     A
                LSR     A
                LSR     A
                JSR     MULTPLI                 ;Multiply digit
                INX                             ;Add 4 to multiplicand table index: point to LSB of next higher multiplicand
                INX
                INX
                INX
                DEY                             ;Decrement DECIMAL input buffer byte index
                BNE     BCDLOOP                 ;LOOP back to BCDLOOP IF byte index <> 0: there are more bytes to process
                RTS                             ; ELSE, done BCDTOHEX subroutine, RETURN
;
;Multiply indexed multiplicand by digit in ACCUMULATOR
;
MULTPLI         PHA                             ;Save registers
                PHX
                PHY
                TAY                             ;Copy digit to Y REGISTER: multiplier loop counter
DMLTLOOP        CPY     #$00
                BNE     DDOADD                  ;GOTO DDOADD IF multiplier loop counter <> 0
                PLY                             ;Restore registers
                PLX
                PLA
                RTS                             ;Done MULTIPLI subroutine, RETURN
;
;Add indexed multiplicand to HEX accumulator (output buffer)
;
DDOADD          CLC
                LDA     DMULTAB,X               ;Least significant byte of indexed multiplicand
                ADC     HEX6AND7                ;Least significant byte of HEX accumulator
                STA     HEX6AND7
                LDA     DMULTAB-1,X
                ADC     HEX4AND5
                STA     HEX4AND5
                LDA     DMULTAB-2,X
                ADC     HEX2AND3
                STA     HEX2AND3
                LDA     DMULTAB-3,X             ;Most significant byte of indexed multiplicand
                ADC     HEX0AND1                ;Most significant byte of HEX accumulator
                STA     HEX0AND1
                DEY                             ;Decrement multiplier loop counter
                BCS     OVERFLOW                ;GOTO OVERFLOW IF the last add produced a CARRY: HEX output buffer has overflowed
                BCC     DMLTLOOP                ; ELSE, LOOP back to DMLTLOOP (always branch)
OVERFLOW        LDA     #$2A                    ;Send "*" to terminal: indicate that an overflow has occured
                JSR     B_CHROUT
                BRA     DMLTLOOP                ;LOOP back to DMLTLOOP
;
;ASCTODEC subroutine: convert ASCII DECIMAL digits to BCD
;
ASCTODEC        STZ     DEC0AND1                ;Init (zero) buffer two most significant BCD digits
                STZ     DEC2AND3
                STZ     DEC4AND5
                STZ     DEC6AND7
                STZ     DEC8AND9                ; two least significant BCD digits
                LDX     BUFIDX                  ;Read number of digits entered: ASCII digit buffer index
                BEQ     A2DDONE                 ;GOTO A2DDONE IF BUFIDX = 0: no digits were entered
                LDY     #$05                    ; ELSE, Initialize BCD input buffer index: process up to 5 BCD bytes (10 digits)
ATODLOOP        JSR     A2DSUB                  ;Read ASCII digit then convert to BCD
                STA     DPHANTOM,Y              ;Write BCD digit to indexed buffer location (index always > 0)
                JSR     A2DSUB                  ;Read ASCII digit then convert to BCD
                ASL     A                       ;Make this BCD digit the more significant in the BCD byte
                ASL     A
                ASL     A
                ASL     A
                ORA     DPHANTOM,Y              ;OR with the less significant digit
                STA     DPHANTOM,Y              ;Write BCD byte to indexed buffer location (index always > 0)
                DEY                             ;Decrement BCD input buffer index
                BNE     ATODLOOP                ;GOTO ATODLOOP IF buffer index <> 0: there is room to process another digit
A2DDONE         RTS                             ; ELSE, done ASCTODEC, RETURN
;
;Read indexed ASCII DECIMAL digit from text buffer then convert digit to 4 bit BCD
;
A2DSUB          TXA                             ;GOTO A2DCONV IF digit buffer index <> 0: there are more digits to process
                BNE     A2DCONV
                PLA                             ; ELSE, pull return address from STACK
                PLA
                RTS                             ;Done ASCTODEC, RETURN
A2DCONV         LDA     IBUFF-1,X               ;Read indexed ASCII DECIMAL digit
                SEC                             ;Subtract ASCII "0" from ASCII DECIMAL digit: convert digit to BCD
                SBC     #$30
                DEX                             ;Decrement ASCII digit buffer index
                RTS                             ;A2DSUB done, RETURN
;
;DECIN subroutine: request 1 - 10 DECIMAL digit input from terminal, followed by [RETURN].
; [ESCAPE] aborts, [BACKSPACE] erases last keystroke.
; Convert input to BCD and HEX then store both results as follows:
; Converted 10 digit (5 byte) BCD value will be contained in variables DEC0AND1 through DEC8AND9:
;  DEC0AND1 ($E5) Two most significant BCD digits
;  DEC2AND3 ($E6)
;  DEC4AND5 ($E7)
;  DEC6AND7 ($E8)
;  DEC8AND9 ($E9) Two least significant BCD digits
; Converted 8 digit (4 byte) HEX value will be contained in variables HEX0AND1 through HEX6AND7:
;  HEX0AND1 ($E1) Two most significant HEX digits
;  HEX2AND3 ($E2)
;  HEX4AND5 ($E3)
;  HEX6AND7 ($E4) Two least significant HEX digits
; NOTE1: If a DECIMAL value greater than 4,294,967,295 ($FFFFFFFF) is entered,
;  1 or 2 asterisks (*) will be sent to the terminal following the inputted digits.
;  This is to indicate that an overflow in the HEX accumulator has occured.
;  (the BCDTOHEX subroutine's HEX accumulator "rolls over" to zero when that value is exceeded)
;  An overflow condition does NOT affect the BCD value stored.
; NOTE2: This subroutine is not used by SyMon; it is here for user purposes, if needed.
;
DECIN           JSR     DECINPUT                ;Request 1 - 8 DECIMAL digit input from terminal
                JSR     ASCTODEC                ;Convert ASCII DECIMAL digits to BCD
                JMP     BCDTOHEX                ;Convert 1-8 digit BCD to a 1-8 digit HEX value
;
;DECINPUT subroutine: request 1 to 8 DECIMAL digits from terminal. Result is
; stored in zero-page address IBUFF through (IBUFF + $08)
;Setup RDLINE subroutine parameters:
;
DECINPUT
                LDX     #$08                    ;  X-REGISTER = maximum number of digits allowed
; Drop into RDLINE routine
;
;RDLINE subroutine: Store keystrokes into buffer until [RETURN] key is struck
; Used for Decimal entry, so only (0-9) are accepted entries.
; On entry, X Reg = buffer length. On exit, X Reg = buffer count
; [BACKSPACE] key removes keystrokes from buffer.
; [ESCAPE] key aborts then returns.
;
RDLINE          STX     BUFLEN                  ;Store buffer length
                STZ     BUFIDX                  ;Zero buffer index
RDLOOP          JSR     RDCHAR                  ;Get character from terminal, convert LC2UC
                CMP     #$1B                    ;Check for ESC key
                BEQ     RDNULL                  ;If yes, exit back to Monitor
NOTESC          CMP     #$0D                    ;Check for C/R
                BEQ     EXITRD                  ;Exit if yes
                CMP     #$08                    ;Check for Backspace
                BEQ     RDBKSP                  ;If yes handle backspace
                CMP     #$30                    ;Check for '0' or higher
                BCC     INPERR                  ;Branch to error if less than '0'
                CMP     #$3A                    ;Check for higher than '9'
                BCS     INPERR                  ;Branch to error if more than '9'
                LDX     BUFIDX                  ;Get the current buffer index
                CPX     BUFLEN                  ;Compare to length for space
                BCC     STRCHR                  ;Branch to store in buffer
INPERR          JSR     BEEP                    ;Else, error, send Bell to terminal
                BRA     RDLOOP                  ;Branch back to RDLOOP
STRCHR          STA     IBUFF,X                 ;Store keystroke in buffer
                JSR     B_CHROUT                ;Send keystroke to terminal
                INC     BUFIDX                  ;Increment buffer index
                BRA     RDLOOP                  ;Branch back to RDLOOP
RDBKSP          LDA     BUFIDX                  ;Check if buffer is empty
                BEQ     INPERR                  ;Branch if yes
                DEC     BUFIDX                  ;Else, decrement buffer index
                JSR     BSOUT                   ;Send Backspace to terminal
                BRA     RDLOOP                  ;Loop back and continue
EXITRD          LDX     BUFIDX                  ;Get keystroke count (set Z flag)
                BNE     RDL_OK                  ;If data entered, normal exit
RDNULL          PLA                             ;Pull return address
                PLA                             ; from stack
                JMP     USER_INPUT              ;Go to main menu
RDL_OK          RTS                             ;Return to caller
;
;RDCHAR subroutine: Waits for a keystroke to be entered.
; if keystroke is a lower-case alphabetical, convert it to upper-case
RDCHAR          JSR     B_CHRIN                 ;Request keystroke input from terminal
                CMP     #$61                    ;Check for lower case value range
                BCC     UCOK                    ;Branch if < $61, control code/upper-case/numeric
                SBC     #$20                    ;Subtract $20 to convert to upper case
UCOK            RTS                             ;Character received, return to caller
;
;BEEP subroutine: Send ASCII [BELL] to terminal
BEEP            PHA                             ;Save A Reg on Stack
                LDA     #$07                    ;Get ASCII [BELL] to terminal
                BRA     SENDIT                  ;Branch to send
;
;SPC subroutine: Send a Space to terminal
SPC             PHA                             ;Save character in A Reg
                LDA     #$20                    ;Get ASCII Space
                BRA     SENDIT                  ;Branch to send
;
;BSOUT subroutine: send a Backspace to terminal
BSOUT           JSR     BSOUT2                  ;Send an ASCII backspace
                JSR     SPC                     ;Send space to clear out character
BSOUT2          PHA                             ;Save character in A Reg
                LDA     #$08                    ;Send another Backspace to return
                BRA     SENDIT                  ;Branch to send
;
;DOLLAR subroutine: Send "$" to terminal
DOLLAR          PHA                             ;Save A Reg on STACK
                LDA     #$24                    ;Get ASCII "$"
                BRA     SENDIT                  ;Branch to send
;
;Send CR/LF to terminal
CROUT           PHA                             ;Save A Reg
                LDA     #$0D                    ;Get ASCII Return
                JSR     B_CHROUT                ;Send to terminal
                LDA     #$0A                    ;Get ASCII Linefeed
SENDIT          JSR     B_CHROUT                ;Send to terminal
                PLA                             ;Restore A Reg
                RTS                             ;Return to caller
;
;INCINDEX subroutine: increment 16 bit variable INDEXL/INDEXH
INCINDEX        INC     INDEXL                  ;Increment index low byte
                BNE     SKP_IDX                 ;If not zero, skip high byte
                INC     INDEXH                  ;Increment index high byte
SKP_IDX         RTS                             ;Return to caller
;
;HEX input subroutines: Request 1 to 4 ASCII HEX digits from terminal, then convert digits into
; a binary value. For 1 to 4 digits entered, HEXDATAH and HEXDATAL contain the output.
; Variable BUFIDX will contain the number of digits entered
; HEXIN2 - returns value in A Reg and Y Reg only (Y Reg always $00)
; HEXIN4 - returns values in A Reg, Y Reg and INDEXL/INDEXH
;
HEXIN4          LDX     #$04                    ;Set for number of characters allowed
                JSR     HEXINPUT                ;Convert digits
                STY     INDEXH                  ;Store to INDEXH
                STA     INDEXL                  ;Store to INDEXL
                RTS                             ;Return to caller
;
HEXIN2          LDX     #$02                    ;Set for number of characters allowed
;
;HEXINPUT subroutine: request 1 to 4 HEX digits from terminal, then convert ASCII HEX to HEX
; minor update from Mike Barry, saves a byte.
; Setup RDLINE subroutine parameters:
HEXINPUT        JSR     DOLLAR                  ;Send "$" to console
                JSR     RDLINE_H                ;Request ASCII HEX input from terminal
                BEQ     HINEXIT                 ;Exit if none (Z flag already set)
                STZ     HEXDATAH                ;Clear Upper HEX byte, Lower HEX byte will be updated
                LDY     #$02                    ;Set index for 2 bytes
ASCLOOP         PHY                             ;Save it to stack
                LDA     INBUFF-1,X              ;Read ASCII digit from buffer
                TAY                             ;Xfer to Y Reg (LSD)
                DEX                             ;Decrement input count
                BEQ     NO_UPNB                 ;Branch if no upper nibble
                LDA     INBUFF-1,X              ;Read ASCII digit from buffer
                BRA     DO_UPNB                 ;Branch to include upper nibble
NO_UPNB         LDA     #$30                    ;Load ASCII "0" (MSD)
DO_UPNB         JSR     ASC2BIN                 ;Convert ASCII digits to binary value
                PLY                             ;Get index from stack
                STA     HEXDATAH-1,Y            ;Write byte to indexed buffer location
                TXA                             ;Check for zero, (no digits left)
                BEQ     HINDONE                 ;If not, exit
                DEY                             ;Else, decrement to next byte set
                DEX                             ;Decrement index count
                BNE     ASCLOOP                 ;Loop back for next byte
HINDONE         LDY     HEXDATAH                ;Get High Byte
                LDA     HEXDATAL                ;Get Low Byte
                LDX     BUFIDX                  ;Get input count (set Z flag)
HINEXIT         RTS                             ;And return to caller
;;RDLINE subroutine: Store keystrokes into buffer until [RETURN] key is struck
; Used for Hex entry, so only (0-9,A-F) are accepted entries. Lower-case alpha characters
; are converted to upper-case. On entry, X Reg = buffer length. On exit, X Reg = buffer count
; [BACKSPACE] key removes keystrokes from buffer. [ESCAPE] key aborts then re-enters monitor.
RDLINE_H        STX     BUFLEN                  ;Store buffer length
                STZ     BUFIDX                  ;Zero buffer index
RDLOOP_H        JSR     RDCHAR                  ;Get character from terminal, convert LC2UC
                CMP     #$1B                    ;Check for ESC key
                BEQ     RDNULL_H                ;If yes, exit back to Monitor
NOTESC_H        CMP     #$0D                    ;Check for C/R
                BEQ     EXITRD_H                ;Exit if yes
                CMP     #$08                    ;Check for Backspace
                BEQ     RDBKSP_H                ;If yes handle backspace
                CMP     #$30                    ;Check for '0' or higher
                BCC     INPERR_H                ;Branch to error if less than '0'
                CMP     #$47                    ;Check for 'G' ('F'+1)
                BCS     INPERR_H                ;Branch to error if 'G' or higher
                LDX     BUFIDX                  ;Get the current buffer index
                CPX     BUFLEN                  ;Compare to length for space
                BCC     STRCHR_H                ;Branch to store in buffer
INPERR_H        JSR     BEEP                    ;Else, error, send Bell to terminal
                BRA     RDLOOP_H                ;Branch back to RDLOOP
STRCHR_H        STA     INBUFF,X                ;Store keystroke in buffer
                JSR     B_CHROUT                ;Send keystroke to terminal
                INC     BUFIDX                  ;Increment buffer index
                BRA     RDLOOP_H                ;Branch back to RDLOOP
RDBKSP_H        LDA     BUFIDX                  ;Check if buffer is empty
                BEQ     INPERR_H                ;Branch if yes
                DEC     BUFIDX                  ;Else, decrement buffer index
                JSR     BSOUT                   ;Send Backspace to terminal
                BRA     RDLOOP_H                ;Loop back and continue
EXITRD_H        LDX     BUFIDX                  ;Get keystroke count (Z flag)
                BNE     HINEXIT                 ;If data entered, normal exit
RDNULL_H        JMP     USER_INPUT              ;Go to main menu
;
;ASC2BIN subroutine: Convert 2 ASCII HEX digits to a binary (byte) value
; Enter: A Register = high digit, Y Register = low digit
; Return: A Register = binary value
; Updated routine via Mike Barry... saves 3 bytes, 10 clock cycles
ASC2BIN         STZ     TEMP1                   ;Clear TEMP1
                JSR     BINARY                  ;Convert high digit to 4-bit nibble
                ASL     A                       ;Shift to high nibble
                ASL     A
                ASL     A
                ASL     A
                STA     TEMP1                   ;Store it in temp area
                TYA                             ;Get Low digit
;
BINARY          EOR     #$30                    ;ASCII -> HEX nibble
                CMP     #$0A                    ;Check for result < 10
                BCC     BNOK                    ;Branch if 0-9
                SBC     #$67                    ;Else subtract for A-F
BNOK            ORA     TEMP1                   ;OR into temp value
RESERVED        RTS                             ;Return to caller
;
;BIN2ASC subroutine: Convert single byte to two ASCII HEX digits
; Enter: A Register contains byte value to convert
; Return: A Register = high digit, Y Register = low digit
BIN2ASC         PHA                             ;Save A Reg on stack
                AND     #$0F                    ;Mask off high nibble
                JSR     ASCII                   ;Convert nibble to ASCII HEX digit
                TAY                             ;Move to Y Reg
                PLA                             ;Get character back from stack
                LSR     A                       ;Shift high nibble to lower 4 bits
                LSR     A
                LSR     A
                LSR     A
;
ASCII           CMP     #$0A                    ;Check for 10 or less
                BCC     ASCOK                   ;Branch if less than 10
                ADC     #$06                    ;Add $06+CF ($07) for A-F
ASCOK           ADC     #$30                    ;Add $30 for ASCII
                RTS                             ;Return to caller
;
;Routines to output 8/16-bit Binary Data and ASCII characters
; PRASC subroutine: Print A-Reg as ASCII (Printable ASCII values = $20 - $7E), else print "."
PRASC           CMP     #$7F                    ;Check for first 128
                BCS     PERIOD                  ;If = or higher, branch
                CMP     #$20                    ;Check for control characters
                BCS     ASCOUT                  ;If space or higher, branch and print
PERIOD          LDA     #$2E                    ;Else, print a "."
ASCOUT          JMP     B_CHROUT                ;Send byte in A-Reg, then return
;
;PRBYTE subroutine: Converts a single Byte to 2 HEX ASCII characters and sends to console on
; entry, A Reg contains the Byte to convert/send. Register contents are preserved on entry/exit.
PRBYTE          PHA                             ;Save A Register
                PHY                             ;Save Y Register
PRBYT2          JSR     BIN2ASC                 ;Convert A Reg to 2 ASCII Hex characters
                JSR     B_CHROUT                ;Print high nibble from A Reg
                TYA                             ;Transfer low nibble to A Reg
                JSR     B_CHROUT                ;Print low nibble from A Reg
                PLY                             ;Restore Y Register
                PLA                             ;Restore A Register
                RTS                             ;Return to caller
;
;PRINDEX subroutine: Prints a $ sign followed by INDEXH/L
PRINDEX         JSR     DOLLAR                  ;Print a $ sign
                LDA     INDEXL                  ;Get Index Low byte
                LDY     INDEXH                  ;Get Index High byte
;
;PRWORD subroutine: Converts a 16-bit word to 4 HEX ASCII characters and sends to console. On
; entry, A Reg contains Low Byte, Y Reg contains High Byte. Registers are preserved on entry/exit.
; NOTE: Routine changed for consistency; A Reg = Low byte, Y Reg = High byte on 2nd May 2020
PRWORD          PHA                             ;Save A Register (Low)
                PHY                             ;Save Y Register (High)
                PHA                             ;Save Low byte again
                TYA                             ;Xfer High byte to A Reg
                JSR     PRBYTE                  ;Convert and print one HEX character (00-FF)
                PLA                             ;Get Low byte value
                BRA     PRBYT2                  ;Finish up Low Byte and exit
;
;Continue routine: called by commands to confirm execution, when No is confirmed, return address
;is removed from stack and the exit goes back to the Monitor input loop.
;Short version prompts for (Y/N) only.
CONTINUE        LDA     #<SYS_CONT_MSG          ;Get Continue msg
                LDY     #>SYS_CONT_MSG          ;
                JSR     B_PROMPTR               ;Send to terminal
TRY_AGN         JSR     RDCHAR                  ;Get keystroke from terminal
                CMP     #$59                    ;"Y" key?
                BEQ     DOCONT                  ;If yes, continue/exit
                CMP     #$4E                    ;If "N", quit/exit
                BEQ     DONTCNT                 ;Return if not ESC
                JSR     BEEP                    ;Send Beep to console
                BRA     TRY_AGN                 ;Loop back, try again
DONTCNT         PLA                             ;Else remove return address
                PLA                             ;and discard it
                STZ     CMDFLAG                 ;Clear all bits in command flag
DOCONT          RTS                             ;Return
;
; Utility Messages are defined here:
;
INTRO_MSG
        .DB     $0D,$0A
        .DB     " Diagnostic and Test Utility for:",$0D,$0A
        .DB     " MicroDrive PATA Adapter, Version 0.91",$0D,$0A
        .DB     " Copyright 2022-2026 by K.E. Maier",$0D,$0A
        .DB     $00
;
MENU_MSG
        .DB     $0D,$0A
        .DB     " ***************************************************************************** ",$0D,$0A
        .DB     " *                                                                           * ",$0D,$0A
        .DB     " *          MicroDrive (IDE) Functions:                                      * ",$0D,$0A
        .DB     " *             1- Identify Drive information                                 * ",$0D,$0A
        .DB     " *             2- Read a LBA to Memory and Display                           * ",$0D,$0A
        .DB     " *             3- Write a LBA from Memory and Verify                         * ",$0D,$0A
        .DB     " *             4- Sequential Read all LBA                                    * ",$0D,$0A
        .DB     " *             5- Sequential Write all LBA                                   * ",$0D,$0A
        .DB     " *             6- Benchmark for LBA Read or Write                            * ",$0D,$0A
        .DB     " *             S- System Transfer (Memory to Disc)                           * ",$0D,$0A
        .DB     " *                                                                           * ",$0D,$0A
        .DB     " *             Q- Quit, return to DOS/65                                     * ",$0D,$0A
        .DB     " *                                                                           * ",$0D,$0A
        .DB     " ***************************************************************************** ",$0D,$0A,$0A
        .DB     "     Enter Command to continue: "
        .DB     $00
;
QUIT_MSG
        .DB     $0D,$0A,$0A
        .DB     " Returning to DOS/65."
        .DB     $0D,$0A
        .DB     $00
;
USER_INMSG
        .DB     $0D,$0A,$0A
        .DB     " Enter Command or M for Menu."
        .DB     $0D,$0A
        .DB     $00
;
DRIVE_IDENTITY
        .DB     $0D,$0A,$0A
        .DB     " MicroDrive Information:"
        .DB     $0D,$0A
        .DB     $00
;
MODEL_NUM
        .DB     $0D,$0A
        .DB     " Model Number: "
        .DB     $00
;
SERIAL_NUM
        .DB     $0D,$0A
        .DB     " Serial Number: "
        .DB     $00
;
FIRM_REV
        .DB     $0D,$0A
        .DB     " Firmware Revision: "
        .DB     $00
;
MODE_SUPPORT
        .DB     $0D,$0A
        .DB     " LBA Mode Supported: "
        .DB     $00
TOTAL_LBA
        .DB     $0D,$0A
        .DB     " Total LBA Count: "
        .DB     $00
;
LBA_INPUT
        .DB     $0D,$0A
        .DB     " Enter LBA number to Read from: "
        .DB     $00
;
LBA_OUTPUT
        .DB     $0D,$0A
        .DB     " Enter LBA number to Write to: "
        .DB     $00
;
LBA_START
        .DB     $0D,$0A
        .DB     " Enter starting LBA number: "
        .DB     $00
;
LBA_WR_DATA
        .DB     $0D,$0A
        .DB     " About to write LBA from buffer Data below!"
        .DB     $0D,$0A
        .DB     $00
;
LBA_WR_CNFM
        .DB     $0D,$0A
        .DB     " Are you SURE you want to overwrite the LBA?"
        .DB     $00
;
NEXT_LBA
        .DB     $0D,$0A
        .DB     " Display (N)ext LBA or (R)eturn "
        .DB     $00
;
SHOW_NEXT_LBA
        .DB     $0D,$0A,$0A
        .DB     " Displaying Data for LBA: "
        .DB     $00
;
LBA_SEQ_RD_MSG
        .DB     $0D,$0A,$0A
        .DB     " About to read ALL LBAs from MicroDrive!"
        .DB     $0D,$0A
        .DB     $00
;
LBA_SEQ_WR_MSG
        .DB     $0D,$0A,$0A
        .DB     " About to write ALL LBAs to MicroDrive!"
        .DB     $0D,$0A
        .DB     $00
;
LBA_SEQ_TM_MSG
        .DB     " Completion time based on drive capacity."
        .DB     $0D,$0A
        .DB     $00

LBA_SEQ_CFM
        .DB     $0D,$0A
        .DB     " Are you sure you want to"
        .DB     $00
;
LBA_SEQ_CFM2
        .DB     $0D,$0A
        .DB     " Are you REALLY sure you want to"
        .DB     $00
;
LBA_BLKS_RD
        .DB     $0D,$0A
        .DB     "Blocks Read:"
        .DB     $0D,$0A,$00
;
LBA_BLKS_WR
        .DB     $0D,$0A
        .DB     "Blocks Written:"
        .DB     $0D,$0A,$00
;
LBA_BLKS_RD_CMP
        .DB     $0D,$0A
        .DB     " All LBAs have been successfully read!"
        .DB     $0D,$0A
        .DB     $00
;
LBA_BLKS_WR_CMP
        .DB     $0D,$0A
        .DB     " All LBAs have been successfully written!"
        .DB     $0D,$0A
        .DB     $00
;
PATTERN_MSG
        .DB     $0D,$0A
        .DB     " Enter a 16-bit Hex value for the Fill Pattern: "
        .DB     $00
;
LBA_BENCH_INTRO
        .DB     $0D,$0A,$0A
        .DB     " Benchmark Performance Testing to Read or Write",$0D,$0A
        .DB     " a 32MB contiguous block of data starting from",$0D,$0A
        .DB     " the entered LBA address.",$0D,$0A,$0A
        .DB     " The Write Benchmark requires a 16-bit Hex fill pattern.",$0D,$0A
        .DB     " Note: the Write Benchmark will result in",$0D,$0A
        .DB     " LOSS of DATA on the MicroDrive being tested!",$0D,$0A,$0A
        .DB     " Make sure you know what you are doing!",$0D,$0A,$0A
        .DB     " Enter 'R' for Read or 'W' for Write: "
        .DB     $00
;
LBA_RD_BENCH
        .DB     $0D,$0A,$0A
        .DB     " Reading 32MB of LBA data in: "
        .DB     $00
;
LBA_WR_BENCH
        .DB     $0D,$0A,$0A
        .DB     " Writing 32MB of LBA data in: "
        .DB     $00
;
LBA_BENCH_WARN
        .DB     $0D,$0A,$0A
        .DB     " You are about to Write 65,536 LBAs!",$0D,$0A
        .DB     " All Data from starting LBA will be overwritten!",$0D,$0A
        .DB     " Be sure about this before continuing (Y/N)"
        .DB     $00
;
LBA_BENCH_ABORT
        .DB     $0D,$0A
        .DB     " Write Benchmark test aborted!",$0D,$0A
        .DB     $00
;
IDE_CONTROLLER_ERROR
        .DB     $0D,$0A,$0A
        .DB     " An error occured accessing the MicroDrive!",$0D,$0A,$0A
        .DB     "  * "
        .DB     $00
;
SYS_INTRO_MSG
        .DB     $0D,$0A
        .DB     "This will write an image from memory to the Microdrive!",$0D,$0A
        .DB     "Make sure you know what you are doing before you commit!!",$0D,$0A,$0A
        .DB     $00
;
SYS_LBA_MSG
        .DB     $0D,$0A
        .DB     " Enter the Starting LBA (decimal) to write the Memory Image to: "
        .DB     $00
;
BLK_SIZE_MSG
        .DB     $0D,$0A
        .DB     " Enter the number of 512-byte Blocks (decimal) to transfer: "
        .DB     $00
;
RAM_START_MSG
        .DB     $0D,$0A
        .DB     " Enter the Starting RAM address in Hex: "
        .DB     $00
;
SYS_CONFIRM_MSG
        .DB     $0D,$0A
        .DB     " Are you sure you want to overwrite the Disc data? "
        .DB     $00
;
SYS_WRITE_MSG
        .DB     $0D,$0A
        .DB     " Writing Disc Image..."
        .DB     $0D,$0A,$00
;
SYS_COMPLETE_MSG
        .DB     $0D,$0A
        .DB     " System Image written to Disc."
        .DB     $0A,$0D,$00
;
SYS_CONT_MSG
        .DB     " cont?"
        .DB     "(y/n)"
        .DB     $00
;
SYS_ADDR_MSG
        .DB     "    addr:"
        .DB     $00
; BCD multiplicand table:
;
HMULTAB .DB $00, $00, $00, $00, $01             ;BCD weight of least significant HEX digit
        .DB $00, $00, $00, $00, $16
        .DB $00, $00, $00, $02, $56
        .DB $00, $00, $00, $40, $96
        .DB $00, $00, $06, $55, $36
        .DB $00, $01, $04, $85, $76
        .DB $00, $16, $77, $72, $16
        .DB $02, $68, $43, $54, $56             ;BCD weight of most significant HEX digit
;
; HEX multiplicand table:
;
DMULTAB .DB  $00, $00, $00, $01                 ;HEX weight of least significant BCD digit
        .DB  $00, $00, $00, $0A
        .DB  $00, $00, $00, $64
        .DB  $00, $00, $03, $E8
        .DB  $00, $00, $27, $10
        .DB  $00, $01, $86, $A0
        .DB  $00, $0F, $42, $40
        .DB  $00, $98, $96, $80
        .DB  $05, $F5, $E1, $00
        .DB  $3B, $9A, $CA, $00                 ;HEX weight of most significant BCD digit
;
; Data variables used
;
ROWS    .DB     #$10                            ;Default to 16 rows of displayed data
;
; LBA word count variables
;
LBA_LOW_WORD    .DW     $0000                   ;Low word for LBA count
LBA_HIGH_WORD   .DW     $0000                   ;High word for LBA count
;
; MicroDrive Error codes
;       These are the error codes per the Hitachi MicroDrive documentation.
;       The codes are read after an error is returned from a command
;       by executing an IDE Get Status command from BIOS.
;
;The X register will contaim the error code as detailed below:
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
; The codes are indexed here and as they are received, the appropriate
; error message will be displayed.
;
IDE_ERROR_CODES
;
        .DB     %10000000                       ;CRC or Bad Block
        .DB     %01000000                       ;Uncorrectable Data Error
        .DB     %00010000                       ;ID Not Found
        .DB     %00000100                       ;Aborted Command
        .DB     %00000010                       ;Track Zero not found
        .DB     %00000001                       ;Data Address Mark not found
;
; IDE Error handler addresses
;       These are the addresses for the error messages.
;       These are indexed as above, so once the error message is matched
;       above, the index is multiplied by two and the address is used for the
;       error message text string.
;
IDE_ERROR_ADDRESS
;
        .DW     IDE_ERROR_00                    ;CRC or Bad Block
        .DW     IDE_ERROR_01                    ;Uncorrectable Data Error
        .DW     IDE_ERROR_02                    ;ID Not Found
        .DW     IDE_ERROR_03                    ;Aborted Command
        .DW     IDE_ERROR_04                    ;Track Zero not found
        .DW     IDE_ERROR_05                    ;Data Address Mark not found
;
; Error messages are here:
;
IDE_ERROR_00
        .DB     "CRC or Bad Block Error"
        .DB     $00
;
IDE_ERROR_01
        .DB     "Uncorrectable Data Error"
        .DB     $00
;
IDE_ERROR_02
        .DB     "Block ID Not Found"
        .DB     $00
;
IDE_ERROR_03
        .DB     "Aborted Command"
        .DB     $00
;
IDE_ERROR_04
        .DB     "Track Zero not Found"
        .DB     $00
;
IDE_ERROR_05
        .DB     "Data Address Mark not found"
        .DB     $00
;
IDE_ERROR_06
        .DB     "Unknown Error"
        .DB     $00
;
        .ORG    $/256*256+256                   ;Benchmark Buffer (start on page boundary)
BENCH_BUFFER
;
        .END


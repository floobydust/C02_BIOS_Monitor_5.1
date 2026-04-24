;**************************************************************************************************
;*                                                                                                *
;*                            Microdrive Boot Block for Booting an OS                             *
;*                                                                                                *
;*                                                                                                *
;*                                  11/14/2025 (Day/Month/Year)                                   *
;*                                                                                                *
;*                                    Copyright Kevin Maier                                       *
;*                                                                                                *
;*                                     GNU GPL V3 License                                         *
;*                                                                                                *
;**************************************************************************************************
; Boot Block 1.00                                                                                 *
; - Boot Block format for enabling a boot from the Microdrive.                                    *
; - As this is based on 65C02 code to boot an OS from a marked active partition, we don't         *
;       really need to try and be as compatible to a typical Boot Record structure.               *
;                                                                                                 *
; - Once this Boot Block is loaded by the Partition Block loader, control is turned over here.    *
;                                                                                                 *
; - The Partition Loader is coded to load into the C02 Pocket TEA address of $0800 and will       *
;       do a JMP to $0800 when successfully loaded from the Microdrive.                           *
;                                                                                                 *
;**************************************************************************************************
        PL      66      ;Page Length
        PW      132     ;Page Width (# of char/line)
        CHIP    W65C02S ;Enable WDC 65C02 instructions
        PASS1   OFF     ;Set ON for debugging
        INCLIST ON      ;Set ON for listing Include files
;**************************************************************************************************
 ;Include required constants/equates for Boot Block to assemble
;
        NOLIST
        INCLUDE         C02Constants5.asm       ;Constants/Equates - C02 BIOS/Monitor/Hardware
        INCLUDE         C02JMP_Table_5.asm      ;Jump Table entries for C02 BIOS/Monitor
        LIST
;
;**************************************************************************************************
;
; Note that the ORG statement below is hard-coded for specific use with the C02 Pocket SBC!
; - Once this Boot Block is loaded, the following actions are taken:
;       - The block is tested for the signature at the end ($55AA)
;       - If invalid, an error is shown and jumps to the Monitor Warm vector
;       - If valid, boot code loading from the Boot Parameter Block (BPB) data.
;       - Note that the BPB is at the end of Boot Block and is similar to that of the
;               Partition Record. It contains extra information to complete the Boot Process.
;
; The Block data is part of the Boot loader code, i.e., it knows how many blocks to load
; from the drive into memory and the memory address to load to. It also has a pointer to
; the start of executable code, which completes the basic Boot process.
; - Control is now turned over to the executable code that boots the OS.
;
        .ORG    $0800           ;Boot block load address (from Partition block)
;
        LDA     #'*'            ;Get an asterisk
        JSR     B_CHROUT        ;Send to the console
;
; We send an asterisk to the console first to show the Boot Block has been loaded and executed.
;
; Now that the Boot Block has been loaded and executed, we check for the correct signature first.
; - The signature is the standard $AA55, which is at the end of the Boot Block.
; Note that the Boot Block has been loaded to a hard-coded location of $0800, so the signature
;   is located at $09FE - $09FF.
;
        JSR     BOOT_CHKSIG     ;Call Boot Block Check Signature routine
;
; Boot Record has the correct signature, yay!
; - Next, validate the Boot Parameter Block Checksum.
; - If this bad, we show an error message and jump to the Monitor warm vector
;
; Calculate checksum for Boot Parameter Block
;
        JSR     BPB_CHKSUM      ;Call BPB Checksum routine
;
; BPB checksum is good. We should have a correct Boot Block loaded now.
; - The BPB contains details about the Boot Image that will need to be
; - loaded and executed. However, we first need to load the first Block
; - of the Boot Image and examine the Load Header to ensure that its the
; - correct Boot Image. It will be loaded to a hard-coded address that is
; - above the the Boot Block (so we don't overwrite it). 
;
; Load the first Block from the Boot Image
;
        LDX     #$01            ;Set Block count to one
        LDA     #$00            ;Get address for DMA
        LDY     #$0A            ; to transfer to
        JSR     LOAD_BLOCK      ;Call Block load routine
;
; The first Block of the Boot Image has been loaded. This contains the Load Header
;
; The Load Header is the first 16 bytes of the first Block of the Boot Image
; - file. It contains information required to validate it, load it and
; - execute it from Boot Block. The Structure is as follows:
;
; - The 16-bit address to start loading the Boot Image to.
; - The 16-bit address to start the Boot Image (BOOT code jumps to this).
; - The 16-bit address for loading the offset to the start of disk data.
; - A long word for the size of the required disk data (for assigned drives).
; - A 5 character string ID to validate the Boot image.
; - A 1 byte checksum to verify the header itself.
; - Next do a checksum on the Load Header, which is the first sixteen
; - bytes of the Boot Image. The last byte is the checksum:
;
        JSR     HEADER_CHKSUM   ;Call Load Header Checksum routine
;
; Load Header appears good.
; - Now match the Boot Image Signature information against the BPB
; - to ensure we have the correct and matching Boot Image on the disk.
;
        LDX     #5              ;Set index for String ID length
LH_STRING_LP
        LDA     $0A00+10,x      ;Get Load Header string
        CMP     BPB_STRING,X    ;Compare against BPB String ID
        BNE     BAD_HEADER      ;Branch if bad compare
        DEX                     ;Decrement index
        BPL     LH_STRING_LP    ;Loop back until Done
;
; String ID matches, so now we need to boot the full image to the
; correct memory address.
;
        LDX     DISK_BPB+1      ;Get Block count to load
        LDA     DISK_BPB+2      ;Get address for DMA
        LDY     DISK_BPB+3      ; to transfer to
        JSR     LOAD_BLOCK      ;Call Load routine
;


; - Now we need to get the working details on how to boot the OS:
;       Get the starting LBA from the Boot Parameter Block
;       Get the first LBA to load the boot image from
;       Get the block count of how many blocks to load into memory
;       Get the memory location that the boot image will be loaded to
;       Get the Block offset that is applied to the Boot image for it's drive space
;
; BPB passes the checksum test.
; - Now load the first block of the Boot Image into memory location $0A00
; The Load Header is the first 16 bytes of the first Block of the Boot Image
; - file. It contains information required to validate it, load it and
; - execute it from Boot Block. The Structure is as follows:
;
; - The 16-bit address to start loading the Boot Image to.
; - The 16-bit address to start the Boot Image (BOOT code jumps to this).
; - The 16-bit address for loading the offset to the start of disk data.
; - A long word for the size of the required disk data (for assigned drives).
; - A 5 character string ID to validate the Boot image.
; - A 1 byte checksum to verify the header itself.
; 
        
; BPB looks good... now try and load the full Boot Image from the disk
;
        LDX     DISK_BPB+1      ;Get Block count to load
        LDA     DISK_BPB+2      ;Get address for DMA
        LDY     DISK_BPB+3      ; to transfer to
        JSR     LOAD_BLOCK      ;Call Load routine
;

;
; Boot image loaded successfully, now do some checks to ensure it's valid
;
        LDA     DISK_BPB+29     ;Get Address offset into Boot image
        LDY     DISK_BPB+30     ;Low and High byte
        STA     $00             ;Make a Page Zero pointer
        STY     $01             ;to access
;
        LDY     #$05            ;Set count for String ID
STRING_CHK
        LDA     DISK_BPB+24,Y   ;Get String ID from BPB
        CMP     ($00),Y         ;Compare to Boot image location
        BNE     NO_OS_FOUND     ;Bad String ID, No OS found
        DEY                     ;Decrement index
        BPL     STRING_CHK      ;Loop back until done
;
; String ID Validates Boot Image as valid
; - Now we need to transfer the LBA Offset into the Boot Image for partition data
;
        LDA     DISK_BPB+14     ;Get Address offset into Boot image
        LDY     DISK_BPB+15     ;Low and High byte
        STA     $00             ;Make a Page Zero pointer
        STY     $01             ;to access
;
        LDY     #$05            ;Set count for 4 bytes
LBA_OFF_LP
        LDA     DISK_BPB+16,Y   ;Get LBA Offset
        STA     ($00),Y         ;Store to Boot Image Disk offsett
        DEY                     ;Decrement index
        BPL     LBA_OFF_LP      ;Loop back until done
;
; LBA Data block offset transferred to Boot Image
; - we should now have a valid OS loaded and ready to jump to, fingers crossed!
        JMP     (DISK_BPB+4)    ;Jump to Boot image and hope it works!
;
;**************************************************************************************************
;
BAD_BOOT_BLK
;        PLA                     ;Clear return address from stack
;        PLA                     ;
        LDA     #<BAD_BLOCK     ;Get low byte offset
        LDY     #>BAD_BLOCK     ;Get low byte offset
        BRA     MSG_FINISH      ;Finish message send/exit
;
BAD_BOOT_CHK
        LDA     #<BAD_CHKSUM    ;Get low byte offset
        LDY     #>BAD_CHKSUM    ;Get low byte offset
        BRA     MSG_FINISH      ;Finish message send/exit
;
BAD_BOOT_REC
;        PLA                     ;Clear return address from stack
;        PLA                     ;
        LDA     #<BAD_BOOT_MSG  ;Get low byte offset
        LDY     #>BAD_BOOT_MSG  ;Get low byte offset
        BRA     MSG_FINISH      ;Finish message send/exit
;
BAD_HEADER
;        PLA                     ;Clear return address from stack
;        PLA                     ;
        LDA     #<BAD_HDR_MSG   ;Get low byte offset
        LDY     #>BAD_HDR_MSG   ;Get low byte offset
        BRA     MSG_FINISH      ;Finish message send/exit
;
NO_OS_FOUND
        LDA     #<NO_OS         ;Get low byte offset
        LDY     #>NO_OS         ;Get low byte offset
;
;MSG_FINISH
;        JSR     M_PROMPTR       ;Send message to console
;        JMP     M_WARM_MON      ;Warm Boot Monitor
;
MSG_FINISH
        STY     $03             ;Store MSG address
        STA     $02             ;
        LDY     #$00            ;Zero Y index
MSG_LOOP
        LDA     ($02),Y         ;Get Message
        BEQ     MSG_EXIT        ;If end of message, branch
        JSR     B_CHROUT        ;Send to Console
        INY                     ;Increment Index
        BRA     MSG_LOOP        ;Branch back until null found
;
MSG_EXIT
        JMP     M_WARM_MON
;**************************************************************************************************
;
; Supporting Routines:
;
; Check Boot Block Signature
;
BOOT_CHKSIG
        LDA     $09FF           ;Get the last byte of the Boot Record
        CMP     #$AA            ;Compare for signature
        BNE     BAD_BOOT_BLK    ;Branch if not equal
        LDA     $09FE           ;Get signature of next to last byte
        CMP     #$55            ;Check for correct bit pattern
        BNE     BAD_BOOT_BLK    ;Branch if not equal
        RTS                     ;Return to caller
;
; Check Boot Parameter Block checksum
;
BPB_CHKSUM
        CLC                     ;Clear Carry for add
        LDX     #$FF            ;Set index count-1
        LDA     #$00            ;Zero A Reg
BPB_CK_LP
        INX                     ;Increment Index (starts at 0)
        ADC     DISK_BPB,X      ;Add in BPB data
        CPX     #30             ;Decrement count
        BNE     BPB_CK_LP       ;Branch back till done
;
        INX                     ;point to checksum byte
        CMP     DISK_BPB,X      ;A Reg should match checksum
        BNE     BAD_BOOT_CHK    ;Failed, branch and bail
        RTS                     ;Return to caller
;
; Check Load Header Checksum
;
HEADER_CHKSUM
        LDX     #$FF            ;Set Index for counting
        CLC                     ;Clewar Carry for add
        LDA     #$00            ;Zero A Reg
LH_CHK_LP
        INX                     ;Increment Index (starts at #0)
        ADC     $0A00,X         ;Add in Load Header data
        CPX     #15             ;Increment count
        BNE     LH_CHK_LP       ;Loop back until done
;
        CMP     $1000,X         ;A Reg should match checksum
        BNE     BAD_HEADER      ;If Bad match, show error and exit
;
; Load Block(s) from Disk Drive:
;
LOAD_BLOCK
        JSR     B_IDE_SET_ADDR  ;Call BIOS
;
        LDA     DISK_BPB+6      ;Get LBA low
        LDY     DISK_BPB+7      ;Get LBA high
        LDX     DISK_BPB+8      ;Get LBA ext
        JSR     B_IDE_SET_LBA   ;Call BIOS
;
        JSR     B_IDE_READ_LBA  ;Call BIOS to read Boot image
        LDA     IDE_STATUS_RAM  ;Get IDE Status
        LSR                     ;Shift error bit into carry
        BCS     BAD_BOOT_REC    ;Error loading boot record
        RTS                     ;Return to Caller
;
;**************************************************************************************************
;
; Error Messages are kept here:
;
BAD_BLOCK
        .DB     13,10,"Bad Boot Block Signature!"
        .DB     13,10,0         ;Boot Block Signature failed
;
BAD_CHKSUM
        .DB     13,10,"Bad Boot Block Checksum!"
        .DB     13,10,0         ;Boot Block Checksum failed
;
BAD_BOOT_MSG
        .DB     13,10,"Bad Boot Image"
        .DB     13,10,0         ;Boot Image failed to load
;
BAD_HDR_MSG
        .DB     13,10,"Bad Load Header in Boot Image"
        .DB     13,10,0         ;Boot Image Load Header failed Checksum
;
NO_OS
        .DB     13,10,"No Operating System found!"
        .DB     13,10,0         ;No valid OS Image (String ID failed)
;
COPYRIGHT
        .DB     "(c) K.E. Maier 2025"
;
;**************************************************************************************************
; 
;Boot Parameter Block is 32 bytes in length and has the following format:
; - As an OS Boot image might be moved to a different partition/location, the Boot Parameter Block
;       will use a 16-bit address to transfer the starting Data Block allocated to it. Note that
;       this does NOT include the Boot image space, which is separate by design. This provides a
;       level of protection so the OS shouldn't be able to clobber itself by accident.
;
;       Offset          Length          Description
;       0x00            1 byte          BPB descriptor = $65 by default
;       0x01            1 byte          Block count for Boot image (512-byte blocks)
;       0x02            2 bytes         Address to load Boot image to (16-bit)
;       0x04            2 bytes         Address to Start execution of Boot image (16-bit)
;
;       0X06            4 bytes         LBA location of first Block of Boot image
;       0x0A            4 bytes         Total Blocks allocated to Boot image including Boot Block
;
;       0x0E            2 bytes         Address in Boot image to Xfer LBA offset for Block data
;       0X10            4 bytes         Starting Block of Data allocated to OS (non-Boot image)
;       0x14            4 bytes         Total count of Block Data allocated to OS
;
;       0x18            5 bytes         String ID for Boot image to validate it
;       0X1D            2 bytes         16-bit location in Boot image for String ID
;       0x1F            1 byte          8-bit Checksum of BPB
;
;**************************************************************************************************
;
        .ORG    $09DE           ;Offset to boot parameter block
;
DISK_BPB                        ;Start of Boot records
;
;Boot Parameter Block start here:
;
        .DB     #$65            ;BPB descriptor byte
        .DB     #16             ;Block count for boot image (blocks are 512 bytes) 8KB
        .DW     $D000           ;Memory address to load boot image to
        .DW     $E400           ;Boot image address to start execution at
;
        .LONG   131072          ;LBA to start Boot Image
        .LONG   131072          ;Total Blocks allocated to Boot image
;
        .DW     $E6CD           ;Boot image offset for disk data starting block
        .LONG   256             ;Starting Block of Data allocated to OS (this value xfers to Boot image)
        .LONG   131328          ;Block count allocated to OS (Boot image and Data)
;
BPB_STRING
        .DB     "dos65"         ;String ID for Boot image validation
        .DW     $D00B           ;Address in Boot image of String ID to validate Boot image
        .DB     #$1A            ;8-bit checksum byte for BPB
;
;**************************************************************************************************
; Boot Block ends with standard 2-byte signature to show valid record
;
        .DW     $AA55           ;Signature bytes - mark as valid partition record
;
;**************************************************************************************************
        .END
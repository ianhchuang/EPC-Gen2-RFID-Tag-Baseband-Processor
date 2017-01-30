# EPC-Gen2-RFID-Tag-Baseband-Processor
EPC Radio-Frequency Identity Protocols Generation-2 RFID :  
http://www.gs1.org/sites/default/files/docs/epc/Gen2_Protocol_Standard.pdf

GitHub repository :  
https://github.com/Gurint/EPC-Gen2-RFID-Tag-Baseband-Processor

## Introduction
A low-cost low-power baseband processor for EPC Gen-2 UHF RFID Tag
- Verilog language
- synthesized by Synopsys Design Compiler 
- apr by Synopsys IC Compiler
- operated in the lowest frequency (refer to FM0 and Miller Encoder/Decoder)
- clock gating
- operand isolation
- need a memory (in my case, I use a ROM)

## Modules  
<table>
  <tr>
    <td>NAME</td> <td>DESCRIPTION</td>
  </tr>
  <tr>
    <td>bb_proc</td> <td>baseband processor, top module</td>  
    <td>cmd_buf</td> <td>command buffer, serial to parallel</td>  
    <td>cmd_proc</td> <td>command processor, processes received commands</td>  
    <td>crc16</td> <td>CRC-16 encoder/decoder</td>  
    <td>crc5</td> <td>CRC-5 encoder/decoder</td>  
    <td>crg</td> <td>clock/reset generator, timing control</td>  
    <td>fm0_enc</td> <td>FM0 Encoder, operates in the lowest freq.</td>  
    <td>frmgen</td> <td>frame generator, generates preamble, backscattered data, end-of-signaling</td>  
    <td>fs_detector</td> <td>frame-sync detector</td>  
    <td>mem_if</td> <td>memory interface</td>  
    <td>miller_enc</td> <td>Miller encoder, operates in the lowest freq.</td>  
    <td>prng</td> <td>16-bit Pseudorandom number generator</td>  
    <td>rx</td> <td>Receive</td>  
    <td>two_dff_sync</td> <td>Synchronizer, synchronizes signals from clock domain A to B</td>  
    <td>tx</td> <td>Transmit</td>  
  </tr>
</table>

---
title: "The curious case of 'ìe°[^]├UëÕ]Ús   UëÕâýj'"
date: 2018-09-13T00:00:00+00:00
lastmod: 2018-09-13T00:00:00+00:00
tags: [ "firedrake", "debugging" ]
slug: "the-curious-case-of"
---

11 months ago was the last time I touched [firedrake](https://github.com/JustSid/firedrake), and last weekend the urge to mess with it caught me again. So I set up WSL, installed all necessary dependencies and opened firedrake. I fired up the last compiled version I had, just to remind myself of where I had left things, and I QEMU was happy to dump my debug `printf()`'s via the virtual UART into stdout. All was good. Then I compiled firedrake from scratch and it stopped working, or rather, it stopped producing output via the UART. That's strange, I thought, messed with a couple of things and also stashed all my git changes but no avail; No more output via the UART.

Alright, debugger time, QEMU is nice enough to provide a gdbserver that can be connected to. I put a breakpoint in the `kputs()` function and checked it's input: `0x0010718c`. When looking at the memory at the address, I found a single lone null byte which explained why there was no output, `kputs()` figured that it was passed a empty string. That didn't make any sense though, it was early in the boot process and firedrake doesn't do any relocation at that point yet. There is no virtual memory, everything is essentially as GRUB had set it up. Just to make sure I also put a breakpoint into the first instruction run after the kernel is loaded and the null byte was still there. Now, that was interesting!

I tried allocating a buffer on the stack and putting a short string in there, unfortunately Clang was smart enough to detect what it was and also put it into the .rodata section (although separate from the strings). That turned out to be interesting, instead of printing 'Hello' it printed 'ìe°[^]├UëÕ]Ús   UëÕâýj'. Wat?!

Obvious next step: Disassembler. I actually found out that my favourite disassembler, Hopper, runs on WSL and works quite well on Windows with a X-Server installed.

However, Hopper revealed that the address was perfectly valid and pointed into the .rodata section of the firedrake binary. I then compared the working binary from 11 months ago to the one I had now, but couldn't find any differences for the life of me. The sections all looked the same, the access was the same, just GRUB seemed to zero out my .rodata section now? I ended up trying a couple of things and scratching my head some more, but eventually I decided to look at the binary itself and dump its content with readelf. Here are the relevant parts:

    Section Headers:
      [Nr] Name              Type            Addr     Off    Size   ES Flg Lk Inf Al
      [ 0]                   NULL            00000000 000000 000000 00      0   0  0
      [ 1] .text             PROGBITS        00100000 001000 0054eb 00  AX  0   0 16
    [...]
      [59] .rodata           PROGBITS        00107000 008000 00018c 00   A  0   0  4
      [60] .rodata.str1.1    PROGBITS        0010718c 00818c 000235 01 AMS  0   0  1

    [...]

    Program Headers:
      Type           Offset   VirtAddr   PhysAddr   FileSiz MemSiz  Flg Align
      LOAD           0x001000 0x00100000 0x00100000 0x06780 0x06780 R E 0x1000
      LOAD           0x008000 0x00107000 0x00108980 0x003f8 0x003f8 R   0x1000
      LOAD           0x009000 0x00108000 0x00109980 0x24010 0x24010 RW  0x1000
      GNU_STACK      0x000000 0x00000000 0x00000000 0x00000 0x00000 RWE 0x10

     Section to Segment mapping:
      Segment Sections...
       00     .text .text.startup [...]
       01     .rodata .rodata.str1.1 [...]
       02     .bss .init_array 
       03     

And with that, the mystery became clear. `0x107000` is where the `rodata` section was supposed to be. But the ELF program header put its physical address at `0x108980` and GRUB loads the kernel into there, instead of the virtual address (which kinda makes sense, it's bare metal, no virtual addressing). Looking at the known good version actually revealed that both .text and .rodata where in one contiguous segment that spanned the kernel space. Looks like the linker I ended up installing on my fresh WSL install honours the fact that .rodata should be readonly and put it in its own segment. Previously the linker used one segment that had the Read, Write and Execute bits set.

With that mystery cleared up, the solution became to just compile the kernel with the `-fPIC` flag and it all started working again. Time to put firedrake down for another year and see what breaks afterwards.

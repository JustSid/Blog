---
title: "Investigating a X-Plane plugin's crash to desktop"
date: 2017-07-04T00:00:00+00:00
lastmod: 2017-07-04T00:00:00+00:00
tags: [ "debugging", "x-plane" ]
slug: "investigating-a-x-plane-plugin-crash-to-desktop"
---

This post is about a crash to desktop that I investigated in a popular plugin for X-Plane, [X-Assign](https://forums.x-plane.org/index.php?/files/file/12551-x-assign-linmacwin3264/). This happened in my free time, although I had the advantage of having the X-Plane source code at hand.

## Git bisect

My new favourite tool on earth is `git bisect`, which I used to find the offending commit rather quickly. At this point I wasn't sure who was at fault for the crash, X-Plane or X-Assign, since the issue only showed up with the update to X-Plane 11.02 and it was working fine in previous versions. The offending commit however turned out to be rather boring, it simply changed the capacity of a couple of datarefs from 100 to 250. Two things about that were interesting though, first of all, the capacity of the underlying variable was already 250, a change introduced in X-Plane 11. Second of all, those datarefs were input related, namely `sim/joystick/joystick_axis_values`, `sim/joystick/joystick_axis_assignments` and `sim/joystick/joystick_axis_reverse`. So not unreasonable that they would be used by X-Assign. The change however, shouldn't have really broke X-Assign in any way. To figure out what happened, I did was every reasonable person would do: I opened up the disassembler!

## Disassembling X-Assign

Because I already declared `git bisect` to be my favourite tool, Hopper has to be my second favourite tool. I don't often try to take binaries apart, but every time I do, Hopper makes it super easy and pleasant. Ah, who am I kidding, x86-64 assembly is still awful.

Sadly MSVC isn't super keen on leaving useful debug symbols in binaries, so they are way too hard to read. I knew where to look, but I had no idea about the context of the procedure I was looking at. Luckily Clang doesn't strip the binary by default of every symbol, so I tried opening the macOS version of the plugin and who would have thought, the debug symbols were there! I used those debug symbols to manually rename some addresses and references in the Windows version and armed with that I set out to figure out what was happening.

As it turns out, X-Assign almost does it right! And by doing so, it fails hard. It reads the number of assignments for joystick axes by calling `XPLMGetDatavi("sim/joystick/joystick_axis_assignments", 0, 0, 0)` which returns the number of entries in the array. In previous versions this would return `100` but now in X-Plane 11.02 it returns `250`.

The way X-Assign does the parsing of its config files is a bit unconventional, it basically builds a super long format string on the stack and then passes that to `fscanf()`` which reads the whole file at once. In pseudo code we end up with something like:

```c
char buffer[...];

int count = XPLMGetDatavi("sim/joystick/joystick_axis_assignments", 0, 0, 0);

for(int i = 0; i < count; i ++)
    strcat(buffer, "%%i:%%i");
    
fscanf(file, buffer, &arg_01, &arg_02, &arg_03, ...);
```

Now, the problem with that approach is that you need to have a buffer on the stack that is long enough AND you need to supply enough arguments to fscanf(). One way or another, if your buffer is not long enough or you don't supply enough arguments, you'll end up smashing your stack and in the best case a crash (which is exactly what happened). X-Assign assumes 100 axis assignments, so the buffer and arguments are appropriately sized, however, now that X-Plane returns 250 it all starts to go wrong. Obviously the author tried to do the right thing by query-ing X-Plane for what the count, but then it didn't do the appropriate steps to verify it can cope with that.

## Monkeypatching X-Assign

Without source code provided by the X-Assign developer, the only real solution to a temporary fix is to monkeypatch the binary itself! After figuring out why it crashes, the solution becomes overriding the call to XPLMGetDatavi(). Here is the assembly for the whole sequence:

    000000006cc81472 488B1D274E0100         mov        rbx, qword [imp_XPLMGetDatavi]
    000000006cc81479 488B0DB02B0100         mov        rcx, qword [0x6cc94030]
    000000006cc81480 FFD3                   call       rbx
    000000006cc81482 4531C9                 xor        r9d, r9d
    000000006cc81485 4531C0                 xor        r8d, r8d
    000000006cc81488 31D2                   xor        edx, edx
    000000006cc8148a 488B0DA72B0100         mov        rcx, qword [0x6cc94038]
    000000006cc81491 4189C4                 mov        r12d, eax
    000000006cc81494 FFD3                   call       rbx
    000000006cc81496 488D1563BB0000         lea        rdx, qword [0x6cc8d000]  
    000000006cc8149d 4889F1                 mov        rcx, rsi
    000000006cc814a0 4189C5                 mov        r13d, eax

The first two lines load the pointer to the XPLMGetDatavi() function and the dataref pointer for the call ("sim/joystick/joystick_axis_reverse"), afterwards executing the call. A bit further down the line is `mov r12d, eax` in which the return value of the call is assigned to `r12`. The same is repeated with a different dataref ("sim/joystick/joystick_axis_assignments") and the result is assigned to `r13`.

The thing we want to achieve is to load 100 into the RAX register and then nop out the calls. The opcode to load `100` into RAX is:

    48 C7 C0 64 00 00 00

So we'll need space for 7 bytes. Luckily, right before the first call there is a 7 byte instruction already that loads the pointer to the dataref, but that is only needed since it's an argument to the function call and we can safely patch it with our own code. The next thing is to patch the call instruction, which is 2 bytes in the original. Luckily, nop only takes one byte (90 is the opcode), so we can easily patch it. What we'll end up with is:

    000000006cc81472 488B1D274E0100         mov        rbx, qword [imp_XPLMGetDatavi]
    000000006cc81479 48C7C064000000         mov        rax, 0x64
    000000006cc81480 90                     nop
    000000006cc81481 90                     nop
    000000006cc81482 4531C9                 xor        r9d, r9d
    000000006cc81485 4531C0                 xor        r8d, r8d
    000000006cc81488 31D2                   xor        edx, edx
    000000006cc8148a 488B0DA72B0100         mov        rcx, qword [0x6cc94038]
    000000006cc81491 4189C4                 mov        r12d, eax
    000000006cc81494 90                     nop
    000000006cc81495 90                     nop
    000000006cc81496 488D1563BB0000         lea        rdx, qword [0x6cc8d000]  
    000000006cc8149d 4889F1                 mov        rcx, rsi
    000000006cc814a0 4189C5                 mov        r13d, eax

And there you have it, after those changes, X-Assign will work again.
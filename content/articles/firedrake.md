 Soo, the Kernel hacking fever caught me. Again. However, I didn't work any further on [NANOS](https://github.com/JustSid/NANOS "The NANOS repository") since its code base is, to be honest, horrific. NANOS was a hobby project to learn about all these new fancy concepts, and I learned a lot. For example that a Kernel isn't a normal C program or library, which was one of the key design misconceptions I made with NANOS. For example, I started by wondering how the hell I would keep programs from accessing Kernel code and running it, in retrospect this is pretty stupid thinking since the Kernel is protected by the CPU itself (although its totally possible to fail shielding the Kernel properly in the various interfaces the Kernel exposes to the Userland (sys calls)). But not only was I designing the Kernel like a retard, I'm also wondering why the heck this thing ever worked. While I looked through some of my old code, I stumbled every now and then over code that just couldn't possible work, but somehow it worked. At least most of the time.

###Long live the King
So I made the decision to stop working on NANOS and start from scratch, not to make the perfect Kernel, but to learn even more things. I won't lie to you, the new Kernel will be horrible too if you are experienced with Kernel development. I will produce new design catastrophes and in a year from now, I will wonder how the heck this stuff even worked. But in the meantime, I will use it as an opportunity to learn new things. This way, Firedrake was born. Firedrake already implements many features NANOS had while being, as far as I can tell, pretty bug free. But, Firedrake can also do things NANOS couldn't, mainly [Virtual Memory](http://en.wikipedia.org/wiki/Virtual_memory "Wikipedia article explaining Virtual Memory"). Very early in the 'boot process', Firedrake crafts a kernel page directory, maps the kernel and some other stuff (video memory, multiboot information) and then switches over to Virtual Memory. However, what Firedrake can't do at the moment is creating additional third party page directories for started programs, they are all running with the Kernel page directory. However, as of now, this isn't really a problem since the only running task is the kernel daemon which runs in Ring 0 anyway and probably never gets its own page directory.

But there are also things Firedrake can't do, that NANOS could do. This is mainly everything related to programs, and while Firedrake can execute arbitrary programs with multiple threads, it can't load them from memory, disk or whatever. Everything has to be compiled into the Kernel directly. There is also no kind of input possible, no USB or Bluetooth stack and no PS/2 controller support, which means that there is also no Shell or something like this, but hey, it boots!

If you are interested to see the current Code, you can check out the [public GitHub repository](https://github.com/JustSid/Firedrake). MIT License, as usual.

###Design
Now that everything is clear, lets talk about the kernels design for a bit. Firedrake is currently way to bare bone to be either a micro- or monolithic kernel. In my head, I see the picture of a hybrid kernel that is easier to extend than eg. Linux, but thats just a picture and I will probably end up creating a monolithic kernel because its easier. The code of the Kernel is divided into multiple parts, which can be found in the different subdirectories of the /Kernel/ directory. If you boot Firedrake, it needs some starter help from GRUB (or any other Multiboot bootloader), to be mapped into the RAM and get some basic information about the system (we also need to end up in [protected mode](http://en.wikipedia.org/wiki/Protected_mode)). Afterwards, everything in the /bootstrap/ directory kicks in. The first 'file' (so to speak) that runs is the `bootstrap.S` file, which contains a few lines of Assembler to get a basic Stack and call the high level, C written, boot code which can be found in `boot.c`. This file is really simple since it only prepares the 80x25 Terminal and it also initializes some basic modules. Modules are initialized in a strict order, since some of them depend on another module. For example, the scheduler assumes that virtual memory is already enabled and uses a higher level memory allocator which also takes care of mapping the memory. Preparing it before Virtual Memory is switched on leads to crashes. The modules that are initialized are;

  * State (This is a very simple module that just contains state information)
  * Interrupts (This module sets up the IDT, GDT and the PIC)
  * Physical Memory (This module grabs the information about the RAM and creates a heap bitmap)
  * Virtual Memory (This module crafts the kernel page directory, maps everything needed and then enables virtual memory)
  * Scheduler (This module crafts the first process and thread later known as the kernel daemon. It also prepares the PIT for actual scheduling)
  * Syscalls (This module maps every sys call to the appropriate function)

After this step is done, Firedrake will enable interrupts and then waits until the Scheduler did the first scheduling. When the scheduler schedules the next thread for execution, it will copy the CPU state (all general purpose registers and some other registers (ss, cs, eflags etc)) into the previously scheduled thread. Normally this allows the thread to execute at the same position again once its scheduled again, but the first the scheduler runs it will copy the Kernel CPU state into the only thread that exists. This way Firedrake makes sure that the Kernel gets some CPU time and can run some privileged Code, for example calling `hlt` in a loop.

Now the only logic that runs is the scheduler, which schedules a new thread every time the PIT fires (actually each thread is granted a few ticks, from 1 to max 10, and only once they are used up the scheduler will be forced to schedule another thread). However, a tiny little part of the scheduler is also implemented in the kernel daemon, this part has the job of getting rid of died threads and processes (I will write more about process and thread handling in Firedrake at some later point).

There are a few other subsystems that run, although not all of the time, but on demand. The second one is the libc, which just implements a few parts of the standard C library. Mainly things like sprintf, memcpy and the like. Look into `/libc/` for more details! The next subsystem is the memory system, this is split between the physical memory system which handles the physical memory (aka RAM), this is done by having splitting the RAM into pages of 4096 bytes each and having an array of integers of which each bit of an integer represents a single page. Depending on the state of the bit, the page is either free or used. The virtual memory system takes care about finding free pages inside of an page directory and mapping this to physical memory. Then comes the scheduler, again, I will cover this part at a later point in time and then already comes the last subsystem called system. This subsystem basically contains everything that is not part of one of the other systems but also crucial for the Kernel, for example this subsystem contains the interrupt handler, the sys call interface and much more. You real should look into it if you are interested about Firedrake.

###Harnessing the Dragon
If you are still with me, you will probably want to know how to compile Firedrake and maybe hack a few lines into the kernel. If you haven't grabbed the Source Code yet, do it now! `git://fufara.repositoryhosting.com/fufara/fd.git`
Then, grab a Linux distribution of your choice, I use Ubuntu, but you are free to use whatever you want. If you want to create an ISO image for VMWare or VirtualBox, you need to install `xorriso` and `grub-rescue-pc`, to compile the kernel you need to install `llvm` and `clang`. If you are not sure what to do, simply hack this into your Terminal (assuming you use Ubuntu):
	
	sudo apt-get install xorriso
	sudo apt-get install grub-rescue-pc
	sudo apt-get install llvm
	sudo apt-get install clang

Then `cd` into the Firedrake folder and run `make`. If you want an ISO image, you have to run `make install` afterwards, you will then find an ISO image in the /Bootable/ folder. If you need to debug Firedrake, you should also run `make debug`. Everything done? Great, now you can boot Firedrake everywhere where you can run x86 binaries!

If you need to debug something, for example a page fault, you can simply run Firedrake inside Qemu with these arguments:

	// If you have an ISO image
	qemu -d int,cpu_reset -no-reboot /path/to/the/iso-file

	// If you have just the kernel
	qemu -d int,cpu_reset -no-reboot -kernel /path/to/the/kernel

Now Qemu will log every interrupt and CPU reset (e.g. caused by an triple fault) into `/temp/qemu.log`. The last entry might look like this;

    	0: v=0e e=0002 i=0 cpl=0 IP=0008:00100a22 pc=00100a22 SP=0010:001478cc CR2=00004000
	EAX=00004000 EBX=00010000 ECX=00004000 EDX=00000000
	ESI=00000000 EDI=00000000 EBP=001478dc ESP=001478cc
	EIP=00100a22 EFL=00200002 [-------] CPL=0 II=0 A20=1 SMM=0 HLT=0
	ES =0010 00000000 ffffffff 00cf9300 DPL=0 DS   [-WA]
	CS =0008 00000000 ffffffff 00cf9a00 DPL=0 CS32 [-R-]
	SS =0010 00000000 ffffffff 00cf9300 DPL=0 DS   [-WA]
	DS =0010 00000000 ffffffff 00cf9300 DPL=0 DS   [-WA]
	FS =0018 00000000 ffffffff 00cf9300 DPL=0 DS   [-WA]
	GS =0018 00000000 ffffffff 00cf9300 DPL=0 DS   [-WA]
	LDT=0000 00000000 0000ffff 00008200 DPL=0 LDT
	TR =0028 00127160 00000068 0000e900 DPL=3 TSS32-avl
	GDT=     00127120 0000002f
	IDT=     001271e0 000007ff
	CR0=80000011 CR2=00004000 CR3=00001000 CR4=00000000
	DR0=00000000 DR1=00000000 DR2=00000000 DR3=00000000 
	DR6=ffff0ff0 DR7=00000400
	CCS=00000000 CCD=00000008 CCO=SUBL    
	EFER=0000000000000000

This basically is a dump of the processor state, however, we are interested in only two things only at the moment. `v=0e` shows us that the interrupt was a 0e (14 in decimal) interrupt, which is a page fault. EIP is the instruction pointer register, and points to the instruction that caused the page fault. Now lets open the `dump.txt` inside the Firedrake folder and search for `100a22`, the address of the bad instruction:
	
	00100a08 <memset>:
	 100a08:	55                   	push   %ebp
	 100a09:	89 e5                	mov    %esp,%ebp
	 100a0b:	83 ec 10             	sub    $0x10,%esp
	 100a0e:	83 7d 10 00          	cmpl   $0x0,0x10(%ebp)
	 100a12:	74 1e                	je     100a32 <memset+0x2a>
	 100a14:	8b 45 08             	mov    0x8(%ebp),%eax
	 100a17:	89 45 fc             	mov    %eax,-0x4(%ebp)
	 100a1a:	8b 45 0c             	mov    0xc(%ebp),%eax
	 100a1d:	89 c2                	mov    %eax,%edx
	 100a1f:	8b 45 fc             	mov    -0x4(%ebp),%eax
	 100a22:	88 10                	mov    %dl,(%eax) // The crashing line
	 100a24:	83 45 fc 01          	addl   $0x1,-0x4(%ebp)
	 100a28:	83 6d 10 01          	subl   $0x1,0x10(%ebp)
	 100a2c:	83 7d 10 00          	cmpl   $0x0,0x10(%ebp)
	 100a30:	75 e8                	jne    100a1a <memset+0x12>
	 100a32:	8b 45 08             	mov    0x8(%ebp),%eax
	 100a35:	c9                   	leave  
	 100a36:	c3                   	ret

Okay, so apparently`memset()` is the bad boy. Now, if you haven't done anything, you need to go up the stack and look what happened before, but if you happened to create a function that allocates memory, maps it and then overwrites it with zeroes using memset… well, just add 1 and 1 ;)
I haven't written a blogpost in a long time, although I really wanted to, but real life and a new project kept me busy. This is also the reason why there haven't been any Firedrake updates lately, but don't worry, the project is far from being dead and there is some progress (and there going to be more in the future). I'm going to write more blogposts about Firedrake in the near future, but in the meantime, I would like to write about register renaming. A few months ago, there was an article on, I think, [#AltDevBlogADay](http://www.altdevblogaday.com/) about CPU optimizations, talking about caches and it also briefly touched the topic of register renaming. The comment section was full of people asking for a more in depth article about this, but as far as I'm aware, there never was an in-depth article, so that's why I decided to write about this.

## Preface
I assume a certain degree of knowledge about CPUs. Don't worry, you don't have to be an expert, but if you have never heard of instruction pipelining or the fact that a CPU is using a clock to do its work, you might want to reconsider reading this. Also worth noting; This blogpost is written with x86 and x86-64 in mind! While some of the concepts are true for other architectures as well, not every architecture behaves this way. Please keep in mind that a modern CPU is an incredibly complex piece of hardware and that this blogpost doesn't aim to be a scientific paper, so a lot of things are simplified.

## The problem
Modern CPUs use a variety of techniques to keep the performance high without increasing the clock speed at the same time. This is done because increasing the clock speed is virtually impossible nowadays, because power consumption and heat generation would be immense, and there is also the physical limitation of signal propagation and contamination delay. The most known technique is probably multi-core CPUs, which are nowadays standard on desktops and even mobile devices. By duplicating the CPU, the throughput is, in theory, duplicated as well, although it requires that the executed program can benefit from multiple cores. However, not everything can benefit from multithreading for various reasons, so maximizing the throughput even for single threaded programs is still desirable. One of the many ways to do this, is by duplicating some of the functional units on a single core, for example by introducing a second [ALU](http://en.wikipedia.org/wiki/Arithmetic_logic_unit), instead of having just one. This way the CPU can achieve so called instruction level parallelism ([ILP](http://en.wikipedia.org/wiki/Instruction_level_parallelism)), by fetching and decoding multiple independent instructions at the same time and dispatching them to the redundant functional units. In the best case this means that the CPU can complete two or more instructions in the time that it would usually take to complete one, depending on the program flow and which and how many functional units are made redundant. A CPU with such an architecture is called a [superscalar CPU](http://en.wikipedia.org/wiki/Superscalar), and such an architecture is used in virtually every CPU made in the last decade (it's safe to assume that every desktop CPU is a superscalar CPU).

### Data dependency
One of the biggest challenges with superscalar CPUs is keeping the functional units saturated at all times, because the moment it becomes impossible for the CPU to parallelize instructions, the throughput of completed instructions will drop significantly. Although there are ways to deal with an unsaturated CPU, for example by using the unused resources for [speculative execution](http://en.wikipedia.org/wiki/Speculative_execution) to predict the future program flow, it is often more desirable to keep the CPU saturated with the execution of the actual program, since speculative execution may waste resources by doing unneeded calculations, which in return rise the power consumption without any performance benefit. However, not everything can be parallelized, because an instruction may impose certain dependencies on a previous instruction, for example by using the result of a previous calculation. A simple example for this is the following pseudo code:

	r1 = r1 + r2 // Add register r1 and r2 and store the result in r1
	r1 = r1 + r3 // Add stored result in r1 and r3 and store the result in r1
	
In this case it's impossible for the CPU to parallelize the two instructions, because the second instruction depends on the result of the first one in a so called [data hazard](http://en.wikipedia.org/wiki/Data_hazard). Data hazards are problems that occur when two or more instructions access the same location (either by reading from or writing to it), and require the CPU to execute the program in order to avoid race conditions. 

There are three possible types of data hazards that the CPU has to take care of in order to avoid race conditions:

 * `Read after write` or `RAW`, demonstrated by the example above, requires that a read from a location returns the result of the last write to that location in the program order. `RAW` is a true dependency, meaning that the CPU has to execute the program in order.
 * `Write after read` or `WAR`, requires that a value read from a location must not return the result of a future write. `WAR` dependencies are also known as false dependencies.
 * `Write after write` or `WAW`, requires that, when multiple instructions write into a location, the location must hold the result of the last write. `WAW` dependencies are also known as output dependencies.

A huge problem with data hazards is the fact that x86 has only 8 general purpose registers (some of them not even being general purpose at all). Even x86-64 is limited to 16 registers, so the compiler has to reuse registers and thus introduce data dependency along the way.  
There have been efforts of solving these problems offline using the compiler, by introducing more registers and giving the compiler better ways of telling the CPU about the program flow (for example the [Itanium](http://en.wikipedia.org/wiki/Itanium) architecture has 128 general purpose registers and allows the compiler to do speculative execution, branch prediction and register renaming), but these efforts are limited to the high-end supercomputer and server market and introduce their own problems.

## Register renaming
`WAR` and `WAW` dependencies can be resolved by using register renaming, a technique that allows the CPU to rename a register at runtime. To make this a bit easier to understand, try to not think of a register as a fixed location but merely a pointer to some location. The location the register names resolves to is decided by the CPU, and can differ from instruction to instruction, by "renaming" the register, the CPU changes the location the register name resolves to. Here is an example of a `WAR` dependency:

	r4 = r1 + r2 // Add register r1 and r2 and store it in r4
	r2 = r1 + r3 // Add register r1 and r2 and store it in r2
	[r4] = r2 // Store the result of register r2 into the memory location pointed to by r4
	
As you can see, the first instructions reads from `r2` while the second instruction writes to `r2`. Without register renaming, the CPU has to wait for the first instruction to complete before it can continue with the second and third instruction, because the first instruction depends on register `r2`, which would be overwritten by the second instruction. This is why `WAR` dependencies are called false dependencies, the dependency isn't the actual result of the previous instruction, but only its location. With register renaming however, the CPU can rename the `r2` register in the second instruction, allowing the first two instructions to be computed in parallel:

	r4 = r1 + r2
	r2(r5) = r1 + r3
	[r4] = r2(r5)
	
In this example, the CPU has remapped the location of the register `r2` to the location of register `r5` (indicated by the `r5` in parentheses). Note that this is completely invisible to the executed program! The program itself is never modified in any way and for all intents and purposes it looks like the CPU is reading and writing to and from the register `r2`. Register renaming is always invisible to the executed program(s), if you stop your program in a debugger and look at the content of the registers, you are guaranteed to see the expected result (that is, if you stop it between the second and third instruction of the example program above, you will see the result of `r1` + `r3` in the `r2` register).

Now, you may have noticed that I wrote earlier that the problem was that there are not enough registers available, so renaming one general purpose register to another general purpose register isn't going to work, because the program is most likely using all registers already. That's why there is a distinction between architectural and physical registers. The architectural registers are the ones provided by the instruction set of the CPU (for x86 this means the `eax`, `ebx`, `ecx`, `edx`, `ebp`, `esp`, `edi` and `esi` registers), and these are the only registers that you can visibly access from within your program. However, a CPU that uses register renaming doesn't actually offer the architectural registers but instead uses a set of physical registers (it usually has somewhere between 64 and 256 physical registers) to which the architectural registers resolve to. Each architectural register can resolve to an arbitrary physical register, and the CPU can remap architectural registers to physical registers for any instruction.

Here is the above example program again, this time with the physical register the architectural register resolves to written in parentheses:

	r4(p4) = r1(p1) + r2(p2)
	r2(p5) = r1(p1) + r3(p3)
	[r4(p4)] = r2(p5)

When the CPU decodes an instruction, it does an implicit dependency check of the instruction against every pipeline that contains a previous instruction of the program stream. There are three possible outcomes of that dependency check:

  * 1) The instruction doesn't depend on a previous instruction
  * 2) The instruction depends on a previous instruction, but the dependency is either a `WAR` or `WAW` dependency and can be resolved using register renaming.
  * 3) The instruction depends on a previous instruction, but the dependency can't be resolved (eg a `RAW` dependency).
  
In the first two cases, the CPU will hand the instruction over to the execution unit (after renaming the register in the second case), however, in the third case the CPU has to stall the pipeline until the dependency is resolved.

Like already mentioned, register renaming can also be used to resolve `WAW` dependencies, for example in this program:

	r1 = r5 + r3
	r1 = r2 + r4
	
By simply renaming the `r1` register, the CPU can execute both instructions in parallel, without having to wait for the first instruction to complete before it can write the result of the second instruction.  
(Okay, I lied, in this example the CPU can simply discard the first instruction since the result is never used, but for the sake of simplicity, let's assume that the first instruction either alters the state of one of the control flags in a way that isn't overwritten by the second instruction or that there is another instruction in between that depends on the result of `r1`).

Another advantage of register renaming is that it allows the CPU to execute certain types of loops in parallel, which would normally be impossible because the registers are reused in every iteration of the loop. However, register renaming can't resolve `RAW` dependencies, like the example posted in the `Data dependency` section.

## Wrap up
Like already mentioned, this blogpost simplifies a lot things! For example the physical registers are much more complex and usually consist out of a list of integer and floating point registers (instead of one unified set of registers like I made it seem). If you are interested in these kinds of things, you should read [this](http://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.91.2599&rep=rep1&type=pdf) paper, which discusses this in much deeper detail and also covers a few more things.
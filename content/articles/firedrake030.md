Let's talk about Firedrake and the upcoming 0.3 release (nicknamed [Jormungand](http://en.wikipedia.org/wiki/J%C3%B6rmungandr)). Although it's not completely finished yet, there already is a tremendous amount of changes that I'm really proud of (to put it into numbers, so far there have been made 8839 additions, adding up to a total of 18615 lines of code). Of course there are the usual suspects like the memory manager, scheduler and interrupt controller, but there are also lots of other changes and additions that made it into the repository so far.

Want to get your hands on the changes made so far? Head over to the Firedrake [repository](https://github.com/JustSid/Firedrake) and checkout commit [00ccd5c84b](https://github.com/JustSid/Firedrake/commit/00ccd5c84bd0ea52a9059fbe6ed1b82d3c47b3bc)!

## ioglue and libio
The major new feature of Firedrake at this point is, without doubt, the in-kernel runtime link editor. It's able to load, relocate and link dynamic ELF binaries, inside of the kernel. As of now the the relocation isn't done lazily but as soon as the dynamic linker is invoked, however, the final release will contain lazy relocation through the [PLT and GOT](http://www.technovelty.org/linux/plt-and-got-the-key-to-code-sharing-and-dynamic-libraries.html). Keep in mind though that ioglue is **not** a replacement for `ld.so`, it works inside the kernel only and loads libraries directly into the kernel space where they are also executed!

So, why exactly would one want to inject code into a running kernel (I mean, seriously, those things are fragile enough already)? Obviously to extend the kernel with new functionality and drivers. And that's exactly where libio kicks in. Libio is the API Firedrake provides to extend the kernel, it's written in C++ and if you are familiar with OS X you will see that it shares some ideas with `IOKit` and the KPI. Libio provides a couple of things that aren't normally found in a C++ environment and there are also things it doesn't provide which you are probably used to; No RTTI, no standard library, no exceptions. The goal is to provide a clean and object oriented interface to the kernel without much of the C++ bloat. The memory model is also different, for the most parts it's a reference counting environment you get there (without the use of shared pointers). There are very few exceptions to this (namely two classes, `IODatabase` and `IOSymbol`), but they are usually not encountered when working with libio, so it's safe to say that libio provides a reference counting environment.   
Additionally you get a lot of abstraction from libio, for example there are three container classes (`IOArray`, `IODictionary` and `IOSet`), and in the final release probably more (planned are counted sets and andersson trees). It also provides you with means of locking and synchronizations (`IOSpinlock` and `IORunLoop`, mutexes and semaphores in the future), message and event dispatching, multithreading, symbol lookup and of course actual driver related stuff like interrupt handling.

### Disclaimer
libio isn't finished yet. Not only is it's API subject to change, but some of the stuff I mentioned here isn't even in the repository yet.

## Debugging and performance for 100
Debugging of kernels is a pain in the ass. Mostly because there is no underlying OS that catches you in case something goes wrong and then prints you a nice dump of everything the crashed process did. As of now you can use the `syslog()` function for printf style debugging, you can place hardware breakpoints and you can have the kernel dump a complete stacktrace of the current thread.

With Firedrake 0.3 you can still do all that, but you can also do more stuff.  
One major change is the `syslog` implementation, up until now it wasn't multithreading safe, meaning that two or more threads were able to write to the video memory at the same time, resulting in strange artifacts (and crashes). Now it's completely multithreading safe, each message is queued inside a new process called `syslogd` which will then write out every message exactly in the order they were received. It also makes sure that every committed message is eventually written out, even if there is a kernel panic.

The stacktrace implementation has been extended quite a bit as well, for example you are now able to create stacktraces for threads different than the currently running one and it now also catches and symbolicates frames from libraries loaded via libio, which looks like this (the `+ 0x3000` is the relocation base of the library):

![stacktraces](/firedrake01.png)

There is another new debug and performance feature called watchdogd inside Firedrake 0.3. It's a special process running inside the kernel which samples each kernel thread every 5 milliseconds and looks what they are currently doing. Then it puts each sample result in a counted set (okay, it's just a set, not a counted one…) and if needed, it prints a nicely formatted list with the 15 functions the thread spent the most time in. Example of the unit test thread:

![watchdogd](/firedrake02.png)

As you can see, `halloc()` is a real performance hog, and if you wanted to improve performance, this would be the low hanging fruit to optimize. This is a very simple, yet efficient way to track down performance bottle necks. Keep in mind though that it's not a complete time based sampler, ie. it doesn't care about the call tree and just looks at the function the process is currently in!

## New container types
Up until now, Firedrake only knew one type of container: Linked lists. While they work reasonably well for small things, they aren't the perfect data structure for every case. So in addition to greatly improved linked lists, Firedrake now also knows about [Andersson Trees](http://en.wikipedia.org/wiki/AA_tree), [Arrays](http://http://en.wikipedia.org/wiki/Array_data_structure) and [Hash Tables](http://en.wikipedia.org/wiki/Hash_table). All of them with their own set of unit tests to make sure that they work as intended. I also tried to make sure that all container have roughly the same API, ie. all of them follow the same naming conventions.

Here is some example code that shows arrays and lists:

	// Search through the dependencies
	array_t *dependencyTree = array_create();
	array_addObject(dependencyTree, library->dependencies);
	
	for(size_t i=0; i<array_count(dependencyTree); i++)
	{
		list_t *dependencies = array_objectAtIndex(dependencyTree, i);
		struct io_dependency_s *dependency = list_first(dependencies);
		while(dependency)
		{
			symbol = io_librarySymbolWithName(dependency->library, name, hash);
			if(symbol)
			{
				*outLib = dependency->library;
				array_destroy(dependencyTree);
				
				return symbol;
			}
	
			if(list_count(dependency->library->dependencies) > 0)
				array_addObject(dependencyTree, dependency->library->dependencies);
			
			dependency = dependency->next;
		}
	}
	
	array_destroy(dependencyTree);

There is also another new type called `iterator_t`, which can be used to iterate over the contents of a container. Currently only Andersson Trees can be enumerated using this API, but the final release will contain support for all container types. It's also trivial to add iterator support for other container types since the iterator API relies on callbacks instead of making assumptions about the container itself, so the actual implementations is part of the container.

## Additional stuff and the future
Obviously those aren't all the changes that made it so far into the repository, for example there is also a new time module that is able to track time with millisecond accuracy, heaps are now mutable and can grow in size and much more. There are also lots and lots of bug fixes, for example a critical bug in the physical memory manager has been fixed, bugs in various libc functions are also fixed etc. This really is a huge release, not only when it comes to features but also the overall stability of the kernel. But hey, that's not all that's coming; There will also a complete virtual filesystem implementation that allows the creation of custom filesystems (and obviously they can be linked at runtime into the kernel, thanks to ioglue and libio).

There is also an incomplete libc implementation coming for the userland which will be used for a `ld.so` implementation, which will then allow the usage of dynamic libraries in third party userland programs. However, I'm not sure if these two will make it into 0.3 or if they are included in 0.4 since 0.3 is already such a huge release.
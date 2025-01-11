+++
title = "Building a Compiler Backend (Part 6: macOS)"
date = 2025-01-11T10:00:00+10:00
summary = "The story of how I became a compiler developer, I guess. In this final part, I'll look at what it takes to target Apple's desktop operating system."
tags = ["Programming Languages", "Callisto"]
+++

Welcome to the final entry in [this series]({{< ref "/tags/callisto" >}}) on the ARM64 backend for [Callisto](https://callisto.mesyeti.uk/). The initial ARM64 backend I developed only supported creating executables for Linux (and technically bare-metal, though I've never tried it).

Because my real goal with this backend was to run Callisto code natively on my Apple Silicon Mac, I needed to expand this with macOS support. I also wanted to extend the existing macOS support in the x86_64 backend. Shouldn't be too hard, just change a few checks and commands, then port the OS core file, right?

Well...

# Symbol Names

Let's start with a simple one. On macOS, which uses the Mach-O object format, symbols in executable files have an underscore prefix -- at least those that conform to standard C calling conventions do. This matters in a few places in the Callisto compiler:

- The entry point, which on macOS will always be the C-style `main` function. To avoid a missing symbol error, the compiler just needs to use `_main` as the entry point name in its assembly output.
- Externs -- functions declared in the Callisto source code that are to be linked from another object file. Every extern declared needs to have its name updated in the assembly output, so I created a helper `ExternSymbol` method that adds the underscore prefix, but only if the current target is macOS.

These changes are pretty simple, and apply in exactly the same way on x86_64 and ARM64.

# Making some PIE

PIE, or Position Independent Executables, are executable files that can be loaded at any address in memory. This is mainly accomplished using code that works with relative addresses rather than absolute addresses, as absolute addresses would become invalid after loading the executable at a different address.

Neither Linux nor macOS *require* PIEs, but macOS has some restrictions that mean some position-independent code must be generated. Specifically, the ARM64 `LDR` pseudo-instruction can't be used to load addresses into registers. This is because it places the actual value to load in memory, somewhere after the instruction, and uses a real `LDR` instruction to load that value. When the value being loaded is an address, the dynamic linker would have to patch the address in when loading the executable. On macOS, this is impossible, as the `.text` section that holds the address is always made read-only.

The fix here is to avoid `LDR` entirely for addresses. Much like `ExternSymbol` from the last section, I created a helper function to emit code which loads an address into a register, with different output on macOS. On macOS, it generates code like the following:

```asm
    # Loads the memory page containing __global_a (relative to instruction pointer)
    adrp x9, __global_a@PAGE
    # Adds the offset within that page to __global_a
    add x9, __global_a@PAGEOFF
```

After this, `x9` will contain the address of `__global_a`, calculated only using relative values and the current instruction pointer.

x86_64 programs run into a similar issue on macOS, but the fix there is mostly automatic using NASM's `default rel` option.

# System Calls

macOS is a Unix system, so it at least shares some of the same kinds of system calls with Linux, which was a helpful starting point for implementing the macOS cores. The calling conventions are also similar, so for some calls only a few tweaks were needed, like this:

```asm
# Linux
func printch begin asm
    "sub x19, x19, #8"
    "mov x8, #64"
    "mov x0, #1"
    "mov x1, x19"
    "mov x2, #1"
    "svc #0"
end end

# macOS
func printch begin asm
    "sub x19, x19, #8"
    "mov x16, #4" # Change the syscall number, and place it in x16, not x8
    "mov x0, #1"
    "mov x1, x19"
    "mov x2, #1"
    "svc #80" # Use 0x80, not 0x0
end end
```

These changes, as well as some redefined constants, covered `IO`, `File`, `Time`, and `Exit`. The only remaining special case was `Heap`, which turned out to be a little harder. Callisto has two implementations of `Heap`, depending on whether a program is linked with libc or not. With libc, Callisto just defines `malloc`, `realloc`, and `free` as externs, letting libc take care of the actual implementation. Without libc, it instead implements a very simple wrapper over `mmap`, `mremap`, and `munmap`. This has the downside that memory can only be allocated in entire pages, but it is easy to implement. 

`malloc` and `free` are easy enough to port to macOS, following the previous method -- the `mmap` and `munmap` calls work basically the same here as on Linux. But then comes `realloc`, which has to call...

# `mremap`

Unfortunately, there's no such thing as `mremap`. It just doesn't exist as a system call on macOS. I hunted around for an equivalent, but had no luck. Without `mremap`, there's no simple way to implement `realloc`, so at this stage I had two options:

1. Implement a proper memory allocator in Callisto that can provide a custom implementation of `realloc`, without depending on `mremap`.
2. Drop `Heap` support.

I chose option 2, but I made sure that the libc-based versions of the functions worked correctly, which brings us to:

# Linking libc

On macOS, this can actually be a little challenging, because system libraries aren't stored in the typical location for a Unix system. Apple chose to organise many of their development libraries and tools into self-contained SDKs, which are stored in **/Library/Developer/CommandLineTools/SDKs** (possibly somewhere else with a full Xcode install). This is where the library we want to link is, but how do we tell `ld` that?

The `-syslibroot` argument to `ld` is the key, or at least part of it. Using this tells `ld` where to find the system components when linking, but it still has a downside -- you have to specify the exact path of the SDK to use. Hardcoding this path into the Callisto compiler wouldn't be right, as it would need to be updated to point to newer SDKs regularly, and expecting the user to provide the path makes the user experience worse. Luckily, using another developer command, it's possible to automatically locate the current SDK: `xcrun --sdk macosx --show-sdk-path`. By passing the output of this command to `-syslibroot`, I was finally able to get Callisto to link with C libraries on Mac.

# That's all folks!

With this part complete, I'm finished with the Callisto post series for now. ARM64 and macOS support has been in Callisto for some time now, and seems reasonably stable, so I'm happy with what I achieved! I'll continue to maintain these features as needed, as well as work on some small Callisto related projects, but this particular project is done.

+++
title = "Building a Compiler Backend (Part 3: Standard Library)"
date = 2024-09-16T10:00:00+10:00
summary = "The story of how I became a compiler developer, I guess. As one final stop before I start explaining the new backend features, I'll take a look at the Callisto standard library."
tags = ["Programming Languages", "Callisto"]
+++

In my last post, I said this:

> I'll write a (probably shorter, and less code-heavy) post about Callisto's standard library.

Turns out that was a complete lie. Enjoy this slightly longer, code-heavier post!

# Starting From Scratch

Usually, when I write code, I prefer not having to create *everything* myself. While it would absolutely be possible to start from a minimal base and write all the code to handle I/O, data structures, memory management and so on, most languages feature a standard library which contains all of these tools ready for developers to start building the next revolutionary piece of tech (hopefully).

In Callisto, this standard library lives in a [separate repository](https://github.com/callisto-lang/std), which is included as a submodule of the main compiler repo. This library needs to be specified when compiling a Callisto program that uses it - this is done with the compiler option `-i std`, which affects the search path when processing `include` statements.

Callisto's standard library is split into two main parts: **cores**, and **std**. Here, I'm going to have a look through what each does, some of the functionality that is included at this stage in development, and where the standard library needs to be extended when adding new CPU and OS support. This post will have a reasonable amount of Callisto code, which unfortunately I cannot highlight nicely at this point in time, so it will appear without any syntax highlighting. As a reminder, Callisto is a [stack based language](https://en.wikipedia.org/wiki/Stack-oriented_programming) so most code will look like [reverse Polish notation](https://en.wikipedia.org/wiki/Reverse_Polish_notation), but block constructs like functions, if, and while are pretty typical.

# std/

I'll start with std, because it closely resembles most people's idea of a standard library. This is where common useful functions are defined, and the code in std is pretty straightforward -- any other library you could write in Callisto would likely have a similar structure. Here are some of the definitions:

## std/ops.cal

This file contains a handful of general purpose functions for common operations. First up, it contains functions to increment and decrement a value:

```text
## ## (Inline) ++
## Parameters: cell num
##
## Returns num + 1
inline ++ begin
	1 +
end

## ## (Inline) --
## Parameters: cell num
##
## Returns num - 1
inline -- begin
	1 -
end
```

There are a few interesting things we can learn from these functions:
- Callisto supports inline functions (specified with `inline` instead of `func`), which don't compile into any sort of jump to the function body, and instead insert their definitions directly where they are used. This means that `41 ++` and `41 1 +` will produce the exact same code in the output binary.
- Pretty much any symbol is valid in a Callisto identifier, except for `[`, `]`, and `&`. Even numbers are allowed, as long as the identifier is not completely numeric.
- There is a convention for documentation comments, starting with `##`, and formatted in Markdown. These comments can be extracted using the [caldoc](https://github.com/callisto-lang/caldoc) tool, which is used for the [official documentation site](https://callisto.mesyeti.uk/docs). From now though, I'll hide the documentation comments, since I'm explaining the functions anyway.

The other functions in ops.cal are `copy_mem` and `fill_mem`, which are Callisto versions of the C functions `memcpy` and `memset` for bulk memory operations:

```text
func copy_mem addr dest addr src cell n begin
	let cell i
	0 -> i

	while i n < do
		src b@ dest b!
		i ++ -> i
		dest ++ -> dest
		src ++ -> src
	end
end

func fill_mem addr dest cell n cell value begin
	let cell i
	0 -> i

	while i n < do
		value dest b!
		i ++ -> i
		dest ++ -> i
	end
end
```

These two functions just use simple loops to perform the copy and set operations, but we also see Callisto's function parameter support (which was only added about a month ago). This is basically just a convenient way to define multiple local variables and store the top value of the stack into them, and is used commonly throughout the standard library.

## std/array.cal

The Callisto compiler provides some basic support for arrays, defining the struct used to represent them and supporting array literals (including string literals), but any operations on those arrays have to be defined in the standard library. The struct definition for the `Array` type would look like this if it were written in Callisto, rather than built in to the compiler:

```text
struct Array
    usize length
    usize memberSize
    addr  elements
end
```

As you can see, arrays store the size of the elements, not just the number of elements, and this is important in order to handle byte-oriented data like strings as well as arrays of full cells. This means that operations on arrays will need to check the size of the elements to produce the correct behaviour, like in `a@`, the function for getting one item from an array (simplified by removing conditional compilation):

```text
func a@ cell offset addr arr begin
	arr Array.memberSize + @ offset * -> offset
	arr Array.elements + @ offset +

    if arr Array.memberSize + @ 1 = then
        b@
    elseif arr Array.memberSize + @ 2 = then
        w@
    elseif arr Array.memberSize + @ 4 = then
        d@
    else
        @
	end
end
```

First, the offset in bytes is calculated, then added to the starting address of the array elements. Then, the `memberSize` of the array is used to select the correct `@` variant for the size (byte, word, double word, or cell). You can probably imagine how the `!` (store) version of this function looks. array.cal also contains a function for checking array equality (see below), as well as some convenience functions for setting all fields of an `Array` struct at once (which I won't show here).

```text
func a= addr arr1 addr arr2 begin
	if arr1 @ arr2 @ = not then
		false return
	end

	let cell i
	0 -> i

	while i arr1 @ < do
		if i arr1 a@ i arr2 a@ = not then
			false return
		end

		i 1 + -> i
	end

	true
end
```

## std/io.cal

This file is where the I/O functions live, for printing numbers and strings to standard output. You might ask "Isn't that just output? Why is it called **i**o.cal?", and you'd be completely right, at least for now. Once Callisto has a standard function for getting input from the user, this is almost certainly where you'll find it, but for now only half of the I/O duo is here.

io.cal contains some functions for printing specific types of data, such as `printdec` and `printstr`:

```text
func printdec_loop begin
	if dup then
		dup 10 / printdec_loop
		10 % 48 + printch
	else
		drop
	end
end

func printdec begin
	if dup then
		printdec_loop
	else
		drop 48 printch
	end
end

func printstr addr arr begin
	let usize length
	let usize i

	arr @ -> length

	while i length < do
		i arr a@ printch
		i 1 + -> i
	end
end
```

`printdec` has a helper function, `printdec_loop`, which works in an interesting way. It doesn't actually loop explicitly, instead calling itself creating a loop by recursion. If the loop worked by calculating the input value modulo 10, printing that character, then calling `printdec_loop` again with the input divided by 10, the resulting output would be reversed -- the least significant digit would be printed first. Instead, the recursive call to `printdec_loop` happens first, leaving each division of the number on the stack, then while returning back up the stack, the values are printed.  `printstr` on the other hand is much more straightforward, using a plain `while` loop.

Also in io.cal, we have a handy function for formatted output, very similar to C's `printf`, though with fewer options. It works by looping through a string like `printstr`, but checks for `%` symbols along the way and calls the other print functions when necessary -- this will pull additional arguments off the stack, intended to be used like this: `12 34 "%d %x" printf`.

```text
func printf addr fmt begin
	let cell i
	let cell ch

	while i fmt @ < do
		if i fmt a@ '%' = then
			i 1 + -> i
			i fmt a@ -> ch

			if ch 's' = then
				printstr
			elseif ch 'd' = then
				printdec
			elseif ch 'X' = then
				printhex
			end
		else
			i fmt a@ printch
		end

		i 1 + -> i
	end
end
```

## std/conv.cal

This is the last file in std that I'll explain, and this one is mostly my code! One of the first things I added to Callisto was a function for converting strings to integers, because I needed to read integer values from the command line arguments, and this is where that function lives.

```text
func parse_int addr arr begin
	let cell pos
	let cell len

	0 -> pos
	arr Array.length + @ -> len

	0
	while pos len < do
		10 * pos arr a@ '0' - +
		pos 1 + -> pos
	end
end
```

The implementation of it is reasonably standard for integer parsing, reading one character out of a string at a time, and using it to update an accumulator by multiplying by 10 and adding the digit value. The accumulator in this case is stored directly on the stack, avoiding unnecessary local variable accesses.

There are other files in the std directory too, but you probably get the idea by now, so let's move on to:

# cores/

I hinted in the first post of this series that in Callisto, even basic arithmetic operations are just functions, although they are implemented in assembly rather than higher level Callisto. This is true for almost all of the low level operations in Callisto, save for a few like `call` (for calling function pointers). The code implementing these lives in the cores directly of the standard library, but as it is largely written in assembly which is CPU-specific and sometimes even OS-specific, the structure is not quite as straightforward.

## cores/select.cal

Usually, the only file you'll need to interact with from cores is cores/select.cal. This needs to be included at the start of pretty much every Callisto program, and takes care of including the other CPU and OS specific files. It just contains a collection of `version` blocks with `include` statements inside:

```text
version RM86
	include "cpu/rm86.cal"
end

version x86_64
	include "cpu/x86_64.cal"
end

version RM86 version DOS
	include "os/rm86_dos.cal"
end end

version x86_64
	version Linux
		include "os/x86_64_linux.cal"
	end

	version OSX
		include "os/x86_64_osx.cal"
	end
end
```

## `asm` blocks

The Callisto compiler generates assembly code from Callisto code, but in order to implement lower level functions it also provides the option to output that assembly directly. This is done with `asm` blocks, which contain strings that are inserted into the output as-is. This behaviour is managed by the general `Compiler` class, without going through backend-specific code, and is often combined with inline functions to reuse chunks of assembly without function calling overhead, which will be seen shortly with the `push` and `pop` operations.

## CPU Cores

The first file included by select.cal for each target is a CPU-specific file, which contains all definitions that are OS-independent (essentially the arithmetic operators and memory access operators). This file typically also includes helpful inline functions for managing the Callisto stack. Most current CPU architectures are register-based, and can't perform calculations directly on a stack that is stored in memory, so functions like these are used to easily move values from the stack to CPU registers and vice versa:

```text
inline __x86_64_pop_rdi begin asm
	"sub r15, 8"
	"mov rdi, [r15]"
end end

inline __x86_64_pop_rsi begin asm
	"sub r15, 8"
	"mov rsi, [r15]"
end end

inline __x86_64_push_rax begin asm
	"mov [r15], rax"
	"add r15, 8"
end end

inline __x86_64_push_rbx begin asm
	"mov [r15], rbx"
	"add r15, 8"
end end
```

On x86_64, Callisto uses 64-bit cells and stores the stack pointer in `r15`, so stack operations involve moving the stack pointer by 8 bytes and loading or storing a value.

With those functions available, the rest of the CPU file is a list of definitions for the [core functions](https://callisto.mesyeti.uk/docs/core/core/), except for those that relate to OS functionality (currently I/O, arguments, and time). Here are some samples:

### Load and store from memory addresses
```text
inline @ begin
	__x86_64_pop_rbx
	asm
		"mov rax, [rbx]"
	end
	__x86_64_push_rax
end

inline ! begin
	__x86_64_pop_rbx
	__x86_64_pop_rax
	asm
		"mov [rbx], rax"
	end
end
```

The typical structure of each core function is: pop some values from the stack into registers, perform the operation using assembly, push the result back to the stack from the output register.

### Simple stack operations
```text
inline dup begin
	__x86_64_pop_rax
	__x86_64_push_rax
	__x86_64_push_rax
end

inline drop begin asm
	"sub r15, 8"
end end
```

`drop` doesn't need to use its argument at all, so it just updates the stack pointer to the previous item.

### Arithmetic
```text
inline + begin
	__x86_64_pop_rbx
	__x86_64_pop_rax
	asm
		"add rax, rbx"
	end
	__x86_64_push_rax
end

inline s+ begin + end
```

Each arithmetic operator comes in signed (`s+`) and unsigned (`+`) versions, but on most CPUs these will be identical, except for division and modulo operators.

### Comparison
```text
func < begin
	__x86_64_pop_rbx
	__x86_64_pop_rax
	asm
		"cmp rax, rbx"
		"jl .push_1"
		"mov qword [r15], 0"
		"add r15, 8"
		"ret"
		".push_1:"
		"mov qword [r15], 0xFFFFFFFFFFFFFFFF"
		"add r15, 8"
	end
end
```

The comparison operators are the most complex CPU core functions, at least on x86_64, simply due to the fact that `cmp` only sets CPU status flags, and we need an actual Boolean value on the stack (true in Callisto, like in Forth, is represented by a value with all bits set, not just 1). Because the assembly has a label inside, it can't be inlined like the other core functions, or we'd end up with duplicate labels. The assembler used by Callisto for x86_64 only allows reusing local labels within different non-local labels. It should in theory be possible to simplify this code to remove all use of conditional jumps, allowing inlining, but I haven't tried this yet.

## OS Cores

The last part of the standard library to look at are the OS specific files. Broken down by both CPU architecture and OS, these contain code to interface with system features, such as accessing files and checking the current time. The functions in these files are placed into `version` blocks to check that the corresponding feature flag is set. The enabled versions are defined by the compiler (at least in b0.9.0, the version of Callisto I'm referencing. This will be changing very soon.)

These files define two things. Firstly, they define the code that should be run at the start and end of the Callisto program. Currently for most OSes, the startup code will save the command line arguments to global variables for later use, and the shutdown code contains a system call to exit the program (no, this is not automatic when you don't have a standard library).

On x86_64 Linux for example, these functions are defined like this:

```text
let addr __linux_argv
let cell __linux_argc

inline __x86_64_program_init begin asm
    "lea rax, [rsp + 16]"
    "mov [__global___us____us__linux__us__argv], rax"
    "mov rax, [rsp + 8]"
    "mov [__global___us____us__linux__us__argc], rax"
end end

inline __x86_64_program_exit begin asm
    "mov rax, 60"
    "mov rdi, 0"
    "syscall"
end end
```

The bizarre name of the global variable in the assembly code here is the result of the `Sanitise` function I mentioned in the previous post, plus a prefix for all global variables.

The rest of the file contains implementations of each system function. These functions range from light wrappers around system calls like these two for reading and writing to files:

```text
func file@ begin
    __x86_64_pop_rdx   # Length
    __x86_64_pop_rsi   # Buffer
    @ __x86_64_pop_rdi # Fd

    asm
        "mov rax, 0" # read
        "syscall"
    end
end

func file! begin
    __x86_64_pop_rdx   # Length
    __x86_64_pop_rsi   # Buffer
    @ __x86_64_pop_rdi # Fd

    asm
        "mov rax, 1" # write
        "syscall"
    end

    __x86_64_push_rax
end
```

To more complex functions like `malloc`, `realloc`, and `free` which provide basic memory allocation functionality using the Linux `mmap`, `mremap`, and `munmap` system calls respectively. I won't go through the design of every function here, but you can check out the [complete os/ directory](https://github.com/callisto-lang/std/tree/main/cores/os) if you're curious.

# Wrapping Up

Between this post and the previous one, I believe I've covered most of how Callisto is implemented, so next time I'll move on to explaining what I did to support ARM64 processors in Callisto, and where I ran into trouble with that. By now, hopefully you have a general idea of what this would take:

- A new backend in the Callisto compiler,
- A CPU core file in the standard library,
- An OS core file, with at least I/O and a way to exit the program.

Hope you enjoyed, see you in the next one!
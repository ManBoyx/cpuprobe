**Français** · [English](#english)

# cpuprobe

Sonde CPU écrite en **assembleur x86-64 pur, sans libc** : tout passe par `cpuid` et les appels système Linux directs (`write`, `exit`). Elle affiche le vendeur du processeur, ses fonctionnalités et lance un petit banc d'essai (`BENCH_ITERS`, 100 millions d'itérations).

## Compiler et lancer
```bash
as --64 cpuprobe.s -o cpuprobe.o && ld cpuprobe.o -o cpuprobe && ./cpuprobe
```
Nécessite `as` et `ld` (binutils) sur Linux x86-64.

## Licence
[MIT](LICENSE).

---

# English

# cpuprobe

A CPU probe written in **pure x86-64 assembly, with no libc**: everything goes through `cpuid` and direct Linux system calls (`write`, `exit`). It prints the processor vendor and features and runs a small benchmark (`BENCH_ITERS`, 100 million iterations).

## Build and run
```bash
as --64 cpuprobe.s -o cpuprobe.o && ld cpuprobe.o -o cpuprobe && ./cpuprobe
```
Requires `as` and `ld` (binutils) on Linux x86-64.

## License
[MIT](LICENSE).

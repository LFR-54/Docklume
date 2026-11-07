# Reads a file in 4 MiB steps and prints the time of each, to see stalls.
import sys, time
start = time.time()
with open(sys.argv[1], "rb", buffering=0) as f:
    total = 0
    while True:
        chunk = f.read(4 << 20)
        if not chunk:
            break
        total += len(chunk)
        print(f"{time.time() - start:6.1f} s  {total >> 20:4d} Mo", flush=True)
print(f"{time.time() - start:6.1f} s  terminé", flush=True)

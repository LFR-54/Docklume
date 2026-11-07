# A relay between rclone and a local server. Once the flag file exists, the connections opened before it stop
# carrying anything, as connections a router lost in an outage; new ones work.
import asyncio, os, sys, time
listen, target, flag = int(sys.argv[1]), int(sys.argv[2]), sys.argv[3]

def cut_since():
    try:
        return os.stat(flag).st_mtime
    except FileNotFoundError:
        return None

async def pipe(reader, writer, opened):
    try:
        while True:
            data = await reader.read(65536)
            if not data:
                break
            since = cut_since()
            if since is not None and opened < since:
                continue  # swallowed: the far end never hears of it
            writer.write(data)
            await writer.drain()
    except Exception:
        pass
    finally:
        try:
            writer.close()
        except Exception:
            pass

async def handle(client_reader, client_writer):
    opened = time.time()
    server_reader, server_writer = await asyncio.open_connection("127.0.0.1", target)
    await asyncio.gather(pipe(client_reader, server_writer, opened), pipe(server_reader, client_writer, opened))

async def main():
    server = await asyncio.start_server(handle, "127.0.0.1", listen)
    async with server:
        await server.serve_forever()

asyncio.run(main())

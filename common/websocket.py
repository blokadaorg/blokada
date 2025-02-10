#!/usr/bin/env python
import asyncio
import websockets
import socket

def get_lan_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        # doesn't even have to be reachable
        s.connect(('8.8.8.8', 1))
        IP = s.getsockname()[0]
    except Exception:
        IP = '127.0.0.1'
    finally:
        s.close()
    return IP

async def echo(websocket, path):
    while True:
        command = input("$ ")
        await websocket.send(command)

async def main():
    ip = get_lan_ip()
    print(f"Starting server on {ip}:8765")
    async with websockets.serve(echo, ip, 8765):
        await asyncio.Future()  # run forever

asyncio.run(main())

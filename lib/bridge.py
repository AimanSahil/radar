import serial
import asyncio
import websockets

# 🔌 CHANGE THIS PORT (very important)
arduino = serial.Serial('/dev/tty.usbmodem141011', 9600)

clients = set()

async def handler(websocket):
    clients.add(websocket)
    try:
        while True:
            data = arduino.readline().decode(errors='ignore').strip()
            if data:
                await asyncio.gather(*[c.send(data) for c in clients])
    finally:
        clients.remove(websocket)

async def main():
    async with websockets.serve(handler, "localhost", 8765):
        print("WebSocket running on ws://localhost:8765")
        await asyncio.Future()

asyncio.run(main())
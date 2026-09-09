"""Use the installed MCP server through its real stdio protocol, including in this setup session."""
import asyncio, json, os, sys
from pathlib import Path
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

async def main():
    env = dict(os.environ, DISABLE_TELEMETRY='true', BLENDER_HOST='127.0.0.1')
    command = str(Path.home()/'.local/bin/blender-mcp.exe')
    async with stdio_client(StdioServerParameters(command=command, env=env)) as (reader, writer):
        async with ClientSession(reader, writer) as session:
            await session.initialize()
            if len(sys.argv) == 1:
                result = await session.list_tools()
                print(json.dumps([dict(name=t.name, schema=t.inputSchema) for t in result.tools],ensure_ascii=False))
            else:
                args = json.loads(Path(sys.argv[2]).read_text(encoding='utf-8')) if len(sys.argv)>2 else {}
                result = await session.call_tool(sys.argv[1], args)
                print(result.model_dump_json())
asyncio.run(main())

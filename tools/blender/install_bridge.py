import bpy
from pathlib import Path

addon = Path.home()/'.local/share/blender-tools/addon.py'
bpy.ops.preferences.addon_install(filepath=str(addon))
bpy.ops.preferences.addon_enable(module='addon')
prefs = bpy.context.preferences.addons['addon'].preferences
prefs.telemetry_consent = False
bpy.context.scene.blendermcp_auto_start_server = True
bpy.ops.wm.save_userpref()
print('BLENDER_MCP_INSTALLED_LOCALHOST_9876')

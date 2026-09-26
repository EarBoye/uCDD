# SPDX-FileCopyrightText: 2026 vorvek
# SPDX-License-Identifier: GPL-3.0-only

"""Render the chrome UCDDPLAY logo with Blender.

blender -b --factory-startup -P logo.py -- <output.png>

The text uses the built-in Blender font. The background is transparent.
"""

import math
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index('--') + 1:]
OUT = argv[0]
WIDTH, HEIGHT = 1600, 400

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 96
scene.cycles.device = 'CPU'
scene.cycles.seed = 1
scene.render.resolution_x = WIDTH
scene.render.resolution_y = HEIGHT
scene.render.film_transparent = True
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.view_settings.view_transform = 'Standard'


def color_ramp(ramp, stops):
    elements = ramp.color_ramp.elements
    elements[0].position, elements[0].color = stops[0][0], (*stops[0][1], 1)
    elements[1].position, elements[1].color = stops[-1][0], (*stops[-1][1], 1)
    for position, color in stops[1:-1]:
        elements.new(position).color = (*color, 1)


curve = bpy.data.curves.new('logo', 'FONT')
curve.body = 'μCDD PLAY'
curve.align_x = 'CENTER'
curve.align_y = 'CENTER'
curve.extrude = 0.10
curve.bevel_depth = 0.035
curve.bevel_resolution = 4
curve.shear = 0.18
curve.space_character = 1.04
text = bpy.data.objects.new('logo', curve)
scene.collection.objects.link(text)
text.rotation_euler = (math.radians(80), 0, 0)

# Chrome: a sky and ground gradient in the base color of a mirror metal.
material = bpy.data.materials.new('chrome')
material.use_nodes = True
nodes = material.node_tree.nodes
links = material.node_tree.links
bsdf = nodes['Principled BSDF']
bsdf.inputs['Metallic'].default_value = 1.0
bsdf.inputs['Roughness'].default_value = 0.10
coord = nodes.new('ShaderNodeTexCoord')
sep = nodes.new('ShaderNodeSeparateXYZ')
ramp = nodes.new('ShaderNodeValToRGB')
links.new(coord.outputs['Generated'], sep.inputs['Vector'])
links.new(sep.outputs['Y'], ramp.inputs['Fac'])
links.new(ramp.outputs['Color'], bsdf.inputs['Base Color'])
color_ramp(ramp, [(0.00, (1.00, 0.88, 0.40)), (0.18, (0.95, 0.52, 0.10)), (0.46, (0.16, 0.06, 0.02)),
                  (0.49, (1.00, 1.00, 1.00)), (0.53, (0.80, 0.93, 1.00)), (0.78, (0.18, 0.38, 1.00)),
                  (1.00, (0.80, 0.92, 1.00))])
text.data.materials.append(material)

world = bpy.data.worlds.new('env')
scene.world = world
world.use_nodes = True
nodes = world.node_tree.nodes
links = world.node_tree.links
nodes.clear()
coord = nodes.new('ShaderNodeTexCoord')
sep = nodes.new('ShaderNodeSeparateXYZ')
map_range = nodes.new('ShaderNodeMapRange')
map_range.inputs['From Min'].default_value = -1.0
map_range.inputs['From Max'].default_value = 1.0
ramp = nodes.new('ShaderNodeValToRGB')
background = nodes.new('ShaderNodeBackground')
background.inputs['Strength'].default_value = 1.2
output = nodes.new('ShaderNodeOutputWorld')
links.new(coord.outputs['Generated'], sep.inputs['Vector'])
links.new(sep.outputs['Z'], map_range.inputs['Value'])
links.new(map_range.outputs['Result'], ramp.inputs['Fac'])
links.new(ramp.outputs['Color'], background.inputs['Color'])
links.new(background.outputs['Background'], output.inputs['Surface'])
color_ramp(ramp, [(0.00, (0.05, 0.02, 0.00)), (0.30, (0.30, 0.12, 0.02)), (0.46, (0.95, 0.55, 0.15)),
                  (0.50, (1.00, 1.00, 1.00)), (0.54, (0.55, 0.75, 1.00)), (0.75, (0.10, 0.25, 0.75)),
                  (1.00, (0.02, 0.03, 0.20))])

camera_data = bpy.data.cameras.new('camera')
camera_data.type = 'ORTHO'
camera = bpy.data.objects.new('camera', camera_data)
scene.collection.objects.link(camera)
camera.rotation_euler = (math.radians(90), 0, 0)
scene.camera = camera

bpy.context.view_layer.update()
evaluated = text.evaluated_get(bpy.context.evaluated_depsgraph_get())
corners = [evaluated.matrix_world @ Vector(c) for c in evaluated.bound_box]
xs = [c.x for c in corners]
zs = [c.z for c in corners]
camera_data.ortho_scale = max((max(xs) - min(xs)) * 1.15, (max(zs) - min(zs)) * 1.6 * WIDTH / HEIGHT)
camera.location = ((max(xs) + min(xs)) / 2, -10, (max(zs) + min(zs)) / 2)

scene.render.filepath = OUT
bpy.ops.render.render(write_still=True)

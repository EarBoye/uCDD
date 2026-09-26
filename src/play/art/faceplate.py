# SPDX-FileCopyrightText: 2026 vorvek
# SPDX-License-Identifier: GPL-3.0-only

"""Render the UCDDPLAY faceplate with Blender.

blender -b --factory-startup -P faceplate.py -- <output.png> [samples]

Coordinates are VGA pixels of the 320x200 screen. The render is 1280x960
(4:3), so one VGA pixel is 1.2 units high.
"""

import math
import sys

import bpy

argv = sys.argv[sys.argv.index('--') + 1:]
OUT = argv[0]
SAMPLES = int(argv[1]) if len(argv) > 1 else 96
SCALE_Y = 1.2

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = SAMPLES
scene.cycles.device = 'CPU'
scene.cycles.use_denoising = True
scene.cycles.seed = 1
scene.render.resolution_x = 1280
scene.render.resolution_y = 960
scene.render.image_settings.file_format = 'PNG'
scene.view_settings.view_transform = 'Standard'


def P(x, y, z=0.0):
    return (x, 240.0 - y * SCALE_Y, z)


def material(name, color, metallic, roughness, emission=None, strength=0.0, coat=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*color, 1)
    b.inputs['Metallic'].default_value = metallic
    b.inputs['Roughness'].default_value = roughness
    if coat:
        b.inputs['Coat Weight'].default_value = coat
    if emission:
        b.inputs['Emission Color'].default_value = (*emission, 1)
        b.inputs['Emission Strength'].default_value = strength
    return m


def stripes(m, scale, strength, angle):
    """Engine-turned bands in the surface normal."""
    nodes = m.node_tree.nodes
    links = m.node_tree.links
    coord = nodes.new('ShaderNodeTexCoord')
    mapping = nodes.new('ShaderNodeMapping')
    mapping.inputs['Rotation'].default_value = (0, 0, math.radians(angle))
    wave = nodes.new('ShaderNodeTexWave')
    wave.wave_type = 'BANDS'
    wave.bands_direction = 'X'
    wave.wave_profile = 'SAW'
    wave.inputs['Scale'].default_value = scale
    bump = nodes.new('ShaderNodeBump')
    bump.inputs['Strength'].default_value = strength
    links.new(coord.outputs['Object'], mapping.inputs['Vector'])
    links.new(mapping.outputs['Vector'], wave.inputs['Vector'])
    links.new(wave.outputs['Fac'], bump.inputs['Height'])
    links.new(bump.outputs['Normal'], nodes['Principled BSDF'].inputs['Normal'])


PLATE = material('plate', (0.012, 0.016, 0.20), 0.05, 0.5)
PLATE.node_tree.nodes['Principled BSDF'].inputs['Specular IOR Level'].default_value = 0.15
stripes(PLATE, 0.11, 0.9, 38)
VELVET = material('velvet', (0.20, 0.008, 0.035), 0.05, 0.55)
PLATE_DARK = material('plate_dark', (0.03, 0.035, 0.12), 0.05, 0.45)
CHROME = material('chrome', (0.95, 0.96, 1.0), 1.0, 0.07)
GOLD = material('gold', (1.0, 0.72, 0.28), 1.0, 0.16)
GLASS = material('glass', (0.0, 0.01, 0.03), 0.0, 0.8)
LCD = material('lcd', (0.0, 0.05, 0.06), 0.0, 0.7, emission=(0.0, 0.10, 0.12), strength=0.30)
BLACK = material('black', (0.005, 0.005, 0.01), 0.0, 0.6)
IVORY = material('ivory', (0.93, 0.85, 0.62), 0.0, 0.45, emission=(1.0, 0.85, 0.55), strength=0.18)
BUTTON = material('button', (0.80, 0.84, 0.95), 1.0, 0.12)
RUBY = material('ruby', (0.8, 0.02, 0.05), 0.0, 0.05, emission=(0.4, 0.0, 0.02), strength=0.6, coat=1.0)


def link(obj, mat):
    obj.data.materials.append(mat)
    return obj


def box(x0, y0, x1, y1, z0, z1, mat):
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    o = bpy.context.object
    o.location = ((x0 + x1 + 1) / 2, 240.0 - (y0 + y1 + 1) / 2 * SCALE_Y, (z0 + z1) / 2)
    o.scale = (x1 - x0 + 1, (y1 - y0 + 1) * SCALE_Y, z1 - z0)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return link(o, mat)


def sphere(x, y, z, sx, sy, sz, mat, segments=16, rotation=0.0):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1.0, segments=segments, ring_count=max(4, segments // 2))
    o = bpy.context.object
    o.location = P(x, y, z)
    o.rotation_euler = (0, 0, rotation)
    o.scale = (sx, sy, sz)
    bpy.ops.object.shade_smooth()
    return link(o, mat)


def path(points, radius, mat, cyclic=False, z=1.0, resolution=4):
    c = bpy.data.curves.new('path', 'CURVE')
    c.dimensions = '3D'
    c.bevel_depth = radius
    c.bevel_resolution = resolution
    c.fill_mode = 'FULL'
    s = c.splines.new('POLY')
    s.points.add(len(points) - 1)
    for i, (x, y) in enumerate(points):
        s.points[i].co = (*P(x, y, z), 1.0)
    s.use_cyclic_u = cyclic
    o = bpy.data.objects.new('path', c)
    scene.collection.objects.link(o)
    return link(o, mat)


def ellipse(cx, cy, r, count):
    return [(cx + r * math.cos(a / count * 2 * math.pi), cy + r / SCALE_Y * math.sin(a / count * 2 * math.pi))
            for a in range(count)]


def rounded_rect(x0, y0, x1, y1, r, steps=4):
    pts = []
    for cx, cy, a0 in ((x1 - r, y0 + r, -90), (x1 - r, y1 - r, 0), (x0 + r, y1 - r, 90), (x0 + r, y0 + r, 180)):
        for i in range(steps + 1):
            a = math.radians(a0 + 90 * i / steps)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def molding(x0, y0, x1, y1, radius, mat, z=1.0, r=3.0):
    return path(rounded_rect(x0, y0, x1, y1, r), radius, mat, cyclic=True, z=z + radius * 1.5)


def jewel(x, y, r, mat):
    sphere(x, y, 0.6, r, r, r * 0.7, mat, segments=24)
    path(ellipse(x, y, r * 1.25, 16), 0.45, GOLD, cyclic=True, z=0.6)


def volute(cx, cy, size, flip_x=1, flip_y=1, turns=1.6, tail=(1.0, 0.0), tail_len=1.0, radius=0.7):
    """A gold C-scroll: a log spiral with a curved tail."""
    pts = []
    theta_max = turns * 2 * math.pi
    for i in range(41):
        theta = theta_max * (1 - i / 40)
        r = size * 0.84 * math.exp(0.22 * (theta - theta_max))
        pts.append((cx + flip_x * r * math.cos(theta), cy + flip_y * r * math.sin(theta) / SCALE_Y))
    ex, ey = pts[-1]
    for i in range(1, 7):
        t = i / 6
        pts.append((ex + flip_x * tail[0] * size * tail_len * t,
                    ey + flip_y * (tail[1] * size * tail_len * t + math.sin(t * math.pi) * size * 0.25) / SCALE_Y))
    return path(pts, radius, GOLD, z=1.2, resolution=3)


def shell(cx, cy, size, a0, a1, petals=6):
    """A gold fan of petals between two screen angles in degrees."""
    for i in range(petals):
        a = math.radians(a0 + (a1 - a0) * (i + 0.5) / petals)
        d = size * 0.55
        sphere(cx + d * math.cos(a), cy + d * math.sin(a), 0.8, size * 0.55, size * 0.16, size * 0.12, GOLD,
               rotation=-a)
    sphere(cx, cy, 1.2, size * 0.2, size * 0.2, size * 0.14, GOLD)


def rosette(cx, cy, r=2.0):
    for i in range(5):
        a = i / 5 * 2 * math.pi
        sphere(cx + r * 0.55 * math.cos(a), cy + r * 0.55 / SCALE_Y * math.sin(a), 0.7, r * 0.5, r * 0.5, r * 0.3,
               GOLD, segments=12)
    sphere(cx, cy, 1.0, r * 0.38, r * 0.38, r * 0.3, RUBY, segments=12)


box(0, 0, 319, 199, -1.0, 0.0, PLATE)

# Outer frame and corner shells.
molding(1, 1, 318, 198, 1.2, GOLD, z=0.8, r=6)
molding(3.6, 3.6, 315.4, 195.4, 0.45, CHROME, z=0.6, r=4)
shell(4, 4, 14, 0, 90, petals=7)
shell(315, 4, 14, 90, 180, petals=7)
shell(4, 195, 14, -90, 0, petals=7)
shell(315, 195, 14, 180, 270, petals=7)

# Logo window with a crest and C-scrolls.
LOGO = (67, 5, 252, 38)
box(LOGO[0], LOGO[1], LOGO[2], LOGO[3], -0.6, 0.05, BLACK)
molding(LOGO[0] - 1.6, LOGO[1] - 1.3, LOGO[2] + 1.6, LOGO[3] + 1.3, 1.0, GOLD, z=0.6, r=4)
molding(LOGO[0] - 0.3, LOGO[1] - 0.2, LOGO[2] + 0.3, LOGO[3] + 0.2, 0.35, CHROME, z=0.3, r=3)
for sx in (-1, 1):
    x = 159.5 + sx * 101
    volute(x, 13, 7.5, flip_x=sx, flip_y=1, turns=1.25, tail=(-0.2, 1.0), tail_len=1.6, radius=0.85)
    volute(x, 30, 7.5, flip_x=sx, flip_y=-1, turns=1.25, tail=(-0.2, 1.0), tail_len=1.6, radius=0.85)
    rosette(x - sx, 21.5, 2.2)
shell(159.5, 5.2, 9, 20, 160, petals=9)
rosette(159.5, 5.0, 2.4)
shell(159.5, 38.8, 7, 200, 340, petals=7)
for sx in (-1, 1):
    volute(159.5 + sx * 9, 4.2, 5.0, flip_x=sx, flip_y=1, turns=1.1, tail=(1.0, -0.1), tail_len=4.0, radius=0.55)

# VU meters.
for (x0, x1) in ((11, 51), (268, 308)):
    box(x0, 7, x1, 36, -0.4, 0.1, IVORY)
    molding(x0 - 1.3, 6, x1 + 1.3, 37, 0.9, GOLD, z=0.6, r=3)
    molding(x0 - 0.2, 6.9, x1 + 0.2, 36.1, 0.3, CHROME, z=0.3, r=2.5)

# LCD and analyzer windows, and the column between them.
for (x0, y0, x1, y1, mat) in ((10, 46, 159, 98, LCD), (168, 46, 309, 98, GLASS)):
    box(x0, y0, x1, y1, -0.8, 0.05, mat)
    molding(x0 - 1.6, y0 - 1.4, x1 + 1.6, y1 + 1.4, 1.05, CHROME, z=0.7, r=3)
    molding(x0 - 3.2, y0 - 2.8, x1 + 3.2, y1 + 2.8, 0.45, GOLD, z=0.4, r=4)
    for (rx, ry) in ((x0 - 2.5, y0 - 2.2), (x1 + 2.5, y0 - 2.2), (x0 - 2.5, y1 + 2.2), (x1 + 2.5, y1 + 2.2)):
        rosette(rx, ry, 1.9)
bpy.ops.mesh.primitive_cylinder_add(radius=1.0, depth=1.0, vertices=24)
column = bpy.context.object
column.rotation_euler = (math.radians(90), 0, 0)
column.location = P(163.5, 72, 0.4)
column.scale = (1.3, 1.3, 44 * SCALE_Y)
bpy.ops.object.shade_smooth()
link(column, GOLD)
for y in (52, 72, 92):
    rosette(163.5, y, 2.1)

# Equalizer section with the volume knob.
box(7, 105, 312, 148, -0.2, 0.02, VELVET)
molding(6, 104, 313, 149, 0.6, GOLD, z=0.5, r=5)
box(9, 107, 58, 146, -0.3, 0.05, PLATE_DARK)
molding(9, 107, 58, 146, 0.45, CHROME, z=0.3, r=3)
sphere(33.5, 119, 0.5, 9.5, 9.5 * SCALE_Y, 3.2, CHROME, segments=48)
for a in range(36):
    ang = a / 36 * 2 * math.pi
    sphere(33.5 + 11.2 * math.cos(ang), 119 + 11.2 / SCALE_Y * math.sin(ang), 0.5, 0.9, 0.9, 0.8, GOLD,
           segments=10)
sphere(33.5, 119, 3.0, 3.2, 3.2 * SCALE_Y, 1.2, GOLD, segments=32)
jewel(16, 141, 2.1, RUBY)
for sx, x in ((1, 61.5), (-1, 310.5)):
    volute(x, 111, 5.5, flip_x=sx, flip_y=1, turns=1.2, tail=(0.0, 1.0), tail_len=2.6, radius=0.55)
    volute(x, 142, 5.5, flip_x=sx, flip_y=-1, turns=1.2, tail=(0.0, 1.0), tail_len=2.6, radius=0.55)
for i in range(11):
    cx = 70 + 23 * i
    box(cx - 1.5, 109, cx + 1.5, 135, -0.8, 0.05, BLACK)
    molding(cx - 2.7, 108, cx + 2.7, 136, 0.4, CHROME, z=0.2, r=1.5)

# Capsule buttons with gold end caps.
BUTTONS = [(7, 26), (37, 30), (71, 26), (101, 26), (131, 40), (175, 46), (225, 40), (269, 44)]
for (x, w) in BUTTONS:
    box(x - 2, 151, x + w + 1, 167, -0.3, 0.05, BLACK)
    bpy.ops.mesh.primitive_cylinder_add(radius=1.0, depth=1.0, vertices=48)
    b = bpy.context.object
    b.rotation_euler = (0, math.radians(90), 0)
    b.location = P(x + w / 2, 159.5, 0.0)
    b.scale = (2.4, 15 * SCALE_Y / 2, w)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bevel = b.modifiers.new('bevel', 'BEVEL')
    bevel.width = 1.2
    bevel.segments = 3
    bevel.limit_method = 'ANGLE'
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(50))
    link(b, BUTTON)
    for ex in (x + 1.2, x + w - 2.2):
        bpy.ops.mesh.primitive_cylinder_add(radius=1.0, depth=1.0, vertices=48)
        e = bpy.context.object
        e.rotation_euler = (0, math.radians(90), 0)
        e.location = P(ex + 0.5, 159.5, 0.2)
        e.scale = (2.8, 15.6 * SCALE_Y / 2, 2.2)
        bpy.ops.object.shade_smooth()
        link(e, GOLD)
    molding(x - 1.2, 151.2, x + w + 0.2, 166.8, 0.4, GOLD, z=0.3, r=2)

# Scroller window.
box(11, 171, 308, 193, -0.8, 0.05, BLACK)
molding(9.4, 169.6, 309.6, 194.4, 1.05, GOLD, z=0.7, r=4)
molding(10.6, 170.6, 308.4, 193.4, 0.35, CHROME, z=0.3, r=3)

# A horizon environment: chrome shows sky and ground bands.
world = bpy.data.worlds.new('env')
scene.world = world
world.use_nodes = True
nodes = world.node_tree.nodes
links = world.node_tree.links
nodes.clear()
coord = nodes.new('ShaderNodeTexCoord')
sep = nodes.new('ShaderNodeSeparateXYZ')
ramp = nodes.new('ShaderNodeValToRGB')
background = nodes.new('ShaderNodeBackground')
output = nodes.new('ShaderNodeOutputWorld')
map_range = nodes.new('ShaderNodeMapRange')
map_range.inputs['From Min'].default_value = -1.0
map_range.inputs['From Max'].default_value = 1.0
links.new(coord.outputs['Generated'], sep.inputs['Vector'])
links.new(sep.outputs['Y'], map_range.inputs['Value'])
links.new(map_range.outputs['Result'], ramp.inputs['Fac'])
links.new(ramp.outputs['Color'], background.inputs['Color'])
links.new(background.outputs['Background'], output.inputs['Surface'])
stops = [(0.0, (0.03, 0.03, 0.03)), (0.30, (0.22, 0.20, 0.18)), (0.47, (0.85, 0.83, 0.80)),
         (0.50, (1.0, 1.0, 1.0)), (0.53, (0.55, 0.60, 0.70)), (0.72, (0.12, 0.13, 0.16)), (1.0, (0.03, 0.03, 0.04))]
elements = ramp.color_ramp.elements
elements[0].position, elements[0].color = stops[0][0], (*stops[0][1], 1)
elements[1].position, elements[1].color = stops[-1][0], (*stops[-1][1], 1)
for position, color in stops[1:-1]:
    elements.new(position).color = (*color, 1)

sun = bpy.data.lights.new('sun', 'SUN')
sun.energy = 3.2
sun.angle = math.radians(8)
sun_object = bpy.data.objects.new('sun', sun)
scene.collection.objects.link(sun_object)
sun_object.rotation_euler = (math.radians(52), math.radians(-30), math.radians(15))

camera_data = bpy.data.cameras.new('camera')
camera_data.type = 'ORTHO'
camera_data.ortho_scale = 320
camera = bpy.data.objects.new('camera', camera_data)
scene.collection.objects.link(camera)
camera.location = (160, 120, 100)
scene.camera = camera

scene.render.filepath = OUT
bpy.ops.render.render(write_still=True)

# Modelli 3D di StarForce «Reborn» costruiti con Blender (bpy), esportati in glTF binario.
# Navi lunghe circa 1 unità con la prua verso +Y (in Godot diventa -Z); materiale «colore_lato»
# che il gioco tinge con il colore della fazione.
import bpy, bmesh, math, os, sys
from mathutils import Vector

OUT = sys.argv[-1] if len(sys.argv) > 1 and sys.argv[-1].endswith("/") else "/home/claude/starforce/assets/models/"
os.makedirs(OUT, exist_ok=True)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name, col, metal=0.7, rough=0.35, emit=None, strength=4.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*col, 1)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    if emit is not None:
        b.inputs["Emission Color"].default_value = (*emit, 1)
        b.inputs["Emission Strength"].default_value = strength
    return m


def setmat(o, m):
    o.data.materials.clear()
    o.data.materials.append(m)
    return o


def bevel(o, w=0.01, seg=2):
    md = o.modifiers.new("smusso", "BEVEL")
    md.width = w
    md.segments = seg
    md.limit_method = "ANGLE"
    return o


def smooth(o, levels=1):
    md = o.modifiers.new("liscio", "SUBSURF")
    md.levels = levels
    md.render_levels = levels
    bpy.context.view_layer.objects.active = o
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def cyl(r1, r2, h, loc, rot=(0, 0, 0), v=12):
    bpy.ops.mesh.primitive_cone_add(vertices=v, radius1=r1, radius2=r2, depth=h, location=loc, rotation=rot)
    return bpy.context.active_object


def box(size, loc, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    return o


def torus(R, r, loc, rot=(0, 0, 0), maj=32, mn=8):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=maj, minor_segments=mn, location=loc, rotation=rot)
    return bpy.context.active_object


def sphere(r, loc, scale=(1, 1, 1), seg=16, rings=8):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=loc, segments=seg, ring_count=rings)
    o = bpy.context.active_object
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return o


def ico(r, loc, scale=(1, 1, 1), sub=1):
    bpy.ops.mesh.primitive_ico_sphere_add(radius=r, location=loc, subdivisions=sub)
    o = bpy.context.active_object
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return o


def join(objs, name):
    for o in bpy.context.selected_objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    for o in objs:
        bpy.context.view_layer.objects.active = o
        for md in list(o.modifiers):
            bpy.ops.object.modifier_apply(modifier=md.name)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = name
    tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
    goal = 4500 if name == "porta" else 1700
    if tris > goal:
        md = o.modifiers.new("riduci", "DECIMATE")
        md.ratio = goal / tris
        bpy.ops.object.modifier_apply(modifier=md.name)
    return o


def export(name):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=OUT + name + ".glb", export_format="GLB", use_selection=True,
                              export_apply=True, export_yup=True)
    print("esportato", name)


X90 = (math.pi / 2, 0, 0)

# ---------------------------------------------------------------- Umani
def nave_umani(name="nave_umani", hull=(0.78, 0.8, 0.84), ring2=False):
    reset()
    H = mat("scafo", hull, 0.75, 0.32)
    D = mat("scuro", (0.18, 0.19, 0.22), 0.6, 0.5)
    C = mat("colore_lato", (0.2, 0.6, 1.0), 0.3, 0.4, emit=(0.2, 0.6, 1.0), strength=1.2)
    G = mat("motore", (0.6, 0.9, 1.0), 0.0, 1.0, emit=(0.55, 0.85, 1.0), strength=8.0)
    parts = []
    # spina dorsale
    parts.append(setmat(bevel(cyl(0.035, 0.035, 0.9, (0, 0, 0), X90, 10), 0.004), D))
    # modulo di comando esagonale a prua (come la nave della copertina)
    cm = setmat(bevel(cyl(0.11, 0.08, 0.16, (0, 0.46, 0), X90, 6), 0.012), H)
    parts.append(cm)
    parts.append(setmat(cyl(0.08, 0.0, 0.08, (0, 0.58, 0), X90, 6), H))
    parts.append(setmat(box((0.24, 0.05, 0.04), (0, 0.44, 0.07)), D))
    # anello abitativo con raggi
    ring = setmat(bevel(torus(0.26, 0.03, (0, 0.22, 0), X90, 40, 8), 0.003), H)
    parts.append(ring)
    parts.append(setmat(torus(0.265, 0.012, (0, 0.22, 0), X90, 40, 6), C))
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        parts.append(setmat(cyl(0.01, 0.01, 0.5, (0, 0.22, 0), (0, a, 0) if False else (math.pi / 2, 0, 0), 6), D))
    sp1 = setmat(box((0.52, 0.02, 0.02), (0, 0.22, 0)), D)
    sp2 = setmat(box((0.02, 0.02, 0.52), (0, 0.22, 0)), D)
    parts += [sp1, sp2]
    if ring2:
        parts.append(setmat(bevel(torus(0.2, 0.025, (0, -0.05, 0), X90, 36, 8), 0.003), H))
    # serbatoi gemelli lungo la spina (le capsule della copertina)
    for sx in (-1, 1):
        for y in (0.02, -0.16):
            parts.append(setmat(smooth(sphere(0.055, (sx * 0.075, y, 0), (1, 1.6, 1), 12, 8)), H))
    # sezione motori
    parts.append(setmat(bevel(box((0.2, 0.14, 0.12), (0, -0.36, 0)), 0.015), H))
    for sx in (-1, 1):
        parts.append(setmat(cyl(0.045, 0.06, 0.1, (sx * 0.06, -0.47, 0), X90, 10), D))
        parts.append(setmat(cyl(0.04, 0.04, 0.02, (sx * 0.06, -0.525, 0), X90, 10), G))
    parts.append(setmat(box((0.36, 0.02, 0.012), (0, -0.33, 0.065)), C))
    o = join(parts, name)
    export(name)


# ---------------------------------------------------------------- L'Chal-Dah
def nave_lcd():
    reset()
    H = mat("scafo", (0.85, 0.66, 0.3), 0.9, 0.25)
    C = mat("colore_lato", (0.9, 0.7, 0.2), 0.4, 0.35, emit=(0.9, 0.7, 0.2), strength=1.0)
    G = mat("motore", (0.6, 1.0, 0.8), 0.0, 1.0, emit=(0.5, 1.0, 0.75), strength=7.0)
    parts = []
    body = smooth(sphere(0.16, (0, 0.05, 0), (0.85, 3.0, 0.6), 20, 12), 2)
    parts.append(setmat(body, H))
    # pinne curve
    for k, ang in enumerate((0, 2.1, -2.1)):
        f = box((0.02, 0.28, 0.22), (0, -0.18, 0))
        f.rotation_euler = (0, ang, 0)
        bpy.ops.object.transform_apply(rotation=True)
        f.location = (math.sin(ang) * 0.1, -0.2, math.cos(ang) * 0.1)
        bpy.ops.object.transform_apply(location=True)
        bm = bmesh.new()
        bm.from_mesh(f.data)
        for v in bm.verts:
            if v.co.y < -0.25:
                v.co.y -= 0.12
                v.co.x *= 1.6
                v.co.z *= 1.6
        bm.to_mesh(f.data)
        bm.free()
        parts.append(setmat(smooth(f, 1), C))
    parts.append(setmat(smooth(sphere(0.05, (0, 0.5, 0.03), (1, 1.4, 0.7), 12, 8)), G))
    parts.append(setmat(smooth(sphere(0.06, (0, -0.42, 0), (1, 0.6, 1), 12, 8)), G))
    for sx in (-1, 1):
        parts.append(setmat(smooth(sphere(0.04, (sx * 0.13, 0.1, -0.02), (0.7, 2.2, 0.7), 10, 6)), H))
    join(parts, "nave_lcd")
    export("nave_lcd")


# ---------------------------------------------------------------- Rame
def nave_rame():
    reset()
    H = mat("scafo", (0.25, 0.75, 0.45), 0.2, 0.15, emit=(0.15, 0.6, 0.35), strength=0.8)
    C = mat("colore_lato", (0.4, 0.9, 0.5), 0.2, 0.2, emit=(0.4, 0.9, 0.5), strength=1.5)
    G = mat("motore", (0.7, 1.0, 0.9), 0.0, 1.0, emit=(0.6, 1.0, 0.8), strength=8.0)
    parts = []
    # cristallo centrale: bipiramide esagonale allungata
    bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.12, radius2=0, depth=0.55, location=(0, 0.27, 0), rotation=(-math.pi / 2, 0, 0))
    parts.append(setmat(bpy.context.active_object, H))
    bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.12, radius2=0, depth=0.4, location=(0, -0.2, 0), rotation=(math.pi / 2, 0, 0))
    parts.append(setmat(bpy.context.active_object, H))
    # cristalli satelliti
    for k in range(5):
        a = k * 2 * math.pi / 5
        bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.045, radius2=0, depth=0.32, location=(math.cos(a) * 0.12, -0.02 + 0.05 * (k % 2), math.sin(a) * 0.12), rotation=(-math.pi / 2 + 0.35 * math.sin(a), 0.4 * math.cos(a), 0))
        parts.append(setmat(bpy.context.active_object, C if k % 2 else H))
    parts.append(setmat(ico(0.06, (0, -0.02, 0), (1, 1, 1), 1), G))
    join(parts, "nave_rame")
    export("nave_rame")


# ---------------------------------------------------------------- Xenofobi
def nave_xeno():
    reset()
    H = mat("scafo", (0.12, 0.06, 0.07), 0.8, 0.4)
    C = mat("colore_lato", (0.6, 0.6, 0.6), 0.5, 0.4, emit=(0.6, 0.6, 0.6), strength=0.6)
    G = mat("motore", (1.0, 0.2, 0.1), 0.0, 1.0, emit=(1.0, 0.15, 0.05), strength=9.0)
    parts = []
    # lama a punta di freccia
    bm = bmesh.new()
    pts = [(0, 0.55, 0), (0.32, -0.35, 0), (0.1, -0.22, 0), (0, -0.45, 0), (-0.1, -0.22, 0), (-0.32, -0.35, 0)]
    top = [bm.verts.new((x, y, 0.035)) for x, y, z in pts]
    bot = [bm.verts.new((x, y, -0.035)) for x, y, z in pts]
    bm.faces.new(top)
    bm.faces.new(list(reversed(bot)))
    n = len(pts)
    for i in range(n):
        bm.faces.new([top[i], top[(i + 1) % n], bot[(i + 1) % n], bot[i]])
    me = bpy.data.meshes.new("lama")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("lama", me)
    bpy.context.collection.objects.link(o)
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    parts.append(setmat(bevel(o, 0.01), H))
    # dorso e spine
    parts.append(setmat(box((0.06, 0.6, 0.08), (0, 0.0, 0.05)), H))
    for k in range(4):
        y = 0.25 - k * 0.15
        bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.025, radius2=0, depth=0.14, location=(0, y, 0.15), rotation=(0.5, 0, 0))
        parts.append(setmat(bpy.context.active_object, G if k % 2 == 0 else C))
    parts.append(setmat(smooth(sphere(0.05, (0, 0.05, 0.08), (1, 1.5, 0.8), 10, 6)), G))
    for sx in (-1, 1):
        parts.append(setmat(cyl(0.03, 0.04, 0.08, (sx * 0.12, -0.3, 0), X90, 8), G))
    join(parts, "nave_xeno")
    export("nave_xeno")


# ---------------------------------------------------------------- StarGate
def porta():
    reset()
    H = mat("scafo", (0.75, 0.77, 0.8), 0.8, 0.3)
    D = mat("scuro", (0.2, 0.2, 0.23), 0.6, 0.5)
    C = mat("colore_lato", (0.2, 0.6, 1.0), 0.3, 0.4, emit=(0.2, 0.6, 1.0), strength=1.5)
    L = mat("luci", (0.8, 0.95, 1.0), 0.0, 1.0, emit=(0.75, 0.95, 1.0), strength=6.0)
    parts = []
    # grande anello con sezione squadrata, smussata
    parts.append(setmat(bevel(torus(0.7, 0.06, (0, 0, 0), (0, 0, 0), 64, 6), 0.004), H))
    parts.append(setmat(torus(0.7, 0.025, (0, 0, 0.055), (0, 0, 0), 64, 6), C))
    parts.append(setmat(torus(0.62, 0.012, (0, 0, 0), (0, 0, 0), 64, 6), D))
    # moduli sull'anello
    for k in range(8):
        a = k * math.pi / 4
        m = setmat(bevel(box((0.14, 0.1, 0.12), (math.cos(a) * 0.7, math.sin(a) * 0.7, 0)), 0.01), H)
        m.rotation_euler = (0, 0, a)
        parts.append(m)
        parts.append(setmat(sphere(0.022, (math.cos(a) * 0.78, math.sin(a) * 0.78, 0), (1, 1, 1), 8, 6), L))
    # raggi
    for k in range(3):
        a = k * math.pi / 3
        r = setmat(box((1.38, 0.025, 0.025), (0, 0, 0)), D)
        r.rotation_euler = (0, 0, a)
        parts.append(r)
    # mozzo centrale con antenna e disco
    parts.append(setmat(bevel(cyl(0.13, 0.16, 0.4, (0, 0, 0), (0, 0, 0), 8), 0.01), H))
    parts.append(setmat(bevel(cyl(0.2, 0.2, 0.06, (0, 0, 0.12), (0, 0, 0), 8), 0.008), D))
    parts.append(setmat(smooth(sphere(0.14, (0, 0, 0.27), (1, 1, 0.35), 16, 8)), L))
    parts.append(setmat(cyl(0.01, 0.01, 0.35, (0, 0, -0.35), (0, 0, 0), 6), D))
    parts.append(setmat(sphere(0.03, (0, 0, -0.53), (1, 1, 1), 8, 6), L))
    join(parts, "porta")
    # in Godot l'anello deve stare orizzontale: Blender Z (alto) diventa Y
    export("porta")


nave_umani()
nave_umani("nave_psl", hull=(0.92, 0.94, 0.98), ring2=True)
nave_lcd()
nave_rame()
nave_xeno()
porta()

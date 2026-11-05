import bpy, math, sys
names = ["nave_umani", "nave_psl", "nave_lcd", "nave_rame", "nave_xeno", "porta"]
for n in names:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath="/home/claude/starforce/assets/models/%s.glb" % n)
    tris = sum(len(p.vertices) - 2 for o in bpy.data.objects if o.type == "MESH" for p in o.data.polygons)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    bpy.context.collection.objects.link(cam)
    d = 2.2 if n == "porta" else 1.5
    cam.location = (d * 0.8, -d * 0.6, d * 0.7) if n != "porta" else (d * 0.5, -d * 0.9, d * 0.9)
    tgt = bpy.data.objects.new("t", None)
    bpy.context.collection.objects.link(tgt)
    c = cam.constraints.new("TRACK_TO")
    c.target = tgt
    bpy.context.scene.camera = cam
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.rotation_euler = (0.8, 0.2, 0.6)
    bpy.data.lights["sun"].energy = 4
    bpy.context.collection.objects.link(sun)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 24
    sc.cycles.device = "CPU"
    sc.render.resolution_x = 360
    sc.render.resolution_y = 300
    sc.world = bpy.data.worlds.new("w")
    sc.world.use_nodes = True
    sc.world.node_tree.nodes["Background"].inputs[0].default_value = (0.02, 0.015, 0.03, 1)
    sc.render.filepath = "/tmp/prev_%s.png" % n
    try:
        bpy.ops.render.render(write_still=True)
    except Exception as e:
        sc.render.engine = "BLENDER_WORKBENCH"
        bpy.ops.render.render(write_still=True)
    print("TRIS", n, tris)

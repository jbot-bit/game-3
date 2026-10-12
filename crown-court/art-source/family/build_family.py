"""Editable family identity meshes. Coordinates below use the game's Y-up axes."""
import bpy, math, json
from pathlib import Path
from mathutils import Vector
ROOT=Path('C:/game-3')
OUT=ROOT/'crown-court/assets/characters'
SOURCE=ROOT/'.tools/art-sources/crown-family'
def vec(p): return Vector((p[0],-p[2],p[1]))
def material(name, rgb, metal=0):
    m=bpy.data.materials.new(name); m.diffuse_color=(*rgb,1); m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF'); bs.inputs['Base Color'].default_value=(*rgb,1)
    bs.inputs['Roughness'].default_value=.48; bs.inputs['Metallic'].default_value=metal
    return m
def mesh(name, verts, faces, mat):
    m=bpy.data.meshes.new(name); m.from_pydata([vec(p) for p in verts],[],faces); m.update()
    o=bpy.data.objects.new(name,m); bpy.context.collection.objects.link(o); o.data.materials.append(mat)
    for p in m.polygons:p.use_smooth=True
    return o
def sphere(name,p,s,mat,segments=24,rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,location=vec(p))
    o=bpy.context.object; o.name=name; o.scale=(s[0],s[2],s[1]); o.data.materials.append(mat)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    for f in o.data.polygons:f.use_smooth=True
    return o
def tube(name,points,radii,mat,sides=10):
    verts=[]; faces=[]
    for i,p in enumerate(points):
        tangent=Vector(points[min(i+1,len(points)-1)])-Vector(points[max(0,i-1)])
        tangent.normalize(); a=tangent.cross(Vector((0,0,1)))
        if a.length<.1:a=tangent.cross(Vector((0,1,0)))
        a.normalize(); b=tangent.cross(a).normalized()
        for k in range(sides):
            q=Vector(p)+radii[i]*(a*math.cos(k*math.tau/sides)+b*math.sin(k*math.tau/sides))
            verts.append(q)
    for i in range(len(points)-1):
        for k in range(sides):
            n=i*sides+k; nk=i*sides+(k+1)%sides
            faces.append((n,nk,nk+sides,n+sides))
    faces.append(tuple(reversed(range(sides))))
    faces.append(tuple((len(points)-1)*sides+k for k in range(sides)))
    return mesh(name,verts,faces,mat)
def lock(name,pts,width,mat):
    # Catmull-Rom interpolation gives broad continuous sculpted clumps.
    points=[]; radii=[]
    for j in range(len(pts)-1):
        p0=Vector(pts[max(0,j-1)]); p1=Vector(pts[j]); p2=Vector(pts[j+1]); p3=Vector(pts[min(j+2,len(pts)-1)])
        for k in range(5):
            t=k/5; q=.5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t*t*t)
            f=(j+t)/(len(pts)-1); points.append(q); radii.append(width*(.65+.35*math.sin(f*math.pi))*(1-.96*f**3))
    points.append(Vector(pts[-1])); radii.append(.006)
    return tube(name,points,radii,mat)
reports=[]
for who in ['evie','tyler','dad']:
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
    skin=material('Skin',(.83,.55,.39) if who=='dad' else (.93,.65,.52))
    dark=material('Ink',(.028,.032,.047)); silver=material('Pearl',(.93,.96,1),.25)
    hair=material('Hair',{'evie':(.025,.13,.40),'tyler':(.19,.095,.043),'dad':(.40,.255,.10)}[who])
    light=material('HairLight',{'evie':(.025,.40,.56),'tyler':(.37,.22,.09),'dad':(.64,.45,.22)}[who])
    accent=material('Accent',{'evie':(.66,.085,.48),'tyler':(.50,.27,.18),'dad':(.31,.19,.085)}[who])
    sphere('Face',(0,1.34,-.025),(.425,.415,.385),skin,32,16)
    for side in [-1,1]:
        sphere('Ear',(side*.405,1.35,.005),(.073,.105,.07),skin,16,8)
        sphere('Eyes',(side*.146,1.40,-.387),(.051,.082,.026),dark)
        sphere('EyeLight',(side*.146-.011,1.425,-.411),(.013,.021,.008),silver,12,8)
        if who=='tyler':
            for n in range(3):sphere('Freckles',(side*(.22+n*.038),1.29+(n%2)*.024,-.347+n*.011),(.012,.011,.006),accent,8,6)
    sphere('Nose',(0,1.29,-.414),(.038,.035,.031),skin,16,8)
    pts=[(x,1.18+.026*(x/.085)**2,-.391) for x in [-.085,-.065,-.04,0,.04,.065,.085]]
    tube('Mouth',pts,[.012]*len(pts),dark,8)
    # Back and crown sit behind the face. Front locks never cover the eyes/mouth.
    sphere('HairTop',(0,1.64,.055),(.44,.24,.36),hair)
    if who=='tyler':
        for i in range(7):
            x=(i-3)*.105
            lock('HairFront',[(x-.045,1.79,-.13),(x,1.72,-.31),(x+.028,1.53+abs(i-3)*.023,-.36)],.073,light if i in [1,4] else hair)
        for i in range(3):lock('HairTop',[(-.23+i*.2,1.77,.05),(-.18+i*.19,1.90,.005),(-.10+i*.17,1.83,-.08)],.082,light if i==1 else hair)
    else:
        for side in [-1,1]:
            for n in range(3):
                z=.02+n*.12
                lock('HairSide',[(side*.29,1.68,z),(side*(.435+n*.018),1.43,z),(side*(.46+n*.02),1.13,z),(side*(.40+n*.04),.94,z-.015)],.085,light if n==0 else hair)
        for i in range(5):
            x=(i-2)*.16
            lock('HairSide',[(x,1.64,.30),(x*1.15,1.3,.35),(x*1.24,.99,.34)],.105,hair if i%2 else light)
        for i in range(6):
            x=(i-2.5)*.123
            lock('HairFront',[(x-.055,1.79,-.14),(x,1.7,-.30),(x+.025,1.55+abs(i-2.5)*.018,-.35)],.072,accent if who=='evie' and i in [1,2,3] else light)
    if who=='dad':
        # Curved beard beneath cheeks leaves a readable smile opening.
        for i in range(9):
            a=math.pi*.11+i*math.pi*.78/8; x=.31*math.cos(a); y=1.21-.20*math.sin(a)
            sphere('Beard',(x,y,-.31),(.088,.11,.094),accent,16,8)
        for side in [-1,1]:lock('Moustache',[(side*.016,1.245,-.422),(side*.084,1.235,-.425),(side*.146,1.21,-.393)],.025,light)
    if who in ['evie','dad']:
        pts=[(.427+.038*math.cos(k*math.tau/20),1.29+.056*math.sin(k*math.tau/20),-.055) for k in range(21)]
        tube('Jewellery',pts,[.009]*21,silver,6)
    if who=='evie':
        pts=[(-.075+.024*math.cos(k*math.tau/20),1.265+.027*math.sin(k*math.tau/20),-.408) for k in range(21)]
        tube('Jewellery',pts,[.006]*21,silver,6)
    # Combine repeated subparts per semantic layer/material; retain separate Mouth.
    groups={}
    for o in list(bpy.context.scene.objects):
        groups.setdefault((o.name.split('.')[0],o.data.materials[0].name),[]).append(o)
    for (name,_),objects in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        for o in objects:o.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]; bpy.ops.object.join(); bpy.context.object.name=name
    tris=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in bpy.context.scene.objects)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/(who+'.blend')))
    bpy.ops.export_scene.gltf(filepath=str(OUT/(who+'.glb')),export_format='GLB',export_yup=True,export_animations=False,export_cameras=False,export_lights=False)
    reports.append({'id':who,'triangles':tris,'materials':6,'mouth':True,'source':'authored Blender geometry; no photo textures'})
(SOURCE/'model-receipt.json').write_text(json.dumps(reports,indent=2))

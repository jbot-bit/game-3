"""Concept-matched bean silhouettes, swept ribbon locks and modular clothes."""
exec(open('C:/game-3/.tools/art-sources/crown-family/build_family.py').read().split('reports=[]')[0])
import random
import numpy as np
random.seed(44)
def linear(h):
    a=[int(h[i:i+2],16)/255 for i in (0,2,4)]
    return tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in a)
def surface_texture(name,h,cloth=False):
    size=256
    yy,xx=np.mgrid[0:size,0:size];u=xx/size;v=yy/size
    if cloth:
        pattern=.97+.018*np.sin(xx*math.pi*.5)*np.sin(yy*math.pi*.5)
        nx=.02*np.cos(xx*math.pi*.5);ny=.02*np.cos(yy*math.pi*.5)
    else:
        wave=2*math.pi*(u*15+.12*np.sin(v*math.tau))
        pattern=.88+.10*np.cos(wave)+.04*np.cos(wave*3.3)+.025*np.sin(yy*.9+xx*1.7)
        nx=.32*np.sin(wave)+.08*np.sin(wave*3.3);ny=.015*np.cos(v*math.tau)
    rgba=np.ones((size,size,4),dtype=np.float32)
    rgb=np.array([int(h[i:i+2],16)/255 for i in (0,2,4)])
    rgba[:,:,:3]=np.clip(rgb[None,None,:]*pattern[:,:,None],0,1)
    image=bpy.data.images.new(name+'Fabric' if cloth else name+'Flow',width=size,height=size)
    image.pixels.foreach_set(rgba.ravel());image.filepath_raw=str(SOURCE/(image.name+'.png'));image.file_format='PNG';image.save();image.pack()
    n=np.stack([nx,ny,np.ones_like(nx)],axis=-1);n=n/np.linalg.norm(n,axis=-1,keepdims=True)
    rgba[:,:,:3]=n*.5+.5
    normal=bpy.data.images.new(name+'Normal',width=size,height=size);normal.colorspace_settings.name='Non-Color';normal.pixels.foreach_set(rgba.ravel());normal.filepath_raw=str(SOURCE/(normal.name+'.png'));normal.file_format='PNG';normal.save();normal.pack()
    return image,normal

def mat(name,h,metal=0):
    m=material(name,linear(h),metal)
    bs=m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Roughness'].default_value=.85 if name in ['Cloth','ClothTrim','Hair','HairLight','HairRidge','Beard'] else .65
    bs.inputs['Specular'].default_value=.18
    if name=='Ink':bs.inputs['Roughness'].default_value=.23
    if name in ['Cloth','ClothTrim','Hair','HairLight','HairRidge','Beard','Pink','Purple']:
        image,normal=surface_texture(name+h,h,name.startswith('Cloth'))
        tex=m.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image
        m.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
        texn=m.node_tree.nodes.new('ShaderNodeTexImage');texn.image=normal
        nm=m.node_tree.nodes.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=.4
        m.node_tree.links.new(texn.outputs['Color'],nm.inputs['Color']);m.node_tree.links.new(nm.outputs['Normal'],bs.inputs['Normal'])
    return m
def curve(pts,steps=18):
    result=[]
    for i in range(steps+1):
        t=i/steps; u=1-t
        result.append(Vector(pts[0])*u**3+Vector(pts[1])*3*u*u*t+Vector(pts[2])*3*u*t*t+Vector(pts[3])*t**3)
    return result
def ribbon(name,pts,width,depth,base,shine):
    path=curve(pts); verts=[]; faces=[]; frames=[]
    for i,p in enumerate(path):
        t=i/(len(path)-1); tangent=(path[min(i+1,len(path)-1)]-path[max(0,i-1)]).normalized()
        a=Vector((tangent.y,-tangent.x,0)).normalized(); b=tangent.cross(a).normalized()
        if b.z>0:b=-b
        taper=max(.012,math.sin(math.pi*(.13+.87*t))**.80)
        frames.append((a,b,taper))
        for k in range(12):
            angle=k*math.tau/12
            verts.append(p+a*math.cos(angle)*width*taper+b*math.sin(angle)*depth*taper)
    for i in range(len(path)-1):
        for k in range(12):faces.append((i*12+k,i*12+(k+1)%12,(i+1)*12+(k+1)%12,(i+1)*12+k))
    faces.extend([tuple(reversed(range(12))),tuple((len(path)-1)*12+k for k in range(12))])
    obj=mesh(name,verts,faces,base)
    uv=obj.data.uv_layers.new(name='UVMap')
    for poly in obj.data.polygons:
        for li in poly.loop_indices:
            vi=obj.data.loops[li].vertex_index
            uv.data[li].uv=((vi%12)/12,(vi//12)/(len(path)-1))
    for offset in []:
        ps=[]; rs=[]
        for i in range(1,len(path)-1,2):
            a,b,taper=frames[i];ps.append(path[i]+a*width*offset*taper+b*depth*.92*taper);rs.append(.0032*taper)
        tube(name,ps,rs,shine,5)
def torso(matshirt,trim):
    levels=[(.43,.43,.29),(.455,.49,.36),(.50,.515,.39),(.72,.525,.41),(1.02,.46,.36),(1.18,.365,.28),(1.22,.31,.255)]
    verts=[]; faces=[]
    for y,rx,rz in levels:
        for i in range(40):
            a=i*math.tau/40;verts.append((rx*math.cos(a),y,rz*math.sin(a)))
    for j in range(len(levels)-1):
        for i in range(40):faces.append((j*40+i,j*40+(i+1)%40,(j+1)*40+(i+1)%40,(j+1)*40+i))
    faces.extend([tuple(reversed(range(40))),tuple((len(levels)-1)*40+i for i in range(40))]);obj=mesh('Torso',verts,[tuple(reversed(f)) for f in faces],matshirt)
    uv=obj.data.uv_layers.new(name='UVMap')
    for loop in obj.data.loops: uv.data[loop.index].uv=((loop.vertex_index%40)/40,(loop.vertex_index//40)/(len(levels)-1))
    for y,rx,rz,r in [(1.213,.314,.259,.018),(.49,.517,.392,.009)]:
        ps=[(rx*math.cos(i*math.tau/40),y,rz*math.sin(i*math.tau/40)) for i in range(41)]
        tube('ShirtTrim',ps,[r]*41,trim,6)
def hair_mass(base,shine):
    nu,nv=56,24; verts=[];faces=[]
    for j in range(nv+1):
        v=j/nv
        for i in range(nu+1):
            a=-1.96+3.92*i/nu
            bottom=1.06+.06*math.cos(a*4)
            y=bottom+(2.055-bottom)*v
            crown=math.sqrt(max(.03,1-((y-1.55)/.58)**2))
            r=.51*crown+.055*(1-v)*math.sin(v*math.tau*1.35+a*1.5)
            r+=.008*math.cos(a*27+v*3)
            verts.append((math.sin(a)*r,y,math.cos(a)*r*.82+.06))
    for j in range(nv):
        for i in range(nu):
            n=j*(nu+1)+i;faces.append((n,n+1,n+nu+2,n+nu+1))
    obj=mesh('HairBack',verts,faces,base)
    uv=obj.data.uv_layers.new(name='UVMap')
    for loop in obj.data.loops: uv.data[loop.index].uv=((loop.vertex_index%(nu+1))/nu,(loop.vertex_index//(nu+1))/nv)
    # Large S-shaped overlapping waves instead of parallel dangling tubes.
    for side in [-1,1]:
        for i in range(3):
            z=-.04+i*.18
            ribbon('HairSide',[(side*.30,1.99,z+.04),(side*.68,1.76,z-.06),(side*.29,1.54,z),(side*.54,1.34,z-.10)],.115,.042,base if i%2 else shine,shine)
            ribbon('HairSide',[(side*.48,1.56,z),(side*.32,1.36,z-.10),(side*.63,1.23,z),(side*.48,1.01,z-.13)],.115,.040,shine if i%2 else base,shine)

def beard_patch(base):
    nu,nv=40,16;verts=[];faces=[]
    for j in range(nv+1):
        v=j/nv
        for i in range(nu+1):
            x=-.36+.72*i/nu
            top=1.36+.16*(abs(x)/.36)**1.6
            bottom=1.16+.11*(abs(x)/.36)**1.7
            y=top*(1-v)+bottom*v
            z=-.405*math.sqrt(max(.03,1-(x/.465)**2-((top-1.58)/.46)**2))-.015
            z=z*(1-v)+(-.37+.16*(abs(x)/.36)**2)*v-.026*math.sin(v*math.pi)
            z-=.0035*math.cos(x*190+v*2)
            verts.append((x,y,z))
    for j in range(nv):
        for i in range(nu):
            n=j*(nu+1)+i;faces.append((n,n+1,n+nu+2,n+nu+1))
    obj=mesh('Beard',verts,faces,base)
    uv=obj.data.uv_layers.new(name='UVMap')
    for loop in obj.data.loops: uv.data[loop.index].uv=((loop.vertex_index%(nu+1))/nu,(loop.vertex_index//(nu+1))/nv)


reports=[]
for who in ['evie','tyler','dad']:
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    skin=mat('Skin','F4AF85'); dark=mat('Ink','141B29'); white=mat('Pearl','FAF4E8'); silver=mat('Silver','BBC9D9',.7)
    shirt=mat('Cloth',{'evie':'343843','tyler':'E9E6E0','dad':'30343C'}[who]); trim=mat('ClothTrim',{'evie':'434958','tyler':'D3D0CB','dad':'414650'}[who])
    hair=mat('Hair',{'evie':'153C9C','tyler':'5A351E','dad':'846037'}[who]); light=mat('HairLight',{'evie':'227AC2','tyler':'976A40','dad':'B68E57'}[who]); ridge=mat('HairRidge',{'evie':'3D8CD4','tyler':'B0885C','dad':'C7A471'}[who]); pink=mat('Pink','CB39A1'); purple=mat('Purple','8036BE'); freckle=mat('Freckle','B6714B')
    torso(shirt,trim)
    sphere('Face',(0,1.58,0),(.465,.46,.405),skin,40,24)
    for side in [-1,1]:
        sphere('Ear',(side*.445,1.52,.01),(.065,.11,.07),skin,16,10)
        sphere('Eyes',(side*.155,1.61,-.386),(.057,.102,.025),dark,24,16)
        sphere('EyeLight',(side*.155-.015,1.65,-.410),(.015,.023,.009),white,12,8)
        for i in range(4):
            x=side*(.25+(i%2)*.046);y=1.47+(i//2)*.028
            z=-.405*math.sqrt(max(.02,1-(x/.465)**2-((y-1.58)/.46)**2))-.007
            sphere('Freckles',(x,y,z),(.007,.007,.004),freckle,8,6)
        sphere('Pants',(side*.245,.36,0),(.195,.16,.225),dark,20,10)
    ps=[(x,1.355+.027*(x/.065)**2,-.367) for x in [-.065,-.045,-.025,0,.025,.045,.065]]
    tube('Mouth',ps,[.009]*len(ps),dark,8)
    sphere('HairTop',(0,1.92,.08),(.455,.23,.36),hair,32,16)
    if who=='tyler':
        # Layered diagonal locks from an off-centre crown, with irregular lengths.
        for i in range(12):
            x=-.40+i*.072; endy=1.70+.10*abs(x)/.4+random.uniform(-.05,.07)
            ribbon('HairFront',[(.12+x*.3,2.105,.01),(x+.10,2.12,-.22),(x+.025,1.91,-.38),(x-.045,endy,-.38)],.065,.017,light if i%3==0 else hair,ridge)
        for i in range(7):
            x=-.32+i*.1
            ribbon('HairTop',[(.1,2.09,.10),(x,2.22,.03),(x-.06,2.16,-.12),(x-.12,2.01,-.22)],.09,.020,light if i%2 else hair,ridge)
        for side in [-1,1]:
            ribbon('HairSide',[(side*.30,2.0,.12),(side*.47,1.98,.02),(side*.49,1.84,-.1),(side*.44,1.67,-.16)],.065,.025,hair,light)
    else:
        hair_mass(hair,light)
        if who=='evie':
            for i in range(6):
                x=-.30+i*.12
                ribbon('HairFront',[(.02,2.10,-.08),(x+.10,2.03,-.32),(x+.06,1.85,-.39),(x-.045,1.72+abs(x)*.2,-.36)],.075,.016,pink if i in [2,3,4] else purple,light if i<2 else pink)
            for i in range(3):
                ribbon('HairFront',[(-.02,2.11+i*.014,.01),(-.37,2.08,-.24),(-.35,1.81,-.38),(-.52,1.66-i*.06,-.24)],.070,.032,light if i%2 else hair,ridge)
        else:
            for side in [-1,1]:
                for i in range(4):
                    ribbon('HairFront',[(.06,2.115-i*.015,-.14+i*.035),(side*(.25+i*.025),2.16-i*.02,-.30+i*.025),(side*(.34+i*.02),1.83+i*.025,-.415+i*.03),(side*(.47+i*.022),1.66+i*.028,-.26+i*.04)],.112,.030,light if i%2==0 else hair,ridge)
            # Continuous beard shell and fine swept strands instead of disconnected beads.
            beard=mat('Beard','906A3F')
            ps=[(-.36,1.52,-.25),(-.32,1.35,-.34),(-.20,1.25,-.39),(0,1.22,-.41),(.20,1.25,-.39),(.32,1.35,-.34),(.36,1.52,-.25)]
            # Beard is layered along the cheek surface, not a tubular chin ring.
            beard_patch(beard)
            for side in [-1,1]:
                ribbon('Moustache',[(side*.01,1.42,-.411),(side*.08,1.44,-.443),(side*.16,1.38,-.44),(side*.205,1.34,-.397)],.032,.022,beard,light)
                ribbon('Brows',[(side*.105,1.80,-.35),(side*.15,1.83,-.35),(side*.21,1.81,-.32),(side*.245,1.78,-.30)],.026,.011,light,ridge)
            for i in range(18):
                x=(i-8.5)*.031;y=1.14-.12*(1-(x/.28)**2);z=-.31-.045*(1-(x/.28)**2)
                ps=[(x+.018*math.cos(k*math.tau/12),y+.024*math.sin(k*math.tau/12),z+(.007 if i%2 else -.007)*math.cos(k*math.tau/12)) for k in range(13)]
                tube('Chain',ps,[.005]*13,silver,5)
    if who in ['evie','dad']:
        ps=[(-.445+.032*math.cos(k*math.tau/20),1.47+.047*math.sin(k*math.tau/20),-.125) for k in range(21)];tube('Jewellery',ps,[.008]*21,silver,6)
    if who=='evie':
        ps=[(.028*math.cos(k*math.tau/20),1.45+.022*math.sin(k*math.tau/20),-.405) for k in range(21)];tube('Jewellery',ps,[.006]*21,silver,6)
        for side in [-1,1]:ribbon('Lashes',[(side*.20,1.64,-.402),(side*.23,1.65,-.40),(side*.24,1.66,-.39),(side*.24,1.675,-.39)],.009,.007,dark,dark)
    groups={}
    for o in list(bpy.context.scene.objects):groups.setdefault((o.name.split('.')[0],o.data.materials[0].name),[]).append(o)
    for (name,_),objects in groups.items():
        if len(objects)>1:
            bpy.ops.object.select_all(action='DESELECT')
            for o in objects:o.select_set(True)
            bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join()
        objects[0].name=name
    # Repair consistent outward winding before AO and glTF export.
    for obj in list(bpy.context.scene.objects):
        bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
        bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.object.mode_set(mode='OBJECT')
    # Local ambient occlusion baked into vertex colour. No runtime texture cost.
    from mathutils.bvhtree import BVHTree
    from mathutils import Vector as V
    av=[]; af=[]
    for obj in bpy.context.scene.objects:
        offset=len(av);av.extend([obj.matrix_world@v.co for v in obj.data.vertices])
        af.extend([tuple(offset+i for i in p.vertices) for p in obj.data.polygons])
    tree=BVHTree.FromPolygons(av,af)
    for obj in bpy.context.scene.objects:
        data=obj.data; data.update(); colours=data.color_attributes.new(name='AmbientOcclusion',type='FLOAT_COLOR',domain='POINT')
        for v in data.vertices:
            p=obj.matrix_world@v.co; normal=(obj.matrix_world.to_3x3()@v.normal).normalized()
            axis=normal.cross(V((0,0,1)))
            if axis.length<.1:axis=normal.cross(V((0,1,0)))
            axis.normalize(); other=normal.cross(axis).normalized(); blocked=0
            for k in range(12):
                phi=k*2.399963; h=(k+.5)/12; r=math.sqrt(1-h*h)
                direction=(normal*h+axis*(r*math.cos(phi))+other*(r*math.sin(phi))).normalized()
                hit=tree.ray_cast(p+normal*.002,direction,.15)
                if hit[0] is not None:blocked+=1
            shade=1-.42*blocked/12
            colours.data[v.index].color=(shade,shade,shade,1)
    tris=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in bpy.context.scene.objects)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/(who+'-v2.blend')))
    bpy.ops.export_scene.gltf(filepath=str(OUT/(who+'.glb')),export_format='GLB',export_yup=True,export_animations=False,export_cameras=False,export_lights=False)
    reports.append({'id':who,'triangles':tris,'source':'authored concept revision 2; no photo textures'})
(SOURCE/'model-receipt-v2.json').write_text(json.dumps(reports,indent=2))

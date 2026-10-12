"""Family art revision 7: rounded beard and layered scalp-following locks; visual review required."""
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
        wave=2*math.pi*(u*4+.18*np.sin(v*math.tau))
        pattern=.97+.018*np.cos(wave)+.012*np.cos(wave*3.3)
        nx=.065*np.sin(wave)+.025*np.sin(wave*3.3);ny=.015*np.cos(v*math.tau)
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
        nm=m.node_tree.nodes.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=.25
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
        radial=p-Vector((0,1.58,.03))
        b=(radial-tangent*radial.dot(tangent)).normalized()
        a=tangent.cross(b).normalized()
        taper=max(.014,(.48+.72*math.sin(math.pi*t))*(1-t**3))
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
    # A small concealed scalp plus overlapping, irregular continuous waves.
    # Individual clumps wrap around the head rather than hanging from a helmet.
    nu,nv=48,16; verts=[];faces=[]
    for j in range(nv+1):
        v=j/nv
        for i in range(nu+1):
            a=-1.88+3.76*i/nu
            bottom=1.19+.035*math.cos(a*5)
            y=bottom+(2.0-bottom)*v
            crown=math.sqrt(max(.03,1-((y-1.57)/.54)**2))
            r=.465*crown+.035*(1-v)*math.sin(v*math.tau+a*1.7)
            verts.append((math.sin(a)*r,y,math.cos(a)*r*.87+.06))
    for j in range(nv):
        for i in range(nu):
            n=j*(nu+1)+i;faces.append((n,n+1,n+nu+2,n+nu+1))
    mesh('HairBack',verts,faces,base)
    for i in range(13):
        a=-1.93+i*3.86/12
        sway=.09*math.sin(i*2.1); end=1.06+.075*math.sin(i*1.6)
        def at(rad,y,ang):return (math.sin(ang)*rad,y,math.cos(ang)*rad*.88+.06)
        ribbon('HairSide',[at(.35,2.0,a-.12),at(.70,1.84,a+.13),at(.32,1.37,a-.15),at(.51,end,a+sway)],.095+(i%3)*.013,.060,shine if i%4==1 else base,shine)
    for side in [-1,1]:
        for i in range(2):
            z=-.15+i*.20
            ribbon('HairSide',[(side*.31,1.96,z+.08),(side*.66,1.82,z-.12),(side*.34,1.53,z-.13),(side*.57,1.42-i*.05,z-.10)],.13,.06,shine if i==0 else base,shine)
            ribbon('HairSide',[(side*.47,1.57,z),(side*.33,1.40,z-.16),(side*.64,1.23,z-.02),(side*.45,1.06-i*.02,z-.11)],.11,.055,base if i==0 else shine,shine)

def beard_patch(base):
    # Rounded chin volume. Joined front/back grid closes the shell; subdivision
    # softens the cheek edge instead of leaving a flat rectangular mask.
    nu,nv=32,10;verts=[];faces=[]
    for layer in range(2):
        for j in range(nv+1):
            v=j/nv
            for i in range(nu+1):
                x=-.355+.71*i/nu; a=abs(x)/.355
                top=1.345+.135*a**2
                bottom=1.145+.245*a**2
                y=top*(1-v)+bottom*v
                z=-.425*math.sqrt(max(.05,1-(x/.48)**2))-.020*math.sin(v*math.pi)
                z+=.030*abs(v-.5)*2
                z+=.045 if layer else 0
                verts.append((x,y,z))
    count=(nu+1)*(nv+1)
    for layer in range(2):
        for j in range(nv):
            for i in range(nu):
                n=layer*count+j*(nu+1)+i
                q=(n,n+1,n+nu+2,n+nu+1)
                faces.append(q if layer==0 else tuple(reversed(q)))
    border=list(range(nu+1))+[j*(nu+1)+nu for j in range(1,nv+1)]+[nv*(nu+1)+i for i in range(nu-1,-1,-1)]+[j*(nu+1) for j in range(nv-1,0,-1)]
    for a,b in zip(border,border[1:]+border[:1]):faces.append((a,b,b+count,a+count))
    obj=mesh('Beard',verts,faces,base)
    bpy.context.view_layer.objects.active=obj
    mod=obj.modifiers.new('Soft beard edge','SUBSURF');mod.levels=1
    bpy.ops.object.modifier_apply(modifier=mod.name)
    # Small swept cheek/chin clumps catch light without a picket-fence edge.
    for i in range(9):
        x=-.29+i*.0725;a=abs(x)/.355
        top=1.35+.08*a; bottom=1.14+.24*a*a
        z=-.432*math.sqrt(max(.1,1-(x/.48)**2))
        ribbon('Beard',[(x,top,z),(x-.018,top-.06,z-.025),(x+.025,bottom+.045,z-.022),(x+.015,bottom,z+.008)],.036,.018,base,base)


reports=[]
for who in ['evie','tyler','dad']:
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    skin=mat('Skin','F2BE9F'); dark=mat('Ink','141B29'); white=mat('Pearl','FAF4E8'); silver=mat('Silver','BBC9D9',.7)
    shirt=mat('Cloth',{'evie':'343843','tyler':'E9E6E0','dad':'30343C'}[who]); trim=mat('ClothTrim',{'evie':'434958','tyler':'D3D0CB','dad':'414650'}[who])
    hair=mat('Hair',{'evie':'274F9F','tyler':'765037','dad':'987445'}[who]); light=mat('HairLight',{'evie':'347BA8','tyler':'9A7551','dad':'C29A66'}[who]); ridge=mat('HairRidge',{'evie':'3D8CD4','tyler':'B0885C','dad':'C7A471'}[who]); pink=mat('Pink','CB39A1'); purple=mat('Purple','8036BE'); freckle=mat('Freckle','B6714B')
    torso(shirt,trim)
    sphere('Face',(0,1.58,0),(.475,.465,.410),skin,40,24)
    for side in [-1,1]:
        sphere('Ear',(side*.445,1.52,.01),(.065,.11,.07),skin,16,10)
        sphere('Eyes',(side*.155,1.61,-.386),(.055,.095,.019),dark,24,16)
        sphere('EyeLight',(side*.155-.015,1.65,-.410),(.010,.015,.006),white,12,8)
        for i in range(4 if who != 'dad' else 0):
            x=side*(.25+(i%2)*.046);y=1.47+(i//2)*.028
            z=-.405*math.sqrt(max(.02,1-(x/.465)**2-((y-1.58)/.46)**2))-.007
            sphere('Freckles',(x,y,z),(.007,.007,.004),freckle,8,6)
        sphere('Pants',(side*.245,.36,0),(.195,.16,.225),dark,20,10)
    ps=[(x,1.355+.027*(x/.065)**2,-.367) for x in [-.065,-.045,-.025,0,.025,.045,.065]]
    tube('Mouth',ps,[.009]*len(ps),dark,8)
    sphere('HairTop',(0,1.88,.09),(.424,.19,.33),hair,32,16)
    if who=='tyler':
        # Tousled asymmetric fringe, broad roots and tapered overlapping tips.
        for i in range(10):
            x=-.40+i*.085; endy=1.71+.12*abs(x)/.4+random.uniform(-.035,.035)
            ribbon('HairFront',[(.16+x*.35,2.04,.025),(x+.11,2.13,-.24),(x-.055,1.96,-.40),(x-.10,endy,-.355)],.077,.052,light if i%3==0 else hair,ridge)
        for i in range(8):
            a=i*math.tau/8
            ribbon('HairTop',[(.12,2.02,.02),(.34*math.cos(a),2.22,.31*math.sin(a)),(.46*math.cos(a),2.0,.38*math.sin(a)),(.45*math.cos(a+.13),1.84,.37*math.sin(a+.13))],.095,.055,light if i%3==0 else hair,ridge)
        for side in [-1,1]:
            for i in range(3):
                ribbon('HairSide',[(side*.28,1.99,.20-i*.11),(side*.46,2.02,.13-i*.11),(side*.50,1.86,.09-i*.11),(side*.43,1.70+i*.04,.08-i*.10)],.072,.042,hair if i%2 else light,light)
    else:
        hair_mass(hair,light)
        if who=='evie':
            for i in range(6):
                x=-.30+i*.12
                ribbon('HairFront',[(.02,2.10,-.08),(x+.10,2.03,-.32),(x+.06,1.85,-.39),(x-.045,1.72+abs(x)*.2,-.36)],.081,.046,pink if i in [2,3,4] else purple,light if i<2 else pink)
            for i in range(3):
                ribbon('HairFront',[(-.02,2.11+i*.014,.01),(-.37,2.08,-.24),(-.35,1.81,-.38),(-.52,1.66-i*.06,-.24)],.091,.055,light if i%2 else hair,ridge)
        else:
            for side in [-1,1]:
                for i in range(4):
                    ribbon('HairFront',[(.075,2.075-i*.011,-.10+i*.04),(side*(.25+i*.025),2.21-i*.027,-.30+i*.025),(side*(.34+i*.02),1.83+i*.025,-.415+i*.03),(side*(.47+i*.022),1.66+i*.028,-.26+i*.04)],.105,.060,light if i%2==0 else hair,ridge)
            # Continuous beard shell and fine swept strands instead of disconnected beads.
            beard=mat('Beard','A58053')
            ps=[(-.36,1.52,-.25),(-.32,1.35,-.34),(-.20,1.25,-.39),(0,1.22,-.41),(.20,1.25,-.39),(.32,1.35,-.34),(.36,1.52,-.25)]
            # Beard is layered along the cheek surface, not a tubular chin ring.
            beard_patch(beard)
            for side in [-1,1]:
                ribbon('Moustache',[(side*.01,1.42,-.411),(side*.08,1.44,-.443),(side*.16,1.38,-.44),(side*.205,1.34,-.397)],.042,.028,beard,light)
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
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/(who+'-v7.blend')))
    bpy.ops.export_scene.gltf(filepath=str(OUT/(who+'.glb')),export_format='GLB',export_yup=True,export_animations=False,export_cameras=False,export_lights=False)
    reports.append({'id':who,'triangles':tris,'source':'authored family revision 7; no photo textures; visual review required'})
(SOURCE/'model-receipt-v7.json').write_text(json.dumps(reports,indent=2))

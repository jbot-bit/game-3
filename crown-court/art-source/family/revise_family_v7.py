from pathlib import Path
p = Path(__file__).parent
s = (p / 'build_family_v2.py').read_text()
s = s.replace('Concept-matched bean silhouettes, swept ribbon locks and modular clothes.', 'Family art revision 7: rounded beard and layered scalp-following locks; visual review required.')
s = s.replace("wave=2*math.pi*(u*15+.12*np.sin(v*math.tau))", "wave=2*math.pi*(u*4+.18*np.sin(v*math.tau))")
s = s.replace("pattern=.88+.10*np.cos(wave)+.04*np.cos(wave*3.3)+.025*np.sin(yy*.9+xx*1.7)", "pattern=.97+.018*np.cos(wave)+.012*np.cos(wave*3.3)")
s = s.replace("nx=.32*np.sin(wave)+.08*np.sin(wave*3.3)", "nx=.065*np.sin(wave)+.025*np.sin(wave*3.3)")
s = s.replace("nm.inputs['Strength'].default_value=.4", "nm.inputs['Strength'].default_value=.25")
s = s.replace("a=Vector((tangent.y,-tangent.x,0)).normalized(); b=tangent.cross(a).normalized()\n        if b.z>0:b=-b", "radial=p-Vector((0,1.58,.03))\n        b=(radial-tangent*radial.dot(tangent)).normalized()\n        a=tangent.cross(b).normalized()")
s = s.replace("max(.012,math.sin(math.pi*(.13+.87*t))**.80)", "max(.014,(.48+.72*math.sin(math.pi*t))*(1-t**3))")
start = s.index('def hair_mass(')
end = s.index('\n\nreports=[]', start)
s = s[:start] + '''def hair_mass(base,shine):
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
''' + s[end:]
s = s.replace("'F4AF85'", "'F2BE9F'")
s = s.replace("'153C9C'", "'274F9F'").replace("'227AC2'", "'347BA8'")
s = s.replace("'5A351E'", "'765037'").replace("'976A40'", "'9A7551'")
s = s.replace("'846037'", "'987445'").replace("'B68E57'", "'C29A66'").replace("'906A3F'", "'A58053'")
s = s.replace("(.465,.46,.405)", "(.475,.465,.410)")
s = s.replace("(.057,.102,.025)", "(.055,.095,.019)")
s = s.replace("(.015,.023,.009)", "(.010,.015,.006)")
s = s.replace("range(4):\n            x=side", "range(4 if who != 'dad' else 0):\n            x=side")
s = s.replace("sphere('HairTop',(0,1.92,.08),(.455,.23,.36),hair,32,16)", "sphere('HairTop',(0,1.88,.09),(.424,.19,.33),hair,32,16)")
start = s.index("        # Layered diagonal locks")
end = s.index("    else:\n        hair_mass", start)
s = s[:start] + '''        # Tousled asymmetric fringe, broad roots and tapered overlapping tips.
        for i in range(10):
            x=-.40+i*.085; endy=1.71+.12*abs(x)/.4+random.uniform(-.035,.035)
            ribbon('HairFront',[(.16+x*.35,2.04,.025),(x+.11,2.13,-.24),(x-.055,1.96,-.40),(x-.10,endy,-.355)],.077,.052,light if i%3==0 else hair,ridge)
        for i in range(8):
            a=i*math.tau/8
            ribbon('HairTop',[(.12,2.02,.02),(.34*math.cos(a),2.22,.31*math.sin(a)),(.46*math.cos(a),2.0,.38*math.sin(a)),(.45*math.cos(a+.13),1.84,.37*math.sin(a+.13))],.095,.055,light if i%3==0 else hair,ridge)
        for side in [-1,1]:
            for i in range(3):
                ribbon('HairSide',[(side*.28,1.99,.20-i*.11),(side*.46,2.02,.13-i*.11),(side*.50,1.86,.09-i*.11),(side*.43,1.70+i*.04,.08-i*.10)],.072,.042,hair if i%2 else light,light)
''' + s[end:]
s = s.replace(".075,.016,pink", ".081,.046,pink")
s = s.replace(".070,.032,light", ".091,.055,light")
s = s.replace(".112,.030,light", ".105,.060,light")
s = s.replace("(.06,2.115-i*.015,-.14+i*.035)", "(.075,2.075-i*.011,-.10+i*.04)")
s = s.replace("side*(.25+i*.025),2.16-i*.02", "side*(.25+i*.025),2.21-i*.027")
s = s.replace(".032,.022,beard", ".042,.028,beard")
s = s.replace("who+'-v2.blend'", "who+'-v7.blend'")
s = s.replace("authored concept revision 2; no photo textures", "authored family revision 7; no photo textures; visual review required")
s = s.replace("model-receipt-v2.json", "model-receipt-v7.json")
(p/'build_family_v7.py').write_text(s)
print('Wrote build_family_v7.py')

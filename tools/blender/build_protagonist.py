"""Original stylized lantern investigator. Run in Blender; no remote generation service."""
import bpy, math, random, json
from mathutils import Vector
from pathlib import Path
from math import sin, cos, pi

ROOT=Path('F:/GitHub/project18buxiuxiuxian')
OUT=ROOT/'art/3d/lantern-investigator'
GAME=ROOT/'godot/assets/characters3d'
OUT.mkdir(parents=True,exist_ok=True); GAME.mkdir(parents=True,exist_ok=True)
random.seed(18)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
for a in list(bpy.data.actions): bpy.data.actions.remove(a)
parts=[]

def mat(name,hexcolor,metal=0,rough=.8,emission=0):
    def linear(v):return v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4
    color=tuple(linear(int(hexcolor[i:i+2],16)/255) for i in (0,2,4))
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
    if emission:p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=emission
    return m
ink=mat('Ink / charcoal','080e13');hair=mat('Blue-black hair','111c24');hairlit=mat('Hair carved planes','24333b')
streak=mat('Silver forelock','a4b6b2');skin=mat('Pale warm porcelain','bfae8d');skinshade=mat('Cheek shadow','917c69')
coat=mat('Petrol wool','123433');coatlit=mat('Wool lit facets','234946');coatside=mat('Deep seam panels','0c2429')
lining=mat('Oxblood lining','3f2229');shirt=mat('Aged ivory','cec8aa');leather=mat('Worn chestnut leather','3b2e25')
brass=mat('Dull engraved brass','8a7041',.55,.48);gold=mat('Brass worn edge','b69a5e',.55,.45)
red=mat('Cravat','643035');eye=mat('Amber iris','bfaa68',0,.5);sole=mat('Boot sole','14191b')
glow=mat('Lantern pale ember','badbc3',.0,.35,3.0)

def finish(obj,name,material,bone='chest',smooth=False):
    obj.name=name
    if material:obj.data.materials.append(material)
    if obj.type=='MESH':
        for f in obj.data.polygons:f.use_smooth=smooth
        if bone:
            obj.vertex_groups.new(name=bone).add(list(range(len(obj.data.vertices))),1,'REPLACE')
        parts.append(obj)
    return obj
def mesh(name,verts,faces,material,bone='chest'):
    m=bpy.data.meshes.new(name);m.from_pydata(verts,[],faces);m.update()
    ob=bpy.data.objects.new(name,m);bpy.context.collection.objects.link(ob)
    return finish(ob,name,material,bone)
def ball(name,center,scale,material,bone,segments=12,rings=8):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,location=center)
    ob=bpy.context.object;ob.scale=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(ob,name,material,bone)
def tube(name,a,b,r1,r2,material,bone,n=10):
    a,b=Vector(a),Vector(b);d=b-a
    bpy.ops.mesh.primitive_cone_add(vertices=n,radius1=r1,radius2=r2,depth=d.length,location=(a+b)/2)
    ob=bpy.context.object;ob.rotation_mode='QUATERNION';ob.rotation_quaternion=d.to_track_quat('Z','Y')
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(ob,name,material,bone)
def line(name,points,r,material,bone='chest',closed=False):
    cu=bpy.data.curves.new(name,'CURVE');cu.dimensions='3D';cu.resolution_u=1;cu.bevel_depth=r;cu.bevel_resolution=0;cu.resolution_u=1
    sp=cu.splines.new('POLY');sp.points.add(len(points)-1)
    for p,v in zip(sp.points,points):p.co=(*v,1)
    sp.use_cyclic_u=closed
    ob=bpy.data.objects.new(name,cu);bpy.context.collection.objects.link(ob)
    bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob
    bpy.ops.object.convert(target='MESH')
    return finish(bpy.context.object,name,material,bone)
def rings(name,levels,material,bone,n=12,start=0,end=2*pi,caps=True):
    closed=abs(end-start-2*pi)<.01;count=n if closed else n+1
    vs=[]
    for z,rx,ry,cy in levels:
        for j in range(count):
            t=start+(end-start)*j/n;vs.append((sin(t)*rx,cy-cos(t)*ry,z))
    fs=[]
    for row in range(len(levels)-1):
        for j in range(n):
            k=(j+1)%count;fs.append((row*count+j,row*count+k,(row+1)*count+k,(row+1)*count+j))
    if caps and closed:fs.extend([tuple(range(count-1,-1,-1)),tuple((len(levels)-1)*count+j for j in range(count))])
    return mesh(name,vs,fs,material,bone)

# Anatomy: heel to scalp 3.30; chin to crown 0.60 (5.5 heads).
rings('Fitted waistcoat',[(1.55,.31,.20,0),(1.82,.28,.19,0),(2.16,.40,.23,0),(2.43,.43,.21,0),(2.52,.21,.15,0)],coatside,'chest')
rings('Ivory shirt neck',[(2.25,.20,.20,-.015),(2.53,.18,.15,0),(2.63,.115,.11,0)],shirt,'chest')
tube('Neck',(0,0,2.5),(0,0,2.73),.115,.115,skin,'neck',12)
face=rings('Faceted face',[(2.66,.115,.12,-.005),(2.73,.19,.185,-.008),(2.88,.255,.225,0),(3.04,.267,.225,0),(3.18,.235,.195,.015),(3.25,.14,.13,.015)],skin,'head',16)
for poly in face.data.polygons:poly.use_smooth=True
for side in [-1,1]:
    ball('Ear',(side*.262,0,2.925),(.05,.045,.086),skin,'head',10,6)
    x=side*.113
    # Eye sockets and narrow almond-shaped eyes lie proud of the face, never spherical button eyes.
    shape=[(-.08,0),(-.04,.034),(.065,.025),(.081,-.002),(.025,-.018),(-.045,-.016)]
    mesh('Dark eye socket',[(x+a,-.234,2.99+b) for a,b in shape],[tuple(range(6))],ink,'head')
    mesh('Ivory almond',[(x+a*.77,-.239,2.99+b*.65) for a,b in shape],[tuple(range(6))],shirt,'head')
    ball('Iris',(x,-.245,2.995),(.023,.009,.025),eye,'head',10,6)
    ball('Pupil',(x,-.253,2.995),(.009,.006,.016),ink,'head',8,4)
    line('Severe brow',[(x-side*.075,-.235,3.066),(x,-.246,3.083),(x+side*.075,-.21,3.084)],.013,hair,'head')
    line('Cheek engraving',[(side*.21,-.154,2.885),(side*.167,-.205,2.846)],.005,skinshade,'head')
mesh('Angular nose',[(0,-.232,3.036),(-.039,-.232,2.907),(0,-.31,2.907),(.039,-.232,2.907),(0,-.247,2.881)],[(0,1,2),(0,2,3),(1,4,2),(2,4,3)],skin,'head')
line('Mouth', [(-.067,-.187,2.796),(-.01,-.214,2.784),(.052,-.198,2.792)],.006,skinshade,'head')
line('Lower lip', [(-.033,-.20,2.773),(.031,-.20,2.776)],.004,shirt,'head')

# Swept carved hair, built as broad locks rather than fine strands.
vs=[];fs=[];N=16
for row in range(4):
    for j in range(N):
        t=2*pi*j/N
        z=[2.94+.09*cos(t),3.17,3.28,3.29][row]
        rx=[.274,.27,.18,.03][row];ry=[.225,.233,.17,.03][row]
        vs.append((sin(t)*rx, .026-cos(t)*ry,z))
for row in range(3):
    for j in range(N):fs.append((row*N+j,row*N+(j+1)%N,(row+1)*N+(j+1)%N,(row+1)*N+j))
fs.append(tuple(3*N+j for j in range(N)))
mesh('Hair crown',vs,fs,hair,'head')
def lock(name,points,width,material):
    vertices=[]
    for i,p in enumerate(points):
        w=width*(1-i/(len(points)-1));p=Vector(p)
        vertices.extend([tuple(p+Vector((-w,0,0))),tuple(p+Vector((0,-w*.38,w*.16))),tuple(p+Vector((w,0,0)))])
    faces=[]
    for i in range(len(points)-1):
        a=i*3;faces.extend([(a,a+3,a+4,a+1),(a+1,a+4,a+5,a+2)])
    ob=mesh(name,vertices,faces,material,'head')
    ob.data.materials.append(hairlit)
    for i,p in enumerate(ob.data.polygons):p.material_index=1 if i%2 else 0
    return ob
for i in range(7):
    x=-.17+i*.054
    lock('Swept fringe %02d'%i,[(x+.11,-.04,3.27+.015*sin(i)),(x+.03,-.218,3.23),(x-.09,-.258,3.095),(x-.14,-.223,2.94+.018*i)],.068,hair)
for side in [-1,1]:
    for i in range(4):
        lock('Temple locks',[(side*.23,.02+i*.047,3.14),(side*.29,.015+i*.055,2.99),(side*(.24+.04*(i%2)),.035+i*.058,2.855)],.052,hair)
lock('Silver streak',[(.13,-.11,3.28),(.065,-.25,3.20),(-.008,-.266,3.10)],.022,streak)

# Legs, fitted trousers, tall practical boots. Face is -Y; bind pose has relaxed low arms.
for side,suffix in [(-1,'L'),(1,'R')]:
    x=side*.205
    ball('Hip cloth',(x,0,1.51),(.195,.18,.24),coatside,'pelvis')
    tube('Trouser thigh',(x,0,1.56),(x,-.005,.91),.185,.13,coatside,'thigh.'+suffix,10)
    ball('Knee',(x,-.005,.91),(.134,.132,.145),coatside,'shin.'+suffix,10,6)
    tube('Shin boot',(x,-.005,.91),(x,0,.27),.14,.105,leather,'shin.'+suffix,10)
    tube('Boot cuff',(x,0,.83),(x,0,.94),.157,.158,ink,'shin.'+suffix,10)
    ball('Boot',(x,-.105,.18),(.145,.29,.17),leather,'foot.'+suffix,12,6)
    ball('Thick sole',(x,-.11,.065),(.15,.305,.064),sole,'foot.'+suffix,12,4)
    for z in [.38,.58,.76]:line('Boot seam',[(x-.085,-.105,z),(x,-.132,z-.022),(x+.085,-.105,z)],.009,brass,'shin.'+suffix)
    shoulder=(side*.44,0,2.40);elbow=(side*.61,-.008,1.99);wrist=(side*.70,-.04,1.61)
    ball('Shoulder',shoulder,(.17,.17,.16),coat,'upper_arm.'+suffix,10,6)
    tube('Upper sleeve',shoulder,elbow,.177,.135,coat,'upper_arm.'+suffix,10)
    ball('Sleeve elbow',elbow,(.137,.145,.15),coat,'forearm.'+suffix,10,6)
    tube('Lower sleeve',elbow,wrist,.14,.097,coat,'forearm.'+suffix,10)
    tube('Leather cuff',(side*.683,-.038,1.70),(side*.703,-.04,1.58),.11,.112,leather,'forearm.'+suffix,10)
    ball('Gloved palm',(side*.715,-.045,1.51),(.099,.066,.125),leather,'hand.'+suffix,10,6)
    for finger in range(4):
        fx=side*(.665+finger*.034)
        tube('Finger',(fx,-.065,1.48),(fx,-.083,1.38+(finger%2)*.015),.022,.017,leather,'hand.'+suffix,6)
    tube('Thumb',(side*.65,-.064,1.53),(side*.645,-.14,1.445),.028,.024,leather,'hand.'+suffix,7)
    ball('Cuff rivet',(side*.71,-.146,1.66),(.019,.012,.019),gold,'forearm.'+suffix,8,4)

# Open coat with individually weighted cloth tails.
body=rings('Open long coat',[(.46,.54,.33,.035),(.83,.47,.30,.03),(1.24,.38,.25,.02),(1.66,.33,.225,.008),(1.88,.32,.226,0),(2.28,.45,.235,0),(2.46,.43,.19,0)],coat,None,20,.48,2*pi-.48,False)
body.data.materials.append(coatlit);body.data.materials.append(coatside);body.data.materials.append(lining)
for f in body.data.polygons:f.material_index=1 if f.index%5==1 else 2 if f.index%7==0 else 0
for v in body.data.vertices:
    x,y,z=v.co;name=('tail.L' if x<0 else 'tail.R') if z<1.65 else 'chest'
    group=body.vertex_groups.get(name) or body.vertex_groups.new(name=name);group.add([v.index],1,'REPLACE')
solid=body.modifiers.new('Actual coat thickness','SOLIDIFY');solid.thickness=.016;solid.material_offset=3
for side,suffix in [(-1,'L'),(1,'R')]:
    line('Coat brass piping',[(side*.26,-.28,.47),(side*.22,-.25,.83),(side*.18,-.23,1.24),(side*.16,-.21,1.64)],.009,brass,'tail.'+suffix)
    mesh('High turned collar',[(side*.115,-.14,2.56),(side*.28,-.16,2.63),(side*.35,-.16,2.38),(side*.17,-.244,2.21)],[(0,1,2,3)],coatlit,'chest')
    line('Collar ink edge',[(side*.115,-.15,2.56),(side*.28,-.17,2.63),(side*.35,-.17,2.38)],.009,ink)
    for z in [1.86,2.035,2.21]:ball('Double breasted button',(side*.18,-.231,z),(.028,.013,.028),gold,'chest',8,4)
cape=rings('Shoulder cape',[(2.22,.66,.305,.045),(2.43,.56,.245,.025),(2.57,.23,.16,.018)],coat,'chest',18,.63,2*pi-.63,False)
cape.data.materials.append(coatlit)
for f in cape.data.polygons:f.material_index=1 if f.index%4==0 else 0
cape.modifiers.new('Cape thickness','SOLIDIFY').thickness=.018
line('Cape ink hem',[(sin(.63+(2*pi-1.26)*j/18)*.66,.045-cos(.63+(2*pi-1.26)*j/18)*.307,2.22) for j in range(19)],.012,ink)
mesh('Cravat knot',[(-.05,-.17,2.51),(.05,-.17,2.51),(.04,-.228,2.445),(-.04,-.228,2.445)],[(0,1,2,3)],red)
mesh('Cravat tails',[(-.032,-.238,2.46),(.037,-.238,2.46),(.078,-.252,2.23),(0,-.262,2.17),(-.065,-.252,2.24)],[(0,1,2,3,4)],red)
for z in [1.62,1.69]:line('Waist belt',[(sin(j*2*pi/24)*.347,-cos(j*2*pi/24)*.244,z) for j in range(24)],.025,leather,'pelvis',True)
line('Belt buckle',[(-.078,-.273,1.60),(.078,-.273,1.60),(.078,-.273,1.715),(-.078,-.273,1.715)],.014,gold,'pelvis',True)
mesh('Diagonal leather strap',[(-.32,-.258,2.40),(-.235,-.278,2.42),(.29,-.266,1.72),(.205,-.269,1.70)],[(0,1,2,3)],leather)
line('Strap stitch',[(-.26,-.282,2.40),(.25,-.278,1.73)],.004,brass)
for i in range(11):
    t=i/10;ball('Watch chain link',(.22+.08*t,-.26,1.94-.11*sin(pi*t)),(.014,.01,.021),brass,'chest',6,4)

# Lantern and ritual baton are part of the skin, with dedicated secondary bones.
lx=-.715;ly=-.07
line('Lantern handle',[(lx+.095*cos(j*pi/12),ly,1.345+.11*sin(j*pi/12)) for j in range(25)],.012,brass,'lantern',True)
tube('Lantern crown',(lx,ly,1.23),(lx,ly,1.32),.15,.065,brass,'lantern',8)
tube('Lantern foot',(lx,ly,.89),(lx,ly,.94),.14,.15,brass,'lantern',8)
tube('Ember glass',(lx,ly,.96),(lx,ly,1.22),.083,.089,glow,'lantern',8)
for j in range(8):
    t=j*pi/4;x=lx+cos(t)*.125;y=ly+sin(t)*.125
    tube('Lantern cage',(x,y,.93),(x,y,1.25),.009,.009,brass,'lantern',6)
for z in [.94,1.24]:line('Lantern rim',[(lx+.13*cos(j*2*pi/16),ly+.13*sin(j*2*pi/16),z) for j in range(16)],.015,brass,'lantern',True)
tube('Ritual baton grip',(.713,-.14,1.36),(.713,-.14,1.62),.027,.027,leather,'hand.R',8)
tube('Ritual baton silver',(.713,-.14,1.62),(.713,-.14,2.10),.027,.012,streak,'hand.R',8)
ball('Baton sigil',(.713,-.14,2.10),(.047,.033,.058),brass,'hand.R',8,6)

# Rig with named bones and rigid/cloth groups. No automatic weighting surprises.
bpy.ops.object.select_all(action='DESELECT')
arm=bpy.data.armatures.new('Investigator skeleton');rig=bpy.data.objects.new('Investigator_Rig',arm);bpy.context.collection.objects.link(rig)
bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
def bone(name,head,tail,parent=None):
    b=arm.edit_bones.new(name);b.head=head;b.tail=tail
    b.align_roll(Vector((0,-1 if tail[2]>=head[2] else 1,0)))
    if parent:b.parent=arm.edit_bones[parent]
bone('root',(0,0,0),(0,0,.3))
bone('pelvis',(0,0,1.45),(0,0,1.72),'root');bone('chest',(0,0,1.72),(0,0,2.45),'pelvis')
bone('neck',(0,0,2.45),(0,0,2.69),'chest');bone('head',(0,0,2.69),(0,0,3.27),'neck')
for side,suf in [(-1,'L'),(1,'R')]:
    bone('thigh.'+suf,(side*.205,0,1.5),(side*.205,0,.91),'pelvis')
    bone('shin.'+suf,(side*.205,0,.91),(side*.205,0,.24),'thigh.'+suf)
    bone('foot.'+suf,(side*.205,0,.24),(side*.205,-.29,.14),'shin.'+suf)
    bone('upper_arm.'+suf,(side*.44,0,2.40),(side*.61,-.008,1.99),'chest')
    bone('forearm.'+suf,(side*.61,-.008,1.99),(side*.70,-.04,1.61),'upper_arm.'+suf)
    bone('hand.'+suf,(side*.70,-.04,1.61),(side*.715,-.045,1.39),'forearm.'+suf)
    bone('tail.'+suf,(side*.22,0,1.66),(side*.40,.10,.50),'pelvis')
bone('lantern',(lx,ly,1.44),(lx,ly,1.05),'hand.L')
bpy.ops.object.mode_set(mode='OBJECT')
for ob in parts:
    mod=ob.modifiers.new('Skin','ARMATURE');mod.object=rig;ob.parent=rig

# Join compatible mesh pieces to a single skinned body, applying only static thickness.
bpy.ops.object.select_all(action='DESELECT')
for ob in parts:
    bpy.context.view_layer.objects.active=ob
    for mod in list(ob.modifiers):
        if mod.type!='ARMATURE':bpy.ops.object.modifier_apply(modifier=mod.name)
    ob.select_set(True)
bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();body=bpy.context.object;body.name='Investigator_SkinnedMesh'
for b in rig.pose.bones:b.rotation_mode='XYZ'
rig.animation_data_create()
def reset_pose():
    for b in rig.pose.bones:b.location=(0,0,0);b.rotation_euler=(0,0,0);b.scale=(1,1,1)
def rot(name,x=0,y=0,z=0):rig.pose.bones[name].rotation_euler=(x,y,z)
clips={'Idle':72,'Walk':32,'Run':24,'Attack':36,'Hit':24,'Defeat':60}
foot_vertices={}
skin_vertices={}
for group in body.vertex_groups:
    if group.name in arm.bones:
        skin_vertices[group.name]=[v.co.copy() for v in body.data.vertices if any(g.group==group.index and g.weight>.9 for g in v.groups)]
for suf in ['L','R']:
    group=body.vertex_groups['foot.'+suf].index
    foot_vertices[suf]=[v.co.copy() for v in body.data.vertices if any(g.group==group and g.weight>.9 for g in v.groups)]
for name,length in clips.items():
    action=bpy.data.actions.new(name);rig.animation_data.action=action
    for f in range(1,length+2):
        reset_pose();t=(f-1)/length;p=t*2*pi
        if name=='Idle':
            rig.pose.bones['pelvis'].location.y=.013*sin(p)
            rot('chest',.018*sin(p),0,.022*sin(p));rot('head',0,.035*sin(p),.04*sin(p))
            rot('forearm.L',-.10+.025*sin(p));rot('forearm.R',-.12)
            rot('lantern',.06*sin(p-.5),0,.035*sin(p));rot('tail.L',.025*sin(p));rot('tail.R',-.025*sin(p))
        elif name in ('Walk','Run'):
            amp=.40 if name=='Walk' else .66
            rig.pose.bones['pelvis'].location.y=.025*(1-cos(2*p))
            rot('chest',.04 if name=='Walk' else .15,0,.05*sin(p))
            for side,suf in [(-1,'L'),(1,'R')]:
                s=sin(p+(pi if side>0 else 0))
                rot('thigh.'+suf,-amp*s);rot('shin.'+suf,max(0,s)*amp*1.45)
                rot('foot.'+suf,-max(0,s)*.25)
                rot('upper_arm.'+suf,.20*s if suf=='L' else .32*s)
                rot('forearm.'+suf,-.16 if name=='Walk' else -.65)
                rot('tail.'+suf,.12*s-.08,0,side*.035)
            rot('lantern',.16*sin(p-.7),.07*cos(p),.05*sin(p))
        elif name=='Attack':
            wind=max(0,1-abs(t-.20)/.20);strike=max(0,1-abs(t-.46)/.20)
            rot('chest',-.10*wind+.22*strike,-.25*wind+.32*strike,0)
            rot('upper_arm.R',-.65*wind-1.65*strike,0,-.35*wind+.15*strike)
            rot('forearm.R',-.8*wind-.10*strike);rot('upper_arm.L',.20*strike);rot('forearm.L',-.18)
            rig.pose.bones['pelvis'].location.z=.18*strike
            rot('thigh.L',-.25*strike);rot('shin.R',.2*strike);rot('head',-.06*strike,-.16*strike,0)
            rot('tail.L',-.20*strike);rot('tail.R',-.16*strike);rot('lantern',.26*strike)
        elif name=='Hit':
            w=max(0,sin(min(t/.7,1)*pi))*math.exp(-t)
            rot('chest',-.26*w,0,.10*w);rot('head',-.18*w)
            rot('upper_arm.L',.28*w);rot('upper_arm.R',.3*w);rot('lantern',.4*w)
        elif name=='Defeat':
            w=min(1,t/.68);w=w*w*(3-2*w)
            rot('root',1.35*w)
            rig.pose.bones['pelvis'].location.y=-.72*w
            rot('thigh.L',-1.05*w);rot('shin.L',1.75*w);rot('thigh.R',-.5*w);rot('shin.R',1.15*w)
            rot('chest',.57*w);rot('head',.30*w);rot('upper_arm.L',.28*w);rot('upper_arm.R',.4*w)
            rot('tail.L',-.5*w);rot('tail.R',-.35*w)
        # Keep the supporting boot on the floor in every clip, including export.
        bpy.context.view_layer.update()
        lowest=10.0
        contacts=skin_vertices if name=='Defeat' else {'foot.'+s:vs for s,vs in foot_vertices.items()}
        for bname,vertices in contacts.items():
            if not vertices:continue
            deform=rig.pose.bones[bname].matrix @ arm.bones[bname].matrix_local.inverted()
            lowest=min(lowest,min((deform@v).z for v in vertices))
        rig.pose.bones['root'].location.y-=lowest
        for b in rig.pose.bones:
            b.keyframe_insert('rotation_euler',frame=f,group=b.name);b.keyframe_insert('location',frame=f,group=b.name)
    action.use_fake_user=True
    track=rig.animation_data.nla_tracks.new();track.name=name
    strip=track.strips.new(name,1,action);strip.name=name
    track.mute=True
rig.animation_data.action=bpy.data.actions.get('Idle');bpy.context.scene.frame_set(1)

# Presentation stage stays out of the game export.
stage=bpy.data.collections.new('Presentation_only');bpy.context.scene.collection.children.link(stage)
def stage_move(ob):
    for c in list(ob.users_collection):c.objects.unlink(ob)
    stage.objects.link(ob)
bpy.ops.mesh.primitive_cylinder_add(vertices=64,radius=1.65,depth=.13,location=(0,0,-.065));ob=bpy.context.object;ob.name='Slate dais';ob.data.materials.append(mat('Dais','111c24'));stage_move(ob)
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.17));ob=bpy.context.object;ob.data.materials.append(mat('Studio floor','080f15'));stage_move(ob)
def area(name,loc,power,color,size):
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.color=color;data.shape='DISK';data.size=size
    ob=bpy.data.objects.new(name,data);stage.objects.link(ob);ob.location=loc;ob.rotation_euler=(Vector((0,0,1.7))-ob.location).to_track_quat('-Z','Y').to_euler()
area('Large warm key',(3,-4,6),550,(1,.84,.66),4)
area('Cool rim',(-3,2,4),700,(.35,.68,.8),3)
area('Soft face fill',(-2,-4,3),220,(.6,.75,1),3)
camdata=bpy.data.cameras.new('Preview camera');cam=bpy.data.objects.new('Preview camera',camdata);stage.objects.link(cam)
cam.location=(4.3,-7,3.4);cam.rotation_euler=(Vector((0,0,1.65))-cam.location).to_track_quat('-Z','Y').to_euler();camdata.type='ORTHO';camdata.ortho_scale=4.35
scene=bpy.context.scene;scene.camera=cam;scene.render.engine='CYCLES';scene.cycles.samples=32
scene.world.color=(.06,.06,.06);scene.render.resolution_x=900;scene.render.resolution_y=1080;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.film_transparent=False
scene.view_settings.view_transform='AgX';scene.render.fps=24;scene.frame_start=1;scene.frame_end=72
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);body.select_set(True);bpy.context.view_layer.objects.active=rig
rig.show_in_front=True
for screen in bpy.data.screens:
    for a in screen.areas:
        if a.type=='VIEW_3D':
            a.spaces.active.region_3d.view_distance=5.5;a.spaces.active.region_3d.view_location=(0,0,1.65)
            a.spaces.active.shading.type='MATERIAL'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'lantern-investigator.blend'))
rig.animation_data.action=None
for track in rig.animation_data.nla_tracks:track.mute=False
bpy.ops.export_scene.gltf(filepath=str(GAME/'lantern-investigator.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True,export_nla_strips=True,export_lights=False,export_cameras=False)
for track in rig.animation_data.nla_tracks:track.mute=True
rig.animation_data.action=bpy.data.actions.get('Idle');scene.frame_set(1)
stats={'height':3.30,'head_height':.60,'heads':5.5,'vertices':len(body.data.vertices),'triangles':sum(len(p.vertices)-2 for p in body.data.polygons),'bones':len(arm.bones),'clips':clips,'fps':24,'source':'Original meshes authored procedurally through Blender MCP; no external model service.'}
(OUT/'manifest.json').write_text(json.dumps(stats,indent=2),encoding='utf-8')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'lantern-investigator.blend'))
print('CHARACTER_BUILD_COMPLETE '+json.dumps(stats))

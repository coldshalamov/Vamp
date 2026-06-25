#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, math, random
from pathlib import Path
from typing import Sequence
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
import visual_asset_core as b

# Eight authored directions avoid mirrored weapons and inverted normal-map lobes.
b.ATLAS_COLS = 8
b.DIRECTION_ANGLES = [i * math.pi / 4.0 for i in range(8)]  # E, SE, S, SW, W, NW, N, NE


def _perp(a, c):
    dx, dy = c[0]-a[0], c[1]-a[1]
    ll=max(1e-6, math.hypot(dx,dy))
    return (-dy/ll, dx/ll)

def _offset(p,n,d): return (p[0]+n[0]*d,p[1]+n[1]*d)

def tapered_segment(a, c, wa, wc, fill, outline, *, highlight=None, opacity=1.0):
    n=_perp(a,c)
    outer=[_offset(a,n,(wa+2.2)/2),_offset(c,n,(wc+2.0)/2),_offset(c,n,-(wc+2.0)/2),_offset(a,n,-(wa+2.2)/2)]
    inner=[_offset(a,n,wa/2),_offset(c,n,wc/2),_offset(c,n,-wc/2),_offset(a,n,-wa/2)]
    out=[b.polygon(outer,outline,opacity=opacity),b.polygon(inner,fill,opacity=opacity)]
    if highlight:
        hi=[_offset(a,n,wa*0.26),_offset(c,n,wc*0.26),_offset(c,n,wc*0.05),_offset(a,n,wa*0.05)]
        out.append(b.polygon(hi,highlight,opacity=opacity*0.46))
    return out

def joint(p, rx, ry, fill, outline, highlight=None, opacity=1):
    out=[b.ellipse(p[0],p[1],rx+1.0,ry+1.0,outline,opacity=opacity), b.ellipse(p[0],p[1],rx,ry,fill,opacity=opacity)]
    if highlight:
        out.append(b.ellipse(p[0]-rx*0.18,p[1]-ry*0.18,rx*0.38,ry*0.28,highlight,opacity=opacity*0.42))
    return out

def boot(ankle, toe, width, fill, outline, highlight=None, opacity=1):
    n=_perp(ankle,toe); d=(toe[0]-ankle[0],toe[1]-ankle[1]); ll=max(1e-6,math.hypot(*d)); u=(d[0]/ll,d[1]/ll)
    back=(ankle[0]-u[0]*1.0,ankle[1]-u[1]*1.0)
    front=(toe[0]+u[0]*2.0,toe[1]+u[1]*2.0)
    outer=[_offset(back,n,(width+2)/2),_offset(front,n,(width*0.72+1.4)/2),_offset(front,n,-(width*0.72+1.4)/2),_offset(back,n,-(width+2)/2)]
    inner=[_offset(back,n,width/2),_offset(front,n,width*0.72/2),_offset(front,n,-width*0.72/2),_offset(back,n,-width/2)]
    out=[b.polygon(outer,outline,opacity=opacity), b.polygon(inner,fill,opacity=opacity)]
    if highlight: out.append(b.line(_offset(back,n,width*0.25),_offset(front,n,width*0.17),highlight,max(0.7,width*0.12),opacity=opacity*0.55))
    return out

def arm_chain(sh, el, hand, p, near, opacity=1):
    out=[]; fill=f"url(#{p.name}_{'coat' if near else 'coat_side'})"; hi=p.rim if near else b.shade(p.rim,-0.13)
    out+=tapered_segment(sh,el,8.0*p.build,6.5*p.build,fill,'#05070b',highlight=hi,opacity=opacity)
    out+=joint(el,3.4*p.build,3.0*p.build,b.shade(p.coat,-0.01) if near else b.shade(p.coat_dark,0.02),'#05070b',hi,opacity)
    out+=tapered_segment(el,hand,6.6*p.build,4.8*p.build,b.shade(p.coat,0.015) if near else b.shade(p.coat_dark,0.02),'#05070b',highlight=hi,opacity=opacity)
    out+=joint(hand,2.7,2.45,f"url(#{p.name}_skin)",'#05070b',b.shade(p.skin,0.12),opacity)
    return out

def leg_chain(hip,knee,ankle,toe,p,near,opacity=1):
    out=[]; hi=p.rim if near else b.shade(p.rim,-0.16)
    fill=f"url(#{p.name}_pants)" if near else b.shade(p.pants,-0.015)
    out+=tapered_segment(hip,knee,10.2*p.build,8.1*p.build,fill,'#05070b',highlight=hi,opacity=opacity)
    out+=joint(knee,4.2*p.build,3.25*p.build,b.shade(p.pants,-0.015),'#05070b',hi,opacity)
    out+=tapered_segment(knee,ankle,8.0*p.build,6.4*p.build,b.shade(p.pants,0.01 if near else -0.02),'#05070b',highlight=hi,opacity=opacity)
    out+=boot(ankle,toe,7.8,'#080b10','#05070b','#637186' if near else '#323b48',opacity)
    return out

def draw_grounded(p, pose, front, side):
    corpse=pose['corpse']>0.5; cx,cy=48,94
    out=[f'<g transform="rotate({-8 if side>=0 else 8} {cx} {cy})">',b.ellipse(cx,cy+12,31,7,'#000',opacity=.38)]
    # Broad torso and coat, bent limbs, tucked head.
    torso=[(cx-18,cy-8),(cx+12,cy-11),(cx+21,cy-1),(cx+14,cy+9),(cx-15,cy+11),(cx-24,cy+2)]
    out.append(b.polygon(torso,'#05070b'))
    out.append(b.polygon([(cx-16,cy-6),(cx+10,cy-8),(cx+17,cy-1),(cx+11,cy+6),(cx-13,cy+8),(cx-20,cy+2)],f'url(#{p.name}_coat)'))
    out+=tapered_segment((cx-10,cy+5),(cx-25,cy+16),9,7,f'url(#{p.name}_pants)','#05070b',highlight=p.rim)
    out+=boot((cx-25,cy+16),(cx-32,cy+19),8,'#080b10','#05070b')
    out+=tapered_segment((cx+3,cy+6),(cx+22,cy+15),9,7,b.shade(p.pants,-.01),'#05070b')
    out+=boot((cx+22,cy+15),(cx+31,cy+17),8,'#080b10','#05070b')
    out+=tapered_segment((cx-7,cy-6),(cx-24,cy-13),7,5,b.shade(p.coat_dark,.02),'#05070b')
    out+=tapered_segment((cx+8,cy-7),(cx+21,cy-15),7,5,f'url(#{p.name}_coat)','#05070b',highlight=p.rim)
    out.append(b.ellipse(cx+22,cy-9,6.5,7.1,f'url(#{p.name}_face)',stroke='#05070b',sw=1.5))
    if p.hooded: out.append(b.path(f'M {cx+16},{cy-13} Q {cx+22},{cy-20} {cx+29},{cy-12} L {cx+28},{cy-5} Q {cx+22},{cy-1} {cx+16},{cy-6} Z',fill=f'url(#{p.name}_cloth)',stroke='#05070b',sw=1.2))
    if corpse:
        out.append(b.path(f'M {cx+8},{cy+5} C {cx+14},{cy+11} {cx+23},{cy+12} {cx+32},{cy+16}',stroke='#81101f',sw=4,opacity=.72))
        out.append(b.ellipse(cx+33,cy+17,10,3.8,'#4d0710',opacity=.48))
    out.append('</g>'); return ''.join(out)

def draw_character(p, angle, row, seed):
    pose=b._pose_for_row(row); front=math.sin(angle); side=math.cos(angle)
    if pose['down'] or pose['corpse']: return draw_grounded(p,pose,front,side)
    rng=random.Random(seed); outline='#05070b'; cx=48
    # Broad 7-head silhouette with foreshortened, heavy limbs. A character should read as mass, not wire.
    view_w=.70+.30*abs(front); profile_v=1-view_w
    gait=math.sin(pose['phase'])*pose['walk']; gc=math.cos(pose['phase'])*pose['walk']
    bob=abs(gc)*1.0 + math.sin(pose['phase'])*(.45 if pose['walk']==0 else .12)
    attack=pose['attack']; hit=pose['hit']; feed=pose['feed']
    crouch=(3.2 if attack==1 else 0)+(5.4*feed)
    lunge=(side*(5.0 if attack==2 else 2.0 if attack==3 else -2.2 if attack==1 else 0), front*(2.0 if attack in (2,3) else 0))
    pelvis=(cx+lunge[0]*.24-hit*side*2.2,78+bob+crouch)
    chest=(cx+side*1.2+lunge[0],53+bob+crouch*.48+lunge[1])
    neck=(chest[0]+side*.5,chest[1]-4.4)
    head=(neck[0]+side*(1.4+profile_v),neck[1]-7.4)
    sh_half=(12.0*p.build)*view_w+4.2*profile_v
    hip_half=(7.4*p.build)*view_w+2.8*profile_v
    sh_l=(chest[0]-sh_half,chest[1]+1.0); sh_r=(chest[0]+sh_half,chest[1]-.6)
    hip_l=(pelvis[0]-hip_half,pelvis[1]); hip_r=(pelvis[0]+hip_half,pelvis[1])
    stride_x=side*gait*6.0; stride_y=front*gait*4.0
    ankle_l=(cx-5.6*view_w+stride_x,108+stride_y-max(0,gc)*2.4)
    ankle_r=(cx+5.6*view_w-stride_x,108-stride_y-max(0,-gc)*2.4)
    knee_l=((hip_l[0]+ankle_l[0])*.5-side*1.1,(hip_l[1]+ankle_l[1])*.5-1.0)
    knee_r=((hip_r[0]+ankle_r[0])*.5+side*1.1,(hip_r[1]+ankle_r[1])*.5-1.0)
    toe_l=(ankle_l[0]+side*6.0,ankle_l[1]+front*1.6); toe_r=(ankle_r[0]+side*6.0,ankle_r[1]+front*1.6)
    arm_swing=-gait*5.8
    hand_l=(sh_l[0]-2.0+side*arm_swing,sh_l[1]+20.5)
    hand_r=(sh_r[0]+2.0-side*arm_swing,sh_r[1]+20.5)
    if attack:
        reach={1.0:-4,2.0:23,3.0:15,4.0:5}[attack]; fx=side*(.84 if abs(side)>.2 else .45); fy=front*.34
        hand_r=(sh_r[0]+fx*reach+side*3,sh_r[1]+11+fy*reach)
        hand_l=(sh_l[0]+fx*max(0,reach-5),sh_l[1]+13+fy*max(0,reach-5))
    if hit:
        hand_l=(sh_l[0]-side*7,sh_l[1]+8); hand_r=(sh_r[0]+side*7,sh_r[1]+10); head=(head[0]-side*4,head[1]+1.5)
    if feed:
        hand_l=(chest[0]-10,chest[1]+12); hand_r=(chest[0]+11,chest[1]+10); head=(head[0]+side*4,head[1]+5)
    el_l=((sh_l[0]+hand_l[0])*.5-2.8,(sh_l[1]+hand_l[1])*.5+1); el_r=((sh_r[0]+hand_r[0])*.5+2.8,(sh_r[1]+hand_r[1])*.5+1)
    near_r=side>=0; farleg=(hip_l,knee_l,ankle_l,toe_l) if near_r else (hip_r,knee_r,ankle_r,toe_r); nearleg=(hip_r,knee_r,ankle_r,toe_r) if near_r else (hip_l,knee_l,ankle_l,toe_l)
    fararm=(sh_l,el_l,hand_l) if near_r else (sh_r,el_r,hand_r); neararm=(sh_r,el_r,hand_r) if near_r else (sh_l,el_l,hand_l)
    out=[]
    # Baked contact shadow.
    out.append(b.ellipse(cx,111,20+4*p.build,5.5,'#000000',opacity=.40,rotate=side*2))
    out += leg_chain(*farleg,p,False,.92); out += arm_chain(*fararm,p,False,.93)
    # Coat skirts sit behind torso and bridge the leg gap.
    skirt_y=95 if p.long_coat else 86
    coat_skirt=[(pelvis[0]-hip_half-2,pelvis[1]-1),(pelvis[0]+hip_half+2,pelvis[1]-1),(pelvis[0]+hip_half+3-side*abs(gait)*2,skirt_y),(pelvis[0]+1,skirt_y-4),(pelvis[0]-hip_half-4-side*abs(gait)*1.5,skirt_y+1)]
    out.append(b.polygon(coat_skirt,outline))
    inner=[(coat_skirt[0][0]+1.3,coat_skirt[0][1]+1),(coat_skirt[1][0]-1.3,coat_skirt[1][1]+1),(coat_skirt[2][0]-1.2,coat_skirt[2][1]-1),(coat_skirt[3][0],coat_skirt[3][1]-1),(coat_skirt[4][0]+1.2,coat_skirt[4][1]-1)]
    out.append(b.polygon(inner,f'url(#{p.name}_coat_side)'))
    if p.long_coat:
        out.append(b.path(f'M {pelvis[0]},{pelvis[1]+1} Q {pelvis[0]+side*2},{skirt_y-8} {pelvis[0]+1},{skirt_y-3}',stroke=p.accent if p.name=='hero' else b.shade(p.coat,.12),sw=1.3,opacity=.65))
    # Muscular/armored torso: wide clavicles, ribcage, cinched waist. Rounded path avoids cardboard trapezoid.
    sx0=chest[0]-sh_half; sx1=chest[0]+sh_half; wx0=pelvis[0]-hip_half-1; wx1=pelvis[0]+hip_half+1
    d=f'M {sx0:.2f},{chest[1]-3:.2f} Q {chest[0]:.2f},{chest[1]-7:.2f} {sx1:.2f},{chest[1]-3:.2f} Q {sx1+2:.2f},{chest[1]+8:.2f} {wx1:.2f},{pelvis[1]+1:.2f} L {wx0:.2f},{pelvis[1]+1:.2f} Q {sx0-2:.2f},{chest[1]+8:.2f} {sx0:.2f},{chest[1]-3:.2f} Z'
    out.append(b.path(d,fill=outline))
    ix0=sx0+1.5; ix1=sx1-1.5; iw0=wx0+1.3; iw1=wx1-1.3
    d2=f'M {ix0:.2f},{chest[1]-1.6:.2f} Q {chest[0]:.2f},{chest[1]-5.0:.2f} {ix1:.2f},{chest[1]-1.6:.2f} Q {ix1+1:.2f},{chest[1]+8:.2f} {iw1:.2f},{pelvis[1]-0.8:.2f} L {iw0:.2f},{pelvis[1]-0.8:.2f} Q {ix0-1:.2f},{chest[1]+8:.2f} {ix0:.2f},{chest[1]-1.6:.2f} Z'
    out.append(b.path(d2,fill=f'url(#{p.name}_coat)'))
    # broad shadow/light sculpting
    out.append(b.path(f'M {chest[0]},{chest[1]-4} Q {sx1-2},{chest[1]+2} {wx1-1},{pelvis[1]-1} L {pelvis[0]+1},{pelvis[1]-1} Z',fill=b.shade(p.coat_dark,.015),opacity=.72))
    out.append(b.path(f'M {ix0},{chest[1]-1} Q {chest[0]-1},{chest[1]+3} {pelvis[0]-1},{pelvis[1]-1} L {iw0},{pelvis[1]-1} Z',fill=b.shade(p.coat,.09),opacity=.42))
    # lapels and garment structure
    out.append(b.path(f'M {neck[0]},{neck[1]+2} L {chest[0]-5},{chest[1]+11} L {chest[0]-1},{chest[1]+14}',stroke=b.shade(p.coat,.17),sw=1.6,opacity=.82))
    out.append(b.path(f'M {neck[0]},{neck[1]+2} L {chest[0]+5},{chest[1]+11} L {chest[0]+1},{chest[1]+14}',stroke=p.accent,sw=1.35,opacity=.76))
    out.append(b.line((wx0+1,pelvis[1]-2),(wx1-1,pelvis[1]-2),'#08090c',2.5)); out.append(b.line((wx0+2,pelvis[1]-2),(wx1-2,pelvis[1]-2),b.shade(p.leather,.12),.9))
    if p.armored:
        plate=[(chest[0]-8*view_w,chest[1]+4),(chest[0]+8*view_w,chest[1]+3.5),(pelvis[0]+5.4*view_w,pelvis[1]-5),(pelvis[0]-5.4*view_w,pelvis[1]-4.5)]
        out.append(b.polygon(plate,outline)); ins=[(chest[0]+(x-chest[0])*.83,chest[1]+8+(y-(chest[1]+8))*.83) for x,y in plate]; out.append(b.polygon(ins,f'url(#{p.name}_metal)',opacity=.82))
        out.append(b.path(f'M {plate[0][0]+2},{plate[0][1]+2} Q {chest[0]},{chest[1]+1} {plate[1][0]-2},{plate[1][1]+2}',stroke=p.rim,sw=1.1,opacity=.62))
    if p.name=='cop':
        out.append(b.polygon([(chest[0]-2,chest[1]+6),(chest[0]+2,chest[1]+6),(chest[0]+2.4,chest[1]+10),(chest[0],chest[1]+12),(chest[0]-2.4,chest[1]+10)],'#c8a94d',stroke='#4c3b12',sw=.6))
        # shoulder patches, not a billboard badge
        out.append(b.polygon([(sh_l[0]+1,sh_l[1]+2),(sh_l[0]+5,sh_l[1]+2),(sh_l[0]+4,sh_l[1]+5),(sh_l[0]+1,sh_l[1]+5)],p.accent,opacity=.85))
    out += leg_chain(*nearleg,p,True,1); out += arm_chain(*neararm,p,True,1)
    # Tucked neck and head. Larger jaw/hood but no floating lollipop.
    out+=tapered_segment((neck[0],chest[1]-1),(head[0]-side*.4,head[1]+5),5.8,4.8,b.shade(p.skin,-.12),outline,highlight=b.shade(p.skin,.08))
    face_rx=5.4*view_w+2.0*profile_v; face_ry=7.1
    if p.hooded:
        hood=[(head[0]-face_rx-2,head[1]-7.8),(head[0]+face_rx+1.5,head[1]-8.2),(head[0]+face_rx+2.6,head[1]+5.4),(head[0],head[1]+9),(head[0]-face_rx-2.5,head[1]+5)]
        out.append(b.polygon(hood,outline)); inn=[(head[0]+(x-head[0])*.84,head[1]+(y-head[1])*.84) for x,y in hood]; out.append(b.polygon(inn,f'url(#{p.name}_cloth)'))
    if p.helmeted:
        out.append(b.ellipse(head[0],head[1]-2,face_rx+2.1,7.8,outline)); out.append(b.ellipse(head[0]-.4,head[1]-2.4,face_rx+1,6.7,f'url(#{p.name}_metal)'))
        out.append(b.path(f'M {head[0]-face_rx},{head[1]-1} Q {head[0]},{head[1]+1.5} {head[0]+face_rx},{head[1]-1}',stroke='#0a111a',sw=2.6))
    out.append(b.ellipse(head[0]+side*.7,head[1],face_rx,face_ry,f'url(#{p.name}_face)',stroke=outline,sw=1.4,rotate=side*4*profile_v))
    if not p.hooded and not p.helmeted:
        out.append(b.path(f'M {head[0]-face_rx},{head[1]-2.3} Q {head[0]},{head[1]-9} {head[0]+face_rx},{head[1]-2.8} L {head[0]+face_rx*.65},{head[1]-6} Q {head[0]},{head[1]-9.8} {head[0]-face_rx*.75},{head[1]-5.6} Z',fill=p.hair,stroke=outline,sw=.8))
    if p.masked:
        out.append(b.path(f'M {head[0]-face_rx*.9},{head[1]+.2} Q {head[0]},{head[1]+6.8} {head[0]+face_rx*.9},{head[1]} L {head[0]+face_rx*.75},{head[1]+5.5} Q {head[0]},{head[1]+8.3} {head[0]-face_rx*.75},{head[1]+5.5} Z',fill=p.cloth,stroke=outline,sw=.8))
    if front>-.35:
        es=2.2*view_w+.5; ey=head[1]-1.2; ecol=p.accent if p.eyes else '#171417'
        out.append(b.line((head[0]-es-1,ey),(head[0]-es+.8,ey),ecol,1.05)); out.append(b.line((head[0]+es-.8,ey),(head[0]+es+1,ey),ecol,1.05))
        if not p.masked:
            out.append(b.path(f'M {head[0]-1},{head[1]+1} L {head[0]+side*.5},{head[1]+3}',stroke=b.shade(p.skin,-.2),sw=.65,opacity=.7))
            out.append(b.line((head[0]-1.8,head[1]+4.5),(head[0]+2,head[1]+4.4),b.shade(p.skin,-.28),.7,opacity=.65))
    # Weapons as broad, physically grounded props.
    weapon_hand=hand_r; fx=side if abs(side)>.24 else .38; fy=front*.44; ll=max(.1,math.hypot(fx,fy)); fx/=ll; fy/=ll
    if p.weapon=='bat':
        length=27+(5 if attack==2 else 0); tip=(weapon_hand[0]+fx*length,weapon_hand[1]+fy*length)
        out.append(b.line(weapon_hand,tip,outline,6.0,cap='square')); out.append(b.line((weapon_hand[0]+fx*1.5,weapon_hand[1]+fy*1.5),tip,'#493728',3.6,cap='square')); out.append(b.line((tip[0]-fx*5,tip[1]-fy*5),tip,b.shade(p.metal,.08),1.4,cap='square'))
    elif p.weapon=='pistol':
        muzzle=(weapon_hand[0]+fx*10,weapon_hand[1]+fy*10); back=(weapon_hand[0]-fx*2,weapon_hand[1]-fy*2)
        out.append(b.line(back,muzzle,outline,5.0,cap='square')); out.append(b.line(weapon_hand,muzzle,b.shade(p.metal,-.12),2.5,cap='square'))
        grip=(weapon_hand[0]-fy*4.5-fx*.5,weapon_hand[1]+fx*4.5-fy*.5); out.append(b.line(weapon_hand,grip,outline,4,cap='square')); out.append(b.line(weapon_hand,grip,'#20242b',2.1,cap='square'))
        if attack==2: out.append(b.polygon([(muzzle[0],muzzle[1]),(muzzle[0]+fx*8-fy*3,muzzle[1]+fy*8+fx*3),(muzzle[0]+fx*12,muzzle[1]+fy*12),(muzzle[0]+fx*8+fy*3,muzzle[1]+fy*8-fx*3)],'#ffd78c',opacity=.9))
    elif p.weapon=='rifle':
        length=30+(5 if attack==2 else 0); back=(weapon_hand[0]-fx*8,weapon_hand[1]-fy*8); tip=(weapon_hand[0]+fx*length,weapon_hand[1]+fy*length)
        out.append(b.line(back,tip,outline,7.0,cap='square')); out.append(b.line((back[0]+fx*1.5,back[1]+fy*1.5),tip,b.shade(p.metal,-.12),3.4,cap='square'))
        out.append(b.line((weapon_hand[0]+fx*5-fy*2.8,weapon_hand[1]+fy*5+fx*2.8),(weapon_hand[0]+fx*15-fy*2.8,weapon_hand[1]+fy*15+fx*2.8),'#454a4c',2.2,cap='square'))
        out.append(b.line(hand_l,(weapon_hand[0]+fx*8,weapon_hand[1]+fy*8),p.accent,1.6,opacity=.75))
    elif p.weapon=='claws':
        reach=10+(10 if attack==2 else 4 if attack==3 else 0)
        for i in (-1,0,1):
            lat=i*1.65; base=(weapon_hand[0]-fy*lat,weapon_hand[1]+fx*lat); tip=(base[0]+fx*reach-fy*lat*.25,base[1]+fy*reach+fx*lat*.25)
            out.append(b.line(base,tip,outline,2)); out.append(b.line((base[0]+fx,base[1]+fy),tip,b.shade(p.metal,.22),.9))
        if attack in (2,3): out.append(b.path(f'M {weapon_hand[0]-side*9},{weapon_hand[1]-10} Q {weapon_hand[0]+side*13},{weapon_hand[1]-17} {weapon_hand[0]+side*29},{weapon_hand[1]+3}',stroke=p.accent,sw=2.8,opacity=.47))
    # Material stitching/scuffs, subtle at atlas scale.
    for _ in range(3):
        xx=chest[0]+rng.uniform(-sh_half*.6,sh_half*.6); yy=rng.uniform(chest[1]+7,pelvis[1]-4)
        out.append(b.line((xx,yy),(xx+rng.uniform(-1,1),yy+rng.uniform(1.8,3.5)),b.shade(p.coat,.16),.55,opacity=.2))
    if feed: out.append(b.path(f'M {head[0]+side},{head[1]+4} C {head[0]+side*3},{head[1]+8} {head[0]+side*3},{head[1]+11} {head[0]+side*4},{head[1]+13}',stroke='#a70f28',sw=1.6,opacity=.85))
    return ''.join(out)

b._draw_character=draw_character
b._draw_grounded=draw_grounded


# ---------------------------------------------------------------------------
# Production roster.  One atlas per materially distinct silhouette; civilians
# share geometry and are tint-varied in the runtime to keep VRAM bounded.
b.PROFILES = [
    b.CharacterProfile(
        "hero", "#1b2029", "#080b11", "#11151d", "#090c11", "#c8bbb0", "#87919e",
        "#a70f28", "#a7bedf", "#261a1a", "claws", 0.98, 1.08, True, True, True, False, False, True,
    ),
    b.CharacterProfile(
        "thug", "#3b3026", "#15100c", "#2a211a", "#17130f", "#a97c5e", "#77716a",
        "#8e2028", "#d2aa83", "#3a281c", "bat", 1.16, 1.02, False, False, False, False, False, False,
        "#241b16",
    ),
    b.CharacterProfile(
        "gunner", "#31272a", "#130d10", "#21191c", "#141014", "#a98268", "#7d7773",
        "#8e2631", "#ca9d92", "#332026", "pistol", 1.03, 1.02, False, False, False, False, False, False,
        "#20191a",
    ),
    b.CharacterProfile(
        "cop", "#1a2940", "#08121f", "#121f31", "#0b111a", "#b79680", "#929daa",
        "#6282b3", "#b4c9e8", "#191d25", "pistol", 1.06, 1.04, False, False, False, True, True, False,
        "#241d1a",
    ),
    b.CharacterProfile(
        "swat", "#141b26", "#05090f", "#0d141e", "#070b11", "#aa9280", "#7b8794",
        "#526f98", "#91aaca", "#11161e", "rifle", 1.19, 1.06, False, False, True, True, True, False,
        "#171719",
    ),
    b.CharacterProfile(
        "hunter", "#27272d", "#0a0a0e", "#17171c", "#0d0d11", "#c7baa7", "#b1aa94",
        "#9b753c", "#d1c9b6", "#2d241a", "rifle", 1.10, 1.10, True, True, True, False, True, False,
    ),
    b.CharacterProfile(
        "elder", "#18171d", "#050507", "#0f0e14", "#07070a", "#d5cec1", "#b8ae96",
        "#ae8543", "#d9ceb2", "#34251a", "rifle", 1.23, 1.16, True, True, True, False, True, False,
        "#d5d0c5",
    ),
    b.CharacterProfile(
        "thrall", "#2b2433", "#0d0912", "#1b1520", "#0c0910", "#b49ead", "#817986",
        "#754082", "#ad9cb9", "#2e202d", "pistol", 0.99, 1.00, True, True, False, False, False, True,
        "#221a22",
    ),
    b.CharacterProfile(
        "civilian", "#3d4854", "#18212a", "#2b3540", "#1d252c", "#c1a18b", "#777d84",
        "#6a7684", "#b4c1ce", "#30251f", "", 0.94, 1.00, False, False, False, False, False, False,
        "#3a2922",
    ),
]


def _generate_character_atlas_clipped(profile: b.CharacterProfile) -> str:
    """Atlas writer with hard per-cell clipping to prevent action-frame bleed."""
    width, height = b.FRAME_W * b.ATLAS_COLS, b.FRAME_H * b.ATLAS_ROWS
    chunks = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<defs>', b._defs(profile), '</defs>',
    ]
    for row in range(b.ATLAS_ROWS):
        for col, angle in enumerate(b.DIRECTION_ANGLES):
            seed = int(hashlib.sha256(f"{profile.name}:{row}:{col}".encode()).hexdigest()[:8], 16)
            chunks.append(
                f'<svg x="{col*b.FRAME_W}" y="{row*b.FRAME_H}" width="{b.FRAME_W}" height="{b.FRAME_H}" '
                f'viewBox="0 0 {b.FRAME_W} {b.FRAME_H}" overflow="hidden">'
            )
            chunks.append(b._draw_character(profile, angle, row, seed))
            chunks.append('</svg>')
    chunks.append('</svg>\n')
    return ''.join(chunks)


b.generate_character_atlas = _generate_character_atlas_clipped


def _rat_frame(angle: float, row: int, seed: int) -> str:
    """Low, four-legged rat silhouette using the same 5x16 atlas contract."""
    pose = b._pose_for_row(row)
    rng = random.Random(seed)
    cx, cy = 48.0, 105.0
    f = (math.cos(angle), math.sin(angle) * 0.46)
    fl = max(1e-6, math.hypot(*f))
    f = (f[0] / fl, f[1] / fl)
    s = (-f[1], f[0])
    walk = pose["walk"]
    phase = pose["phase"]
    attack = pose["attack"]
    hit = pose["hit"]
    down = pose["down"] or pose["corpse"]
    body_len = 28.0 if not down else 31.0
    body_w = 10.5 if not down else 7.0
    bob = abs(math.cos(phase)) * walk * 1.1
    if hit:
        cx -= f[0] * 4.0
        cy -= f[1] * 4.0
    if down:
        f = (1.0, 0.16 if pose["corpse"] else -0.12)
        s = (-f[1], f[0])
    head = (cx + f[0] * (body_len * 0.53), cy + f[1] * (body_len * 0.53) - bob)
    tail_root = (cx - f[0] * (body_len * 0.50), cy - f[1] * (body_len * 0.50))
    out: list[str] = []
    out.append(b.ellipse(cx, cy + 3.0, body_len * 0.72, body_w * 0.58, "#000000", opacity=0.30, rotate=math.degrees(angle) * 0.34))
    # Tail first: a tapered-looking double stroke with a slight deterministic curve.
    bend = (s[0] * (8.0 + rng.uniform(-2.0, 2.0)), s[1] * (8.0 + rng.uniform(-2.0, 2.0)))
    tail_end = (tail_root[0] - f[0] * 31.0 + bend[0], tail_root[1] - f[1] * 31.0 + bend[1])
    control = ((tail_root[0] + tail_end[0]) * 0.5 + bend[0], (tail_root[1] + tail_end[1]) * 0.5 + bend[1])
    out.append(b.path(f"M {tail_root[0]:.2f},{tail_root[1]:.2f} Q {control[0]:.2f},{control[1]:.2f} {tail_end[0]:.2f},{tail_end[1]:.2f}", stroke="#120b0d", sw=3.6, opacity=0.95))
    out.append(b.path(f"M {tail_root[0]:.2f},{tail_root[1]:.2f} Q {control[0]:.2f},{control[1]:.2f} {tail_end[0]:.2f},{tail_end[1]:.2f}", stroke="#7f555a", sw=2.0, opacity=0.92))
    # Broad tapered body as layered ellipses, avoiding the old bead-chain look.
    rot = math.degrees(math.atan2(f[1], f[0]))
    out.append(b.ellipse(cx, cy - bob, body_len * 0.53, body_w * 0.58, "#0a0808", opacity=1.0, rotate=rot))
    out.append(b.ellipse(cx + s[0] * 0.6, cy + s[1] * 0.6 - bob, body_len * 0.48, body_w * 0.50, "#3b3432", opacity=1.0, rotate=rot))
    out.append(b.ellipse(cx - s[0] * 2.4, cy - s[1] * 2.4 - bob, body_len * 0.38, body_w * 0.22, "#675b55", opacity=0.36, rotate=rot))
    # Four visible feet, alternating during locomotion.
    if not down:
        for idx, along in enumerate((-8.0, 7.0)):
            gait = math.sin(phase + idx * math.pi) * walk * 3.0
            for side_sign in (-1.0, 1.0):
                p = (cx + f[0] * along + s[0] * side_sign * 6.5 + f[0] * gait,
                     cy + f[1] * along + s[1] * side_sign * 6.5 + f[1] * gait + 4.0)
                out.append(b.ellipse(p[0], p[1], 3.4, 1.4, "#7f5d5c", stroke="#160c0e", sw=0.8, rotate=rot))
    # Snout, ears, eye and whiskers.
    head_push = 4.0 if attack == 2.0 else 0.0
    head = (head[0] + f[0] * head_push, head[1] + f[1] * head_push)
    out.append(b.ellipse(head[0], head[1], 8.2, 6.4, "#413937", stroke="#0b0808", sw=1.4, rotate=rot))
    snout = (head[0] + f[0] * 7.3, head[1] + f[1] * 7.3)
    out.append(b.ellipse(snout[0], snout[1], 4.6, 3.2, "#8d6767", stroke="#130b0d", sw=1.0, rotate=rot))
    nose = (snout[0] + f[0] * 3.7, snout[1] + f[1] * 3.7)
    out.append(b.ellipse(nose[0], nose[1], 1.8, 1.4, "#1c1014"))
    for sign in (-1.0, 1.0):
        ear = (head[0] - f[0] * 2.0 + s[0] * sign * 5.3, head[1] - f[1] * 2.0 + s[1] * sign * 5.3)
        out.append(b.ellipse(ear[0], ear[1], 3.5, 3.0, "#291d1e", stroke="#0a0708", sw=1.0))
        out.append(b.ellipse(ear[0], ear[1], 2.2, 1.8, "#9b6c72", opacity=0.80))
    eye = (head[0] + f[0] * 2.0 + s[0] * 3.3, head[1] + f[1] * 2.0 + s[1] * 3.3 - 1.0)
    out.append(b.ellipse(eye[0], eye[1], 1.25, 1.15, "#b01528" if attack else "#140b0c"))
    for sign in (-1.0, 1.0):
        for off in (-1.8, 0.0, 1.8):
            a = (snout[0] + s[0] * sign * (2.0 + off * 0.22), snout[1] + s[1] * sign * (2.0 + off * 0.22))
            z = (a[0] + f[0] * 10.0 + s[0] * sign * (4.0 + off), a[1] + f[1] * 10.0 + s[1] * sign * (4.0 + off))
            out.append(b.line(a, z, "#b9aca5", 0.55, opacity=0.54))
    if pose["corpse"]:
        out.append(b.ellipse(cx + 7.0, cy + 8.0, 10.0, 3.5, "#4f0710", opacity=0.48))
    return "".join(out)


def generate_rat_atlas() -> str:
    width, height = b.FRAME_W * b.ATLAS_COLS, b.FRAME_H * b.ATLAS_ROWS
    chunks = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">']
    for row in range(b.ATLAS_ROWS):
        for col, angle in enumerate(b.DIRECTION_ANGLES):
            seed = int(hashlib.sha256(f"rat:{row}:{col}".encode()).hexdigest()[:8], 16)
            chunks.append(f'<svg x="{col*b.FRAME_W}" y="{row*b.FRAME_H}" width="{b.FRAME_W}" height="{b.FRAME_H}" viewBox="0 0 {b.FRAME_W} {b.FRAME_H}" overflow="hidden">')
            chunks.append(_rat_frame(angle, row, seed))
            chunks.append('</svg>')
    chunks.append('</svg>\n')
    return ''.join(chunks)


def generate_blood_decals() -> str:
    """Four deterministic organic blood splats used by BloodRenderer."""
    width, height, frame = 256, 64, 64
    chunks = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">']
    for variant in range(4):
        rng = random.Random(0xB100D + variant * 7919)
        ox = variant * frame
        cx, cy = ox + 32.0, 33.0
        pts = []
        count = 18 + variant * 2
        for i in range(count):
            a = i / count * math.tau
            radius = 19.0 + rng.uniform(-5.0, 6.0)
            radius *= 0.82 + 0.18 * math.sin(a * (3 + variant))
            pts.append((cx + math.cos(a) * radius, cy + math.sin(a) * radius * 0.57))
        chunks.append(b.polygon(pts, "#25030a", opacity=0.88))
        inner = [((x - cx) * 0.75 + cx, (y - cy) * 0.75 + cy) for x, y in pts]
        chunks.append(b.polygon(inner, "#580713", opacity=0.86))
        chunks.append(b.ellipse(cx - 4.5, cy - 3.5, 10.0 + variant, 4.2, "#9c1327", opacity=0.36, rotate=-12 + variant * 7))
        for _ in range(7 + variant):
            a = rng.random() * math.tau
            rr = rng.uniform(21.0, 29.0)
            x, y = cx + math.cos(a) * rr, cy + math.sin(a) * rr * 0.61
            rad = rng.uniform(1.3, 3.4)
            chunks.append(b.ellipse(x, y, rad, rad * rng.uniform(0.55, 0.90), "#42050e", opacity=rng.uniform(0.55, 0.86), rotate=rng.uniform(-30, 30)))
        for _ in range(4):
            x, y = cx + rng.uniform(-11, 8), cy + rng.uniform(-8, 4)
            chunks.append(b.ellipse(x, y, rng.uniform(1.2, 3.4), rng.uniform(0.7, 1.8), "#d13a4e", opacity=rng.uniform(0.18, 0.32), rotate=rng.uniform(-40, 40)))
    chunks.append('</svg>\n')
    return ''.join(chunks)


def main() -> int:
    import json
    parser = argparse.ArgumentParser(description="Generate Vampire City source atlases (deterministic SVG).")
    parser.add_argument("--output", type=Path, default=Path("assets/visual/source"))
    args = parser.parse_args()
    files = b.write_assets(args.output)
    rat = args.output / "characters" / "rat_atlas.svg"
    rat.write_text(generate_rat_atlas(), encoding="utf-8")
    files.append(rat)
    fx_dir = args.output / "fx"
    fx_dir.mkdir(parents=True, exist_ok=True)
    blood = fx_dir / "blood_decals.svg"
    blood.write_text(generate_blood_decals(), encoding="utf-8")
    files.append(blood)
    manifest = args.output / "atlas_manifest.json"
    data = json.loads(manifest.read_text(encoding="utf-8"))
    data.update({
        "version": 3,
        "baseline_y": 112,
        "columns": ["east", "southeast", "south", "southwest", "west", "northwest", "north", "northeast"],
        "direction_runtime_map": {str(i): [i, False] for i in range(8)},
        "archetypes": [p.name for p in b.PROFILES] + ["rat"],
        "vehicle_size": [192, 96],
        "blood_decal_frame_size": [64, 64],
        "generator": "tools/visual/generate_visual_atlas.py",
    })
    manifest.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"Generated {len(files)} source assets in {args.output}")
    for path in files:
        print(f"  {path} ({path.stat().st_size:,} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

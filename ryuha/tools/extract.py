"""Cut the uploaded sprite sheets into transparent, foot-anchored frames."""
import os, json, numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi
import sys
sys.path.insert(0, os.path.dirname(__file__))
from seg import bg_model

UP='/mnt/user-data/uploads/'
OUT=sys.argv[1]  # usage: python3 tools/extract.py <out_dir>  (then copy PNGs to assets/characters)

SHEETS = {
 'nodachi': ('IMG_1202.jpeg', [(0,0,400,64),(85,308,145,335),(380,308,430,335),(645,308,705,335),(895,308,1060,335),(185,538,332,564),(680,538,862,564)], {
   'idle':[(42,66,230,292)], 'walk':[(262,66,456,292),(486,66,686,292),(711,66,915,292),(937,66,1141,292)],
   'jump':[(55,296,245,512)], 'fall':[(310,334,495,520)], 'hurt':[(570,300,780,532)],
   'attack_startup':[(850,292,1135,540)], 'attack_active':[(45,536,485,770)], 'attack_recovery':[(535,536,775,762)]}),
 'katana': ('IMG_1203.jpeg', [(0,0,1168,100),(30,100,1168,123),(10,340,1140,350),(10,540,1140,550),(30,352,95,380),(380,352,435,380),(712,352,772,380),(30,557,1168,579)], {
   'idle':[(36,123,214,332)], 'walk':[(401,123,548,332),(576,123,732,332),(759,123,910,332),(936,123,1076,332)],
   'jump':[(95,352,257,512)], 'fall':[(422,352,580,524)], 'hurt':[(755,352,955,534)],
   'attack_startup':[(40,579,230,754)], 'attack_active':[(340,579,733,758)], 'attack_recovery':[(812,579,1090,762)]}),
 'naginata': ('IMG_1204.jpeg', [(0,0,450,50),(15,50,70,72),(575,50,725,74),(18,296,70,318),(462,296,510,318),(845,296,895,318),(18,522,165,544),(422,522,666,544),(872,522,1030,544)], {
   'idle':[(18,52,282,284)], 'walk':[(296,62,542,284),(503,62,742,284),(706,62,938,284),(905,62,1142,284)],
   'jump':[(46,284,346,500)], 'fall':[(433,300,733,505)], 'hurt':[(796,300,1037,505)],
   'attack_startup':[(16,516,302,746)], 'attack_active':[(262,516,842,768)], 'attack_recovery':[(850,516,1112,753)]}),
 'ronin': ('IMG_1205.jpeg', [(0,0,320,46),(10,48,240,72),(10,110,70,130),(10,255,170,285),(10,445,70,465),(10,605,165,628),(225,388,255,410),(467,388,489,410),(688,388,712,410),(910,388,935,410),(225,565,250,585),(800,563,855,586),(130,738,960,780)], {
   'idle':[(249,38,362,216)], 'walk':[(179,208,312,388),(414,208,543,388),(633,208,765,388),(858,208,988,388)],
   'jump':[(170,425,312,564),(457,386,587,548)], 'fall':[(457,386,587,548)], 'hurt':[(706,390,918,566)],
   'attack_startup':[(133,586,356,738)], 'attack_active':[(413,554,705,738)], 'attack_recovery':[(783,581,952,738)]}),
}
# manual anchor x overrides (sheet px) where the automatic leg-centroid is fooled by VFX
ANCHOR_X = {('nodachi','attack_active',0):190, ('katana','attack_active',0):505, ('naginata','attack_active',0):560,
            ('ronin','attack_active',0):560, ('ronin','hurt',0):835}

def build_mask(a):
    bg=bg_model(a)
    diff=np.abs(a-bg).max(2)
    g=a.mean(2); bgg=bg.mean(2)
    m=ndi.uniform_filter(g,5); m2=ndi.uniform_filter(g*g,5)
    std=np.sqrt(np.maximum(m2-m*m,0))
    core=(diff>16)|((std>7)&(diff>7))
    shadow=(g<bgg)&(std<9)&(diff<40)
    core&=~shadow
    core=ndi.binary_opening(core,iterations=1)
    return core,diff

def main():
    meta={}
    for cid,(fn,excl,anims) in SHEETS.items():
        a=np.asarray(Image.open(UP+fn).convert('RGB')).astype(float)
        core,diff=build_mask(a)
        for (x0,y0,x1,y1) in excl: core[y0:y1,x0:x1]=False
        closed=ndi.binary_closing(core,iterations=4)
        lab,n=ndi.label(ndi.binary_dilation(closed,iterations=4))
        sizes=ndi.sum(np.ones_like(lab),lab,index=np.arange(n+1))
        frames=[]
        for anim,rects in anims.items():
            for i,(x0,y0,x1,y1) in enumerate(rects):
                sub=lab[y0:y1,x0:x1]
                keep=np.zeros_like(sub,bool)
                ids,counts=np.unique(sub[sub>0],return_counts=True)
                for cid2,c in zip(ids,counts):
                    if c/sizes[cid2]>0.55 and c>60: keep|=(sub==cid2)
                m=closed[y0:y1,x0:x1]&keep
                holes=ndi.binary_fill_holes(m)&~m
                hl,hn=ndi.label(holes)
                if hn:
                    hs=ndi.sum(holes,hl,index=np.arange(1,hn+1))
                    m|=np.isin(hl,np.nonzero(hs<500)[0]+1)
                # soft alpha: solid core + ramp at the edges
                d=diff[y0:y1,x0:x1]
                edge=m&~ndi.binary_erosion(m,iterations=2)
                alpha=np.where(m,1.0,0.0)
                alpha[edge]=np.clip((d[edge]-6)/22,0.25,1.0)
                alpha=ndi.gaussian_filter(alpha,0.6)*ndi.binary_dilation(m,iterations=1)
                ys,xs=np.nonzero(m)
                foot=ys.max()
                top=ys.min()
                band=ys>top+(foot-top)*0.62
                ax=float(np.median(xs[band]))
                if (cid,anim,i) in ANCHOR_X: ax=ANCHOR_X[(cid,anim,i)]-x0
                rgba=np.dstack([a[y0:y1,x0:x1],alpha*255]).astype(np.uint8)
                frames.append(dict(anim=anim,i=i,img=rgba,ax=ax,foot=foot,bbox=(xs.min(),ys.min(),xs.max(),ys.max())))
        # common canvas: anchor at bottom-centre
        L=max(f['ax']-f['bbox'][0] for f in frames); R=max(f['bbox'][2]-f['ax'] for f in frames)
        U=max(f['foot']-f['bbox'][1] for f in frames); D=max(f['bbox'][3]-f['foot'] for f in frames)
        half=int(np.ceil(max(L,R)))+4; W=half*2; H=int(U+D)+8; base=int(U)+4
        os.makedirs(f'{OUT}/{cid}',exist_ok=True)
        info={'canvas':[W,H],'foot_y':base,'idle_height':0,'frames':{}}
        for f in frames:
            img=Image.fromarray(f['img'],'RGBA')
            canvas=Image.new('RGBA',(W,H),(0,0,0,0))
            canvas.paste(img,(int(round(half-f['ax'])),int(base-f['foot'])),img)
            name=f"{f['anim']}_{f['i']}.png"; canvas.save(f'{OUT}/{cid}/{name}')
            info['frames'].setdefault(f['anim'],[]).append(name)
            if f['anim']=='idle':
                info['idle_height']=int(f['foot']-f['bbox'][1])
                al=np.asarray(canvas)[...,3]>128; ys,xs=np.nonzero(al); top=ys.min()
                info['head']=[float(np.median(xs[ys<top+45])),int(top)]  # portrait crop anchor
        meta[cid]=info
    json.dump(meta,open(f'{OUT}/frames_meta.json','w'),indent=1)
    print(json.dumps({k:(v['canvas'],v['foot_y'],v['idle_height']) for k,v in meta.items()}))

main()

import sys, numpy as np
from PIL import Image
from scipy import ndimage as ndi

def bg_model(a):
    h,w,_=a.shape
    ys,xs=np.mgrid[0:h:8,0:w:8]
    s=a[0:h:8,0:w:8].reshape(-1,3).astype(float)
    X=np.stack([np.ones(xs.size),xs.ravel()/w,ys.ravel()/h,(xs.ravel()/w)**2,(ys.ravel()/h)**2,(xs.ravel()/w)*(ys.ravel()/h)],1)
    keep=np.ones(len(s),bool)
    for it in range(6):
        coef,_,_,_=np.linalg.lstsq(X[keep],s[keep],rcond=None)
        pred=X@coef
        r=np.abs(s-pred).max(1)
        thr=max(4.0,np.percentile(r[keep],70)*1.5)
        keep=r<thr
    yy,xx=np.mgrid[0:h,0:w]
    XF=np.stack([np.ones(h*w),xx.ravel()/w,yy.ravel()/h,(xx.ravel()/w)**2,(yy.ravel()/h)**2,(xx.ravel()/w)*(yy.ravel()/h)],1)
    return (XF@coef).reshape(h,w,3)

def segment(path):
    a=np.asarray(Image.open(path).convert('RGB')).astype(float)
    bg=bg_model(a)
    diff=np.abs(a-bg).max(2)
    g=a.mean(2)
    m=ndi.uniform_filter(g,5); m2=ndi.uniform_filter(g*g,5)
    std=np.sqrt(np.maximum(m2-m*m,0))
    core=(diff>16)|((std>7)&(diff>7))
    core=ndi.binary_opening(core,iterations=1)
    return a,bg,diff,core

if __name__=='__main__':
    a,bg,diff,core=segment(sys.argv[1])
    lab,n=ndi.label(ndi.binary_dilation(core,iterations=7))
    objs=ndi.find_objects(lab)
    for i,sl in enumerate(objs):
        area=(lab[sl]==i+1).sum()
        if area<2500: continue
        print(i+1, 'x',sl[1].start,sl[1].stop,'y',sl[0].start,sl[0].stop,'area',area)
    Image.fromarray((core*255).astype(np.uint8)).save(sys.argv[2])

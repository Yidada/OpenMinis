# Lychee app icon source.
# Run: python3 gen.py  -> light.svg, dark.svg, tinted.svg (1024x1024).
# Render each SVG to a 1024x1024 RGB PNG (no alpha), then copy:
#   light  -> src/ios/Assets.xcassets/AppIcon.appiconset/Icon-1024.png and src/ios/Resources/AlternateIcons/AppIcon-Light.png
#   dark   -> .../Icon-1024-Dark.png and src/ios/Resources/AlternateIcons/AppIcon-Dark.png
#   tinted -> .../Icon-1024-Tinted.png
import math
def lychee_shape(cx,cy,r):
    # round with a soft point at the bottom
    return (f"M{cx},{cy-r} C{cx+r*0.56},{cy-r} {cx+r},{cy-r*0.6} {cx+r},{cy-r*0.02} "
            f"C{cx+r},{cy+r*0.55} {cx+r*0.45},{cy+r*0.92} {cx},{cy+r*1.08} "
            f"C{cx-r*0.45},{cy+r*0.92} {cx-r},{cy+r*0.55} {cx-r},{cy-r*0.02} "
            f"C{cx-r},{cy-r*0.6} {cx-r*0.56},{cy-r} {cx},{cy-r} Z")
def hexes(cx,cy,r,c,ch,step=50,hr=21):
    out=[]
    for row in range(-8,9):
        for col in range(-8,9):
            x=cx+col*step+(step/2 if row%2 else 0); y=cy+row*step*0.87
            if (x-cx)**2+(y-cy)**2 < (r*1.15)**2:
                pts=" ".join(f"{x+hr*math.cos(math.radians(60*k+30)):.1f},{y+hr*math.sin(math.radians(60*k+30)):.1f}" for k in range(6))
                out.append(f'<polygon points="{pts}" fill="{c}" stroke="{c}" stroke-width="6" stroke-linejoin="round"/><circle cx="{x-3:.1f}" cy="{y-5:.1f}" r="4.5" fill="{ch}"/>')
    return "".join(out)
def svg(P):
    # back: whole red lychee
    ax,ay,ar=420,540,235
    # front: peeled lychee in a shell cup
    bx,by,br=650,690,170
    A=lychee_shape(ax,ay,ar); B=lychee_shape(bx,by,br)
    # jagged shell cup line across front fruit
    zig=[]; n=9; y0=by+br*0.18
    for i in range(n+1):
        x=bx-br*1.08+i*(2*br*1.08/n); y=y0+(-22 if i%2 else 18)
        zig.append(f"{x:.1f},{y:.1f}")
    cup=f"M{zig[0]} L{' L'.join(zig[1:])} L{bx+br*1.2},{by+br*1.4} L{bx-br*1.2},{by+br*1.4} Z"
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
<defs><clipPath id="a"><path d="{A}"/></clipPath><clipPath id="b"><path d="{B}"/></clipPath><clipPath id="cup"><path d="{cup}"/></clipPath></defs>
<rect width="1024" height="1024" fill="{P['bg']}"/><g transform="translate(512 512) scale(0.9) translate(-502 -478)">
<path d="M{ax+10},{ay-ar+8} C{ax+20},{ay-ar-60} {ax+70},{ay-ar-110} {ax+150},{ay-ar-140}" fill="none" stroke="{P['stem']}" stroke-width="20" stroke-linecap="round"/>
<path d="M{ax+150},{ay-ar-140} C{ax+200},{ay-ar-230} {ax+330},{ay-ar-240} {ax+400},{ay-ar-200} C{ax+330},{ay-ar-110} {ax+220},{ay-ar-100} {ax+150},{ay-ar-140} Z" fill="{P['leaf1']}"/>
<path d="M{ax+150},{ay-ar-140} C{ax+240},{ay-ar-185} {ax+320},{ay-ar-200} {ax+385},{ay-ar-200}" fill="none" stroke="{P['leaf2']}" stroke-width="8" stroke-linecap="round"/>
<path d="M{ax+120},{ay-ar-122} C{ax+60},{ay-ar-220} {ax-60},{ay-ar-230} {ax-120},{ay-ar-190} C{ax-60},{ay-ar-100} {ax+50},{ay-ar-90} {ax+120},{ay-ar-122} Z" fill="{P['leaf2']}"/>
<path d="{A}" fill="{P['fruit']}"/>
<g clip-path="url(#a)">{hexes(ax,ay,ar,P['bump'],P['bumpHi'])}</g>
<path d="{B}" fill="{P['bg']}" stroke="{P['bg']}" stroke-width="28"/>
<path d="{B}" fill="{P['flesh']}"/>
<g clip-path="url(#b)">
 <ellipse cx="{bx+br*0.35}" cy="{by+br*0.1}" rx="{br*0.8}" ry="{br*1.1}" fill="{P['fleshShade']}"/>
 <ellipse cx="{bx-br*0.38}" cy="{by-br*0.42}" rx="{br*0.22}" ry="{br*0.34}" transform="rotate(-35 {bx-br*0.38} {by-br*0.42})" fill="#fff" opacity="{P['gloss']}"/>
 <g clip-path="url(#cup)"><rect x="0" y="0" width="1024" height="1024" fill="{P['fruit']}"/>{hexes(bx,by+br*0.4,br*1.2,P['bump'],P['bumpHi'],step=44,hr=18)}</g>
</g>
</g></svg>'''
L=dict(bg='#FFF1E3',fruit='#E2364C',bump='#B71F37',bumpHi='#F27586',leaf1='#4CAF50',leaf2='#2E8B3E',stem='#6B4E2E',flesh='#FFFFFF',fleshShade='#EFEBE3',gloss=0.9)
D=dict(L,bg='#241417',stem='#A07A52',flesh='#F4F1EC',fleshShade='#DED8CE')
T=dict(bg='#000000',fruit='#BDBDBD',bump='#8C8C8C',bumpHi='#E0E0E0',leaf1='#C8C8C8',leaf2='#9A9A9A',stem='#8A8A8A',flesh='#F5F5F5',fleshShade='#E2E2E2',gloss=0.9)
import os
os.chdir(os.path.dirname(os.path.abspath(__file__)))
for n,P in [('light',L),('dark',D),('tinted',T)]: open(n+'.svg','w').write(svg(P))

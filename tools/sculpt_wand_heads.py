"""Solid, fourfold-symmetric voxel crowns for the equipped wands.

All positions share the original shaft origin. Rotate any crown 90 degrees
around that shaft and both its geometry and its palette roles are unchanged.
"""
from math import ceil, floor, sqrt


def sculpt(voxels, item_id):
    for p in list(voxels):
        if p[1] >= 8:
            del voxels[p]

    def dot(x, y, z, role):
        # Authored details go around the entire crown, never on one face only.
        for a, b in {(x, z), (-z, x), (-x, -z), (z, -x),
                     (-x, z), (x, -z), (z, x), (-z, -x)}:
            voxels[a, y, b] = role

    def ball(y, radius, role='finish', height=None, lift=0):
        height = radius if height is None else height
        for yy in range(floor(y-height), ceil(y+height)+1):
            for x in range(-ceil(radius), ceil(radius)+1):
                for z in range(-ceil(radius), ceil(radius)+1):
                    if (x*x+z*z)/radius**2 + ((yy-y)/height)**2 <= 1.001:
                        dot(x, yy, z, role if yy >= y+lift else 'finish_shade')

    def ring(y, radius, role='trim'):
        for x in range(-ceil(radius+0.8), ceil(radius+0.8)+1):
            for z in range(-ceil(radius+0.8), ceil(radius+0.8)+1):
                if abs(sqrt(x*x+z*z)-radius) <= 0.8:
                    dot(x, y, z, role)

    def gem(y=12, radius=2, role='finish', height=3):
        for yy in range(y-height, y+height+1):
            width = radius*(1-abs(yy-y)/(height+0.5))
            for x in range(-radius, radius+1):
                for z in range(-radius, radius+1):
                    if abs(x)+abs(z) <= width+0.1:
                        dot(x, yy, z, role if yy >= y else 'finish_shade')

    def runes(y=12, radius=2, role='glow'):
        dot(radius, y, 0, role)

    def prongs(y=10, reach=2, tall=3, role='trim'):
        for step in range(reach+1):
            dot(step, y, 0, role)
        for yy in range(y, y+tall+1):
            dot(reach, yy, 0, 'glow' if yy == y+tall else role)

    def orb(y=12, radius=2.3):
        ball(y, radius)
        runes(y, int(radius))
        dot(0, y+int(radius), 0, 'glow')

    def halo(y=12, radius=3):
        # Intersecting vertical hoops have the same silhouette on all sides.
        for yy in range(y-radius, y+radius+1):
            for x in range(-radius, radius+1):
                if abs(sqrt(x*x+(yy-y)**2)-radius) <= 0.8:
                    dot(x, yy, 0, 'trim')

    # The neck and ferrule are circular too; the original grip stays untouched.
    dot(0, 8, 0, 'finish_shade')
    ring(9, 1, 'finish_shade')
    dot(0, 9, 0, 'finish')
    dot(0, 10, 0, 'finish')

    name = item_id.split('_wand', 1)[1].lstrip('_')
    if item_id.startswith('G'):
        grade = int(item_id[1])
        if grade in [1, 2]:
            orb(radius=2.3 if grade == 1 else 2.5)
            ring(10, 1.4)
        elif grade == 3:
            ball(12, 2.2, height=2.8)
            runes(12)
            dot(0, 15, 0, 'glow')
        elif grade == 4:
            gem()
            runes(12)
            ring(10, 1.4)
        elif grade == 5:
            orb(radius=1.8)
            prongs(10, 2, 4, 'finish')
        elif grade == 6:
            gem(radius=2, height=3)
            ring(12, 2)
            dot(0, 15, 0, 'glow')
        elif grade == 7:
            orb(radius=1.8)
            prongs(11, 3, 2)
            ring(10, 1.4)
        else:
            orb(radius=2.5)
            ring(12, 3)
            ring(10, 1.4)
            dot(0, 15, 0, 'glow')
    elif name in ['ofiron', 'thewandofsteel']:
        # Rounded steel rivet versus the Iron set's square forged cage.
        if name == 'ofiron':
            for yy in range(10, 14):
                for x in range(-2, 3):
                    for z in range(-2, 3):
                        if abs(x)+abs(z) <= 3:
                            dot(x, yy, z, 'finish_shade' if yy == 10 else 'finish')
            ring(13, 2, 'trim')
            runes(12)
        else:
            orb(radius=2.3)
            ring(11, 2)
            dot(0, 14, 0, 'trim')
    elif name in ['offrost', 'ofstorm', 'ofthestormeye']:
        if name == 'offrost':
            gem(height=3)
            prongs(11, 3, 2, 'finish')
        elif name == 'ofstorm':
            gem(height=3)
            ring(11, 2)
            runes(13, 1)
        else:
            orb(radius=1.8)
            halo()
            ring(12, 3, 'finish')
    elif name in ['ofjade', 'ofvenom', 'thewandofthefallenwood', 'seedoftomorrow']:
        ball(12, 1.8, height=2.8)
        if name == 'ofjade':
            prongs(10, 2, 3, 'finish')
            dot(0, 15, 0, 'glow')
        elif name == 'ofvenom':
            ring(12, 2)
            runes(13, 1)
            dot(0, 15, 0, 'glow')
        else:
            for yy in range(10, 13):
                dot(yy-9, yy, 0, 'finish_shade' if yy < 12 else 'trim')
            for yy, reach in [(12, 2), (13, 3), (14, 2)]:
                dot(reach, yy, 0, 'finish' if name == 'thewandofthefallenwood' else 'glow')
                dot(reach, yy, 1, 'finish')
            if name == 'seedoftomorrow':
                dot(0, 15, 0, 'trim')
    elif name == 'ofmycelium':
        ball(12, 3.2, height=1.6)
        ring(11, 2, 'finish_shade')
        runes(13, 2, 'glow')
        dot(0, 14, 0, 'trim')
    elif name in ['ofeclipse', 'oftheafterlife', 'oftheunmade', 'ofrequiem']:
        orb(radius=1.8)
        if name == 'ofeclipse':
            ring(12, 3)
            ring(11, 2, 'finish_shade')
        elif name == 'oftheafterlife':
            halo()
            prongs(10, 2, 2, 'finish')
        elif name == 'oftheunmade':
            halo()
            runes(15, 0)
            ring(12, 3, 'finish')
        else:
            prongs(10, 2, 4, 'finish')
            ring(11, 2, 'trim')
            dot(0, 14, 0, 'finish')
            dot(0, 15, 0, 'glow')
    elif name in ['thewandofdarkness', 'thewandofpower', 'thewandofsatan', 'thewandofthedivine', 'thewandofthespitit']:
        orb(radius=2.3)
        if name == 'thewandofdarkness':
            prongs(10, 3, 3, 'finish_shade')
        elif name == 'thewandofpower':
            gem(12, 3, 'finish', 2)
            runes(12, 3)
            dot(0, 15, 0, 'glow')
        elif name == 'thewandofsatan':
            prongs(10, 3, 4, 'finish')
            ring(11, 2)
        elif name == 'thewandofthedivine':
            ring(12, 3)
            prongs(10, 3, 3)
            dot(0, 15, 0, 'glow')
        else:
            ball(12, 2, height=3)
            ring(11, 2)
            runes(13, 1)
            dot(0, 15, 0, 'glow')
    elif name == 'counterhymn':
        prongs(10, 2, 4, 'finish')
        ring(10, 2)
        dot(0, 11, 0, 'glow')
    elif name in ['daybreaker', 'sunsplinter']:
        orb(radius=1.8)
        for reach in range(1, 4):
            dot(reach, 12, 0, 'glow' if reach == 3 else 'finish')
        for yy in [9, 10, 14, 15]:
            dot(0, yy, 0, 'glow' if yy in [9, 15] else 'finish')
        if name == 'sunsplinter':
            for yy in [10, 14]:
                dot(1, yy, 1, 'trim')
    elif name in ['mirageengine', 'wakeful', 'stillpoint', 'pocketplanetarium']:
        orb(radius=1.3 if name == 'stillpoint' else 1.8)
        if name == 'mirageengine':
            halo()
            ring(12, 3, 'glow')
        elif name == 'wakeful':
            halo(radius=2)
            ring(11, 2)
            dot(0, 15, 0, 'trim')
        elif name == 'stillpoint':
            prongs(10, 2, 4, 'finish')
            ring(10, 2)
            ring(14, 2)
        else:
            ring(12, 3)
            halo()
            runes(12, 3, 'glow')
    elif name == 'silentbell':
        # A genuinely hollow bell, with an open underside and solid clapper.
        for yy, radius in [(10, 2.7), (11, 2.3), (12, 2), (13, 1.4)]:
            ring(yy, radius, 'trim' if yy == 10 else 'finish')
        dot(0, 13, 0, 'finish')
        dot(0, 14, 0, 'trim')
        for yy in range(9, 13):
            dot(0, yy, 0, 'glow' if yy == 9 else 'finish_shade')
        runes(12, 2)
    elif name == 'dewglass':
        ball(11.5, 2.4, height=2.1)
        gem(13, 1, 'trim', 2)
        runes(12, 2)
        ring(10, 1.4)
    elif name == 'thewandofash':
        orb(radius=1.8)
        prongs(10, 2, 3, 'finish')
        dot(0, 14, 0, 'trim')
        dot(0, 15, 0, 'glow')
    elif name == 'lastfirework':
        orb(radius=2.5)
        prongs(10, 3, 4, 'trim')
        dot(0, 15, 0, 'glow')
        ring(10, 2, 'finish')
    else:
        raise ValueError('Wand needs an authored crown: ' + item_id)
